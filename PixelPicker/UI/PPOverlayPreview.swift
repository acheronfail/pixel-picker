//
//  PPOverlayPreview.swift
//  PixelPicker
//

class PPOverlayPreview: NSView, CALayerDelegate {
    
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
    
    func updateCrosshair(_ nPixels: CGFloat, _ middle: CGFloat, _ color: CGColor) {
        let squareSize = getPanelSize() / nPixels
        
        let pos: CGFloat = (squareSize * middle) - (squareSize / 2)
        let pixelRect = NSMakeRect(pos, pos, squareSize, squareSize)
        let outerRect = pixelRect.insetBy(dx: -1, dy: -1)
        
        crosshair.path = CGPath(rect: outerRect, transform: nil)
        crosshair.strokeColor = color
        setNeedsDisplay(outerRect)
    }
}
