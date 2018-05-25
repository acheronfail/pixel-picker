//
//  NSColor.swift
//  PixelPicker
//

import SwiftyJSON

extension NSColor {
    // Convert an NSColor instance to JSON in order to save it to disk.
    static func serialize(_ color: NSColor) -> JSON {
        let export = color.usingColorSpace(.deviceRGB)!
        return [
            "r": export.redComponent,
            "g": export.greenComponent,
            "b": export.blueComponent,
            "a": export.alphaComponent
        ]
    }

    // Create an NSColor instance from JSON.
    static func deserialize(fromJson json: JSON) -> NSColor? {
        if let r = json["r"].float, let g = json["g"].float, let b = json["b"].float, let a = json["a"].float {
            return NSColor(deviceRed: CGFloat(r), green: CGFloat(g), blue: CGFloat(b), alpha: CGFloat(a))
        }

        return nil
    }

    // Creates an NSImage with the given size and color.
    func image(withSize size: NSSize) -> NSImage {
        let image = NSImage(size: size)
        image.lockFocus()
        self.set()
        NSRect(origin: NSPoint.zero, size: size).fill()
        image.unlockFocus()
        return image
    }

    // Returns either black or white, whichever will contrast the most with the given color.
    // See https://stackoverflow.com/a/3943023/5552584
    func bestContrastingColor() -> NSColor {
        let rgb: [CGFloat] = [self.redComponent, self.greenComponent, self.blueComponent].map({
            if $0 <= 0.03928 {
                return $0 / 12.92
            } else {
                return pow(($0 + 0.055) / 1.055, 2.4)
            }
        })

        let L = 0.2126 * rgb[0] + 0.7152 * rgb[1] + 0.0722 * rgb[2];
        return L > 0.197 ? NSColor.black : NSColor.white
    }
}
