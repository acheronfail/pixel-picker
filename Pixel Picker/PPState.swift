//
//  PPState.swift
//  Pixel Picker
//

import SwiftyJSON
import MASShortcut
import LaunchAtLogin
import CocoaLumberjackSwift

// This state class is responsible for saving/loading application state and keeping
// track of the active state and user configuration.
@objcMembers class PPState: NSObject {
    // Only one instance of this class should be used at a time.
    static let shared = PPState(atPath: defaultConfigurationPath())
    
    // The max float precision we support.
    static let maxFloatPrecision = 12

    // Location of our serialised application state.
    let savePath: URL

    // UserDefaults is used to provide some experimental overrides.
    let defaults: UserDefaults = UserDefaults.standard
    
    // Whether the picker should be square or not.
    var paschaModeEnabled: Bool = false
    
    // Whether the color format should be uppercased or not.
    var useUppercase: Bool = false
    
    // Whether to display the WCAG contrast level when picking a color.
    var showWCAGLevel: Bool = false
    
    // The chosen icon for the status item (the icon in the menu bar).
    var statusItemImageName: String = "icon-default"

    // The shortcut that activates the pixel picker.
    var activatingShortcut: MASShortcut?

    // Magnification level of the picker.
    var magnificationLevel: Int = 8

    // When to draw a grid in the preview.
    var gridSetting: GridSetting = .inFocusMode
    
    // Hold this down to enter focus mode.
    var focusModeModifier: NSEvent.ModifierFlags = .control
    
    // The currently chosen format.
    var chosenFormat: PPColor = .genericHex

    // The name of the chosen color space. If this is nil, then the picker will attempt to get the
    // color space of the screen the picker is currently on (and if that fails, fall back to the
    // default color space of the screenshot).
    var colorSpace: String? = nil
    
    // How precise floats should be when copied.
    var floatPrecision: UInt = 3
    
    // Recent colors picks.
    var recentPicks: [PPPickedColor] = []

    private init(atPath url: URL) {
        self.savePath = url
        defaults.register(defaults: [:])
    }
    
    func addRecentPick(_ color: PPPickedColor) {
        while recentPicks.count >= 5 { let _ = recentPicks.removeFirst() }
        recentPicks.append(color)
    }
    
    // Returns the chosen image for the Status Item in the menu bar.
    func statusItemImage(withName name: String) -> NSImage? {
        if let img = NSImage(named: NSImage.Name(stringLiteral: name)) {
            return setupMenuBarIcon(img)
        }

        return setupMenuBarIcon(NSImage(named: NSImage.Name(stringLiteral: "icon-default")))
    }
    
    func changeMagnification(_ n: Int) {
        let level = magnificationLevel + n
        if AppDelegate.MIN_MAGNIFICATION <= level && level <= AppDelegate.MAX_MAGNIFICATION {
            magnificationLevel = level
        }
    }

    /**
     * Below are methods related to saving/loading state from disk.
     */
    
    func resetState() {
        paschaModeEnabled = false
        useUppercase = false
        showWCAGLevel = false
        statusItemImageName = "icon-default"
        focusModeModifier = .control
        activatingShortcut = nil
        chosenFormat = .genericHex
        floatPrecision = 3
        recentPicks = []
    }

    // Loads the app state (JSON) from disk - if the file exists - otherwise it does nothing.
    func loadFromDisk() {
        resetState()
        
        do {
            let jsonString = try String(contentsOf: savePath, encoding: .utf8)
            try loadFromString(jsonString)
        } catch {
            // Ignore error when there's no file.
            let err = error as NSError
            if err.domain != NSCocoaErrorDomain && err.code != CocoaError.fileReadNoSuchFile.rawValue {
                DDLogError("Unexpected error loading application state from disk: \(error)")
            }
        }
    }

    // Load state from a (JSON encoded) string.
    func loadFromString(_ jsonString: String) throws {
        if let dataFromString = jsonString.data(using: .utf8, allowLossyConversion: false) {
            let json = try JSON(data: dataFromString)
            for (key, value):(String, JSON) in json {
                switch key {
                case "paschaModeEnabled":
                    paschaModeEnabled = value.bool ?? false
                case "useUppercase":
                    useUppercase = value.bool ?? false
                case "showWCAGLevel":
                    showWCAGLevel = value.bool ?? false
                case "statusItemImageName":
                    statusItemImageName = value.string ?? "icon-default"
                case "focusModeModifier":
                    focusModeModifier = NSEvent.ModifierFlags(rawValue: value.uInt ?? NSEvent.ModifierFlags.control.rawValue)
                case "activatingShortcut":
                    if let keyCode = value["keyCode"].uInt, let modifierFlags = value["modifierFlags"].uInt {
                        let shortcut = MASShortcut(keyCode: keyCode, modifierFlags: modifierFlags)
                        if MASShortcutValidator.shared().isShortcutValid(shortcut) {
                            activatingShortcut = shortcut
                        }
                    }
                case "colorSpace":
                    // Check for the presence of the color space in our list. If it's found, then we
                    // can use it (safeguard against bogus input).
                    if let _ = PPColor.colorSpaceNames.index(where: { $0.1 == value.string }) {
                        colorSpace = value.string
                    }
                case "chosenFormat":
                    chosenFormat = PPColor(rawValue: value.stringValue) ?? .genericHex
                case "magnificationLevel":
                    magnificationLevel = value.int ?? 8
                case "floatPrecision":
                    let n = value.uInt ?? 3
                    floatPrecision = (n > 0 && n < PPState.maxFloatPrecision) ? n : 3
                case "recentPicks":
                    recentPicks = deserializeRecentPicks(fromJSON: value)
                default:
                    DDLogWarn("unknown key '\(key)' encountered in json")
                    continue
                }
            }
            DDLogInfo("Loaded config from disk")
        }
    }
    
    // Loads seralised recent picks.
    func deserializeRecentPicks(fromJSON jsonValue: JSON) -> [PPPickedColor] {
        var recents: [PPPickedColor] = []
        for (_, pickedColorJson): (String, JSON) in jsonValue {
            if let pickedColor = PPPickedColor(fromJSON: pickedColorJson) {
                recents.append(pickedColor)
            }
        }
        return recents
    }

    // Saves the app state to disk, creating the parent directories if they don't already exist.
    func saveToDisk() {
        var shortcutData: JSON = [:]
        if let shortcut = activatingShortcut {
            shortcutData["keyCode"].uInt = shortcut.keyCode
            shortcutData["modifierFlags"].uInt = shortcut.modifierFlags
        }
        
        let json: JSON = [
            "paschaModeEnabled": paschaModeEnabled,
            "useUppercase": useUppercase,
            "showWCAGLevel": showWCAGLevel,
            "statusItemImageName": statusItemImageName,
            "focusModeModifier": focusModeModifier.rawValue,
            "activatingShortcut": shortcutData,
            "magnificationLevel": magnificationLevel,
            "colorSpace": colorSpace ?? "",
            "chosenFormat": chosenFormat.rawValue,
            "floatPrecision": floatPrecision,
            "recentPicks": recentPicks.map({ $0.asJSON })
        ]
        do {
            if let jsonString = json.rawString([:]) {
                let configDir = savePath.deletingLastPathComponent()
                try FileManager.default.createDirectory(atPath: configDir.path, withIntermediateDirectories: true, attributes: nil)
                try jsonString.write(to: savePath, atomically: false, encoding: .utf8)
                DDLogInfo("Saved config to disk")
            } else {
                DDLogError("Could not serialise config")
            }
        } catch {
            DDLogError("Unexpected error saving application state to disk: \(error)")
        }
    }
}
