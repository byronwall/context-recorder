import AppKit
import AVFoundation
import ImageIO
import SwiftUI
import UniformTypeIdentifiers

/// Draws a session's annotations over the video, and in draw mode lets you add and edit them the way
/// RegionShot does: pick a tool with one key, drag to draw, drag a shape to move it, drag a handle to
/// resize, click empty space to deselect. Sits exactly on the video frame (the player keeps its aspect).
struct AnnotationLayer: View {
    var model: SessionModel
    /// The annotation being drawn, moved or resized; committed (one undo step) when the drag ends.
    @State private var draft: Annotation?
    @State private var drag: DragKind?
    /// The open inline text editor.
    @State private var editing: Annotation?
    @State private var editString = ""
    @FocusState private var textFocused: Bool

    enum DragKind { case create, move(Annotation), handle(Int, Annotation), none }

    var body: some View {
        GeometryReader { geo in
            let size = geo.size
            let visible = model.annotations(at: model.currentTime)
            ZStack(alignment: .topLeading) {
                Canvas { ctx, _ in
                    for a in visible where a.id != draft?.id && a.id != editing?.id {
                        AnnotationRenderer.draw(a, in: ctx, size: size)
                    }
                    if let draft { AnnotationRenderer.draw(draft, in: ctx, size: size) }
                }
                .allowsHitTesting(false)

                if model.drawMode {
                    surface(size: size, visible: visible)
                    if editing == nil, let id = model.selectedAnnotation,
                       let a = draft?.id == id ? draft : visible.first(where: { $0.id == id }) {
                        SelectionChrome(annotation: a, size: size)
                    }
                    if let editing { textEditor(editing, size: size) }
                }
            }
        }
        .onChange(of: model.drawMode) { _, on in if !on { commitText() } }
    }

    // MARK: Gestures

    private func surface(size: CGSize, visible: [Annotation]) -> some View {
        Rectangle()
            .fill(.clear)
            .contentShape(.rect)
            .gesture(DragGesture(minimumDistance: 0, coordinateSpace: .local)
                .onChanged { g in dragChanged(g, size: size, visible: visible) }
                .onEnded { g in dragEnded(g, size: size) })
            .simultaneousGesture(SpatialTapGesture(count: 2).onEnded { tap in
                // Double-click text to edit it in place.
                if let a = hit(tap.location, size: size, in: visible), a.kind == .text { beginEditing(a) }
            })
            .onContinuousHover { phase in
                guard case .active(let p) = phase else { NSCursor.arrow.set(); return }
                cursor(at: p, size: size, visible: visible).set()
            }
    }

    private func n(_ p: CGPoint, _ size: CGSize) -> CGPoint {
        CGPoint(x: p.x / max(size.width, 1), y: p.y / max(size.height, 1))
    }

    private func dragChanged(_ g: DragGesture.Value, size: CGSize, visible: [Annotation]) {
        if drag == nil {
            commitText()
            let p = g.startLocation
            let selected = visible.first { $0.id == model.selectedAnnotation }
            if let selected, let h = AnnotationGeometry.handle(at: p, of: selected, size: size) {
                drag = .handle(h, selected)
                draft = selected
            } else if let a = hit(p, size: size, in: visible), model.tool == .select || model.tool.kind == a.kind {
                model.selectedAnnotation = a.id
                drag = .move(a)
                draft = a
            } else if let kind = model.tool.kind, kind != .text {
                model.selectedAnnotation = nil
                draft = model.newAnnotation(kind, points: [n(p, size), n(p, size)])
                drag = .create
            } else {
                drag = kind(of: model.tool) == .text ? .create : DragKind.none
                if model.tool == .select { model.selectedAnnotation = nil }
            }
        }
        let here = n(g.location, size)
        switch drag {
        case .create:
            guard var d = draft else { return }
            if d.kind == .pen {
                if let last = d.points.last, hypot((here.x - last.x) * size.width, (here.y - last.y) * size.height) > 1.5 { d.points.append(here) }
            } else {
                d.points[1] = here
            }
            draft = d
        case .move(let start):
            draft = start.moved(by: CGSize(width: g.translation.width / size.width, height: g.translation.height / size.height))
        case .handle(let h, let start):
            draft = AnnotationGeometry.resize(start, handle: h, to: here, size: size)
        default:
            break
        }
    }

