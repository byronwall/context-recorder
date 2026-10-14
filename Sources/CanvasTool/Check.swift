import AVFoundation
import CanvasKit
import Foundation

/// Runs the analyzer on every fixture and checks the result against the clip's known answers.
enum Check {
    struct Result {
        var clip: String
        var doc: CanvasDocument
        var failures: [String]
        var notes: [String]
        var seconds: Double
    }

    static func run(root: URL, only: Set<String>?, options: CanvasAnalyzer.Options) async throws -> [Result] {
        var results: [Result] = []
        for clip in Fixtures.clips() where only?.contains(clip.name) ?? true {
            let folder = root.appendingPathComponent(clip.name)
            let truth = try JSONDecoder().decode(Fixtures.Truth.self, from: Data(contentsOf: folder.appendingPathComponent("truth.json")))
            let started = Date()
            let doc = try await CanvasAnalyzer.build(folder: folder, box: truth.box, options: options)
            let seconds = Date().timeIntervalSince(started)
            var failures: [String] = [], notes: [String] = []
            try await checkSeeks(doc, folder: folder, failures: &failures)
            checkStoryboard(doc, truth, failures: &failures)
            Geometry.check(doc, truth, failures: &failures, notes: &notes)
            results.append(Result(clip: clip.name, doc: doc, failures: failures, notes: notes, seconds: seconds))
        }
        return results
    }

    /// Every frame the canvas points at must be the frame a zero-tolerance seek to its `seekTime` shows.
    static func checkSeeks(_ doc: CanvasDocument, folder: URL, failures: inout [String]) async throws {
        let generator = AVAssetImageGenerator(asset: AVURLAsset(url: folder.appendingPathComponent(doc.video.file)))
        generator.requestedTimeToleranceBefore = .zero
        generator.requestedTimeToleranceAfter = .zero
        var refs = Set<FrameRef>()
        for item in doc.items {
            refs.insert(item.frame)
            // Spot-check patches: first, last and a few between.
            let step = max(1, item.patches.count / 5)
            for (i, p) in item.patches.enumerated() where i % step == 0 || i == item.patches.count - 1 { refs.insert(p.frame) }
        }
        for ref in refs.sorted(by: { $0.index < $1.index }) {
            let (image, actual) = try await generator.image(at: CMTime(seconds: ref.seekTime, preferredTimescale: 600))
            let shown = Fixtures.readBarcode(image)
            if shown != ref.index { failures.append("seek to frame \(ref.index) showed frame \(shown.map(String.init) ?? "?")") }
            if abs(actual.seconds - ref.time) > 0.0005 {
                failures.append("frame \(ref.index): time \(ref.time) but the seek landed at \(actual.seconds)")
            }
        }
    }

    static func checkStoryboard(_ doc: CanvasDocument, _ truth: Fixtures.Truth, failures: inout [String]) {
        let cards = doc.items.filter { $0.kind == .card }
        let starts = doc.items.map(\.frame.index)
        if let want = truth.expect.cardStarts, cards.map(\.frame.index) != want, doc.items.allSatisfy({ $0.kind == .card }) {
            failures.append("cards start at \(cards.map(\.frame.index)), expected \(want)")
        }
        if let want = truth.expect.cardCount, cards.count != want { failures.append("\(cards.count) cards, expected \(want)") }
        for f in truth.expect.mustStartAt ?? [] where !starts.contains(f) {
            failures.append("no item starts at frame \(f) (items start at \(starts))")
        }
        for (a, b) in zip(doc.items, doc.items.dropFirst()) where b.start < a.start {
            failures.append("items out of time order at \(b.id)")
        }
    }

    static func report(_ results: [Result]) -> Bool {
        func pad(_ s: String, _ n: Int) -> String { s.count >= n ? s : s + String(repeating: " ", count: n - s.count) }
        print(pad("clip", 15) + pad("items", 7) + pad("cards", 7) + pad("cols", 6) + pad("time", 8) + "result")
        for r in results {
            let cols = r.doc.items.filter { $0.kind == .column }.count
            print(pad(r.clip, 15) + pad("\(r.doc.items.count)", 7) + pad("\(r.doc.items.count - cols)", 7) + pad("\(cols)", 6)
                  + pad(String(format: "%.2fs", r.seconds), 8) + (r.failures.isEmpty ? "pass" : "FAIL"))
            for n in r.notes { print("    · \(n)") }
            for f in r.failures { print("    ✗ \(f)") }
        }
        let failed = results.filter { !$0.failures.isEmpty }.count
        print(failed == 0 ? "\nAll \(results.count) clips pass." : "\n\(failed) of \(results.count) clips fail.")
        return failed == 0
    }
}
