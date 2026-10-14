import Annotation
import AppKit
import SwiftUI

/// The image viewer's surface: an AppKit view, because RegionShot's handling needs events SwiftUI
/// doesn't expose: a trackpad scroll (pan) told apart from a mouse wheel (zoom toward the pointer), and
/// middle-button drags.
///
/// Coordinates: the view is flipped (y down), like image pixels. `origin` is where the image's top-left
/// pixel sits in the view and `scale` is view points per image pixel. Annotation work happens in image
/// pixels in `AnnotationEditor`; this view converts the pointer, draws, and hosts the inline text editor.
final class ImageCanvasView: NSView, NSTextViewDelegate {
    weak var viewer: ImageViewerModel?
    private var editor: AnnotationEditor? { viewer?.editor }

    private(set) var image: CGImage?
    private(set) var scale: CGFloat = 1
    private(set) var origin: CGPoint = .zero
    /// While true the image refits when the view resizes. Any manual zoom or pan clears it.
    private var fitted = true
    private var spaceDown = false
    private var panStart: (mouse: CGPoint, origin: CGPoint)?
    /// The current left-button drag belongs to the annotation editor (else it pans).
    private var editorDrag = false
    private var animation: (from: (CGFloat, CGPoint), to: (CGFloat, CGPoint), start: CFTimeInterval)?
    private var link: CADisplayLink?
    private var textView: AnnotationTextView?
    private var textBefore: AnnotationDoc?

    static let minZoom: CGFloat = 0.05, maxZoom: CGFloat = 32
    private let margin: CGFloat = 28
    /// Room for the floating toolbars above and below a fitted image.
    private let topInset: CGFloat = 64, bottomInset: CGFloat = 56
    /// Pointer slop for hit-testing, in view points.
    private let slop: CGFloat = 5

    override var isFlipped: Bool { true }
    override var acceptsFirstResponder: Bool { true }
    override var isOpaque: Bool { false }
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

    override init(frame: NSRect) {
        super.init(frame: frame)
        wantsLayer = true
        layerContentsRedrawPolicy = .onSetNeedsDisplay
    }

    required init?(coder: NSCoder) { fatalError("not used") }

    // MARK: Image and view transform

    func setImage(_ image: CGImage?) {
        guard image !== self.image else { return }
        if textView != nil { endTextEditing(commit: true) }
        self.image = image
        fitted = true
        fit(animated: false)
    }

    /// The annotation document changed in a way that moves the content (crop, crop tool).
    func contentDidChange(refit: Bool) {
        if refit { fit() }
        needsDisplay = true
    }

    /// Device pixels per image pixel, as a percentage: 100% shows every pixel of the capture once.
    var zoomPercent: CGFloat { scale * (window?.backingScaleFactor ?? 2) * 100 }

    /// The image pixels on show: the crop, or the whole image (always the whole image while cropping).
    private var contentRect: CGRect {
        editor?.visibleRect ?? image.map { CGRect(x: 0, y: 0, width: $0.width, height: $0.height) } ?? .zero
    }

    func fit(animated: Bool = true) {
        let content = contentRect
        guard image != nil, content.width > 0, bounds.width > 0, bounds.height > 0 else { return }
        let room = CGSize(width: max(bounds.width - margin * 2, 40), height: max(bounds.height - topInset - bottomInset, 40))
        // Never blow a small shot up past actual size just to fill the window.
        let target = min(room.width / content.width, room.height / content.height, actualScale)
        let o = CGPoint(x: (bounds.width - content.width * target) / 2 - content.minX * target,
                        y: topInset + (room.height - content.height * target) / 2 - content.minY * target)
        set(scale: target, origin: o, animated: animated)
        fitted = true
    }

    /// One image pixel per device pixel.
    private var actualScale: CGFloat { 1 / (window?.backingScaleFactor ?? 2) }

    func actualSize(at point: CGPoint? = nil, animated: Bool = true) {
        zoom(to: actualScale, at: point, animated: animated)
    }

    func zoom(percent: CGFloat, animated: Bool = true) {
        zoom(to: percent / 100 * actualScale, at: nil, animated: animated)
    }

