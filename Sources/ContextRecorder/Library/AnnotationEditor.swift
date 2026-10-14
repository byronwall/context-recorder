import Annotation
import AppKit

/// Annotating one image, RegionShot style: one key per tool, draw straight on the image, then move,
/// resize, recolor, delete, undo. Works in image pixels; the canvas converts the pointer and draws.
@MainActor @Observable
final class AnnotationEditor {
    enum Tool: String, CaseIterable, Identifiable {
        case select, rect, arrow, text, highlight, freehand, crop
        var id: String { rawValue }

        var key: Character {
            switch self {
            case .select: "v"
            case .rect: "r"
            case .arrow: "a"
            case .text: "t"
            case .highlight: "h"
            case .freehand: "p"
            case .crop: "c"
            }
        }

        var name: String {
            switch self {
            case .select: "Select"
            case .rect: "Rectangle"
            case .arrow: "Arrow"
            case .text: "Text"
            case .highlight: "Highlight"
            case .freehand: "Freehand"
            case .crop: "Crop"
            }
        }

        var symbol: String {
            switch self {
            case .select: "cursorarrow"
            case .rect: "rectangle"
            case .arrow: "arrow.up.right"
            case .text: "textformat"
            case .highlight: "highlighter"
            case .freehand: "scribble"
            case .crop: "crop"
            }
        }

        /// The shape a drawing tool makes, and the only kind it grabs.
        var kind: Shape.Kind? {
            switch self {
            case .rect: .rect
            case .arrow: .arrow
            case .text: .text
            case .highlight: .highlight
            case .freehand: .freehand
            case .select, .crop: nil
            }
        }
    }

    private(set) var doc: AnnotationDoc
    /// The document as it was opened; `isDirty` compares against it.
    let original: AnnotationDoc
    private(set) var history = History<AnnotationDoc>()
    var tool: Tool = .select {
        didSet {
            guard tool != oldValue else { return }
            if oldValue == .crop { pendingCrop = nil }
            if tool == .crop { pendingCrop = doc.crop ?? fullRect }
            if editingText != nil { canvas?.endTextEditing(commit: true) }
            if let kind = tool.kind, let s = selected, s.kind != kind { selection = nil }
            canvas?.contentDidChange(refit: oldValue == .crop || tool == .crop)
        }
    }
    var color = Style.defaultColor
    var highlightColor = Style.defaultHighlight
    var selection: Shape.ID? { didSet { canvas?.needsDisplay = true } }
    private(set) var hovered: Shape.ID?
    /// The crop being dragged out with the crop tool; Return applies it.
    private(set) var pendingCrop: CGRect?
    /// The text shape open in the inline editor.
    var editingText: Shape.ID?

    @ObservationIgnored weak var canvas: ImageCanvasView?
    @ObservationIgnored private var drag: Drag?
    @ObservationIgnored private var before: AnnotationDoc?

    private enum Drag {
        case create(Shape.ID, from: CGPoint)
        case move(Shape.ID, start: Shape, from: CGPoint)
        case resize(Shape.ID, Geometry.Handle, start: Shape)
        case crop(from: CGPoint)
        case cropMove(start: CGRect, from: CGPoint)
        case cropResize(Geometry.Handle, start: CGRect)
    }

    init(doc: AnnotationDoc) {
        self.doc = doc
        original = doc
    }

    var isDirty: Bool { doc != original }
    var selected: Shape? { selection.flatMap { doc[$0] } }
    private var fullRect: CGRect { CGRect(origin: .zero, size: doc.imageSize) }
    /// What the canvas shows: the whole image while cropping, else the kept area.
    var visibleRect: CGRect { tool == .crop ? fullRect : doc.contentRect }

    private var lineWidth: Double { Style.lineWidth(for: doc.contentRect.size) }
    private var fontSize: Double { Style.fontSize(for: doc.contentRect.size) }

    // MARK: Changes (all undoable)

    private func change(_ body: (inout AnnotationDoc) -> Void) {
        let old = doc
        body(&doc)
        if doc != old { history.record(old) }
        canvas?.needsDisplay = true
    }

    func undo() {
        if editingText != nil { canvas?.endTextEditing(commit: true) }
        guard let previous = history.undo(doc) else { NSSound.beep(); return }
        restore(previous)
    }

