//
//  PPColor.swift
//  PixelPicker
//

import SwiftyJSON

// This allows us to iterate over the raw values of an enum.
// TODO: use `CaseIterable` when Swift 4.2 comes out
func iterateEnum<T: Hashable>(_: T.Type) -> AnyIterator<T> {
    var i = 0
    return AnyIterator {
        let next = withUnsafeBytes(of: &i) { $0.load(as: T.self) }
        if next.hashValue != i { return nil }
        i += 1
        return next
    }
}

// Each time the user picks a pixel we save it as the format and the color.
struct PPPickedColor {
    let color: NSColor
    let format: PPColor
    
    init(color: NSColor, format: PPColor) {
        self.color = color
        self.format = format
    }
    
    init?(fromJSON json: JSON) {
        guard
            let formatString = json["format"].string,
            let format = PPColor(rawValue: formatString),
            let color = NSColor.deserialize(fromJson: json["color"])
            else { return nil }
        
        self.init(color: color, format: format)
    }
    
    var asString: String {
        return format.asString(withColor: color)
    }
    
    var asJSON: JSON {
        return [
            "color": NSColor.serialize(self.color),
            "format": self.format.rawValue
        ]
    }
}

// This enum is responsible for each of the color formats PixelPicker supports,
// as well as being responsible for formatting them as strings, etc.
enum PPColor: String {
    case genericHex                = "Generic Hex"
    case generic8Bit               = "Generic 8-Bit"
    case genericDecimal            = "Generic Decimal"
    case cssHex                    = "CSS Hex"
    case cssRgb                    = "CSS RGB"
    case cssRgba                   = "CSS RGBA"
    case cssHsl                    = "CSS HSL"
    case cssHsla                   = "CSS HSLA"
    case swiftNSColorRgb           = "Swift NSColor RGB"
    case swiftNSColorDeviceRgb     = "Swift NSColor Device RGB"
    case swiftNSColorCalibratedRgb = "Swift NSColor Calibrated RGB"
    case swiftNSColorDeviceHsb     = "Swift NSColor Device HSB"
    case swiftNSColorCalibratedHsb = "Swift NSColor Calibrated HSB"
    case swiftUIColorRgb           = "Swift UI Color RGB"
    case swiftUIColorHsb           = "Swift UI Color HSB"
    case objCNSColorRgb            = "Objective-C NSColor RSB"
    case objCNSColorDeviceRgb      = "Objective-C NSColor Device RSB"
    case objCNSColorCalibratedRgb  = "Objective-C NSColor Calibrated RSB"
    case objCNSColorDeviceHsb      = "Objective-C NSColor Device HSB"
    case objCNSColorCalibratedHsb  = "Objective-C NSColor Calibrated HSB"
    case objCUIColorRgb            = "Objective-C UI Color RGB"
    case objCUIColorHsb            = "Objective-C UI Color HSB"
    case cgColorRgb                = "CGColor RGB"
    case dotNetRgb                 = ".NET RGB"
    case dotNetArgb                = ".NET ARGB"
    case javaRgb                   = "Java RGB"
    case javaRgba                  = "Java RGBA"
    case androidRgb                = "Android RGB"
    case androidArgb               = "Android ARGB"
    case androidXmlRgb             = "Android XML RGB"
    case androidXmlArgb            = "Android XML ARGB"
    case openGlRgb                 = "OpenGL RGB"
    case openGlRgba                = "OpenGL RGBA"

