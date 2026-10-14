import CanvasKit
import Foundation

/// Checks joined columns against the true scroll positions.
///
/// In a correct column every patch shows page row `scrollY[frame] + sourceY` at `destY`, so
/// `scrollY[frame] + sourceY - destY` is the same for all of them: the page row at the column's top.
/// Any patch that disagrees by more than 4 px is a false join; the 95th-percentile error must stay within 2 px.
enum Geometry {
    static func check(_ doc: CanvasDocument, _ truth: Fixtures.Truth, failures: inout [String], notes: inout [String]) {
        let columns = doc.items.filter { $0.kind == .column }
        guard !columns.isEmpty else {
            if truth.expect.maxColumns != nil || truth.expect.mustRefuse != nil { notes.append("storyboard only; joining not checked") }
            return
        }
        var errors: [Int] = []
        var falseJoins = 0
        for col in columns {
            let patches = col.patches
            let offsets = patches.map { truth.scrollY[$0.frame.index] + $0.sourceY - $0.destY }
            guard let reference = median(offsets) else { continue }
            for (p, o) in zip(patches, offsets) {
                let e = abs(o - reference)
                errors.append(e)
                if e > 4 { falseJoins += 1; if falseJoins <= 3 { failures.append("\(col.id): frame \(p.frame.index) placed \(e) px off") } }
            }
            let variants = Set(col.patches.map { truth.pages[$0.frame.index] })
            if variants.count > 1 { failures.append("\(col.id) mixes page states \(variants.sorted())") }
            let frames = col.patches.map(\.frame.index)
            for pair in truth.expect.neverJoined ?? [] where pair.count == 2 {
                if let lo = frames.min(), let hi = frames.max(), lo <= pair[0], pair[1] <= hi {
                    failures.append("\(col.id) joins frames \(pair[0]) and \(pair[1]) across a break")
                }
            }
        }
        if falseJoins > 3 { failures.append("\(falseJoins) false joins in total") }

        // Hover and click: for rows across each column, the frame `frame(atImageY:)` returns must show that row
        // of the page inside the box when the video is at that frame.
        var mapped = 0, misses = 0
        for col in columns {
            let offsets = col.patches.map { truth.scrollY[$0.frame.index] + $0.sourceY - $0.destY }
            guard let top = median(offsets) else { continue }
            for i in 0..<25 {
                let y = Double(col.height - 1) * Double(i) / 24
                let f = col.frame(atImageY: y)
                let pageRow = top + Int(y)
                let visible = truth.scrollY[f.index]..<(truth.scrollY[f.index] + truth.box.height)
                mapped += 1
                if !visible.contains(pageRow) {
                    misses += 1
                    if misses <= 2 { failures.append("\(col.id): row \(Int(y)) maps to frame \(f.index), which doesn't show it") }
                }
            }
        }
        notes.append("row → frame mapping: \(mapped - misses)/\(mapped) rows land on a frame that shows them")
        let sorted = errors.sorted()
        let p95 = sorted.isEmpty ? 0 : sorted[min(sorted.count - 1, Int(Double(sorted.count) * 0.95))]
        notes.append("patches \(errors.count), p95 error \(p95) px, max \(sorted.last ?? 0) px")
        if p95 > 2 { failures.append("p95 error \(p95) px > 2 px") }
        if let max = truth.expect.maxColumns, columns.count > max { failures.append("\(columns.count) columns, expected at most \(max)") }
        if truth.expect.mustRefuse == true,
           !doc.items.contains(where: { $0.reason == .ambiguous || $0.reason == .noOverlap }) {
            failures.append("expected a refused join (ambiguous or no overlap)")
        }
    }

    private static func median(_ xs: [Int]) -> Int? {
        guard !xs.isEmpty else { return nil }
        return xs.sorted()[xs.count / 2]
    }
}
