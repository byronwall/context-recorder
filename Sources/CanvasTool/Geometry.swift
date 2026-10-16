import CanvasKit
import Foundation

/// Checks joined columns against the true scroll positions.
///
/// The analyzer sees the whole screen, so a patch's rows are screen rows (`doc.box.y + sourceY`). In a correct
/// column every patch shows page row `scrollY[frame] + screenRow - truth.box.y` at `destY`, so that minus `destY`
/// is the same for all of them: the page row at the column's top. Any patch that disagrees by more than 4 px is a
/// false join; the 95th-percentile error must stay within 2 px.
enum Geometry {
    static func check(_ doc: CanvasDocument, _ truth: Fixtures.Truth, joining: Bool = true,
                      failures: inout [String], notes: inout [String]) {
        let columns = doc.items.filter { $0.kind == .column }
        /// The page row behind screen row `y` in frame `f`.
        func pageRow(_ f: FrameRef, screenY y: Int) -> Int { truth.scrollY[f.index] + y - truth.box.y }
        /// The page row at the top of a column, from each patch.
        func offsets(_ col: CanvasItem) -> [Int] { col.patches.map { pageRow($0.frame, screenY: doc.box.y + $0.sourceY) - $0.destY } }
        /// Page rows a frame shows below any fixed header.
        func visible(_ f: FrameRef) -> Range<Int> { (truth.scrollY[f.index] + truth.header)..<(truth.scrollY[f.index] + truth.box.height) }

        guard !columns.isEmpty else {
            if !joining {
                if truth.expect.maxColumns != nil || truth.expect.mustRefuse != nil { notes.append("storyboard only; joining not checked") }
            } else if truth.expect.minCoverage != nil {
                failures.append("no columns: the scrolling page was never reconstructed")
            }
            return
        }
        var errors: [Int] = []
        var falseJoins = 0
        for col in columns {
            let offs = offsets(col)
            guard let reference = median(offs) else { continue }
            for (p, o) in zip(col.patches, offs) {
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
            // A column is the page: it must not carry a stationary sidebar or rail along with it.
            let x0 = doc.box.x + (col.sourceX ?? 0), x1 = x0 + col.width
            for f in truth.fixed {
                let overlap = min(x1, f.maxX) - max(x0, f.x)
                if overlap > 16 { failures.append("\(col.id) spans x \(x0)..<\(x1), \(overlap) px into stationary chrome at x \(f.x)..<\(f.maxX)") }
            }
        }
        if falseJoins > 3 { failures.append("\(falseJoins) false joins in total") }

        // Hover and click: for rows across each column, the frame `frame(atImageY:)` returns must show that row
        // of the page when the video is at that frame.
        var mapped = 0, misses = 0
        for col in columns {
            guard let top = median(offsets(col)) else { continue }
            for i in 0..<25 {
                let y = Double(col.height - 1) * Double(i) / 24
                let f = col.frame(atImageY: y)
                let row = top + Int(y)
                mapped += 1
                // Rows above the page (a column can start with the top of the first frame) show what they show.
                if row < truth.header { continue }
                if !visible(f).contains(row) {
                    misses += 1
                    if misses <= 2 { failures.append("\(col.id): row \(Int(y)) maps to frame \(f.index), which doesn't show it") }
                }
            }
        }
        notes.append("row → frame mapping: \(mapped - misses)/\(mapped) rows land on a frame that shows them")

        // Following the playhead: at each patch's moment, the column's recorded view must be where those rows are.
        var poses = 0, poseMisses = 0
        for col in columns {
            for p in col.patches {
                let v = col.viewport(at: p.frame.time)
                poses += 1
                // Bands vary a few rows from pair to pair; the middle of what a frame supplied must be in its view.
                if !v.contains(Double(p.destY) + Double(p.height) / 2) {
                    poseMisses += 1
                    if poseMisses <= 2 { failures.append("\(col.id): at frame \(p.frame.index) the view is \(v) but rows \(p.destY)..<\(p.destY + p.height) came from it") }
                }
            }
        }
        notes.append("playhead → view: \(poses - poseMisses)/\(poses) patches inside the view recorded at their moment")

        // Marks from the canvas: a selection maps to a video region of one frame that shows the same page rows.
        var regions = 0, regionMisses = 0
        for col in columns {
            guard let top = median(offsets(col)) else { continue }
            for i in 0..<10 {
                let y = Double(max(0, col.height - 200)) * Double(i) / 9
                let sel = CGRect(x: 50, y: y, width: min(300, Double(col.width) - 60), height: 180)
                guard let (f, r) = col.sourceRegion(for: sel, box: doc.box) else { continue }
                regions += 1
                // Seen in frame f, the region's top row is a page row. It must be the selection's top page row,
                // unless the selection was clipped to the frame's top edge. It must stay inside the document and
                // never reach past the selection.
                let shownRow = pageRow(f, screenY: Int(r.minY))
                let wanted = top + Int(sel.minY)
                let clippedAtTop = shownRow > wanted && Int(r.minY) <= truth.box.y + truth.header + 4
                let inBox = r.minY >= Double(truth.box.y) && r.maxY <= Double(truth.box.maxY)
                    && r.minX >= Double(truth.box.x) - 32 && r.maxX <= Double(truth.box.maxX) + 32
                let withinSelection = shownRow >= wanted && shownRow + Int(r.height) <= top + Int(sel.maxY)
                if !(shownRow == wanted || clippedAtTop) || !inBox || !withinSelection {
                    regionMisses += 1
                    if regionMisses <= 2 { failures.append("\(col.id): selection at \(Int(y)) maps to \(r) in frame \(f.index)") }
                }
            }
        }
        notes.append("canvas → video regions: \(regions - regionMisses)/\(regions) correct")
        let sorted = errors.sorted()
        let p95 = sorted.isEmpty ? 0 : sorted[min(sorted.count - 1, Int(Double(sorted.count) * 0.95))]
        notes.append("patches \(errors.count), p95 error \(p95) px, max \(sorted.last ?? 0) px")
        if p95 > 2 { failures.append("p95 error \(p95) px > 2 px") }
        if let max = truth.expect.maxColumns, columns.count > max { failures.append("\(columns.count) columns, expected at most \(max)") }
        if truth.expect.mustRefuse == true,
           !doc.items.contains(where: { $0.reason == .ambiguous || $0.reason == .noOverlap }) {
            failures.append("expected a refused join (ambiguous or no overlap)")
        }
        if let want = truth.expect.minCoverage {
            var missing: [String] = []
            let c = coverage(doc, truth, columns: columns, missing: &missing)
            notes.append(String(format: "coverage %.1f%% of observed document area, correctly placed", c * 100)
                         + (missing.isEmpty ? "" : "; missing rows " + missing.prefix(4).joined(separator: ", ")))
            if c < want { failures.append(String(format: "coverage %.1f%% < %.0f%%", c * 100, want * 100)) }
        }
    }

    /// Correctly placed document area in columns over document area the recording showed. A page row counts by
    /// the share of the document's width its column covers; rows under a fixed header were never observed.
    /// Rows a patch placed more than 4 px off don't count, so a false join can't buy coverage.
    static func coverage(_ doc: CanvasDocument, _ truth: Fixtures.Truth, columns: [CanvasItem]) -> Double {
        var unused: [String] = []
        return coverage(doc, truth, columns: columns, missing: &unused)
    }

    static func coverage(_ doc: CanvasDocument, _ truth: Fixtures.Truth, columns: [CanvasItem], missing: inout [String]) -> Double {
        var observed: [String: Set<Int>] = [:]
        for (i, y) in truth.scrollY.enumerated() {
            observed[truth.pages[i], default: []].formUnion((y + truth.header)..<(y + truth.box.height))
        }
        var covered: [String: [Int: Double]] = [:]
        for col in columns {
            let x0 = doc.box.x + (col.sourceX ?? 0), x1 = x0 + col.width
            let share = Double(max(0, min(x1, truth.box.maxX) - max(x0, truth.box.x))) / Double(truth.box.width)
            let offs = col.patches.map { truth.scrollY[$0.frame.index] + doc.box.y + $0.sourceY - truth.box.y - $0.destY }
            guard let reference = median(offs) else { continue }
            for (p, o) in zip(col.patches, offs) where abs(o - reference) <= 4 {
                let variant = truth.pages[p.frame.index]
                let screenTop = doc.box.y + p.sourceY
                for r in 0..<p.height {
                    let screenY = screenTop + r
                    guard screenY >= truth.box.y + truth.header, screenY < truth.box.maxY else { continue }
                    let row = truth.scrollY[p.frame.index] + screenY - truth.box.y
                    covered[variant, default: [:]][row] = max(covered[variant]?[row] ?? 0, share)
                }
            }
        }
        var total = 0.0, seen = 0
        missing = []
        for (variant, rows) in observed {
            seen += rows.count
            var gapStart: Int?, last = Int.min
            for r in rows.sorted() {
                let share = covered[variant]?[r] ?? 0
                total += share
                if let g = gapStart, share > 0 || r != last + 1 { missing.append("\(variant) \(g)..<\(last + 1)"); gapStart = nil }
                if share == 0, gapStart == nil { gapStart = r }
                last = r
            }
            if let g = gapStart { missing.append("\(variant) \(g)..<\(last + 1)") }
        }
        return seen == 0 ? 1 : total / Double(seen)
    }

    private static func median(_ xs: [Int]) -> Int? {
        guard !xs.isEmpty else { return nil }
        return xs.sorted()[xs.count / 2]
    }
}
