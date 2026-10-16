import Foundation

public struct JoinSettings: Sendable {
    /// A join is ambiguous when another shift fits within this many gray levels of the best one.
    public var ambiguityMargin = 0.12
    /// After alignment, at most this share of overlap pixels may differ (pointer, caret, compression)…
    public var maxResidual = 0.012
    /// …a pixel differs when it moves by more than this.
    public var pixelDelta = 32
    /// Below this share the frames still line up and something on the page changed; above it nothing lines up.
    public var changeResidual = 0.05
    /// A join whose differences are a few compact spots may differ in up to this share of the overlap.
    public var maxLocalResidual = 0.3
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
    /// Nothing that matters moved.
    case same
    /// The view held still and a few spots changed (frame pixels): a pointer, a caret, a ticked box, a menu.
    case local([PixelRect])
    /// The content scrolled by `shift` rows; `fixedTop`/`fixedBottom` rows stayed put (header, footer).
    /// `cols` is the part that scrolls when a sidebar inside the box stays put.
    /// `held`: strips (16 px each) that clearly stayed put in this pair. `changes`: spots in `cur` (frame pixels)
    /// that differ although everything else lines up.
    case shift(Int, fixedTop: Int, fixedBottom: Int, cols: Range<Int>, held: Set<Int>, changes: [PixelRect], fraction: Double)
    /// The frames line up but the content changed (an edit, a new page with the same layout).
    case change
    /// Nothing lines up within the overlap: a jump, a new page.
    case noOverlap
    /// More than one distance fits: repeated rows or blank space.
    case ambiguous
}

/// The part of the frame a run scrolls: columns, and the rows that stay put above and below them.
struct ScrollRegion: Equatable {
    var cols: Range<Int>
    var top: Int
    var bottom: Int
    /// Strips that stayed put at some point in this run (a sidebar, even one that later slides): the run never
    /// grows into them.
    var held: Set<Int> = []
}

struct Joiner {
    static let debug = ProcessInfo.processInfo.environment["CANVAS_DEBUG"] != nil
    let settings: JoinSettings
    /// nil: cards only; frames are compared in place.
    let estimator: (any ShiftEstimator)?

    /// `region`: where this run scrolls, once known. Still frames are compared only there, so a sidebar hover,
    /// a table of contents highlight or the menu bar clock doesn't end the run. `hint`: the columns that scrolled
    /// last anywhere in the recording; tried alongside a fresh search, and kept only if they verify.
    func join(_ prev: DecodedFrame, _ cur: DecodedFrame, region: ScrollRegion? = nil, hint: Range<Int>? = nil) -> JoinResult {
        guard let estimator else { return inPlace(prev, cur) }
        let known = region?.cols
        let h = prev.gray.height, full = 0..<prev.gray.width
        let (top, bottom) = fixedBands(prev.gray, cur.gray)
        // Compression smears a few rows past a fixed band's edge; keep them out of matching.
        let rows = (top > 0 ? top + 4 : 0)..<(h - (bottom > 0 ? bottom + 4 : 0))
        guard rows.count > 32, let first = estimator.estimate(prev, cur, rows: rows, cols: known ?? hint ?? full) else { return .noOverlap }
        if first.shift == 0 {
            // Stationary sidebars and chrome can win zero shift over the whole width. If the view changed, look again
            // where a page usually is: the remembered region, else the middle half of the screen.
            let still = inPlace(prev, cur, within: region)
            guard known == nil, still == .change else { return still }
            let probe = hint ?? (full.count / 4)..<(full.count * 3 / 4)
            guard let again = estimator.estimate(prev, cur, rows: rows, cols: probe), again.shift != 0 else { return still }
            return verify(prev, cur, candidates: candidates(prev, cur, shift: again.shift, rows: rows, known: nil, hint: hint),
                          region: region)
        }
        return verify(prev, cur, candidates: candidates(prev, cur, shift: first.shift, rows: rows, known: known, hint: hint,
                                                        held: region?.held ?? []),
                      region: region)
    }

