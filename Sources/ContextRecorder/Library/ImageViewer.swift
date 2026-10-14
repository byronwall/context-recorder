import AppKit
import ImageIO
import SwiftUI

/// The in-app image viewer: a mark's screenshot or frame, large, over the session. Replaces Quick Look.
@MainActor @Observable
final class ImageViewerModel {
    struct Item: Hashable {
        var url: URL
        var mark: Int
        var title: String
    }

    let items: [Item]
    private(set) var index: Int
    /// Full resolution; nil while loading.
    private(set) var image: CGImage?
    private(set) var loadFailed = false
    /// Reported by the canvas so the toolbar readout follows pinches and wheels.
    private(set) var zoomPercent: CGFloat = 100

    @ObservationIgnored weak var canvas: ImageCanvasView?
    @ObservationIgnored private weak var session: SessionModel?
    @ObservationIgnored private var loading: Task<Void, Never>?

    init(session: SessionModel, items: [Item], index: Int) {
        self.session = session
        self.items = items
        self.index = index
        load()
    }

    var item: Item { items[index] }

    func step(_ direction: Int) {
        let next = index + direction
        guard items.indices.contains(next) else { NSSound.beep(); return }
        index = next
        session?.select(item.mark, seek: false)
        load()
    }

    func close() {
        loading?.cancel()
        withAnimation(.easeOut(duration: 0.16)) { session?.viewer = nil }
    }

    private func load() {
        let url = item.url
        loading?.cancel()
        loadFailed = false
        loading = Task {
            let image = await Task.detached(priority: .userInitiated) { Self.fullImage(url) }.value
            guard !Task.isCancelled, url == item.url else { return }
            self.image = image
            loadFailed = image == nil
        }
    }

    nonisolated static func fullImage(_ url: URL) -> CGImage? {
        guard let src = CGImageSourceCreateWithURL(url as CFURL, nil) else { return nil }
        return CGImageSourceCreateImageAtIndex(src, 0, [kCGImageSourceShouldCacheImmediately: true] as CFDictionary)
    }

    // MARK: Canvas hooks

    func canvasDidChange(_ canvas: ImageCanvasView) {
        let z = canvas.zoomPercent
        if abs(z - zoomPercent) > 0.05 { zoomPercent = z }
    }

    /// False: a plain drag on the image pans it.
    var handlesPrimaryDrag: Bool { false }
    func primaryDown(at p: CGPoint, in canvas: ImageCanvasView, event: NSEvent, panning: Bool) {}
    func primaryDragged(to p: CGPoint, in canvas: ImageCanvasView, event: NSEvent) {}
    func primaryUp(at p: CGPoint, in canvas: ImageCanvasView, event: NSEvent) {}
    func hover(_ p: CGPoint?, in canvas: ImageCanvasView) -> NSCursor { .openHand }
    func keyDown(_ event: NSEvent, in canvas: ImageCanvasView) -> Bool { false }
    func keyEquivalent(_ event: NSEvent, in canvas: ImageCanvasView) -> Bool { false }
}

extension SessionModel {
    /// Every image a session's marks show, in mark order: each mark's image, then a shot's full frame.
    var viewerItems: [ImageViewerModel.Item] {
        var items: [ImageViewerModel.Item] = []
        for m in marks {
            let name = m.isShot ? "Shot \(m.index)" : "Mark \(m.index)"
            if let url = url(m.image) { items.append(.init(url: url, mark: m.index, title: name)) }
            if m.isShot, m.frame != m.image, let frame = url(m.frame), FileManager.default.fileExists(atPath: frame.path) {
                items.append(.init(url: frame, mark: m.index, title: "\(name) · full screen"))
            }
        }
        return items.reduce(into: []) { list, item in if !list.contains(where: { $0.url == item.url }) { list.append(item) } }
    }

    /// Opens `url` in the viewer, with the session's other images a step away.
    func view(_ url: URL) {
        let items = viewerItems
        guard let i = items.firstIndex(where: { $0.url == url }) else { return }
        player.pause()
        withAnimation(.easeOut(duration: 0.18)) { viewer = ImageViewerModel(session: self, items: items, index: i) }
    }
}

