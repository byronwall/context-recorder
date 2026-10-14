import CoreGraphics
import CoreText
import Foundation

/// Draws shapes. The live canvas and the flattened PNG use the same code, so what you see while editing
/// is what the export gets.
///
/// Every function expects a context whose user space is image pixels with y pointing down.
public enum Renderer {
    // MARK: Text layout

    public struct TextLayout {
        /// The background box, in image pixels.
        public var box: CGRect
        public var padding: Double
        fileprivate var framesetter: CTFramesetter
        fileprivate var textSize: CGSize
    }

    public static func font(size: Double) -> CTFont {
        CTFontCreateUIFontForLanguage(.emphasizedSystem, size, nil) ?? CTFontCreateWithName("Helvetica-Bold" as CFString, size, nil)
    }

    public static func textLayout(_ shape: Shape) -> TextLayout {
        let size = shape.fontSize ?? 24
        let pad = Style.textPadding(fontSize: size)
        // An empty or trailing line still needs its height measured.
        var string = shape.text ?? ""
        if string.isEmpty || string.hasSuffix("\n") { string += " " }
        let attributed = NSAttributedString(string: string, attributes: [
            NSAttributedString.Key(kCTFontAttributeName as String): font(size: size),
            NSAttributedString.Key(kCTForegroundColorAttributeName as String): textColor(on: shape.color),
        ])
        let setter = CTFramesetterCreateWithAttributedString(attributed)
        let limit = shape.wrapWidth ?? Style.autoWrap(fontSize: size)
        var fit = CTFramesetterSuggestFrameSizeWithConstraints(setter, CFRange(), nil,
                                                               CGSize(width: limit, height: .greatestFiniteMagnitude), nil)
        fit.width = shape.wrapWidth ?? max(ceil(fit.width), size * 2.5)
        fit.height = ceil(fit.height)
        let origin = shape.points.first ?? .zero
        let box = CGRect(x: origin.x, y: origin.y, width: fit.width + pad * 2, height: fit.height + pad * 2)
        return TextLayout(box: box, padding: pad, framesetter: setter, textSize: fit)
    }

    // MARK: Bounds

    /// What a shape covers on the image, stroke included.
    public static func bounds(_ shape: Shape) -> CGRect {
        switch shape.kind {
        case .rect: return shape.rect.insetBy(dx: -shape.lineWidth / 2, dy: -shape.lineWidth / 2)
        case .highlight: return shape.rect
        case .text: return textLayout(shape).box
        case .arrow:
            let head = arrowHead(shape)
            return pathBounds(shape.points).union(pathBounds(head)).insetBy(dx: -shape.lineWidth, dy: -shape.lineWidth)
        case .freehand: return pathBounds(shape.points).insetBy(dx: -shape.lineWidth / 2, dy: -shape.lineWidth / 2)
        }
    }

    static func pathBounds(_ points: [CGPoint]) -> CGRect {
        guard let first = points.first else { return .null }
        return points.dropFirst().reduce(CGRect(origin: first, size: .zero)) { $0.union(CGRect(origin: $1, size: .zero)) }
    }

    // MARK: Drawing

    public static func draw(_ doc: AnnotationDoc, in ctx: CGContext, hiding hidden: Shape.ID? = nil) {
        for shape in doc.shapes where shape.id != hidden { draw(shape, in: ctx) }
    }

    public static func draw(_ shape: Shape, in ctx: CGContext) {
        ctx.saveGState()
        defer { ctx.restoreGState() }
        let color = cgColor(shape.color)
        // A soft shadow keeps strokes readable on light and dark captures alike.
        let shadow = { ctx.setShadow(offset: CGSize(width: 0, height: shape.lineWidth * 0.35), blur: shape.lineWidth * 1.2,
                                     color: CGColor(gray: 0, alpha: 0.35)) }
        switch shape.kind {
        case .rect:
            shadow()
            ctx.setStrokeColor(color)
            ctx.setLineWidth(shape.lineWidth)
            ctx.setLineJoin(.round)
            let r = shape.rect
            ctx.addPath(CGPath(roundedRect: r, cornerWidth: min(shape.lineWidth * 0.8, r.width / 2),
                               cornerHeight: min(shape.lineWidth * 0.8, r.height / 2), transform: nil))
            ctx.strokePath()
        case .highlight:
            ctx.setBlendMode(.multiply)
            ctx.setFillColor(color.copy(alpha: Style.highlightAlpha) ?? color)
            ctx.fill(shape.rect)
        case .arrow:
            guard shape.points.count >= 2 else { return }
            shadow()
            ctx.setStrokeColor(color)
            ctx.setFillColor(color)
            ctx.setLineWidth(shape.lineWidth)
            ctx.setLineCap(.round)
            ctx.setLineJoin(.round)
            let head = arrowHead(shape)
            // The shaft stops inside the head so its round cap doesn't poke through the tip.
            ctx.beginTransparencyLayer(auxiliaryInfo: nil)
            ctx.move(to: shape.points[0])
            ctx.addLine(to: CGPoint(x: (head[1].x + head[2].x) / 2, y: (head[1].y + head[2].y) / 2))
            ctx.strokePath()
            ctx.addLines(between: head)
            ctx.closePath()
            ctx.fillPath()
            ctx.endTransparencyLayer()
        case .freehand:
            guard !shape.points.isEmpty else { return }
            shadow()
            ctx.setStrokeColor(color)
            ctx.setLineWidth(shape.lineWidth)
            ctx.setLineCap(.round)
            ctx.setLineJoin(.round)
            ctx.addPath(freehandPath(shape.points))
            ctx.strokePath()
        case .text:
            let layout = textLayout(shape)
            ctx.setShadow(offset: CGSize(width: 0, height: 1), blur: 4, color: CGColor(gray: 0, alpha: 0.25))
            ctx.setFillColor(color)
            let radius = min(layout.padding, layout.box.height / 2)
            ctx.addPath(CGPath(roundedRect: layout.box, cornerWidth: radius, cornerHeight: radius, transform: nil))
            ctx.fillPath()
            ctx.setShadow(offset: .zero, blur: 0, color: nil)
            // CoreText draws y-up: flip around the text's own box.
            let textRect = layout.box.insetBy(dx: layout.padding, dy: layout.padding)
            ctx.translateBy(x: textRect.minX, y: textRect.maxY)
            ctx.scaleBy(x: 1, y: -1)
            ctx.textMatrix = .identity
            let frame = CTFramesetterCreateFrame(layout.framesetter, CFRange(), CGPath(rect: CGRect(origin: .zero, size: CGSize(width: textRect.width, height: textRect.height + 1)), transform: nil), nil)
            CTFrameDraw(frame, ctx)
        }
    }

