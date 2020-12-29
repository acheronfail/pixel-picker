//
//  AppDelegate.swift
//  Pixel Picker
//

import MASShortcut
import CocoaLumberjackSwift

@NSApplicationMain class AppDelegate: NSObject, NSApplicationDelegate {

    // This controller manages the pixel picker itself.
    @IBOutlet weak var overlayController: PPOverlayController!

    // The actual menu bar item.
    var menuBarItem: NSStatusItem! = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    // The menu that drops down from the menu bar item.
    var contextMenu: NSMenu = NSMenu()
    // When the menu bar is opened, we observe the run loop for changes in modifierFlags.
    var runLoopObserver: CFRunLoopObserver? = nil

    // Setup logging and load state.
    func applicationWillFinishLaunching(_ notification: Notification) {
        DDLog.add(DDOSLogger.sharedInstance) // Uses os_log
        let fileLogger: DDFileLogger = DDFileLogger() // File Logger
        dynamicLogLevel = PPState.shared.defaults.bool(forKey: "debugMode") ? .debug : .info
        #if DEBUG
        dynamicLogLevel = .debug
        #endif
        fileLogger.rollingFrequency = 60 * 60 * 24 * 7 // 7 days
        fileLogger.logFileManager.maximumNumberOfLogFiles = 3
        DDLog.add(fileLogger)

        PPState.shared.loadFromDisk()
    }

    // Setup the menubar item and register our activating shortcut.
    func applicationDidFinishLaunching(_ aNotification: Notification) {
        contextMenu.delegate = self

        menuBarItem.image = PPState.shared.statusItemImage(withName: PPState.shared.statusItemImageName)
        menuBarItem.action = #selector(onMenuClick)
        menuBarItem.sendAction(on: [.leftMouseUp, .rightMouseUp])

        registerActivatingShortcut()

        // Set the CGEventSource.localEventsSuppressionInterval to a small interval (default: 250ms)
        // otherwise there'll be a delay when we re-associate the mouse input with the mouse cursor
        // (in the picker) that makes it feel laggy (the suppression interval controls how long
        // hardware events are suppressed after functions like CGWarpMouseCursorPosition are used.
        CGEventSource(stateID: CGEventSourceStateID.combinedSessionState)?.localEventsSuppressionInterval = 0.05

//        Log.info?.message("Sucessfully launched.")
    }

    func applicationWillTerminate(_ aNotification: Notification) {
        PPState.shared.saveToDisk()
    }

    func registerActivatingShortcut() {
        if let shortcut = PPState.shared.activatingShortcut {
            MASShortcutMonitor.shared().register(shortcut, withAction: showPicker)
        }
    }

    func unregisterActivatingShortcut() {
        MASShortcutMonitor.shared().unregisterShortcut(PPState.shared.activatingShortcut)
    }

    @objc func onMenuClick(sender: NSStatusItem) {
        let leftClickToggles = PPState.shared.defaults.bool(forKey: "leftClickActivates")
        let pickerEvent: NSEvent.EventType = leftClickToggles ? .leftMouseUp : .rightMouseUp
        let dropdownEvent: NSEvent.EventType = leftClickToggles ? .rightMouseUp : .leftMouseUp

        let event = NSApp.currentEvent!
        if event.type == dropdownEvent {
            rebuildContextMenu()
            menuBarItem?.popUpMenu(contextMenu)
        } else if event.type == pickerEvent {
            showPicker()
        }
    }

    @objc func showPicker() {
        overlayController.showPicker()
    }

    @objc func showAboutPanel() {
        NSApp.orderFrontStandardAboutPanel()
        NSApp.activate(ignoringOtherApps: true)
    }

    @objc func quitApplication() {
        NSApplication.shared.terminate(self)
    }
}
