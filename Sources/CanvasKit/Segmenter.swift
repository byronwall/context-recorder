import CoreGraphics
import Foundation

/// Rows `sourceY ..< sourceY + height` of `frame`, placed at `destY` (relative to the run's first frame).
struct PendingPatch {
    var frame: FrameRef
    var sourceY: Int
    var destY: Int
    var height: Int
    var image: CGImage
}

/// A stretch of the recording that becomes one canvas item: a card when it never scrolled, a column when it did.
struct Run {
    var start: DecodedFrame
    var reason: CanvasItem.Reason
    /// Kept on the canvas: held still long enough, scrolled, or the first item.
    var confirmed: Bool
    /// The last frame joined (or the start).
    var last: DecodedFrame
    /// Page position of `last`'s top row, relative to `start`…
    var y = 0
    /// …to a fraction of a pixel, so slow scrolling doesn't drift by rounding every step.
    var yExact = 0.0
    var patches: [PendingPatch]
    /// The rows with real content so far (relative to `start`).
    var contentTop: Int
    var contentBottom: Int
    /// Where the page scrolls, set by the first join; nil until then (a card is the whole frame).
    var region: ScrollRegion?
    var cols: Range<Int>? { region?.cols }
    /// Every join's sticky bands; the column's first frame is trimmed by a low percentile of them, since one pair
    /// can mistake blank page rows for a band (too much) and noise can hide a band (too little).
    var topBands: [Int] = []
    var bottomBands: [Int] = []
    /// Where the view was at each joined frame: its time and the page position of its top row (relative to `start`).
    var poses: [(time: Double, y: Int)] = []
    /// Local changes being watched, and those already resolved into edits and overlays.
    var candidates: [ChangeCandidate] = []
    var overlays: [OverlayTrack] = []
    /// Where something pointer-sized moved between consecutive still frames (page coordinates): the pointer's
    /// trail. A change that is only there is the pointer arriving or leaving, not an edit.
    var trail: [PixelRect] = []
    /// What moved in the previous frame: a spot joins the trail only if something moved near it a frame earlier
    /// too (a pointer travels; a ticked box changes once).
    var lastMotion: [PixelRect] = []
    var events: [FoundEvent] = []
    /// When the view last scrolled.
    var lastMoved = -Double.infinity

    init(start: DecodedFrame, reason: CanvasItem.Reason, confirmed: Bool) throws {
        guard let image = start.colorImage() else { throw CanvasError("Couldn't read frame \(start.ref.index)") }
        self.start = start
        self.reason = reason
        self.confirmed = confirmed
        last = start
        let h = start.gray.height
        patches = [PendingPatch(frame: start.ref, sourceY: 0, destY: 0, height: h, image: image)]
        contentTop = 0
        contentBottom = h
        poses = [(start.ref.time, 0)]
    }

    var isColumn: Bool { patches.count > 1 }
    var height: Int { contentBottom - contentTop }

    /// The pixels the column shows in `rect` (page coordinates), in gray, when one patch supplied all of them.
    func ownedGray(_ rect: PixelRect) -> [UInt8]? {
        guard let p = patches.last(where: { $0.destY <= rect.y && rect.maxY <= $0.destY + $0.height }),
              let crop = p.image.cropping(to: CGRect(x: rect.x, y: rect.y - p.destY, width: rect.width, height: rect.height))
        else { return nil }
        var out = [UInt8](repeating: 0, count: rect.width * rect.height)
        guard let ctx = CGContext(data: &out, width: rect.width, height: rect.height, bitsPerComponent: 8, bytesPerRow: rect.width,
                                  space: CGColorSpaceCreateDeviceGray(), bitmapInfo: CGImageAlphaInfo.none.rawValue) else { return nil }
        ctx.draw(crop, in: CGRect(x: 0, y: 0, width: rect.width, height: rect.height))
        return out
    }

