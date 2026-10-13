import AppKit
import AVFoundation
import CoreMedia
import Foundation
import ScreenCaptureKit

/// Records the main display + default microphone into a single .mp4 using ScreenCaptureKit and AVAssetWriter.
///
/// All timing uses the host clock: SCStream sample PTS values are host-clock based, so a mark's
/// offset into the video is `hostNow - firstVideoPTS`.
final class Recorder: NSObject, SCStreamOutput, SCStreamDelegate {
    private let queue = DispatchQueue(label: "context-recorder.capture")
    private var stream: SCStream?
    private var writer: AVAssetWriter?
    private var videoInput: AVAssetWriterInput?
    private var audioInput: AVAssetWriterInput?
    private(set) var startPTS: CMTime?
    private(set) var display: SCDisplay?
    var onError: ((Error) -> Void)?

    static let maxWidth = 1920
    static let fps: Int32 = 15

    func start(outputURL: URL, recordMicrophone: Bool) async throws {
        let content = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true)
        let mainID = CGMainDisplayID()
        guard let display = content.displays.first(where: { $0.displayID == mainID }) ?? content.displays.first else {
            throw NSError(domain: "ContextRecorder", code: 1, userInfo: [NSLocalizedDescriptionKey: "No display found"])
        }
        self.display = display

        // Scale to <= maxWidth, keeping aspect, even dimensions for H.264.
        let scale = min(1.0, Double(Self.maxWidth) / Double(display.width))
        let width = Int(Double(display.width) * scale) & ~1
        let height = Int(Double(display.height) * scale) & ~1

        let config = SCStreamConfiguration()
        config.width = width
        config.height = height
        config.minimumFrameInterval = CMTime(value: 1, timescale: Self.fps)
        config.showsCursor = true
        config.capturesAudio = false
        config.captureMicrophone = recordMicrophone
        config.queueDepth = 6

        // Don't record our own (menu bar) app's windows.
        let ownApps = content.applications.filter { $0.processID == ProcessInfo.processInfo.processIdentifier }
        let filter = SCContentFilter(display: display, excludingApplications: ownApps, exceptingWindows: [])

        let writer = try AVAssetWriter(outputURL: outputURL, fileType: .mp4)
        let videoInput = AVAssetWriterInput(mediaType: .video, outputSettings: [
            AVVideoCodecKey: AVVideoCodecType.h264,
            AVVideoWidthKey: width,
            AVVideoHeightKey: height,
            AVVideoCompressionPropertiesKey: [
                AVVideoAverageBitRateKey: 4_000_000,
                AVVideoExpectedSourceFrameRateKey: Self.fps,
                AVVideoMaxKeyFrameIntervalKey: Self.fps * 2,
            ],
        ])
        videoInput.expectsMediaDataInRealTime = true
        let audioInput = AVAssetWriterInput(mediaType: .audio, outputSettings: [
            AVFormatIDKey: kAudioFormatMPEG4AAC,
            AVSampleRateKey: 48_000,
            AVNumberOfChannelsKey: 1,
            AVEncoderBitRateKey: 96_000,
        ])
        audioInput.expectsMediaDataInRealTime = true
        writer.add(videoInput)
        if recordMicrophone { writer.add(audioInput) }
        self.writer = writer
        self.videoInput = videoInput
        self.audioInput = recordMicrophone ? audioInput : nil
        self.startPTS = nil

        let stream = SCStream(filter: filter, configuration: config, delegate: self)
        try stream.addStreamOutput(self, type: .screen, sampleHandlerQueue: queue)
        if recordMicrophone { try stream.addStreamOutput(self, type: .microphone, sampleHandlerQueue: queue) }
        self.stream = stream
        try await stream.startCapture()
    }

    func stop() async {
        if let stream { try? await stream.stopCapture() }
        stream = nil
        await withCheckedContinuation { (cont: CheckedContinuation<Void, Never>) in
            queue.async {
                guard let writer = self.writer, writer.status == .writing else {
                    cont.resume(); return
                }
                self.videoInput?.markAsFinished()
                self.audioInput?.markAsFinished()
                writer.finishWriting { cont.resume() }
            }
        }
        writer = nil
    }

    /// Seconds since the first recorded video frame (nil until recording has produced a frame).
    func currentOffset() -> Double? {
        guard let startPTS else { return nil }
        let now = CMClockGetTime(CMClockGetHostTimeClock())
        return CMTimeGetSeconds(CMTimeSubtract(now, startPTS))
    }

    /// Full-resolution still of part of the main display. `rect` is in display points with a top-left origin;
    /// nil captures the whole display. Our own windows (panel, selection overlay) are excluded.
    func screenshot(to url: URL, rect: CGRect?) async throws {
        guard let display else { return }
        let content = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true)
        let ownApps = content.applications.filter { $0.processID == ProcessInfo.processInfo.processIdentifier }
        let filter = SCContentFilter(display: display, excludingApplications: ownApps, exceptingWindows: [])
        let scale = CGFloat(filter.pointPixelScale)
        let area = rect ?? CGRect(x: 0, y: 0, width: display.width, height: display.height)
        let config = SCStreamConfiguration()
        config.sourceRect = area
        config.width = Int(area.width * scale)
        config.height = Int(area.height * scale)
        config.showsCursor = false
        let image = try await SCScreenshotManager.captureImage(contentFilter: filter, configuration: config)
        let rep = NSBitmapImageRep(cgImage: image)
        try rep.representation(using: .png, properties: [:])?.write(to: url)
    }

    // MARK: SCStreamOutput

    func stream(_ stream: SCStream, didOutputSampleBuffer sampleBuffer: CMSampleBuffer, of type: SCStreamOutputType) {
        guard sampleBuffer.isValid, let writer else { return }
        switch type {
        case .screen:
            guard let attachments = CMSampleBufferGetSampleAttachmentsArray(sampleBuffer, createIfNecessary: false)
                as? [[SCStreamFrameInfo: Any]],
                let statusRaw = attachments.first?[.status] as? Int,
                SCFrameStatus(rawValue: statusRaw) == .complete else { return }
            let pts = CMSampleBufferGetPresentationTimeStamp(sampleBuffer)
            if startPTS == nil {
                writer.startWriting()
                writer.startSession(atSourceTime: pts)
                startPTS = pts
            }
            if let videoInput, videoInput.isReadyForMoreMediaData { videoInput.append(sampleBuffer) }
        case .microphone:
            guard let startPTS, writer.status == .writing else { return }
            let pts = CMSampleBufferGetPresentationTimeStamp(sampleBuffer)
            guard CMTimeCompare(pts, startPTS) >= 0 else { return }
            if let audioInput, audioInput.isReadyForMoreMediaData { audioInput.append(sampleBuffer) }
        default:
            break
        }
        if writer.status == .failed, let error = writer.error {
            DispatchQueue.main.async { self.onError?(error) }
        }
    }

    func stream(_ stream: SCStream, didStopWithError error: Error) {
        DispatchQueue.main.async { self.onError?(error) }
    }
}
