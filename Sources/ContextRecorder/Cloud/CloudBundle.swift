import AVFoundation
import CryptoKit
import Foundation
import ImageIO
import SwiftUI
import UniformTypeIdentifiers

/// The cloud copy of a session (docs/cloud-sessions.md §1): one folder in edited time, laid out like a session
/// recorded without edits. Cuts and joins are flattened into one mp4, drawings become transparent PNGs (and
/// edited-time annotations.json), marks' images take their play-order names, and session.json and the logs are
/// rewritten for that single video, so nothing downstream needs to know about edits.json, and a Mac that
/// downloads the copy can process it again and get the same session.
struct CloudManifest: Codable, Equatable {
    struct Video: Codable, Equatable { var path: String; var width: Int; var height: Int }
    struct Thumbs: Codable, Equatable { var interval: Double; var count: Int; var pattern: String; var width: Int }
    struct SkippedPage: Codable, Equatable { var path: String; var size: Int64 }
    struct File: Codable, Equatable { var path: String; var size: Int64; var sha256: String; var type: String }

    var format = 1
    var sessionId: String
    var title: String
    var recordedAt: String?
    var duration: Double
    var markCount: Int
    var video: Video
    var thumbs: Thumbs
    var poster: String?
    var skippedPages: [SkippedPage]
    var inputHash: String
    /// The Mac that pushed it, so another Mac can say where a cloud-only session came from. Absent in older pushes.
    var machine: String?
    var files: [File]

    func encoded() throws -> Data {
        let enc = JSONEncoder()
        enc.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        return try enc.encode(self)
    }
}

/// One entry of drawings.json: a drawing's PNG and when it shows, in edited time.
struct CloudDrawing: Codable, Equatable {
    var id: String
    var file: String
    var start: Double
    var end: Double
}

@MainActor
enum CloudBundle {
    nonisolated static let format = 1
    static let thumbInterval = 2.0
    static let thumbWidth = 480
    static let minimumPageBudget: Int64 = 10 * 1024 * 1024

    /// Written by processing; copied as is. The logs it is built from are rewritten in edited time (`writeLogs`).
    static let plainFiles = ["session.md"]
    /// Fields processing adds to a mark of an edited or joined session; a flat session has none of them.
    static let editFields = ["sourceOffsetSeconds", "sourceSession", "rawSession", "rawIndex"]

    typealias Progress = (_ phase: String, _ fraction: Double) -> Void

