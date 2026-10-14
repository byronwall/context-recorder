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

    /// The edited video as one asset: each segment's range of its source, back to back.
    func composition(in session: URL) async throws -> AVComposition {
        let composition = AVMutableComposition()
        var assets: [String: AVURLAsset] = [:]
        var at = CMTime.zero
        for s in segments {
            let asset = assets[s.source] ?? AVURLAsset(url: Self.folder(of: s.source, in: session).appendingPathComponent("recording.mp4"))
            assets[s.source] = asset
            let available = try await asset.load(.duration)
            let start = CMTime(seconds: s.start, preferredTimescale: 600)
            let end = CMTimeMinimum(CMTime(seconds: s.end, preferredTimescale: 600), available)
            guard end > start else { continue }
            let range = CMTimeRange(start: start, end: end)
            try await composition.insertTimeRange(range, of: asset, at: at)
            at = at + range.duration
        }
        return composition
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

    func restoreOriginal() {
        guard edits != nil else { return }
        apply(nil)
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
