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
    /// Page position of `last`'s top row, relative to `start`.
    var y = 0
    var patches: [PendingPatch]
    /// The rows with real content so far (relative to `start`).
    var contentTop: Int
    var contentBottom: Int
    /// The columns that scroll, once a join found a sidebar that doesn't; nil = the whole box.
    var cols: Range<Int>?

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
    }

    var isColumn: Bool { patches.count > 1 }
    var height: Int { contentBottom - contentTop }

    /// `frame` shows the page `shift` rows further down than `ref`. Adds the rows not seen yet.
    mutating func append(_ frame: DecodedFrame, shift: Int, fixedTop: Int, fixedBottom: Int) {
        let h = frame.gray.height
        // A fixed footer or header on the frame that set the column's edge isn't page content; let real rows replace it.
        if fixedBottom > 0, contentBottom == y + h { contentBottom = y + h - fixedBottom }
        if fixedTop > 0, contentTop == y { contentTop = y + fixedTop }
        let newY = y + shift
        let moving = fixedTop..<(h - fixedBottom)
        // New rows below.
        let belowStart = max(contentBottom - newY, moving.lowerBound)
        let below = min(belowStart, moving.upperBound)..<moving.upperBound
        if !below.isEmpty, let image = frame.colorRows(below.lowerBound, below.upperBound) {
            patches.append(PendingPatch(frame: frame.ref, sourceY: below.lowerBound, destY: newY + below.lowerBound,
                                        height: below.count, image: image))
            contentBottom = newY + below.upperBound
        }
        // New rows above (scrolling back up past where the run started).
        let aboveEnd = min(contentTop - newY, moving.upperBound)
        let above = moving.lowerBound..<max(aboveEnd, moving.lowerBound)
        if !above.isEmpty, let image = frame.colorRows(above.lowerBound, above.upperBound) {
            patches.append(PendingPatch(frame: frame.ref, sourceY: above.lowerBound, destY: newY + above.lowerBound,
                                        height: above.count, image: image))
            contentTop = newY + above.lowerBound
        }
        y = newY
        last = frame
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

    init(settings: StoryboardSettings, joiner: Joiner, pixelCount: Int) {
        self.settings = settings
        self.joiner = joiner
        self.pixelCount = pixelCount
    }

    /// Feeds one frame; returns any runs that are finished and kept.
    mutating func feed(_ frame: DecodedFrame) throws -> [Run] {
        guard var current = run else {
            run = try Run(start: frame, reason: .start, confirmed: true)
            return []
        }
        let s = settings
        var result: JoinResult = .same
        if Diff.changedCount(current.last.small, frame.small, delta: s.pixelDelta, limit: s.changedPixels) >= s.changedPixels {
            result = joiner.join(current.last, frame, cols: current.cols)
        }
        if result == .same {
            // Holding still: a tentative run that lasts becomes a card.
            if !current.confirmed, frame.ref.time - current.last.ref.time >= s.settleSeconds {
                current.confirmed = true
                run = current
            }
            return []
        }

        if case let .shift(shift, top, bottom, cols) = result {
            if cols != 0..<frame.gray.width { current.cols = cols }
            current.append(frame, shift: shift, fixedTop: top, fixedBottom: bottom)
            current.confirmed = true
            if current.height > joiner.settings.maxColumnHeight {
                run = nil
                lastKept = current.last
                run = try Run(start: frame, reason: .heightLimit, confirmed: true)
                return [current]
            }
            run = current
            return []
        }

        // The run ends here; what comes next starts a new tentative run.
        let reason: CanvasItem.Reason = switch result {
        case .noOverlap: .noOverlap
        case .ambiguous: .ambiguous
        default: .change
        }
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

    /// The last run, if worth keeping.
    mutating func finish() -> Run? {
        guard let current = run else { return nil }
        run = nil
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