    func redo() {
        guard let next = history.redo(doc) else { NSSound.beep(); return }
        restore(next)
    }

    private func restore(_ value: AnnotationDoc) {
        let cropChanged = value.crop != doc.crop
        doc = value
        if let s = selection, doc[s] == nil { selection = nil }
        if tool == .crop { pendingCrop = doc.crop ?? fullRect }
        canvas?.contentDidChange(refit: cropChanged)
    }

    func deleteSelection() {
        guard let id = selection else { return }
        change { $0[id] = nil }
        selection = nil
    }

    /// Picks the color for new shapes and recolors the selection, as RegionShot does.
    func setColor(_ hex: String) {
        let highlighting = tool == .highlight || selected?.kind == .highlight
        if highlighting { highlightColor = hex } else { color = hex }
        if let id = selection, let s = doc[id], (s.kind == .highlight) == highlighting {
            change { $0[id]?.color = hex }
        }
    }

    /// The color the palette shows as current.
    var activeColor: String {
        if let s = selected { return s.color }
        return tool == .highlight ? highlightColor : color
    }

    var showsHighlightPalette: Bool { tool == .highlight || selected?.kind == .highlight }

    func nudge(_ dx: Double, _ dy: Double) {
        guard let id = selection else { return }
        change { $0[id] = $0[id].map { Geometry.moved($0, by: CGSize(width: dx, height: dy)) } }
    }

    // MARK: Crop

    func applyCrop() {
        let full = fullRect
        guard let rect = pendingCrop?.integral.intersection(full), rect.width >= 4, rect.height >= 4 else { return }
        change { $0.crop = rect == full ? nil : rect }
        tool = .select
    }

    func clearCrop() {
        pendingCrop = fullRect
        canvas?.needsDisplay = true
    }

    // MARK: Pointer (image pixels; `t` is a few view points in image pixels)

    /// Returns false to let the canvas pan instead.
    func down(at p: CGPoint, tolerance t: Double, clickCount: Int) -> Bool {
        if editingText != nil {
            // A click away commits the text without starting something new.
            canvas?.endTextEditing(commit: true)
            return true
        }
        before = doc
        switch tool {
        case .crop:
            let rect = pendingCrop ?? fullRect
            if let h = Geometry.frameHandle(of: rect, at: p, tolerance: t * 1.6) {
                drag = .cropResize(h, start: rect)
            } else if rect.contains(p), rect != fullRect {
                drag = .cropMove(start: rect, from: p)
            } else {
                drag = .crop(from: p)
            }
            return true
        case .select:
            if clickCount == 2, let id = Geometry.hit(doc, at: p, tolerance: t, kinds: [.text], selected: selection) {
                selection = id
                canvas?.beginTextEditing(id)
                return true
            }
            if grabSelectionOrShape(at: p, tolerance: t, kinds: nil) { return true }
            selection = nil
            return false
        case .text:
            if let id = Geometry.hit(doc, at: p, tolerance: t, kinds: [.text], selected: selection) {
                if let h = selected.flatMap({ Geometry.handle(of: $0, at: p, tolerance: t * 1.6) }), selection == id {
                    drag = .resize(id, h, start: doc[id]!)
                    return true
                }
                // First click selects (and can drag it); clicking the selected text edits it.
                let wasSelected = selection == id
                selection = id
                if clickCount >= 2 || wasSelected {
                    canvas?.beginTextEditing(id)
                } else {
                    drag = .move(id, start: doc[id]!, from: p)
                }
                return true
            }
            let shape = Shape(kind: .text, color: color, lineWidth: lineWidth, points: [p], text: "", fontSize: fontSize)
            doc.shapes.append(shape)
            selection = shape.id
            canvas?.beginTextEditing(shape.id)
            return true
        case .rect, .arrow, .highlight, .freehand:
            let kind = tool.kind!
            if grabSelectionOrShape(at: p, tolerance: t, kinds: [kind]) { return true }
            let shape = Shape(kind: kind, color: kind == .highlight ? highlightColor : color, lineWidth: lineWidth, points: [p, p])
            doc.shapes.append(shape)
            selection = nil
            drag = .create(shape.id, from: p)
            return true
        }
    }

