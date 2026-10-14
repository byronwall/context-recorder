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
        return failures
    }
}
