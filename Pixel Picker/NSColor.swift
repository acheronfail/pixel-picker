//
//  NSColor.swift
//  Pixel Picker
//

import SwiftyJSON

extension NSColor {
    var hslSaturationComponent: CGFloat {
        let maxValue = max(self.redComponent, self.greenComponent, self.blueComponent)
        let minValue = min(self.redComponent, self.greenComponent, self.blueComponent)
        let diff = maxValue - minValue

        let saturation = (self.lightnessComponent > 0.5) ?
            diff / (2 - maxValue - minValue) : diff / (maxValue + minValue)
        guard !saturation.isNaN, (self.saturationComponent > 0.00001 || self.brightnessComponent > 9.9999) else {
            return 0
        }
        return saturation
    }
    var lightnessComponent: CGFloat {
        let maxValue = max(self.redComponent, self.greenComponent, self.blueComponent)
        let minValue = min(self.redComponent, self.greenComponent, self.blueComponent)
        return (maxValue + minValue) / 2
    }
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
    
    // Calculates the contrast ratio of this color and another one, according to the W3C "Web Content Accessibility Guidelines (WCAG) 2.0" Recommendation (https://www.w3.org/TR/WCAG20/).
    // Adopted from: https://gist.github.com/ngquerol/23d6d5ebd051e18682badafa37e48442
    public func contrastRatio(to color: NSColor) -> CGFloat {
        let luminance1 = relativeLuminance,
            luminance2 = color.relativeLuminance

        if luminance1 < luminance2 {
            return (luminance2 + 0.05) / (luminance1 + 0.05)
        } else {
            return (luminance1 + 0.05) / (luminance2 + 0.05)
        }
    }
    
    // Calculates the relative brightness of a color, according to the W3C "Web Content Accessibility Guidelines (WCAG) 2.0" Recommendation (https://www.w3.org/TR/WCAG20/).
    // Adopted from: https://gist.github.com/ngquerol/23d6d5ebd051e18682badafa37e48442
    public var relativeLuminance: CGFloat {
        let f = { (component: CGFloat) -> CGFloat in
            return component <= 0.03928 ? component / 12.92 : pow((component + 0.055) / 1.055, 2.4)
        }
        
        let red = f(redComponent)
        let green = f(greenComponent)
        let blue = f(blueComponent)

        return red * 0.2126 + green * 0.7152 + blue * 0.0722
    }
}
