//
//  AppDelegate.swift
//  Apptivator
//

import SwiftyJSON
import CleanroomLogger

let ENABLED_INDICATOR_ON = "\(APP_NAME): on"
let ENABLED_INDICATOR_OFF = "\(APP_NAME): off"
let ICON_ON = setupMenuBarIcon(NSImage(named: NSImage.Name(rawValue: "icon-on")))
let ICON_OFF = setupMenuBarIcon(NSImage(named: NSImage.Name(rawValue: "icon-off")))

@NSApplicationMain class AppDelegate: NSObject, NSApplicationDelegate {
    @IBOutlet weak var popover: NSPopover!
    @IBOutlet weak var popoverViewController: PopoverViewController!

    private var contextMenu: NSMenu = NSMenu()
    private var menuBarItem: NSStatusItem! = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    private let enabledIndicator = NSMenuItem(title: ENABLED_INDICATOR_OFF, action: nil, keyEquivalent: "")

    // The window must be at least 1x1 pixel in order for it to be drawn on the screen.
    // See @togglePreferencesPopover for why an invisible window exists.
    private let invisibleWindow = NSWindow(contentRect: NSMakeRect(0, 0, 1, 1), styleMask: .borderless, backing: .buffered, defer: false)

    func applicationWillFinishLaunching(_ notification: Notification) {
        let minimumSeverity: LogSeverity = ApplicationState.shared.defaults.bool(forKey: "debugMode") ? .debug : .info
        var logConfigurations: [LogConfiguration] = [
            RotatingLogFileConfiguration(minimumSeverity: minimumSeverity, daysToKeep: 7, directoryPath: defaultLogPath().path)
        ]
        #if DEBUG
        logConfigurations.append(XcodeLogConfiguration(minimumSeverity: .debug))
        #endif
        Log.enable(configuration: logConfigurations)
        ApplicationState.shared.loadFromDisk()
    }

    func applicationDidFinishLaunching(_ aNotification: Notification) {
        popover.delegate = self
        contextMenu.delegate = self
        contextMenu.autoenablesItems = false
        enabledIndicator.isEnabled = false

        invisibleWindow.alphaValue = 0
        invisibleWindow.hidesOnDeactivate = true
        invisibleWindow.collectionBehavior = .canJoinAllSpaces

        menuBarItem.image = ICON_OFF
        menuBarItem.action = #selector(onMenuClick)
        menuBarItem.sendAction(on: [.leftMouseUp, .rightMouseUp])

        enable(ApplicationState.shared.isEnabled)
        popoverViewController.reloadView()

        // Check for accessibility permissions.
        if !UIElement.isProcessTrusted(withPrompt: true) {
            Log.info?.message("Application does not have Accessibility Permissions, requesting...")
            let alert = NSAlert()
            alert.messageText = "Action Required"
            alert.informativeText = """
            \(APP_NAME) requires access to the accessibility API in order to hide/show other application's windows.\n
            Please open System Preferences and allow \(APP_NAME) access.\n
            System Preferences -> Security & Privacy -> Privacy
            """
            alert.alertStyle = .warning
            alert.runModal()
        }

        Log.info?.message("Sucessfully launched.")
    }

    func applicationWillTerminate(_ aNotification: Notification) {
        ApplicationState.shared.saveToDisk()
    }

    func enable(_ flag: Bool) {
        ApplicationState.shared.isEnabled = flag
        menuBarItem?.image = flag ? ICON_ON : ICON_OFF
        enabledIndicator.title = flag ? ENABLED_INDICATOR_ON : ENABLED_INDICATOR_OFF
    }

    @objc func onMenuClick(sender: NSStatusItem) {
        let leftClickToggles = ApplicationState.shared.defaults.bool(forKey: "leftClickToggles")
        let toggleEvent: NSEvent.EventType = leftClickToggles ? .leftMouseUp : .rightMouseUp
        let dropdownEvent: NSEvent.EventType = leftClickToggles ? .rightMouseUp : .leftMouseUp

        let event = NSApp.currentEvent!
        if event.type == dropdownEvent {
            buildContextMenu(ApplicationState.shared.getEntries())
            menuBarItem?.popUpMenu(contextMenu)
        } else if event.type == toggleEvent {
            enable(!ApplicationState.shared.isEnabled)
        }
    }

    @objc func showAboutPanel() {
        NSApp.orderFrontStandardAboutPanel()
        NSApplication.shared.activate(ignoringOtherApps: true)
    }