    // Formats the given color as a string.
    func asString(withColor passedColor: NSColor) -> String {
        let f = self.insertFloatPrecisionFormatter
        let c = colorInCorrectColorSpace(passedColor)
        switch self {
        case .genericHex:                return self.formatAsHex(c, "%2X")
        case .generic8Bit:               return self.formatAs8Bit(c, "%u, %u, %u")
        case .genericDecimal:            return self.formatAsDecimal(c, f("%f, %f, %f"), .rgb)
        case .cssHex:                    return self.formatAsHex(c, "#%2X")
        case .cssRgb:                    return self.formatAs8Bit(c, "rgb(%u, %u, %u)")
        case .cssRgba:                   return self.formatAs8Bit(c, "rgba(%u, %u, %u, 1)")
        case .cssHsl:                    return self.formatAsHSL(c, "hsl(%u, %u%%, %u%%)")
        case .cssHsla:                   return self.formatAsHSL(c, "hsla(%u, %u%%, %u%%, 1)")
        case .swiftNSColorRgb:           return self.formatAsDecimal(c, f("NSColor(red: %f, green: %f, blue: %f, alpha: 1.000)"), .rgb)
        case .swiftNSColorDeviceRgb:     return self.formatAsDecimal(c, f("NSColor(deviceRed: %f, green: %f, blue: %f, alpha: 1.000)"), .rgb)
        case .swiftNSColorCalibratedRgb: return self.formatAsDecimal(c, f("NSColor(calibratedRed: %f, green: %f, blue: %f, alpha: 1.000)"), .rgb)
        case .swiftNSColorDeviceHsb:     return self.formatAsDecimal(c, f("NSColor(deviceHue: %f, saturation: %f, brightness: %f, alpha: 1.000)"), .hsb)
        case .swiftNSColorCalibratedHsb: return self.formatAsDecimal(c, f("NSColor(calibratedHue: %f, saturation: %f, brightness: %f, alpha: 1.000)"), .hsb)
        case .swiftUIColorRgb:           return self.formatAsDecimal(c, f("NSColor(red: %f, green: %f, blue: %f, alpha: 1.000)"), .rgb)
        case .swiftUIColorHsb:           return self.formatAsDecimal(c, f("NSColor(hue: %f, saturation: %f, brightness: %f, alpha: 1.000)"), .hsb)
        case .objCNSColorRgb:            return self.formatAsDecimal(c, f("[NSColor colorWithSRGBRed: %f green: %f blue: %f alpha:1.000]"), .rgb)
        case .objCNSColorDeviceRgb:      return self.formatAsDecimal(c, f("[NSColor colorWithDeviceRed: %f green: %f blue: %f alpha:1.000]"), .rgb)
        case .objCNSColorCalibratedRgb:  return self.formatAsDecimal(c, f("[NSColor colorWithCalibratedRed: %f green: %f blue: %f alpha:1.000]"), .rgb)
        case .objCNSColorDeviceHsb:      return self.formatAsDecimal(c, f("[NSColor colorWithDeviceHue: %f saturation: %f brightness: %f alpha:1.000]"), .hsb)
        case .objCNSColorCalibratedHsb:  return self.formatAsDecimal(c, f("[NSColor colorWithCalibratedHue: %f saturation: %f brightness: %f alpha:1.000]"), .hsb)
        case .objCUIColorRgb:            return self.formatAsDecimal(c, f("[UIColor colorWithRed: %f green: %f blue: %f alpha:1.000]"), .rgb)
        case .objCUIColorHsb:            return self.formatAsDecimal(c, f("[UIColor colorWithHue: %f saturation: %f brightness: %f alpha:1.000]"), .hsb)
        case .dotNetRgb:                 return self.formatAs8Bit(c, "Color.FromRgb(%u, %u, %u)")
        case .dotNetArgb:                return self.formatAs8Bit(c, "Color.FromArgb(255, %u, %u, %u)")
        case .javaRgb:                   return self.formatAs8Bit(c, "new Color(%u, %u, %u)")
        case .javaRgba:                  return self.formatAs8Bit(c, "new Color(%u, %u, %u, 255)")
        case .androidRgb:                return self.formatAs8Bit(c, "Color.rgb(%u, %u, %u)")
        case .androidArgb:               return self.formatAs8Bit(c, "Color.argb(255, %u, %u, %u)")
        case .androidXmlRgb:             return self.formatAsHex(c, "<color name=\"color_name\">#%2X</color>")
        case .androidXmlArgb:            return self.formatAsHex(c, "<color name=\"color_name\">#ff%2X</color>")
        case .cgColorRgb:                return self.formatAsDecimal(c, f("CGColorCreateGenericRGB(%f, %f, %f, 1.000)"), .rgb)
        case .openGlRgb:                 return self.formatAsDecimal(c, f("glColor3f(%f, %f, %f)"), .rgb)
        case .openGlRgba:                return self.formatAsDecimal(c, f("glColor4f(%f, %f, %f, 1.000)"), .rgb)
        }
    }

