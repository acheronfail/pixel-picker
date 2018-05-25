//
//  PPOverlayPreview.swift
//  PixelPicker
//

// This class is in charge of rendering the pixel preview.
class PPOverlayPreview: NSView, CALayerDelegate {
    // A grid that's optionally shown in the preview.
    private var grid: CAShapeLayer = CAShapeLayer()
    private var lastCellSize: CGFloat?
    private var lastNumberOfCells: Int?

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

        grid.strokeColor = NSColor.gray.cgColor
        grid.fillColor = nil
        layer?.addSublayer(grid)
    }

    // Update the crosshair with the correct color, position and size.
    func updateCrosshair(_ pixelSize: CGFloat, _ middle: CGFloat, _ color: CGColor) {
        let pos: CGFloat = (pixelSize * middle) - (pixelSize / 2)
        let pixelRect = NSMakeRect(pos, pos, pixelSize, pixelSize)
        
        crosshair.path = CGPath(rect: pixelRect, transform: nil)
        crosshair.strokeColor = color
        setNeedsDisplay(pixelRect)
    }

    // Redraws the grid in the preview.
    func updateGrid(cellSize size: CGFloat, numberOfCells n: Int, shouldDisplay: Bool) {
        // Disable implicit animations within this transaction.
        CATransaction.setDisableActions(true)
        grid.opacity = shouldDisplay ? 0.25 : 0

        // Only redraw the grid if we need to display it and the dimensions have changed since last
        // the last time we drew it.
        guard shouldDisplay && (size != lastCellSize || n != lastNumberOfCells) else { return }
        lastCellSize = size
        lastNumberOfCells = n

        let path = NSBezierPath()
        let start = CGFloat(0)
        let end = CGFloat(n) * size

        for i in 1..<n {
            let pos = CGFloat(i) * size
            path.move(to: NSPoint(x: pos, y: start))
            path.line(to: NSPoint(x: pos, y: end))
            path.move(to: NSPoint(x: start, y: pos))
            path.line(to: NSPoint(x: end, y: pos))
        }

        grid.path = path.cgPath
    }
}

// Extend NSBezierPath to allow easy conversion to a CGPath.
// https://developer.apple.com/library/content/documentation/Cocoa/Conceptual/CocoaDrawingGuide/Paths/Paths.html#//apple_ref/doc/uid/TP40003290-CH206-SW2
extension NSBezierPath {
    var cgPath: CGPath {
        let path = CGMutablePath()
        var points = [CGPoint](repeating: .zero, count: 3)
        for i in 0 ..< self.elementCount {
            switch self.element(at: i, associatedPoints: &points) {
            case .moveToBezierPathElement: path.move(to: points[0])
            case .lineToBezierPathElement: path.addLine(to: points[0])
            case .curveToBezierPathElement: path.addCurve(to: points[2], control1: points[0], control2: points[1])
            case .closePathBezierPathElement: path.closeSubpath()
            }
        }
        return path
    }
}
