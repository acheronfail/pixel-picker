//
//  PPOverlayController.swift
//  PixelPicker
//

import CleanroomLogger

// This is the controller for the actual pixel picker itself.
class PPOverlayController: NSWindowController {

    // Outlets related to the actual pixel picker.
    @IBOutlet weak var overlayPanel: PPOverlayPanel!
    @IBOutlet weak var wrapper: PPOverlayWrapper!
    @IBOutlet weak var preview: PPOverlayPreview!

    // Outlets relating to the picker's info box.
    @IBOutlet weak var infoPanel: PPOverlayPanel!
    @IBOutlet weak var infoBox: NSBox!
    @IBOutlet weak var infoFormatField: NSTextField!
    @IBOutlet weak var infoDetailField: NSTextField!

    // This mode increases the picker's size, increases the magnification and also slows down move
    // events to make it easier to pick the right pixel. We dissociate the mouse (input) from the
    // mouse cursor while the concentrationMode is active. This is so we can slow it down.
    var concentrationMode: Bool = false {
        didSet {
            if isEnabled {
                panelSize = concentrationMode ? 300 : 150
                overlayPanel.activate(withSize: panelSize, infoPanel: infoPanel)
                wrapper.layer?.cornerRadius = PPState.shared.paschaModeEnabled ? 0 : panelSize / 2
                CGAssociateMouseAndMouseCursorPosition(boolean_t(truncating: concentrationMode ? 0 : 1))
            }
        }
    }

    // The size of the pixel picker.
    // TODO: use constants rather than hard-coded values.
    private var panelSize: CGFloat = 150

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
                concentrationMode = false
            }
        }
    }

    override func awakeFromNib() {
        // For some reason if we don't listen for events this way we miss the escape key.
        NSEvent.addLocalMonitorForEvents(matching: [.keyDown]) {
            if self.isEnabled { self.keyDown(with: $0) }
            return nil
        }
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
        hidePicker(animate: true)

        let pickedColor = PPPickedColor(color: lastHighlightedColor, format: PPState.shared.chosenFormat)
        PPState.shared.addRecentPick(pickedColor)
        copyToPasteboard(stringValue: pickedColor.asString)
    }

    // Close picker immediately when the user presses the escape key.
    override func keyDown(with event: NSEvent) {
        if event.keyCode == kVK_Escape { hidePicker(animate: false) }
        if event.keyCode == kVK_Space {
            let format = PPState.shared.chosenFormat
            PPState.shared.chosenFormat = event.modifierFlags.contains(.shift) ? format.previous() : format.next()
            updateInfoPanel(lastHighlightedColor, lastHighlightedColor.bestContrastingColor())
        }
    }

    // Enable "concentrationMode" when correct modifier flag is changed.
    override func flagsChanged(with event: NSEvent) {
        if isEnabled {
            concentrationMode = event.modifierFlags.contains(PPState.shared.concentrationModeModifier)
            updatePreview(aroundPoint: lastMouseLocation)
        }
    }

    // Move the picker with the mouse, and if "concentrationMode" is active then
    // slow it down to make it easier to pick the correct pixel.
    override func mouseMoved(with event: NSEvent) {
        if isEnabled {
            let currentMouseLocation = NSEvent.mouseLocation
            var nextMouseLocation = currentMouseLocation

            // Slow down tracking speed when concentration mode is active.
            if concentrationMode {
                let speed: CGFloat = concentrationMode ? 0.1 : 0.5
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

    // Show the picker, save the previously active application, and hide the cursor.
    func showPicker() {
        if overlayPanel.isVisible || infoPanel.isVisible { return }
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

    // Updates the info panel with the correct colors and text.
    func updateInfoPanel(_ color: NSColor, _ contrastingColor: NSColor) {
        infoBox.fillColor = color.alphaComponent == 0 ? NSColor.black : color
        infoFormatField.textColor = contrastingColor
        infoDetailField.textColor = contrastingColor
        infoFormatField.stringValue = PPState.shared.chosenFormat.rawValue
        infoDetailField.stringValue = PPState.shared.chosenFormat.asComponentString(withColor: color)
        resizeInfoPanel()
    }

    // Gets a screenshot of all windows below the picker. If the panel is configured correctly,
    // then hopefully this should capture everything - dock, menubar, etc - underneath the picker.
    func getScreenShot(aroundPoint point: NSPoint) -> CGImage? {
        let cgPoint = convertToCGCoordinateSystem(point)
        let rect = CGRect(x: cgPoint.x - panelSize / 2, y: cgPoint.y - panelSize / 2, width: panelSize, height: panelSize)
        return CGWindowListCreateImage(rect, [.optionOnScreenBelowWindow], CGWindowID(overlayPanel.windowNumber), .bestResolution)
    }

    // Update overlay with zoomed pixels around the given point.
    func updatePreview(aroundPoint point: NSPoint) {
        // Ensure the overlayPanel is always the key window.
        if !overlayPanel.isKeyWindow {
            overlayPanel.activate(withSize: panelSize, infoPanel: infoPanel)
        }

        let normalisedPoint = NSPoint(x: round(point.x * 2) / 2, y: round(point.y * 2) / 2)
        if let screenShot = getScreenShot(aroundPoint: normalisedPoint) {
            // Calculate a zoomed rect which will crop the screenshot we took.
            let magnification = CGFloat(PPState.shared.magnificationLevel)
            let zoomReciprocal: CGFloat = 1.0 / (concentrationMode ? magnification * 2.5 : magnification)
            let currentSize = CGFloat(screenShot.width) + 1
            let origin = floor(currentSize * ((1 - zoomReciprocal) / 2))
            let x = origin + (isHalf(normalisedPoint.x) ? 1 : 0)
            let y = origin + (isHalf(normalisedPoint.y) ? 1 : 0)

            // Ensure preview size is an odd number (so there's a middle pixel).
            let zoomedSize = floor(ensureOdd(currentSize * zoomReciprocal))
            let middle = zoomedSize / 2

            let croppedRect = CGRect(x: x, y: y, width: zoomedSize, height: zoomedSize)
            let zoomedImage: CGImage = screenShot.cropping(to: croppedRect)!

            // Extract the middle pixel color from the zoomed image.
            let bitmap = NSBitmapImageRep(cgImage: zoomedImage)
            if let colorAtPixel = bitmap.colorAt(x: Int(middle), y: Int(middle)) {
                let contrastingColor = colorAtPixel.bestContrastingColor()

                preview.layer?.contents = zoomedImage
                preview.updateCrosshair(panelSize / zoomedSize, middle, contrastingColor.cgColor)
                wrapper.update(contrastingColor.cgColor)
                updateInfoPanel(colorAtPixel, contrastingColor)

                // Save color under pixel (used when copied).
                lastHighlightedColor = colorAtPixel
            }
        }

        // Center the mouse in the picker window.
        overlayPanel.setFrameOrigin(NSPoint(x: normalisedPoint.x - (panelSize / 2), y: normalisedPoint.y - (panelSize / 2)))
    }
}
