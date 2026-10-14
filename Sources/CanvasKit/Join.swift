import Foundation

public struct JoinSettings: Sendable {
    /// A join is ambiguous when another shift fits within this many gray levels of the best one.
    public var ambiguityMargin = 0.12
    /// After alignment, at most this share of overlap pixels may differ (pointer, caret, compression)…
    public var maxResidual = 0.008
    /// …a pixel differs when it moves by more than this.
    public var pixelDelta = 32
    /// Below this share the frames still line up and something on the page changed; above it nothing lines up.
    public var changeResidual = 0.05
    /// The overlap must include this many rows with visible detail; blank space proves nothing.
    public var minDetailRows = 12
    /// A fixed header or footer (rows identical in both frames while the rest moves) may be at most this share.
    public var maxFixedShare = 0.4
    /// A still view whose only change is about this many pixels (a moving pointer) is the same view.
    public var ignorePixels = 600
    /// Columns end here and continue in the next one.
    public var maxColumnHeight = 16_000

    public init() {}
}

enum JoinResult: Equatable {
    /// Nothing that matters moved: only a pointer or caret.
    case same
    /// The content scrolled by `shift` rows; `fixedTop`/`fixedBottom` rows stayed put (header, footer).
    /// `cols` is the part that scrolls when a sidebar inside the box stays put.
    case shift(Int, fixedTop: Int, fixedBottom: Int, cols: Range<Int>)
    /// The frames line up but the content changed (an edit, a new page with the same layout).
    case change
    /// Nothing lines up within the overlap: a jump, a new page.
    case noOverlap
    /// More than one distance fits: repeated rows or blank space.
    case ambiguous
}

struct Joiner {
    static let debug = ProcessInfo.processInfo.environment["CANVAS_DEBUG"] != nil
    let settings: JoinSettings
    /// nil: cards only; frames are compared in place.
    let estimator: (any ShiftEstimator)?

    /// `cols`: the scrolling columns found earlier in this run, if any.
    func join(_ prev: DecodedFrame, _ cur: DecodedFrame, cols known: Range<Int>? = nil) -> JoinResult {
        guard let estimator else { return inPlace(prev, cur) }
        let (top, bottom) = fixedBands(prev.gray, cur.gray)
        // Compression smears a few rows past a fixed band's edge; keep them out of matching.
        let rows = (top > 0 ? top + 4 : 0)..<(prev.gray.height - (bottom > 0 ? bottom + 4 : 0))
        let full = 0..<prev.gray.width
        guard rows.count > 32, var est = estimator.estimate(prev, cur, rows: rows, cols: known ?? full) else { return .noOverlap }
        var cols = known ?? full
        if known == nil, est.shift != 0 {
            // A sidebar that stays put while the page scrolls: match and keep only the part that moves.
            let moving = scrollingColumns(prev.gray, cur.gray, shift: est.shift, rows: rows)
            if moving != full, moving.count >= full.count / 3,
               let again = estimator.estimate(prev, cur, rows: rows, cols: moving) {
                cols = moving
                est = again
            }
        }
        let residual = residualShare(prev.gray, cur.gray, shift: est.shift, rows: rows, cols: cols)
        if Joiner.debug {
            print("join \(prev.ref.index)->\(cur.ref.index) bands \(top)/\(bottom) shift \(est.shift) cost \(String(format: "%.3f", est.cost)) runner \(est.runnerUp.map { String(format: "%.3f", $0) } ?? "-") residual \(String(format: "%.4f", residual)) cols \(cols) detail \(detailRows(cur.gray, shift: est.shift, rows: rows, cols: cols))")
        }
        if est.shift == 0 { return inPlace(prev, cur) }
        if residual > settings.maxResidual {
            // Lined up, but the content differs: the page changed while scrolling. Otherwise nothing lines up.
            return residual < settings.changeResidual ? .change : .noOverlap
        }
        if let r = est.runnerUp, r - est.cost < settings.ambiguityMargin { return .ambiguous }
        if detailRows(cur.gray, shift: est.shift, rows: rows, cols: cols) < settings.minDetailRows { return .ambiguous }
        return .shift(est.shift, fixedTop: top, fixedBottom: bottom, cols: cols)
    }

    /// The view didn't scroll: is it the same apart from a pointer?
    func inPlace(_ prev: DecodedFrame, _ cur: DecodedFrame) -> JoinResult {
        let h = prev.gray.height
        let changed = residualShare(prev.gray, cur.gray, shift: 0, rows: 0..<h) * Double(h * prev.gray.width)
        return changed <= Double(settings.ignorePixels) ? .same : .change
    }

