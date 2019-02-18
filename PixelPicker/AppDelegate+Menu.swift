//
//  AppDelegate+Menu.swift
//  PixelPicker
//

/**
 * This file is responsible for managing PixelPicker's dropdown menu when
 * the user clicks on the status bar item.
 */

import LaunchAtLogin

// The settings available for displaying a grid in the picker's preview.
enum GridSetting {
    case never, always, inFocusMode
    static let withNames: [(String, GridSetting)] = [
        ("Only in Focus Mode", .inFocusMode),
        ("Always", .always),
        ("Never", .never)
    ]
}

// The modifiers available to use to toggle "focusMode".
let focusModifiers: [(String, NSEvent.ModifierFlags)] = [
    ("fn Function", .function),
    ("⌘ Command", .command),
    ("⌃ Control", .control),
    ("⌥ Option", .option),
    ("⇧ Shift ", .shift)
]

// The available status item images that the user may pick from.
let statusItemImages: [(String, String)] =  [
    ("Magnifying Glass (Default)", "icon-default"),
    ("Palette", "icon-palette"),
    ("Dropper", "icon-dropper"),
    ("Magnifying Glass Dropper", "icon-mag-dropper"),
    ("Magnifying Glass Dropper Flat", "icon-mag-dropper-flat")
]

extension AppDelegate: NSMenuDelegate {
    // Unregister the activating shortcut when the menu is opened/closed so it can't be called when
    // setting a new shortcut. Also start a run loop observer so we know when the modifierFlags have
    // changed (used to dynamically update the menu).
    func menuWillOpen(_ menu: NSMenu) {
        unregisterActivatingShortcut()
        if runLoopObserver == nil {
            let activites = CFRunLoopActivity.beforeWaiting.rawValue
            runLoopObserver = CFRunLoopObserverCreateWithHandler(nil, activites, true, 0, { [unowned self] (_, _) in
                self.updateMenuItems()
            })
            CFRunLoopAddObserver(CFRunLoopGetCurrent(), runLoopObserver, CFRunLoopMode.commonModes)
        }
    }

    // Re-register the activating shortcut, and remove the run loop observer.
    func menuDidClose(_ menu: NSMenu) {
        registerActivatingShortcut()
        if (runLoopObserver != nil) {
            CFRunLoopObserverInvalidate(runLoopObserver)
            runLoopObserver = nil
        }
    }

    // Updates the titles of the recently picked colors - if the `option` key is pressed, then
    // the colors will be in the format they were *when* they were picked, otherwise they'll be
    // in the currently chosen format.
    private func updateMenuItems() {
        // Update recent picks list with correct titles.
        let alternate = NSEvent.modifierFlags.contains(.option)
        for item in contextMenu.items {
            if let pickedColor = item.representedObject as? PPPickedColor {
                item.title = alternate
                    ? pickedColor.asString
                    : PPState.shared.chosenFormat.asString(withColor: pickedColor.color)
            }
        }
    }