    private func kind(of tool: AnnotationTool) -> Annotation.Kind? { tool.kind }

    private func dragEnded(_ g: DragGesture.Value, size: CGSize) {
        defer { drag = nil; draft = nil }
        switch drag {
        case .create:
            if model.tool == .text {
                let p = n(g.startLocation, size)
                let a = model.newAnnotation(.text, points: [p, CGPoint(x: min(1, p.x + AnnotationGeometry.defaultTextWidth), y: p.y)], text: "")
                beginEditing(a)
                return
            }
            guard var d = draft else { return }
            let r = AnnotationGeometry.pixelBounds(d, size: size)
            // A click without a drag deselects instead of leaving a dot.
            guard max(r.width, r.height) >= 4 else { model.selectedAnnotation = nil; return }
            if d.kind == .pen { d.points = AnnotationGeometry.smoothed(d.points) }
            model.addAnnotation(d)
        case .move(let start), .handle(_, let start):
            if let d = draft, d != start { model.updateAnnotation(d) }
        default:
            break
        }
    }

    private func hit(_ p: CGPoint, size: CGSize, in visible: [Annotation]) -> Annotation? {
        visible.reversed().first { AnnotationGeometry.contains($0, p, size: size, selected: $0.id == model.selectedAnnotation) }
    }

    private func cursor(at p: CGPoint, size: CGSize, visible: [Annotation]) -> NSCursor {
        if let selected = visible.first(where: { $0.id == model.selectedAnnotation }),
           AnnotationGeometry.handle(at: p, of: selected, size: size) != nil { return .crosshair }
        if let a = hit(p, size: size, in: visible), model.tool == .select || model.tool.kind == a.kind { return .openHand }
        switch model.tool {
        case .select: return .arrow
        case .text: return .iBeam
        default: return .crosshair
        }
    }

    // MARK: Text

    private func beginEditing(_ a: Annotation) {
        editing = a
        editString = a.text ?? ""
        model.editingText = a.id
        model.selectedAnnotation = a.id
        DispatchQueue.main.async { textFocused = true }
    }

    /// Return commits; an empty text removes the annotation.
    private func commitText() {
        guard var a = editing else { return }
        editing = nil
        model.editingText = nil
        let text = editString.trimmingCharacters(in: .whitespacesAndNewlines)
        let exists = model.annotations.contains { $0.id == a.id }
        if text.isEmpty {
            if exists { model.selectedAnnotation = a.id; model.deleteSelectedAnnotation() }
            return
        }
        a.text = editString.trimmingCharacters(in: .newlines)
        if exists { model.updateAnnotation(a) } else { model.addAnnotation(a) }
    }

    private func cancelText() {
        editing = nil
        model.editingText = nil
    }

    private func textEditor(_ a: Annotation, size: CGSize) -> some View {
        let font = AnnotationGeometry.fontSize(size)
        let box = AnnotationGeometry.textBox(a, text: editString.isEmpty ? "M" : editString, size: size)
        let width = max(box.width, AnnotationGeometry.minimumTextWidth(size))
        return TextField("", text: $editString, axis: .vertical)
            .textFieldStyle(.plain)
            .font(.system(size: font, weight: .semibold))
            .foregroundStyle(AnnotationPalette.textColor(on: a.color))
            .focused($textFocused)
            .onSubmit { commitText() }
            .onKeyPress(.return, phases: .down) { press in
                if press.modifiers.contains(.shift) { editString += "\n"; return .handled }
                commitText()
                return .handled
            }
            .onKeyPress(.escape) { cancelText(); return .handled }
            .padding(AnnotationGeometry.textPadding(size))
            .frame(width: width, alignment: .leading)
            .background(AnnotationPalette.color(a.color), in: .rect(cornerRadius: font * 0.25))
            .overlay(RoundedRectangle(cornerRadius: font * 0.25).strokeBorder(Color.accentColor, lineWidth: 1.5))
            .offset(x: box.minX, y: box.minY)
    }
}

/// The selected annotation's outline and handles.
private struct SelectionChrome: View {
    var annotation: Annotation
    var size: CGSize

