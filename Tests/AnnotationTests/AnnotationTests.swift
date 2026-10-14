import CoreGraphics
import Testing
@testable import Annotation

private let size = CGSize(width: 400, height: 300)

private func rect(_ x: Double, _ y: Double, _ w: Double, _ h: Double, kind: Shape.Kind = .rect, color: String = "#FF0000") -> Shape {
    Shape(kind: kind, color: color, lineWidth: 6, points: [CGPoint(x: x, y: y), CGPoint(x: x + w, y: y + h)])
}

@Suite struct ModelTests {
    @Test func roundTripsThroughJSON() throws {
        var doc = AnnotationDoc(imageSize: size, crop: CGRect(x: 10, y: 20, width: 300, height: 200))
        doc.shapes = [rect(10, 10, 50, 40),
                      Shape(kind: .text, color: "#0A84FF", lineWidth: 4, points: [CGPoint(x: 5, y: 6)], text: "Hi\nthere", fontSize: 20, wrapWidth: 120)]
        #expect(try AnnotationDoc.decoded(from: doc.encoded()) == doc)
    }

    @Test func emptyMeansUntouched() {
        var doc = AnnotationDoc(imageSize: size)
        #expect(doc.isEmpty)
        doc.crop = CGRect(x: 0, y: 0, width: 10, height: 10)
        #expect(!doc.isEmpty)
        #expect(doc.contentRect == CGRect(x: 0, y: 0, width: 10, height: 10))
    }

    @Test func subscriptReplacesAndRemoves() {
        let a = rect(0, 0, 10, 10)
        var doc = AnnotationDoc(imageSize: size, shapes: [a])
        var moved = a
        moved.color = "#00FF00"
        doc[a.id] = moved
        #expect(doc.shapes.first?.color == "#00FF00")
        doc[a.id] = nil
        #expect(doc.shapes.isEmpty)
    }

    @Test func defaultsScaleWithTheImage() {
        #expect(Style.lineWidth(for: CGSize(width: 200, height: 100)) == 3)
        #expect(Style.lineWidth(for: CGSize(width: 1920, height: 1080)) == 6)
        #expect(Style.fontSize(for: CGSize(width: 1920, height: 1080)) == 1920.0 / 36)
    }
}

@Suite struct HitTests {
    @Test func rectangleOutlineHitsButItsMiddleDoesNot() {
        let r = rect(100, 100, 100, 80)
        let doc = AnnotationDoc(imageSize: size, shapes: [r])
        #expect(Geometry.hit(doc, at: CGPoint(x: 100, y: 140), tolerance: 3) == r.id)
        #expect(Geometry.hit(doc, at: CGPoint(x: 150, y: 140), tolerance: 3) == nil)
        // Once selected, the whole box is a move target.
        #expect(Geometry.hit(doc, at: CGPoint(x: 150, y: 140), tolerance: 3, selected: r.id) == r.id)
    }

    @Test func topmostShapeWins() {
        let below = rect(0, 0, 200, 200, kind: .highlight)
        let above = rect(50, 50, 50, 50, kind: .highlight)
        let doc = AnnotationDoc(imageSize: size, shapes: [below, above])
        #expect(Geometry.hit(doc, at: CGPoint(x: 70, y: 70), tolerance: 0) == above.id)
        #expect(Geometry.hit(doc, at: CGPoint(x: 10, y: 10), tolerance: 0) == below.id)
    }

    @Test func kindFilterLimitsDrawingTools() {
        let box = rect(0, 0, 100, 100)
        let doc = AnnotationDoc(imageSize: size, shapes: [box])
        #expect(Geometry.hit(doc, at: CGPoint(x: 0, y: 50), tolerance: 3, kinds: [.arrow]) == nil)
        #expect(Geometry.hit(doc, at: CGPoint(x: 0, y: 50), tolerance: 3, kinds: [.rect]) == box.id)
    }

    @Test func arrowHitsAlongItsShaft() {
        let arrow = Shape(kind: .arrow, color: "#FF0000", lineWidth: 4, points: [CGPoint(x: 0, y: 0), CGPoint(x: 100, y: 100)])
        #expect(Geometry.contains(arrow, CGPoint(x: 52, y: 48), tolerance: 2))
        #expect(!Geometry.contains(arrow, CGPoint(x: 80, y: 20), tolerance: 2))
    }

