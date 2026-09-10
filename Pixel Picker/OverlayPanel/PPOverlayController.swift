//
//  PPOverlayController.swift
//  Pixel Picker
//

import CocoaLumberjackSwift
import ScreenCaptureKit

// This is the controller for the actual pixel picker itself.
class PPOverlayController: NSWindowController {

    private var captureTask: Task<Void, Never>?
    private var captureContent: SCShareableContent?
    private var pendingCapturePoint: NSPoint?
    private var captureSession = 0
    private var pickAfterCapture = false

    // Outlets related to the actual pixel picker.
    @IBOutlet weak var overlayPanel: PPOverlayPanel!
    @IBOutlet weak var wrapper: PPOverlayWrapper!
    @IBOutlet weak var preview: PPOverlayPreview!

    // Outlets relating to the picker's info box.
    @IBOutlet weak var infoPanel: PPOverlayPanel!
    @IBOutlet weak var infoWrapper: NSView!
    @IBOutlet weak var infoFormatField: NSTextField!
    @IBOutlet weak var infoDetailField: NSTextField!
    @IBOutlet weak var infoContrastView: NSView!
    @IBOutlet weak var infoContrastField: NSTextField!

    // This mode increases the picker's size, increases the magnification and also slows down move
    // events to make it easier to pick the right pixel. We dissociate the mouse (input) from the
    // mouse cursor while the focusMode is active. This is so we can slow it down.
    var focusMode: Bool = false {
        didSet {
            if isEnabled {
                panelSize = focusMode ? PPOverlayController.panelSizeLarge : PPOverlayController.panelSizeNormal
                overlayPanel.activate(withSize: panelSize, infoPanel: infoPanel)
                wrapper.layer?.cornerRadius = PPState.shared.paschaModeEnabled ? 0 : panelSize / 2
                CGAssociateMouseAndMouseCursorPosition(boolean_t(truncating: focusMode ? 0 : 1))
            }
        }
    }

    // The current and different sizes of the pixel picker.
    private static let panelSizeNormal: CGFloat = 150
    private static let panelSizeLarge: CGFloat = 300
    private var panelSize: CGFloat = PPOverlayController.panelSizeNormal

    // The app that was last active before the picker was activated. We keep track
    // of this in order to fully restore first responder status after picking a pixel.
    private var lastActiveApp: NSRunningApplication?

    // Used to compute the next mouse location while we control the mouse.
    private var lastMouseLocation = NSEvent.mouseLocation

    // The last colour that the picker inspected.
    private var lastHighlightedColor: NSColor = NSColor.black

    // Whether or not the picker should be actively updating its preview.
    private var isEnabled: Bool = false {
        didSet {
            if isEnabled {
                lastMouseLocation = NSEvent.mouseLocation
                startMonitoringEvents()
            } else {
                stopMonitoringEvents()
                focusMode = false
            }
        }
    }

    override func awakeFromNib() {
        // Setup the info window.
        infoWrapper.wantsLayer = true
        infoWrapper.layer?.cornerRadius = 8
        infoWrapper.layer?.backgroundColor = NSColor.black.cgColor
        infoContrastView.wantsLayer = true
        infoContrastView.layer?.cornerRadius = 3

        // For some reason if we don't listen for events this way we miss the escape key.
        NSEvent.addLocalMonitorForEvents(matching: [.keyDown]) { [weak self] event in
            guard let self = self else { return event }
            return self.handleLocalKeyEvent(event)
        }
    }

    // Other controls, including the shortcut editor, must receive keys
    // while the picker is closed. Consume only events handled by the picker.
    func handleLocalKeyEvent(_ event: NSEvent) -> NSEvent? {
        guard isEnabled else { return event }
        keyDown(with: event)
        return nil
    }

    // Even though the picker is active and is the key window, our application is not the
    // active application. This means we won't get local events, so we must subscribe to
    // the global events instead.
    var globalMonitors: [Any] = []
    func startMonitoringEvents() {
        stopMonitoringEvents()
        globalMonitors.append(NSEvent.addGlobalMonitorForEvents(matching: [.flagsChanged]) { self.flagsChanged(with: $0) }!)
        globalMonitors.append(NSEvent.addGlobalMonitorForEvents(matching: [.mouseMoved]) { self.mouseMoved(with: $0) }!)
    }
    func stopMonitoringEvents() {
        while globalMonitors.count > 0 { NSEvent.removeMonitor(globalMonitors.popLast()!) }
    }

