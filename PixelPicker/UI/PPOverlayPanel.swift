//
//  PPOverlayPanel.swift
//  PixelPicker
//

var PANEL_SIZE: CGFloat = 200
var hPANEL_SIZE = PANEL_SIZE / 2

func getPanelSize() -> CGFloat {
   return PANEL_SIZE
}
func setPanelSize(_ newSize: CGFloat) {
    PANEL_SIZE = newSize
}

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
    
    // Reset the dimensions of the panel each time it's activated.
    override func makeKeyAndOrderFront(_ sender: Any?) {
        super.makeKeyAndOrderFront(sender)
        setFrame(NSMakeRect(frame.origin.x, frame.origin.y, getPanelSize() + 1, getPanelSize() + 1), display: false)
    }
    
    // ...
    func activate(withInfoPanel infoPanel: PPOverlayPanel) {
        makeKeyAndOrderFront(self)
        addChildWindow(infoPanel, ordered: .above)
        let origin = NSPoint(x: frame.midX + (getPanelSize() / 4), y: frame.midY - (infoPanel.frame.height / 2))
        infoPanel.setFrameOrigin(origin)
    }
}