    func zoomStep(_ direction: Int) {
        let stops: [CGFloat] = [5, 10, 25, 33, 50, 67, 100, 150, 200, 300, 400, 800, 1600]
        let now = zoomPercent
        let next = direction > 0 ? stops.first { $0 > now * 1.01 } : stops.last { $0 < now * 0.99 }
        if let next { zoom(percent: next) }
    }

    /// Zooms to `target`, keeping the image point under `point` (default: the view's center) still.
    func zoom(to target: CGFloat, at point: CGPoint?, animated: Bool = false) {
        let s = target.clamped(to: Self.minZoom...Self.maxZoom)
        let p = point ?? CGPoint(x: bounds.midX, y: bounds.midY)
        let anchor = imagePoint(p)
        fitted = false
        set(scale: s, origin: CGPoint(x: p.x - anchor.x * s, y: p.y - anchor.y * s), animated: animated)
    }

    private func set(scale s: CGFloat, origin o: CGPoint, animated: Bool) {
        let o = clamp(o, scale: s)
        if animated, window != nil {
            animation = ((scale, origin), (s, o), CACurrentMediaTime())
            if link == nil {
                link = displayLink(target: self, selector: #selector(step))
                link?.add(to: .main, forMode: .common)
            }
        } else {
            stopAnimation()
            apply(s, o)
        }
    }

    @objc private func step(_ link: CADisplayLink) {
        guard let a = animation else { stopAnimation(); return }
        let t = min(1, (CACurrentMediaTime() - a.start) / 0.18)
        let e = 1 - pow(1 - t, 3)   // ease out
        let s = a.from.0 + (a.to.0 - a.from.0) * e
        let o = CGPoint(x: a.from.1.x + (a.to.1.x - a.from.1.x) * e, y: a.from.1.y + (a.to.1.y - a.from.1.y) * e)
        apply(s, o)
        if t >= 1 { stopAnimation() }
    }

    private func stopAnimation() {
        animation = nil
        link?.invalidate()
        link = nil
    }

    private func apply(_ s: CGFloat, _ o: CGPoint) {
        scale = s
        origin = o
        needsDisplay = true
        layoutTextEditor()
        viewer?.canvasDidChange(self)
    }

    /// Generous overpan, but a strip of the content always stays on screen.
    private func clamp(_ o: CGPoint, scale s: CGFloat) -> CGPoint {
        let c = contentRect
        let w = c.width * s, h = c.height * s
        let keepX = min(80, w), keepY = min(80, h)
        let x = (o.x + c.minX * s).clamped(to: (keepX - w)...(bounds.width - keepX))
        let y = (o.y + c.minY * s).clamped(to: (keepY - h)...(bounds.height - keepY))
        return CGPoint(x: x - c.minX * s, y: y - c.minY * s)
    }

    func pan(by delta: CGSize) {
        stopAnimation()
        fitted = false
        apply(scale, clamp(CGPoint(x: origin.x + delta.width, y: origin.y + delta.height), scale: scale))
    }

    override func setFrameSize(_ newSize: NSSize) {
        let center = CGPoint(x: bounds.midX, y: bounds.midY)
        super.setFrameSize(newSize)
        if fitted {
            fit(animated: false)
        } else {
            // Keep the same image point in the middle as the window resizes.
            let shift = CGSize(width: bounds.midX - center.x, height: bounds.midY - center.y)
            apply(scale, clamp(CGPoint(x: origin.x + shift.width, y: origin.y + shift.height), scale: scale))
        }
    }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        if window != nil { fit(animated: false); window?.makeFirstResponder(self) }
    }

    /// View point → image pixel.
    func imagePoint(_ p: CGPoint) -> CGPoint { CGPoint(x: (p.x - origin.x) / scale, y: (p.y - origin.y) / scale) }
    /// Image pixel → view point.
    func viewPoint(_ p: CGPoint) -> CGPoint { CGPoint(x: origin.x + p.x * scale, y: origin.y + p.y * scale) }
    func viewRect(_ r: CGRect) -> CGRect {
        CGRect(origin: viewPoint(r.origin), size: CGSize(width: r.width * scale, height: r.height * scale))
    }

