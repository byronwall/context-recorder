import AVFoundation
import Foundation

/// A kept range of a source recording. `source` is "." for the session's own recording, or a folder path
/// relative to the session (a joined session's sources). Times are seconds into that source's video.
struct Segment: Codable, Hashable {
    var source: String
    var start: Double
    var end: Double
    /// Where the segment begins in the edited video. Filled in by `EditMap`; written by process_session.py.
    var editedStart: Double?

    var length: Double { end - start }

    enum CodingKeys: String, CodingKey { case source, start, end, editedStart }

    init(source: String = ".", start: Double, end: Double, editedStart: Double? = nil) {
        self.source = source; self.start = start; self.end = end; self.editedStart = editedStart
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        source = try c.decodeIfPresent(String.self, forKey: .source) ?? "."
        start = try c.decode(Double.self, forKey: .start)
        end = try c.decode(Double.self, forKey: .end)
        editedStart = try c.decodeIfPresent(Double.self, forKey: .editedStart)
    }
}

/// An edited session: segments in play order. Maps between edited time (what the player and every view
/// use) and source time (what the raw files under the session store). The same rules live in
/// scripts/process_session.py; scripts/fixtures/edit-cases.json keeps the two in step.
struct EditMap: Equatable {
    private(set) var segments: [Segment]

    init(_ segments: [Segment]) {
        var at = 0.0
        self.segments = segments.map { s in
            var s = s
            s.editedStart = at
            at += s.length
            return s
        }
    }

    /// Same kept ranges, ignoring how editedStart was rounded (Swift vs process_session.py).
    static func == (a: EditMap, b: EditMap) -> Bool {
        a.segments.count == b.segments.count && zip(a.segments, b.segments).allSatisfy {
            $0.source == $1.source && abs($0.start - $1.start) < 1e-6 && abs($0.end - $1.end) < 1e-6
        }
    }

    var duration: Double { segments.reduce(0) { $0 + $1.length } }
    var sources: [String] { segments.reduce(into: []) { if !$0.contains($1.source) { $0.append($1.source) } } }

    /// Edited time for a source time, or nil when that moment was cut.
    func toEdited(source: String = ".", _ t: Double) -> Double? {
        for s in segments where s.source == source && s.start <= t && t <= s.end {
            return (s.editedStart ?? 0) + t - s.start
        }
        return nil
    }

    /// Edited time for a source time; a cut moment lands on the start of the next kept range.
    func nearestEdited(source: String = ".", _ t: Double) -> Double {
        if let e = toEdited(source: source, t) { return e }
        let next = segments.first { $0.source == source && $0.start > t }
        return next?.editedStart ?? min(duration, max(0, t))
    }

    /// The source and source time under an edited time, clamped to the ends.
    func toSource(_ edited: Double) -> (source: String, time: Double) {
        guard let last = segments.last else { return (".", edited) }
        for s in segments where edited < (s.editedStart ?? 0) + s.length {
            return (s.source, s.start + max(0, edited - (s.editedStart ?? 0)))
        }
        return (last.source, last.end)
    }

    // MARK: Editing (pure; the model writes the result to edits.json)

    /// A removed range of one source, shown on the timeline where its neighbours now meet.
    struct Cut: Hashable, Identifiable {
        var source: String
        var start: Double
        var end: Double
        /// Where the cut sits in the edited video.
        var editedAt: Double
        var id: String { "\(source)@\(start)" }
        var length: Double { end - start }
    }

    /// Kept ranges shorter than this are dropped rather than left as a flash of video.
    static let minimumSegment = 0.1

    /// The segments left after removing edited range a…b.
    func removing(editedFrom a: Double, to b: Double) -> [Segment] {
        let lo = min(a, b), hi = max(a, b)
        var out: [Segment] = []
        for s in segments {
            let es = s.editedStart ?? 0, ee = es + s.length
            if hi <= es || lo >= ee { out.append(s); continue }
            if lo > es { out.append(Segment(source: s.source, start: s.start, end: s.start + (lo - es))) }
            if hi < ee { out.append(Segment(source: s.source, start: s.start + (hi - es), end: s.end)) }
        }
        return Self.tidy(out)
    }