    /// `frame` shows the page `shift` rows further down than `ref`. Adds the rows not seen yet.
    mutating func append(_ frame: DecodedFrame, shift measured: Int, fraction: Double = 0, fixedTop: Int, fixedBottom: Int,
                         holding: [PixelRect] = []) {
        let h = frame.gray.height
        // `measured` is against `last`, which sits at `yExact`; place the frame at the nearest whole row.
        yExact += Double(measured) + fraction
        let shift = Int(yExact.rounded()) - y
        // A fixed footer or header on the frame that set the column's edge isn't page content; let real rows replace it.
        if fixedBottom > 0, contentBottom == y + h { contentBottom = y + h - fixedBottom }
        if fixedTop > 0, contentTop == y { contentTop = y + fixedTop }
        let newY = y + shift
        let moving = fixedTop..<(h - fixedBottom)
        // New rows below.
        let belowStart = max(contentBottom - newY, moving.lowerBound)
        // New rows stop above any changed spot (a menu, the pointer): the next frame brings the rest.
        let blocked = holding.filter { $0.maxY > belowStart }.map(\.y).min() ?? moving.upperBound
        let below = min(belowStart, moving.upperBound)..<max(min(belowStart, moving.upperBound), min(moving.upperBound, blocked))
        if !below.isEmpty, let image = frame.colorRows(below.lowerBound, below.upperBound) {
            patches.append(PendingPatch(frame: frame.ref, sourceY: below.lowerBound, destY: newY + below.lowerBound,
                                        height: below.count, image: image))
            contentBottom = newY + below.upperBound
        }
        // New rows above (scrolling back up past where the run started).
        let aboveEnd = min(contentTop - newY, moving.upperBound)
        let blockedAbove = holding.filter { $0.y < aboveEnd }.map(\.maxY).max() ?? moving.lowerBound
        let above = max(moving.lowerBound, blockedAbove)..<max(aboveEnd, max(moving.lowerBound, blockedAbove))
        if !above.isEmpty, let image = frame.colorRows(above.lowerBound, above.upperBound) {
            patches.append(PendingPatch(frame: frame.ref, sourceY: above.lowerBound, destY: newY + above.lowerBound,
                                        height: above.count, image: image))
            contentTop = newY + above.lowerBound
        }
        y = newY
        last = frame
        poses.append((frame.ref.time, newY))
    }
}

/// Splits the recording into runs. A run starts tentatively at a frame that differs from what came before;
/// it is kept once it holds still (a card), joins a scroll (a column), or as a periodic card while the view
/// keeps moving without joining (animation, unjoinable scrolling). The first frame always starts one.
struct Segmenter {
    let settings: StoryboardSettings
    let joiner: Joiner
    let pixelCount: Int

    private(set) var run: Run?
    /// The last view of the last kept run, for deciding when motion deserves another card.
    private var lastKept: DecodedFrame?
    /// Why the next run starts: the strongest reason seen since the last kept run ended.
    private var pending: CanvasItem.Reason = .change
    /// The columns that last scrolled, anywhere in the recording: a page usually keeps its layout, so the next
    /// run tries them first (they still have to verify).
    private(set) var tracked: Range<Int>?

    init(settings: StoryboardSettings, joiner: Joiner, pixelCount: Int) {
        self.settings = settings
        self.joiner = joiner
        self.pixelCount = pixelCount
    }

    /// A run that stopped lining up, kept open for a while in case the view comes back: a menu, a tooltip, a
    /// slow scroll that hasn't moved a whole pixel yet. `first` is the first frame that didn't fit.
    private var uncertain: (first: DecodedFrame, reason: CanvasItem.Reason)?
    /// A few frames from the uncertain stretch (one every fifth of a second), replayed into the next run if the
    /// view doesn't come back, so a new page that starts scrolling at once keeps its first rows.
    private var uncertainFrames: [DecodedFrame] = []
    /// The frame fed before this one, for what moved frame to frame (the pointer).
    private var previous: DecodedFrame?

