import AppKit
import CanvasKit
import SwiftUI

/// The recording laid out in space: items left to right in time order, all at one scale, so a page that
/// scrolled reads as one tall column. Hover shows that moment's narration; click returns to the video there.
struct CanvasStage: View {
    var model: SessionModel
    /// nil = fit one viewport to the stage height.
    @State private var zoom: CGFloat?
    @State private var pinch: CGFloat = 1
    @State private var images = CanvasImages()

    var body: some View {
        if let doc = model.canvas {
            GeometryReader { geo in
                let fit = fitZoom(doc, geo.size)
                let scale = max(0.05, min(2, (zoom ?? fit) * pinch))
                ZStack(alignment: .bottom) {
                    Color.stage
                    ScrollViewReader { proxy in
                        ScrollView([.horizontal, .vertical]) {
                            CanvasStrip(model: model, doc: doc, images: images, scale: scale)
                        }
                        .onAppear {
                            if let id = model.canvasItem(at: model.currentTime)?.id { proxy.scrollTo(id, anchor: .center) }
                        }
                    }
                    .gesture(MagnifyGesture()
                        .onChanged { pinch = $0.magnification }
                        .onEnded { v in zoom = max(0.05, min(2, (zoom ?? fit) * v.magnification)); pinch = 1 })

                    controls(doc, fit: fit, scale: scale).padding(.bottom, 16)
                }
            }
            .task(id: doc.builtAt) { images.load(doc, folder: model.folder) }
            .onDisappear { model.previewTime = nil }
        } else {
            ContentUnavailableView {
                Label(model.canvasOutdated ? "Canvas Needs Rebuilding" : "No Canvas", systemImage: "rectangle.split.3x1")
            } description: {
                Text(model.canvasOutdated ? "An older version built this canvas. Rebuild it to see the recording laid out in space."
                                          : "Build a canvas to see this recording laid out in space.")
            } actions: {
                Button(model.canvasOutdated ? "Rebuild Canvas" : "Build Canvas") { model.buildCanvas() }
                    .disabled(model.canvasBuilding)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color.stage)
        }
    }

    // MARK: Controls

    private func controls(_ doc: CanvasDocument, fit: CGFloat, scale: CGFloat) -> some View {
        let cols = doc.items.filter { $0.kind == .column }.count
        return HStack(spacing: 4) {
            button("minus.magnifyingglass", "Zoom out") { zoom = max(0.05, scale / 1.25) }
            Button { zoom = nil } label: {
                Text("\(Int((scale * 100).rounded()))%")
                    .font(.system(size: 11, weight: .semibold).monospacedDigit())
                    .frame(width: 44, height: 30)
                    .contentShape(.rect)
            }
            .buttonStyle(.plain)
            .help("Fit to the stage")
            button("plus.magnifyingglass", "Zoom in") { zoom = min(2, scale * 1.25) }

            Divider().frame(height: 18).padding(.horizontal, 6)

            button("flag", "Add a mark at the moment under the pointer (M)") { Task { await model.markFromCanvas() } }
            button("camera.viewfinder", "Capture a region of the canvas as a mark (S)") { model.startCanvasShot() }

            Divider().frame(height: 18).padding(.horizontal, 6)

            Text(cols == 0 ? "\(doc.items.count) cards" : "\(cols) columns · \(doc.items.count - cols) cards")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.secondary)
                .fixedSize()
                .padding(.trailing, 4)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .glassEffect(.regular, in: .capsule)
        .fixedSize()
    }

    private func button(_ symbol: String, _ help: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 13, weight: .semibold))
                .frame(width: 30, height: 30)
                .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .help(help)
        .accessibilityLabel(help)
    }

    /// One viewport fills the stage height, leaving room for labels and the controls.
    private func fitZoom(_ doc: CanvasDocument, _ size: CGSize) -> CGFloat {
        let available = size.height - 18 - 78 - 24
        return max(0.05, min(1, available / CGFloat(max(1, doc.box.height))))
    }
}