    // This rebuilds the context menu from scratch. For the sake of simplicity, we re-create the
    // menu from scratch each time. It's not an expensive operation, and is only called when the
    // user opens the menu.
    func rebuildContextMenu() {
        contextMenu.removeAllItems()

        let pickItem = contextMenu.addItem(withTitle: "Pick a pixel!", action: #selector(showPicker), keyEquivalent: "")
        pickItem.image = PPState.shared.statusItemImage(withName: PPState.shared.statusItemImageName)

        buildRecentPicks()

        contextMenu.addItem(.separator())
        buildAppIconMenu()
        buildShowGridMenu()
        buildColorSpaceItem()
        buildColorFormatsMenu()
        buildMagnificationMenu()
        buildFocusModeModifierMenu()
        buildFloatPrecisionSlider()
        buildShortcutMenuItem()
        buildUseUppercaseItem()
        buildLaunchAtLoginItem()

        contextMenu.addItem(.separator())
        contextMenu.addItem(withTitle: "About", action: #selector(showAboutPanel), keyEquivalent: "")
        contextMenu.addItem(withTitle: "Quit \(APP_NAME)", action: #selector(quitApplication), keyEquivalent: "")
    }

    // Choose the status item icon.
    private func buildAppIconMenu() {
        let submenu = NSMenu()
        for (name, imageName) in statusItemImages {
            let item = submenu.addItem(withTitle: name, action: #selector(selectAppIcon(_:)), keyEquivalent: "")
            item.representedObject = imageName
            item.state = PPState.shared.statusItemImageName == imageName ? .on : .off
            item.image = PPState.shared.statusItemImage(withName: imageName)
        }

        let item = contextMenu.addItem(withTitle: "App Icon", action: nil, keyEquivalent: "")
        item.submenu = submenu
    }

    @objc private func selectAppIcon(_ sender: NSMenuItem) {
        if let imageName = sender.representedObject as? String {
            menuBarItem.image = PPState.shared.statusItemImage(withName: imageName)
            PPState.shared.statusItemImageName = imageName
        }
    }

    // Choose whether to always draw a grid, never draw one, or only draw one when in focus mode.
    private func buildShowGridMenu() {
        let submenu = NSMenu()
        for (title, setting) in GridSetting.withNames {
            let item = submenu.addItem(withTitle: title, action: #selector(selectGridSetting(_:)), keyEquivalent: "")
            item.representedObject = setting
            item.state = PPState.shared.gridSetting == setting ? .on : .off
        }

        let item = contextMenu.addItem(withTitle: "Show Grid", action: nil, keyEquivalent: "")
        item.submenu = submenu
    }

    @objc private func selectGridSetting(_ sender: NSMenuItem) {
        if let setting = sender.representedObject as? GridSetting {
            PPState.shared.gridSetting = setting
        }
    }

    // A menu that allows choosing what color space the picker will use.
    private func buildColorSpaceItem() {
        let submenu = NSMenu()

        let defaultItem = submenu.addItem(withTitle: "Default (infer from screen)", action: #selector(setColorSpace(_:)), keyEquivalent: "")
        defaultItem.state = PPState.shared.colorSpace == nil ? .on : .off
        submenu.addItem(.separator())
        for (title, name) in PPColor.colorSpaceNames {
            let item = submenu.addItem(withTitle: title, action: #selector(setColorSpace(_:)), keyEquivalent: "")
            item.representedObject = name
            item.state = PPState.shared.colorSpace == name ? .on : .off
        }

        let item = contextMenu.addItem(withTitle: "Color Space", action: nil, keyEquivalent: "")
        item.submenu = submenu
    }

    // If the selected color space is nil, then the preview will just infer the color space from
    // the screen the picker is currently on.
    @objc private func setColorSpace(_ sender: NSMenuItem) {
        PPState.shared.colorSpace = sender.representedObject as? String
    }

    // A menu which allows the magnification level of the picker to be adjusted.
    private func buildMagnificationMenu() {
        let submenu = NSMenu()
        for i in stride(from: 4, through: 24, by: 2) {
            let item = submenu.addItem(withTitle: "\(i)x", action: #selector(selectMagnification(_:)), keyEquivalent: "")
            item.representedObject = i
            item.state = PPState.shared.magnificationLevel == i ? .on : .off
        }
        let item = contextMenu.addItem(withTitle: "Magnification", action: nil, keyEquivalent: "")
        item.submenu = submenu
    }

    @objc private func selectMagnification(_ sender: NSMenuItem) {
        if let level = sender.representedObject as? Int {
            PPState.shared.magnificationLevel = level
        }
    }

    // Format hex colors to uppercase.
    private func buildUseUppercaseItem() {
        let item = contextMenu.addItem(withTitle: "Uppercase Hex Digits", action: #selector(setUseUppercase(_:)), keyEquivalent: "")
        item.state = PPState.shared.useUppercase ? .on : .off
    }

    @objc private func setUseUppercase(_ sender: NSMenuItem) {
        PPState.shared.useUppercase = sender.state != .on
    }

    // Simple launch app at login menu item.
    private func buildLaunchAtLoginItem() {
        let item = contextMenu.addItem(withTitle: "Launch \(APP_NAME) at Login", action: #selector(launchAtLogin(_:)), keyEquivalent: "")
        item.state = LaunchAtLogin.isEnabled ? .on : .off
    }

    @objc private func launchAtLogin(_ sender: NSMenuItem) {
        LaunchAtLogin.isEnabled = !LaunchAtLogin.isEnabled
    }

    // Show the user's recent picks in the menu.
    private func buildRecentPicks() {
        if PPState.shared.recentPicks.count > 0 {
            contextMenu.addItem(.separator())
            contextMenu.addItem(withTitle: "Recently Picked", action: nil, keyEquivalent: "")
            let format = PPState.shared.chosenFormat
            for pickedColor in PPState.shared.recentPicks.reversed() {
                let item = contextMenu.addItem(withTitle: format.asString(withColor: pickedColor.color), action: #selector(copyRecentPick(_:)), keyEquivalent: "")
                item.representedObject = pickedColor
                item.image = circleImage(withSize: 12, color: pickedColor.color)
            }
        }
    }

    // Copies the recently picked color (associated with the menu item) to the clipboard.
    // If the `option` key is pressed, then it copies the color in the same format it was
    // when it was picked (otherwise, it copies it in the currently chosen format).
    @objc private func copyRecentPick(_ sender: NSMenuItem) {
        if let pickedColor = sender.representedObject as? PPPickedColor {
            let value = NSEvent.modifierFlags.contains(.option)
                ? pickedColor.asString
                : PPState.shared.chosenFormat.asString(withColor: pickedColor.color)
            copyToPasteboard(stringValue: value)
        }
    }

    // Simply creates a circle NSImage with the given size and color.
    private func circleImage(withSize size: CGFloat, color: NSColor) -> NSImage {
        let image = NSImage(size: NSSize(width: size, height: size))
        image.lockFocus()
        color.set()
        NSBezierPath(roundedRect: NSMakeRect(0, 0, size, size), xRadius: size, yRadius: size).fill()
        image.unlockFocus()
        return image
    }

    // A slider to change the float precision.
    private func buildFloatPrecisionSlider() {
        contextMenu.addItem(withTitle: "Float Precision (\(PPState.shared.floatPrecision))", action: nil, keyEquivalent: "")

        let value = Double(PPState.shared.floatPrecision)
        let maxValue = Double(PPState.maxFloatPrecision)
        let slider = NSSlider(value: value, minValue: 1, maxValue: maxValue, target: self, action: #selector(sliderUpdate(_:)))
        slider.allowsTickMarkValuesOnly = true
        slider.autoresizingMask = .width
        slider.tickMarkPosition = .above
        slider.numberOfTickMarks = PPState.maxFloatPrecision
        slider.frame = slider.frame.insetBy(dx: 20, dy: 0)

        let item = contextMenu.addItem(withTitle: "Slider", action: nil, keyEquivalent: "")
        item.view = NSView(frame: NSMakeRect(0, 0, 100, 20))
        item.view!.autoresizingMask = .width
        item.view!.addSubview(slider)
    }

    // Called when the slider is updated.
    @objc private func sliderUpdate(_ sender: NSSlider) {
        let newValue = UInt(sender.intValue)

        // Update slider title.
        if let item = contextMenu.item(withTitle: "Float Precision (\(PPState.shared.floatPrecision))") {
            item.title = "Float Precision (\(newValue))"
        }

        // Update state.
        PPState.shared.floatPrecision = newValue

        // Update recent picks list with new precision.
        updateMenuItems()
    }

    // Build a submenu with each case in the PPColor enum.
    private func buildColorFormatsMenu() {
        let submenu = NSMenu()
        for format in PPColor.allCases {
            let formatItem = submenu.addItem(withTitle: format.rawValue, action: #selector(selectFormat(_:)), keyEquivalent: "")
            formatItem.representedObject = format
            if PPState.shared.chosenFormat == format { formatItem.state = .on }
        }

        let item = contextMenu.addItem(withTitle: "Color Format", action: nil, keyEquivalent: "")
        item.submenu = submenu
    }

    // Set the selected format as the default.
    @objc private func selectFormat(_ sender: NSMenuItem) {
        if let format = sender.representedObject as? PPColor {
            PPState.shared.chosenFormat = format
        }
    }

    // Builds and adds the focus modifier submenu.
    private func buildFocusModeModifierMenu() {
        let submenu = NSMenu()
        for (name, modifier) in focusModifiers {
            let modifierItem = submenu.addItem(withTitle: name, action: #selector(selectModifier(_:)), keyEquivalent: "")
            modifierItem.representedObject = modifier
            if PPState.shared.focusModeModifier == modifier { modifierItem.state = .on }
        }

        let item = contextMenu.addItem(withTitle: "Focus Mode Modifier", action: nil, keyEquivalent: "")
        item.submenu = submenu
    }

    // Set the chosen modifier to toggle "focusMode".
    @objc private func selectModifier(_ sender: NSMenuItem) {
        if let modifier = sender.representedObject as? NSEvent.ModifierFlags {
            PPState.shared.focusModeModifier = modifier
        }
    }

    // Builds and adds the MASShortcutView to be used in the menu.
    // Uses a custom view to handle events correctly (since it's inside a NSMenu).
    private func buildShortcutMenuItem() {
        contextMenu.addItem(withTitle: "Picker Shortcut", action: nil, keyEquivalent: "")

        let shortcutView = MASShortcutView()
        shortcutView.style = .flat
        shortcutView.shortcutValue = PPState.shared.activatingShortcut
        shortcutView.shortcutValueChange = { PPState.shared.activatingShortcut = $0?.shortcutValue }

        let item = contextMenu.addItem(withTitle: "Shortcut", action: nil, keyEquivalent: "")
        item.view = PPMenuShortcutView(shortcut: shortcutView)
    }
}