    /// Writes the cloud copy of `session` into `out` (created, or replaced when it holds an earlier bundle).
    @discardableResult
    static func build(session: URL, to out: URL, progress: Progress? = nil) async throws -> CloudManifest {
        let session = session.standardizedFileURL
        let fm = FileManager.default
        let sessionJSON = session.appendingPathComponent("session.json")
        guard let raw = try? Data(contentsOf: sessionJSON),
              var data = try JSONSerialization.jsonObject(with: raw) as? [String: Any] else {
            throw ReviewError("\(session.lastPathComponent) hasn't been processed yet (no session.json).")
        }
        let typed = try JSONDecoder().decode(SessionData.self, from: raw)
        if let missing = typed.errors.first(where: { $0.hasPrefix("Source missing") }) { throw ReviewError(missing) }

        try prepare(out)
        progress?("Preparing", 0)
        let inputHash = try await Task.detached { () throws -> String in try CloudBundle.inputHash(session: session) }.value

        // 1. The video: copied as is, or the edited composition exported to one mp4.
        let segments = typed.segments.isEmpty ? [Segment(start: 0, end: typed.duration ?? 0)] : typed.segments
        let durations = typed.sourceDurations.isEmpty ? [".": typed.duration ?? 0] : typed.sourceDurations
        let edited = fm.fileExists(atPath: EditsFile.url(session).path) && !EditMap.isUnedited(segments, sourceDurations: durations)
        let map = EditMap(segments)
        let video = out.appendingPathComponent("recording.mp4")
        if edited {
            progress?("Exporting the edited video", 0.05)
            try await exportEdited(map, session: session, to: video) { progress?("Exporting the edited video", 0.05 + 0.6 * $0) }
        } else {
            let source = session.appendingPathComponent("recording.mp4")
            guard fm.fileExists(atPath: source.path) else { throw ReviewError("recording.mp4 is missing") }
            if isFastStart(source) {
                try fm.copyItem(at: source, to: video)
            } else {
                progress?("Optimizing the video for streaming", 0.05)
                try await remuxFastStart(source, session: session, to: video)
            }
        }
        let asset = AVURLAsset(url: video)
        let measured = try await asset.load(.duration).seconds
        let duration = round3(measured.isFinite && measured > 0 ? measured : map.duration)
        let size = try await displaySize(asset)

        // 2. Drawings, each a transparent PNG at the video's size, shown over its edited-time window.
        progress?("Rendering drawings", 0.68)
        let annotations = AnnotationsFile.load(session)
        let drawings = try renderDrawings(annotations, map: map, size: size, out: out)
        try writeJSON(drawings, to: out.appendingPathComponent("drawings.json"))
        // The same drawings as shapes, so a Mac that downloads this copy can show and edit them.
        try AnnotationsFile.save(flattened(annotations, map: map), to: out)

        // 3. Thumbnails every couple of seconds, for timeline hover and the frames fallback.
        progress?("Making thumbnails", 0.72)
        let thumbCount = try await writeThumbs(asset: asset, duration: duration, size: size, out: out)

        // 4. Images, Markdown, logs and saved pages; session.json rewritten for the flat video.
        progress?("Copying files", 0.85)
        var copies: [String: URL] = [:]   // bundle path → file
        func include(_ relative: String?) -> String? {
            guard let relative, !relative.isEmpty else { return nil }
            let file = session.appendingPathComponent(relative).standardizedFileURL
            guard fm.fileExists(atPath: file.path) else { return nil }
            let path = bundlePath(relative)
            copies[path] = file
            return path
        }
        for name in plainFiles { _ = include(name) }
        if let mds = try? fm.contentsOfDirectory(atPath: session.appendingPathComponent("marks").path) {
            for md in mds.sorted() where md.hasSuffix(".md") { _ = include("marks/" + md) }
        }
        /// `relative` stored at `path` in the bundle instead of at its own path; nil when it doesn't exist.
        func place(_ relative: String?, at path: String) -> String? {
            guard let relative, !relative.isEmpty else { return nil }
            let file = session.appendingPathComponent(relative).standardizedFileURL
            guard fm.fileExists(atPath: file.path) else { return nil }
            copies[path] = file
            return path
        }
        /// An image's marked-up copy (and its editable drawing) under the name processing gives `path`.
        let store = AnnotationStore(folder: session)
        func placeAnnotated(_ original: String?, as path: String) -> String? {
            guard let original else { return nil }
            let from = store.base(for: original), to = "annotations/" + (path as NSString).deletingPathExtension.replacingOccurrences(of: "/", with: "-")
            guard fm.fileExists(atPath: from.appendingPathExtension("png").path) else { return nil }
            copies[to + ".png"] = from.appendingPathExtension("png")
            if fm.fileExists(atPath: from.appendingPathExtension("json").path) { copies[to + ".json"] = from.appendingPathExtension("json") }
            return to + ".png"
        }

        let videoSize = (try? fm.attributesOfItem(atPath: video.path)[.size] as? Int64) ?? 0
        let budget = max(minimumPageBudget, videoSize / 2)
        var pages: [(path: String, file: URL, size: Int64)] = []
        var marks = data["marks"] as? [[String: Any]] ?? []
        for i in marks.indices {
            var m = marks[i]
            // Each mark's frame and screenshot (and marked-up copies) go where processing a flat session puts
            // them: `frames/NNN.jpg`, `screenshots/NNN.png`, by play-order index.
            let n = String(format: "%03d", (m["index"] as? Int) ?? i + 1)
            let originalFrame = (m["sourceFrame"] ?? m["frame"]) as? String
            let frame = place(originalFrame, at: "frames/\(n).jpg")
            let markedFrame = placeAnnotated(originalFrame, as: "frames/\(n).jpg")
            var shot: String?, markedShot: String?
            if let original = m["screenshot"] as? String {
                shot = place(original, at: "screenshots/\(n).png")
                markedShot = placeAnnotated(original, as: "screenshots/\(n).png")
            }
            m["screenshot"] = shot
            m["sourceFrame"] = frame.map { $0 as Any } ?? NSNull()
            m["sourceImage"] = (shot ?? frame).map { $0 as Any } ?? NSNull()
            m["frame"] = (markedFrame ?? frame).map { $0 as Any } ?? NSNull()
            m["image"] = (shot.map { markedShot ?? $0 } ?? markedFrame ?? frame).map { $0 as Any } ?? NSNull()
            for key in editFields { m[key] = nil }
            if var browser = m["browser"] as? [String: Any], let page = browser["pageFile"] as? String {
                let file = session.appendingPathComponent(page).standardizedFileURL
                let path = bundlePath(page)
                browser["pageFile"] = path
                if let size = try? fm.attributesOfItem(atPath: file.path)[.size] as? Int64,
                   !pages.contains(where: { $0.path == path }) {
                    pages.append((path, file, size))
                }
                m["browser"] = browser
            }
            marks[i] = m
        }
        var used: Int64 = 0
        var skipped: [CloudManifest.SkippedPage] = []
        for page in pages.sorted(by: { ($0.size, $0.path) < ($1.size, $1.path) }) {
            if used + page.size <= budget {
                used += page.size
                copies[page.path] = page.file
            } else {
                skipped.append(.init(path: page.path, size: page.size))
            }
        }
        skipped.sort { $0.path < $1.path }
        // Processing a downloaded copy again reads this as the reason the page is missing.
        for page in skipped {
            let note = out.appendingPathComponent((page.path as NSString).deletingPathExtension + ".error.txt")
            try fm.createDirectory(at: note.deletingLastPathComponent(), withIntermediateDirectories: true)
            try "Left out of the cloud copy (\(ByteCountFormatter.string(fromByteCount: page.size, countStyle: .file)))\n"
                .write(to: note, atomically: true, encoding: .utf8)
        }

        for (path, file) in copies {
            let target = out.appendingPathComponent(path)
            try fm.createDirectory(at: target.deletingLastPathComponent(), withIntermediateDirectories: true)
            try fm.copyItem(at: file, to: target)
        }

        data["marks"] = marks
        data["hiddenMarks"] = []   // cut footage stays on the Mac
        data["segments"] = [["source": ".", "start": 0, "end": duration, "editedStart": 0]]
        data["sourceDurations"] = [".": duration]
        data["duration"] = duration
        data["folder"] = ""
        try writeJSON(data, to: out.appendingPathComponent("session.json"))
        try writeLogs(data, session: session, edited: edited, map: map, out: out)

        // 5. The manifest: every file with its hash, then index.html with everything embedded.
        progress?("Hashing", 0.92)
        let files = try await Task.detached { () throws -> [CloudManifest.File] in try CloudBundle.listFiles(in: out) }.value
        let manifest = CloudManifest(
            sessionId: sessionID(for: session),
            title: SessionInfo.title(session) ?? session.lastPathComponent,
            recordedAt: recordedAt(session),
            duration: duration,
            markCount: marks.count,
            video: .init(path: "recording.mp4", width: Int(size.width), height: Int(size.height)),
            thumbs: .init(interval: thumbInterval, count: thumbCount, pattern: "thumbs/%04d.jpg", width: thumbWidth),
            poster: thumbCount > 0 ? "thumbs/0000.jpg" : nil,
            skippedPages: skipped,
            inputHash: inputHash,
            machine: Host.current().localizedName,
            files: files)
        try manifest.encoded().write(to: out.appendingPathComponent("manifest.json"), options: .atomic)
        try writeIndex(session: data, manifest: manifest, drawings: drawings, to: out.appendingPathComponent("index.html"))
        progress?("Done", 1)
        return manifest
    }

