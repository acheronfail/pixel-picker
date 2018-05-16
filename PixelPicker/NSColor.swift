//
//  NSColor.swift
//  PixelPicker
//

// TODO: configuration options:
// - custom prefixes "#", or "0x", etc
// - uppercase
// - CSS use W3C color names (?)
// - CSS shorthand version (?)
//
// floating point
// - precision
// - leading zero
// - add suffix?
// - as fractions of integers
//
// whitespace
// - b/w key:<>value pairs
// - b/w comma,<>separated,<>values


enum ColorFormat {
    case genericHex   // 4cbf56
    case generic8bit  // 76, 191, 86
    case genericDecimal // 0.299, 0.751, 0.339
    
    case cssHex // #4cbf56
    case cssRgb // rgb(76, 191, 86)
    case cssRgba // rgba(76, 191, 86, 1)
    case cssHsl // hsl(125, 48%, 52%)
    case cssHsla // hsla(125, 48%, 52%, 1.000)
    
    case swiftNSColorRgb // NSColor(red:0.299, green:0.751, blue:0.339, alpha:1.000)
    case swiftNSColorDeviceRgb // NSColor(deviceRed:0.299, green:0.751, blue:0.339, alpha:1.000)
    case swiftNSColorCalibratedRgb // NSColor(calibratedRed:0.254, green:0.716, blue:0.270, alpha:1.000)
    case swiftNSColorDeviceHsb // NSColor(deviceHue:0.348, saturation:0.602, brightness:0.751, alpha:1.000)
    case swiftNSColorCalibratedHsb // NSColor(calibratedHue:0.339, saturation:0.645, brightness:0.716, alpha:1.000)
    
    case swiftUIColorRgb // UIColor(red:0.299, green:0.751, blue:0.339, alpha:1.000)
    case swiftUIColorHsb // UIColor(hue:0.348, saturation:0.602, brightness:0.751, alpha:1.000)
    
    case objCNSColorRgb // [NSColor colorWithSRGBRed:0.299 green:0.751 blue:0.339 alpha:1.000]
    case objCNSColorDeviceRgb // [NSColor colorWithDeviceRed:0.299 green:0.751 blue:0.339 alpha:1.000]
    case objCNSColorCalibratedRgb // [NSColor colorWithCalibratedRed:0.254 green:0.716 blue:0.270 alpha:1.000]
    case objCNSColorDeviceHsb // [NSColor colorWithDeviceHue:0.348 saturation:0.602 brightness:0.751 alpha:1.000]
    case objCNSColorCalibratedHsb // [NSColor colorWithCalibratedHue:0.339 saturation:0.645 brightness:0.716 alpha:1.000]
    
    case objCUIColorRgb // [UIColor colorWithRed:0.299 green:0.751 blue:0.339 alpha:1.000]
    case objCUIColorHsb // [UIColor colorWithHue:0.348 saturation:0.602 brightness:0.751 alpha:1.000]
    
    case dotNetRgb // Color.FromRgb(76, 191, 86)
    case dotNetArgb // Color.FromArgb(255, 76, 191, 86)
    
    case javaRgb // new Color(76, 191, 86)
    case javaRgba // new Color(76, 191, 86, 255)
    
    case androidRgb // Color.rgb(76, 191, 86)
    case androidArgb // Color.argb(255, 76, 191, 86)
    case androidXmlRgb // <color name="color_name">#4cbf56</color>
    case androidXmlArgb // <color name="color_name">#ff4cbf56</color>
    
    case cgColorRgb // CGColorCreateGenericRGB(0.254, 0.716, 0.270, 1.000)
    
    case openGlRgb // glColor3f(0.299, 0.751, 0.339)
    case openGlRgba // glColor4f(0.299, 0.751, 0.339, 1.000)
}

extension NSColor {
    // TODO: add more export string options
    
    // TODO: check if components are available? See comments https://stackoverflow.com/a/15887762/5552584
    var asHexString: String {
        let r = Int(self.redComponent * 255) << 16
        let g = Int(self.greenComponent * 255) << 8
        let b = Int(self.blueComponent * 255) << 0
        return String(format: "%2X", r | g | b)
    }

    // Returns either black or white, whichever will contrast the most.
    // https://stackoverflow.com/a/3943023/5552584
    func contrastingColor() -> NSColor {
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
