import AVFoundation
import CanvasKit
import CoreGraphics
import CoreText
import Foundation

/// Synthetic recordings with known answers. Each clip scrolls a generated tall page inside a document area on
/// a simulated screen, so the true scroll position of every frame is known exactly. The analyzer gets the whole
/// screen and has to find the document itself. A barcode in a band below the screen encodes the frame number,
/// so a seek can be checked against the frame actually shown; it is test instrumentation, not screen content.
enum Fixtures {
    static let screenSize = (width: 1280, height: 800)
    static let screen = PixelRect(x: 0, y: 0, width: screenSize.width, height: screenSize.height)
    static let frameSize = (width: screenSize.width, height: screenSize.height + 56)
    /// The document area of the windowed layout.
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
    /// Variant "S" is "A" with a checkbox ticked and one digit changed on this row: a small edit.
    static let smallEditY = 1300

    /// Where the page sits on screen.
    enum Layout: String, Codable {
        /// A plain window: gray margins and a title bar around a 1000×600 document.
        case window
        /// A maximized browser like the real recordings: menu bar, tabs and toolbar, a sticky site header, a
        /// detailed left nav, a right "On this page" rail whose highlight follows the scroll, a scrollbar, the Dock.
        case desktop
        /// The same desktop with wide sidebars around a narrow document.
        case narrow

        var document: PixelRect {
            switch self {
            case .window: Fixtures.box
            case .desktop: PixelRect(x: 230, y: 148, width: 800, height: 592)
            case .narrow: PixelRect(x: 440, y: 148, width: 400, height: 592)
            }
        }

        /// Stationary detail beside the document that a column must leave out: the nav's items and the rail's
        /// highlight, headings and card. Their blank margins look like the page's and may go either way.
        var fixed: [PixelRect] {
            let d = document
            switch self {
            case .window: return []
            case .desktop, .narrow:
                return [PixelRect(x: 16, y: d.y, width: d.x - 32, height: d.height),
                        PixelRect(x: d.maxX + 20, y: d.y, width: Fixtures.screenSize.width - d.maxX - 20, height: d.height)]
            }
        }
    }

    struct FrameSpec {
        var page: String = "A"
        var scrollY: Int = 0
        var header = false
        var cursor: CGPoint?
        var caret = false
        var layout: Layout = .window
        /// The menu bar clock has ticked over (desktop layouts).
        var minute = 0
        /// Desktop layouts: how far past `scrollY` the page sits, in fractions of a pixel (slow trackpad scrolling).
        var fraction = 0.0
        /// Desktop layouts: a dropdown menu open over the page.
        var overlay = false
        /// Desktop layouts: the count on a badge in the sticky site header.
        var badge = 3
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
        /// Joining: at least this share of the observed document area must appear, correctly placed, in columns.
        /// Cards don't count: a canvas of screenshots hasn't reconstructed anything.
        var minCoverage: Double?
        /// Changes the canvas must keep as local events.
        var events: [EventExpectation]?
        /// The clip has only pointer, caret and chrome noise: no edit events.
        var noEdits: Bool?
    }

    /// An edit or overlay the canvas must record: its kind, the page rows it covers, and the frames it may
    /// start within (its first visible frame, give or take the settle time).
    struct EventExpectation: Codable {
        var kind: String
        var pageRows: [Int]
        var startFrames: [Int]
    }

    struct Truth: Codable {
        var name: String
        var fps: Int
        /// What the analyzer gets: the whole simulated screen.
        var screen: PixelRect
        /// Where the page scrolls on screen. Never given to the analyzer.
        var box: PixelRect
        /// Stationary detail beside the document (sidebars, a rail).
        var fixed: [PixelRect]
        var header: Int
        var pages: [String]
        var scrollY: [Int]
        /// Sub-pixel part of each frame's scroll position (slow scrolling).
        var scrollFraction: [Double]?
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
        clips.append(Clip(name: "cursor", frames: cursor, expect: Expectations(cardCount: 1, noEdits: true)))

        // Scroll, an edit while still, then more scrolling on the edited page.
        var edit = scroll(0, 600, 15)
        edit += hold(15, FrameSpec(page: "A", scrollY: 600))
        let editFrame = edit.count
        edit += hold(15, FrameSpec(page: "B", scrollY: 600))
        edit += scroll(600, 1500, 22, FrameSpec(page: "B"))
        edit += hold(8, FrameSpec(page: "B", scrollY: 1500))
        clips.append(Clip(name: "edit", frames: edit, expect: Expectations(
            maxColumns: 2,
            events: [EventExpectation(kind: "edit", pageRows: [editY - 10, editY + 50], startFrames: [editFrame, editFrame + 10])])))