    // MARK: Logs

    /// The raw inputs processing reads, in edited time on the flat video: marks.jsonl and the activity and page
    /// logs from session.json (already mapped), and transcript.json with its word timings mapped the same way
    /// processing maps them. An unedited session's transcript is copied as is.
    private static func writeLogs(_ data: [String: Any], session: URL, edited: Bool, map: EditMap, out: URL) throws {
        func jsonl(_ items: [[String: Any]], _ name: String) throws {
            guard !items.isEmpty else { return }
            let lines = try items.map { String(decoding: try JSONSerialization.data(withJSONObject: $0, options: [.sortedKeys, .withoutEscapingSlashes]), as: UTF8.self) }
            try (lines.joined(separator: "\n") + "\n").write(to: out.appendingPathComponent(name), atomically: true, encoding: .utf8)
        }
        let derived = ["frame", "image", "sourceFrame", "sourceImage", "narration"]
        let marks = (data["marks"] as? [[String: Any]] ?? []).map { $0.filter { !derived.contains($0.key) && !($0.value is NSNull) } }
        try jsonl(marks, "marks.jsonl")
        try jsonl(data["activity"] as? [[String: Any]] ?? [], "activity.jsonl")
        try jsonl(data["browser"] as? [[String: Any]] ?? [], "browser.jsonl")

        let transcript = out.appendingPathComponent("transcript.json")
        guard edited else {
            let own = session.appendingPathComponent("transcript.json")
            if FileManager.default.fileExists(atPath: own.path) { try FileManager.default.copyItem(at: own, to: transcript) }
            return
        }
        var sentences: [[String: Any]] = []
        for source in map.sources {
            let file = EditMap.folder(of: source, in: session).appendingPathComponent("transcript.json")
            guard let raw = try? Data(contentsOf: file),
                  let obj = try JSONSerialization.jsonObject(with: raw) as? [String: Any] else { continue }
            sentences += mapSentences(obj["sentences"] as? [[String: Any]] ?? [], map: map, source: source)
        }
        guard !sentences.isEmpty else { return }
        sentences.sort { ($0["start"] as? Double ?? 0) < ($1["start"] as? Double ?? 0) }
        let text = sentences.compactMap { $0["text"] as? String }.joined()
        try writeJSON(["text": text, "sentences": sentences], to: transcript)
    }