    /// Hit slop in image pixels.
    private var tolerance: Double { slop / scale }

    // MARK: Drawing

    override func draw(_ dirtyRect: NSRect) {
        guard let image, let ctx = NSGraphicsContext.current?.cgContext else { return }
        let content = viewRect(contentRect)
        ctx.saveGState()
        ctx.setShadow(offset: CGSize(width: 0, height: 10), blur: 40, color: NSColor.black.withAlphaComponent(0.55).cgColor)
        ctx.setFillColor(NSColor.black.cgColor)
        ctx.fill(content)
        ctx.restoreGState()

        // Image space: image pixels, y down.
        ctx.saveGState()
        ctx.clip(to: content)
        ctx.translateBy(x: origin.x, y: origin.y)
        ctx.scaleBy(x: scale, y: scale)
        // Past 2 device pixels per image pixel, show crisp pixels instead of a smear.
        ctx.interpolationQuality = zoomPercent >= 200 ? .none : .high
        Renderer.drawImage(image, in: ctx)
        ctx.interpolationQuality = .high
        if let editor { Renderer.draw(editor.doc, in: ctx, hiding: editor.editingText) }
        ctx.restoreGState()

        guard let editor else { return }
        if editor.tool == .crop {
            drawCrop(editor.pendingCrop ?? contentRect, in: ctx)
            return
        }
        if let id = editor.hovered, id != editor.selection, let s = editor.doc[id] {
            outline(viewRect(Renderer.bounds(s)).insetBy(dx: -3, dy: -3), in: ctx, dashed: false, alpha: 0.6)
        }
        if let s = editor.selected, editor.editingText != s.id {
            if s.kind != .arrow { outline(viewRect(Renderer.bounds(s)).insetBy(dx: -3, dy: -3), in: ctx, dashed: true, alpha: 1) }
            for (_, p) in Geometry.handles(s) { handle(at: viewPoint(p), in: ctx, round: s.kind == .arrow) }
        }
    }

    private func outline(_ r: CGRect, in ctx: CGContext, dashed: Bool, alpha: CGFloat) {
        ctx.saveGState()
        ctx.setStrokeColor(NSColor.controlAccentColor.withAlphaComponent(alpha).cgColor)
        ctx.setLineWidth(1.5)
        if dashed { ctx.setLineDash(phase: 0, lengths: [5, 3]) }
        ctx.stroke(r)
        ctx.restoreGState()
    }

    private func handle(at p: CGPoint, in ctx: CGContext, round: Bool) {
        let r = CGRect(x: p.x - 5, y: p.y - 5, width: 10, height: 10)
        ctx.saveGState()
        ctx.setShadow(offset: CGSize(width: 0, height: 1), blur: 2, color: NSColor.black.withAlphaComponent(0.4).cgColor)
        ctx.setFillColor(NSColor.white.cgColor)
        ctx.setStrokeColor(NSColor.controlAccentColor.cgColor)
        ctx.setLineWidth(1.5)
        if round { ctx.addEllipse(in: r) } else { ctx.addPath(CGPath(roundedRect: r, cornerWidth: 2, cornerHeight: 2, transform: nil)) }
        ctx.drawPath(using: .fillStroke)
        ctx.restoreGState()
    }

