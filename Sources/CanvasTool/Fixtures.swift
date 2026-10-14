import AVFoundation
import CanvasKit
import CoreGraphics
import CoreText
import Foundation

/// Synthetic recordings with known answers. Each clip scrolls a generated tall page inside a fixed
/// content box, so the true scroll position of every frame is known exactly. A barcode below the box
/// encodes the frame number, so a seek can be checked against the frame actually shown.
enum Fixtures {
    static let frameSize = (width: 1280, height: 800)
    static let box = PixelRect(x: 100, y: 80, width: 1000, height: 600)
    static let fps: Int32 = 15
    static let pageWidth = 1000

    // Page regions (page y): normal content, then repeated rows, then blank, then content again.
    static let repeatedRange = 3000..<4200
    static let repeatedPeriod = 40
    static let blankRange = 4200..<5100
    static let pageHeight = 6000
    /// The value that changes between page variants "A" and "B" sits here.
    static let editY = 900

    struct FrameSpec {
        var page: String = "A"
        var scrollY: Int = 0
        var header = false
        var cursor: CGPoint?
        var caret = false
    }

    struct Clip {
        var name: String
        var frames: [FrameSpec]
        var expect: Expectations
    }

    /// What a correct analysis of the clip must show. Absent fields are not checked.
    struct Expectations: Codable {
        /// Exact first frames of the cards, storyboard only.
        var cardStarts: [Int]?
        var cardCount: Int?
        /// Frames that must start an item (a change the canvas has to keep).
        var mustStartAt: [Int]?
        /// Joining: pairs of frames that must never end up in the same column.
        var neverJoined: [[Int]]?
        /// Joining: the most columns a correct join needs (one per continuous scroll).
        var maxColumns: Int?
        /// Joining: the clip has scrolling that a correct joiner must refuse (a jump, ambiguity).
        var mustRefuse: Bool?
    }

    struct Truth: Codable {
        var name: String
        var fps: Int
        var box: PixelRect
        var header: Int
        var pages: [String]
        var scrollY: [Int]
        var expect: Expectations
    }

    static let headerHeight = 70

    // MARK: Clips

