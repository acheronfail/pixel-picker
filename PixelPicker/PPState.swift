//
//  PPState.swift
//  PixelPicker
//

import SwiftyJSON
import MASShortcut
import LaunchAtLogin
import CleanroomLogger

@objcMembers class PPState: NSObject {
    // Only one instance of this class should be used at a time.
    static var shared = PPState(atPath: defaultConfigurationPath())

    // Location of our serialised application state.
    let savePath: URL

    // UserDefaults is used to provide some experimental overrides.
    let defaults: UserDefaults = UserDefaults.standard
    
    // Toggle for dark mode.
    var darkModeEnabled = appleInterfaceStyleIsDark()
    // Whether or not the app should launch after login.
    private var launchAppAtLogin = LaunchAtLogin.isEnabled

    private init(atPath url: URL) {
        self.savePath = url

        defaults.register(defaults: [:])
        Log.info?.message("PPState initialised at \(url.path)")
    }

    // Loads the app state (JSON) from disk - if the file exists, otherwise it does nothing.
    func loadFromDisk() {
        darkModeEnabled = appleInterfaceStyleIsDark()

        do {
            let jsonString = try String(contentsOf: savePath, encoding: .utf8)
            try loadFromString(jsonString)
        } catch {
            // Ignore error when there's no file.
            let err = error as NSError
            if err.domain != NSCocoaErrorDomain && err.code != CocoaError.fileReadNoSuchFile.rawValue {
                Log.error?.message("Unexpected error loading application state from disk: \(error)")
            }
        }
    }

    func loadFromString(_ jsonString: String) throws {
        if let dataFromString = jsonString.data(using: .utf8, allowLossyConversion: false) {
            let json = try JSON(data: dataFromString)
            for (key, value):(String, JSON) in json {
                switch key {
                case "darkModeEnabled":
                    darkModeEnabled = value.bool ?? false
                default:
                    Log.warning?.message("unknown key '\(key)' encountered in json")
                }
            }

            if PPState.shared.defaults.bool(forKey: "matchAppleInterfaceStyle") {
                darkModeEnabled = appleInterfaceStyleIsDark()
            }

            Log.info?.message("Loaded config from disk")
        }
    }

    // Saves the app state to disk, creating the parent directories if they don't already exist.
    func saveToDisk() {
        let json: JSON = [
            "darkModeEnabled": darkModeEnabled
        ]
        do {
            if let jsonString = json.rawString() {
                let configDir = savePath.deletingLastPathComponent()
                try FileManager.default.createDirectory(atPath: configDir.path, withIntermediateDirectories: true, attributes: nil)
                try jsonString.write(to: savePath, atomically: false, encoding: .utf8)
                Log.info?.message("Saved config to disk")
            } else {
                Log.error?.message("Could not serialise config")
            }
        } catch {
            Log.error?.message("Unexpected error saving application state to disk: \(error)")
        }
    }
}
