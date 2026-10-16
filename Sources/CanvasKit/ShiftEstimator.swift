import CoreGraphics
import Foundation
import Vision

/// How far the content moved between two frames: `cur[y] == prev[y + shift]` (scrolling down is positive).
public struct ShiftEstimate: Sendable {
    public var shift: Int
    /// Mean absolute row-profile difference at `shift` (gray levels); lower is better.
    public var cost: Double
    /// The best cost at any other shift at least 3 px away, if the estimator searched; near `cost` = ambiguous.
    public var runnerUp: Double?
    /// Sub-pixel refinement: the content moved `shift + fraction` rows (|fraction| ≤ 0.5). Slow trackpad scrolling
    /// moves less than a pixel a frame; rounding every step would drift.
    public var fraction: Double = 0
}

/// Estimates vertical scrolling between two frames, within rows `rows` and columns `cols` of the content box
/// (full resolution).
public protocol ShiftEstimator: Sendable {
    var name: String { get }
    func estimate(_ prev: DecodedFrame, _ cur: DecodedFrame, rows: Range<Int>, cols: Range<Int>) -> ShiftEstimate?
}

extension ShiftEstimator {
    public func estimate(_ prev: DecodedFrame, _ cur: DecodedFrame, rows: Range<Int>) -> ShiftEstimate? {
        estimate(prev, cur, rows: rows, cols: 0..<prev.gray.width)
    }
}

/// Matches row profiles: each row reduced to the mean gray of `bins` column bands. Every candidate shift is
/// scored at full resolution on every other row; the best few are rescored on all rows. The runner-up (the best
/// shift at least 3 px from the winner) says whether another distance fits nearly as well: repeated rows, blank space.
public struct RowProfileEstimator: ShiftEstimator {
    public var name: String { "row-profile" }
    public var bins = 16
    /// Overlap needed for a candidate shift, as a share of the moving rows.
    public var minOverlap = 0.2

    public init() {}

    public func estimate(_ prev: DecodedFrame, _ cur: DecodedFrame, rows: Range<Int>, cols: Range<Int>) -> ShiftEstimate? {
        let pa = profiles(prev.gray, rows, cols), pb = profiles(cur.gray, rows, cols)
        let m = rows.count
        let minRows = max(16, Int(Double(m) * minOverlap))
        guard m > minRows else { return nil }
        let range = -(m - minRows)...(m - minRows)
        var coarse: [(s: Int, c: Double)] = []
        coarse.reserveCapacity(range.count)
        for s in range { coarse.append((s, cost(pa, pb, shift: s, rows: m, step: 2))) }
        // Rescore the strongest candidates on every row.
        let top = coarse.sorted { $0.c < $1.c }.prefix(12)
        var fine: [(s: Int, c: Double)] = []
        for cand in top {
            for s in (cand.s - 1)...(cand.s + 1) where range.contains(s) && !fine.contains(where: { $0.s == s }) {
                fine.append((s, cost(pa, pb, shift: s, rows: m, step: 1)))
            }
        }
        guard let best = fine.min(by: { $0.c < $1.c }) else { return nil }
        let runnerUp = fine.filter { abs($0.s - best.s) >= 3 }.map(\.c).min()
        // A parabola through the costs either side of the best places the minimum between rows.
        var fraction = 0.0
        if range.contains(best.s - 1), range.contains(best.s + 1) {
            let l = cost(pa, pb, shift: best.s - 1, rows: m, step: 1), r = cost(pa, pb, shift: best.s + 1, rows: m, step: 1)
            let curve = l - 2 * best.c + r
            if curve > 1e-6 { fraction = max(-0.5, min(0.5, 0.5 * (l - r) / curve)) }
        }
        return ShiftEstimate(shift: best.s, cost: best.c, runnerUp: runnerUp, fraction: fraction)
    }

    /// rows × bins means, row-major.
    private func profiles(_ img: GrayImage, _ rows: Range<Int>, _ cols: Range<Int>) -> [Float] {
        var out = [Float](repeating: 0, count: rows.count * bins)
        let w = img.width, cw = cols.count, cx = cols.lowerBound
        img.pixels.withUnsafeBufferPointer { px in
            for (r, y) in rows.enumerated() {
                let base = y * w
                for k in 0..<bins {
                    let x0 = cx + k * cw / bins, x1 = cx + (k + 1) * cw / bins
                    var sum = 0
                    for x in x0..<x1 { sum += Int(px[base + x]) }
                    out[r * bins + k] = Float(sum) / Float(max(1, x1 - x0))
                }
            }
        }
        return out
    }

    /// Mean |a[y + s] - b[y]| over the rows where both exist, taking every `step`-th row.
    private func cost(_ a: [Float], _ b: [Float], shift s: Int, rows m: Int, step: Int) -> Double {
        let y0 = max(0, -s), y1 = min(m, m - s)
        guard y1 > y0 else { return .infinity }
        var total: Float = 0
        var n = 0
        a.withUnsafeBufferPointer { pa in
            b.withUnsafeBufferPointer { pb in
                var y = y0
                while y < y1 {
                    let ra = (y + s) * bins, rb = y * bins
                    for k in 0..<bins { total += abs(pa[ra + k] - pb[rb + k]) }
                    n += 1
                    y += step
                }
            }
        }
        return Double(total) / Double(max(1, n * bins))
    }
}

/// Apple Vision's translational registration. It returns one translation without an ambiguity signal.
public struct VisionEstimator: ShiftEstimator {
    public var name: String { "vision" }
    public init() {}

    public func estimate(_ prev: DecodedFrame, _ cur: DecodedFrame, rows: Range<Int>, cols: Range<Int>) -> ShiftEstimate? {
        guard let a = Self.cgImage(prev.gray, rows), let b = Self.cgImage(cur.gray, rows) else { return nil }
        let request = VNTranslationalImageRegistrationRequest(targetedCGImage: b)
        let handler = VNImageRequestHandler(cgImage: a)
        guard (try? handler.perform([request])) != nil,
              let obs = request.results?.first as? VNImageTranslationAlignmentObservation else { return nil }
        // Vision's y axis points up: content moving up (scrolling down) is a negative ty in image terms.
        let ty = obs.alignmentTransform.ty
        return ShiftEstimate(shift: Int((-ty).rounded()), cost: 0, runnerUp: nil)
    }

    static func cgImage(_ img: GrayImage, _ rows: Range<Int>) -> CGImage? {
        let data = Data(img.pixels[(rows.lowerBound * img.width)..<(rows.upperBound * img.width)])
        guard let provider = CGDataProvider(data: data as CFData) else { return nil }
        return CGImage(width: img.width, height: rows.count, bitsPerComponent: 8, bitsPerPixel: 8, bytesPerRow: img.width,
                       space: CGColorSpaceCreateDeviceGray(), bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.none.rawValue),
                       provider: provider, decode: nil, shouldInterpolate: false, intent: .defaultIntent)
    }
}