    /// Rows at the top and bottom that are the same in both frames while rows between them changed.
    func fixedBands(_ a: GrayImage, _ b: GrayImage) -> (Int, Int) {
        let w = a.width, h = a.height
        func same(_ y: Int) -> Bool {
            var diff = 0
            a.pixels.withUnsafeBufferPointer { pa in
                b.pixels.withUnsafeBufferPointer { pb in
                    let o = y * w
                    for x in stride(from: 0, to: w, by: 2) {
                        let d = Int(pa[o + x]) - Int(pb[o + x])
                        if d > 24 || d < -24 { diff += 1 }
                    }
                }
            }
            // Allow compression noise: a fixed row matches on nearly every sampled pixel.
            return diff <= max(2, w / 200)
        }
        let limit = Int(Double(h) * settings.maxFixedShare)
        var top = 0
        while top < limit, same(top) { top += 1 }
        var bottom = 0
        while bottom < limit, same(h - 1 - bottom) { bottom += 1 }
        // Uniform rows that happen to match (blank page edges) are harmless to leave out of matching,
        // but a band that's just a few rows is noise.
        return (top >= 8 ? top : 0, bottom >= 8 ? bottom : 0)
    }

    /// Share of overlap pixels that differ after shifting `prev` by `shift`. Recordings are scaled down from
    /// Retina, so a scroll can land between rows: a pixel matches when it lies between its two neighboring
    /// source rows (on the better of the two sides) within `pixelDelta`.
    func residualShare(_ a: GrayImage, _ b: GrayImage, shift s: Int, rows: Range<Int>, cols: Range<Int>? = nil) -> Double {
        let w = a.width
        let cols = cols ?? 0..<w
        // Leave a row of margin so both neighbors exist.
        let y0 = max(rows.lowerBound, rows.lowerBound - s) + 1, y1 = min(rows.upperBound, rows.upperBound - s) - 1
        guard y1 > y0 else { return 1 }
        let delta = settings.pixelDelta
        func count(side: Int) -> Int {
            var diff = 0
            a.pixels.withUnsafeBufferPointer { pa in
                b.pixels.withUnsafeBufferPointer { pb in
                    for y in y0..<y1 {
                        let oa = (y + s) * w, on = (y + s + side) * w, ob = y * w
                        for x in cols {
                            let v = Int(pb[ob + x]), p = Int(pa[oa + x]), q = Int(pa[on + x])
                            let lo = min(p, q) - delta, hi = max(p, q) + delta
                            if v < lo || v > hi { diff += 1 }
                        }
                    }
                }
            }
            return diff
        }
        let diff = s == 0 ? count(side: 0) : min(count(side: 1), count(side: -1))
        return Double(diff) / Double((y1 - y0) * cols.count)
    }

    /// The columns that scrolled: drops bands at the left and right edges that match in place but not
    /// after shifting (a sticky sidebar or table of contents).
    func scrollingColumns(_ a: GrayImage, _ b: GrayImage, shift s: Int, rows: Range<Int>) -> Range<Int> {
        let w = a.width, strips = 32
        func strip(_ k: Int) -> Range<Int> { (k * w / strips)..<((k + 1) * w / strips) }
        /// 1: stays put while the page scrolls; 0: blank either way (margin); -1: scrolls.
        func kind(_ k: Int) -> Int {
            let inPlace = residualShare(a, b, shift: 0, rows: rows, cols: strip(k))
            let shifted = residualShare(a, b, shift: s, rows: rows, cols: strip(k))
            // In place it may still change a little (a table of contents highlighting the current section).
            if inPlace < 0.01 && shifted > max(0.01, inPlace * 3) { return 1 }
            if inPlace < 0.002 && shifted < 0.002 { return 0 }
            return -1
        }
        let limit = Int(Double(strips) * settings.maxFixedShare)
        // Walk in from each edge over blank margins and fixed strips; the band ends at the last fixed one.
        func band(_ index: (Int) -> Int) -> Int {
            var end = 0
            for i in 0..<limit {
                let k = kind(index(i))
                if k < 0 { break }
                if k > 0 { end = i + 1 }
            }
            return end
        }
        let left = band { $0 }
        let right = band { strips - 1 - $0 }
        return strip(left).lowerBound..<strip(strips - 1 - right).upperBound
    }

    /// Overlap rows in `cur` with visible horizontal detail.
    func detailRows(_ img: GrayImage, shift s: Int, rows: Range<Int>, cols: Range<Int>) -> Int {
        let w = img.width
        let y0 = max(rows.lowerBound, rows.lowerBound - s), y1 = min(rows.upperBound, rows.upperBound - s)
        var count = 0
        img.pixels.withUnsafeBufferPointer { px in
            for y in stride(from: y0, to: y1, by: 1) {
                let o = y * w
                var edges = 0
                for x in stride(from: max(1, cols.lowerBound), to: cols.upperBound, by: 2) where abs(Int(px[o + x]) - Int(px[o + x - 1])) > 40 { edges += 1 }
                if edges >= 4 { count += 1 }
            }
        }
        return count
    }
}
