import CoreGraphics
import Foundation

/// Hit-testing, handles, moving and resizing: everything about where shapes are, kept apart from any view
/// so it can be tested and reused on video frames.
public enum Geometry {
    // MARK: Hit-testing

    /// The topmost shape under `p`. `tolerance` is in image pixels (callers pass a few view points ÷ zoom).
    /// `kinds` limits the search, for drawing tools that only grab their own kind.
    public static func hit(_ doc: AnnotationDoc, at p: CGPoint, tolerance: Double, kinds: Set<Shape.Kind>? = nil,
                           selected: Shape.ID? = nil) -> Shape.ID? {
        for shape in doc.shapes.reversed() where kinds?.contains(shape.kind) ?? true {
            if contains(shape, p, tolerance: tolerance, selected: shape.id == selected) { return shape.id }
        }
        return nil
    }

    public static func contains(_ shape: Shape, _ p: CGPoint, tolerance t: Double, selected: Bool = false) -> Bool {
        switch shape.kind {
        case .rect:
            // The outline, or anywhere inside once selected (so a selected box can be dragged by its middle).
            let r = shape.rect
            if selected { return r.insetBy(dx: -t, dy: -t).contains(p) }
            let outer = r.insetBy(dx: -(t + shape.lineWidth / 2), dy: -(t + shape.lineWidth / 2))
            let inner = r.insetBy(dx: t + shape.lineWidth / 2, dy: t + shape.lineWidth / 2)
            return outer.contains(p) && (inner.isNull || inner.isEmpty || !inner.contains(p))
        case .highlight, .text:
            return Renderer.bounds(shape).insetBy(dx: -t, dy: -t).contains(p)
        case .arrow:
            if selected, Renderer.bounds(shape).insetBy(dx: -t, dy: -t).contains(p) { return true }
            guard shape.points.count >= 2 else { return false }
            return distance(p, segment: shape.points[0], shape.points[1]) <= t + shape.lineWidth * 1.5
        case .freehand:
            if selected { return Renderer.bounds(shape).insetBy(dx: -t, dy: -t).contains(p) }
            let reach = t + shape.lineWidth / 2
            if shape.points.count == 1 { return hypot(p.x - shape.points[0].x, p.y - shape.points[0].y) <= reach }
            for i in 1..<shape.points.count where distance(p, segment: shape.points[i - 1], shape.points[i]) <= reach { return true }
            return false
        }
    }

    public static func distance(_ p: CGPoint, segment a: CGPoint, _ b: CGPoint) -> Double {
        let dx = b.x - a.x, dy = b.y - a.y
        let len2 = dx * dx + dy * dy
        guard len2 > 0 else { return hypot(p.x - a.x, p.y - a.y) }
        let t = (((p.x - a.x) * dx + (p.y - a.y) * dy) / len2).clamped(0, 1)
        return hypot(p.x - (a.x + t * dx), p.y - (a.y + t * dy))
    }

    // MARK: Handles

    public enum Handle: Hashable, Sendable {
        /// Rect, highlight and crop: corners and edge midpoints. x and y are each -1, 0 or 1.
        case frame(x: Int, y: Int)
        /// Arrow ends.
        case tail, tip
        /// Text: left or right edge, changing the wrap width.
        case wrap(edge: Int)
    }

    public static func handles(_ shape: Shape) -> [(Handle, CGPoint)] {
        switch shape.kind {
        case .rect, .highlight: return frameHandles(shape.rect)
        case .arrow: return shape.points.count >= 2 ? [(.tail, shape.points[0]), (.tip, shape.points[1])] : []
        case .text:
            let b = Renderer.bounds(shape)
            return [(.wrap(edge: -1), CGPoint(x: b.minX, y: b.midY)), (.wrap(edge: 1), CGPoint(x: b.maxX, y: b.midY))]
        case .freehand: return []
        }
    }

    public static func frameHandles(_ r: CGRect) -> [(Handle, CGPoint)] {
        var out: [(Handle, CGPoint)] = []
        for y in -1...1 {
            for x in -1...1 where !(x == 0 && y == 0) {
                out.append((.frame(x: x, y: y), CGPoint(x: r.midX + CGFloat(x) * r.width / 2, y: r.midY + CGFloat(y) * r.height / 2)))
            }
        }
        return out
    }

    public static func handle(of shape: Shape, at p: CGPoint, tolerance: Double) -> Handle? {
        handles(shape).min { hypot($0.1.x - p.x, $0.1.y - p.y) < hypot($1.1.x - p.x, $1.1.y - p.y) }
            .flatMap { hypot($0.1.x - p.x, $0.1.y - p.y) <= tolerance ? $0.0 : nil }
    }