    /// One way to read the pair: this part of the frame scrolled by `shift`.
    struct Candidate {
        var label: String
        var shift: Int
        var cost: Double
        var runnerUp: Double?
        var cols: Range<Int>
        var top: Int
        var bottom: Int
        var residual = 1.0
        var held: Set<Int> = []
        var fraction = 0.0
    }

    /// The regions worth verifying: the run's own columns when it has them; otherwise a fresh search for what
    /// moved, the remembered region, and the whole frame.
    private func candidates(_ prev: DecodedFrame, _ cur: DecodedFrame, shift: Int, rows: Range<Int>,
                            known: Range<Int>?, hint: Range<Int>?, held: Set<Int> = []) -> [Candidate] {
        let full = 0..<prev.gray.width
        var cache: [Int: Strips] = [:]
        func stripsAt(_ s: Int) -> Strips {
            if let c = cache[s] { return c }
            let c = strips(prev.gray, cur.gray, shift: s, rows: rows)
            cache[s] = c
            return c
        }
        var regions: [(String, Range<Int>)] = []
        if let known {
            regions = [("run", known)]
            // The page may be wider than the first pair showed: offer what this pair says moved, joined to the run's.
            // Only by several strips: a rail highlight that steps by about the scroll distance looks like one
            // strip of page.
            if let found = movingColumns(stripsAt(shift), width: full.count), found.overlaps(known),
               found.lowerBound <= known.lowerBound - 48 || found.upperBound >= known.upperBound + 48 {
                var lo = min(found.lowerBound, known.lowerBound), hi = max(found.upperBound, known.upperBound)
                for k in held {
                    let x = k * Strips.width
                    if x < known.lowerBound { lo = max(lo, x + Strips.width) }
                    if x >= known.upperBound { hi = min(hi, x) }
                }
                // The added strips must have scrolled themselves, not just sit next to strips that did.
                let st = stripsAt(shift), w = Strips.width
                let added = Array(lo / w..<known.lowerBound / w) + Array((known.upperBound + w - 1) / w..<min(st.kinds.count, (hi + w - 1) / w))
                let moved = added.filter { st.kinds.indices.contains($0) && st.kinds[$0] == -1 }.count
                if moved >= 2, lo <= known.lowerBound - 48 || hi >= known.upperBound + 48 { regions.append(("grow", lo..<hi)) }
            }
        } else {
            if let found = movingColumns(stripsAt(shift), width: full.count) { regions.append(("found", found)) }
            if let hint, !regions.contains(where: { $0.1 == hint }) { regions.append(("hint", hint)) }
            // The whole frame only when nothing better turned up: it can't verify beside a sidebar anyway.
            if regions.isEmpty { regions.append(("full", full)) }
        }
        var out: [Candidate] = []
        for (label, cols) in regions {
            var s = shift, est: ShiftEstimate?
            // Rows that stay put inside these columns (browser chrome, a sticky header, the Dock) aren't page:
            // rows identical in both frames, or rows that held still while the rest scrolled.
            let still = fixedBands(prev.gray, cur.gray, cols: cols)
            func bands(_ s: Int) -> (Int, Int) {
                let m = movingRows(prev.gray, cur.gray, shift: s, cols: cols)
                return (max(m.0, still.0), max(m.1, still.1))
            }
            var (top, bottom) = bands(s)
            for _ in 0..<2 {
                let r = (top > 0 ? top + 4 : 0)..<(prev.gray.height - (bottom > 0 ? bottom + 4 : 0))
                guard r.count > 32, let e = estimator?.estimate(prev, cur, rows: r, cols: cols) else { est = nil; break }
                est = e
                if e.shift == s { break }
                s = e.shift
                (top, bottom) = bands(s)
            }
            guard let est, est.shift != 0 else { continue }
            let r = (top > 0 ? top + 4 : 0)..<(prev.gray.height - (bottom > 0 ? bottom + 4 : 0))
            var c = Candidate(label: label, shift: est.shift, cost: est.cost, runnerUp: est.runnerUp, cols: cols, top: top, bottom: bottom)
            c.fraction = est.fraction
            c.residual = residualShare(prev.gray, cur.gray, shift: est.shift, rows: r, cols: cols)
            // A region that holds a strip which clearly stayed put isn't one scrolling page: a sparse sidebar
            // can't spoil the residual enough to fail, but it would repeat down the column.
            let st = stripsAt(est.shift)
            c.held = Set(st.kinds.indices.filter { st.kinds[$0] == 1 })
            let inside = st.stationary(in: cols)
            if let x = inside.first {
                c.residual = 1
                c.label += "(still x \(x * Strips.width))"
            }
            out.append(c)
        }
        return out
    }