    /// Feeds one frame; returns any runs that are finished and kept.
    mutating func feed(_ frame: DecodedFrame) throws -> [Run] {
        let before = previous
        previous = frame
        guard var current = run else {
            run = try Run(start: frame, reason: .start, confirmed: true)
            return []
        }
        let s = settings
        var result: JoinResult = .same
        let changed = Diff.changedCount(current.last.small, frame.small, delta: s.pixelDelta, limit: s.changedPixels)
        if changed >= s.changedPixels {
            result = joiner.join(current.last, frame, region: current.region, hint: tracked)
        } else if changed >= s.localPixels {
            // Too little for a new view, enough for a ticked box or a changed digit.
            result = joiner.inPlace(current.last, frame, within: current.region)
        }

        switch result {
        case .same, .local, .shift: recover(&current, at: frame, via: result)
        default: break
        }

        switch result {
        case .same, .local:
            if case .local = result, let before { followPointer(&current, from: before, to: frame) }
            if case let .local(spots) = result {
                // Just after motion stops, compression sharpens text for a few frames: small spots then aren't edits.
                let settled = frame.ref.time - current.lastMoved >= s.settleAfterMotion
                track(&current, spots: spots.filter { settled || Self.isLarge($0) }, in: frame, y: current.y, anchorY: current.y)
                followOverlays(&current, spots: spots.filter(Self.isLarge), in: frame, shift: 0)
            } else {
                followOverlays(&current, spots: [], in: frame, shift: 0)
            }
            watch(&current, frame, viewMoved: false)
            // Holding still: a tentative run that lasts becomes a card.
            if !current.confirmed, frame.ref.time - current.last.ref.time >= s.settleSeconds {
                current.confirmed = true
            }
            run = current
            return []

        case let .shift(shift, top, bottom, cols, held, changes, fraction):
            // A few rows past a sticky band's edge are smeared by compression; leave them out too, so no frame
            // adds a strip of header or Dock to the page. A run's columns only grow (a later pair can show more
            // of a page than the first one did); its images keep every frame's full width.
            let band = { (new: Int) in new > 0 ? new + 4 : 0 }
            let wider = current.region.map { min($0.cols.lowerBound, cols.lowerBound)..<max($0.cols.upperBound, cols.upperBound) } ?? cols
            let region = ScrollRegion(cols: wider, top: band(top), bottom: band(bottom), held: (current.region?.held ?? []).union(held))
            current.region = region
            current.topBands.append(region.top)
            current.bottomBands.append(region.bottom)
            // A narrower verified region on the same page is usually a partial view (a grid of cards with a
            // gap); remember the wider one. A region elsewhere means the layout changed.
            if let t = tracked, t.overlaps(cols), cols.count < t.count * 9 / 10 {} else { tracked = cols }
            let anchorY = current.y
            // Rows that arrive under a menu wait for a frame without it. Pointer-sized spots don't hold anything up:
            // a pointer resting over a scrolling page would stop the column at its row.
            let menus = changes.filter { $0.width >= 48 && $0.height >= 24 }
            current.append(frame, shift: shift, fraction: fraction, fixedTop: region.top, fixedBottom: region.bottom, holding: menus)
            followOverlays(&current, spots: menus, in: frame, shift: current.y - anchorY)
            current.lastMoved = frame.ref.time
            watch(&current, frame, viewMoved: true)
            current.confirmed = true
            if current.height > joiner.settings.maxColumnHeight {
                close(&current)
                run = nil
                lastKept = current.last
                run = try Run(start: frame, reason: .heightLimit, confirmed: true)
                return [current]
            }
            run = current
            return []

        default:
            break
        }

        if Joiner.debug {
            print("break \(current.last.ref.index)->\(frame.ref.index) t=\(String(format: "%.2f", frame.ref.time)) \(result) confirmed \(current.confirmed) region \(current.region.map { "\($0.cols) \($0.top)/\($0.bottom)" } ?? "-")")
        }
        let reason: CanvasItem.Reason = switch result {
        case .noOverlap: .noOverlap
        case .ambiguous: .ambiguous
        default: .change
        }
        // A kept run waits a moment for the view to come back before it ends.
        if current.confirmed, joiner.estimator != nil {
            guard let u = uncertain else {
                uncertain = (frame, reason)
                uncertainFrames = []
                run = current
                return []
            }
            if frame.ref.time - u.first.ref.time <= s.recoverSeconds {
                if frame.ref.time - (uncertainFrames.last ?? u.first).ref.time >= 0.2, uncertainFrames.count < 8 { uncertainFrames.append(frame) }
                run = current
                return []
            }
            // It didn't come back: the run ended at the first frame that didn't fit; carry on from there.
            return try giveUp(current, then: [frame])
        }
        return try end(current, nextFrom: frame, reason: reason)
    }