    public static func frameHandle(of rect: CGRect, at p: CGPoint, tolerance: Double) -> Handle? {
        frameHandles(rect).first { hypot($0.1.x - p.x, $0.1.y - p.y) <= tolerance }?.0
    }

    // MARK: Editing

    public static func moved(_ shape: Shape, by d: CGSize) -> Shape {
        var s = shape
        s.points = s.points.map { CGPoint(x: $0.x + d.width, y: $0.y + d.height) }
        return s
    }

    /// `start` is the shape when the drag began; `p` is the pointer now.
    public static func resized(_ start: Shape, handle: Handle, to p: CGPoint) -> Shape {
        var s = start
        switch handle {
        case .frame:
            let r = resizedFrame(start.rect, handle: handle, to: p)
            s.points = [CGPoint(x: r.minX, y: r.minY), CGPoint(x: r.maxX, y: r.maxY)]
        case .tail where s.points.count >= 2: s.points[0] = p
        case .tip where s.points.count >= 2: s.points[1] = p
        case .wrap(let edge):
            let b = Renderer.bounds(start)
            let pad = Style.textPadding(fontSize: start.fontSize ?? 24)
            let minWidth = (start.fontSize ?? 24) * 2
            if edge > 0 {
                s.wrapWidth = max(minWidth, p.x - b.minX - pad * 2)
            } else {
                let width = max(minWidth, b.maxX - p.x - pad * 2)
                s.wrapWidth = width
                s.points[0].x = b.maxX - width - pad * 2
            }
        default: break
        }
        return s
    }

    /// Drags one corner or edge of `r`; dragging past the opposite side flips it rather than going negative.
    public static func resizedFrame(_ r: CGRect, handle: Handle, to p: CGPoint) -> CGRect {
        guard case .frame(let hx, let hy) = handle else { return r }
        var minX = r.minX, maxX = r.maxX, minY = r.minY, maxY = r.maxY
        if hx < 0 { minX = p.x } else if hx > 0 { maxX = p.x }
        if hy < 0 { minY = p.y } else if hy > 0 { maxY = p.y }
        return CGRect(x: min(minX, maxX), y: min(minY, maxY), width: abs(maxX - minX), height: abs(maxY - minY))
    }

    // MARK: Freehand

    /// Drops points closer than `minDistance` to the last kept one, then smooths twice (Chaikin), keeping
    /// the stroke's real ends.
    public static func smoothed(_ points: [CGPoint], minDistance: Double) -> [CGPoint] {
        guard var kept = points.first.map({ [$0] }) else { return [] }
        for p in points.dropFirst() where hypot(p.x - kept[kept.count - 1].x, p.y - kept[kept.count - 1].y) >= minDistance {
            kept.append(p)
        }
        if let last = points.last, kept.count > 1, kept[kept.count - 1] != last { kept.append(last) }
        guard kept.count > 2 else { return kept }
        for _ in 0..<2 {
            var next = [kept[0]]
            for i in 0..<(kept.count - 1) {
                let a = kept[i], b = kept[i + 1]
                next.append(CGPoint(x: a.x * 0.75 + b.x * 0.25, y: a.y * 0.75 + b.y * 0.25))
                next.append(CGPoint(x: a.x * 0.25 + b.x * 0.75, y: a.y * 0.25 + b.y * 0.75))
            }
            next.append(kept[kept.count - 1])
            kept = next
        }
        return kept
    }
}

/// Linear undo and redo over whole document snapshots. Documents are small, so snapshots keep this simple
/// and make every edit (draw, move, recolor, crop) undoable the same way.
public struct History<Value: Equatable>: Sendable where Value: Sendable {
    public private(set) var undoStack: [Value] = []
    public private(set) var redoStack: [Value] = []
    public var limit = 200

    public init() {}

    public var canUndo: Bool { !undoStack.isEmpty }
    public var canRedo: Bool { !redoStack.isEmpty }

    /// Call with the value as it was before a change.
    public mutating func record(_ before: Value) {
        if undoStack.last == before { return }
        undoStack.append(before)
        if undoStack.count > limit { undoStack.removeFirst() }
        redoStack.removeAll()
    }

    public mutating func undo(_ current: Value) -> Value? {
        guard let previous = undoStack.popLast() else { return nil }
        redoStack.append(current)
        return previous
    }

    public mutating func redo(_ current: Value) -> Value? {
        guard let next = redoStack.popLast() else { return nil }
        undoStack.append(current)
        return next
    }
}