/// The items in a row at one scale. Separate from the scroll view so it can also be rendered offscreen.
struct CanvasStrip: View {
    var model: SessionModel
    var doc: CanvasDocument
    var images: CanvasImages
    var scale: CGFloat
    @State private var hoverY: (id: String, y: CGFloat)?

    init(model: SessionModel, doc: CanvasDocument, images: CanvasImages, scale: CGFloat, hover: (id: String, y: CGFloat)? = nil) {
        self.model = model
        self.doc = doc
        self.images = images
        self.scale = scale
        _hoverY = State(initialValue: hover)
    }

    var body: some View {
        HStack(alignment: .top, spacing: 26) {
            ForEach(doc.items) { item in
                itemView(item, scale: scale).id(item.id)
            }
        }
        .padding(.horizontal, 28)
        .padding(.top, 18)
        .padding(.bottom, 78)
    }

    // MARK: Items

    private func itemView(_ item: CanvasItem, scale: CGFloat) -> some View {
        let current = model.canvasItem(at: model.focusTime)?.id == item.id
        let w = CGFloat(item.width) * scale, h = CGFloat(item.height) * scale
        return VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Text(Format.time(item.start)).font(.system(size: 11, weight: .semibold).monospacedDigit())
                if let label = label(item.reason) {
                    Text(label)
                        .font(.system(size: 10.5, weight: .medium))
                        .foregroundStyle(item.reason == .ambiguous || item.reason == .noOverlap ? .orange : .secondary)
                }
            }
            .foregroundStyle(current ? .primary : .secondary)
            .frame(width: w, alignment: .leading)
            .lineLimit(1)

            Group {
                if let image = images[item.image] {
                    Image(nsImage: image).resizable().interpolation(.high)
                } else {
                    Rectangle().fill(.quaternary)
                }
            }
            .frame(width: w, height: h)
            .overlay(alignment: .topLeading) {
                if let hover = hoverY, hover.id == item.id {
                    Rectangle().fill(Color.accentColor.opacity(0.8)).frame(height: 1.5).offset(y: hover.y)
                        .allowsHitTesting(false)
                }
            }
            .overlay {
                if model.canvasSelecting {
                    CanvasSelection { rect in
                        let r = CGRect(x: rect.minX / scale, y: rect.minY / scale, width: rect.width / scale, height: rect.height / scale)
                        Task { await model.markFromCanvas(item, imageRect: r) }
                    }
                }
            }
            .clipShape(.rect(cornerRadius: 6))
            .overlay(RoundedRectangle(cornerRadius: 6).strokeBorder(current ? Color.accentColor : .black.opacity(0.12),
                                                                     lineWidth: current ? 2 : 0.5))
            .overlay(alignment: .topTrailing) {
                // In a column, rows come from different moments: show when the row under the pointer was on screen.
                if item.kind == .column, let hover = hoverY, hover.id == item.id {
                    Text(Format.time(item.frame(atImageY: Double(hover.y / scale)).time))
                        .font(.system(size: 10.5, weight: .semibold).monospacedDigit())
                        .foregroundStyle(.white)
                        .padding(.horizontal, 6).padding(.vertical, 2)
                        .background(Color.accentColor, in: .capsule)
                        .offset(x: 6, y: max(0, hover.y - 18))
                        .allowsHitTesting(false)
                }
            }
            .shadow(color: .black.opacity(0.14), radius: 10, y: 4)
            .contentShape(.rect)
            .onContinuousHover(coordinateSpace: .local) { phase in
                switch phase {
                case .active(let p):
                    hoverY = (item.id, p.y)
                    model.previewTime = item.frame(atImageY: Double(p.y / scale)).time
                    NSCursor.pointingHand.set()
                case .ended:
                    if hoverY?.id == item.id { hoverY = nil; model.previewTime = nil }
                    NSCursor.arrow.set()
                }
            }
            .onTapGesture(coordinateSpace: .local) { p in
                NSCursor.arrow.set()
                model.showSource(item.frame(atImageY: Double(p.y / scale)))
            }
            .contextMenu { contextMenu(item) }
            .accessibilityElement()
            .accessibilityLabel("\(item.kind == .column ? "Column" : "Card") at \(Format.time(item.start))")
            .accessibilityHint("Shows the video at this moment")
            .accessibilityAddTraits(.isButton)
            .accessibilityAction { model.showSource(item.frame) }
        }
    }

    @ViewBuilder private func contextMenu(_ item: CanvasItem) -> some View {
        Button("Show in Video", systemImage: "play.rectangle") { model.showSource(item.frame) }
        Divider()
        Button("Copy Image", systemImage: "doc.on.doc") {
            guard let image = images[item.image] else { return }
            NSPasteboard.general.clearContents()
            NSPasteboard.general.writeObjects([image])
        }
        Button("Export PNG…", systemImage: "square.and.arrow.down") { export(item) }
        Button("Capture Region as Mark…", systemImage: "camera.viewfinder") { model.startCanvasShot() }
        Divider()
        Button("Reveal Image in Finder", systemImage: "folder") {
            NSWorkspace.shared.activateFileViewerSelecting([model.folder.appendingPathComponent(item.image)])
        }
    }

    /// Saves a copy of the item's image. A column combines several moments; its name gives the time span.
    private func export(_ item: CanvasItem) {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.png]
        panel.nameFieldStringValue = model.exportName(item)
        panel.message = item.kind == .column ? "A column joins frames from \(Format.time(item.start)) to \(Format.time(item.end))." : ""
        guard panel.runModal() == .OK, let url = panel.url else { return }
        do {
            try? FileManager.default.removeItem(at: url)
            try FileManager.default.copyItem(at: model.folder.appendingPathComponent(item.image), to: url)
        } catch {
            model.canvasError = "Couldn't export: \(error.localizedDescription)"
        }
    }

    private func label(_ reason: CanvasItem.Reason) -> String? {
        switch reason {
        case .start: nil
        case .change: "Changed"
        case .motion: "Moving"
        case .noOverlap: "Not joined: no overlap"
        case .ambiguous: "Not joined: ambiguous"
        case .heightLimit: "Continued"
        }
    }

}