    var body: some View {
        let r = AnnotationGeometry.pixelBounds(annotation, size: size).insetBy(dx: -4, dy: -4)
        ZStack(alignment: .topLeading) {
            Rectangle()
                .strokeBorder(Color.accentColor, style: StrokeStyle(lineWidth: 1, dash: [4, 3]))
                .frame(width: r.width, height: r.height)
                .offset(x: r.minX, y: r.minY)
            ForEach(Array(AnnotationGeometry.handles(annotation, size: size).enumerated()), id: \.offset) { _, p in
                Circle()
                    .fill(.white)
                    .overlay(Circle().strokeBorder(Color.accentColor, lineWidth: 1.5))
                    .frame(width: 9, height: 9)
                    .offset(x: p.x - 4.5, y: p.y - 4.5)
            }
        }
        .allowsHitTesting(false)
    }
}

// MARK: - Geometry and drawing

enum AnnotationGeometry {
    static let defaultTextWidth: CGFloat = 0.28

    static func lineWidth(_ size: CGSize) -> CGFloat { max(2, size.height * 0.0045) }
    static func fontSize(_ size: CGSize) -> CGFloat { max(11, size.height * 0.028) }
    static func textPadding(_ size: CGSize) -> CGFloat { fontSize(size) * 0.35 }
    static func minimumTextWidth(_ size: CGSize) -> CGFloat { fontSize(size) * 4 }

    static func px(_ p: CGPoint, _ size: CGSize) -> CGPoint { CGPoint(x: p.x * size.width, y: p.y * size.height) }

    static func textBox(_ a: Annotation, text: String? = nil, size: CGSize) -> CGRect {
        let origin = px(a.points.first ?? .zero, size)
        let maxWidth = max(minimumTextWidth(size), ((a.points.last?.x ?? 0) - (a.points.first?.x ?? 0)) * size.width)
        let pad = textPadding(size)
        let font = NSFont.systemFont(ofSize: fontSize(size), weight: .semibold)
        let string = (text ?? a.text ?? "").isEmpty ? " " : (text ?? a.text ?? "")
        let measured = (string as NSString).boundingRect(
            with: CGSize(width: maxWidth - pad * 2, height: .greatestFiniteMagnitude),
            options: [.usesLineFragmentOrigin, .usesFontLeading], attributes: [.font: font])
        return CGRect(x: origin.x, y: origin.y, width: min(maxWidth, ceil(measured.width) + pad * 2 + 2),
                      height: ceil(measured.height) + pad * 2)
    }

    static func pixelBounds(_ a: Annotation, size: CGSize) -> CGRect {
        if a.kind == .text { return textBox(a, size: size) }
        let b = a.bounds
        return CGRect(x: b.minX * size.width, y: b.minY * size.height, width: b.width * size.width, height: b.height * size.height)
    }

    static func contains(_ a: Annotation, _ p: CGPoint, size: CGSize, selected: Bool) -> Bool {
        let slop: CGFloat = 6
        switch a.kind {
        case .arrow where !selected:
            return distance(p, toSegment: px(a.points[0], size), px(a.points[1], size)) < slop + lineWidth(size)
        case .rectangle where !selected:
            // An outline is grabbed by its edge, so you can still draw inside it.
            let r = pixelBounds(a, size: size)
            return r.insetBy(dx: -slop, dy: -slop).contains(p) && !r.insetBy(dx: slop + 2, dy: slop + 2).contains(p)
        default:
            return pixelBounds(a, size: size).insetBy(dx: -slop, dy: -slop).contains(p)
        }
    }

    /// Handle positions: corners then sides for boxes, both ends for arrows, the two edges for text.
    static func handles(_ a: Annotation, size: CGSize) -> [CGPoint] {
        switch a.kind {
        case .rectangle, .highlight:
            let r = pixelBounds(a, size: size)
            return [CGPoint(x: r.minX, y: r.minY), CGPoint(x: r.maxX, y: r.minY), CGPoint(x: r.maxX, y: r.maxY), CGPoint(x: r.minX, y: r.maxY),
                    CGPoint(x: r.midX, y: r.minY), CGPoint(x: r.maxX, y: r.midY), CGPoint(x: r.midX, y: r.maxY), CGPoint(x: r.minX, y: r.midY)]
        case .arrow:
            return a.points.prefix(2).map { px($0, size) }
        case .text:
            let r = textBox(a, size: size)
            return [CGPoint(x: r.minX, y: r.midY), CGPoint(x: r.maxX, y: r.midY)]
        case .pen:
            return []
        }
    }

    static func handle(at p: CGPoint, of a: Annotation, size: CGSize) -> Int? {
        handles(a, size: size).firstIndex { hypot($0.x - p.x, $0.y - p.y) <= 8 }
    }