// MARK: Overlay

/// Covers the stage and timeline; the marks inspector stays beside it.
struct ImageViewerOverlay: View {
    @Bindable var viewer: ImageViewerModel

    var body: some View {
        ZStack {
            Rectangle().fill(.black.opacity(0.88))
                .background(.ultraThinMaterial)
                .environment(\.colorScheme, .dark)
            ImageCanvas(viewer: viewer)
                .accessibilityLabel(viewer.item.title)
                .accessibilityAddTraits(.isImage)
            if viewer.image == nil {
                if viewer.loadFailed {
                    ContentUnavailableView("Can't Open Image", systemImage: "photo.badge.exclamationmark",
                                           description: Text(viewer.item.url.lastPathComponent))
                } else {
                    ProgressView().controlSize(.large)
                }
            }
        }
        .overlay(alignment: .top) { ViewerToolbar(viewer: viewer).padding(.top, 12) }
        .environment(\.colorScheme, .dark)
    }
}

struct ViewerToolbar: View {
    var viewer: ImageViewerModel

    var body: some View {
        HStack(spacing: 10) {
            group {
                button("chevron.left", "Previous image (←)", disabled: viewer.index == 0) { viewer.step(-1) }
                VStack(spacing: 0) {
                    Text(viewer.item.title).font(.system(size: 12, weight: .semibold))
                    Text("\(viewer.index + 1) of \(viewer.items.count)")
                        .font(.system(size: 10, weight: .medium).monospacedDigit())
                        .foregroundStyle(.secondary)
                }
                .frame(minWidth: 96)
                button("chevron.right", "Next image (→)", disabled: viewer.index == viewer.items.count - 1) { viewer.step(1) }
            }
            Spacer(minLength: 0)
            group { ZoomControls(viewer: viewer) }
            group { button("xmark", "Close (Esc)") { viewer.close() } }
        }
        .padding(.horizontal, 14)
    }

    private func group<Content: View>(@ViewBuilder _ content: () -> Content) -> some View {
        HStack(spacing: 2) { content() }
            .padding(.horizontal, 6).padding(.vertical, 4)
            .glassEffect(.regular, in: .capsule)
    }

    private func button(_ symbol: String, _ help: String, disabled: Bool = false, action: @escaping () -> Void) -> some View {
        ViewerButton(symbol: symbol, help: help, action: action).disabled(disabled)
    }
}

struct ZoomControls: View {
    var viewer: ImageViewerModel

    var body: some View {
        ViewerButton(symbol: "minus.magnifyingglass", help: "Zoom out (⌘−)") { viewer.canvas?.zoomStep(-1) }
        Menu {
            Button("Fit (⌘0)") { viewer.canvas?.fit() }
            Button("Actual Size (⌘1)") { viewer.canvas?.actualSize() }
            Divider()
            ForEach([25, 50, 100, 200, 400], id: \.self) { p in
                Button("\(p)%") { viewer.canvas?.zoom(percent: CGFloat(p)) }
            }
        } label: {
            Text("\(Int(viewer.zoomPercent.rounded()))%")
                .font(.system(size: 11, weight: .semibold).monospacedDigit())
                .frame(width: 44, height: 24)
        }
        .menuStyle(.button)
        .buttonStyle(.plain)
        .menuIndicator(.hidden)
        .fixedSize()
        .help("Zoom")
        .accessibilityLabel("Zoom \(Int(viewer.zoomPercent.rounded())) percent")
        ViewerButton(symbol: "plus.magnifyingglass", help: "Zoom in (⌘+)") { viewer.canvas?.zoomStep(1) }
    }
}

struct ViewerButton: View {
    var symbol: String
    var help: String
    var selected = false
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 13, weight: .semibold))
                .frame(width: 28, height: 26)
                .background(selected ? AnyShapeStyle(.white.opacity(0.18)) : AnyShapeStyle(.clear), in: .rect(cornerRadius: 7))
                .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .help(help)
        .accessibilityLabel(help)
        .accessibilityAddTraits(selected ? .isSelected : [])
    }
}
