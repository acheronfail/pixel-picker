//
//  PPDisplayCapture.swift
//  Pixel Picker
//

import ScreenCaptureKit

// Keep one native-resolution frame and copy only the pixels needed by the preview.
struct PPCaptureFrame {
    let buffer: CVPixelBuffer

    func pixelRegion(centeredAt point: CGPoint, size: Int) -> CGImage? {
        guard size > 0, CVPixelBufferGetPixelFormatType(buffer) == kCVPixelFormatType_32BGRA,
              CVPixelBufferLockBaseAddress(buffer, .readOnly) == kCVReturnSuccess else { return nil }
        defer { CVPixelBufferUnlockBaseAddress(buffer, .readOnly) }
        guard let source = CVPixelBufferGetBaseAddress(buffer) else { return nil }

        let width = CVPixelBufferGetWidth(buffer)
        let height = CVPixelBufferGetHeight(buffer)
        let originX = Int(floor(point.x)) - size / 2
        let originY = Int(floor(point.y)) - size / 2
        let left = max(0, originX)
        let top = max(0, originY)
        let right = min(width, originX + size)
        let bottom = min(height, originY + size)
        guard left < right, top < bottom else { return nil }

        // Zero-filled pixels preserve the crop's center at display edges.
        let bytesPerRow = size * 4
        let sourceBytesPerRow = CVPixelBufferGetBytesPerRow(buffer)
        var pixels = Data(count: bytesPerRow * size)
        pixels.withUnsafeMutableBytes { destination in
            for y in top..<bottom {
                memcpy(destination.baseAddress!.advanced(by: (y - originY) * bytesPerRow + (left - originX) * 4),
                       source.advanced(by: y * sourceBytesPerRow + left * 4), (right - left) * 4)
            }
        }
        guard let provider = CGDataProvider(data: pixels as CFData) else { return nil }
        let colorSpace = CVImageBufferGetColorSpace(buffer)?.takeUnretainedValue() ?? CGColorSpaceCreateDeviceRGB()
        return CGImage(
            width: size,
            height: size,
            bitsPerComponent: 8,
            bitsPerPixel: 32,
            bytesPerRow: bytesPerRow,
            space: colorSpace,
            bitmapInfo: CGBitmapInfo.byteOrder32Little.union(CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedFirst.rawValue)),
            provider: provider,
            decode: nil,
            shouldInterpolate: false,
            intent: .defaultIntent
        )
    }
}

// All state and screen output callbacks are confined to the main queue.
class PPDisplayCapture: NSObject, SCStreamOutput, SCStreamDelegate {
    let displayID: CGDirectDisplayID
    let displayFrame: CGRect
    let scale: CGFloat
    private(set) var latestFrame: PPCaptureFrame?
    var frameChanged: (() -> Void)?
    var failed: ((Error) -> Void)?
    private var stream: SCStream?
    private var stopped = false

    init(display: SCDisplay, filter: SCContentFilter) {
        displayID = display.displayID
        displayFrame = display.frame
        scale = CGFloat(filter.pointPixelScale)
        super.init()

        let configuration = SCStreamConfiguration()
        configuration.width = Int((filter.contentRect.width * scale).rounded())
        configuration.height = Int((filter.contentRect.height * scale).rounded())
        configuration.captureResolution = .best
        configuration.pixelFormat = kCVPixelFormatType_32BGRA
        configuration.minimumFrameInterval = CMTime(value: 1, timescale: 60)
        configuration.queueDepth = 3
        configuration.showsCursor = false
        configuration.capturesAudio = false
        stream = SCStream(filter: filter, configuration: configuration, delegate: self)
    }

    @MainActor
    func start() async throws {
        guard let stream = stream, !stopped else { return }
        try stream.addStreamOutput(self, type: .screen, sampleHandlerQueue: .main)
        try await stream.startCapture()
        // A display change or dismissal may have happened while starting.
        if stopped || Task.isCancelled {
            stop()
            try? await stream.stopCapture()
        }
    }

    func stop() {
        stopped = true
        latestFrame = nil
        frameChanged = nil
        failed = nil
        if let stream = stream {
            try? stream.removeStreamOutput(self, type: .screen)
            stream.stopCapture(completionHandler: { _ in })
        }
        stream = nil
    }

    func stream(_ stream: SCStream, didOutputSampleBuffer sampleBuffer: CMSampleBuffer, of type: SCStreamOutputType) {
        guard !stopped, type == .screen, sampleBuffer.isValid,
              let attachments = CMSampleBufferGetSampleAttachmentsArray(sampleBuffer, createIfNecessary: false) as? [[SCStreamFrameInfo: Any]],
              let status = attachments.first?[.status] as? Int,
              status == SCFrameStatus.complete.rawValue,
              let buffer = sampleBuffer.imageBuffer else { return }
        latestFrame = PPCaptureFrame(buffer: buffer)
        frameChanged?()
    }

    func stream(_ stream: SCStream, didStopWithError error: Error) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self, !self.stopped else { return }
            self.failed?(error)
        }
    }
}