    /// Picks the candidate that lines up best, then applies the usual refusals to it.
    private func verify(_ prev: DecodedFrame, _ cur: DecodedFrame, candidates: [Candidate], region: ScrollRegion?) -> JoinResult {
        // The widest region that lines up: a narrower one can always look cleaner by leaving page out.
        // Growing a run takes clean evidence: the added strips must line up about as well as the run already does.
        let runResidual = candidates.first { $0.label == "run" }?.residual ?? 1
        let passing = candidates.filter {
            $0.residual <= settings.maxResidual
                && ($0.label != "grow" || $0.residual <= min(settings.maxResidual / 3, runResidual * 2 + 0.001))
        }
        guard let best = passing.max(by: { $0.cols.count < $1.cols.count }) ?? candidates.min(by: { $0.residual < $1.residual })
        else { return inPlace(prev, cur, within: region) }
        let rows = (best.top > 0 ? best.top + 4 : 0)..<(prev.gray.height - (best.bottom > 0 ? best.bottom + 4 : 0))
        let detail = detailRows(cur.gray, shift: best.shift, rows: rows, cols: best.cols)
        if Joiner.debug {
            let list = candidates.map { "\($0.label) \($0.cols) rows \($0.top)/\($0.bottom) shift \($0.shift) residual \(String(format: "%.4f", $0.residual))" }
            print("join \(prev.ref.index)->\(cur.ref.index) cost \(String(format: "%.3f", best.cost)) runner \(best.runnerUp.map { String(format: "%.3f", $0) } ?? "-") detail \(detail) · " + list.joined(separator: " | "))
        }
        // What differs after aligning: a few compact spots (an edit, a menu, the pointer) don't stop the join; the
        // rest of the overlap has to line up. Differences everywhere mean the page changed, or nothing lines up.
        let changes = Changes.blobs(prev.gray, cur.gray, shift: best.shift, rows: rows, cols: best.cols, delta: settings.pixelDelta)
        if best.residual > settings.maxResidual && (best.residual > settings.maxLocalResidual || changes?.isEmpty ?? true) {
            return best.residual < settings.changeResidual ? .change : .noOverlap
        }
        if let r = best.runnerUp, r - best.cost < settings.ambiguityMargin { return .ambiguous }
        if detail < settings.minDetailRows { return .ambiguous }
        return .shift(best.shift, fixedTop: best.top, fixedBottom: best.bottom, cols: best.cols, held: best.held, changes: changes ?? [],
                      fraction: best.fraction)
    }

