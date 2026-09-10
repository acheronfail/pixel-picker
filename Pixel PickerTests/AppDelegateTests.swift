//
//  AppDelegateTests.swift
//  PixelPickerTests
//

import XCTest
import CoreVideo
@testable import PixelPicker

#if !PIXEL_PICKER_TESTING
#error("Run tests with the Testing build configuration.")
#endif

final class AppDelegateTests: XCTestCase {
    func testDebugBuildDoesNotStartUpdater() {
        let delegate = AppDelegate()
        delegate.applicationDidFinishLaunching(Notification(name: NSApplication.didFinishLaunchingNotification))
        XCTAssertNil(delegate.updaterController)
    }

    func testPixelSamplingKeepsChannelOrder() throws {
        let context = try XCTUnwrap(CGContext(data: nil, width: 3, height: 3,
            bitsPerComponent: 8, bytesPerRow: 12, space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue))
        context.setFillColorSpace(CGColorSpaceCreateDeviceRGB())
        context.setFillColor([1, 0, 0, 1])
        context.fill(CGRect(x: 0, y: 0, width: 3, height: 3))
        context.setFillColor([0, 1, 0, 1])
        context.fill(CGRect(x: 1, y: 1, width: 1, height: 1))
        let image = try XCTUnwrap(context.makeImage())
        let center = image.colorAt(x: 1, y: 1)
        XCTAssertEqual(center.redComponent, 0, accuracy: 0.01)
        XCTAssertEqual(center.greenComponent, 1, accuracy: 0.01)
        XCTAssertEqual(center.blueComponent, 0, accuracy: 0.01)
        XCTAssertEqual(image.colorAt(x: 0, y: 0).redComponent, 1, accuracy: 0.01)
    }

    func testPreviewCropKeepsThePointerPixelCentered() {
        for size in [150, 300, 600] {
            for magnification in stride(from: 4, through: 48, by: 2) {
                let rect = pixelPreviewRect(imageWidth: size, imageHeight: size, magnification: CGFloat(magnification))
                XCTAssertEqual(Int(rect.width) % 2, 1)
                XCTAssertEqual(Int(rect.minX) + Int(rect.width) / 2, size / 2)
                XCTAssertEqual(Int(rect.minY) + Int(rect.height) / 2, size / 2)
            }
        }
    }

    func testInactivePickerPreservesShortcutRecorderKeyEvents() throws {
        let controller = PPOverlayController()
        let event = try XCTUnwrap(NSEvent.keyEvent(with: .keyDown, location: .zero,
            modifierFlags: [.command, .shift], timestamp: 0, windowNumber: 0,
            context: nil, characters: "P", charactersIgnoringModifiers: "p",
            isARepeat: false, keyCode: 35))
        XCTAssertTrue(controller.handleLocalKeyEvent(event) === event)
    }

    func testFractionalPixelStepsNeverBlendAdjacentPixels() throws {
        let image = try checkerboard()
        for step in 0..<8 {
            let point = CGPoint(x: 2 + Double(step) / 2, y: 3.5)
            let region = try XCTUnwrap(image.pixelRegion(centeredAt: point, size: 4))
            let actual = region.colorAt(x: 2, y: 2).redComponent
            let expected = image.colorAt(x: Int(floor(point.x)), y: 3).redComponent
            XCTAssertEqual(actual, expected, accuracy: 1.0 / 255)
            XCTAssertTrue(actual == 0 || actual == 1, "A captured pixel was interpolated")
        }
    }

    func testEdgePaddingPreservesCenterAndOrientation() throws {
        let image = try checkerboard()
        for x in [0.25, 1.5, 6.5, 7.75] {
            for y in [0.25, 1.5, 6.5, 7.75] {
                let region = try XCTUnwrap(image.pixelRegion(centeredAt: CGPoint(x: x, y: y), size: 4))
                XCTAssertEqual(region.width, 4)
                XCTAssertEqual(region.height, 4)
                let expected = image.colorAt(x: Int(floor(x)), y: Int(floor(y)))
                XCTAssertEqual(region.colorAt(x: 2, y: 2).redComponent, expected.redComponent, accuracy: 1.0 / 255)
            }
        }
    }

