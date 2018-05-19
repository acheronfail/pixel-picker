//
//  PPOverlayPanel.swift
//  PixelPicker
//

// This class is in charge of managing the panels which are brought to the front
// (above other apps) without actually activating PixelPicker itself.
class PPOverlayPanel: NSPanel {
    override var canBecomeKey: Bool {
        get { return true }
    }
    
    override var canBecomeMain: Bool {
        get { return true }
    }
    
    override func awakeFromNib() {
        // `.canJoinAllSpaces` to show on all spaces,
        // `.fullScreenAuxiliary` to show over fullscreen windows.
        self.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        // `.popUpMenu` to show above the Dock and other apps like Alfred.
        self.level = .popUpMenu
        // `.nonactivatingPanel` to activating the panel doesn't activate the app.
        self.styleMask = .nonactivatingPanel
        
        // Tell the OS that if we don't draw in an area, it's not part of the window
        // and clicks should pass through it.
        self.isOpaque = false
        self.backgroundColor = NSColor.clear
        
        // Listen for .mouseMoved events over the window.
        self.acceptsMouseMovedEvents = true
    }
    
    // Activates the panel (makes it key window and orders it to the front), and
    // positions the info panel accordingly.
    func activate(withSize size: CGFloat, infoPanel: PPOverlayPanel) {
        makeKeyAndOrderFront(self)
        setFrame(NSMakeRect(frame.origin.x, frame.origin.y, size + 1, size + 1), display: false)
        addChildWindow(infoPanel, ordered: .above)
        let origin = NSPoint(x: frame.midX + (size / 4), y: frame.midY - (infoPanel.frame.height / 2))
        infoPanel.setFrameOrigin(origin)
    }
}
