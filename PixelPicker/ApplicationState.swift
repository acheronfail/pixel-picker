//
//  Configuration.swift
//  Apptivator
//

import SwiftyJSON
import MASShortcut
import LaunchAtLogin
import CleanroomLogger

@objcMembers class ApplicationState: NSObject {
    // Only one instance of this class should be used at a time.
    static var shared = ApplicationState(atPath: defaultConfigurationPath())

    // Location of our serialised application state.
    let savePath: URL

    // Easier access to the shared instance of MASShortcutMonitor.
    var monitor: MASShortcutMonitor! = MASShortcutMonitor.shared()
    // UserDefaults is used to provide some experimental overrides.
    let defaults: UserDefaults = UserDefaults.standard
    // A Timer to handle the delay between keypresses in a sequence. When this runs out, then the
    // sequence cancels and the user will have to start the sequence from the beginning.
    var timer: Timer?

    // Toggle for dark mode.
    var darkModeEnabled = appleInterfaceStyleIsDark()
    // Whether or not the app should launch after login.
    private var launchAppAtLogin = LaunchAtLogin.isEnabled
    // Don't fire any shortcuts if user is recording a new shortcut.
    private var currentlyRecording = false
    // This is intentionally public and prefixed with "_" because *it should not be used*, except as
    // a workaround for a limitation of MASShortcut. See https://github.com/acheronfail/apptivator/pull/32
    var _currentlyRecording: Bool {
        get { return currentlyRecording }
        set { currentlyRecording = newValue }
    }

    // Whether or not the app is globally enabled.
    private var _isEnabled = true
    var isEnabled: Bool {
        get { return _isEnabled && !currentlyRecording }
        set { _isEnabled = newValue }
    }

    // The list of application -> shortcut mappings. Made private because whenever we need to
    // unregister an entry's shortcuts otherwise its reference count will always be > 0. So we
    // provide helpers to manipulate this array.
    private var entries: [ApplicationEntry] = []

    private init(atPath url: URL) {
        self.savePath = url

        defaults.register(defaults: [
            "leftClickToggles": false,
            "maxShortcutsInSequence": 5,
            "sequentialShortcutDelay": 0.5,
            "matchAppleInterfaceStyle": false,
            "showPopoverOnScreenWithMouse": false
        ])

        // Allow all shortcuts.
        // NOTE: this feature comes from a custom fork of MASShortcut.
        // See https://github.com/acheronfail/MASShortcut/tree/custom
        MASShortcutValidator.shared().allowAnyShortcut = true

        Log.info?.message("ApplicationState initialised at \(url.path)")
    }

    // Get a specific entry at the given index.
    func getEntry(at index: Int) -> ApplicationEntry {
        return entries[index]
    }

    // Return a slice of the entries array.
    func getEntries() -> ArraySlice<ApplicationEntry> {
        return entries[0..<entries.count]
    }

    // Add an entry.
    func addEntry(_ entry: ApplicationEntry) {
        entries.append(entry)
        registerShortcuts()
    }

    // In order for an entry to be cleaned up by ARC, there must be no more references to it.
    // MASShortcutMonitor keeps a reference to the `shortcutValue`, so unregister the shortcut here.
    func removeEntry(at index: Int) {
        let entry = entries.remove(at: index)
        entry.sequence.forEach({ shortcutView in
            if monitor.isShortcutRegistered(shortcutView.shortcutValue) {
                monitor.unregisterShortcut(shortcutView.shortcutValue)
            }
            shortcutView.shortcutValue = nil
        })
        registerShortcuts()
    }

    func sortEntries(comparator: (ApplicationEntry, ApplicationEntry) -> Bool) {
        entries.sort(by: comparator)
    }

    // Disable all shortcuts when the user is recording a shortcut.
    func onRecordingChange<Value>(_ view: MASShortcutView, _ change: NSKeyValueObservedChange<Value>) {
        currentlyRecording = view.isRecording
    }

    // This resets the shortcut state to its initial setting. This should be called whenever a
    // an ApplicationEntry updates its sequence.
    func registerShortcuts() {
        registerShortcuts(atIndex: 0, last: nil)
    }

    // Unregister all previously registered application shortcuts. We can't just use
    // monitor.unregisterAllShortcuts() since that unregisters *all* bindings (even those bound
    // with MASShortcutBinder).
    func unregisterShortcuts() {
        entries.forEach({ entry in
            entry.sequence.forEach({ shortcutView in
                if monitor.isShortcutRegistered(shortcutView.shortcutValue) {
                    monitor.unregisterShortcut(shortcutView.shortcutValue)
                }
            })
        })
    }