    /// process_session.py's map_sentences: a sentence survives when more than half of it is kept; its times are
    /// clamped to what is kept and words inside cuts are dropped.
    static func mapSentences(_ sentences: [[String: Any]], map: EditMap, source: String) -> [[String: Any]] {
        func round6(_ x: Double) -> Double { (x * 1_000_000).rounded() / 1_000_000 }
        var out: [[String: Any]] = []
        for var sentence in sentences {
            guard let start = sentence["start"] as? Double, let end = sentence["end"] as? Double else { continue }
            let pieces = map.editedPieces(source: source, start, end)
            guard let first = pieces.first, let last = pieces.last,
                  pieces.reduce(0, { $0 + $1.upperBound - $1.lowerBound }) > max(1e-6, end - start) / 2 else { continue }
            var tokens: [[String: Any]] = []
            for var token in sentence["tokens"] as? [[String: Any]] ?? [] {
                guard let a = token["start"] as? Double, let b = token["end"] as? Double,
                      let mid = map.toEdited(source: source, (a + b) / 2) else { continue }
                token["start"] = round6(mid - (b - a) / 2)
                token["end"] = round6(mid + (b - a) / 2)
                tokens.append(token)
            }
            sentence["start"] = round6(first.lowerBound)
            sentence["end"] = round6(last.upperBound)
            sentence["tokens"] = tokens
            out.append(sentence)
        }
        return out
    }

    // MARK: Output folder

    /// Creates `out`, replacing it only when it is empty or an earlier bundle (never an arbitrary folder).
    private static func prepare(_ out: URL) throws {
        let fm = FileManager.default
        if fm.fileExists(atPath: out.path) {
            let contents = (try? fm.contentsOfDirectory(atPath: out.path)) ?? []
            guard contents.isEmpty || contents.contains("manifest.json") else {
                throw ReviewError("\(out.path) isn't empty and isn't a cloud copy; choose another folder.")
            }
            try fm.removeItem(at: out)
        }
        try fm.createDirectory(at: out, withIntermediateDirectories: true)
    }

    // MARK: Video

    /// Exports are cached outside the session (keyed by the cut list and the source recordings), because
    /// AVAssetExportSession stamps each file differently: re-exporting would re-upload an unchanged video.
    private static func exportEdited(_ map: EditMap, session: URL, to url: URL, progress: @escaping (Double) -> Void) async throws {
        var parts = ["format \(format)"]
        for s in map.segments {
            let rec = EditMap.folder(of: s.source, in: session).appendingPathComponent("recording.mp4")
            parts.append("\(rec.standardizedFileURL.path) \(s.start) \(s.end) \(fileStamp(rec))")
        }
        try await cachedVideo(session: session, key: parts, to: url) { try await exportComposition(map, session: session, to: $0, progress: progress) }
    }

    /// An unedited recording with `moov` at the end, rewritten fast start. Cached like edited exports:
    /// the remux is lossless, but its file differs on every run.
    private static func remuxFastStart(_ source: URL, session: URL, to url: URL) async throws {
        let parts = ["format \(format)", "fast-start \(source.standardizedFileURL.path) \(fileStamp(source))"]
        try await cachedVideo(session: session, key: parts, to: url) { out in
            guard let export = AVAssetExportSession(asset: AVURLAsset(url: source), presetName: AVAssetExportPresetPassthrough) else {
                throw ReviewError("Couldn't start optimizing the video")
            }
            // Passthrough copies the samples as they are: no re-encode.
            export.shouldOptimizeForNetworkUse = true
            try await export.export(to: out, as: .mp4)
        }
    }

    private static func fileStamp(_ url: URL) -> String {
        let a = try? FileManager.default.attributesOfItem(atPath: url.path)
        return "\((a?[.size] as? Int64) ?? 0)@\(((a?[.modificationDate] as? Date)?.timeIntervalSince1970 ?? 0))"
    }