    static func clips() -> [Clip] {
        var clips: [Clip] = []
        func hold(_ n: Int, _ s: FrameSpec) -> [FrameSpec] { Array(repeating: s, count: n) }
        func scroll(_ from: Int, _ to: Int, _ n: Int, _ base: FrameSpec = FrameSpec()) -> [FrameSpec] {
            (0..<n).map { i in
                var s = base
                let t = Double(i + 1) / Double(n)
                let eased = t < 0.5 ? 2 * t * t : 1 - pow(-2 * t + 2, 2) / 2
                s.scrollY = from + Int((Double(to - from) * eased).rounded())
                return s
            }
        }

        // Three different screens with hard cuts; a caret blinks on the second.
        var changes: [FrameSpec] = hold(30, FrameSpec(page: "P1"))
        changes += (0..<30).map { i in FrameSpec(page: "P2", caret: (i / 7) % 2 == 0) }
        changes += hold(30, FrameSpec(page: "P3"))
        clips.append(Clip(name: "changes", frames: changes, expect: Expectations(cardStarts: [0, 30, 60])))

        // A pointer wanders over a still page.
        let cursor = (0..<60).map { i -> FrameSpec in
            let a = Double(i) / 60 * 2 * .pi
            return FrameSpec(page: "P1", cursor: CGPoint(x: 600 + 220 * cos(a), y: 380 + 160 * sin(a)))
        }
        clips.append(Clip(name: "cursor", frames: cursor, expect: Expectations(cardCount: 1)))

        // Scroll, an edit while still, then more scrolling on the edited page.
        var edit = scroll(0, 600, 15)
        edit += hold(15, FrameSpec(page: "A", scrollY: 600))
        let editFrame = edit.count
        edit += hold(15, FrameSpec(page: "B", scrollY: 600))
        edit += scroll(600, 1500, 22, FrameSpec(page: "B"))
        edit += hold(8, FrameSpec(page: "B", scrollY: 1500))
        clips.append(Clip(name: "edit", frames: edit, expect: Expectations(
            mustStartAt: [editFrame], neverJoined: [[editFrame - 1, editFrame]], maxColumns: 2)))

        var plain = hold(8, FrameSpec())
        plain += scroll(0, 2400, 60)
        plain += hold(8, FrameSpec(scrollY: 2400))
        clips.append(Clip(name: "scroll", frames: plain, expect: Expectations(maxColumns: 1)))

        var reversal = scroll(0, 1800, 30)
        reversal += scroll(1800, 900, 15)
        reversal += scroll(900, 2400, 30)
        clips.append(Clip(name: "reversal", frames: reversal, expect: Expectations(maxColumns: 1)))

        var jump = scroll(0, 900, 22)
        jump += hold(8, FrameSpec(scrollY: 900))
        let jumpFrame = jump.count
        jump += hold(8, FrameSpec(scrollY: 2000))
        jump += scroll(2000, 2400, 15)
        clips.append(Clip(name: "jump", frames: jump, expect: Expectations(
            mustStartAt: [jumpFrame], neverJoined: [[jumpFrame - 1, jumpFrame]], maxColumns: 2, mustRefuse: true)))

        var header = hold(5, FrameSpec(header: true))
        header += scroll(0, 2000, 45, FrameSpec(header: true))
        clips.append(Clip(name: "header", frames: header, expect: Expectations(maxColumns: 1)))

        var cursorScroll = scroll(0, 1500, 45)
        for i in cursorScroll.indices {
            cursorScroll[i].cursor = CGPoint(x: 400 + Double(i) * 9, y: 300 + 80 * sin(Double(i) / 6))
        }
        clips.append(Clip(name: "cursor-scroll", frames: cursorScroll, expect: Expectations(maxColumns: 1)))

        // 25 px a frame through rows that repeat every 40 px: several distances fit equally well.
        let repStart = repeatedRange.lowerBound - 300
        var repeated = hold(5, FrameSpec(scrollY: repStart))
        repeated += (1...56).map { FrameSpec(scrollY: repStart + 25 * $0) }
        repeated += hold(5, FrameSpec(scrollY: repStart + 25 * 56))
        clips.append(Clip(name: "repeated", frames: repeated, expect: Expectations(mustRefuse: true)))

        var blank = scroll(blankRange.lowerBound - 500, blankRange.upperBound + 300, 50)
        blank += hold(5, FrameSpec(scrollY: blankRange.upperBound + 300))
        clips.append(Clip(name: "blank", frames: blank, expect: Expectations(mustRefuse: true)))

        return clips
    }

    // MARK: Writing

    static func write(to root: URL, only: Set<String>? = nil) async throws {
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        var pages: [String: CGImage] = [:]
        for clip in clips() where only?.contains(clip.name) ?? true {
            for spec in clip.frames where pages[spec.page] == nil { pages[spec.page] = renderPage(spec.page) }
            let folder = root.appendingPathComponent(clip.name, isDirectory: true)
            try? FileManager.default.removeItem(at: folder)
            try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
            try await encode(clip, pages: pages, to: folder.appendingPathComponent("recording.mp4"))
            let truth = Truth(name: clip.name, fps: Int(fps), box: box, header: clip.frames.contains(where: \.header) ? headerHeight : 0,
                              pages: clip.frames.map(\.page), scrollY: clip.frames.map(\.scrollY), expect: clip.expect)
            let enc = JSONEncoder()
            enc.outputFormatting = [.prettyPrinted, .sortedKeys]
            try enc.encode(truth).write(to: folder.appendingPathComponent("truth.json"))
            print("  \(clip.name): \(clip.frames.count) frames")
        }
    }