    @Test func freehandHitsNearTheStroke() {
        let stroke = Shape(kind: .freehand, color: "#FF0000", lineWidth: 4,
                           points: [CGPoint(x: 0, y: 0), CGPoint(x: 50, y: 0), CGPoint(x: 100, y: 0)])
        #expect(Geometry.contains(stroke, CGPoint(x: 75, y: 3), tolerance: 2))
        #expect(!Geometry.contains(stroke, CGPoint(x: 75, y: 30), tolerance: 2))
    }

    @Test func distanceToSegmentClampsToTheEnds() {
        #expect(Geometry.distance(CGPoint(x: -3, y: 4), segment: .zero, CGPoint(x: 10, y: 0)) == 5)
        #expect(Geometry.distance(CGPoint(x: 5, y: 2), segment: .zero, CGPoint(x: 10, y: 0)) == 2)
    }
}

@Suite struct EditTests {
    @Test func cornerHandleResizesAndFlipsPastTheOppositeSide() {
        let r = rect(100, 100, 100, 100)
        let bigger = Geometry.resized(r, handle: .frame(x: 1, y: 1), to: CGPoint(x: 250, y: 260))
        #expect(bigger.rect == CGRect(x: 100, y: 100, width: 150, height: 160))
        let flipped = Geometry.resized(r, handle: .frame(x: 1, y: 0), to: CGPoint(x: 60, y: 999))
        #expect(flipped.rect == CGRect(x: 60, y: 100, width: 40, height: 100))
    }

    @Test func edgeHandleMovesOneSideOnly() {
        let r = rect(100, 100, 100, 100)
        let taller = Geometry.resized(r, handle: .frame(x: 0, y: -1), to: CGPoint(x: 0, y: 40))
        #expect(taller.rect == CGRect(x: 100, y: 40, width: 100, height: 160))
    }

    @Test func handleLookupFindsTheNearestWithinTolerance() {
        let r = rect(100, 100, 100, 100)
        #expect(Geometry.handle(of: r, at: CGPoint(x: 198, y: 201), tolerance: 5) == .frame(x: 1, y: 1))
        #expect(Geometry.handle(of: r, at: CGPoint(x: 150, y: 150), tolerance: 5) == nil)
    }

    @Test func arrowEndsMoveIndependently() {
        let arrow = Shape(kind: .arrow, color: "#FF0000", lineWidth: 4, points: [.zero, CGPoint(x: 10, y: 10)])
        #expect(Geometry.resized(arrow, handle: .tip, to: CGPoint(x: 50, y: 5)).points == [.zero, CGPoint(x: 50, y: 5)])
        #expect(Geometry.resized(arrow, handle: .tail, to: CGPoint(x: 1, y: 2)).points == [CGPoint(x: 1, y: 2), CGPoint(x: 10, y: 10)])
    }

    @Test func textWrapHandleChangesWidthNotFontSize() {
        let text = Shape(kind: .text, color: "#000000", lineWidth: 4, points: [CGPoint(x: 10, y: 10)],
                         text: "A longer note that will wrap", fontSize: 20)
        let narrow = Geometry.resized(text, handle: .wrap(edge: 1), to: CGPoint(x: 150, y: 0))
        #expect(narrow.fontSize == 20)
        #expect(narrow.wrapWidth == 150 - 10 - Style.textPadding(fontSize: 20) * 2)
        #expect(Renderer.bounds(narrow).height > Renderer.bounds(text).height)
    }

    @Test func moveShiftsEveryPoint() {
        let r = Geometry.moved(rect(0, 0, 10, 10), by: CGSize(width: 5, height: -2))
        #expect(r.points == [CGPoint(x: 5, y: -2), CGPoint(x: 15, y: 8)])
    }

    @Test func smoothingKeepsTheEndsAndDropsJitter() {
        let raw = (0...40).map { CGPoint(x: Double($0), y: $0 % 2 == 0 ? 0 : 0.4) }
        let smooth = Geometry.smoothed(raw, minDistance: 3)
        #expect(smooth.first == raw.first)
        #expect(smooth.last == raw.last)
        #expect(smooth.allSatisfy { abs($0.y) <= 0.4 })
    }