    /// A drawing tool edits shapes of its own kind: grab a handle of the selection, or a shape's body.
    private func grabSelectionOrShape(at p: CGPoint, tolerance t: Double, kinds: Set<Shape.Kind>?) -> Bool {
        if let s = selected, kinds?.contains(s.kind) ?? true, let h = Geometry.handle(of: s, at: p, tolerance: t * 1.6) {
            drag = .resize(s.id, h, start: s)
            return true
        }
        if let id = Geometry.hit(doc, at: p, tolerance: t, kinds: kinds, selected: selection) {
            selection = id
            drag = .move(id, start: doc[id]!, from: p)
            return true
        }
        return false
    }

    func dragged(to p: CGPoint, tolerance t: Double, constrain: Bool) {
        switch drag {
        case .create(let id, let from)?:
            guard var s = doc[id] else { return }
            if s.kind == .freehand {
                if let last = s.points.last, hypot(p.x - last.x, p.y - last.y) >= t / 4 { s.points.append(p) }
            } else {
                s.points = [from, constrain ? constrained(from, p, kind: s.kind) : p]
            }
            doc[id] = s
        case .move(let id, let start, let from)?:
            doc[id] = Geometry.moved(start, by: CGSize(width: p.x - from.x, height: p.y - from.y))
        case .resize(let id, let handle, let start)?:
            doc[id] = Geometry.resized(start, handle: handle, to: p)
        case .crop(let from)?:
            pendingCrop = CGRect(x: min(from.x, p.x), y: min(from.y, p.y), width: abs(p.x - from.x), height: abs(p.y - from.y))
                .intersection(fullRect)
        case .cropMove(let start, let from)?:
            var r = start.offsetBy(dx: p.x - from.x, dy: p.y - from.y)
            r.origin.x = r.origin.x.clamped(to: 0...(fullRect.width - r.width))
            r.origin.y = r.origin.y.clamped(to: 0...(fullRect.height - r.height))
            pendingCrop = r
        case .cropResize(let handle, let start)?:
            pendingCrop = Geometry.resizedFrame(start, handle: handle, to: p).intersection(fullRect)
        case nil: return
        }
        canvas?.needsDisplay = true
    }

    /// Shift: squares, and arrows snapped to 45°.
    private func constrained(_ from: CGPoint, _ p: CGPoint, kind: Shape.Kind) -> CGPoint {
        let dx = p.x - from.x, dy = p.y - from.y
        if kind == .arrow {
            let angle = (atan2(dy, dx) / (.pi / 4)).rounded() * (.pi / 4)
            let length = hypot(dx, dy)
            return CGPoint(x: from.x + cos(angle) * length, y: from.y + sin(angle) * length)
        }
        let side = max(abs(dx), abs(dy))
        return CGPoint(x: from.x + (dx < 0 ? -side : side), y: from.y + (dy < 0 ? -side : side))
    }

    /// `t` doubles as the dead-click threshold: anything smaller was a click, not a drawing.
    func up(at p: CGPoint, tolerance t: Double) {
        defer { drag = nil; canvas?.needsDisplay = true }
        switch drag {
        case .create(let id, _)?:
            guard let s = doc[id] else { break }
            let b = Renderer.bounds(s)
            let tiny = s.kind == .freehand ? s.points.count < 2 || max(b.width, b.height) < t * 1.2 + s.lineWidth
                                           : hypot(s.points[1].x - s.points[0].x, s.points[1].y - s.points[0].y) < t * 1.2
            if tiny {
                // A dead click deselects instead of leaving a speck.
                doc[id] = nil
                selection = nil
                before = nil
                return
            }
            if s.kind == .freehand { doc[id]?.points = Geometry.smoothed(s.points, minDistance: t / 3) }
            selection = id
        case .crop?:
            if let r = pendingCrop, r.width < t || r.height < t { pendingCrop = doc.crop ?? fullRect }
            before = nil
            return
        case .cropMove?, .cropResize?:
            before = nil
            return
        default: break
        }
        commitGesture()
    }

    private func commitGesture() {
        if let before, before != doc { history.record(before) }
        before = nil
    }