        var plain = hold(8, FrameSpec())
        plain += scroll(0, 2400, 60)
        plain += hold(8, FrameSpec(scrollY: 2400))
        clips.append(Clip(name: "scroll", frames: plain, expect: Expectations(maxColumns: 1, minCoverage: 0.9)))

        var reversal = scroll(0, 1800, 30)
        reversal += scroll(1800, 900, 15)
        reversal += scroll(900, 2400, 30)
        clips.append(Clip(name: "reversal", frames: reversal, expect: Expectations(maxColumns: 1, minCoverage: 0.9)))

        var jump = scroll(0, 900, 22)
        jump += hold(8, FrameSpec(scrollY: 900))
        let jumpFrame = jump.count
        jump += hold(8, FrameSpec(scrollY: 2000))
        jump += scroll(2000, 2400, 15)
        clips.append(Clip(name: "jump", frames: jump, expect: Expectations(
            mustStartAt: [jumpFrame], neverJoined: [[jumpFrame - 1, jumpFrame]], maxColumns: 2, mustRefuse: true, minCoverage: 0.9)))

        var header = hold(5, FrameSpec(header: true))
        header += scroll(0, 2000, 45, FrameSpec(header: true))
        clips.append(Clip(name: "header", frames: header, expect: Expectations(maxColumns: 1, minCoverage: 0.9)))

        var cursorScroll = scroll(0, 1500, 45)
        for i in cursorScroll.indices {
            cursorScroll[i].cursor = CGPoint(x: 400 + Double(i) * 9, y: 300 + 80 * sin(Double(i) / 6))
        }
        clips.append(Clip(name: "cursor-scroll", frames: cursorScroll, expect: Expectations(maxColumns: 1, minCoverage: 0.9, noEdits: true)))

        // 25 px a frame through rows that repeat every 40 px: several distances fit equally well.
        let repStart = repeatedRange.lowerBound - 300
        var repeated = hold(5, FrameSpec(scrollY: repStart))
        repeated += (1...56).map { FrameSpec(scrollY: repStart + 25 * $0) }
        repeated += hold(5, FrameSpec(scrollY: repStart + 25 * 56))
        clips.append(Clip(name: "repeated", frames: repeated, expect: Expectations(mustRefuse: true)))

        var blank = scroll(blankRange.lowerBound - 500, blankRange.upperBound + 300, 50)
        blank += hold(5, FrameSpec(scrollY: blankRange.upperBound + 300))
        clips.append(Clip(name: "blank", frames: blank, expect: Expectations(mustRefuse: true)))

        // A maximized browser: the analyzer has to find the page between a nav and a rail, under chrome, while
        // the pointer drifts over the page, the rail highlight follows the scroll and the clock ticks.
        for (name, layout) in [("desktop", Layout.desktop), ("desktop-narrow", Layout.narrow)] {
            var desk = hold(8, FrameSpec(layout: layout))
            desk += scroll(0, 2400, 60, FrameSpec(layout: layout))
            desk += hold(8, FrameSpec(scrollY: 2400, layout: layout))
            for i in desk.indices {
                let d = layout.document
                desk[i].cursor = CGPoint(x: Double(d.x + d.width / 3) + Double(i % 40) * 3, y: Double(d.y + 220) + 40 * sin(Double(i) / 9))
                if i >= desk.count / 2 { desk[i].minute = 1 }
            }
            clips.append(Clip(name: name, frames: desk, expect: Expectations(maxColumns: 1, minCoverage: 0.9)))
        }

        // A trackpad scroll that creeps half a pixel a frame, then speeds up: no single pair moves a whole pixel.
        var slow = hold(4, FrameSpec(layout: .desktop))
        for i in 1...60 { slow.append(FrameSpec(scrollY: i / 2, layout: .desktop, fraction: Double(i % 2) / 2)) }
        for i in 1...60 { slow.append(FrameSpec(scrollY: 30 + Int((Double(i) * 1.5).rounded(.down)), layout: .desktop, fraction: (Double(i) * 1.5).truncatingRemainder(dividingBy: 1))) }
        slow += hold(4, FrameSpec(scrollY: 120, layout: .desktop))
        clips.append(Clip(name: "slow-scroll", frames: slow, expect: Expectations(maxColumns: 1, minCoverage: 0.9, noEdits: true)))