    // NSPopovers will follow the view they are relative to, even if it moves. Apps like Bartender
    // that control the menubar can move the menu bar item, which moves and janks the popover
    // around. We get around this by attaching it to a tiny, invisible window whose location we
    // can control.
    @objc func togglePreferencesPopover() {
        if popover.isShown {
            popover.performClose(nil)
        } else {
            // Get the screen coords of the menu bar item's current location.
            let menuBarButton = menuBarItem.button!
            let buttonBounds = menuBarButton.convert(menuBarButton.bounds, to: nil)
            let screenBounds = menuBarButton.window!.convertToScreen(buttonBounds)

            var xPosition: CGFloat
            if ApplicationState.shared.defaults.bool(forKey: "showPopoverOnScreenWithMouse"), let screen = getScreenWithMouse() {
                xPosition = screen.frame.origin.x + screen.frame.width - 1
            } else {
                // Account for Bartender moving the menu bar item offscreen. If the midpoint doesn't
                // seem to be on the main screen, then place the popover in the top-right corner.
                let screenFrame = NSScreen.main!.frame
                xPosition = screenBounds.midX
                if abs(xPosition) > screenFrame.width {
                    xPosition = screenFrame.origin.x + screenFrame.width - 1
                }
            }

            // Move the window to the coords, and activate the popover on the window.
            invisibleWindow.setFrameOrigin(NSPoint(x: xPosition, y: screenBounds.origin.y))
            invisibleWindow.makeKeyAndOrderFront(nil)
            popover.show(relativeTo: invisibleWindow.contentView!.frame, of: invisibleWindow.contentView!, preferredEdge: NSRectEdge.minY)
            NSApp.activate(ignoringOtherApps: true)
        }
    }

    @objc func quitApplication() {
        NSApplication.shared.terminate(self)
    }
}

extension AppDelegate: NSMenuDelegate {
    func buildContextMenu(_ entries: ArraySlice<ApplicationEntry>) {
        contextMenu.addItem(enabledIndicator)
        contextMenu.addItem(NSMenuItem(title: "Configure Shortcuts", action: #selector(togglePreferencesPopover), keyEquivalent: ""))
        contextMenu.addItem(NSMenuItem.separator())
        contextMenu.addItem(NSMenuItem(title: "About", action: #selector(showAboutPanel), keyEquivalent: ""))
        contextMenu.addItem(NSMenuItem.separator())
        contextMenu.addItem(NSMenuItem(title: "Active applications", action: nil, keyEquivalent: ""))
        contextMenu.item(at: contextMenu.numberOfItems - 1)?.isEnabled = false

        // HACK: Having custom text for a NSMenuItem's `keyEquivalent` is unnecessarily difficult.
        // You can't change the text, and getting custom views to appear native is practically impossible.

        // Below is a hacky but effective 4-step remedy (inspired by Sublime Text's implementation).
        // See https://forum.sublimetext.com/t/q-how-does-sublime-create-a-custom-keyequivalent-string-in-its-menu/36825?u=acheronfail

        // 1: We need the width of the longest title (the text on the left of the NSMenuItem).
        // The added `80` is the margins of the NSMenuItem, the image, plus some inner padding.
        let maxWidth: CGFloat = entries.reduce(0, { max($0, ($1.name as NSString).size(withAttributes: [.font: contextMenu.font]).width + 80) })
        for entry in entries {
            // Here we try and attach an observer there isn't already one.
            if !entry.isActive { entry.createObserver(findRunningApp(withURL: entry.url)) }
            if entry.isActive {
                let menuItem = NSMenuItem(title: "", action: #selector(apptivate(_:)), keyEquivalent: "")
                menuItem.image = entry.icon.copy() as? NSImage
                menuItem.image?.size = NSSize(width: 20, height: 20)
                menuItem.representedObject = entry

                // 2: Separate the title, and our "keyEquivalent" text with a tab. Make sure that there aren't any extra tabs.
                let title = "\(entry.name.replacingOccurrences(of: "\t", with: ""))\t\(entry.shortcutString ?? "")"
                // 3: Create a left-aligned paragraph and use left-aligned tabStops with a long enough stop location (with width from earlier).
                let paragraph = NSMutableParagraphStyle.init()
                paragraph.alignment = .left
                paragraph.tabStops = [NSTextTab.init(textAlignment: .left, location: maxWidth, options: [:])]
                // 4: Set the NSMenuItem's title to an attributed string with the paragraph attribute we just created.
                menuItem.attributedTitle = NSMutableAttributedString.init(string: title, attributes: [.paragraphStyle: paragraph])

                contextMenu.addItem(menuItem)
            }
        }

        contextMenu.addItem(NSMenuItem.separator())
        contextMenu.addItem(NSMenuItem(title: "Quit \(APP_NAME)", action: #selector(quitApplication), keyEquivalent: ""))
    }

    @objc func apptivate(_ sender: Any) {
        if let menuItem = sender as? NSMenuItem {
            (menuItem.representedObject as? ApplicationEntry)?.apptivate()
        }
    }

    func menuDidClose(_ menu: NSMenu) {
        contextMenu.removeAllItems()
    }
}

extension AppDelegate: NSPopoverDelegate {
    // Allows the user to click + drag to move the popover around, where it can become a separate,
    // persistent window.
    func popoverShouldDetach(_ popover: NSPopover) -> Bool {
        return true
    }
}