    // When the user clicks, animate the cursor out, save the picked color and copy it.
    override func mouseDown(with event: NSEvent) {
        requestPick()
    }

    // Listen to key events.
    override func keyDown(with event: NSEvent) {
        if pickAfterCapture && Int(event.keyCode) != kVK_Escape { return }
        switch Int(event.keyCode) {
        // Close immediately on escape.
        case kVK_Escape:
            hidePicker(animate: false)
        // Act as if the user clicked on space.
        case kVK_Space:
            requestPick()
        // Cycle between formats when the user presses the left or right arrow keys.
        case kVK_LeftArrow:
            PPState.shared.chosenFormat = PPState.shared.chosenFormat.previous()
            updateInfoPanel(lastHighlightedColor, lastHighlightedColor.bestContrastingColor())
        case kVK_RightArrow:
            PPState.shared.chosenFormat = PPState.shared.chosenFormat.next()
            updateInfoPanel(lastHighlightedColor, lastHighlightedColor.bestContrastingColor())
        // Move up
        case kVK_ANSI_K:
            moveByPixel(dx: 0.0, dy: 1.0)
            break
        // Move down
        case kVK_ANSI_J:
            moveByPixel(dx: 0.0, dy: -1.0)
            break
        // Move left
        case kVK_ANSI_H:
            moveByPixel(dx: -1.0, dy: 0.0)
            break
        // Move right
        case kVK_ANSI_L:
            moveByPixel(dx: 1.0, dy: 0.0)
            break
        // Adjust magnification with `+` or `-` and `[` or `]`
        case kVK_ANSI_Minus:
            fallthrough
        case kVK_ANSI_LeftBracket:
            PPState.shared.changeMagnification(-2)
            moveByPixel(dx: 0, dy: 0)
        case kVK_ANSI_Equal:
            fallthrough
        case kVK_ANSI_RightBracket:
            PPState.shared.changeMagnification(2)
            moveByPixel(dx: 0, dy: 0)
        default:
            break
        }
    }

    func moveByPixel(dx: CGFloat, dy: CGFloat) {
        var mouseLoc = lastMouseLocation
        let currentScreen = getScreenWithMouse()
        guard let screenScale = currentScreen?.backingScaleFactor else {
            return
        }
        mouseLoc.x += dx / screenScale
        mouseLoc.y += dy / screenScale
        lastMouseLocation = mouseLoc
        updatePreview(aroundPoint: mouseLoc)
        CGWarpMouseCursorPosition(convertToCGCoordinateSystem(mouseLoc))
    }

    // Enable "focusMode" when correct modifier flag is changed.
    override func flagsChanged(with event: NSEvent) {
        if isEnabled && !pickAfterCapture {
            focusMode = event.modifierFlags.contains(PPState.shared.focusModeModifier)
            updatePreview(aroundPoint: lastMouseLocation)
        }
    }

    // Move the picker with the mouse, and if "focusMode" is active then
    // slow it down to make it easier to pick the correct pixel.
    override func mouseMoved(with event: NSEvent) {
        if isEnabled && !pickAfterCapture {
            let currentMouseLocation = NSEvent.mouseLocation
            var nextMouseLocation = currentMouseLocation

            // Slow down tracking speed when focusMode is active.
            if focusMode {
                let speed: CGFloat = focusMode ? 0.1 : 0.5
                let x = lastMouseLocation.x + (event.deltaX * speed)
                let y = lastMouseLocation.y - (event.deltaY * speed)

                // Ensure the picker doesn't travel off screen.
                nextMouseLocation = NSPoint(x: x, y: y)
                for screen in NSScreen.screens {
                    let outlier = Coordinate.isOutsideRect(nextMouseLocation, screen.frame)
                    if NSMouseInRect(currentMouseLocation, screen.frame, false) && outlier != .none {
                        if outlier == .x { nextMouseLocation.x = currentMouseLocation.x }
                        if outlier == .y { nextMouseLocation.y = currentMouseLocation.y }
                        if outlier == .both { nextMouseLocation = currentMouseLocation }
                    }
                }

                // Since we've disassociated the mouse input with the cursor, we manually move it.
                CGWarpMouseCursorPosition(convertToCGCoordinateSystem(nextMouseLocation))
            }

            updatePreview(aroundPoint: nextMouseLocation)
            lastMouseLocation = nextMouseLocation
        }
    }