    static func resize(_ a: Annotation, handle h: Int, to p: CGPoint, size: CGSize) -> Annotation {
        var out = a
        switch a.kind {
        case .rectangle, .highlight:
            let b = a.bounds
            var minX = b.minX, minY = b.minY, maxX = b.maxX, maxY = b.maxY
            switch h {
            case 0: minX = p.x; minY = p.y
            case 1: maxX = p.x; minY = p.y
            case 2: maxX = p.x; maxY = p.y
            case 3: minX = p.x; maxY = p.y
            case 4: minY = p.y
            case 5: maxX = p.x
            case 6: maxY = p.y
            default: minX = p.x
            }
            out.points = [CGPoint(x: min(minX, maxX), y: min(minY, maxY)), CGPoint(x: max(minX, maxX), y: max(minY, maxY))]
        case .arrow:
            out.points[min(h, 1)] = p
        case .text:
            // Edges change the wrap width, not the font size.
            let minWidth = minimumTextWidth(size) / max(size.width, 1)
            if h == 0 {
                let right = a.points[1].x
                out.points[0].x = min(p.x, right - minWidth)
                out.points[1].x = right
            } else {
                out.points[1].x = max(p.x, a.points[0].x + minWidth)
            }
        case .pen:
            break
        }
        return out
    }

    /// A light smoothing pass on freehand strokes.
    static func smoothed(_ points: [CGPoint]) -> [CGPoint] {
        guard points.count > 4 else { return points }
        var out = [points[0]]
        for i in 1..<(points.count - 1) {
            let a = points[i - 1], b = points[i], c = points[i + 1]
            out.append(CGPoint(x: (a.x + 2 * b.x + c.x) / 4, y: (a.y + 2 * b.y + c.y) / 4))
        }
        out.append(points[points.count - 1])
        return out
    }

    static func distance(_ p: CGPoint, toSegment a: CGPoint, _ b: CGPoint) -> CGFloat {
        let dx = b.x - a.x, dy = b.y - a.y
        let len2 = dx * dx + dy * dy
        guard len2 > 0 else { return hypot(p.x - a.x, p.y - a.y) }
        let t = max(0, min(1, ((p.x - a.x) * dx + (p.y - a.y) * dy) / len2))
        return hypot(p.x - (a.x + t * dx), p.y - (a.y + t * dy))
    }
}

enum AnnotationRenderer {
    static func draw(_ a: Annotation, in ctx: GraphicsContext, size: CGSize) {
        let color = AnnotationPalette.color(a.color)
        let lw = AnnotationGeometry.lineWidth(size)
        let pts = a.points.map { AnnotationGeometry.px($0, size) }
        switch a.kind {
        case .rectangle:
            let r = AnnotationGeometry.pixelBounds(a, size: size)
            ctx.stroke(Path(roundedRect: r, cornerRadius: lw), with: .color(color), lineWidth: lw)
        case .highlight:
            let r = AnnotationGeometry.pixelBounds(a, size: size)
            ctx.fill(Path(roundedRect: r, cornerRadius: lw), with: .color(color.opacity(0.35)))
        case .arrow:
            guard pts.count >= 2 else { return }
            let (tail, head) = (pts[0], pts[1])
            let angle = atan2(head.y - tail.y, head.x - tail.x)
            let len = min(lw * 5, hypot(head.x - tail.x, head.y - tail.y) * 0.6)
            let left = CGPoint(x: head.x - len * cos(angle - .pi / 7), y: head.y - len * sin(angle - .pi / 7))
            let right = CGPoint(x: head.x - len * cos(angle + .pi / 7), y: head.y - len * sin(angle + .pi / 7))
            let shaftEnd = CGPoint(x: head.x - len * 0.7 * cos(angle), y: head.y - len * 0.7 * sin(angle))
            ctx.stroke(Path { p in p.move(to: tail); p.addLine(to: shaftEnd) }, with: .color(color),
                       style: StrokeStyle(lineWidth: lw, lineCap: .round))
            ctx.fill(Path { p in p.move(to: head); p.addLine(to: left); p.addLine(to: right); p.closeSubpath() }, with: .color(color))
        case .pen:
            guard let first = pts.first else { return }
            var path = Path()
            path.move(to: first)
            for p in pts.dropFirst() { path.addLine(to: p) }
            ctx.stroke(path, with: .color(color), style: StrokeStyle(lineWidth: lw, lineCap: .round, lineJoin: .round))
        case .text:
            guard let text = a.text, !text.isEmpty else { return }
            let box = AnnotationGeometry.textBox(a, size: size)
            let pad = AnnotationGeometry.textPadding(size)
            let font = AnnotationGeometry.fontSize(size)
            ctx.fill(Path(roundedRect: box, cornerRadius: font * 0.25), with: .color(color))
            let resolved = ctx.resolve(Text(text).font(.system(size: font, weight: .semibold))
                .foregroundStyle(AnnotationPalette.textColor(on: a.color)))
            ctx.draw(resolved, in: box.insetBy(dx: pad, dy: pad))
        }
    }
}

