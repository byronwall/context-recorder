import CoreGraphics
import CryptoKit
import Foundation
import ImageIO
import UniformTypeIdentifiers

/// Builds a session's canvas from recording.mp4. Runs only on request; never during capture or reprocessing.
public enum CanvasAnalyzer {
    public struct Options: Sendable {
        public var storyboard = StoryboardSettings()
        /// Join scrolling into tall columns. Off: cards only.
        public var joinScrolling = false
        public init() {}
    }

    /// Analyzes `folder/recording.mp4` inside `box` (video pixels; nil = whole frame), writes images under
    /// `canvas/` and then `canvas.json`. An existing canvas is replaced only once the new one is complete.
    @discardableResult
    public static func build(folder: URL, box: PixelRect?, options: Options = Options(),
                             progress: @Sendable (Double) -> Void = { _ in }) async throws -> CanvasDocument {
        let fm = FileManager.default
        let video = folder.appendingPathComponent("recording.mp4")
        guard fm.fileExists(atPath: video.path) else { throw CanvasError("recording.mp4 is missing") }

        let source = try await FrameSource(url: video, box: box)
        let content = source.contentBox
        let staging = folder.appendingPathComponent(".canvas-building", isDirectory: true)
        try? fm.removeItem(at: staging)
        try fm.createDirectory(at: staging, withIntermediateDirectories: true)
        defer { try? fm.removeItem(at: staging) }

        var tracker = StoryboardTracker(settings: options.storyboard, pixelCount: (content.width / 2) * (content.height / 2))
        var items: [CanvasItem] = []
        var frameCount = 0
        var lastTime = 0.0

        func addCard(_ frame: DecodedFrame, _ reason: CanvasItem.Reason) throws {
            let name = String(format: "card-%04d.png", items.count + 1)
            guard let image = frame.colorImage() else { throw CanvasError("Couldn't read frame \(frame.ref.index)") }
            try writePNG(image, to: staging.appendingPathComponent(name))
            items.append(CanvasItem(id: "c\(items.count + 1)", kind: .card, reason: reason, start: frame.ref.time,
                                    end: frame.ref.time, frame: frame.ref, image: "\(CanvasDocument.imageFolder)/\(name)",
                                    width: content.width, height: content.height))
        }

        while let frame = try source.next() {
            try Task.checkCancellation()
            frameCount += 1
            lastTime = frame.ref.time
            if case let .card(f, reason)? = tracker.feed(frame) { try addCard(f, reason) }
            if frameCount % 15 == 0 { progress(min(0.99, Double(frameCount) / Double(source.estimatedFrameCount))) }
        }
        guard !items.isEmpty else { throw CanvasError("The recording has no frames") }

        // Each item lasts until the next one starts; the last until the end of the video.
        let end = max(lastTime, source.duration)
        for i in items.indices { items[i].end = i + 1 < items.count ? items[i + 1].start : end }

        let attrs = try fm.attributesOfItem(atPath: video.path)
        let doc = CanvasDocument(
            video: VideoInfo(file: "recording.mp4", byteSize: (attrs[.size] as? NSNumber)?.int64Value ?? 0,
                             sha256: try sha256(of: video), width: Int(source.size.width), height: Int(source.size.height),
                             duration: end, frameCount: frameCount),
            box: content,
            builtAt: ISO8601DateFormatter().string(from: .now),
            items: items)

        // Swap in the finished canvas.
        let images = folder.appendingPathComponent(CanvasDocument.imageFolder, isDirectory: true)
        try? fm.removeItem(at: images)
        try fm.moveItem(at: staging, to: images)
        try doc.write(to: folder)
        progress(1)
        return doc
    }

    /// Whether `doc` still describes `folder/recording.mp4`. Cheap size check first, then the hash.
    public static func matchesVideo(_ doc: CanvasDocument, folder: URL) -> Bool {
        let video = folder.appendingPathComponent(doc.video.file)
        guard doc.version == CanvasDocument.currentVersion,
              let size = (try? FileManager.default.attributesOfItem(atPath: video.path))?[.size] as? NSNumber,
              size.int64Value == doc.video.byteSize else { return false }
        return (try? sha256(of: video)) == doc.video.sha256
    }

    public static func sha256(of url: URL) throws -> String {
        let handle = try FileHandle(forReadingFrom: url)
        defer { try? handle.close() }
        var hasher = SHA256()
        while let chunk = try handle.read(upToCount: 4 << 20), !chunk.isEmpty { hasher.update(data: chunk) }
        return hasher.finalize().map { String(format: "%02x", $0) }.joined()
    }

    public static func writePNG(_ image: CGImage, to url: URL) throws {
        guard let dest = CGImageDestinationCreateWithURL(url as CFURL, UTType.png.identifier as CFString, 1, nil) else {
            throw CanvasError("Couldn't write \(url.lastPathComponent)")
        }
        CGImageDestinationAddImage(dest, image, nil)
        guard CGImageDestinationFinalize(dest) else { throw CanvasError("Couldn't write \(url.lastPathComponent)") }
    }
}