/// Drag out a rectangle on a canvas item while capturing a region as a mark.
struct CanvasSelection: View {
    var done: (CGRect) -> Void
    @State private var start: CGPoint?
    @State private var end: CGPoint?

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .topLeading) {
                Rectangle().fill(Color.shot.opacity(0.06))
                if let r = rect {
                    Rectangle()
                        .strokeBorder(Color.shot, style: StrokeStyle(lineWidth: 1.5, dash: [5, 3]))
                        .background(Color.shot.opacity(0.12))
                        .frame(width: r.width, height: r.height)
                        .offset(x: r.minX, y: r.minY)
                }
            }
            .contentShape(.rect)
            .gesture(DragGesture(minimumDistance: 2)
                .onChanged { g in start = start ?? g.startLocation; end = g.location }
                .onEnded { _ in
                    if let r = rect { done(r.intersection(CGRect(origin: .zero, size: geo.size))) }
                    start = nil; end = nil
                })
            .onContinuousHover { phase in
                if case .active = phase { NSCursor.crosshair.set() } else { NSCursor.arrow.set() }
            }
        }
    }

    private var rect: CGRect? {
        guard let start, let end else { return nil }
        return CGRect(x: min(start.x, end.x), y: min(start.y, end.y), width: abs(end.x - start.x), height: abs(end.y - start.y))
    }
}

/// Canvas images, decoded once per build.
@MainActor @Observable
final class CanvasImages {
    private var images: [String: NSImage] = [:]
    private var builtAt: String?

    subscript(_ path: String) -> NSImage? { images[path] }

    func load(_ doc: CanvasDocument, folder: URL) {
        guard builtAt != doc.builtAt else { return }
        builtAt = doc.builtAt
        images = [:]
        for item in doc.items {
            if let image = NSImage(contentsOf: folder.appendingPathComponent(item.image)) { images[item.image] = image }
        }
    }
}
