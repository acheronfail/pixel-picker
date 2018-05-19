//
//  PPOverlayWrapper.swift
//  PixelPicker
//

// This class is basically the content view of the overlay panel.
// It draws the shape, border and background of the picker.
class PPOverlayWrapper: NSView {
    
    override var wantsUpdateLayer: Bool {
        get { return true }
    }

    override func awakeFromNib() {
        wantsLayer = true
        layer?.backgroundColor = NSColor.white.cgColor
        layer?.borderColor = NSColor.black.cgColor
        layer?.borderWidth = 1
    }
    
    // Provide a smoother transition when changing the border color of the wrapper.
    func update(_ color: CGColor) {
        runAnimation({ (context) in
            context.duration = 0.1
            layer?.borderColor = color
        }, done: nil)
    }
}