        // A dropdown opens over the page for about half a second, mid-scroll, while the header badge changes.
        var overlay = hold(4, FrameSpec(layout: .desktop))
        overlay += scroll(0, 600, 24, FrameSpec(layout: .desktop))
        let overlayFrame = overlay.count
        overlay += hold(4, FrameSpec(scrollY: 600, layout: .desktop, overlay: true))
        overlay += scroll(600, 680, 4, FrameSpec(layout: .desktop, overlay: true))
        overlay += scroll(680, 1400, 24, FrameSpec(layout: .desktop, badge: 4))
        overlay += hold(4, FrameSpec(scrollY: 1400, layout: .desktop, badge: 4))
        clips.append(Clip(name: "overlay", frames: overlay, expect: Expectations(
            maxColumns: 1, minCoverage: 0.9,
            events: [EventExpectation(kind: "overlay", pageRows: [], startFrames: [overlayFrame, overlayFrame + 8])])))

        // A checkbox is ticked and a digit changes (20 px each) while the page holds still, then scrolling goes on.
        var small = hold(4, FrameSpec(layout: .desktop))
        small += scroll(0, 900, 30, FrameSpec(layout: .desktop))
        small += hold(6, FrameSpec(scrollY: 900, layout: .desktop))
        let smallFrame = small.count
        small += hold(10, FrameSpec(page: "S", scrollY: 900, layout: .desktop))
        small += scroll(900, 1800, 30, FrameSpec(page: "S", layout: .desktop))
        for i in small.indices { small[i].cursor = CGPoint(x: 520 + Double(i % 20) * 4, y: 420) }
        clips.append(Clip(name: "small-edit", frames: small, expect: Expectations(
            maxColumns: 1, minCoverage: 0.9,
            events: [EventExpectation(kind: "edit", pageRows: [smallEditY - 12, smallEditY + 24], startFrames: [smallFrame, smallFrame + 10])])))

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
            let layout = clip.frames.first?.layout ?? .window
            let truth = Truth(name: clip.name, fps: Int(fps), screen: screen, box: layout.document, fixed: layout.fixed,
                              header: clip.frames.contains(where: \.header) ? headerHeight : 0,
                              pages: clip.frames.map(\.page), scrollY: clip.frames.map(\.scrollY),
                              scrollFraction: clip.frames.map(\.fraction), expect: clip.expect)
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
        // The barcode band below the screen.
        ctx.setFillColor(gray: 1, alpha: 1)
        ctx.fill(cg(CGRect(x: 0, y: screenSize.height, width: W, height: H - screenSize.height), H))
        for bit in 0..<16 where index & (1 << bit) != 0 {
            ctx.setFillColor(gray: 0, alpha: 1)
            ctx.fill(cg(CGRect(x: barcodeX + bit * barcodeStep, y: barcodeY, width: 28, height: 28), H))
        }
        if spec.layout != .window { drawDesktop(spec, pages: pages, ctx: ctx, H: H); return }

        // Window chrome around the content box: stays still, so it must not matter.
        ctx.setFillColor(gray: 0.86, alpha: 1)
        ctx.fill(cg(CGRect(x: 0, y: 0, width: W, height: screenSize.height), H))
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
        drawCursor(spec.cursor, ctx: ctx, H: H)
    }

    private static func drawCursor(_ cursor: CGPoint?, ctx: CGContext, H: Int) {
        if let p = cursor {
            let path = CGMutablePath()
            let pts = [CGPoint(x: 0, y: 0), CGPoint(x: 0, y: 19), CGPoint(x: 5, y: 15), CGPoint(x: 9, y: 23),
                       CGPoint(x: 12, y: 22), CGPoint(x: 8, y: 14), CGPoint(x: 14, y: 14)]
            path.addLines(between: pts.map { CGPoint(x: p.x + $0.x, y: CGFloat(H) - (p.y + $0.y)) })
            path.closeSubpath()
            ctx.addPath(path); ctx.setFillColor(gray: 0, alpha: 1); ctx.fillPath()
            ctx.addPath(path); ctx.setStrokeColor(gray: 1, alpha: 1); ctx.setLineWidth(1.5); ctx.strokePath()
        }
    }