    /// The view didn't come back: end the run where it stopped fitting and replay the stretch since into the next.
    private mutating func giveUp(_ current: Run, then rest: [DecodedFrame]) throws -> [Run] {
        guard let u = uncertain else { return [] }
        uncertain = nil
        let replay = uncertainFrames + rest
        uncertainFrames = []
        var finished = try end(current, nextFrom: u.first, reason: u.reason)
        for f in replay { finished += try feed(f) }
        return finished
    }

    /// Ends `current` and starts a tentative run at `frame`.
    private mutating func end(_ current: Run, nextFrom frame: DecodedFrame, reason: CanvasItem.Reason) throws -> [Run] {
        var current = current
        let s = settings
        close(&current)
        if priority(reason) > priority(pending) { pending = reason }
        var finished: [Run] = []
        if current.confirmed {
            finished.append(current)
            lastKept = current.last
        }
        var next = try Run(start: frame, reason: current.confirmed ? reason : pending, confirmed: false)
        if current.confirmed { pending = reason }
        // Still moving with nothing to join: leave a card now and then.
        if let kept = lastKept, frame.ref.time - kept.ref.time >= s.motionSeconds {
            let limit = Int(Double(pixelCount) * s.motionShare)
            if Diff.changedCount(kept.small, frame.small, delta: s.pixelDelta, limit: limit) >= limit {
                next.confirmed = true
                if next.reason == .change { next.reason = .motion }
            }
        }
        if next.confirmed { pending = .change }
        run = next
        return finished
    }

    /// The view fits the run again after frames that didn't. A menu or dialog that came and went is kept as a
    /// moment to play back; a slow scroll that needed a few frames to move a pixel is just motion.
    private mutating func recover(_ current: inout Run, at frame: DecodedFrame, via result: JoinResult) {
        guard let u = uncertain else { return }
        uncertain = nil
        let duration = frame.ref.time - u.first.ref.time
        let h = u.first.gray.height
        let region = current.region ?? ScrollRegion(cols: 0..<u.first.gray.width, top: 0, bottom: 0)
        let rows = region.top..<max(region.top + 1, h - region.bottom)
        let spots = Changes.blobs(current.last.gray, u.first.gray, shift: 0, rows: rows, cols: region.cols,
                                  delta: joiner.settings.pixelDelta, maxShare: 1, maxBlobs: .max) ?? []
        let cameBack: Bool = switch result { case .same, .local: true; default: false }
        guard duration >= 0.15, cameBack, !spots.isEmpty else { return }
        let box = spots.dropFirst().reduce(spots[0]) { $0.union($1) }
        let rect = PixelRect(x: box.x, y: current.y + box.y, width: box.width, height: box.height)
        current.events.append(FoundEvent(kind: .overlay, rect: rect, start: u.first.ref, end: frame.ref, before: nil,
                                         beforeImage: nil, afterImage: u.first.colorCrop(box)))
    }

