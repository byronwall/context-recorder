import CanvasKit
import Foundation

/// The canvas: the recording laid out left to right, built on request into canvas.json beside the video.
/// Without a canvas (or with one that no longer matches the video) the session works exactly as before.
extension SessionModel {
    var canvasBuilding: Bool { canvasProgress != nil }

    /// Picks up canvas.json when it appears or changes; checks it still describes recording.mp4.
    func reloadCanvas() {
        let url = CanvasDocument.url(in: folder)
        let stamp = (try? FileManager.default.attributesOfItem(atPath: url.path))?[.modificationDate] as? Date
        guard stamp != canvasStamp else { return }
        canvasStamp = stamp
        guard stamp != nil, let doc = try? CanvasDocument.load(from: folder), doc.version == CanvasDocument.currentVersion else {
            canvas = nil
            canvasStale = false
            canvasOutdated = stamp != nil
            if stage == .canvas, !canvasBuilding { stage = .video }
            return
        }
        canvas = doc
        canvasStale = false
        canvasOutdated = false
        let folder = self.folder
        Task.detached(priority: .utility) {
            let matches = CanvasAnalyzer.matchesVideo(doc, folder: folder)
            await MainActor.run { [weak self] in
                guard let self, self.canvas == doc else { return }
                self.canvasStale = !matches
            }
        }
    }

    /// Build canvas from the whole recording: the analyzer finds the scrolling page itself.
    func buildCanvas() { buildCanvas(box: nil) }

    /// Build from a chosen area: pause and let the user drag around the page content. A diagnostic and an escape
    /// hatch; the ordinary build doesn't need it. A click takes the whole frame.
    func chooseCanvasBox() {
        player.pause()
        stage = .video
        canvasError = nil
        regionPurpose = .canvasBox
        regionMode = true
    }

    /// Rebuild from the whole recording. An area chosen for an earlier build is not reused silently.
    func rebuildCanvas() { buildCanvas(box: nil) }

    /// `region` is normalized to the video (0…1, top-left origin); nil = whole frame.
    func buildCanvas(region: CGRect?) {
        let box = region.flatMap { r -> PixelRect? in
            guard let size = videoSize else { return nil }
            return PixelRect(x: Int((r.minX * size.width).rounded()), y: Int((r.minY * size.height).rounded()),
                             width: Int((r.width * size.width).rounded()), height: Int((r.height * size.height).rounded()))
        }
        buildCanvas(box: box)
    }

    func buildCanvas(box: PixelRect?) {
        canvasTask?.cancel()
        canvasProgress = 0
        canvasError = nil
        let folder = self.folder
        let ref = WeakModel(self)
        canvasTask = Task { [weak self] in
            do {
                let doc = try await CanvasAnalyzer.build(folder: folder, box: box) { p in
                    Task { @MainActor in if let m = ref.model, m.canvasProgress != nil { m.canvasProgress = p } }
                }
                guard let self else { return }
                self.canvasProgress = nil
                self.canvasStamp = nil
                self.reloadCanvas()
                if self.canvas == doc { self.stage = .canvas }
            } catch is CancellationError {
                self?.canvasProgress = nil
            } catch {
                self?.canvasProgress = nil
                self?.canvasError = "Couldn't build the canvas: \(error.localizedDescription)"
            }
        }
    }

    func cancelCanvasBuild() {
        canvasTask?.cancel()
        canvasTask = nil
        canvasProgress = nil
    }

    /// Back to plain video review.
    func deleteCanvas() {
        cancelCanvasBuild()
        CanvasDocument.remove(from: folder)
        canvasStamp = nil
        reloadCanvas()
        stage = .video
    }

    /// Show the video at the frame that supplied this part of the canvas.
    func showSource(_ frame: FrameRef) {
        if isPlaying { togglePlay() }
        previewTime = nil
        canvasSelecting = false
        seek(frame.seekTime)
        stage = .video
    }

    // MARK: Marks from the canvas

    /// S on the canvas: drag over an item to capture that region of its source frame as a review shot.
    func startCanvasShot() {
        if isPlaying { togglePlay() }
        canvasSelecting = true
    }

    /// M on the canvas: a mark at the moment under the pointer, or at the playhead.
    func markFromCanvas() async {
        if let t = previewTime { seek(t + 0.002) }
        await addReviewMark()
    }

    /// `rect` is in the item's image pixels. The shot comes from the one frame that supplied the middle of the
    /// selection, clipped to what that frame showed, so a mark never mixes moments.
    func markFromCanvas(_ item: CanvasItem, imageRect rect: CGRect) async {
        canvasSelecting = false
        guard let doc = canvas, rect.width > 4, rect.height > 4,
              let (frame, source) = item.sourceRegion(for: rect, box: doc.box) else { return }
        let W = Double(doc.video.width), H = Double(doc.video.height)
        let region = CGRect(x: source.minX / W, y: source.minY / H, width: source.width / W, height: source.height / H)
        previewTime = nil
        seek(frame.seekTime)
        await addReviewShot(region: region)
    }

    // MARK: Export

    /// File name for an exported item: session, kind and time span (no colons; Finder shows them as slashes).
    func exportName(_ item: CanvasItem) -> String {
        func t(_ s: Double) -> String { String(format: "%02d-%02d", Int(s) / 60, Int(s) % 60) }
        let kind = item.kind == .column ? "column" : "card"
        return "\(folder.lastPathComponent) \(kind) \(t(item.start)) to \(t(item.end)).png"
    }

    /// The canvas item on screen at the playhead.
    func canvasItem(at t: Double) -> CanvasItem? {
        canvas?.items.last { $0.start <= t + 0.001 } ?? canvas?.items.first
    }
}

/// Lets progress reports from the analyzer reach the model without keeping it alive.
private final class WeakModel: @unchecked Sendable {
    weak var model: SessionModel?
    init(_ model: SessionModel) { self.model = model }
}