    /// Every removed range: before, between and after each source's kept ranges.
    func cuts(sourceDurations: [String: Double]) -> [Cut] {
        var out: [Cut] = []
        for source in sources {
            let kept = segments.filter { $0.source == source }
            var at = 0.0
            for s in kept {
                if s.start - at > 0.05 { out.append(Cut(source: source, start: at, end: s.start, editedAt: s.editedStart ?? 0)) }
                at = s.end
            }
            if let full = sourceDurations[source], full - at > 0.05, let last = kept.last {
                out.append(Cut(source: source, start: at, end: full, editedAt: (last.editedStart ?? 0) + last.length))
            }
        }
        return out.sorted { $0.editedAt < $1.editedAt }
    }

    /// The segments with one cut put back next to its neighbours.
    func restoring(_ cut: Cut) -> [Segment] {
        var out = segments.map { Segment(source: $0.source, start: $0.start, end: $0.end) }
        let restored = Segment(source: cut.source, start: cut.start, end: cut.end)
        if let i = out.lastIndex(where: { $0.source == cut.source && $0.end <= cut.start + 0.001 }) {
            out.insert(restored, at: i + 1)
        } else if let i = out.firstIndex(where: { $0.source == cut.source }) {
            out.insert(restored, at: i)
        } else {
            out.append(restored)
        }
        return Self.tidy(out)
    }

    /// True when the segments are the whole of the session's own recording, i.e. nothing is edited.
    static func isUnedited(_ segments: [Segment], sourceDurations: [String: Double]) -> Bool {
        guard segments.count == 1, let s = segments.first, s.source == ".", let full = sourceDurations["."] else { return false }
        return s.start < 0.05 && abs(s.end - full) < 0.05
    }

    /// Drops slivers and merges ranges of the same source that now meet.
    private static func tidy(_ segments: [Segment]) -> [Segment] {
        var out: [Segment] = []
        for s in segments where s.length >= minimumSegment {
            if let last = out.last, last.source == s.source, abs(last.end - s.start) < 0.001 {
                out[out.count - 1].end = s.end
            } else {
                out.append(Segment(source: s.source, start: s.start, end: s.end))
            }
        }
        return out
    }

    static func folder(of source: String, in session: URL) -> URL {
        source == "." ? session : session.appendingPathComponent(source).standardizedFileURL
    }

    /// The edited video: each segment's range of its source, back to back on one video and one audio
    /// track. Sources of different sizes (a joined session) get a video composition that fits each one
    /// into the largest frame; sources without audio play silence.
    struct Playback {
        var asset: AVComposition
        var videoComposition: AVVideoComposition?
    }