    // Only register the shortcuts that are expected.
    // NOTE: Ideally this should be a private function, but we need to expose it here s in order to
    // write tests for its behaviour.
    func registerShortcuts(atIndex index: Int, last: (UInt, UInt)?) {
        guard entries.count > 0 else { return }
        unregisterShortcuts()

        // Bind new shortcuts.
        var count = 0
        entries.forEach({ entry in
            if index < entry.sequence.count {
                let shortcut = entry.sequence[index].shortcutValue!
                // If this is the first shortcut (index == 0) then bind all the first shortcut keys.
                if index == 0 {
                    if !monitor.isShortcutRegistered(shortcut) {
                        monitor.register(shortcut, withAction: { self.keyFired(1, entry, shortcut) })
                        count += 1
                    }
                    return
                }

                // If this is a sequential shortcut (index > 0), then only bind the next shortcuts
                // at the given index, whose previous shortcut was hit.
                let (lastKeyCode, lastModifierFlags) = last!
                let prev = entry.sequence[index - 1].shortcutValue!
                if prev.keyCode == lastKeyCode && prev.modifierFlags == lastModifierFlags {
                    if !monitor.isShortcutRegistered(shortcut) {
                        monitor.register(shortcut, withAction: { self.keyFired(index + 1, entry, shortcut) })
                        count += 1
                    }
                }
            }
        })

        Log.debug?.message("Registered \(count)/\(entries.count) shortcuts at index: \(index), last: \(String(describing: last)).")

        // If this is a sequential shortcut, then start a timer to reset back to the initial state
        // if no other shortcuts were hit.
        if index > 0 {
            let interval = TimeInterval(defaults.float(forKey: "sequentialShortcutDelay"))
            timer = Timer.scheduledTimer(withTimeInterval: interval, repeats: false) { _ in
                self.timer = nil
                self.registerShortcuts(atIndex: 0, last: nil)
                Log.debug?.message("Resetting shortcut state.")
            }
        }
    }

    // This is called when a key is hit in a sequence of shortcuts. If it's the last shortcut, it
    // will activate the app, otherwise it will just advance the sequence along.
    private func keyFired(_ i: Int, _ entry: ApplicationEntry, _ shortcut: MASShortcut) {
        if currentlyRecording { return }
        if i > 0 { timer?.invalidate() }

        // Last shortcut in sequence: apptivate and reset shortcut state.
        if i == entry.sequence.count {
            entry.apptivate()
            registerShortcuts(atIndex: 0, last: nil)
            Log.debug?.message("Apptivating \(entry.name).")
        } else {
            // Advance shortcut state with last shortcut and the number of shortcuts hit.
            let last = (shortcut.keyCode, shortcut.modifierFlags)
            registerShortcuts(atIndex: i, last: last)
        }
    }

    // This checks the given sequences to see if it conflicts with another sequence. Shortcut
    // sequences must have unique prefixes, so that each one can be distinguished from another.
    // See `SequenceViewController.updateUIWith()`.
    func checkForConflictingSequence(_ otherSequence: [MASShortcutView], excluding otherEntry: ApplicationEntry?) -> ApplicationEntry? {
        // It doesn't make sense to call this function with an empty sequence.
        assert(otherSequence.count > 0, "tried to check sequence with count == 0")

        return entries.first(where: { entry in
            if entry.sequence.count == 0 || entry === otherEntry { return false }
            var wasConflict = true
            for (a, b) in zip(otherSequence, entry.sequence) {
                if a.shortcutValue != b.shortcutValue {
                    wasConflict = false
                    break
                }
            }

            return wasConflict
        })
    }

    // Loads the app state (JSON) from disk - if the file exists, otherwise it does nothing.
    func loadFromDisk() {
        // Reset the state before loading from disk.
        _currentlyRecording = false
        _isEnabled = true
        timer = nil
        darkModeEnabled = appleInterfaceStyleIsDark()

        // Unregister shortcuts and remove all entries.
        unregisterShortcuts()
        entries.removeAll()

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

        registerShortcuts()
    }

    func loadFromString(_ jsonString: String) throws {
        if let dataFromString = jsonString.data(using: .utf8, allowLossyConversion: false) {
            let json = try JSON(data: dataFromString)
            for (key, value):(String, JSON) in json {
                switch key {
                case "darkModeEnabled":
                    darkModeEnabled = value.bool ?? false
                case "appIsEnabled":
                    _isEnabled = value.bool ?? true
                case "entries":
                    entries = ApplicationEntry.deserialiseList(fromJSON: value)
                default:
                    Log.warning?.message("unknown key '\(key)' encountered in json")
                }
            }

            if ApplicationState.shared.defaults.bool(forKey: "matchAppleInterfaceStyle") {
                darkModeEnabled = appleInterfaceStyleIsDark()
            }

            Log.info?.message("Loaded config from disk")
        }
    }

    // Saves the app state to disk, creating the parent directories if they don't already exist.
    func saveToDisk() {
        let json: JSON = [
            "appIsEnabled": _isEnabled,
            "darkModeEnabled": darkModeEnabled,
            "entries": ApplicationEntry.serialiseList(entries: getEntries())
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
