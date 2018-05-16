//
//  PPOverlayController.swift
//  PixelPicker
//

import CleanroomLogger

class PPOverlayController: NSWindowController {

    @IBOutlet weak var overlayPanel: PPOverlayPanel!
    @IBOutlet weak var wrapper: PPOverlayWrapper!
    @IBOutlet weak var preview: PPOverlayPreview!
    
    @IBOutlet weak var infoPanel: PPOverlayPanel!
    @IBOutlet weak var infoBox: NSBox!
    @IBOutlet weak var infoFormatField: NSTextField!
    @IBOutlet weak var infoDetailField: NSTextField!
    
    // ...
    var magnification: CGFloat = 8.0
    
    // ...
    var concentrationMode: Bool = false {
        didSet {
            if isEnabled {
                setPanelSize(concentrationMode ? 300 : 200)
                overlayPanel.activate(withInfoPanel: infoPanel)
                wrapper.layer?.cornerRadius = getPanelSize() / 2
            }
        }
    }
    
    // ...
    private var lastActiveApp: NSRunningApplication?
    
    // ...
    private var lastMouseLocation = NSEvent.mouseLocation
    
    // ...
    private var lastHighlightedColor: NSColor = NSColor.black
    
    // ...
    // doc mouse dissociation
    private var isEnabled: Bool = false {
        didSet {
            if isEnabled {
                lastMouseLocation = NSEvent.mouseLocation
                startMonitoringEvents()
                CGAssociateMouseAndMouseCursorPosition(boolean_t(truncating: false as NSNumber))
            } else {
                stopMonitoringEvents()
                concentrationMode = false
                CGAssociateMouseAndMouseCursorPosition(boolean_t(truncating: true as NSNumber))
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
    
    // ...
    // doc why (since background app)
    var globalMonitors: [Any] = []
    func startMonitoringEvents() {
        stopMonitoringEvents()
        globalMonitors.append(NSEvent.addGlobalMonitorForEvents(matching: [.flagsChanged]) { self.flagsChanged(with: $0) }!)
        globalMonitors.append(NSEvent.addGlobalMonitorForEvents(matching: [.mouseMoved]) { self.mouseMoved(with: $0) }!)
    }
    func stopMonitoringEvents() {
        while globalMonitors.count > 0 { NSEvent.removeMonitor(globalMonitors.popLast()!) }
    }
    
    override func mouseDown(with event: NSEvent) {
        hide(animate: true)

        // TODO: copy value in chosen format
        let value = "#\(lastHighlightedColor.asHexString)"
        NSPasteboard.general.declareTypes([.string], owner: nil)
        NSPasteboard.general.setString(value, forType: .string)
        
        infoFormatField.stringValue = "Copied!"
    }
    
    // ...
    override func keyDown(with event: NSEvent) {
        if event.keyCode == kVK_Escape { hide(animate: false) }
    }
    
    // Enable concentrationMode when correct flag is changed.
    override func flagsChanged(with event: NSEvent) {
        if isEnabled {
            concentrationMode = event.modifierFlags.contains(PPState.shared.getConcentrationModeModifier())
            updatePreview(aroundPoint: lastMouseLocation)
        }
    }
    
    // ...
    override func mouseMoved(with event: NSEvent) {
        if isEnabled {
            let speed: CGFloat = concentrationMode ? 0.1 : 0.5            
            var currentMouseLocation = NSEvent.mouseLocation
            currentMouseLocation.x = lastMouseLocation.x + (event.deltaX * speed)
            currentMouseLocation.y = lastMouseLocation.y - (event.deltaY * speed)

            CGWarpMouseCursorPosition(convertToCGCoordinateSystem(currentMouseLocation))
            lastMouseLocation = currentMouseLocation
            updatePreview(aroundPoint: currentMouseLocation)
        }
    }

    // ...
    // doc should only be called when starting the app, otherwise overlayPanel.activate()
    func show() {
        if NSWorkspace.shared.frontmostApplication?.bundleIdentifier != Bundle.main.bundleIdentifier {
            lastActiveApp = NSWorkspace.shared.frontmostApplication
        }
        overlayPanel.activate(withInfoPanel: infoPanel)
        isEnabled = true
        
        // TODO: restore preferred format
        infoFormatField.stringValue = "CSS Hex"

        updatePreview(aroundPoint: NSEvent.mouseLocation)
        HideCursor()
    }

    // ...
    func hide(animate: Bool) {
        isEnabled = false
        
        let deactivate = { [unowned self] in
            self.overlayPanel.orderOut(nil)
            self.wrapper.layer?.cornerRadius = getPanelSize() / 2
            
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
                overlayPanel.setFrame(overlayPanel.frame.insetBy(dx: getPanelSize() / 2, dy: getPanelSize() / 2), display: false)
            }, done: { ShowCursor() })

            // (After 500ms): close everything.
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5, execute: deactivate)
        } else {
            ShowCursor()
            deactivate()
        }
    }

    // ...
    func updateInfoBox(_ color: NSColor, _ contrastingColor: NSColor) {
        infoBox.fillColor = color.alphaComponent == 0 ? NSColor.black : color
        infoFormatField.textColor = contrastingColor
        infoDetailField.textColor = contrastingColor
        infoDetailField.stringValue = "#\(color.asHexString)"
    }

    // Get a screenshot of all windows below this panel. If we've configured the panel correctly,
    // then hopefully this should capture everything that's on the screen.
    func getScreenShot(aroundPoint point: NSPoint) -> CGImage? {
        let cgPoint = convertToCGCoordinateSystem(point)
        let rect = CGRect(x: cgPoint.x - getPanelSize() / 2, y: cgPoint.y - getPanelSize() / 2, width: getPanelSize(), height: getPanelSize())
        return CGWindowListCreateImage(rect, [.optionOnScreenBelowWindow], CGWindowID(overlayPanel.windowNumber), .bestResolution)
    }

    // Update overlay with zoomed pixels around the given point.
    func updatePreview(aroundPoint point: NSPoint) {

        // Ensure the overlayPanel is always the keywindow.
        if !overlayPanel.isKeyWindow {
            overlayPanel.makeKeyAndOrderFront(self)
        }

        let normalisedPoint = NSPoint(x: round(point.x * 2) / 2, y: round(point.y * 2) / 2)
        if let screenShot = getScreenShot(aroundPoint: normalisedPoint) {
            // Calculate a zoomed rect which will crop the screenshot we took.
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
            bitmap.colorSpaceName = .calibratedRGB
            if let colorAtPixel = bitmap.colorAt(x: Int(middle), y: Int(middle)) {
                let contrastingColor = colorAtPixel.contrastingColor()

                preview.layer?.contents = NSImage(cgImage: zoomedImage, size: NSSize(width: getPanelSize(), height: getPanelSize()))
                preview.updateCrosshair(zoomedSize, middle, contrastingColor.cgColor)
                wrapper.update(contrastingColor.cgColor)
                updateInfoBox(colorAtPixel, contrastingColor)

                // Save color under pixel (used when copied).
                lastHighlightedColor = colorAtPixel
            }
        }
        
        // Center the mouse in the picker window.
        overlayPanel.setFrameOrigin(NSPoint(x: normalisedPoint.x - (getPanelSize() / 2), y: normalisedPoint.y - (getPanelSize() / 2)))
    }
}