    func composition(in session: URL) async throws -> Playback {
        let composition = AVMutableComposition()
        guard let video = composition.addMutableTrack(withMediaType: .video, preferredTrackID: kCMPersistentTrackID_Invalid),
              let audio = composition.addMutableTrack(withMediaType: .audio, preferredTrackID: kCMPersistentTrackID_Invalid) else {
            throw ReviewError("Couldn't create the edited video")
        }
        struct Source {
            var asset: AVURLAsset   // tracks only hold their asset weakly; keep it alive while inserting
            var video: AVAssetTrack; var audio: AVAssetTrack?
            var videoRange: CMTimeRange; var audioRange: CMTimeRange?
            var size: CGSize; var transform: CGAffineTransform
        }
        var sources: [String: Source] = [:]
        var placed: [(range: CMTimeRange, source: Source)] = []
        var at = CMTime.zero
        for s in segments {
            if sources[s.source] == nil {
                let url = Self.folder(of: s.source, in: session).appendingPathComponent("recording.mp4")
                guard FileManager.default.fileExists(atPath: url.path) else {
                    throw ReviewError("Source missing: \(s.source)")
                }
                let asset = AVURLAsset(url: url)
                guard let track = try await asset.loadTracks(withMediaType: .video).first else {
                    throw ReviewError("\(s.source) has no video")
                }
                let (size, transform, videoRange) = try await track.load(.naturalSize, .preferredTransform, .timeRange)
                let audio = try await asset.loadTracks(withMediaType: .audio).first
                let audioRange = try await audio?.load(.timeRange)
                sources[s.source] = Source(asset: asset, video: track, audio: audio, videoRange: videoRange, audioRange: audioRange,
                                           size: size, transform: transform)
            }
            guard let source = sources[s.source] else { continue }
            // Tracks can end a little before the file does; never ask for time a track doesn't have.
            let wanted = CMTimeRange(start: CMTime(seconds: s.start, preferredTimescale: 600),
                                     end: CMTime(seconds: s.end, preferredTimescale: 600))
            let range = wanted.intersection(source.videoRange)
            guard range.duration > .zero else { continue }
            do {
                try video.insertTimeRange(range, of: source.video, at: at)
                if let track = source.audioRange.map({ range.intersection($0) }), track.duration > .zero, let a = source.audio {
                    try audio.insertTimeRange(track, of: a, at: at + (track.start - range.start))
                }
            } catch {
                throw ReviewError("\(s.source) \(Int(s.start))–\(Int(s.end)) s: \(error.localizedDescription)")
            }
            placed.append((CMTimeRange(start: at, duration: range.duration), source))
            at = at + range.duration
        }
        if audio.segments.isEmpty { composition.removeTrack(audio) }

        let sizes = Set(placed.map { "\($0.source.size.width)x\($0.source.size.height)" })
        guard sizes.count > 1 else {
            video.preferredTransform = placed.first?.source.transform ?? .identity
            return Playback(asset: composition, videoComposition: nil)
        }
        // Fit every source into the largest frame, centred.
        let render = placed.reduce(CGSize.zero) { CGSize(width: max($0.width, $1.source.size.width), height: max($0.height, $1.source.size.height)) }
        let instructions = placed.map { item -> AVVideoCompositionInstruction in
            let size = item.source.size
            let scale = min(render.width / size.width, render.height / size.height)
            let fitted = item.source.transform
                .concatenating(CGAffineTransform(scaleX: scale, y: scale))
                .concatenating(CGAffineTransform(translationX: (render.width - size.width * scale) / 2,
                                                 y: (render.height - size.height * scale) / 2))
            var layer = AVVideoCompositionLayerInstruction.Configuration(assetTrack: video)
            layer.setTransform(fitted, at: item.range.start)
            return AVVideoCompositionInstruction(configuration: .init(
                backgroundColor: CGColor(gray: 0, alpha: 1),
                layerInstructions: [AVVideoCompositionLayerInstruction(configuration: layer)],
                timeRange: item.range))
        }
        let videoComposition = AVVideoComposition(configuration: .init(
            frameDuration: CMTime(value: 1, timescale: 30),
            instructions: instructions,
            renderSize: render))
        return Playback(asset: composition, videoComposition: videoComposition)
    }
}

/// `--self-test edits`: runs the shared cases in scripts/fixtures/edit-cases.json against `EditMap`.
enum EditSelfTest {
    static func run(fixture: URL) -> [String] {
        struct File: Decodable { var cases: [Case] }
        struct Case: Decodable {
            var name: String
            var segments: [Segment]
            var duration: Double
            var toEdited: [[JSONValue]]
            var toSource: [[JSONValue]]
        }
        guard let data = try? Data(contentsOf: fixture), let file = try? JSONDecoder().decode(File.self, from: data) else {
            return ["couldn't read \(fixture.path)"]
        }
        var failures: [String] = []
        func near(_ a: Double, _ b: Double) -> Bool { abs(a - b) < 1e-6 }
        for c in file.cases {
            let map = EditMap(c.segments)
            if !near(map.duration, c.duration) { failures.append("\(c.name): duration \(map.duration) ≠ \(c.duration)") }
            for row in c.toEdited {
                guard row.count == 3, let source = row[0].stringValue, let t = row[1].numberValue else { continue }
                let got = map.toEdited(source: source, t)
                let want = row[2].numberValue
                if (got == nil) != (want == nil) || (got.map { !near($0, want ?? .nan) } ?? false) {
                    failures.append("\(c.name): toEdited(\(source), \(t)) = \(String(describing: got)), want \(String(describing: want))")
                }
            }
            for row in c.toSource {
                guard row.count == 3, let edited = row[0].numberValue, let source = row[1].stringValue, let t = row[2].numberValue else { continue }
                let got = map.toSource(edited)
                if got.source != source || !near(got.time, t) {
                    failures.append("\(c.name): toSource(\(edited)) = \(got), want (\(source), \(t))")
                }
            }
        }
        // Swift-only cases: cutting and restoring.
        struct Ops: Decodable { var removeCases: [Remove]; var restoreCases: [Restore] }
        struct Remove: Decodable { var name: String; var segments: [Segment]; var remove: [Double]; var expect: [Segment] }
        struct Restore: Decodable { var name: String; var segments: [Segment]; var durations: [String: Double]; var cuts: Int; var restore: Int; var expect: [Segment] }
        if let ops = try? JSONDecoder().decode(Ops.self, from: data) {
            func same(_ a: [Segment], _ b: [Segment]) -> Bool {
                a.count == b.count && zip(a, b).allSatisfy { $0.source == $1.source && near($0.start, $1.start) && near($0.end, $1.end) }
            }
            for c in ops.removeCases {
                let got = EditMap(c.segments).removing(editedFrom: c.remove[0], to: c.remove[1])
                if !same(got, c.expect) { failures.append("\(c.name): removing → \(got)") }
            }
            for c in ops.restoreCases {
                let map = EditMap(c.segments)
                let cuts = map.cuts(sourceDurations: c.durations)
                if cuts.count != c.cuts { failures.append("\(c.name): \(cuts.count) cuts, want \(c.cuts)"); continue }
                let got = map.restoring(cuts[c.restore])
                if !same(got, c.expect) { failures.append("\(c.name): restoring → \(got)") }
            }
        } else {
            failures.append("removeCases/restoreCases missing")
        }
        return failures
    }
}

