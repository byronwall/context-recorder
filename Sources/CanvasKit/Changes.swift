import CoreGraphics
import Foundation

/// Local changes: the few spots that differ between two views that otherwise line up. A ticked checkbox, a
/// changed number, a menu that opens over the page, the pointer. Each becomes a candidate that is watched until
/// it either settles (a persistent edit, kept with its before and after) or goes away (a brief overlay, kept as a
/// moment to play back; or pointer noise, dropped).
enum Changes {
    static let cell = 8

    /// Bounding boxes (frame pixels, top-left origin) of clusters of 8×8 cells where `b` differs from `a` shifted
    /// by `s`, within `rows`×`cols`; nil when the differences are spread too widely to be local (a new page, a
    /// sub-pixel scroll that resampled every glyph).
    static func blobs(_ a: GrayImage, _ b: GrayImage, shift s: Int, rows: Range<Int>, cols: Range<Int>, delta: Int,
                      maxShare: Double = 0.25, maxDetailShare: Double = 0.35, maxBlobs: Int = 8) -> [PixelRect]? {
        let w = a.width, h = a.height
        let y0 = max(rows.lowerBound, rows.lowerBound - s, 1), y1 = min(rows.upperBound, rows.upperBound - s, h - 1)
        guard y1 > y0, cols.count > cell else { return [] }
        let nx = (cols.count + cell - 1) / cell, ny = (y1 - y0 + cell - 1) / cell
        var counts = [Int](repeating: 0, count: nx * ny), edges = counts
        a.pixels.withUnsafeBufferPointer { pa in
            b.pixels.withUnsafeBufferPointer { pb in
                for y in y0..<y1 {
                    let ob = y * w, oa = (y + s) * w
                    let cy = (y - y0) / cell
                    for x in stride(from: max(1, cols.lowerBound), to: cols.upperBound, by: 2) {
                        let v = Int(pb[ob + x]), p = Int(pa[oa + x])
                        if abs(v - Int(pb[ob + x - 1])) > 40 { edges[cy * nx + (x - cols.lowerBound) / cell] += 1 }
                        guard v > p + delta || v < p - delta else { continue }
                        if s != 0 {
                            // A scroll can land between rows: match against either neighbor too.
                            let q = Int(pa[oa + w + x]), r = Int(pa[oa - w + x])
                            if (v >= min(p, q) - delta && v <= max(p, q) + delta) || (v >= min(p, r) - delta && v <= max(p, r) + delta) { continue }
                        }
                        counts[cy * nx + (x - cols.lowerBound) / cell] += 1
                    }
                }
            }
        }
        // A cell changed when a few of its sampled pixels did: compression flicker is one or two.
        let changed = counts.map { $0 >= 3 }
        let total = changed.filter { $0 }.count
        if total == 0 { return [] }
        if Double(total) > Double(nx * ny) * maxShare { return nil }
        // Most of what has detail must still match: otherwise this is a different view whose blank space happens
        // to line up, not one view with a few changes.
        let detail = edges.indices.filter { edges[$0] >= 2 || changed[$0] }.count
        if Double(total) > Double(max(1, detail)) * maxDetailShare { return nil }
        // Clusters of touching cells (8-connected, with a one-cell gap bridged so a word stays one blob).
        var label = [Int](repeating: -1, count: nx * ny)
        var boxes: [(x0: Int, y0: Int, x1: Int, y1: Int)] = [], sizes: [Int] = []
        for start in changed.indices where changed[start] && label[start] < 0 {
            var stack = [start], box = (x0: Int.max, y0: Int.max, x1: Int.min, y1: Int.min), size = 0
            label[start] = boxes.count
            while let i = stack.popLast() {
                size += 1
                let cx = i % nx, cy = i / nx
                box = (min(box.x0, cx), min(box.y0, cy), max(box.x1, cx), max(box.y1, cy))
                for dy in -2...2 {
                    for dx in -2...2 {
                        let x = cx + dx, y = cy + dy
                        guard x >= 0, x < nx, y >= 0, y < ny else { continue }
                        let j = y * nx + x
                        if changed[j], label[j] < 0 { label[j] = boxes.count; stack.append(j) }
                    }
                }
            }
            boxes.append(box)
            sizes.append(size)
        }
        if boxes.count > maxBlobs { return nil }
        // A single changed cell is compression flicker or a caret, not a change worth watching.
        return zip(boxes, sizes).filter { $0.1 >= 2 }.map(\.0).map { bx in
            let x = cols.lowerBound + bx.x0 * cell, y = y0 + bx.y0 * cell
            return PixelRect(x: x, y: y, width: min(cols.upperBound, cols.lowerBound + (bx.x1 + 1) * cell) - x,
                             height: min(y1, y0 + (bx.y1 + 1) * cell) - y)
        }
    }

