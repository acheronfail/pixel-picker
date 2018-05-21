//
//  PPOverlayPreview.swift
//  PixelPicker
//

// This class is in charge of rendering the pixel preview.
//
// TODO: draw grid b/w pixels when zoomed?
class PPOverlayPreview: NSView, CALayerDelegate {
    // The small pixel-box in the centre of the picker.
    var crosshair: CAShapeLayer = CAShapeLayer()
    
    override var wantsUpdateLayer: Bool {
        get { return true }
    }

    override func awakeFromNib() {
        // Make layers contents resize to fill, and disable antialiasing.
        wantsLayer = true
        layer?.magnificationFilter = kCAFilterNearest
        layer?.contentsGravity = kCAGravityResizeAspectFill
        layer?.delegate = self

        // Prepare crosshair shape layers.
        crosshair.strokeColor = NSColor.black.cgColor
        crosshair.fillColor = nil
        layer?.addSublayer(crosshair)
    }

    // Update the crosshair with the correct color, position and size.
    func updateCrosshair(_ pixelSize: CGFloat, _ middle: CGFloat, _ color: CGColor) {
        let pos: CGFloat = (pixelSize * middle) - (pixelSize / 2)
        let pixelRect = NSMakeRect(pos, pos, pixelSize, pixelSize)
        let outerRect = pixelRect.insetBy(dx: -1, dy: -1)
        
        crosshair.path = CGPath(rect: outerRect, transform: nil)
        crosshair.strokeColor = color
        setNeedsDisplay(outerRect)
    }
}
