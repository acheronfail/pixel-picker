//
//  PPOverlayWrapper.swift
//  PixelPicker
//

class PPOverlayWrapper: NSView {
    
    override var wantsUpdateLayer: Bool {
        get { return true }
    }

    override func awakeFromNib() {
        // TODO: look into drawing a magnifying glass as border
        wantsLayer = true
        layer?.cornerRadius = getPanelSize() / 2
        layer?.backgroundColor = NSColor.white.cgColor
        layer?.borderColor = NSColor.black.cgColor
        layer?.borderWidth = 1
    }
    
    func update(_ color: CGColor) {
        runAnimation({ (context) in
            context.duration = 0.1
            layer?.borderColor = color
        }, done: nil)
    }
}