    /// Gray pixels of `r` (clipped to the image), row-major; nil when nothing is left.
    static func crop(_ img: GrayImage, _ r: PixelRect) -> [UInt8]? {
        let x0 = max(0, r.x), y0 = max(0, r.y), x1 = min(img.width, r.maxX), y1 = min(img.height, r.maxY)
        guard x1 > x0, y1 > y0, x1 - x0 == r.width, y1 - y0 == r.height else { return nil }
        var out = [UInt8](); out.reserveCapacity(r.width * r.height)
        for y in y0..<y1 { out.append(contentsOf: img.pixels[(y * img.width + x0)..<(y * img.width + x1)]) }
        return out
    }

    /// Share of pixels that differ by more than `delta`.
    static func difference(_ a: [UInt8], _ b: [UInt8], delta: Int) -> Double {
        guard a.count == b.count, !a.isEmpty else { return 1 }
        var n = 0
        for i in a.indices where abs(Int(a[i]) - Int(b[i])) > delta { n += 1 }
        return Double(n) / Double(a.count)
    }
}

/// A local change seen in a run, watched until it settles or goes away.
struct ChangeCandidate {
    /// Page position: x in the content box, y in the run's page coordinates (row 0 = the run's first frame's top).
    var rect: PixelRect
    var first: FrameRef
    var lastSeen: FrameRef
    /// The anchor frame that still showed the old state, and the latest frame that showed the new one.
    var before: FrameRef
    var after: FrameRef
    var beforeGray: [UInt8]
    var afterGray: [UInt8]
    var beforeImage: CGImage?
    var afterImage: CGImage?
    /// When the new state last changed: an edit has to hold still for a while (a moving pointer never does).
    var changedAt: Double
    /// Held long enough to count as an edit. Still provisional: if the spot goes back to what was there (the
    /// pointer resting, then moving on), it wasn't one.
    var confirmed = false
}

/// A large spot followed on screen: a menu, tooltip or dialog stays put while the page moves under it, then
/// goes away. One that moves with the page, or never goes away, is page content (an edit), not an overlay.
struct OverlayTrack {
    /// Where it first appeared on screen, and everything it has touched since.
    var origin: PixelRect
    var screen: PixelRect
    var first: FrameRef
    var last: FrameRef
    /// The last frame that still looked the same at `origin`: an overlay does until it goes; page content that
    /// scrolls away stops long before.
    var stillUntil: FrameRef
    var originGray: [UInt8]
    /// The page row of the view's top when it appeared.
    var viewY: Int
    var image: CGImage?
}

/// What a run found locally, ready for the canvas: rect in the run's page coordinates.
struct FoundEvent {
    enum Kind { case edit, overlay }
    var kind: Kind
    var rect: PixelRect
    var start: FrameRef
    var end: FrameRef
    var before: FrameRef?
    var beforeImage: CGImage?
    var afterImage: CGImage?
}

extension DecodedFrame {
    /// Color pixels of `r` (content-box pixels, clipped).
    func colorCrop(_ r: PixelRect) -> CGImage? {
        let y0 = max(0, r.y), y1 = min(gray.height, r.maxY)
        guard y1 > y0, let rows = colorRows(y0, y1) else { return nil }
        let x0 = max(0, r.x), x1 = min(gray.width, r.maxX)
        guard x1 > x0 else { return nil }
        return rows.cropping(to: CGRect(x: x0, y: 0, width: x1 - x0, height: y1 - y0))
    }
}