    /// A maximized browser on a desktop, modeled on the real recordings.
    private static func drawDesktop(_ spec: FrameSpec, pages: [String: CGImage], ctx: CGContext, H: Int) {
        let W = screenSize.width, d = spec.layout.document
        let ink = CGColor(gray: 0.15, alpha: 1), muted = CGColor(gray: 0.42, alpha: 1)
        func fill(_ r: CGRect, _ c: CGColor) { ctx.setFillColor(c); ctx.fill(cg(r, H)) }
        // Wallpaper and Dock.
        fill(CGRect(x: 0, y: 0, width: W, height: screenSize.height), CGColor(red: 0.2, green: 0.35, blue: 0.45, alpha: 1))
        fill(CGRect(x: 200, y: d.maxY + 6, width: W - 400, height: screenSize.height - d.maxY - 10), CGColor(gray: 0.85, alpha: 1))
        for i in 0..<14 {
            fill(CGRect(x: 216 + i * 62, y: d.maxY + 12, width: 44, height: 40),
                 CGColor(red: CGFloat(i % 5) / 5, green: CGFloat((i * 3) % 7) / 7, blue: CGFloat((i * 2) % 3) / 3, alpha: 1))
        }
        // Menu bar with a clock.
        fill(CGRect(x: 0, y: 0, width: W, height: 24), CGColor(gray: 0.93, alpha: 1))
        text("Chrome   File   Edit   View   History   Bookmarks   Window   Help", at: CGPoint(x: 36, y: 17), size: 13, color: ink, in: ctx, height: H)
        text(spec.minute == 0 ? "Tue Oct 13  00:57" : "Tue Oct 13  00:58", at: CGPoint(x: W - 140, y: 17), size: 13, color: ink, in: ctx, height: H)
        // Tabs, address bar, bookmarks.
        fill(CGRect(x: 0, y: 24, width: W, height: 80), CGColor(gray: 0.88, alpha: 1))
        for i in 0..<8 { text("Tab \(i + 1) · docs", at: CGPoint(x: 20 + i * 150, y: 46), size: 12, color: muted, in: ctx, height: H) }
        fill(CGRect(x: 120, y: 56, width: 900, height: 24), CGColor(gray: 0.97, alpha: 1))
        text("exploreda.dev/docs/developers", at: CGPoint(x: 140, y: 73), size: 13, color: ink, in: ctx, height: H)
        text("Research   Slack   Planning   Dashboard   Usage desk", at: CGPoint(x: 20, y: 98), size: 12, color: muted, in: ctx, height: H)
        // The page itself, then the site's sticky header over its top.
        if let page = pages[spec.page] {
            // The whole page, offset by a fractional scroll and clipped to the document: resampled like a
            // browser compositing a sub-pixel scroll position.
            ctx.saveGState()
            ctx.clip(to: cg(CGRect(x: d.x, y: d.y, width: d.width, height: d.height), H))
            ctx.interpolationQuality = .high
            let y = Double(d.y) - Double(spec.scrollY) - spec.fraction
            ctx.draw(page, in: CGRect(x: Double(d.x), y: Double(H) - y - Double(page.height), width: Double(page.width), height: Double(page.height)))
            ctx.restoreGState()
        }
        fill(CGRect(x: 0, y: 104, width: W, height: 44), CGColor(gray: 1, alpha: 1))
        fill(CGRect(x: 0, y: 147, width: W, height: 1), CGColor(gray: 0.8, alpha: 1))
        text("explorEDA   Docs        Search the docs", at: CGPoint(x: 30, y: 132), size: 16, color: ink, in: ctx, height: H, bold: true)
        text("Examples   GitHub", at: CGPoint(x: W - 200, y: 132), size: 14, color: ink, in: ctx, height: H)
        fill(CGRect(x: W - 60, y: 116, width: 28, height: 20), CGColor(red: 0.85, green: 0.2, blue: 0.2, alpha: 1))
        text("\(spec.badge)", at: CGPoint(x: W - 50, y: 131), size: 13, color: CGColor(gray: 1, alpha: 1), in: ctx, height: H, bold: true)
        // Left nav.
        fill(CGRect(x: 0, y: d.y, width: d.x, height: d.height), CGColor(gray: 1, alpha: 1))
        let nav = ["The workspace", "Load data", "Fields", "Chart settings", "Developers", "Scatter plot", "Bar chart", "Row chart",
                   "Line chart", "Box plot", "Calendar heatmap", "Hierarchy", "Donut", "Waterfall", "Sankey chart", "Parallel coordinates"]
        for (i, item) in nav.enumerated() {
            let y = d.y + 24 + i * 34
            if i == 4 { fill(CGRect(x: 16, y: y - 8, width: d.x - 32, height: 28), CGColor(gray: 0.93, alpha: 1)) }
            text(item, at: CGPoint(x: 30, y: y + 11), size: 14, color: i == 4 ? ink : muted, in: ctx, height: H, bold: i == 4)
        }
        // Right rail: "On this page", highlight follows the scroll; a full-example card; the window scrollbar.
        let rx = d.maxX
        fill(CGRect(x: rx, y: d.y, width: W - rx, height: d.height), CGColor(gray: 1, alpha: 1))
        text("ON THIS PAGE", at: CGPoint(x: rx + 24, y: d.y + 30), size: 12, color: ink, in: ctx, height: H, bold: true)
        let active = min(9, spec.scrollY / 260)
        for i in 0..<10 {
            let y = d.y + 52 + i * 26
            if i == active { fill(CGRect(x: rx + 22, y: y - 4, width: 2, height: 22), CGColor(red: 0.1, green: 0.3, blue: 0.7, alpha: 1)) }
            text("Section \(i + 1) heading", at: CGPoint(x: rx + 32, y: y + 12), size: 13, color: i == active ? ink : muted,
                 in: ctx, height: H, bold: i == active)
        }
        fill(CGRect(x: rx + 20, y: d.y + 340, width: min(200, W - rx - 40), height: 90), CGColor(gray: 0.96, alpha: 1))
        text("FULL EXAMPLE", at: CGPoint(x: rx + 32, y: d.y + 364), size: 11, color: ink, in: ctx, height: H, bold: true)
        text("Inside the order book", at: CGPoint(x: rx + 32, y: d.y + 390), size: 13, color: ink, in: ctx, height: H, bold: true)
        let thumb = d.y + Int(Double(d.height - 80) * Double(spec.scrollY) / Double(pageHeight - d.height))
        fill(CGRect(x: W - 10, y: thumb, width: 6, height: 80), CGColor(gray: 0.55, alpha: 1))
        if spec.overlay {
            // A dropdown menu over the page, fixed on screen while the page scrolls under it.
            let m = CGRect(x: d.x + 260, y: d.y + 60, width: 240, height: 170)
            fill(m.insetBy(dx: -3, dy: -3), CGColor(gray: 0.7, alpha: 1))
            fill(m, CGColor(gray: 0.99, alpha: 1))
            for (i, item) in ["Copy link", "Open in new tab", "Download PNG", "Export CSV", "Settings…"].enumerated() {
                if i == 1 { fill(CGRect(x: m.minX + 6, y: m.minY + 8 + CGFloat(i) * 32, width: m.width - 12, height: 28), CGColor(red: 0.2, green: 0.45, blue: 0.9, alpha: 1)) }
                text(item, at: CGPoint(x: Int(m.minX) + 18, y: Int(m.minY) + 28 + i * 32), size: 14,
                     color: i == 1 ? CGColor(gray: 1, alpha: 1) : ink, in: ctx, height: H)
            }
        }
        drawCursor(spec.cursor, ctx: ctx, H: H)
    }

