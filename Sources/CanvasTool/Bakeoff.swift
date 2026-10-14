import CanvasKit
import Foundation

/// Compares shift estimators on consecutive fixture frames with a true scroll in range.
enum Bakeoff {
    static func run(root: URL) async throws {
        let estimators: [any ShiftEstimator] = [RowProfileEstimator(), VisionEstimator()]
        var errors: [String: [Int]] = [:], seconds: [String: Double] = [:]
        var ambiguity: [String] = []
        for clip in Fixtures.clips() {
            let folder = root.appendingPathComponent(clip.name)
            let truth = try JSONDecoder().decode(Fixtures.Truth.self, from: Data(contentsOf: folder.appendingPathComponent("truth.json")))
            let source = try await FrameSource(url: folder.appendingPathComponent("recording.mp4"), box: truth.box)
            let rows = (truth.header)..<truth.box.height
            var prev: DecodedFrame?
            while let frame = try source.next() {
                defer { prev = frame }
                guard let p = prev else { continue }
                let i = frame.ref.index
                let d = truth.scrollY[i] - truth.scrollY[i - 1]
                guard d != 0, abs(d) < rows.count * 6 / 10, truth.pages[i] == truth.pages[i - 1] else { continue }
                for e in estimators {
                    let t0 = Date()
                    let est = e.estimate(p, frame, rows: rows)
                    seconds[e.name, default: 0] += Date().timeIntervalSince(t0)
                    let err = est.map { abs($0.shift - d) } ?? 9999
                    if clip.name == "repeated" || clip.name == "blank" {
                        if e.name == "row-profile", let est {
                            let ratio = (est.runnerUp ?? .infinity) / max(est.cost, 0.01)
                            ambiguity.append(String(format: "%@ f%d true %d est %d err %d cost %.2f runner %.2f ratio %.1f",
                                                    clip.name, i, d, est.shift, err, est.cost, est.runnerUp ?? -1, ratio))
                        }
                        continue   // ambiguous by design; scored separately
                    }
                    errors[e.name, default: []].append(err)
                }
            }
        }
        print("estimator     pairs  exact≤1px  p95   max    ms/pair")
        for e in estimators {
            let errs = (errors[e.name] ?? []).sorted()
            guard !errs.isEmpty else { continue }
            let exact = Double(errs.filter { $0 <= 1 }.count) / Double(errs.count)
            let p95 = errs[min(errs.count - 1, Int(Double(errs.count) * 0.95))]
            print(String(format: "%-13@ %-6d %-10.1f %-5d %-6d %.2f", e.name, errs.count, exact * 100, p95, errs.last!,
                         (seconds[e.name] ?? 0) * 1000 / Double(errs.count)))
        }
        print("\nrow-profile on ambiguous clips (repeated rows, blank):")
        for line in ambiguity.prefix(400) { print("  " + line) }
    }
}
