import AppKit

/// ⌘⇧4-style region picker: dims the main screen, drag a rectangle, Esc cancels.
/// A click without dragging selects the whole screen.
/// Completion gets the selection in global AppKit screen coordinates (bottom-left origin), or nil if cancelled.
final class RegionSelector {
    private var window: OverlayWindow?
    private var previousApp: NSRunningApplication?

    func begin(completion: @escaping (NSRect?) -> Void) {
        guard window == nil, let screen = NSScreen.main else { completion(nil); return }
        previousApp = NSWorkspace.shared.frontmostApplication

        let window = OverlayWindow(screen: screen) { [weak self] rect in
            self?.finish(rect, completion: completion)
        }
        self.window = window
        NSApp.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)
        NSCursor.crosshair.push()
    }

    private func finish(_ rect: NSRect?, completion: @escaping (NSRect?) -> Void) {
        NSCursor.pop()
        window?.orderOut(nil)
        window = nil
        // Hand focus back to whatever the user was working in.
        previousApp?.activate()
        // Let the overlay leave the screen before anything captures it.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { completion(rect) }
    }
}

private final class OverlayWindow: NSWindow {
    init(screen: NSScreen, onDone: @escaping (NSRect?) -> Void) {
        super.init(contentRect: screen.frame, styleMask: .borderless, backing: .buffered, defer: false)
        level = .screenSaver
        isOpaque = false
        backgroundColor = .clear
        hasShadow = false
        ignoresMouseEvents = false
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        setFrame(screen.frame, display: false)
        contentView = SelectionView(frame: NSRect(origin: .zero, size: screen.frame.size)) { [weak self] local in
            guard let self else { return }
            onDone(local.map { self.convertToScreen($0) })
        }
    }

    override var canBecomeKey: Bool { true }
}

private final class SelectionView: NSView {
    private var start: NSPoint?
    private var current: NSPoint?
    private let onDone: (NSRect?) -> Void
    private var finished = false

    init(frame: NSRect, onDone: @escaping (NSRect?) -> Void) {
        self.onDone = onDone
        super.init(frame: frame)
    }

    required init?(coder: NSCoder) { fatalError() }

    override var acceptsFirstResponder: Bool { true }
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }
    override func viewDidMoveToWindow() { window?.makeFirstResponder(self) }
    override func resetCursorRects() { addCursorRect(bounds, cursor: .crosshair) }

    private var selection: NSRect? {
        guard let start, let current else { return nil }
        return NSRect(x: min(start.x, current.x), y: min(start.y, current.y),
                      width: abs(current.x - start.x), height: abs(current.y - start.y))
    }

    override func mouseDown(with event: NSEvent) {
        start = convert(event.locationInWindow, from: nil)
        current = start
        needsDisplay = true
    }

    override func mouseDragged(with event: NSEvent) {
        current = convert(event.locationInWindow, from: nil)
        needsDisplay = true
    }

    override func mouseUp(with event: NSEvent) {
        current = convert(event.locationInWindow, from: nil)
        guard let rect = selection else { return done(nil) }
        // A click (no real drag) means "whole screen".
        done(rect.width < 4 || rect.height < 4 ? bounds : rect.integral)
    }

    override func keyDown(with event: NSEvent) {
        if event.keyCode == 53 { done(nil) } // Esc
    }

    override func rightMouseDown(with event: NSEvent) { done(nil) }

    private func done(_ rect: NSRect?) {
        guard !finished else { return }
        finished = true
        onDone(rect)
    }

    override func draw(_ dirtyRect: NSRect) {
        NSColor.black.withAlphaComponent(0.3).setFill()
        bounds.fill()

        guard let rect = selection, rect.width > 0, rect.height > 0 else {
            hint("Drag to capture a region · click for full screen · Esc to cancel", at: NSPoint(x: bounds.midX, y: bounds.midY))
            return
        }
        NSColor.clear.setFill()
        rect.fill(using: .copy)
        NSColor.white.setStroke()
        let border = NSBezierPath(rect: rect.insetBy(dx: -0.5, dy: -0.5))
        border.lineWidth = 1
        border.stroke()
        hint("\(Int(rect.width)) × \(Int(rect.height))", at: NSPoint(x: rect.maxX, y: rect.minY - 14))
    }

    private func hint(_ text: String, at point: NSPoint) {
        let attrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.monospacedDigitSystemFont(ofSize: 12, weight: .medium),
            .foregroundColor: NSColor.white,
            .backgroundColor: NSColor.black.withAlphaComponent(0.6),
        ]
        let s = NSAttributedString(string: " \(text) ", attributes: attrs)
        let size = s.size()
        s.draw(at: NSPoint(x: min(max(4, point.x - size.width / 2), bounds.maxX - size.width - 4),
                           y: min(max(4, point.y - size.height / 2), bounds.maxY - size.height - 4)))
    }
}
