//
//  Helpers.swift
//  ApptivatorTests
//

import XCTest
import MASShortcut
@testable import Apptivator

let KEY_A: UInt = 0
let KEY_B: UInt = 11
let KEY_C: UInt = 8
let KEY_D: UInt = 2
let KEY_E: UInt = 14
let KEY_F: UInt = 3
let KEY_G: UInt = 5
let OPT: UInt = 524288
let CMD: UInt = 1048576
let CMD_SHIFT: UInt = 1179648

func shortcutView(withKeyCode keyCode: UInt, modifierFlags: UInt) -> MASShortcutView {
    let shortcutView = MASShortcutView()
    shortcutView.shortcutValue = MASShortcut(keyCode: keyCode, modifierFlags: modifierFlags)
    return shortcutView
}

func entry(atURL url: URL, sequence: [MASShortcutView]) -> ApplicationEntry {
    let entry = ApplicationEntry(url: url, config: nil)!
    entry.sequence = sequence
    return entry
}