    /// Copies the cached video for `key` to `url`, or makes it with `make` and caches it (one per session).
    private static func cachedVideo(session: URL, key parts: [String], to url: URL, make: (URL) async throws -> Void) async throws {
        let fm = FileManager.default
        let key = SHA256.hash(data: Data(parts.joined(separator: "\n").utf8)).prefix(12).map { String(format: "%02x", $0) }.joined()
        let id = sessionID(for: session)
        let cache = (fm.urls(for: .cachesDirectory, in: .userDomainMask).first ?? fm.temporaryDirectory)
            .appendingPathComponent("ContextRecorder/cloud-video")
        let cached = cache.appendingPathComponent("\(id)-\(key).mp4")
        if fm.fileExists(atPath: cached.path) {
            try fm.copyItem(at: cached, to: url)
            return
        }
        try await make(url)
        try? fm.createDirectory(at: cache, withIntermediateDirectories: true)
        // Keep one export per session.
        for old in (try? fm.contentsOfDirectory(atPath: cache.path)) ?? [] where old.hasPrefix(id + "-") {
            try? fm.removeItem(at: cache.appendingPathComponent(old))
        }
        try? fm.copyItem(at: url, to: cached)
    }

    private static func exportComposition(_ map: EditMap, session: URL, to url: URL, progress: @escaping (Double) -> Void) async throws {
        let playback = try await map.composition(in: session)
        guard let export = AVAssetExportSession(asset: playback.asset, presetName: AVAssetExportPresetHighestQuality) else {
            throw ReviewError("Couldn't start exporting the edited video")
        }
        export.videoComposition = playback.videoComposition
        export.shouldOptimizeForNetworkUse = true
        let watch = Task {
            for await state in export.states(updateInterval: 0.5) {
                if case .exporting(let p) = state { progress(p.fractionCompleted) }
            }
        }
        defer { watch.cancel() }
        try await export.export(to: url, as: .mp4)
    }

    /// The top-level box types of an MP4, in file order (`ftyp`, `moov`, `mdat`, …); nil when unreadable.
    nonisolated static func topLevelAtoms(_ url: URL) -> [String]? {
        guard let handle = try? FileHandle(forReadingFrom: url) else { return nil }
        defer { try? handle.close() }
        guard let end = try? handle.seekToEnd() else { return nil }
        var atoms: [String] = [], offset: UInt64 = 0
        while offset + 8 <= end {
            guard (try? handle.seek(toOffset: offset)) != nil,
                  let header = try? handle.read(upToCount: 16), header.count >= 8 else { return nil }
            let bytes = [UInt8](header)
            func be(_ range: Range<Int>) -> UInt64 { bytes[range].reduce(0) { $0 << 8 | UInt64($1) } }
            var size = be(0..<4)
            let type = String(decoding: bytes[4..<8], as: UTF8.self)
            if size == 1 {   // 64-bit size follows the type
                guard bytes.count >= 16 else { return nil }
                size = be(8..<16)
            } else if size == 0 {   // runs to the end of the file
                size = end - offset
            }
            guard size >= 8 else { return nil }
            atoms.append(type)
            offset += size
        }
        return atoms
    }

    /// True when `moov` comes before `mdat`, so a player needs only the start of the file to begin.
    nonisolated static func isFastStart(_ url: URL) -> Bool {
        guard let atoms = topLevelAtoms(url), let moov = atoms.firstIndex(of: "moov") else { return false }
        return atoms.firstIndex(of: "mdat").map { moov < $0 } ?? true
    }

    /// The video's size as displayed (rotation applied).
    static func displaySize(_ asset: AVAsset) async throws -> CGSize {
        guard let track = try await asset.loadTracks(withMediaType: .video).first else { throw ReviewError("The video has no picture") }
        let (natural, transform) = try await track.load(.naturalSize, .preferredTransform)
        let r = CGRect(origin: .zero, size: natural).applying(transform)
        return CGSize(width: abs(r.width).rounded(), height: abs(r.height).rounded())
    }

    // MARK: Drawings

    /// Each drawing's surviving pieces in edited time; pieces that meet across a cut become one window.
    static func windows(_ a: Annotation, map: EditMap) -> [ClosedRange<Double>] {
        var out: [ClosedRange<Double>] = []
        for piece in map.editedPieces(source: a.source, a.start, a.end) {
            if let last = out.last, piece.lowerBound - last.upperBound < 0.001 {
                out[out.count - 1] = last.lowerBound...max(last.upperBound, piece.upperBound)
            } else {
                out.append(piece)
            }
        }
        return out
    }