    // This is used to return a simple representation of the color (used as a preview in the info panel).
    func asComponentString(withColor passedColor: NSColor) -> String {
        let color = colorInCorrectColorSpace(passedColor)
        switch self {
        // Hexadecimal-like formats.
        case .cssHex:                    fallthrough
        case .androidXmlRgb:             fallthrough
        case .androidXmlArgb:            fallthrough
        case .cgColorRgb:                fallthrough
        case .genericHex:                return self.formatAsHex(color, "%2X")
        // CSS HSL is a unique format.
        case .cssHsl:                    fallthrough
        case .cssHsla:                   return self.formatAsHSL(color, "%u, %u%%, %u%%")
        // 8-bit-like formats.
        case .cssRgb:                    fallthrough
        case .cssRgba:                   fallthrough
        case .dotNetRgb:                 fallthrough
        case .dotNetArgb:                fallthrough
        case .javaRgb:                   fallthrough
        case .javaRgba:                  fallthrough
        case .androidRgb:                fallthrough
        case .androidArgb:               fallthrough
        case .generic8Bit:               return self.formatAs8Bit(color, "%u, %u, %u")
        // Decimal-like formats.
        case .swiftNSColorRgb:           fallthrough
        case .swiftNSColorDeviceRgb:     fallthrough
        case .swiftNSColorCalibratedRgb: fallthrough
        case .swiftUIColorRgb:           fallthrough
        case .objCNSColorRgb:            fallthrough
        case .objCNSColorDeviceRgb:      fallthrough
        case .objCNSColorCalibratedRgb:  fallthrough
        case .objCUIColorRgb:            fallthrough
        case .openGlRgb:                 fallthrough
        case .openGlRgba:                fallthrough
        case .genericDecimal:            fallthrough
        case .swiftNSColorDeviceHsb:     fallthrough
        case .swiftNSColorCalibratedHsb: fallthrough
        case .swiftUIColorHsb:           fallthrough
        case .objCNSColorDeviceHsb:      fallthrough
        case .objCNSColorCalibratedHsb:  fallthrough
        case .objCUIColorHsb:            return self.formatAsDecimal(color, self.insertFloatPrecisionFormatter("%f, %f, %f"), .rgb)
        }
    }
    
    // A tiny enum that describes which components should be used when formatting.
    private enum Components {
        case rgb
        case hsb
    }
    
    // Replaces "%f" with "%.3f" (if "3" is the current precision level).
    private func insertFloatPrecisionFormatter(_ input: String) -> String {
        return input.replacingOccurrences(of: "%f", with: String(format: "%%.%uf", PPState.shared.floatPrecision))
    }
    
    // Formats the colors as a hex value, eg: "D3504E".
    private func formatAsHex(_ color: NSColor, _ template: String) -> String {
        let a = Int(color.redComponent * 255) << 16
        let b = Int(color.greenComponent * 255) << 8
        let c = Int(color.blueComponent * 255) << 0
        return String(format: template, a | b | c)
    }
    
    // Formats the color as decimal values, eg: "0.145, 0.361, 0.722".
    private func formatAsDecimal(_ color: NSColor, _ template: String, _ cmp: Components) -> String {
        let a = cmp == .rgb ? color.redComponent   : color.hueComponent
        let b = cmp == .rgb ? color.greenComponent : color.saturationComponent
        let c = cmp == .rgb ? color.blueComponent  : color.brightnessComponent
        return String(format: template, a, b, c)
    }
    
    // Formats the color as 8-bit values, eg: "158, 198, 117".
    private func formatAs8Bit(_ color: NSColor, _ template: String) -> String {
        let a = Int(color.redComponent * 255)
        let b = Int(color.greenComponent * 255)
        let c = Int(color.blueComponent * 255)
        return String(format: template, a, b, c)
    }
    
    // Special formatter since CSS uses a unique style here, eg: "35, 79%, 47%".
    private func formatAsHSL(_ color: NSColor, _ template: String) -> String {
        let a = Int(color.hueComponent * 360)
        let b = Int(color.saturationComponent * 100)
        let c = Int(color.brightnessComponent * 100)
        return String(format: template, a, b, c)
    }
    
    // Returns a new color in the correct colorspace for the format.
    private func colorInCorrectColorSpace(_ color: NSColor) -> NSColor {
        switch self {
        case .objCNSColorCalibratedHsb: fallthrough
        case .objCNSColorCalibratedRgb: fallthrough
        case .swiftNSColorCalibratedHsb: fallthrough
        case .swiftNSColorCalibratedRgb:
            return color.usingColorSpaceName(.calibratedRGB) ?? color
        case .objCNSColorDeviceHsb: fallthrough
        case .objCNSColorDeviceRgb: fallthrough
        case .swiftNSColorDeviceHsb: fallthrough
        case .swiftNSColorDeviceRgb:
            return color.usingColorSpaceName(.deviceRGB) ?? color
        default:
            return color
        }
    }
}