    /// Dims what the crop drops, with thirds and handles on what it keeps.
    private func drawCrop(_ crop: CGRect, in ctx: CGContext) {
        let full = viewRect(CGRect(x: 0, y: 0, width: image?.width ?? 0, height: image?.height ?? 0))
        let keep = viewRect(crop)
        ctx.saveGState()
        ctx.addRect(full)
        ctx.addRect(keep)
        ctx.setFillColor(NSColor.black.withAlphaComponent(0.55).cgColor)
        ctx.fillPath(using: .evenOdd)
        ctx.setStrokeColor(NSColor.white.withAlphaComponent(0.35).cgColor)
        ctx.setLineWidth(1)
        for i in 1...2 {
            let x = keep.minX + keep.width * CGFloat(i) / 3, y = keep.minY + keep.height * CGFloat(i) / 3
            ctx.move(to: CGPoint(x: x, y: keep.minY)); ctx.addLine(to: CGPoint(x: x, y: keep.maxY))
            ctx.move(to: CGPoint(x: keep.minX, y: y)); ctx.addLine(to: CGPoint(x: keep.maxX, y: y))
        }
        ctx.strokePath()
        ctx.setStrokeColor(NSColor.white.cgColor)
        ctx.setLineWidth(1.5)
        ctx.stroke(keep)
        ctx.restoreGState()
        for (_, p) in Geometry.frameHandles(crop) { handle(at: viewPoint(p), in: ctx, round: false) }
        // The size it will be.
        let label = "\(Int(crop.width.rounded())) × \(Int(crop.height.rounded()))" as NSString
        let attrs: [NSAttributedString.Key: Any] = [.font: NSFont.monospacedDigitSystemFont(ofSize: 11, weight: .semibold), .foregroundColor: NSColor.white]
        let size = label.size(withAttributes: attrs)
        let box = CGRect(x: keep.minX, y: max(keep.minY - size.height - 10, 4), width: size.width + 10, height: size.height + 4)
        NSColor.black.withAlphaComponent(0.65).setFill()
        NSBezierPath(roundedRect: box, xRadius: 4, yRadius: 4).fill()
        label.draw(at: CGPoint(x: box.minX + 5, y: box.minY + 2), withAttributes: attrs)
    }

    // MARK: Input

    override func magnify(with event: NSEvent) {
        zoom(to: scale * (1 + event.magnification), at: convert(event.locationInWindow, from: nil))
    }

    override func smartMagnify(with event: NSEvent) {
        toggleZoom(at: convert(event.locationInWindow, from: nil))
    }

    override func scrollWheel(with event: NSEvent) {
        let p = convert(event.locationInWindow, from: nil)
        if event.hasPreciseScrollingDeltas && !event.modifierFlags.contains(.command) {
            // Trackpad: two fingers pan.
            pan(by: CGSize(width: event.scrollingDeltaX, height: event.scrollingDeltaY))
        } else {
            // Mouse wheel (or ⌘-scroll): zoom toward the pointer.
            let dy = event.hasPreciseScrollingDeltas ? event.scrollingDeltaY / 10 : event.scrollingDeltaY
            guard dy != 0 else { return }
            zoom(to: scale * pow(1.12, dy), at: p)
        }
    }

    /// Double-click on nothing: fit ↔ actual size at the pointer.
    private func toggleZoom(at p: CGPoint) {
        if fitted { actualSize(at: p) } else { fit() }
    }

    override func mouseDown(with event: NSEvent) {
        window?.makeFirstResponder(self)
        let p = convert(event.locationInWindow, from: nil)
        panStart = (p, origin)
        editorDrag = false
        if spaceDown { NSCursor.closedHand.set(); return }
        if let editor, editor.down(at: imagePoint(p), tolerance: tolerance, clickCount: event.clickCount) {
            editorDrag = true
            return
        }
        if event.clickCount == 2 { toggleZoom(at: p); panStart = nil; return }
        NSCursor.closedHand.set()
    }

    override func mouseDragged(with event: NSEvent) {
        let p = convert(event.locationInWindow, from: nil)
        if editorDrag {
            editor?.dragged(to: imagePoint(p), tolerance: tolerance, constrain: event.modifierFlags.contains(.shift))
        } else {
            dragPan(to: p)
        }
    }

    override func mouseUp(with event: NSEvent) {
        let p = convert(event.locationInWindow, from: nil)
        if editorDrag { editor?.up(at: imagePoint(p), tolerance: tolerance) }
        editorDrag = false
        panStart = nil
        updateCursor(at: p)
    }

    override func otherMouseDown(with event: NSEvent) {
        panStart = (convert(event.locationInWindow, from: nil), origin)
        NSCursor.closedHand.set()
    }