    static let barcodeX = 100, barcodeY = 814, barcodeStep = 40

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
        func smallEditRow() {
            // A checkbox and a quantity on one row; "S" ticks the box and changes one digit.
            fill(CGRect(x: 40, y: smallEditY - 14, width: 920, height: 44), CGColor(gray: 1, alpha: 1))
            fill(CGRect(x: 60, y: smallEditY - 6, width: 22, height: 22), CGColor(gray: 0.3, alpha: 1))
            fill(CGRect(x: 62, y: smallEditY - 4, width: 18, height: 18), variant == "S" ? CGColor(red: 0.15, green: 0.5, blue: 0.95, alpha: 1) : CGColor(gray: 1, alpha: 1))
            text("Include returns", at: CGPoint(x: 96, y: smallEditY + 12), size: 16, color: ink, in: ctx, height: H)
            text(variant == "S" ? "Qty 4" : "Qty 3", at: CGPoint(x: 320, y: smallEditY + 12), size: 16, color: ink, in: ctx, height: H, bold: true)
        }
        // The edited value.
        fill(CGRect(x: 40, y: editY - 10, width: 920, height: 60), CGColor(gray: 0.95, alpha: 1))
        text(variant == "B" ? "Total due: $9,870.15  · updated" : "Total due: $1,240.00", at: CGPoint(x: 60, y: editY + 28),
             size: 24, color: variant == "B" ? CGColor(red: 0.7, green: 0.1, blue: 0.1, alpha: 1) : ink, in: ctx, height: H, bold: true)
        y = editY + 70
        contentBlock(until: repeatedRange.lowerBound)
        smallEditRow()
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