    /// Tip, then the two back corners.
    public static func arrowHead(_ shape: Shape) -> [CGPoint] {
        guard shape.points.count >= 2 else { return [] }
        let tail = shape.points[0], tip = shape.points[1]
        let dx = tip.x - tail.x, dy = tip.y - tail.y
        let length = max(hypot(dx, dy), 0.001)
        let headLength = min(max(shape.lineWidth * 4.2, 14), length * 0.9)
        let halfWidth = headLength * 0.5
        let ux = dx / length, uy = dy / length
        let base = CGPoint(x: tip.x - ux * headLength, y: tip.y - uy * headLength)
        return [tip, CGPoint(x: base.x - uy * halfWidth, y: base.y + ux * halfWidth),
                CGPoint(x: base.x + uy * halfWidth, y: base.y - ux * halfWidth)]
    }

    /// A smooth curve through the stroke's points (quadratic segments through the midpoints).
    public static func freehandPath(_ points: [CGPoint]) -> CGPath {
        let path = CGMutablePath()
        guard let first = points.first else { return path }
        path.move(to: first)
        if points.count == 1 { path.addLine(to: first); return path }
        if points.count == 2 { path.addLine(to: points[1]); return path }
        for i in 1..<(points.count - 1) {
            let mid = CGPoint(x: (points[i].x + points[i + 1].x) / 2, y: (points[i].y + points[i + 1].y) / 2)
            path.addQuadCurve(to: mid, control: points[i])
        }
        path.addLine(to: points[points.count - 1])
        return path
    }

    // MARK: Flatten

    /// The image as it should be exported: cropped, with every shape drawn on it.
    public static func flatten(_ doc: AnnotationDoc, onto image: CGImage) -> CGImage? {
        let content = doc.contentRect.integral.intersection(CGRect(x: 0, y: 0, width: image.width, height: image.height))
        guard content.width >= 1, content.height >= 1,
              let ctx = CGContext(data: nil, width: Int(content.width), height: Int(content.height), bitsPerComponent: 8,
                                  bytesPerRow: 0, space: image.colorSpace ?? CGColorSpace(name: CGColorSpace.sRGB)!,
                                  bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)
        else { return nil }
        ctx.interpolationQuality = .high
        // y down, origin at the crop's top-left.
        ctx.translateBy(x: 0, y: content.height)
        ctx.scaleBy(x: 1, y: -1)
        ctx.translateBy(x: -content.minX, y: -content.minY)
        drawImage(image, in: ctx)
        draw(doc, in: ctx)
        return ctx.makeImage()
    }

    /// Draws `image` at its pixel size into a y-down context.
    public static func drawImage(_ image: CGImage, in ctx: CGContext, rect: CGRect? = nil) {
        let r = rect ?? CGRect(x: 0, y: 0, width: image.width, height: image.height)
        ctx.saveGState()
        ctx.translateBy(x: r.minX, y: r.maxY)
        ctx.scaleBy(x: 1, y: -1)
        ctx.draw(image, in: CGRect(origin: .zero, size: r.size))
        ctx.restoreGState()
    }

    // MARK: Color

    public static func cgColor(_ hex: String, alpha: Double = 1) -> CGColor {
        let (r, g, b) = rgb(hex)
        return CGColor(srgbRed: r, green: g, blue: b, alpha: alpha)
    }

    static func rgb(_ hex: String) -> (Double, Double, Double) {
        var s = hex.trimmingCharacters(in: .whitespaces)
        if s.hasPrefix("#") { s.removeFirst() }
        guard s.count >= 6, let v = UInt32(s.prefix(6), radix: 16) else { return (1, 0.23, 0.19) }
        return (Double((v >> 16) & 0xff) / 255, Double((v >> 8) & 0xff) / 255, Double(v & 0xff) / 255)
    }

    /// White on dark backgrounds, near-black on light ones.
    public static func textColor(on hex: String) -> CGColor {
        let (r, g, b) = rgb(hex)
        return 0.2126 * r + 0.7152 * g + 0.0722 * b > 0.62 ? CGColor(gray: 0.1, alpha: 1) : CGColor(gray: 1, alpha: 1)
    }
}