    /// The view didn't scroll: is it the same apart from a pointer?
    func inPlace(_ prev: DecodedFrame, _ cur: DecodedFrame, within region: ScrollRegion? = nil) -> JoinResult {
        let h = prev.gray.height
        let rows = (region?.top ?? 0)..<max((region?.top ?? 0) + 1, h - (region?.bottom ?? 0))
        let cols = region?.cols ?? 0..<prev.gray.width
        let changed = residualShare(prev.gray, cur.gray, shift: 0, rows: rows, cols: cols) * Double(rows.count * cols.count)
        // Compact spots are local changes, however large.
        // In place nothing has to be aligned, so a menu may cover more of the page than a join would allow; only a
        // view where nearly everything changed is a new one.
        let spots = Changes.blobs(prev.gray, cur.gray, shift: 0, rows: rows, cols: cols, delta: settings.pixelDelta,
                                  maxShare: 0.35, maxDetailShare: 0.6)
        if let spots, !spots.isEmpty { return .local(spots) }
        if changed <= Double(settings.ignorePixels) { return .same }
        // Spread-out change. Moved less than a pixel (a slow scroll, resampled)? Every glyph differs a little, but
        // each pixel lies between its neighbors above and below: not a change, the next whole pixel joins.
        if residualShare(prev.gray, cur.gray, shift: 0, rows: rows, cols: cols, subpixel: true) <= settings.maxResidual { return .same }
        return .change
    }

