//
//  Util.swift
//  PixelPicker
//

import CleanroomLogger

let APP_NAME = Bundle.main.infoDictionary![kCFBundleNameKey as String] as! String
let APPLE_INTERFACE_STYLE = "AppleInterfaceStyle"

func appleInterfaceStyleIsDark() -> Bool {
    return UserDefaults.standard.string(forKey: APPLE_INTERFACE_STYLE) == "Dark"
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