// MARK: - Editing a session

/// Cutting from the timeline. Every change writes edits.json, swaps the video straight away and then
/// re-processes so marks, narration and the lanes follow (the same path review marks use).
extension SessionModel {
    /// The kept ranges right now; the whole recording when unedited.
    var currentSegments: [Segment] {
        if let edits { return edits.segments }
        if let s = data?.segments, !s.isEmpty { return s }
        return [Segment(start: 0, end: duration)]   // processed before edits existed
    }

    var sourceDurations: [String: Double] {
        if let d = data?.sourceDurations, !d.isEmpty { return d }
        return edits == nil ? [".": duration] : [:]
    }

    /// Removed ranges, for the markers on the timeline.
    var cuts: [EditMap.Cut] { edits?.cuts(sourceDurations: sourceDurations) ?? [] }

    /// Marks that a cut hides, so its marker can say what restoring brings back.
    func hiddenMarks(in cut: EditMap.Cut) -> [SessionMark] {
        (data?.hiddenMarks ?? []).filter { ($0.sourceSession ?? ".") == cut.source && $0.originalOffset >= cut.start && $0.originalOffset <= cut.end }
    }

    /// I and O: set one end of the selection at the playhead.
    func setSelectionEdge(start: Bool) {
        let t = currentTime
        if start {
            let end = max(t, selection?.upperBound ?? duration)
            selection = t...end
        } else {
            let begin = min(t, selection?.lowerBound ?? 0)
            selection = begin...t
        }
    }

    /// Delete: remove the selected range.
    func cutSelection() {
        guard let range = selection, range.upperBound - range.lowerBound >= 0.1 else { return }
        let next = EditMap(currentSegments).removing(editedFrom: range.lowerBound, to: range.upperBound)
        guard !next.isEmpty else { reviewError = "That would cut the whole recording."; return }
        apply(next)
        seek(range.lowerBound)
    }

    func restore(_ cut: EditMap.Cut) {
        apply(EditMap(currentSegments).restoring(cut))
    }

    /// A joined session keeps its sources, each whole again; any other session drops edits.json.
    func restoreOriginal() {
        guard let edits else { return }
        if isJoined {
            apply(edits.sources.compactMap { source in sourceDurations[source].map { Segment(source: source, start: 0, end: $0) } })
        } else {
            apply(nil)
        }
    }

    var isJoined: Bool { currentSegments.contains { $0.source != "." } }

    /// Where the video moves from one source session to the next, for the timeline.
    var sourceBoundaries: [(at: Double, source: String)] {
        guard isJoined, let edits else { return [] }
        var out: [(Double, String)] = []
        var previous: String?
        for s in edits.segments where s.source != previous {
            out.append((s.editedStart ?? 0, s.source))
            previous = s.source
        }
        return out
    }

    var canUndoEdit: Bool { !undoStack.isEmpty }
    var canRedoEdit: Bool { !redoStack.isEmpty }

    func undoEdit() {
        guard let previous = undoStack.popLast() else { return }
        redoStack.append(edits?.segments)
        apply(previous, recordUndo: false)
    }

    func redoEdit() {
        guard let next = redoStack.popLast() else { return }
        undoStack.append(edits?.segments)
        apply(next, recordUndo: false)
    }

