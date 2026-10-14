import AppKit
import SwiftUI

/// The image viewer's surface: an AppKit view, because RegionShot's handling needs events SwiftUI
/// doesn't expose: a trackpad scroll (pan) told apart from a mouse wheel (zoom toward the pointer), and
/// middle-button drags.
///
/// Coordinates: the view is flipped (y down), like image pixels. `origin` is where the image's top-left
/// pixel sits in the view and `scale` is view points per image pixel.
final class ImageCanvasView: NSView {
    weak var viewer: ImageViewerModel?

    private(set) var image: CGImage?
    private(set) var scale: CGFloat = 1
    private(set) var origin: CGPoint = .zero
    /// While true the image refits when the view resizes. Any manual zoom or pan clears it.
    private var fitted = true
    private var spaceDown = false
    private var panStart: (mouse: CGPoint, origin: CGPoint)?
    private var animation: (from: (CGFloat, CGPoint), to: (CGFloat, CGPoint), start: CFTimeInterval)?
    private var link: CADisplayLink?

    static let minZoom: CGFloat = 0.05, maxZoom: CGFloat = 32
    private let margin: CGFloat = 28
    /// Room for the floating toolbar above a fitted image.
    private let topInset: CGFloat = 64

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
        self.image = image
        fitted = true
        fit(animated: false)
    }

    /// Device pixels per image pixel, as a percentage: 100% shows every pixel of the capture once.
    var zoomPercent: CGFloat { scale * (window?.backingScaleFactor ?? 2) * 100 }

    private var imageSize: CGSize { image.map { CGSize(width: $0.width, height: $0.height) } ?? .zero }

    func fit(animated: Bool = true) {
        guard image != nil, bounds.width > 0, bounds.height > 0 else { return }
        let s = imageSize
        let room = CGSize(width: max(bounds.width - margin * 2, 40), height: max(bounds.height - margin - topInset, 40))
        // Never blow a small shot up past actual size just to fill the window.
        let target = min(room.width / s.width, room.height / s.height, actualScale)
        set(scale: target, origin: centered(at: target), animated: animated)
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
        let anchor = CGPoint(x: (p.x - origin.x) / scale, y: (p.y - origin.y) / scale)
        fitted = false
        set(scale: s, origin: CGPoint(x: p.x - anchor.x * s, y: p.y - anchor.y * s), animated: animated)
    }

    private func centered(at s: CGFloat) -> CGPoint {
        CGPoint(x: (bounds.width - imageSize.width * s) / 2, y: topInset + (bounds.height - topInset - margin - imageSize.height * s) / 2)
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
            animation = nil
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
        viewer?.canvasDidChange(self)
    }

    /// Generous overpan, but a strip of the image always stays on screen.
    private func clamp(_ o: CGPoint, scale s: CGFloat) -> CGPoint {
        let w = imageSize.width * s, h = imageSize.height * s
        let keepX = min(80, w), keepY = min(80, h)
        return CGPoint(x: o.x.clamped(to: (keepX - w)...(bounds.width - keepX)),
                       y: o.y.clamped(to: (keepY - h)...(bounds.height - keepY)))
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
    var imageRect: CGRect { CGRect(origin: origin, size: CGSize(width: imageSize.width * scale, height: imageSize.height * scale)) }

    // MARK: Drawing

    override func draw(_ dirtyRect: NSRect) {
        guard let image, let ctx = NSGraphicsContext.current?.cgContext else { return }
        let rect = imageRect
        ctx.saveGState()
        ctx.setShadow(offset: CGSize(width: 0, height: 10), blur: 40, color: NSColor.black.withAlphaComponent(0.55).cgColor)
        ctx.setFillColor(NSColor.black.cgColor)
        ctx.fill(rect)
        ctx.restoreGState()

        ctx.saveGState()
        // Past 2 device pixels per image pixel, show crisp pixels instead of a smear.
        ctx.interpolationQuality = zoomPercent >= 200 ? .none : .high
        ctx.translateBy(x: rect.minX, y: rect.maxY)
        ctx.scaleBy(x: 1, y: -1)
        ctx.draw(image, in: CGRect(origin: .zero, size: rect.size))
        ctx.restoreGState()
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

    /// Double-click: fit ↔ actual size at the pointer.
    private func toggleZoom(at p: CGPoint) {
        if fitted { actualSize(at: p) } else { fit() }
    }

    override func mouseDown(with event: NSEvent) {
        window?.makeFirstResponder(self)
        let p = convert(event.locationInWindow, from: nil)
        if event.clickCount == 2 { toggleZoom(at: p); return }
        panStart = (p, origin)
        if spaceDown || viewer?.handlesPrimaryDrag == false { NSCursor.closedHand.set() }
        viewer?.primaryDown(at: p, in: self, event: event, panning: spaceDown)
    }

    override func mouseDragged(with event: NSEvent) {
        let p = convert(event.locationInWindow, from: nil)
        if spaceDown || viewer?.handlesPrimaryDrag == false {
            dragPan(to: p)
        } else {
            viewer?.primaryDragged(to: p, in: self, event: event)
        }
    }

    override func mouseUp(with event: NSEvent) {
        let p = convert(event.locationInWindow, from: nil)
        if !(spaceDown || viewer?.handlesPrimaryDrag == false) { viewer?.primaryUp(at: p, in: self, event: event) }
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
        if viewer?.keyDown(event, in: self) == true { return }
        let mods = event.modifierFlags.intersection([.command, .control, .option])
        guard mods.isEmpty else { super.keyDown(with: event); return }
        switch event.keyCode {
        case 49:   // space: hold to pan with any tool
            if !spaceDown { spaceDown = true; NSCursor.openHand.set() }
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

    /// ⌘+ ⌘− ⌘0 ⌘1 and anything the viewer claims (undo and redo).
    override func performKeyEquivalent(with event: NSEvent) -> Bool {
        guard window?.firstResponder === self else { return super.performKeyEquivalent(with: event) }
        if viewer?.keyEquivalent(event, in: self) == true { return true }
        guard event.modifierFlags.intersection([.command, .control, .option]) == .command else {
            return super.performKeyEquivalent(with: event)
        }
        switch event.charactersIgnoringModifiers {
        case "+", "=": zoomStep(1)
        case "-", "_": zoomStep(-1)
        case "0": fit()
        case "1": actualSize()
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
    override func mouseExited(with event: NSEvent) { NSCursor.arrow.set(); viewer?.hover(nil, in: self) }

    func updateCursor(at p: CGPoint) {
        if spaceDown { NSCursor.openHand.set(); return }
        (viewer?.hover(p, in: self) ?? NSCursor.arrow).set()
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