    @Test func historyUndoesAndRedoesInOrder() {
        var h = History<Int>()
        var value = 0
        for next in 1...3 { h.record(value); value = next }
        value = h.undo(value)!
        #expect(value == 2)
        value = h.undo(value)!
        #expect(value == 1)
        value = h.redo(value)!
        #expect(value == 2)
        // A new edit clears redo.
        h.record(value); value = 9
        #expect(!h.canRedo)
        #expect(h.undo(value) == 2)
    }
}

@Suite struct RenderTests {
    /// A solid white image of `size`.
    private func white(_ size: CGSize) -> CGImage {
        let ctx = CGContext(data: nil, width: Int(size.width), height: Int(size.height), bitsPerComponent: 8, bytesPerRow: 0,
                            space: CGColorSpace(name: CGColorSpace.sRGB)!, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
        ctx.setFillColor(CGColor(gray: 1, alpha: 1))
        ctx.fill(CGRect(origin: .zero, size: size))
        return ctx.makeImage()!
    }

    /// RGBA of the pixel at (x, y), y measured from the top.
    private func pixel(_ image: CGImage, _ x: Int, _ y: Int) -> (Int, Int, Int) {
        let ctx = CGContext(data: nil, width: image.width, height: image.height, bitsPerComponent: 8, bytesPerRow: image.width * 4,
                            space: CGColorSpace(name: CGColorSpace.sRGB)!, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
        ctx.draw(image, in: CGRect(x: 0, y: 0, width: image.width, height: image.height))
        let data = ctx.data!.assumingMemoryBound(to: UInt8.self)
        // Bitmap memory starts at the top row.
        let i = (y * image.width + x) * 4
        return (Int(data[i]), Int(data[i + 1]), Int(data[i + 2]))
    }

    @Test func flattenDrawsShapesWhereTheyAreWithYDown() throws {
        let doc = AnnotationDoc(imageSize: size, shapes: [rect(20, 30, 100, 60, kind: .highlight, color: "#0000FF")])
        let out = try #require(Renderer.flatten(doc, onto: white(size)))
        #expect(out.width == 400 && out.height == 300)
        let inside = pixel(out, 50, 50), outside = pixel(out, 300, 250), below = pixel(out, 50, 150)
        #expect(inside.2 > 200 && inside.0 < 200)      // blue multiplied over white
        #expect(outside == (255, 255, 255))
        #expect(below == (255, 255, 255))              // y is down: nothing at y 150
    }

    @Test func flattenCropsToTheKeptArea() throws {
        let doc = AnnotationDoc(imageSize: size, crop: CGRect(x: 100, y: 50, width: 120, height: 80),
                                shapes: [rect(100, 50, 20, 20, kind: .highlight, color: "#FF0000")])
        let out = try #require(Renderer.flatten(doc, onto: white(size)))
        #expect(out.width == 120 && out.height == 80)
        let corner = pixel(out, 5, 5)
        #expect(corner.0 > 200 && corner.1 < 200)      // the highlight at the crop's top-left
        #expect(pixel(out, 100, 70) == (255, 255, 255))
    }

    @Test func rectangleStrokesItsOutline() throws {
        let doc = AnnotationDoc(imageSize: size, shapes: [rect(50, 50, 200, 150, color: "#FF0000")])
        let out = try #require(Renderer.flatten(doc, onto: white(size)))
        let edge = pixel(out, 50, 120), middle = pixel(out, 150, 120)
        #expect(edge.0 > 200 && edge.1 < 80)
        #expect(middle == (255, 255, 255))
    }

    @Test func textGetsABackgroundBoxAtItsPoint() throws {
        let text = Shape(kind: .text, color: "#1C1C1E", lineWidth: 4, points: [CGPoint(x: 40, y: 40)], text: "Note", fontSize: 24)
        let box = Renderer.bounds(text)
        #expect(box.minX == 40 && box.minY == 40)
        #expect(box.width > 40 && box.height > 24)
        let out = try #require(Renderer.flatten(AnnotationDoc(imageSize: size, shapes: [text]), onto: white(size)))
        let p = pixel(out, Int(box.minX) + 3, Int(box.midY))
        #expect(p.0 < 60)                              // dark background in the box's left padding
        #expect(pixel(out, Int(box.maxX) + 4, Int(box.midY)) == (255, 255, 255))
    }

    @Test func textColorContrastsWithItsBackground() {
        #expect(Renderer.textColor(on: "#FFD60A").components?.first ?? 1 < 0.5)
        #expect(Renderer.textColor(on: "#1C1C1E").components?.first ?? 0 > 0.5)
    }
}
