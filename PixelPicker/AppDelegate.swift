//
//  AppDelegate.swift
//  PixelPicker
//

import SwiftyJSON
import CleanroomLogger

let ICON = setupMenuBarIcon(NSImage(named: NSImage.Name(rawValue: "icon")))

@NSApplicationMain class AppDelegate: NSObject, NSApplicationDelegate {

    @IBOutlet weak var panel: NSPanel!
    var panelController: PPOverlayController!
    
    private var contextMenu: NSMenu = NSMenu()
    private var menuBarItem: NSStatusItem! = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    
    func applicationWillFinishLaunching(_ notification: Notification) {
        let minimumSeverity: LogSeverity = PPState.shared.defaults.bool(forKey: "debugMode") ? .debug : .info
        var logConfigurations: [LogConfiguration] = [
            RotatingLogFileConfiguration(minimumSeverity: minimumSeverity, daysToKeep: 7, directoryPath: defaultLogPath().path)
        ]
        #if DEBUG
        logConfigurations.append(XcodeLogConfiguration(minimumSeverity: .debug))
        #endif
        Log.enable(configuration: logConfigurations)
        PPState.shared.loadFromDisk()
    }

    func applicationDidFinishLaunching(_ aNotification: Notification) {
        panelController = (panel.windowController as? PPOverlayController)!

        contextMenu.addItem(NSMenuItem(title: "Settings", action: #selector(showSettingsWindow), keyEquivalent: ""))
        contextMenu.addItem(NSMenuItem.separator())
        contextMenu.addItem(NSMenuItem(title: "About", action: #selector(showAboutPanel), keyEquivalent: ""))
        contextMenu.addItem(NSMenuItem.separator())
        contextMenu.addItem(NSMenuItem(title: "Quit \(APP_NAME)", action: #selector(quitApplication), keyEquivalent: ""))

        menuBarItem.image = ICON
        menuBarItem.action = #selector(onMenuClick)
        menuBarItem.sendAction(on: [.leftMouseUp, .rightMouseUp])
        
        // TODO: set this from settings window
        let shortcut = MASShortcut(keyCode: 0, modifierFlags: 1179648)
        MASShortcutMonitor.shared().register(shortcut, withAction: {
            self.panelController.show()
        })

        Log.info?.message("Sucessfully launched.")
    }

    func applicationWillTerminate(_ aNotification: Notification) {
        PPState.shared.saveToDisk()
    }
    
    @objc func showSettingsWindow(_ sender: Any?) {
        // TODO: make a settings window
    }

    @objc func onMenuClick(sender: NSStatusItem) {
        let event = NSApp.currentEvent!
        if event.type == .leftMouseUp {
            menuBarItem?.popUpMenu(contextMenu)
        } else if event.type == .rightMouseUp {
            Log.debug?.message("right click")
        }
    }

    @objc func showAboutPanel() {
        NSApp.orderFrontStandardAboutPanel()
        NSApplication.shared.activate(ignoringOtherApps: true)
    }

    @objc func quitApplication() {
        NSApplication.shared.terminate(self)
    }
}