    override func otherMouseDragged(with event: NSEvent) { dragPan(to: convert(event.locationInWindow, from: nil)) }

    override func otherMouseUp(with event: NSEvent) {
        panStart = nil
        updateCursor(at: convert(event.locationInWindow, from: nil))
    }

    private func dragPan(to p: CGPoint) {
        guard let start = panStart else { return }
        stopAnimation()
        fitted = false
        apply(scale, clamp(CGPoint(x: start.origin.x + p.x - start.mouse.x, y: start.origin.y + p.y - start.mouse.y), scale: scale))
    }

    override func keyDown(with event: NSEvent) {
        if event.keyCode == 49, event.modifierFlags.intersection([.command, .control, .option]).isEmpty {
            // Space: hold to pan with any tool.
            if !spaceDown { spaceDown = true; NSCursor.openHand.set() }
            return
        }
        if editor?.keyDown(event) == true { return }
        let mods = event.modifierFlags.intersection([.command, .control, .option])
        guard mods.isEmpty else { super.keyDown(with: event); return }
        switch event.keyCode {
        case 53: viewer?.close()                       // esc
        case 123, 40: viewer?.step(-1)                 // ← k
        case 124, 38: viewer?.step(1)                  // → j
        default:
            switch event.charactersIgnoringModifiers {
            case "+", "=": zoomStep(1)
            case "-", "_": zoomStep(-1)
            case "0": fit()
            case "1": actualSize()
            default: super.keyDown(with: event)
            }
        }
    }

    override func keyUp(with event: NSEvent) {
        if event.keyCode == 49 {
            spaceDown = false
            updateCursor(at: convert(window?.mouseLocationOutsideOfEventStream ?? .zero, from: nil))
        } else {
            super.keyUp(with: event)
        }
    }

    /// ⌘+ ⌘− ⌘0 ⌘1, ⌘Z and ⇧⌘Z.
    override func performKeyEquivalent(with event: NSEvent) -> Bool {
        guard window?.firstResponder === self else { return super.performKeyEquivalent(with: event) }
        let mods = event.modifierFlags.intersection([.command, .control, .option, .shift])
        switch (mods, event.charactersIgnoringModifiers?.lowercased()) {
        case (.command, "z"): editor?.undo()
        case ([.command, .shift], "z"): editor?.redo()
        case (.command, "+"), (.command, "="), ([.command, .shift], "="), ([.command, .shift], "+"): zoomStep(1)
        case (.command, "-"): zoomStep(-1)
        case (.command, "0"): fit()
        case (.command, "1"): actualSize()
        default: return super.performKeyEquivalent(with: event)
        }
        return true
    }