    func hover(_ p: CGPoint?, tolerance t: Double) -> NSCursor {
        guard let p else { setHovered(nil); return .arrow }
        if editingText != nil { setHovered(nil); return .arrow }
        switch tool {
        case .crop:
            let rect = pendingCrop ?? fullRect
            if let h = Geometry.frameHandle(of: rect, at: p, tolerance: t * 1.6) { return Self.cursor(for: h) }
            return rect.contains(p) && rect != fullRect ? .openHand : .crosshair
        case .select:
            if let s = selected, let h = Geometry.handle(of: s, at: p, tolerance: t * 1.6) { setHovered(s.id); return Self.cursor(for: h) }
            let id = Geometry.hit(doc, at: p, tolerance: t, selected: selection)
            setHovered(id)
            return id == nil ? .openHand : .arrow
        default:
            let kind = tool.kind!
            if let s = selected, s.kind == kind, let h = Geometry.handle(of: s, at: p, tolerance: t * 1.6) { setHovered(s.id); return Self.cursor(for: h) }
            let id = Geometry.hit(doc, at: p, tolerance: t, kinds: [kind], selected: selection)
            setHovered(id)
            if id != nil { return kind == .text ? .iBeam : .openHand }
            return kind == .text ? .iBeam : .crosshair
        }
    }

    private func setHovered(_ id: Shape.ID?) {
        guard hovered != id else { return }
        hovered = id
        canvas?.needsDisplay = true
    }

    private static func cursor(for handle: Geometry.Handle) -> NSCursor {
        switch handle {
        case .frame(let x, let y):
            let position: NSCursor.FrameResizePosition = switch (x, y) {
            case (-1, -1): .topLeft
            case (1, -1): .topRight
            case (-1, 1): .bottomLeft
            case (1, 1): .bottomRight
            case (0, -1): .top
            case (0, 1): .bottom
            case (-1, 0): .left
            default: .right
            }
            return .frameResize(position: position, directions: .all)
        case .wrap(let edge): return .frameResize(position: edge < 0 ? .left : .right, directions: .all)
        case .tail, .tip: return .crosshair
        }
    }

    // MARK: Text

    /// The inline editor's text changed: grow the shape with it.
    func updateText(_ id: Shape.ID, _ text: String) {
        doc[id]?.text = text
    }

    /// `before` is the document when editing began, so the whole edit undoes in one step.
    func finishText(_ id: Shape.ID, commit: Bool, before: AnnotationDoc) {
        editingText = nil
        let text = doc[id]?.text?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if !commit {
            doc = before
        } else if text.isEmpty {
            doc[id] = nil
        }
        if doc[id] == nil, selection == id { selection = nil }
        if doc != before { history.record(before) }
        canvas?.needsDisplay = true
    }

    // MARK: Keys

    /// Tool keys, Delete, Return/Esc for crop and drawing, arrow nudges. False: not ours.
    func keyDown(_ event: NSEvent) -> Bool {
        guard event.modifierFlags.intersection([.command, .control, .option]).isEmpty else { return false }
        switch event.keyCode {
        case 51, 117:   // delete, forward delete
            guard selection != nil else { return false }
            deleteSelection()
            return true
        case 36, 76:    // return, enter
            if tool == .crop { applyCrop(); return true }
            if let id = selection, doc[id]?.kind == .text { canvas?.beginTextEditing(id); return true }
            return false
        case 53:        // esc: cancel a drag or crop, then deselect; the viewer closes after that
            if drag != nil, let before {
                doc = before
                drag = nil
                self.before = nil
                canvas?.needsDisplay = true
                return true
            }
            if tool == .crop { tool = .select; return true }
            if selection != nil { selection = nil; return true }
            return false
        case 123, 124, 125, 126:
            guard selection != nil else { return false }
            let step: Double = event.modifierFlags.contains(.shift) ? 10 : 1
            switch event.keyCode {
            case 123: nudge(-step, 0)
            case 124: nudge(step, 0)
            case 125: nudge(0, step)
            default: nudge(0, -step)
            }
            return true
        default:
            guard let ch = event.charactersIgnoringModifiers?.lowercased().first,
                  let t = Tool.allCases.first(where: { $0.key == ch }) else { return false }
            tool = t
            return true
        }
    }
}
