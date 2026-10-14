import CoreGraphics
import Foundation

/// RegionShot's annotation set, as data: what a person drew on one image.
///
/// Coordinates are image pixels with the origin at the top-left, so a document stays valid at any zoom and
/// can be flattened onto the original without knowing how it was displayed. The same shapes are meant to
/// sit on video frames later (session editing adds a time range); nothing here assumes a still image
/// beyond `imageSize`.
public struct AnnotationDoc: Codable, Equatable, Sendable {
    public static let currentVersion = 1

    public var version = AnnotationDoc.currentVersion
    /// Pixel size of the image the shapes were drawn on.
    public var imageSize: CGSize
    /// The kept area, in image pixels; nil keeps the whole image.
    public var crop: CGRect?
    /// Back to front.
    public var shapes: [Shape]

    public init(imageSize: CGSize, crop: CGRect? = nil, shapes: [Shape] = []) {
        self.imageSize = imageSize
        self.crop = crop
        self.shapes = shapes
    }

    /// Nothing drawn and nothing cropped: the image as captured.
    public var isEmpty: Bool { shapes.isEmpty && crop == nil }

    /// The part of the image that shows: the crop, or all of it.
    public var contentRect: CGRect { crop ?? CGRect(origin: .zero, size: imageSize) }

    /// Pretty, stable JSON for `annotations/<name>.json`.
    public func encoded() throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return try encoder.encode(self)
    }

    public static func decoded(from data: Data) throws -> AnnotationDoc {
        try JSONDecoder().decode(AnnotationDoc.self, from: data)
    }

    public func index(of id: Shape.ID?) -> Int? { shapes.firstIndex { $0.id == id } }

    public subscript(id: Shape.ID) -> Shape? {
        get { shapes.first { $0.id == id } }
        set {
            guard let i = index(of: id) else { return }
            if let newValue { shapes[i] = newValue } else { shapes.remove(at: i) }
        }
    }
}

public struct Shape: Codable, Equatable, Identifiable, Sendable {
    public enum Kind: String, Codable, CaseIterable, Sendable {
        case rect, arrow, text, highlight, freehand
    }

    public var id: UUID
    public var kind: Kind
    /// `#RRGGBB`. Text uses it as its background.
    public var color: String
    /// Stroke width in image pixels (rect, arrow, freehand).
    public var lineWidth: Double
    /// rect, highlight: two opposite corners. arrow: tail, then head. freehand: the stroke. text: top-left.
    public var points: [CGPoint]
    public var text: String?
    public var fontSize: Double?
    /// Text wraps at this width (image pixels); nil grows with the text up to `Style.autoWrap`.
    public var wrapWidth: Double?

    public init(id: UUID = UUID(), kind: Kind, color: String, lineWidth: Double, points: [CGPoint],
                text: String? = nil, fontSize: Double? = nil, wrapWidth: Double? = nil) {
        self.id = id
        self.kind = kind
        self.color = color
        self.lineWidth = lineWidth
        self.points = points
        self.text = text
        self.fontSize = fontSize
        self.wrapWidth = wrapWidth
    }

    /// The rectangle a rect or highlight covers, from its two corners.
    public var rect: CGRect {
        guard points.count >= 2 else { return CGRect(origin: points.first ?? .zero, size: .zero) }
        return CGRect(x: min(points[0].x, points[1].x), y: min(points[0].y, points[1].y),
                      width: abs(points[1].x - points[0].x), height: abs(points[1].y - points[0].y))
    }
}

/// Defaults that scale with the image, so a box on a 4K frame isn't a hairline and one on a small
/// region shot isn't a crayon.
public enum Style {
    public static let palette = ["#FF3B30", "#FF9500", "#FFD60A", "#34C759", "#0A84FF", "#BF5AF2", "#1C1C1E", "#FFFFFF"]
    public static let highlightPalette = ["#FFD60A", "#34C759", "#FF6FD8", "#64D2FF"]
    public static let defaultColor = "#FF3B30"
    public static let defaultHighlight = "#FFD60A"
    /// Highlight fill opacity; it multiplies over the image.
    public static let highlightAlpha = 0.38

    public static func lineWidth(for size: CGSize) -> Double {
        (max(size.width, size.height) / 320).clamped(3, 14)
    }

    public static func fontSize(for size: CGSize) -> Double {
        (max(size.width, size.height) / 36).clamped(16, 72)
    }

    /// Unset wrap widths grow to this, then wrap (RegionShot's 400 px at its default size).
    public static func autoWrap(fontSize: Double) -> Double { fontSize * 22 }
    public static func textPadding(fontSize: Double) -> Double { (fontSize * 0.35).rounded() }
}

extension Double {
    func clamped(_ lo: Double, _ hi: Double) -> Double { Swift.min(Swift.max(self, lo), hi) }
}