    /// One PNG per drawing; a drawing split by a cut gets one drawings.json entry per window
    /// (`<uuid>`, then `<uuid>-2`, …) sharing the PNG.
    private static func renderDrawings(_ annotations: [Annotation], map: EditMap, size: CGSize, out: URL) throws -> [CloudDrawing] {
        var list: [CloudDrawing] = []
        for a in annotations {
            let spans = windows(a, map: map)
            guard !spans.isEmpty else { continue }
            let id = a.id.uuidString.lowercased()
            let file = "drawings/\(id).png"
            try writePNG(drawing(a, size: size), to: out.appendingPathComponent(file))
            for (i, span) in spans.enumerated() {
                list.append(CloudDrawing(id: i == 0 ? id : "\(id)-\(i + 1)", file: file,
                                         start: round3(span.lowerBound), end: round3(span.upperBound)))
            }
        }
        return list.sorted { ($0.start, $0.id) < ($1.start, $1.id) }
    }

    /// The annotations moved onto the flattened video: source ".", edited-time windows. A drawing split by a
    /// cut becomes one annotation per window; the first keeps its id.
    static func flattened(_ annotations: [Annotation], map: EditMap) -> [Annotation] {
        var out: [Annotation] = []
        for a in annotations {
            for (i, span) in windows(a, map: map).enumerated() {
                var piece = a
                if i > 0 { piece.id = derivedID(a.id, i) }
                piece.source = "."
                piece.start = round3(span.lowerBound)
                piece.end = round3(span.upperBound)
                out.append(piece)
            }
        }
        return out.sorted { ($0.start, $0.id.uuidString) < ($1.start, $1.id.uuidString) }
    }

    /// A stable id for the nth extra piece of a split drawing, so pushing again doesn't change the file.
    private static func derivedID(_ id: UUID, _ n: Int) -> UUID {
        var bytes = Array(SHA256.hash(data: Data("\(id.uuidString)-\(n)".utf8)).prefix(16))
        bytes[6] = (bytes[6] & 0x0F) | 0x50   // version 5-style, variant RFC 4122
        bytes[8] = (bytes[8] & 0x3F) | 0x80
        return UUID(uuid: (bytes[0], bytes[1], bytes[2], bytes[3], bytes[4], bytes[5], bytes[6], bytes[7],
                           bytes[8], bytes[9], bytes[10], bytes[11], bytes[12], bytes[13], bytes[14], bytes[15]))
    }

    /// The drawing alone on a transparent canvas the size of the video, drawn by the same renderer the
    /// app uses over the player, so it lands exactly where it does in the app.
    static func drawing(_ a: Annotation, size: CGSize) throws -> CGImage {
        let renderer = ImageRenderer(content: Canvas { ctx, _ in AnnotationRenderer.draw(a, in: ctx, size: size) }
            .frame(width: size.width, height: size.height))
        renderer.scale = 1
        renderer.isOpaque = false
        guard let image = renderer.cgImage else { throw ReviewError("Couldn't render drawing \(a.id)") }
        return image
    }

    // MARK: Thumbnails

    private static func writeThumbs(asset: AVAsset, duration: Double, size: CGSize, out: URL) async throws -> Int {
        let folder = out.appendingPathComponent("thumbs")
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let count = max(1, Int((duration / thumbInterval + 1e-9).rounded(.down)) + 1)
        let generator = AVAssetImageGenerator(asset: asset)
        generator.appliesPreferredTrackTransform = true
        generator.requestedTimeToleranceBefore = .zero
        generator.requestedTimeToleranceAfter = .zero
        let height = max(1, Int((Double(thumbWidth) * size.height / max(1, size.width)).rounded()))
        // The picture can end a frame before the audio does; never ask for time past the last frame.
        var lastFrame = max(0, duration - 0.05)
        if let track = try await asset.loadTracks(withMediaType: .video).first {
            let (range, fps) = try await track.load(.timeRange, .nominalFrameRate)
            let frame = fps > 0 ? 1 / Double(fps) : 1.0 / 30
            lastFrame = max(0, min(lastFrame, range.end.seconds - frame / 2))
        }
        for i in 0..<count {
            let t = min(Double(i) * thumbInterval, lastFrame)
            let at = CMTime(seconds: t, preferredTimescale: 600)
            let frame: CGImage
            do { frame = try await generator.image(at: at).image } catch {
                // Fall back to the nearest frame rather than failing the whole copy.
                let loose = AVAssetImageGenerator(asset: asset)
                loose.appliesPreferredTrackTransform = true
                frame = try await loose.image(at: at).image
            }
            guard let ctx = CGContext(data: nil, width: thumbWidth, height: height, bitsPerComponent: 8, bytesPerRow: 0,
                                      space: CGColorSpace(name: CGColorSpace.sRGB)!,
                                      bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue) else { continue }
            ctx.interpolationQuality = .high
            ctx.draw(frame, in: CGRect(x: 0, y: 0, width: thumbWidth, height: height))
            guard let small = ctx.makeImage() else { continue }
            try writeImage(small, type: .jpeg, to: folder.appendingPathComponent(String(format: "%04d.jpg", i)),
                           options: [kCGImageDestinationLossyCompressionQuality: 0.72])
        }
        return count
    }