    func testFocusedShortcutEditorRecordsQueuedKeyboardInput() throws {
        let alert = makePickerShortcutEditor(shortcut: nil)
        let recorder = try XCTUnwrap(alert.accessoryView as? MASShortcutView)
        alert.window.makeKeyAndOrderFront(nil)
        recorder.isRecording = true
        defer {
            recorder.isRecording = false
            alert.window.orderOut(nil)
        }
        let event = try XCTUnwrap(NSEvent.keyEvent(with: .keyDown, location: .zero,
            modifierFlags: [.control, .option, .command], timestamp: ProcessInfo.processInfo.systemUptime,
            windowNumber: alert.window.windowNumber, context: nil, characters: "p",
            charactersIgnoringModifiers: "p", isARepeat: false, keyCode: 35))
        let input = Timer(timeInterval: 0.1, repeats: false) { _ in
            NSApp.postEvent(event, atStart: false)
        }
        let finish = Timer(timeInterval: 0.4, repeats: false) { _ in
            XCTAssertFalse(recorder.isRecording)
            XCTAssertEqual(recorder.shortcutValue?.keyCode, 35)
            XCTAssertEqual(recorder.shortcutValue?.modifierFlags, [.control, .option, .command])
            NSApp.stopModal(withCode: .alertFirstButtonReturn)
        }
        RunLoop.main.add(input, forMode: .modalPanel)
        RunLoop.main.add(finish, forMode: .modalPanel)
        XCTAssertEqual(alert.runModal(), .alertFirstButtonReturn)
        input.invalidate()
        finish.invalidate()
    }

    func testStreamFrameCropPreservesPixelsAndPadsDisplayEdges() throws {
        var buffer: CVPixelBuffer?
        XCTAssertEqual(CVPixelBufferCreate(kCFAllocatorDefault, 8, 8,
            kCVPixelFormatType_32BGRA, nil, &buffer), kCVReturnSuccess)
        let pixels = try XCTUnwrap(buffer)
        CVPixelBufferLockBaseAddress(pixels, [])
        let base = try XCTUnwrap(CVPixelBufferGetBaseAddress(pixels))
        let stride = CVPixelBufferGetBytesPerRow(pixels)
        for y in 0..<8 {
            for x in 0..<8 {
                let pixel = base.advanced(by: y * stride + x * 4).assumingMemoryBound(to: UInt8.self)
                pixel[0] = 25
                pixel[1] = UInt8(y * 30)
                pixel[2] = UInt8(x * 30)
                pixel[3] = 255
            }
        }
        CVPixelBufferUnlockBaseAddress(pixels, [])

        // Reuse one captured frame across fractional pointer movements and edges.
        let frame = PPCaptureFrame(buffer: pixels)
        for x in [0.25, 0.75, 1.5, 4.25, 4.75, 7.75] {
            for y in [0.25, 1.5, 4.25, 7.75] {
                let image = try XCTUnwrap(frame.pixelRegion(centeredAt: CGPoint(x: x, y: y), size: 4))
                XCTAssertEqual(image.width, 4)
                XCTAssertEqual(image.height, 4)
                for row in 0..<4 {
                    for column in 0..<4 {
                        let sourceX = Int(floor(x)) - 2 + column
                        let sourceY = Int(floor(y)) - 2 + row
                        let color = image.colorAt(x: column, y: row)
                        if (0..<8).contains(sourceX) && (0..<8).contains(sourceY) {
                            XCTAssertEqual(color.redComponent, CGFloat(sourceX * 30) / 255, accuracy: 1.0 / 255)
                            XCTAssertEqual(color.greenComponent, CGFloat(sourceY * 30) / 255, accuracy: 1.0 / 255)
                            XCTAssertEqual(color.blueComponent, 25.0 / 255, accuracy: 1.0 / 255)
                            XCTAssertEqual(color.alphaComponent, 1)
                        } else {
                            XCTAssertEqual(color.alphaComponent, 0)
                        }
                    }
                }
            }
        }
    }

    private func checkerboard() throws -> CGImage {
        let bytes = (0..<64).flatMap { index -> [UInt8] in
            let value: UInt8 = ((index % 8 + index / 8) % 2 == 0) ? 0 : 255
            return [value, value, value, 255]
        }
        let provider = try XCTUnwrap(CGDataProvider(data: Data(bytes) as CFData))
        return try XCTUnwrap(CGImage(width: 8, height: 8, bitsPerComponent: 8,
            bitsPerPixel: 32, bytesPerRow: 32, space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.last.rawValue),
            provider: provider, decode: nil, shouldInterpolate: false, intent: .defaultIntent))
    }
}
