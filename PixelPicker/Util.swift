//
//  Util.swift
//  PixelPicker
//

import CleanroomLogger

let APP_NAME = Bundle.main.infoDictionary![kCFBundleNameKey as String] as! String
let APPLE_INTERFACE_STYLE = "AppleInterfaceStyle"

// Copies the given string to the clipboard.
func copyToPasteboard(stringValue value: String) {
    NSPasteboard.general.declareTypes([.string], owner: nil)
    NSPasteboard.general.setString(value, forType: .string)
}

// Ensure that the given number is odd.
func ensureOdd(_ x: CGFloat) -> CGFloat {
    if Int(x) % 2 == 0 { return x + 1 }
    return x
}

// Checks whether a float roughly ends in ".5".
func isHalf(_ x: CGFloat) -> Bool {
    return Int(x * 2) % 2 != 0
}

// The Cocoa APIs have a coordinate system (origin is top-left of the screen) but the
// Carbon/CoreGraphics APIs use an old coordinate system where the origin is the
// bottom-left corner *of the primary display*.
// The primary display is always the first item of the NSScreen.screens array.
func convertToCGCoordinateSystem(_ point: NSPoint) -> CGPoint {
    return CGPoint(x: point.x, y: NSScreen.screens[0].frame.size.height - point.y)
}

// Returns the screen which contains the mouse cursor.
func getScreenFromPoint(_ point: NSPoint) -> NSScreen? {
    return NSScreen.screens.first { NSMouseInRect(point, $0.frame, false) }
}

// A simple helper to run animations with the same context configration.
func runAnimation(_ f: (NSAnimationContext) -> Void, done: (() -> Void)?) {
    NSAnimationContext.runAnimationGroup({ context in
        context.duration = 0.5
        context.timingFunction = .init(name: kCAMediaTimingFunctionEaseInEaseOut)
        context.allowsImplicitAnimation = true
        f(context)
    }, completionHandler: done)
}

// Make menu bar images templates with 16x16 dimensions.
func setupMenuBarIcon(_ image: NSImage?) -> NSImage? {
    image?.isTemplate = true
    image?.size = NSSize(width: 16, height: 16)
    return image
}

// When running tests, use a temporary logging path.
func defaultLogPath() -> URL {
    var url: URL
    if ProcessInfo.processInfo.environment["TEST"] != nil {
        url = URL(fileURLWithPath: "\(NSTemporaryDirectory())\(APP_NAME)-\(UUID().uuidString)-logs/")
    } else {
        url = URL(fileURLWithPath: "\(NSHomeDirectory())/Library/Preferences/\(APP_NAME)/logs")
    }

    // Create directory if it doesn't already exist.
    do {
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true, attributes: nil)
    } catch {
        Log.error?.message("Unexpected error creating log directory: \(error)")
    }

    Log.info?.message("Default Log Path: \(url.path)")
    return url
}

// When running tests, use a temporary config file.
func defaultConfigurationPath() -> URL {
    var url: URL
    if ProcessInfo.processInfo.environment["TEST"] != nil {
        url = URL(fileURLWithPath: "\(NSTemporaryDirectory())\(APP_NAME)-\(UUID().uuidString).json")
    } else {
        url = URL(fileURLWithPath: "\(NSHomeDirectory())/Library/Preferences/\(APP_NAME)/configuration.json")
    }

    Log.info?.message("Default Config Path: \(url.path)")
    return url
}