    /// New changed spots (frame pixels in `frame`, whose top row is page row `y`) become candidates, compared
    /// against the anchor (`current.last`, top at page row `anchorY`), which still shows what was there before.
    private func track(_ current: inout Run, spots: [PixelRect], in frame: DecodedFrame, y: Int, anchorY: Int) {
        let anchor = current.last
        // Only on the page: chrome changes (a scrollbar thumb, the clock) aren't edits. A run that hasn't scrolled
        // yet uses the page the recording last scrolled.
        guard let cols = current.region?.cols ?? tracked else { return }
        if Joiner.debug { print("  spots f\(frame.ref.index) y\(y) " + spots.map { "\($0.x),\($0.y) \($0.width)×\($0.height)" }.joined(separator: " | ")) }
        // Not right at the region's edges either: a sliver of a rail or nav can sit just inside.
        for spot in spots where spot.x >= cols.lowerBound + 16 && spot.maxX <= cols.upperBound - 16 {
            let pad = 6
            var screen = PixelRect(x: spot.x - pad, y: spot.y - pad, width: spot.width + 2 * pad, height: spot.height + 2 * pad)
            screen = screen.clamped(width: frame.gray.width, height: frame.gray.height)
            var page = PixelRect(x: screen.x, y: y + screen.y, width: screen.width, height: screen.height)
            // A known edit stays as found; the anchor still shows its old state, so it keeps showing up here.
            if current.candidates.contains(where: { $0.confirmed && $0.rect.intersects(page) }) { continue }
            var first = frame.ref
            if let i = current.candidates.firstIndex(where: { $0.rect.intersects(page) }) {
                // The same spot again: the anchor still shows the old state, so it shows up every frame. Watching it
                // is enough; only a spot that grew becomes a new, larger candidate.
                let grown = current.candidates[i].rect.union(page)
                if grown == current.candidates[i].rect { continue }
                first = current.candidates[i].first
                page = grown
                current.candidates.remove(at: i)
            }
            let inFrame = PixelRect(x: page.x, y: page.y - y, width: page.width, height: page.height)
            let inAnchor = PixelRect(x: page.x, y: page.y - anchorY, width: page.width, height: page.height)
            guard let after = Changes.crop(frame.gray, inFrame), let before = Changes.crop(anchor.gray, inAnchor) else { continue }
            current.candidates.append(ChangeCandidate(rect: page, first: first, lastSeen: frame.ref, before: anchor.ref,
                                                      after: frame.ref, beforeGray: before, afterGray: after,
                                                      beforeImage: anchor.colorCrop(inAnchor), afterImage: frame.colorCrop(inFrame),
                                                      changedAt: frame.ref.time))
        }
    }

    /// Checks every candidate the frame shows: back to before (a brief overlay, or the pointer), still the new
    /// state long enough (an edit), or changed again (keeps watching the newest state).
    private func watch(_ current: inout Run, _ frame: DecodedFrame, viewMoved: Bool) {
        let s = settings
        let h = frame.gray.height
        let top = current.region?.top ?? 0, bottom = h - (current.region?.bottom ?? 0)
        var keep: [ChangeCandidate] = []
        for var c in current.candidates {
            let screen = PixelRect(x: c.rect.x, y: c.rect.y - current.y, width: c.rect.width, height: c.rect.height)
            guard screen.y >= top, screen.maxY <= bottom, let now = Changes.crop(frame.gray, screen) else { keep.append(c); continue }
            let delta = joiner.settings.pixelDelta
            let fromBefore = Changes.difference(now, c.beforeGray, delta: delta)
            let fromAfter = Changes.difference(now, c.afterGray, delta: delta)
            // Back to (about) what was there: it came and went (a provisional edit too: that was the pointer).
            if fromBefore <= 0.02 {
                if !c.confirmed { resolveTransient(&current, c, end: frame.ref) }
                continue
            }
            if fromAfter > 0.01, Self.isEdit(c.afterGray, now, minShare: 0.02, minCount: 6) {
                // Changed again (by more than compression flicker): watch the newest state.
                c.afterGray = now
                c.afterImage = frame.colorCrop(screen)
                c.after = frame.ref
                c.changedAt = frame.ref.time
            }
            c.lastSeen = frame.ref
            if !c.confirmed, frame.ref.time - c.changedAt >= s.editSeconds, Self.isEdit(c.beforeGray, now),
               changedBeyondPointer(current, c, now: now) >= 12 {
                c.confirmed = true
            }
            keep.append(c)
        }
        current.candidates = keep
    }

