import Foundation

/// canvas.json: a session's recording laid out in space, written by `CanvasAnalyzer` beside recording.mp4.
///
/// The canvas reads left to right. Every item is either a **card** (one frame, for a moment with no joined
/// scrolling) or a **column** (frames joined into one tall image while a page scrolled). Every displayed
/// pixel maps back to one decoded frame through `frame` (cards) or `patches` (columns), so a click can
/// return to the moment that supplied it. Images live under `canvas/` and are cropped to the content box.
public struct CanvasDocument: Codable, Equatable, Sendable {
    public static let currentVersion = 1
    public static let fileName = "canvas.json"
    public static let imageFolder = "canvas"

    public var version: Int
    public var video: VideoInfo
    /// The content area chosen when building, in video pixels (top-left origin).
    public var box: PixelRect
    public var builtAt: String
    public var items: [CanvasItem]

    public init(version: Int = CanvasDocument.currentVersion, video: VideoInfo, box: PixelRect, builtAt: String, items: [CanvasItem]) {
        self.version = version
        self.video = video
        self.box = box
        self.builtAt = builtAt
        self.items = items
    }

    public static func url(in folder: URL) -> URL { folder.appendingPathComponent(fileName) }

    public static func load(from folder: URL) throws -> CanvasDocument {
        try JSONDecoder().decode(CanvasDocument.self, from: Data(contentsOf: url(in: folder)))
    }

    public func write(to folder: URL) throws {
        let enc = JSONEncoder()
        enc.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        try enc.encode(self).write(to: Self.url(in: folder), options: .atomic)
    }

    /// Removes canvas.json and the canvas images: the session goes back to plain video review.
    public static func remove(from folder: URL) {
        let fm = FileManager.default
        try? fm.removeItem(at: url(in: folder))
        try? fm.removeItem(at: folder.appendingPathComponent(imageFolder))
    }
}

public struct VideoInfo: Codable, Equatable, Sendable {
    public var file: String
    public var byteSize: Int64
    public var sha256: String
    public var width: Int
    public var height: Int
    public var duration: Double
    public var frameCount: Int

    public init(file: String, byteSize: Int64, sha256: String, width: Int, height: Int, duration: Double, frameCount: Int) {
        self.file = file
        self.byteSize = byteSize
        self.sha256 = sha256
        self.width = width
        self.height = height
        self.duration = duration
        self.frameCount = frameCount
    }
}

public struct PixelRect: Codable, Equatable, Hashable, Sendable {
    public var x: Int
    public var y: Int
    public var width: Int
    public var height: Int

    public init(x: Int, y: Int, width: Int, height: Int) {
        self.x = x
        self.y = y
        self.width = width
        self.height = height
    }

    public var maxX: Int { x + width }
    public var maxY: Int { y + height }
    public var cgRect: CGRect { CGRect(x: x, y: y, width: width, height: height) }
}

/// One decoded frame: its position in decode order and its presentation time in seconds.
public struct FrameRef: Codable, Equatable, Hashable, Sendable {
    public var index: Int
    public var time: Double

    public init(index: Int, time: Double) {
        self.index = index
        self.time = time
    }

    /// Where to seek so a zero-tolerance seek shows exactly this frame. Rounding seconds back into a
    /// media timescale can land just before the presentation time and show the previous frame.
    public var seekTime: Double { time + 0.002 }
}

public struct CanvasItem: Codable, Equatable, Identifiable, Sendable {
    public enum Kind: String, Codable, Sendable { case card, column }

    /// Why this item starts a new place on the canvas instead of continuing the previous one.
    public enum Reason: String, Codable, Sendable {
        /// The first item.
        case start
        /// The content changed (an edit, a new page, a different app).
        case change
        /// The view kept changing (animation, video, fast scrolling) without settling or joining.
        case motion
        /// Scrolling went further than the frames overlap, so nothing ties the two views together.
        case noOverlap = "no-overlap"
        /// More than one scroll distance fits (repeated rows, blank space); joining would be a guess.
        case ambiguous
        /// A column reached the height limit and continues in the next one.
        case heightLimit = "height-limit"
    }

