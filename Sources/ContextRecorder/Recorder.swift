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

        let filter = contentFilter(content, display: display)

        let writer = try AVAssetWriter(outputURL: outputURL, fileType: .mp4)
        // Fast start: the moov index goes before the media, so a browser can play it without a tail request.
        writer.shouldOptimizeForNetworkUse = true
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
        levelSliceStart = nil
        levelPeak = 0

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

    /// Our windows that do belong in the recording: the Sessions window, so a session about this app shows
    /// it. The control panel, the region overlay and any other window of ours stays out. Call
    /// `refreshFilter()` after changing it while recording.
    var recordedOwnWindows: Set<CGWindowID> = []

    private func contentFilter(_ content: SCShareableContent, display: SCDisplay) -> SCContentFilter {
        let pid = ProcessInfo.processInfo.processIdentifier
        let ownApps = content.applications.filter { $0.processID == pid }
        let keep = content.windows.filter { recordedOwnWindows.contains($0.windowID) }
        return SCContentFilter(display: display, excludingApplications: ownApps, exceptingWindows: keep)
    }

    /// Re-applies the filter to the running stream, e.g. once the Sessions window has opened.
    func refreshFilter() async {
        guard let stream, let display,
              let content = try? await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true) else { return }
        try? await stream.updateContentFilter(contentFilter(content, display: display))
    }

    /// Seconds since the first recorded video frame (nil until recording has produced a frame).
    func currentOffset() -> Double? {
        guard let startPTS else { return nil }
        let now = CMClockGetTime(CMClockGetHostTimeClock())
        return CMTimeGetSeconds(CMTimeSubtract(now, startPTS))
    }

    /// Full-resolution still of part of the main display. `rect` is in display points with a top-left origin;
    /// nil captures the whole display. Our own windows (panel, selection overlay) are excluded, except
    /// `recordedOwnWindows`.
    func screenshot(to url: URL, rect: CGRect?) async throws {
        guard let display else { return }
        let content = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true)
        let filter = contentFilter(content, display: display)
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
            meterLevel(sampleBuffer)
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

    // MARK: Microphone level

    /// Called on the capture queue about `levelsPerSecond` times a second while the microphone delivers
    /// audio: the loudest moment of that slice, 0 (silence, -54 dBFS or quieter) … 1 (full scale).
    var onAudioLevel: ((Float) -> Void)?
    static let levelsPerSecond = 15.0
    private var levelPeak: Float = 0
    private var levelSliceStart: CMTime?

    private func meterLevel(_ sampleBuffer: CMSampleBuffer) {
        guard let onAudioLevel,
              let format = sampleBuffer.formatDescription?.audioStreamBasicDescription else { return }
        let isFloat = format.mFormatFlags & kAudioFormatFlagIsFloat != 0
        guard isFloat ? format.mBitsPerChannel == 32 : format.mBitsPerChannel == 16 else { return }
        var sum: Double = 0
        var count = 0
        try? sampleBuffer.withAudioBufferList { list, _ in
            for buffer in list {
                guard let data = buffer.mData else { continue }
                if isFloat {
                    let samples = UnsafeBufferPointer(start: data.assumingMemoryBound(to: Float.self),
                                                      count: Int(buffer.mDataByteSize) / 4)
                    for s in samples { sum += Double(s * s) }
                    count += samples.count
                } else {
                    let samples = UnsafeBufferPointer(start: data.assumingMemoryBound(to: Int16.self),
                                                      count: Int(buffer.mDataByteSize) / 2)
                    for s in samples { let f = Double(s) / 32768; sum += f * f }
                    count += samples.count
                }
            }
        }
        guard count > 0 else { return }
        let db = 10 * log10(max(sum / Double(count), 1e-10))   // RMS in dBFS
        levelPeak = max(levelPeak, Float(min(1, max(0, (db + 54) / 54))))

        let pts = sampleBuffer.presentationTimeStamp
        guard let start = levelSliceStart else { levelSliceStart = pts; return }
        if CMTimeGetSeconds(CMTimeSubtract(pts, start)) >= 1 / Self.levelsPerSecond {
            onAudioLevel(levelPeak)
            levelPeak = 0
            levelSliceStart = pts
        }
    }

    func stream(_ stream: SCStream, didStopWithError error: Error) {
        DispatchQueue.main.async { self.onError?(error) }
    }
}
