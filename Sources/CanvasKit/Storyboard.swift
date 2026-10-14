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