    static func isLarge(_ r: PixelRect) -> Bool { r.width >= 48 && r.height >= 24 }

    /// Small spots that differ from the previous frame while the view holds still: the pointer moving.
    private func followPointer(_ current: inout Run, from before: DecodedFrame, to frame: DecodedFrame) {
        let h = frame.gray.height
        let region = current.region ?? ScrollRegion(cols: tracked ?? 0..<frame.gray.width, top: 0, bottom: 0)
        let rows = region.top..<max(region.top + 1, h - region.bottom)
        guard let moved = Changes.blobs(before.gray, frame.gray, shift: 0, rows: rows, cols: region.cols, delta: joiner.settings.pixelDelta)
        else { current.lastMotion = []; return }
        let now = moved.filter { $0.width <= 48 && $0.height <= 56 }
            .map { PixelRect(x: $0.x - 4, y: current.y + $0.y - 4, width: $0.width + 8, height: $0.height + 8) }
        func near(_ a: PixelRect, _ b: PixelRect) -> Bool {
            hypot(Double(a.x + a.width / 2 - b.x - b.width / 2), Double(a.y + a.height / 2 - b.y - b.height / 2)) <= 80
        }
        for m in now where current.lastMotion.contains(where: { near($0, m) }) {
            current.trail.append(m)
            current.trail += current.lastMotion.filter { near($0, m) }
        }
        current.lastMotion = now
        if current.trail.count > 400 { current.trail.removeFirst(current.trail.count - 400) }
    }

    /// Strongly changed pixels in `c` that the pointer's trail doesn't explain.
    private func changedBeyondPointer(_ current: Run, _ c: ChangeCandidate, now: [UInt8]) -> Int {
        let trail = current.trail.filter { $0.intersects(c.rect) }
        var n = 0
        for i in now.indices where abs(Int(now[i]) - Int(c.beforeGray[i])) > 64 {
            let x = c.rect.x + i % c.rect.width, y = c.rect.y + i / c.rect.width
            if !trail.contains(where: { x >= $0.x && x < $0.maxX && y >= $0.y && y < $0.maxY }) { n += 1 }
        }
        return n
    }