    // MARK: Paths

    /// A session-relative path as it is stored in the bundle: `/`-separated with no `..`. Files from a
    /// joined session's sources (`../2026-10-13_00-57-10/frames/001.jpg`) go under `sources/`.
    static func bundlePath(_ relative: String) -> String {
        var parts = relative.split(separator: "/").map(String.init).filter { $0 != "." && !$0.isEmpty }
        var outside = false
        while parts.first == ".." { parts.removeFirst(); outside = true }
        parts = parts.map { $0 == ".." ? "_" : $0.replacingOccurrences(of: "..", with: "_") }
        return ((outside ? ["sources"] : []) + parts).joined(separator: "/")
    }

    /// The folder name when it fits `^[A-Za-z0-9._-]{1,100}$`, otherwise a cleaned-up version of it.
    nonisolated static func sessionID(for session: URL) -> String {
        let allowed = Set("ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789._-")
        let cleaned = String(session.lastPathComponent.map { allowed.contains($0) ? $0 : "-" }.prefix(100))
        return cleaned.isEmpty || cleaned.allSatisfy({ $0 == "." }) ? "session" : cleaned
    }

    static func recordedAt(_ session: URL) -> String? {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd_HH-mm-ss"
        f.locale = Locale(identifier: "en_US_POSIX")
        let date = f.date(from: session.lastPathComponent)
            ?? (try? FileManager.default.attributesOfItem(atPath: session.path)[.creationDate] as? Date)
        guard let date else { return nil }
        let iso = ISO8601DateFormatter()
        iso.timeZone = .current
        iso.formatOptions = [.withInternetDateTime]
        return iso.string(from: date)
    }

    // MARK: Hashes

    /// What the cloud copy is built from. A different hash means the pushed copy is out of date.
    nonisolated static func inputHash(session: URL) throws -> String {
        let fm = FileManager.default
        // Bump "bundle-format" when the bundle's output changes for the same inputs, so copies already
        // pushed show as outdated and rebuild. 2: unedited videos are remuxed to fast start (moov first).
        // 3: laid out as an unedited session (play-order images, logs in edited time, annotations.json, machine).
        var lines = ["format \(format)", "bundle-format 3"]
        func stamp(_ url: URL) -> String {
            guard let a = try? fm.attributesOfItem(atPath: url.path) else { return "-" }
            let size = (a[.size] as? Int64) ?? 0
            let mtime = (a[.modificationDate] as? Date)?.timeIntervalSince1970 ?? 0
            return "\(size)@\(Int((mtime * 1000).rounded()))"
        }
        for name in ["session.json", "edits.json", "annotations.json", "session-info.json"] {
            let url = session.appendingPathComponent(name)
            lines.append("\(name) " + ((try? sha256(of: url)) ?? "-"))
        }
        // Every recording the edited video draws on.
        var sources = ["."]
        if let data = try? Data(contentsOf: EditsFile.url(session)),
           let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
           let segs = obj["segments"] as? [[String: Any]] {
            for s in segs { if let src = s["source"] as? String, !sources.contains(src) { sources.append(src) } }
        }
        for src in sources.sorted() {
            lines.append("recording \(src) " + stamp(EditMap.folder(of: src, in: session).appendingPathComponent("recording.mp4")))
        }
        // Marked-up images.
        let annotations = session.appendingPathComponent("annotations")
        for name in ((try? fm.contentsOfDirectory(atPath: annotations.path)) ?? []).sorted() where name.hasSuffix(".png") {
            lines.append("annotations/\(name) " + stamp(annotations.appendingPathComponent(name)))
        }
        return SHA256.hash(data: Data(lines.joined(separator: "\n").utf8)).map { String(format: "%02x", $0) }.joined()
    }

    nonisolated static func sha256(of url: URL) throws -> String {
        let handle = try FileHandle(forReadingFrom: url)
        defer { try? handle.close() }
        var hasher = SHA256()
        while let chunk = try handle.read(upToCount: 4 << 20), !chunk.isEmpty { hasher.update(data: chunk) }
        return hasher.finalize().map { String(format: "%02x", $0) }.joined()
    }