    // MARK: Cursor

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        trackingAreas.forEach(removeTrackingArea)
        addTrackingArea(NSTrackingArea(rect: .zero, options: [.mouseMoved, .cursorUpdate, .activeInKeyWindow, .inVisibleRect, .mouseEnteredAndExited], owner: self))
    }

    override func mouseMoved(with event: NSEvent) { updateCursor(at: convert(event.locationInWindow, from: nil)) }
    override func cursorUpdate(with event: NSEvent) { updateCursor(at: convert(event.locationInWindow, from: nil)) }
    override func mouseExited(with event: NSEvent) { NSCursor.arrow.set(); _ = editor?.hover(nil, tolerance: tolerance) }

    func updateCursor(at p: CGPoint) {
        if spaceDown { NSCursor.openHand.set(); return }
        (editor?.hover(imagePoint(p), tolerance: tolerance) ?? NSCursor.openHand).set()
    }

    // MARK: Inline text editing

    // Shape.ID, written as UUID: `Annotation.Shape` would name the video-drawing struct, not the module.
    func beginTextEditing(_ id: UUID) {
        guard let editor, let shape = editor.doc[id], shape.kind == .text else { return }
        if textView != nil { endTextEditing(commit: true) }
        textBefore = editor.doc
        editor.editingText = id
        let view = AnnotationTextView(frame: .zero)
        view.delegate = self
        view.isRichText = false
        view.allowsUndo = true
        view.drawsBackground = true
        view.isVerticallyResizable = false
        view.isHorizontallyResizable = false
        view.textContainer?.lineFragmentPadding = 0
        view.textContainer?.widthTracksTextView = false
        view.wantsLayer = true
        view.string = shape.text ?? ""
        view.onFinish = { [weak self] commit in self?.endTextEditing(commit: commit) }
        addSubview(view)
        textView = view
        layoutTextEditor()
        window?.makeFirstResponder(view)
        view.selectAll(nil)
        needsDisplay = true
    }

    func endTextEditing(commit: Bool) {
        guard let view = textView, let editor, let id = editor.editingText, let before = textBefore else { return }
        textView = nil
        textBefore = nil
        view.onFinish = nil
        view.removeFromSuperview()
        editor.finishText(id, commit: commit, before: before)
        window?.makeFirstResponder(self)
    }

    /// Keeps the editor over its shape, at the shape's size, through zooms and pans.
    private func layoutTextEditor() {
        guard let view = textView, let editor, let id = editor.editingText, let shape = editor.doc[id] else { return }
        let layout = Renderer.textLayout(shape)
        let size = (shape.fontSize ?? 24) * scale
        let fill = NSColor(cgColor: Renderer.cgColor(shape.color)) ?? .systemRed
        let ink = NSColor(cgColor: Renderer.textColor(on: shape.color)) ?? .white
        // A little slack so AppKit's line breaking never wraps a line the renderer kept whole.
        var frame = viewRect(layout.box)
        if shape.wrapWidth == nil { frame.size.width += size * 0.6 }
        if view.frame != frame { view.frame = frame }
        // Wrap where the renderer wraps: at the shape's width, or its automatic limit while it grows.
        let wrap = (shape.wrapWidth ?? Style.autoWrap(fontSize: shape.fontSize ?? 24)) * scale + (shape.wrapWidth == nil ? 0 : size * 0.3)
        let container = NSSize(width: wrap, height: .greatestFiniteMagnitude)
        if view.textContainer?.containerSize != container { view.textContainer?.containerSize = container }
        let inset = NSSize(width: layout.padding * scale, height: layout.padding * scale)
        if view.textContainerInset != inset { view.textContainerInset = inset }
        // Only touch the text's attributes when they change: resetting them on every keystroke re-lays
        // out the text inside AppKit's constraint pass.
        if view.font?.pointSize != CGFloat(size) { view.font = Renderer.font(size: size) as NSFont }
        if view.backgroundColor != fill { view.backgroundColor = fill }
        if view.textColor != ink { view.textColor = ink; view.insertionPointColor = ink }
        view.layer?.cornerRadius = layout.padding * scale
    }

    func textDidChange(_ notification: Notification) {
        guard let view = textView, let id = editor?.editingText else { return }
        editor?.updateText(id, view.string)
        layoutTextEditor()
    }
}

/// Return commits, ⇧Return breaks the line, Esc cancels: RegionShot's text keys.
final class AnnotationTextView: NSTextView {
    var onFinish: ((Bool) -> Void)?

    override func keyDown(with event: NSEvent) {
        if (event.keyCode == 36 || event.keyCode == 76) && !event.modifierFlags.contains(.shift) {
            onFinish?(true)
        } else if event.keyCode == 53 {
            onFinish?(false)
        } else {
            super.keyDown(with: event)
        }
    }
}

/// Hosts the canvas in SwiftUI and keeps it pointed at the current image.
struct ImageCanvas: NSViewRepresentable {
    var viewer: ImageViewerModel

    func makeNSView(context: Context) -> ImageCanvasView {
        let view = ImageCanvasView()
        view.viewer = viewer
        viewer.canvas = view
        view.setImage(viewer.image)
        return view
    }

    func updateNSView(_ view: ImageCanvasView, context: Context) {
        view.setImage(viewer.image)
        view.needsDisplay = true
    }
}

extension Comparable {
    func clamped(to range: ClosedRange<Self>) -> Self { min(max(self, range.lowerBound), range.upperBound) }
}
