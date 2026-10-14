import Foundation

/// Change thresholds, at half resolution.
public struct StoryboardSettings: Sendable {
    /// A pixel counts as changed when its gray value moves by more than this.
    public var pixelDelta = 24
    /// Two frames differ when at least this many pixels changed: well above a blinking caret
    /// (about 8 pixels at half size), below a one-word edit.
    public var changedPixels = 60
    /// A new state must hold still this long before it becomes a card, so transitions don't.
    /// Shorter than the 500 ms an edit has to stay visible to be kept.
    public var settleSeconds = 0.35
    /// While the view keeps moving, take a card whenever this share of the box differs from the last card…
    public var motionShare = 0.25
    /// …and at least this long has passed since it.
    public var motionSeconds = 0.6

    public init() {}
}

enum Diff {
    /// Pixels whose gray value differs by more than `delta`. Stops counting at `limit`.
    static func changedCount(_ a: GrayImage, _ b: GrayImage, delta: Int, limit: Int = .max) -> Int {
        precondition(a.width == b.width && a.height == b.height)
        var count = 0
        a.pixels.withUnsafeBufferPointer { pa in
            b.pixels.withUnsafeBufferPointer { pb in
                let n = pa.count
                var i = 0
                while i < n {
                    let d = Int(pa[i]) - Int(pb[i])
                    if d > delta || d < -delta {
                        count += 1
                        if count >= limit { return }
                    }
                    i += 1
                }
            }
        }
        return count
    }
}

/// Splits a recording into cards: one per state that held still, plus periodic cards while the view keeps
/// moving. This is the fallback for everything the scroll joiner refuses.
struct StoryboardTracker {
    let settings: StoryboardSettings
    let pixelCount: Int

    /// The current card's frame.
    private(set) var card: DecodedFrame?
    private var previous: DecodedFrame?
    /// The first frame of the current still stretch, if the view is holding still.
    private var stillSince: DecodedFrame?

    init(settings: StoryboardSettings, pixelCount: Int) {
        self.settings = settings
        self.pixelCount = pixelCount
    }

    enum Event {
        case card(DecodedFrame, CanvasItem.Reason)
    }

    mutating func feed(_ frame: DecodedFrame) -> Event? {
        defer { previous = frame }
        guard let card else {
            self.card = frame
            stillSince = frame
            return .card(frame, .start)
        }
        let s = settings
        let moved = previous.map { Diff.changedCount($0.small, frame.small, delta: s.pixelDelta, limit: s.changedPixels) >= s.changedPixels } ?? false
        if moved { stillSince = nil } else if stillSince == nil { stillSince = previous ?? frame }

        if let still = stillSince {
            // Holding still: a new state once it has lasted long enough and differs from the card.
            guard frame.ref.time - still.ref.time >= s.settleSeconds, still !== card else { return nil }
            let differs = Diff.changedCount(card.small, still.small, delta: s.pixelDelta, limit: s.changedPixels) >= s.changedPixels
            guard differs else { return nil }
            self.card = still
            return .card(still, .change)
        }
        // Still moving: keep a card now and then so fast scrolling and animation leave a trail.
        guard frame.ref.time - card.ref.time >= s.motionSeconds else { return nil }
        let limit = Int(Double(pixelCount) * s.motionShare)
        guard Diff.changedCount(card.small, frame.small, delta: s.pixelDelta, limit: limit) >= limit else { return nil }
        self.card = frame
        return .card(frame, .motion)
    }
}