    // Wait for the latest capture before copying the selected pixel.
    private func requestPick() {
        guard isEnabled && !pickAfterCapture else { return }
        pickAfterCapture = true
        updatePreview(aroundPoint: lastMouseLocation)
    }

    func pickColor() {
        let pickedColor = PPPickedColor(color: lastHighlightedColor, format: PPState.shared.chosenFormat)
        PPState.shared.addRecentPick(pickedColor)
        copyToPasteboard(stringValue: pickedColor.asString)
    }

    // Show the picker, save the previously active application, and hide the cursor.
    func showPicker() {
        if overlayPanel.isVisible || infoPanel.isVisible { return }
        captureSession += 1
        captureContent = nil
        isEnabled = true
        overlayPanel.activate(withSize: panelSize, infoPanel: infoPanel)

        if NSWorkspace.shared.frontmostApplication?.bundleIdentifier != Bundle.main.bundleIdentifier {
            lastActiveApp = NSWorkspace.shared.frontmostApplication
        }

        wrapper.layer?.cornerRadius = PPState.shared.paschaModeEnabled ? 0 : panelSize / 2
        resizeInfoPanel()
        updatePreview(aroundPoint: NSEvent.mouseLocation)
        HideCursor()
    }

    // Hides the picker, optionally with an animation. Takes care to restore the last
    // active application (if there was one).
    func hidePicker(animate: Bool) {
        isEnabled = false
        captureSession += 1
        captureTask?.cancel()
        captureTask = nil
        captureContent = nil
        pendingCapturePoint = nil
        pickAfterCapture = false
        infoFormatField.stringValue = "Copied!"

        let deactivate = { [unowned self] in
            self.overlayPanel.orderOut(self)
            self.infoPanel.orderOut(self)
            if !PPState.shared.paschaModeEnabled { self.wrapper.layer?.cornerRadius = self.panelSize / 2 }

            // Ensure the app that was in use before overlay is shown is re-activated.
            if self.lastActiveApp != nil, self.lastActiveApp != NSRunningApplication.current {
                self.lastActiveApp!.activate(options: .activateAllWindows)
                self.lastActiveApp = nil
            }
        }

        if animate {
            // Hide crosshair.
            preview.crosshair.strokeColor = nil

            // (0-150ms): move the info panel to the middle.
            runAnimation({ (context) in
                context.duration = 0.15
                infoPanel.setFrameOrigin(NSPoint(x: overlayPanel.frame.midX - (infoPanel.frame.width / 2), y: infoPanel.frame.origin.y))
            }, done: nil)

            // (0-300ms): shrink preview, after that show the cursor.
            runAnimation({ (context) in
                context.duration = 0.3
                wrapper.layer?.cornerRadius = 0
                overlayPanel.setFrame(overlayPanel.frame.insetBy(dx: panelSize / 2, dy: panelSize / 2), display: false)
            }, done: { ShowCursor() })

            // (After 500ms): close everything.
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5, execute: deactivate)
        } else {
            ShowCursor()
            deactivate()
        }
    }

    // Ensures the info panel is wide enough to fit its contents.
    func resizeInfoPanel() {
        var rect = infoPanel.frame
        rect.size.width = max(infoFormatField.intrinsicContentSize.width, infoDetailField.intrinsicContentSize.width) + 40
        infoPanel.setFrame(rect, display: false)
    }

    // Get the screen that current has displayed the mouse.
    func getScreenWithMouse() -> NSScreen? {
        let mouseLocation = NSEvent.mouseLocation
        let screens = NSScreen.screens
        let screenWithMouse = (screens.first { NSMouseInRect(mouseLocation, $0.frame, false) })

        return screenWithMouse
    }

    // Updates the info panel with the correct colors and text.
    func updateInfoPanel(_ color: NSColor, _ contrastingColor: NSColor) {
        infoWrapper.layer?.backgroundColor = color.cgColor
        infoFormatField.textColor = contrastingColor
        infoDetailField.textColor = contrastingColor
        infoFormatField.stringValue = PPState.shared.chosenFormat.rawValue
        infoDetailField.stringValue = PPState.shared.chosenFormat.asComponentString(withColor: color)
        
        // Show contrast level if it's enabled and a color has previously been picked.
        if let previousPick = PPState.shared.recentPicks.last, PPState.shared.showWCAGLevel {
            infoContrastView.isHidden = false
            
            // Calculate constrast ratio between current and previously picked color.
            let wcagLevel = WCAGLevel(contrastRatio: color.contrastRatio(to: previousPick.color))
            infoContrastField.stringValue = wcagLevel.rawValue
            
            infoContrastView.layer?.backgroundColor = previousPick.color.cgColor
            infoContrastField.textColor = previousPick.color.bestContrastingColor()
        } else {
            infoContrastView.isHidden = true
        }
        
        resizeInfoPanel()
    }

    // ScreenCaptureKit replaces CGWindowListCreateImage in current macOS SDKs.
    // Exclude our own windows so the magnifier never captures itself.
    @MainActor
    private func getScreenShot(aroundPoint point: NSPoint) async throws -> CGImage? {
        let panelIDs = Set([CGWindowID(overlayPanel.windowNumber), CGWindowID(infoPanel.windowNumber)])
        if captureContent == nil {
            // A status-item click can reach here before WindowServer has listed
            // the newly ordered panels. Never cache an incomplete exclusion list.
            for _ in 0..<10 {
                let content = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: false)
                try Task.checkCancellation()
                if panelIDs.isSubset(of: Set(content.windows.map(\.windowID))) {
                    captureContent = content
                    break
                }
                try await Task.sleep(nanoseconds: 20_000_000)
            }
        }
        guard let content = captureContent else {
            throw NSError(domain: "PixelPicker.Capture", code: 1,
                userInfo: [NSLocalizedDescriptionKey: "The picker windows are not ready for capture. Please try again."])
        }
        guard let screen = getScreenFromPoint(point),
              let displayID = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? UInt32,
              let display = content.displays.first(where: { $0.displayID == displayID }) else { return nil }
        // Window IDs are reliable for accessory/menu-bar apps even when they
        // aren't included in SCShareableContent.applications.
        let excludedWindows = content.windows.filter {
            panelIDs.contains($0.windowID) || $0.owningApplication?.processID == ProcessInfo.processInfo.processIdentifier
        }
        let filter = SCContentFilter(display: display, excludingWindows: excludedWindows)
        let configuration = SCStreamConfiguration()
        let scale = CGFloat(filter.pointPixelScale)
        // Capture the complete native raster. Fractional sourceRect origins can
        // interpolate neighboring pixels before we ever get a CGImage.
        configuration.width = Int((filter.contentRect.width * scale).rounded())
        configuration.height = Int((filter.contentRect.height * scale).rounded())
        configuration.captureResolution = .best
        configuration.showsCursor = false
        configuration.capturesAudio = false
        let image = try await SCScreenshotManager.captureImage(contentFilter: filter, configuration: configuration)
        let cgPoint = convertToCGCoordinateSystem(point)
        let pixelPoint = CGPoint(
            x: (cgPoint.x - display.frame.minX) * scale,
            y: (cgPoint.y - display.frame.minY) * scale
        )
        return image.pixelRegion(centeredAt: pixelPoint, size: Int((panelSize * scale).rounded()))
    }

    // Update overlay with zoomed pixels around the given point.
    func updatePreview(aroundPoint point: NSPoint) {
        // Ensure the overlayPanel is always the key window.
        if !overlayPanel.isKeyWindow {
            overlayPanel.activate(withSize: panelSize, infoPanel: infoPanel)
            // Reset the cursor state to ensure it's hidden (the foremost application changes then
            // WindowServer resets our "SetsCursorInBackground" magic).
            ShowCursor()
            HideCursor()
        }

        // Center the mouse in the picker window.
        overlayPanel.setFrameOrigin(NSPoint(x: point.x - (panelSize / 2), y: point.y - (panelSize / 2)))
        pendingCapturePoint = point
        guard captureTask == nil else { return }
        let session = captureSession
        captureTask = Task { @MainActor [weak self] in
            guard let self = self else { return }
            defer {
                if self.captureSession == session { self.captureTask = nil }
            }
            do {
                while let point = self.pendingCapturePoint, self.isEnabled, self.captureSession == session {
                    self.pendingCapturePoint = nil
                    guard let image = try await self.getScreenShot(aroundPoint: point) else { continue }
                    guard !Task.isCancelled, self.isEnabled, self.captureSession == session else { return }
                    self.renderPreview(image, aroundPoint: point)
                    if self.pickAfterCapture && self.pendingCapturePoint == nil {
                        self.pickColor()
                        self.hidePicker(animate: true)
                        return
                    }
                }
            } catch {
                guard self.isEnabled, self.captureSession == session else { return }
                self.hidePicker(animate: false)
                let alert = NSAlert()
                alert.messageText = "Screen capture unavailable"
                alert.informativeText = "Allow Pixel Picker in System Settings → Privacy & Security → Screen Recording, then try again.\n\n" + error.localizedDescription
                alert.runModal()
            }
        }
    }

    // Crop and color-match the captured pixels before drawing the preview.
    private func renderPreview(_ screenShot: CGImage, aroundPoint point: NSPoint) {
        // Calculate a zoomed rect which will crop the screenshot we took.
        let magnification = CGFloat(PPState.shared.magnificationLevel) * (focusMode ? 2 : 1)
        let croppedRect = pixelPreviewRect(imageWidth: screenShot.width,
            imageHeight: screenShot.height, magnification: magnification)
        let zoomedSize = croppedRect.width
        guard let zoomedImage = screenShot.cropping(to: croppedRect) else { return }
        let pixelSize = panelSize / zoomedSize

        // Convert the preview to the correct color space, and update the overlay.

        // User has chosen a custom color space.
        if let colorSpace = getChosenColorSpace(point) {
            if colorSpace == zoomedImage.colorSpace {
                return updatePreview(zoomedImage, pixelSize, zoomedSize)
            } else if let image = zoomedImage.copy(colorSpace: colorSpace) {
                return updatePreview(image, pixelSize, zoomedSize)
            }
        }

        // No custom color space chosen, so use the screen's one.
        if let colorSpace = getScreenColorSpace(point) {
            if colorSpace == zoomedImage.colorSpace {
                return updatePreview(zoomedImage, pixelSize, zoomedSize)
            } else if let image = zoomedImage.copy(colorSpace: colorSpace) {
                return updatePreview(image, pixelSize, zoomedSize)
            }
        }

        // If that also didn't work, then just return the image in its default color space.
        return updatePreview(zoomedImage, pixelSize, zoomedSize)
    }

    private func updatePreview(_ image: CGImage, _ pixelSize: CGFloat, _ numberOfPixels: CGFloat) {
        let middlePosition = numberOfPixels / 2

        // Extract the middle pixel color from the prepared image.
        let colorAtPixel = image.colorAt(x: Int(middlePosition), y: Int(middlePosition))
        let contrastingColor = colorAtPixel.bestContrastingColor()

        // Update picker border and info panel.
        wrapper.update(contrastingColor.cgColor)
        updateInfoPanel(colorAtPixel, contrastingColor)

        // Update the picker preview.
        preview.layer?.contents = image
        preview.updateCrosshair(pixelSize, middlePosition, contrastingColor.cgColor)
        let showGrid = PPState.shared.gridSetting == .always || (focusMode && PPState.shared.gridSetting == .inFocusMode)
        preview.updateGrid(cellSize: pixelSize, numberOfCells: Int(numberOfPixels), shouldDisplay: showGrid)

        // Save color under pixel (used when copied).
        lastHighlightedColor = colorAtPixel
    }

    private func getScreenColorSpace(_ point: NSPoint) -> CGColorSpace? {
        return getScreenFromPoint(point)?.colorSpace?.cgColorSpace
    }

    // Gets the colorspace in which to display the preview and retreive color values.
    private func getChosenColorSpace(_ point: NSPoint) -> CGColorSpace? {
        if let name = PPState.shared.colorSpace, let colorSpace = CGColorSpace(name: name as CFString) {
            return colorSpace
        }

        return nil
    }
}