    /// Writes the cut list (nil, or the whole recording, deletes edits.json) and updates everything.
    private func apply(_ segments: [Segment]?, recordUndo: Bool = true) {
        // Millisecond times, exactly as edits.json stores them, so the reload after processing matches.
        let rounded = segments?.map { Segment(source: $0.source, start: ($0.start * 1000).rounded() / 1000, end: ($0.end * 1000).rounded() / 1000) }
        let unedited = rounded.map { EditMap.isUnedited($0, sourceDurations: sourceDurations) } ?? true
        let next = unedited ? nil : rounded
        guard next.map(EditMap.init) != edits else { return }
        if recordUndo {
            undoStack.append(edits?.segments)
            redoStack = []
        }
        selection = nil
        do {
            try EditsFile.save(next, to: folder)
        } catch {
            reviewError = "edits.json couldn't be saved: \(error.localizedDescription)"
            return
        }
        setEdits(next.map(EditMap.init))
        Task {
            reviewStatus = "Updating…"
            defer { reviewStatus = nil }
            do { try await reprocess() } catch { reviewError = error.localizedDescription }
        }
    }
}

/// edits.json on disk: only the kept ranges (process_session.py adds editedStart in session.json).
enum EditsFile {
    static func url(_ folder: URL) -> URL { folder.appendingPathComponent("edits.json") }

    static func save(_ segments: [Segment]?, to folder: URL) throws {
        guard let segments else {
            try? FileManager.default.removeItem(at: url(folder))
            return
        }
        struct File: Encodable { var segments: [Segment] }
        let plain = segments.map { Segment(source: $0.source, start: ($0.start * 1000).rounded() / 1000, end: ($0.end * 1000).rounded() / 1000) }
        let enc = JSONEncoder()
        enc.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        try enc.encode(File(segments: plain)).write(to: url(folder), options: .atomic)
    }
}

// MARK: - Joining sessions

enum SessionJoin {
    /// Makes a new session that plays `sessions` end to end (oldest first), next to the first of them.
    /// It has no video of its own: edits.json points at each source's kept ranges, so cuts already made
    /// in a source carry over, and the sources are never changed.
    static func join(_ sessions: [URL]) throws -> URL {
        let ordered = sessions.sorted { $0.lastPathComponent < $1.lastPathComponent }
        guard ordered.count >= 2, let parent = ordered.first?.deletingLastPathComponent() else {
            throw ReviewError("Select two or more sessions to join.")
        }
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd_HH-mm-ss"
        f.locale = Locale(identifier: "en_US_POSIX")
        var date = Date.now
        var folder = parent.appendingPathComponent(f.string(from: date))
        while FileManager.default.fileExists(atPath: folder.path) {
            date += 1
            folder = parent.appendingPathComponent(f.string(from: date))
        }

        var segments: [Segment] = []
        for source in ordered {
            guard let data = try? Data(contentsOf: source.appendingPathComponent("session.json")),
                  let session = try? JSONDecoder().decode(SessionData.self, from: data) else {
                throw ReviewError("\(SessionTitle.title(for: source)) hasn't been processed yet.")
            }
            let kept = session.segments.isEmpty ? [Segment(start: 0, end: session.duration ?? 0)] : session.segments
            for s in kept {
                let target = EditMap.folder(of: s.source, in: source)
                segments.append(Segment(source: relativePath(from: folder, to: target), start: s.start, end: s.end))
            }
        }

        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: false)
        try EditsFile.save(segments, to: folder)
        let names = ordered.map { SessionInfo.title($0) ?? String(SessionTitle.title(for: $0).split(separator: "·").last ?? "").trimmingCharacters(in: .whitespaces) }
        try SessionInfo.setTitle("Joined: " + names.joined(separator: " + "), for: folder)
        return folder
    }

    /// "../2026-10-13_00-57-10" for a sibling folder; works across any two folders.
    static func relativePath(from base: URL, to target: URL) -> String {
        let a = base.standardizedFileURL.pathComponents, b = target.standardizedFileURL.pathComponents
        var common = 0
        while common < min(a.count, b.count), a[common] == b[common] { common += 1 }
        let up = Array(repeating: "..", count: a.count - common)
        let parts = up + b[common...]
        return parts.isEmpty ? "." : parts.joined(separator: "/")
    }
}