    public var id: String
    public var kind: Kind
    public var reason: Reason
    /// The interval this item covers, in seconds: from its first frame to the next item's first frame.
    public var start: Double
    public var end: Double
    /// The representative frame: a card's only frame, a column's first frame.
    public var frame: FrameRef
    /// Relative to the session folder.
    public var image: String
    /// Image size in pixels.
    public var width: Int
    public var height: Int
    /// Columns only: which frame supplied which rows. Cards have none (the whole image is `frame`).
    public var patches: [Patch]
    /// Columns only: the image starts this many pixels into the content box (a sticky sidebar was left out).
    public var sourceX: Int?

    public init(id: String, kind: Kind, reason: Reason, start: Double, end: Double, frame: FrameRef,
                image: String, width: Int, height: Int, patches: [Patch] = [], sourceX: Int? = nil) {
        self.id = id
        self.kind = kind
        self.reason = reason
        self.start = start
        self.end = end
        self.frame = frame
        self.image = image
        self.width = width
        self.height = height
        self.patches = patches
        self.sourceX = sourceX
    }

    /// The frame that supplied the pixel at `y` in this item's image.
    public func frame(atImageY y: Double) -> FrameRef {
        guard kind == .column, !patches.isEmpty else { return frame }
        // Later patches are drawn over earlier ones, so the last one covering y wins.
        if let p = patches.last(where: { Double($0.destY) <= y && y < Double($0.destY + $0.height) }) { return p.frame }
        return patches.min { abs(Double($0.destY) - y) < abs(Double($1.destY) - y) }!.frame
    }

    /// The video region (pixels, top-left origin) and frame behind `rect` in this item's image. The frame is the
    /// one that supplied the middle of the selection; the region is clipped to what that frame showed, so it
    /// never mixes moments. nil when too little of the selection is left.
    public func sourceRegion(for rect: CGRect, box: PixelRect) -> (frame: FrameRef, rect: CGRect)? {
        let f = frame(atImageY: Double(rect.midY))
        // Where that frame's row 0 sits in the image.
        var viewTop = 0.0
        if kind == .column,
           let p = patches.last(where: { $0.frame == f && Double($0.destY) <= Double(rect.midY) && Double(rect.midY) < Double($0.destY + $0.height) }) {
            viewTop = Double(p.destY - p.sourceY)
        }
        let top = max(Double(rect.minY), viewTop), bottom = min(Double(rect.maxY), viewTop + Double(box.height))
        let left = max(0, Double(rect.minX)), right = min(Double(width), Double(rect.maxX))
        guard bottom - top >= 2, right - left >= 2 else { return nil }
        let x = Double(box.x + (sourceX ?? 0)) + left
        let y = Double(box.y) + (top - viewTop)
        return (f, CGRect(x: x, y: y, width: right - left, height: bottom - top))
    }

    /// The content-box rectangle (top-left origin) that supplied the image rows `y0..<y1`, with its frame.
    public func source(forImageRows y0: Int, _ y1: Int) -> (frame: FrameRef, sourceY: Int, height: Int)? {
        guard kind == .column else { return (frame, max(0, y0), min(height, y1) - max(0, y0)) }
        let mid = Double(y0 + y1) / 2
        let f = frame(atImageY: mid)
        guard let p = patches.last(where: { $0.frame == f && $0.destY <= Int(mid) && Int(mid) < $0.destY + $0.height }) else { return nil }
        let top = max(y0, p.destY), bottom = min(y1, p.destY + p.height)
        return (f, p.sourceY + (top - p.destY), bottom - top)
    }
}

/// Rows `sourceY ..< sourceY + height` of `frame`'s content box, drawn at `destY` in the column image.
/// Patches are full box width; scrolling is vertical.
public struct Patch: Codable, Equatable, Sendable {
    public var frame: FrameRef
    public var sourceY: Int
    public var destY: Int
    public var height: Int

    public init(frame: FrameRef, sourceY: Int, destY: Int, height: Int) {
        self.frame = frame
        self.sourceY = sourceY
        self.destY = destY
        self.height = height
    }
}