    /// Follows large spots on screen. One that held its place (even while the page scrolled) and then went away
    /// was an overlay: kept as a moment to play back, with what it showed.
    private func followOverlays(_ current: inout Run, spots: [PixelRect], in frame: DecodedFrame, shift: Int) {
        var seen = Set<Int>()
        for spot in spots {
            if let i = current.overlays.firstIndex(where: { $0.screen.intersects(spot) }) {
                seen.insert(i)
                var t = current.overlays[i]
                t.screen = t.screen.union(spot)
                t.last = frame.ref
                if let now = Changes.crop(frame.gray, t.origin), Changes.difference(now, t.originGray, delta: joiner.settings.pixelDelta) <= 0.1 {
                    t.stillUntil = frame.ref
                }
                current.overlays[i] = t
            } else if let g = Changes.crop(frame.gray, spot) {
                seen.insert(current.overlays.count)
                current.overlays.append(OverlayTrack(origin: spot, screen: spot, first: frame.ref, last: frame.ref, stillUntil: frame.ref,
                                                     originGray: g, viewY: current.y, image: frame.colorCrop(spot)))
            }
        }
        // Gone this frame: an overlay if it stayed put for a moment. A spot under a known edit is the edit.
        var keep: [OverlayTrack] = []
        for (i, t) in current.overlays.enumerated() {
            if seen.contains(i) { keep.append(t); continue }
            let page = PixelRect(x: t.origin.x, y: t.viewY + t.origin.y, width: t.origin.width, height: t.origin.height)
            let isEdit = current.candidates.contains { $0.rect.intersects(page) && $0.confirmed }
            // Held its place until it went (within a couple of frames), for long enough to see.
            let heldToTheEnd = t.last.time - t.stillUntil.time <= 0.15
            if heldToTheEnd, !isEdit, t.stillUntil.time - t.first.time >= 0.15 {
                // Parts of one overlay (a tooltip and its chart, side by side) show and go together: one event.
                if let j = current.events.lastIndex(where: { $0.kind == .overlay && abs($0.start.time - t.first.time) <= 0.1 }) {
                    current.events[j].rect = current.events[j].rect.union(page)
                    if t.last.time > current.events[j].end.time { current.events[j].end = t.last }
                    current.events[j].afterImage = nil
                } else {
                    current.events.append(FoundEvent(kind: .overlay, rect: page, start: t.first, end: t.last, before: nil,
                                                     beforeImage: nil, afterImage: t.image))
                }
            }
        }
        current.overlays = keep
    }

    /// Before and after differ like content, not like compression settling after motion: enough pixels change by
    /// a lot (a ticked box, a different digit), not a haze of small shifts at glyph edges.
    static func isEdit(_ before: [UInt8], _ after: [UInt8], minShare: Double = 0.03, minCount: Int = 12) -> Bool {
        guard before.count == after.count else { return false }
        var strong = 0
        for i in before.indices where abs(Int(before[i]) - Int(after[i])) > 64 { strong += 1 }
        return strong >= minCount && Double(strong) >= Double(before.count) * minShare
    }

    /// A change that went away before it settled: the pointer, a caret, or an overlay (which `followOverlays`
    /// keeps on its own).
    private func resolveTransient(_ current: inout Run, _ c: ChangeCandidate, end: FrameRef) {}

    /// The run is over: changes that held to the end are edits; the rest were too brief to tell.
    private func close(_ current: inout Run) {
        for c in current.candidates where c.confirmed
            || (c.lastSeen.time - c.changedAt >= settings.editSeconds && Self.isEdit(c.beforeGray, c.afterGray)
                && changedBeyondPointer(current, c, now: c.afterGray) >= 12) {
            // The canvas already shows the new state there: the old one was only the pointer in the anchor frame.
            if let shown = current.ownedGray(c.rect), !Self.isEdit(shown, c.afterGray) { continue }
            current.events.append(FoundEvent(kind: .edit, rect: c.rect, start: c.first, end: c.after, before: c.before,
                                             beforeImage: c.beforeImage, afterImage: c.afterImage))
        }
        current.candidates = []
    }

    /// The runs still open at the end, if worth keeping.
    mutating func finish() throws -> [Run] {
        guard let open = run else { return [] }
        // Still waiting for the view to come back when the recording ended: it didn't.
        if uncertain != nil {
            var finished = try giveUp(open, then: [])
            if let last = try finish().first { finished.append(last) }
            return finished
        }
        return finishOne().map { [$0] } ?? []
    }

    private mutating func finishOne() -> Run? {
        guard var current = run else { return nil }
        run = nil
        close(&current)
        if current.confirmed { return current }
        // A final state that never settled: keep it when it differs from the last item.
        guard let kept = lastKept else { return current }
        let differs = Diff.changedCount(kept.small, current.last.small, delta: settings.pixelDelta, limit: settings.changedPixels) >= settings.changedPixels
        return differs ? current : nil
    }

    private func priority(_ r: CanvasItem.Reason) -> Int {
        switch r {
        case .noOverlap, .ambiguous: 3
        case .motion: 2
        case .change: 1
        case .start, .heightLimit: 0
        }
    }
}