    private static func encode(_ clip: Clip, pages: [String: CGImage], to url: URL) async throws {
        let writer = try AVAssetWriter(outputURL: url, fileType: .mp4)
        // Same codec and bitrate as the recorder.
        let input = AVAssetWriterInput(mediaType: .video, outputSettings: [
            AVVideoCodecKey: AVVideoCodecType.h264,
            AVVideoWidthKey: frameSize.width,
            AVVideoHeightKey: frameSize.height,
            AVVideoCompressionPropertiesKey: [AVVideoAverageBitRateKey: 4_000_000],
        ])
        input.expectsMediaDataInRealTime = false
        let adaptor = AVAssetWriterInputPixelBufferAdaptor(assetWriterInput: input, sourcePixelBufferAttributes: [
            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA,
            kCVPixelBufferWidthKey as String: frameSize.width,
            kCVPixelBufferHeightKey as String: frameSize.height,
        ])
        writer.add(input)
        guard writer.startWriting() else { throw CanvasError(writer.error?.localizedDescription ?? "Can't write \(url.path)") }
        writer.startSession(atSourceTime: .zero)
        for (i, spec) in clip.frames.enumerated() {
            while !input.isReadyForMoreMediaData { try await Task.sleep(for: .milliseconds(2)) }
            guard let pool = adaptor.pixelBufferPool else { throw CanvasError("No pixel buffer pool") }
            var pb: CVPixelBuffer?
            CVPixelBufferPoolCreatePixelBuffer(nil, pool, &pb)
            guard let pb else { throw CanvasError("No pixel buffer") }
            draw(spec, index: i, pages: pages, into: pb)
            guard adaptor.append(pb, withPresentationTime: CMTime(value: CMTimeValue(i), timescale: fps)) else {
                throw CanvasError(writer.error?.localizedDescription ?? "Couldn't append frame \(i)")
            }
        }
        input.markAsFinished()
        await writer.finishWriting()
        if writer.status != .completed { throw CanvasError(writer.error?.localizedDescription ?? "Writing failed") }
    }

    /// Converts a top-left rect to Core Graphics' bottom-left space for a context `height` tall.
    private static func cg(_ r: CGRect, _ height: Int) -> CGRect {
        CGRect(x: r.minX, y: CGFloat(height) - r.maxY, width: r.width, height: r.height)
    }

    private static func draw(_ spec: FrameSpec, index: Int, pages: [String: CGImage], into pb: CVPixelBuffer) {
        CVPixelBufferLockBaseAddress(pb, [])
        defer { CVPixelBufferUnlockBaseAddress(pb, []) }
        let W = frameSize.width, H = frameSize.height
        guard let ctx = CGContext(data: CVPixelBufferGetBaseAddress(pb), width: W, height: H, bitsPerComponent: 8,
                                  bytesPerRow: CVPixelBufferGetBytesPerRow(pb), space: CGColorSpace(name: CGColorSpace.sRGB)!,
                                  bitmapInfo: CGImageAlphaInfo.noneSkipFirst.rawValue | CGBitmapInfo.byteOrder32Little.rawValue)
        else { return }
        // Window chrome around the content box: stays still, so it must not matter.
        ctx.setFillColor(gray: 0.86, alpha: 1)
        ctx.fill(CGRect(x: 0, y: 0, width: W, height: H))
        ctx.setFillColor(gray: 0.25, alpha: 1)
        ctx.fill(cg(CGRect(x: 0, y: 0, width: W, height: 56), H))
        text("Browser — fixture", at: CGPoint(x: 24, y: 36), size: 18, color: CGColor(gray: 0.95, alpha: 1), in: ctx, height: H)

        if let page = pages[spec.page] {
            let crop = CGRect(x: 0, y: spec.scrollY, width: box.width, height: box.height)
            if let part = page.cropping(to: crop) { ctx.draw(part, in: cg(box.cgRect, H)) }
        }
        if spec.header {
            ctx.setFillColor(red: 0.12, green: 0.2, blue: 0.4, alpha: 1)
            ctx.fill(cg(CGRect(x: box.x, y: box.y, width: box.width, height: headerHeight), H))
            text("Fixed header · Dashboard · Reports · Settings", at: CGPoint(x: box.x + 24, y: box.y + 44), size: 20,
                 color: CGColor(gray: 1, alpha: 1), in: ctx, height: H)
        }
        if spec.caret {
            ctx.setFillColor(gray: 0, alpha: 1)
            ctx.fill(cg(CGRect(x: box.x + 420, y: box.y + 200, width: 2, height: 18), H))
        }
        if let p = spec.cursor {
            let path = CGMutablePath()
            let pts = [CGPoint(x: 0, y: 0), CGPoint(x: 0, y: 19), CGPoint(x: 5, y: 15), CGPoint(x: 9, y: 23),
                       CGPoint(x: 12, y: 22), CGPoint(x: 8, y: 14), CGPoint(x: 14, y: 14)]
            path.addLines(between: pts.map { CGPoint(x: p.x + $0.x, y: CGFloat(H) - (p.y + $0.y)) })
            path.closeSubpath()
            ctx.addPath(path); ctx.setFillColor(gray: 0, alpha: 1); ctx.fillPath()
            ctx.addPath(path); ctx.setStrokeColor(gray: 1, alpha: 1); ctx.setLineWidth(1.5); ctx.strokePath()
        }
        // Frame number, 16 bits, least significant first, below the box.
        ctx.setFillColor(gray: 1, alpha: 1)
        ctx.fill(cg(CGRect(x: 0, y: barcodeY - 14, width: W, height: 56), H))
        for bit in 0..<16 where index & (1 << bit) != 0 {
            ctx.setFillColor(gray: 0, alpha: 1)
            ctx.fill(cg(CGRect(x: barcodeX + bit * barcodeStep, y: barcodeY, width: 28, height: 28), H))
        }
    }