/// Draw mode's floating toolbar: tools, colors, done.
struct DrawToolbar: View {
    var model: SessionModel

    var body: some View {
        HStack(spacing: 2) {
            ForEach(AnnotationTool.available) { tool in
                Button { model.tool = tool } label: {
                    Image(systemName: tool.symbol)
                        .font(.system(size: 13, weight: .medium))
                        .frame(width: 28, height: 24)
                        .background(model.tool == tool ? Color.accentColor.opacity(0.25) : .clear, in: .rect(cornerRadius: 6))
                }
                .buttonStyle(.plain)
                .help("\(tool.title) (\(String(tool.key).uppercased()))")
                .accessibilityLabel(tool.title)
                .accessibilityAddTraits(model.tool == tool ? .isSelected : [])
            }
            Divider().frame(height: 18).padding(.horizontal, 6)
            let current = currentColor
            ForEach(AnnotationPalette.colors, id: \.self) { hex in
                Button { model.setColor(hex) } label: {
                    Circle()
                        .fill(AnnotationPalette.color(hex))
                        .overlay(Circle().strokeBorder(.secondary.opacity(0.5), lineWidth: 0.5))
                        .overlay(Circle().strokeBorder(Color.accentColor, lineWidth: current == hex ? 2 : 0).padding(-3))
                        .frame(width: 14, height: 14)
                        .padding(4)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Color \(hex)")
            }
            Divider().frame(height: 18).padding(.horizontal, 6)
            Button("Done") { model.enterDrawMode(false) }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
                .help("Leave draw mode (E or Esc)")
        }
        .padding(.horizontal, 10).padding(.vertical, 5)
        .glassEffect(.regular, in: .capsule)
        .fixedSize()
    }

    private var currentColor: String {
        if let id = model.selectedAnnotation, let a = model.annotations.first(where: { $0.id == id }) { return a.color }
        return model.tool == .highlight ? model.highlightColor : model.annotationColor
    }
}

/// A frame of the edited video with the drawings on screen at that moment, as an image.
@MainActor
enum AnnotatedFrame {
    static func image(model: SessionModel, at t: Double) async throws -> CGImage {
        let generator = AVAssetImageGenerator(asset: model.playbackAsset)
        generator.videoComposition = model.playbackVideoComposition
        generator.appliesPreferredTrackTransform = true
        generator.requestedTimeToleranceBefore = .zero
        generator.requestedTimeToleranceAfter = .zero
        let (frame, _) = try await generator.image(at: CMTime(seconds: t, preferredTimescale: 600))
        let size = CGSize(width: frame.width, height: frame.height)
        let drawings = model.annotations(at: t)
        let renderer = ImageRenderer(content: ZStack(alignment: .topLeading) {
            Image(decorative: frame, scale: 1)
            Canvas { ctx, _ in for a in drawings { AnnotationRenderer.draw(a, in: ctx, size: size) } }
        }.frame(width: size.width, height: size.height))
        guard let image = renderer.cgImage else { throw ReviewError("Couldn't render the frame") }
        return image
    }

    static func write(model: SessionModel, at t: Double, to url: URL) async throws {
        let image = try await image(model: model, at: t)
        guard let dest = CGImageDestinationCreateWithURL(url as CFURL, UTType.png.identifier as CFString, 1, nil) else {
            throw ReviewError("Couldn't write \(url.lastPathComponent)")
        }
        CGImageDestinationAddImage(dest, image, nil)
        guard CGImageDestinationFinalize(dest) else { throw ReviewError("Couldn't write \(url.lastPathComponent)") }
    }
}