    /// Every file in the bundle except manifest.json and index.html, sorted by path.
    nonisolated static func listFiles(in out: URL) throws -> [CloudManifest.File] {
        let root = out.standardizedFileURL.resolvingSymlinksInPath().path + "/"
        var files: [CloudManifest.File] = []
        guard let walker = FileManager.default.enumerator(at: out, includingPropertiesForKeys: [.isRegularFileKey, .fileSizeKey]) else { return [] }
        for case let url as URL in walker {
            let values = try url.resourceValues(forKeys: [.isRegularFileKey, .fileSizeKey])
            guard values.isRegularFile == true else { continue }
            let full = url.standardizedFileURL.resolvingSymlinksInPath().path
            guard full.hasPrefix(root) else { continue }
            let path = String(full.dropFirst(root.count))
            if path == "manifest.json" || path == "index.html" || url.lastPathComponent == ".DS_Store" { continue }
            files.append(.init(path: path, size: Int64(values.fileSize ?? 0), sha256: try sha256(of: url), type: contentType(path)))
        }
        return files.sorted { $0.path < $1.path }
    }

    nonisolated static func contentType(_ path: String) -> String {
        switch (path as NSString).pathExtension.lowercased() {
        case "mp4": "video/mp4"
        case "json": "application/json"
        case "jsonl": "application/x-ndjson"
        case "png": "image/png"
        case "jpg", "jpeg": "image/jpeg"
        case "md": "text/markdown; charset=utf-8"
        case "mhtml", "mht": "multipart/related"
        case "html": "text/html; charset=utf-8"
        case "txt", "log": "text/plain; charset=utf-8"
        default: "application/octet-stream"
        }
    }

    // MARK: index.html

    /// viewer.html sits next to process_session.py (in the app's Resources, or scripts/ when run from
    /// the repo), the same template process_session.py's write_viewer() fills.
    nonisolated static func viewerTemplateURL() -> URL? {
        guard let url = RecorderController.processScriptURL()?.deletingLastPathComponent().appendingPathComponent("viewer.html"),
              FileManager.default.fileExists(atPath: url.path) else { return nil }
        return url
    }

    /// The viewer with `DATA` = the session plus `cloud: { manifest, drawings }`, for file:// playback.
    private static func writeIndex(session: [String: Any], manifest: CloudManifest, drawings: [CloudDrawing], to url: URL) throws {
        guard let template = viewerTemplateURL().flatMap({ try? String(contentsOf: $0, encoding: .utf8) }) else {
            throw ReviewError("viewer.html wasn't found")
        }
        let placeholder = "/*__SESSION_DATA__*/null"
        guard template.contains(placeholder) else { throw ReviewError("viewer.html has no data placeholder") }
        var payload = session
        payload["cloud"] = [
            "manifest": try JSONSerialization.jsonObject(with: try manifest.encoded()),
            "drawings": try JSONSerialization.jsonObject(with: try JSONEncoder().encode(drawings)),
        ]
        let json = String(decoding: try JSONSerialization.data(withJSONObject: payload, options: [.sortedKeys, .withoutEscapingSlashes]), as: UTF8.self)
            .replacingOccurrences(of: "</", with: "<\\/")
        try template.replacingOccurrences(of: placeholder, with: json).write(to: url, atomically: true, encoding: .utf8)
    }

    // MARK: Writing

    static func writeJSON(_ value: Any, to url: URL) throws {
        let data: Data
        if let encodable = value as? Encodable {
            let enc = JSONEncoder()
            enc.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
            data = try enc.encode(encodable)
        } else {
            data = try JSONSerialization.data(withJSONObject: value, options: [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes])
        }
        try data.write(to: url, options: .atomic)
    }

    static func writePNG(_ image: CGImage, to url: URL) throws { try writeImage(image, type: .png, to: url) }

    static func writeImage(_ image: CGImage, type: UTType, to url: URL, options: [CFString: Any] = [:]) throws {
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        guard let dest = CGImageDestinationCreateWithURL(url as CFURL, type.identifier as CFString, 1, nil) else {
            throw ReviewError("Couldn't write \(url.lastPathComponent)")
        }
        CGImageDestinationAddImage(dest, image, options as CFDictionary)
        guard CGImageDestinationFinalize(dest) else { throw ReviewError("Couldn't write \(url.lastPathComponent)") }
    }

    nonisolated static func round3(_ x: Double) -> Double { (x * 1000).rounded() / 1000 }
}