    static let barcodeX = 100, barcodeY = 726, barcodeStep = 40

    /// Reads the frame number back from a decoded frame (top-left origin pixels).
    static func readBarcode(_ image: CGImage) -> Int? {
        let W = image.width, H = image.height
        var pixels = [UInt8](repeating: 0, count: W * H)
        guard let ctx = CGContext(data: &pixels, width: W, height: H, bitsPerComponent: 8, bytesPerRow: W,
                                  space: CGColorSpaceCreateDeviceGray(), bitmapInfo: CGImageAlphaInfo.none.rawValue) else { return nil }
        ctx.draw(image, in: CGRect(x: 0, y: 0, width: W, height: H))
        var value = 0
        for bit in 0..<16 {
            let x = barcodeX + bit * barcodeStep + 14, y = barcodeY + 14
            if pixels[y * W + x] < 128 { value |= 1 << bit }
        }
        return value
    }

    // MARK: Pages

    /// A tall page. Variant "B" is "A" with one value changed; "P1"… are unrelated screens.
    static func renderPage(_ variant: String) -> CGImage {
        let W = pageWidth
        let H = variant.hasPrefix("P") ? box.height : pageHeight
        let ctx = CGContext(data: nil, width: W, height: H, bitsPerComponent: 8, bytesPerRow: W * 4,
                            space: CGColorSpace(name: CGColorSpace.sRGB)!,
                            bitmapInfo: CGImageAlphaInfo.noneSkipFirst.rawValue | CGBitmapInfo.byteOrder32Little.rawValue)!
        ctx.setFillColor(gray: 1, alpha: 1)
        ctx.fill(CGRect(x: 0, y: 0, width: W, height: H))
        // "A" and "B" share a seed so they differ only in the edited value.
        var rng = SplitMix(seed: variant.hasPrefix("P") ? variant.utf8.reduce(UInt64(14_695_981_039_346_656_037)) { ($0 ^ UInt64($1)) &* 1_099_511_628_211 } : 7)
        let ink = CGColor(gray: 0.1, alpha: 1), muted = CGColor(gray: 0.4, alpha: 1)

        func fill(_ r: CGRect, _ c: CGColor) { ctx.setFillColor(c); ctx.fill(cg(r, H)) }
        func words(_ n: Int) -> String { (0..<n).map { _ in vocabulary[Int(rng.next() % UInt64(vocabulary.count))] }.joined(separator: " ") }

        var y = 30
        var section = 1
        func contentBlock(until limit: Int) {
            while y < limit - 220 {
                text("\(section). \(words(3).capitalized)", at: CGPoint(x: 40, y: y + 30), size: 26, color: ink, in: ctx, height: H, bold: true)
                y += 54
                for _ in 0..<(4 + Int(rng.next() % 5)) where y < limit - 40 {
                    text(words(9 + Int(rng.next() % 5)), at: CGPoint(x: 40, y: y + 18), size: 16, color: muted, in: ctx, height: H)
                    y += 26
                }
                if rng.next() % 2 == 0, y < limit - 140 {
                    let hue = CGFloat(rng.next() % 100) / 100
                    for c in 0..<3 {
                        let r = CGRect(x: 40 + c * 310, y: y + 10, width: 290, height: 100)
                        fill(r, CGColor(red: 0.6 + 0.4 * hue, green: 0.75, blue: 0.95 - 0.3 * hue * CGFloat(c) / 2, alpha: 1))
                        text("\(words(2)) \(Int(rng.next() % 9000) + 100)", at: CGPoint(x: Int(r.minX) + 14, y: Int(r.minY) + 56),
                             size: 18, color: ink, in: ctx, height: H, bold: true)
                    }
                    y += 130
                }
                y += 24
                section += 1
            }
            y = limit
        }

        if variant.hasPrefix("P") {
            fill(CGRect(x: 0, y: 0, width: W, height: 90), CGColor(red: 0.2, green: 0.35 + CGFloat(rng.next() % 50) / 100, blue: 0.5, alpha: 1))
            text("Screen \(variant.dropFirst()) — \(words(2).capitalized)", at: CGPoint(x: 40, y: 58), size: 30,
                 color: CGColor(gray: 1, alpha: 1), in: ctx, height: H, bold: true)
            y = 120
            contentBlock(until: H)
            return ctx.makeImage()!
        }

        contentBlock(until: editY - 20)
        // The edited value.
        fill(CGRect(x: 40, y: editY - 10, width: 920, height: 60), CGColor(gray: 0.95, alpha: 1))
        text(variant == "B" ? "Total due: $9,870.15  · updated" : "Total due: $1,240.00", at: CGPoint(x: 60, y: editY + 28),
             size: 24, color: variant == "B" ? CGColor(red: 0.7, green: 0.1, blue: 0.1, alpha: 1) : ink, in: ctx, height: H, bold: true)
        y = editY + 70
        contentBlock(until: repeatedRange.lowerBound)
        var r = repeatedRange.lowerBound
        while r < repeatedRange.upperBound {
            fill(CGRect(x: 40, y: r + repeatedPeriod - 2, width: 920, height: 1), CGColor(gray: 0.8, alpha: 1))
            text("Line item   ·   Qty 1   ·   $10.00", at: CGPoint(x: 60, y: r + 26), size: 16, color: ink, in: ctx, height: H)
            r += repeatedPeriod
        }
        y = blankRange.upperBound + 20
        contentBlock(until: pageHeight)
        return ctx.makeImage()!
    }

    static func text(_ s: String, at p: CGPoint, size: CGFloat, color: CGColor, in ctx: CGContext, height: Int, bold: Bool = false) {
        let font = CTFontCreateWithName((bold ? "Helvetica-Bold" : "Helvetica") as CFString, size, nil)
        let attr = NSAttributedString(string: s, attributes: [
            NSAttributedString.Key(kCTFontAttributeName as String): font,
            NSAttributedString.Key(kCTForegroundColorAttributeName as String): color,
        ])
        let line = CTLineCreateWithAttributedString(attr)
        ctx.textPosition = CGPoint(x: p.x, y: CGFloat(height) - p.y)
        CTLineDraw(line, ctx)
    }

    static let vocabulary = """
    revenue pipeline account review forecast region quarter target margin growth churn cohort ledger invoice \
    shipment vendor capacity backlog roadmap release metric signal latency budget variance onboarding renewal \
    workspace project milestone approval estimate contract support escalation summary insight trend baseline
    """.split(separator: " ").map(String.init)
}

struct SplitMix {
    var state: UInt64
    init(seed: UInt64) { state = seed }
    mutating func next() -> UInt64 {
        state &+= 0x9E37_79B9_7F4A_7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
        z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
        return z ^ (z >> 31)
    }
}
