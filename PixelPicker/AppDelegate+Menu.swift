//
//  AppDelegate+Menu.swift
//  PixelPicker
//

/**
 * This file is responsible for managing PixelPicker's dropdown menu when
 * the user clicks on the status bar item.
 */

// The modifiers available to use to toggle "concentrationMode".
let concentrationModifiers: [(String, NSEvent.ModifierFlags)] = [
    ("fn Function", .function),
    ("⌘ Command", .command),
    ("⌃ Control", .control),
    ("⌥ Option", .option),
    ("⇧ Shift ", .shift)
]

extension AppDelegate: NSMenuDelegate {
    // Unregister/register the activating shortcut when the menu is opened/closed
    // so it can't be called when setting a new shortcut.
    func menuWillOpen(_ menu: NSMenu) { unregisterActivatingShortcut() }
    func menuDidClose(_ menu: NSMenu) { registerActivatingShortcut() }

    // TODO: look into only updating the menu rather than rebuilding it each time.
    // Might not be worth it - it doesn't seem expensive to build it every time it's opened...
    func rebuildContextMenu() {
        contextMenu.removeAllItems()
        
        let pickItem = contextMenu.addItem(withTitle: "Pick a pixel!", action: #selector(showPicker), keyEquivalent: "")
        pickItem.image = ICON
        
        buildRecentPicks()
        
        contextMenu.addItem(.separator())
        buildColorFormatsMenu()
        buildConcentrationMenu()
        buildFloatPrecisionSlider()
        buildShortcutMenuItem()
        
        contextMenu.addItem(.separator())
        contextMenu.addItem(withTitle: "About", action: #selector(showAboutPanel), keyEquivalent: "")
        contextMenu.addItem(withTitle: "Quit \(APP_NAME)", action: #selector(quitApplication), keyEquivalent: "")
    }
    
    // Show the user's recent picks in the menu.
    private func buildRecentPicks() {
        // Recent picks.
        // TODO: it would be nice to hold the `option` key and have the recent picks show in the
        // currently chosen format, and when clicked copy in that format.
        // https://stackoverflow.com/q/11208632/5552584
        if PPState.shared.recentPicks.count > 0 {
            contextMenu.addItem(.separator())
            contextMenu.addItem(withTitle: "Recently Picked", action: nil, keyEquivalent: "")
            for pickedColor in PPState.shared.recentPicks {
                // TODO: copy to clipboard when clicked, if alt then in current format
                let item = contextMenu.addItem(withTitle: pickedColor.asString, action: #selector(copyRecentPick(_:)), keyEquivalent: "")
                item.representedObject = pickedColor
                item.image = circleImage(withSize: 12, color: pickedColor.color)
            }
        }
    }
    
    @objc private func copyRecentPick(_ sender: NSMenuItem) {
        if let pickedColor = sender.representedObject as? PPPickedColor {
            copyToPasteboard(stringValue: pickedColor.asString)
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
        for item in contextMenu.items {
            if let pickedColor = item.representedObject as? PPPickedColor {
                item.title = pickedColor.asString
            }
        }
    }
    
    // Build a submenu with each case in the PPColor enum.
    // TODO: with Swift 4.2, we shouldn't need to resort to the hacky "iterateEnum" approach.
    private func buildColorFormatsMenu() {
        let submenu = NSMenu()
        for format in iterateEnum(PPColor.self) {
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
            sender.menu?.items.forEach({ $0.state = .off })
            sender.state = .on
        }
    }
    
    // Builds and adds the concentration modifier submenu.
    private func buildConcentrationMenu() {
        let submenu = NSMenu()
        for (name, modifier) in concentrationModifiers {
            let modifierItem = submenu.addItem(withTitle: name, action: #selector(selectModifier(_:)), keyEquivalent: "")
            modifierItem.representedObject = modifier
            if PPState.shared.concentrationModeModifier == modifier { modifierItem.state = .on }
        }

        let item = contextMenu.addItem(withTitle: "Concentration Modifier", action: nil, keyEquivalent: "")
        item.submenu = submenu
    }
    
    // Set the chosen modifier to toggle "concentrationMode".
    @objc private func selectModifier(_ sender: NSMenuItem) {
        if let modifier = sender.representedObject as? NSEvent.ModifierFlags {
            PPState.shared.concentrationModeModifier = modifier
            sender.menu?.items.forEach({ $0.state = .off })
            sender.state = .on
        }
    }
    
    // Builds and adds the MASShortcutView to be used in the menu.
    // Uses a custom view to handle events correctly (since it's inside a NSMenu).
    private func buildShortcutMenuItem() {
        contextMenu.addItem(withTitle: "Picker Shortcut", action: nil, keyEquivalent: "")

        let shortcutView = MASShortcutView()
        shortcutView.shortcutValue = PPState.shared.activatingShortcut
        shortcutView.shortcutValueChange = { PPState.shared.activatingShortcut = $0?.shortcutValue }
        
        let item = contextMenu.addItem(withTitle: "Shortcut", action: nil, keyEquivalent: "")
        item.view = PPMenuShortcutView(shortcut: shortcutView)
    }
}