    /// Rows at the top and bottom that are the same in both frames while rows between them changed.
    func fixedBands(_ a: GrayImage, _ b: GrayImage, cols: Range<Int>? = nil) -> (Int, Int) {
        let w = a.width, h = a.height
        let cols = cols ?? 0..<w
        func same(_ y: Int) -> Bool {
            var diff = 0
            a.pixels.withUnsafeBufferPointer { pa in
                b.pixels.withUnsafeBufferPointer { pb in
                    let o = y * w
                    for x in stride(from: cols.lowerBound, to: cols.upperBound, by: 2) {
                        let d = Int(pa[o + x]) - Int(pb[o + x])
                        if d > 24 || d < -24 { diff += 1 }
                    }
                }
            }
            // Allow compression noise: a fixed row matches on nearly every sampled pixel.
            return diff <= max(2, cols.count / 200)
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
    func residualShare(_ a: GrayImage, _ b: GrayImage, shift s: Int, rows: Range<Int>, cols: Range<Int>? = nil, subpixel: Bool = false) -> Double {
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
        let diff = s == 0 && !subpixel ? count(side: 0) : min(count(side: 1), count(side: -1))
        return Double(diff) / Double((y1 - y0) * cols.count)
    }

    /// Changed-pixel counts on a grid of `cellW`×`cellH` tiles: `still` compares each pixel in place, `moved` after
    /// shifting `prev` by `shift` (nil where the shifted row falls outside the frame). Samples every other column.
    struct TileDiff {
        var cols: Int, rows: Int
        var cellW: Int, cellH: Int
        var still: [Int]
        var moved: [Int]
        var movedValid: [Bool]
    }

    /// `source`: rows the shifted comparison may read from (page rows); outside them a tile can't tell.
    func tileDiff(_ a: GrayImage, _ b: GrayImage, shift s: Int, cols: Range<Int>, cellW: Int, cellH: Int,
                  source: Range<Int>? = nil) -> TileDiff {
        let w = a.width, h = a.height
        let nx = (cols.count + cellW - 1) / cellW, ny = (h + cellH - 1) / cellH
        var still = [Int](repeating: 0, count: nx * ny), moved = still
        var valid = [Bool](repeating: true, count: nx * ny)
        let delta = settings.pixelDelta
        a.pixels.withUnsafeBufferPointer { pa in
            b.pixels.withUnsafeBufferPointer { pb in
                for y in 0..<h {
                    let cy = y / cellH
                    let sy = y + s
                    let lo = max(1, source?.lowerBound ?? 1), hi = min(h - 2, (source?.upperBound ?? h) - 1)
                    let ok = sy >= lo && sy <= hi && y >= lo - 1 && y <= hi + 1
                    if !ok { for cx in 0..<nx { valid[cy * nx + cx] = false } }
                    let ob = y * w, oa = (ok ? sy : 0) * w
                    for x in stride(from: cols.lowerBound, to: cols.upperBound, by: 2) {
                        let cell = cy * nx + (x - cols.lowerBound) / cellW
                        let v = Int(pb[ob + x])
                        let d = v - Int(pa[ob + x])
                        if d > delta || d < -delta { still[cell] += 1 }
                        guard ok else { continue }
                        let p = Int(pa[oa + x]), q = Int(pa[oa + w + x]), r = Int(pa[oa - w + x])
                        let inQ = v >= min(p, q) - delta && v <= max(p, q) + delta
                        let inR = v >= min(p, r) - delta && v <= max(p, r) + delta
                        if !inQ && !inR { moved[cell] += 1 }
                    }
                }
            }
        }
        return TileDiff(cols: nx, rows: ny, cellW: cellW, cellH: cellH, still: still, moved: moved, movedValid: valid)
    }

    /// 1: stays put while the rest scrolls (sidebar, chrome); -1: scrolled; 0: can't tell (blank, or both).
    private func kind(still: Int, moved: Int, valid: Bool, pixels: Int) -> Int {
        let floor = max(3, pixels / 400)
        if !valid { return still < floor ? 1 : -1 }
        if moved * 2 < still && still >= floor { return -1 }
        if still * 2 < moved && moved >= floor { return 1 }
        return 0
    }

    /// The columns that scrolled by `shift`, from tile-by-tile evidence: from the first to the last strip that
    /// moved, widened over strips that can't tell (page margins) up to a strip that stayed put (a sticky
    /// sidebar, a table of contents whose highlight changes, a scrollbar beyond it). nil when too little moved.
    /// How each 16-pixel strip behaved when the page scrolled by `shift`.
    struct Strips {
        static let width = 16
        /// 1: stayed put; 2: a little still evidence (a sidebar's last few words, or a resting pointer);
        /// -1: scrolled; 0: blank or mixed.
        var kinds: [Int]
        /// Nothing changed in the strip at all, in place or shifted: margin.
        var quiet: [Bool]

        /// Strips wholly inside `cols` (less one at each edge) that clearly stayed put.
        func stationary(in cols: Range<Int>) -> [Int] {
            let lo = (cols.lowerBound + Strips.width - 1) / Strips.width + 1, hi = cols.upperBound / Strips.width - 1
            guard lo < hi else { return [] }
            return (lo..<min(hi, kinds.count)).filter { kinds[$0] == 1 }
        }
    }

    func strips(_ a: GrayImage, _ b: GrayImage, shift s: Int, rows: Range<Int>) -> Strips {
        let w = a.width, cellW = Strips.width
        let t = tileDiff(a, b, shift: s, cols: 0..<w, cellW: cellW, cellH: 8, source: rows)
        let r0 = rows.lowerBound / t.cellH, r1 = min(t.rows, (rows.upperBound + t.cellH - 1) / t.cellH)
        // Vote tile by tile: a pointer resting over the page is a few still tiles, a sidebar is dozens.
        var kinds: [Int] = [], quiet: [Bool] = []
        for cx in 0..<t.cols {
            var still = 0, moving = 0, changed = 0, lo = Int.max, hi = Int.min
            for cy in r0..<r1 where t.movedValid[cy * t.cols + cx] {
                let i = cy * t.cols + cx
                changed += t.still[i] + t.moved[i]
                switch kind(still: t.still[i], moved: t.moved[i], valid: true, pixels: t.cellH * cellW / 2) {
                case 1: still += 1; lo = min(lo, cy); hi = max(hi, cy)
                case -1: moving += 1
                default: break
                }
            }
            // A sidebar's still tiles run down most of the view; a menu or tooltip held over the page is one block.
            let tall = still > 0 && Double(hi - lo + 1) >= Double(r1 - r0) * 0.4
            quiet.append(changed == 0 && edgeCount(b, x: (cx * cellW)..<min(w, (cx + 1) * cellW), rows: rows) <= 2)
            kinds.append(still >= 4 && still > moving && tall ? 1 : moving >= 3 && moving > still ? -1 : still > moving ? 2 : 0)
        }
        if Joiner.debug { print("  strips " + kinds.map { ["=", ".", "#", "~"][$0 + 1] }.joined()) }
        return Strips(kinds: kinds, quiet: quiet)
    }

    /// Pixels in `x`×`rows` (every fourth row) with a sharp step from their left neighbor: visible detail.
    func edgeCount(_ img: GrayImage, x: Range<Int>, rows: Range<Int>) -> Int {
        var n = 0
        img.pixels.withUnsafeBufferPointer { px in
            for y in stride(from: rows.lowerBound, to: rows.upperBound, by: 4) {
                let o = y * img.width
                for c in max(1, x.lowerBound)..<x.upperBound where abs(Int(px[o + c]) - Int(px[o + c - 1])) > 40 { n += 1 }
            }
        }
        return n
    }

    /// The columns that scrolled: from the first to the last strip that moved (the widest stretch not split by a
    /// strip that stayed put), widened over a strip or two of blank margin. nil when too little moved.
    func movingColumns(_ st: Strips, width w: Int) -> Range<Int>? {
        let kinds = st.kinds, quiet = st.quiet, cellW = Strips.width
        guard let firstMoving = kinds.firstIndex(of: -1), let lastMoving = kinds.lastIndex(of: -1) else { return nil }
        let movingCount = kinds.filter { $0 < 0 }.count
        guard movingCount >= 4 else { return nil }
        // Inside the span, a strip that clearly stayed put splits it: keep the widest stretch between such strips.
        var best = firstMoving...firstMoving, start = firstMoving
        for i in firstMoving...lastMoving + 1 {
            if i > lastMoving || kinds[i] == 1 {
                let end = i - 1
                if end >= start, let a = (start...end).first(where: { kinds[$0] == -1 }), let b = (start...end).last(where: { kinds[$0] == -1 }),
                   b - a > best.upperBound - best.lowerBound { best = a...b }
                start = i + 1
            }
        }
        // Widen over blank margins, but not into anything that held still.
        var lo = best.lowerBound, hi = best.upperBound
        // Page margins are a strip or two; beyond that blank space is as likely to be a sidebar's empty edge.
        // Only strips with nothing at all in them: a rail's highlight bar or a nav's last word is not margin.
        for _ in 0..<2 where lo > 0 && kinds[lo - 1] == 0 && quiet[lo - 1] { lo -= 1 }
        for _ in 0..<2 where hi < kinds.count - 1 && kinds[hi + 1] == 0 && quiet[hi + 1] { hi += 1 }
        let range = (lo * cellW)..<min(w, (hi + 1) * cellW)
        // A stationary edge can't be most of the frame, and a "page" a few strips wide is noise.
        guard range.count >= w / 6 else { return nil }
        return range
    }

    /// Rows at the top and bottom that stay put inside `cols` while the rest scrolls by `shift`: browser
    /// chrome, a sticky header, the Dock. Walks in from each edge over rows that stayed put or can't tell and
    /// stops at the first that scrolled; the band ends at the last that stayed put.
    func movingRows(_ a: GrayImage, _ b: GrayImage, shift s: Int, cols: Range<Int>) -> (Int, Int) {
        let h = a.height, cellH = 4
        let t = tileDiff(a, b, shift: s, cols: cols, cellW: max(1, cols.count), cellH: cellH)
        let kinds = (0..<t.rows).map { cy in
            kind(still: t.still[cy * t.cols], moved: t.moved[cy * t.cols], valid: t.movedValid[cy * t.cols], pixels: cellH * cols.count / 2)
        }
        let limit = Int(Double(t.rows) * settings.maxFixedShare)
        func band(_ index: (Int) -> Int) -> Int {
            var end = 0
            for i in 0..<limit {
                let k = kinds[index(i)]
                if k < 0 { break }
                if k > 0 { end = i + 1 }
            }
            return end
        }
        let top = min(h, band { $0 } * cellH)
        let bottom = min(h - top, band { t.rows - 1 - $0 } * cellH - (t.rows * cellH - h))
        return (top >= 8 ? top : 0, bottom >= 8 ? bottom : 0)
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
