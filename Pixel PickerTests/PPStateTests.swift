//
//  PPStateTests.swift
//  PixelPickerTests
//

import XCTest
import MASShortcut
@testable import PixelPicker

final class PPStateTests: XCTestCase {
    func testLegacyShortcutSurvivesSaveAndReload() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let path = directory.appendingPathComponent("settings.json")
        let state = PPState(atPath: path)
        // Existing releases wrote both fields as unsigned JSON numbers.
        try state.loadFromString("""
            {"activatingShortcut":{"keyCode":35,"modifierFlags":1048576}}
            """)
        XCTAssertEqual(state.activatingShortcut?.keyCode, 35)
        XCTAssertEqual(state.activatingShortcut?.modifierFlags, .command)
        state.saveToDisk()
        let restored = PPState(atPath: path)
        restored.loadFromDisk()
        XCTAssertEqual(restored.activatingShortcut?.keyCode, 35)
        XCTAssertEqual(restored.activatingShortcut?.modifierFlags, .command)
    }

    func testMalformedShortcutDoesNotTrapOrBecomeActive() throws {
        let path = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let state = PPState(atPath: path)
        for code in ["-1", "128", "18446744073709551615"] {
            try state.loadFromString("{\"activatingShortcut\":{\"keyCode\":\(code),\"modifierFlags\":1048576}}")
            XCTAssertNil(state.activatingShortcut)
        }
    }
}
