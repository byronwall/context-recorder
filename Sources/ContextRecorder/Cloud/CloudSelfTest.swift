import AVFoundation
import CryptoKit
import Foundation
import ImageIO

/// `--self-test cloud-bundle` and `--self-test cloud-client`.
@MainActor
enum CloudSelfTest {
    // MARK: Fixture

    struct Fixture: Decodable {
        var fps: Int
        var sources: [Source]
        var cases: [Case]
    }
    struct Source: Decodable { var name: String; var id: Int; var seconds: Double; var width: Int; var height: Int }
    struct Case: Decodable {
        var name: String
        var copyOf: String?
        var edits: [Segment]?
        var duration: Double
        var marks: [Mark]
        var drawings: [Drawing]
    }
    struct Mark: Decodable { var source: String; var time: Double; var edited: Double?; var page: String?; var annotated: Bool? }
    struct Drawing: Decodable {
        var kind: String; var source: String; var start: Double; var end: Double
        var points: [[Double]]; var text: String?; var windows: [[Double]]
    }

    // MARK: Bundle checks

    static func runBundle(fixture url: URL, keep: Bool) async -> [String] {
        guard let data = try? Data(contentsOf: url) else { return ["couldn't read \(url.path)"] }
        let fixture: Fixture
        do { fixture = try JSONDecoder().decode(Fixture.self, from: data) } catch { return ["\(url.lastPathComponent): \(error)"] }
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("cloud-bundle-selftest-\(UUID().uuidString.prefix(8))")
        defer { if !keep { try? FileManager.default.removeItem(at: root) } else { print("kept \(root.path)") } }
        var failures: [String] = []
        do {
            try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
            for s in fixture.sources { try await makeSource(s, fps: fixture.fps, in: root) }
            for c in fixture.cases {
                let folder = try makeSession(c, fixture: fixture, root: root)
                let out = root.appendingPathComponent("bundles/\(c.name)")
                do {
                    let manifest = try await CloudBundle.build(session: folder, to: out)
                    failures += await check(c, fixture: fixture, folder: folder, out: out, manifest: manifest).map { "\(c.name): \($0)" }
                } catch {
                    failures.append("\(c.name): build failed: \(error.localizedDescription)")
                }
            }
        } catch {
            failures.append("setup: \(error.localizedDescription)")
        }
        return failures
    }

    private static func check(_ c: Case, fixture: Fixture, folder: URL, out: URL, manifest: CloudManifest) async -> [String] {
        var f: [String] = []
        let frame = 1.0 / Double(fixture.fps)
        let segments = c.edits ?? [Segment(start: 0, end: c.duration)]
        let map = EditMap(segments)
        let ids = Dictionary(uniqueKeysWithValues: fixture.sources.map { ($0.name, $0.id) })
        func sourceID(_ source: String) -> Int {
            source == "." ? (ids[c.copyOf ?? ""] ?? -1) : (ids[source.replacingOccurrences(of: "../", with: "")] ?? -1)
        }

        // Duration: the fixture, EditMap and the exported file agree within a frame.
        if abs(map.duration - c.duration) > 1e-6 { f.append("EditMap duration \(map.duration) ≠ \(c.duration)") }
        if abs(manifest.duration - c.duration) > frame { f.append("exported duration \(manifest.duration) ≠ \(c.duration)") }

        let video = AVURLAsset(url: out.appendingPathComponent("recording.mp4"))
        // H.264 + AAC.
        do {
            let v = try await video.loadTracks(withMediaType: .video).first
            let a = try await video.loadTracks(withMediaType: .audio).first
            let vf = try await v?.load(.formatDescriptions).first
            let af = try await a?.load(.formatDescriptions).first
            if vf.map(CMFormatDescriptionGetMediaSubType) != kCMVideoCodecType_H264 { f.append("video isn't H.264") }
            if af.map(CMFormatDescriptionGetMediaSubType) != kAudioFormatMPEG4AAC { f.append("audio isn't AAC") }
        } catch { f.append("couldn't read the video: \(error)") }
        // Fast start: moov before mdat, so the viewer needs no tail request.
        if !CloudBundle.isFastStart(video.url) {
            f.append("video isn't fast start: \(CloudBundle.topLevelAtoms(video.url) ?? [])")
        }

        // Every frame of the flattened video is the source frame EditMap says it should be.
        let generator = AVAssetImageGenerator(asset: video)
        generator.requestedTimeToleranceBefore = .zero
        generator.requestedTimeToleranceAfter = .zero
        func code(at t: Double) async -> (id: Int, frame: Int)? {
            guard let (image, _) = try? await generator.image(at: CMTime(seconds: t, preferredTimescale: 600)) else { return nil }
            return readBarcode(image)
        }
        func expect(_ source: String, _ time: Double) -> (id: Int, frame: Int) {
            (sourceID(source), Int((time * Double(fixture.fps) + 1e-6).rounded(.down)))
        }
        func near(_ got: (id: Int, frame: Int)?, _ want: (id: Int, frame: Int)) -> Bool {
            guard let got else { return false }
            return got.id == want.id && abs(got.frame - want.frame) <= 1
        }
        var bad = 0
        let frames = Int((c.duration * Double(fixture.fps)).rounded())
        // The picture may stop a composition frame (1/30 s) before the audio; that's inside the one-frame rule.
        let pictureEnd = (try? await video.loadTracks(withMediaType: .video).first?.load(.timeRange).end.seconds) ?? 0
        if pictureEnd < c.duration - frame { f.append("picture ends at \(pictureEnd), want \(c.duration)") }
        for n in 0..<frames {
            let t = (Double(n) + 0.5) * frame
            if t >= pictureEnd { continue }
            let s = map.toSource(t)
            let want = expect(s.source, s.time)
            let got = await code(at: t)
            if !near(got, want) {
                bad += 1
                if bad <= 3 { f.append("frame at \(t) s shows \(got.map { "\($0)" } ?? "nothing"), want \(want)") }
            }
        }
        if bad > 3 { f.append("… \(bad) frames off in all") }

        // Marks: kept ones at their expected edited time, showing their source moment; cut ones gone.
        let session = (try? Data(contentsOf: out.appendingPathComponent("session.json")))
            .flatMap { try? JSONSerialization.jsonObject(with: $0) as? [String: Any] } ?? [:]
        let marks = session["marks"] as? [[String: Any]] ?? []
        let kept = c.marks.filter { $0.edited != nil }
        if marks.count != kept.count { f.append("\(marks.count) marks in session.json, want \(kept.count)") }
        if manifest.markCount != kept.count { f.append("markCount \(manifest.markCount)") }
        for (m, want) in zip(marks, kept) {
            let t = m["offsetSeconds"] as? Double ?? -1
            if abs(t - (want.edited ?? 0)) > 1e-6 { f.append("mark at \(t), want \(want.edited ?? 0)") }
            if let e = map.toEdited(source: want.source, want.time), abs(e - t) > 1e-6 { f.append("mark at \(t) but EditMap says \(e)") }
            let got = await code(at: t + frame / 2)
            if !near(got, expect(want.source, want.time)) { f.append("mark at \(t) shows \(String(describing: got))") }
            for key in ["image", "frame"] {
                guard let p = m[key] as? String else { f.append("mark at \(t) has no \(key)"); continue }
                if !FileManager.default.fileExists(atPath: out.appendingPathComponent(p).path) { f.append("\(key) \(p) not in bundle") }
                if c.edits?.first?.source.hasPrefix("../") == true, !p.hasPrefix("sources/") { f.append("\(key) \(p) should be under sources/") }
                if want.annotated == true, key == "image", !p.hasPrefix("annotations/") { f.append("annotated image not used: \(p)") }
            }
            if m["sourceImage"] != nil || m["sourceFrame"] != nil { f.append("sourceImage/sourceFrame left in") }
        }
        if (session["hiddenMarks"] as? [Any])?.isEmpty != true { f.append("hiddenMarks not empty") }
        if (session["folder"] as? String) != "" { f.append("folder not empty") }
        let segs = session["segments"] as? [[String: Any]] ?? []
        if segs.count != 1 || (segs.first?["source"] as? String) != "." || abs((segs.first?["end"] as? Double ?? -1) - manifest.duration) > 1e-6 {
            f.append("segments not flattened: \(segs)")
        }

        // Drawings: windows as expected and as EditMap gives them; each window opens on its own source moment.
        let drawings = (try? Data(contentsOf: out.appendingPathComponent("drawings.json")))
            .flatMap { try? JSONDecoder().decode([CloudDrawing].self, from: $0) } ?? []
        let wanted = c.drawings.flatMap { d in d.windows.map { (d, $0) } }.sorted { $0.1[0] < $1.1[0] }
        if drawings.count != wanted.count { f.append("\(drawings.count) drawing windows, want \(wanted.count)") }
        for (got, (d, w)) in zip(drawings, wanted) {
            if abs(got.start - w[0]) > frame || abs(got.end - w[1]) > frame { f.append("drawing \(d.kind) window \(got.start)–\(got.end), want \(w)") }
            let pieces = map.editedPieces(source: d.source, d.start, d.end)
            if !pieces.contains(where: { $0.lowerBound <= got.start + 1e-6 && got.start < $0.upperBound }) {
                f.append("drawing \(d.kind) starts at \(got.start), outside EditMap's pieces \(pieces)")
            }
            let s = map.toSource(got.start + frame / 2)
            if s.source != d.source || s.time < d.start - frame || s.time > d.end + frame { f.append("drawing \(d.kind) opens on \(s)") }
            if let image = loadImage(out.appendingPathComponent(got.file)) {
                if image.width != manifest.video.width || image.height != manifest.video.height {
                    f.append("drawing PNG \(image.width)x\(image.height) ≠ video \(manifest.video.width)x\(manifest.video.height)")
                }
                let (clear, inked) = alphaStats(image)
                if !clear || !inked { f.append("drawing \(d.kind) PNG isn't a transparent overlay (clear \(clear), inked \(inked))") }
            } else { f.append("drawing PNG \(got.file) missing") }
        }

        // Thumbs, pages, manifest integrity, index.html.
        let thumbs = Int((c.duration / CloudBundle.thumbInterval).rounded(.down)) + 1
        if manifest.thumbs.count != thumbs { f.append("\(manifest.thumbs.count) thumbs, want \(thumbs)") }
        for i in 0..<manifest.thumbs.count {
            let image = loadImage(out.appendingPathComponent(String(format: "thumbs/%04d.jpg", i)))
            if image?.width != CloudBundle.thumbWidth { f.append("thumb \(i) width \(image?.width ?? 0)"); break }
        }
        if c.marks.contains(where: { $0.page == "big" }), !manifest.skippedPages.contains(where: { $0.path == "pages/big.mhtml" }) {
            f.append("big page not skipped: \(manifest.skippedPages)")
        }
        if c.marks.contains(where: { $0.page == "small" }), !manifest.files.contains(where: { $0.path == "pages/small.mhtml" }) {
            f.append("small page not included")
        }
        for file in manifest.files {
            let url = out.appendingPathComponent(file.path)
            if file.path.split(separator: "/").contains("..") || file.path.contains("..") || file.path.hasPrefix("/") { f.append("bad path \(file.path)") }
            if (try? CloudBundle.sha256(of: url)) != file.sha256 { f.append("sha256 of \(file.path) doesn't match") }
        }
        for banned in ["audio.wav", "process.log", "edits.json", "annotations.json", "viewer.html", "manifest.json", "index.html"]
        where manifest.files.contains(where: { $0.path == banned }) { f.append("\(banned) listed in files") }
        if (try? CloudBundle.inputHash(session: folder)) != manifest.inputHash { f.append("inputHash isn't stable") }
        let index = (try? String(contentsOf: out.appendingPathComponent("index.html"), encoding: .utf8)) ?? ""
        if index.contains("/*__SESSION_DATA__*/") || !index.contains("\"cloud\":{\"drawings\":") { f.append("index.html doesn't embed the cloud data") }
        return f
    }

    // MARK: Synthetic sessions

    private static func makeSource(_ s: Source, fps: Int, in root: URL) async throws {
        let folder = root.appendingPathComponent(s.name)
        try FileManager.default.createDirectory(at: folder.appendingPathComponent("frames"), withIntermediateDirectories: true)
        try await encode(s, fps: fps, to: folder.appendingPathComponent("recording.mp4"))
    }

    private static func makeSession(_ c: Case, fixture: Fixture, root: URL) throws -> URL {
        let fm = FileManager.default
        let folder = root.appendingPathComponent(c.name)
        try fm.createDirectory(at: folder.appendingPathComponent("frames"), withIntermediateDirectories: true)
        if let copy = c.copyOf { try fm.copyItem(at: root.appendingPathComponent("\(copy)/recording.mp4"), to: folder.appendingPathComponent("recording.mp4")) }
        if let edits = c.edits { try EditsFile.save(edits, to: folder) }
        let segments = c.edits ?? [Segment(start: 0, end: c.duration)]
        let map = EditMap(segments)
        var durations: [String: Double] = [:]
        for s in Set(segments.map(\.source)) {
            let name = s == "." ? (c.copyOf ?? "") : s.replacingOccurrences(of: "../", with: "")
            durations[s] = fixture.sources.first { $0.name == name }?.seconds
        }

        // A tiny frame image per mark, stored where processing would put it (a joined session's in its source).
        var marks: [[String: Any]] = [], hidden: [[String: Any]] = []
        for (i, m) in c.marks.enumerated() {
            let owner = m.source == "." ? folder : root.appendingPathComponent(m.source.replacingOccurrences(of: "../", with: ""))
            let prefix = m.source == "." ? "" : m.source + "/"
            let name = String(format: "frames/%03d.jpg", i + 1)
            try writeSolid(owner.appendingPathComponent(name), gray: 0.5)
            var mark: [String: Any] = [
                "index": i + 1, "kind": "mark", "frame": prefix + name, "image": prefix + name,
                "sourceImage": prefix + name, "sourceFrame": prefix + name,
                "sourceOffsetSeconds": m.time, "sourceSession": m.source,
                "context": ["app": "Fixture"],
            ]
            if m.annotated == true {
                let copy = "annotations/" + (prefix + name).replacingOccurrences(of: ".jpg", with: "").replacingOccurrences(of: "/", with: "-") + ".png"
                try writeSolid(folder.appendingPathComponent(copy), gray: 0.8)
                mark["image"] = copy
            }
            if let page = m.page {
                let file = "pages/\(page).mhtml"
                try fm.createDirectory(at: folder.appendingPathComponent("pages"), withIntermediateDirectories: true)
                try Data(count: page == "big" ? 11 * 1024 * 1024 : 2048).write(to: folder.appendingPathComponent(file))
                mark["browser"] = ["url": "https://example.test/", "pageFile": file]
            }
            if let e = m.edited { mark["offsetSeconds"] = e; marks.append(mark) } else { mark["offsetSeconds"] = m.time; hidden.append(mark) }
        }
        let session: [String: Any] = [
            "name": c.name, "folder": folder.path, "duration": map.duration,
            "segments": map.segments.map { ["source": $0.source, "start": $0.start, "end": $0.end, "editedStart": $0.editedStart ?? 0] },
            "sourceDurations": durations, "errors": [], "marks": marks, "hiddenMarks": hidden,
            "activity": [], "browser": [], "transcript": [["start": 1.0, "end": 2.0, "text": "Hello"]],
        ]
        try CloudBundle.writeJSON(session, to: folder.appendingPathComponent("session.json"))
        try "# \(c.name)\n".write(to: folder.appendingPathComponent("session.md"), atomically: true, encoding: .utf8)

        let annotations = c.drawings.map { d in
            Annotation(kind: Annotation.Kind(rawValue: d.kind) ?? .rectangle, source: d.source, start: d.start, end: d.end,
                       points: d.points.map { CGPoint(x: $0[0], y: $0[1]) }, color: d.kind == "highlight" ? "#FFCC00" : "#FF3B30", text: d.text)
        }
        try AnnotationsFile.save(annotations, to: folder)
        return folder
    }

    // MARK: Barcoded video

    /// 16 blocks across the top quarter: bits 0–11 the frame number, 12–15 the source id.
    nonisolated private static func drawBarcode(_ ctx: CGContext, width: Int, height: Int, value: Int) {
        ctx.setFillColor(gray: 0.5, alpha: 1)
        ctx.fill(CGRect(x: 0, y: 0, width: width, height: height))
        let block = Double(width) / 16, band = Double(height) / 4
        for bit in 0..<16 {
            ctx.setFillColor(gray: (value >> bit) & 1 == 1 ? 0 : 1, alpha: 1)
            // CG is y-up: the band sits at the top of the picture.
            ctx.fill(CGRect(x: Double(bit) * block, y: Double(height) - band, width: block, height: band))
        }
    }

    static func readBarcode(_ image: CGImage) -> (id: Int, frame: Int)? {
        let W = image.width, H = image.height
        var pixels = [UInt8](repeating: 0, count: W * H)
        guard let ctx = CGContext(data: &pixels, width: W, height: H, bitsPerComponent: 8, bytesPerRow: W,
                                  space: CGColorSpaceCreateDeviceGray(), bitmapInfo: CGImageAlphaInfo.none.rawValue) else { return nil }
        ctx.draw(image, in: CGRect(x: 0, y: 0, width: W, height: H))
        var value = 0
        let y = H / 8   // memory rows run top-down
        for bit in 0..<16 {
            let x = Int((Double(bit) + 0.5) * Double(W) / 16)
            if pixels[y * W + x] < 128 { value |= 1 << bit }
        }
        return (value >> 12, value & 0xFFF)
    }

    nonisolated private static func encode(_ s: Source, fps: Int, to url: URL) async throws {
        let writer = try AVAssetWriter(outputURL: url, fileType: .mp4)
        let video = AVAssetWriterInput(mediaType: .video, outputSettings: [
            AVVideoCodecKey: AVVideoCodecType.h264, AVVideoWidthKey: s.width, AVVideoHeightKey: s.height,
            AVVideoCompressionPropertiesKey: [AVVideoAverageBitRateKey: 2_000_000],
        ])
        video.expectsMediaDataInRealTime = false
        let adaptor = AVAssetWriterInputPixelBufferAdaptor(assetWriterInput: video, sourcePixelBufferAttributes: [
            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA,
            kCVPixelBufferWidthKey as String: s.width, kCVPixelBufferHeightKey as String: s.height,
        ])
        let rate = 44100
        let audio = AVAssetWriterInput(mediaType: .audio, outputSettings: [
            AVFormatIDKey: kAudioFormatMPEG4AAC, AVSampleRateKey: rate, AVNumberOfChannelsKey: 1, AVEncoderBitRateKey: 64000,
        ])
        audio.expectsMediaDataInRealTime = false
        writer.add(video)
        writer.add(audio)
        guard writer.startWriting() else { throw ReviewError(writer.error?.localizedDescription ?? "Can't write \(url.path)") }
        writer.startSession(atSourceTime: .zero)
        let frames = Int(s.seconds * Double(fps))
        let samples = Int(s.seconds * Double(rate))

        async let videoDone: Void = {
            for i in 0..<frames {
                while !video.isReadyForMoreMediaData { try await Task.sleep(for: .milliseconds(2)) }
                guard let pool = adaptor.pixelBufferPool else { throw ReviewError("No pixel buffer pool") }
                var pb: CVPixelBuffer?
                CVPixelBufferPoolCreatePixelBuffer(nil, pool, &pb)
                guard let pb else { throw ReviewError("No pixel buffer") }
                CVPixelBufferLockBaseAddress(pb, [])
                if let ctx = CGContext(data: CVPixelBufferGetBaseAddress(pb), width: s.width, height: s.height, bitsPerComponent: 8,
                                       bytesPerRow: CVPixelBufferGetBytesPerRow(pb), space: CGColorSpace(name: CGColorSpace.sRGB)!,
                                       bitmapInfo: CGImageAlphaInfo.noneSkipFirst.rawValue | CGBitmapInfo.byteOrder32Little.rawValue) {
                    drawBarcode(ctx, width: s.width, height: s.height, value: s.id << 12 | i)
                }
                CVPixelBufferUnlockBaseAddress(pb, [])
                guard adaptor.append(pb, withPresentationTime: CMTime(value: CMTimeValue(i), timescale: CMTimeScale(fps))) else {
                    throw ReviewError(writer.error?.localizedDescription ?? "Couldn't append frame \(i)")
                }
            }
            video.markAsFinished()
        }()
        async let audioDone: Void = {
            var asbd = AudioStreamBasicDescription(mSampleRate: Double(rate), mFormatID: kAudioFormatLinearPCM,
                                                   mFormatFlags: kLinearPCMFormatFlagIsSignedInteger | kLinearPCMFormatFlagIsPacked,
                                                   mBytesPerPacket: 2, mFramesPerPacket: 1, mBytesPerFrame: 2, mChannelsPerFrame: 1,
                                                   mBitsPerChannel: 16, mReserved: 0)
            var format: CMAudioFormatDescription?
            CMAudioFormatDescriptionCreate(allocator: nil, asbd: &asbd, layoutSize: 0, layout: nil, magicCookieSize: 0,
                                           magicCookie: nil, extensions: nil, formatDescriptionOut: &format)
            guard let format else { throw ReviewError("No audio format") }
            var at = 0
            while at < samples {
                while !audio.isReadyForMoreMediaData { try await Task.sleep(for: .milliseconds(2)) }
                let n = min(4096, samples - at)
                var pcm = [Int16](repeating: 0, count: n)
                for k in 0..<n {
                    let phase = Double(at + k) * 2 * Double.pi * 440 / Double(rate)
                    pcm[k] = Int16(sin(phase) * 8000)
                }
                var block: CMBlockBuffer?
                CMBlockBufferCreateWithMemoryBlock(allocator: nil, memoryBlock: nil, blockLength: n * 2, blockAllocator: nil,
                                                   customBlockSource: nil, offsetToData: 0, dataLength: n * 2, flags: 0, blockBufferOut: &block)
                guard let block else { throw ReviewError("No audio block") }
                pcm.withUnsafeMutableBytes { _ = CMBlockBufferReplaceDataBytes(with: $0.baseAddress!, blockBuffer: block, offsetIntoDestination: 0, dataLength: n * 2) }
                var buffer: CMSampleBuffer?
                CMAudioSampleBufferCreateReadyWithPacketDescriptions(allocator: nil, dataBuffer: block, formatDescription: format, sampleCount: n,
                                                                     presentationTimeStamp: CMTime(value: CMTimeValue(at), timescale: CMTimeScale(rate)),
                                                                     packetDescriptions: nil, sampleBufferOut: &buffer)
                guard let buffer, audio.append(buffer) else { throw ReviewError(writer.error?.localizedDescription ?? "Couldn't append audio") }
                at += n
            }
            audio.markAsFinished()
        }()
        _ = try await (videoDone, audioDone)
        await writer.finishWriting()
        if writer.status != .completed { throw ReviewError(writer.error?.localizedDescription ?? "Writing failed") }
    }

    // MARK: Image helpers

    private static func writeSolid(_ url: URL, gray: Double) throws {
        let ctx = CGContext(data: nil, width: 32, height: 20, bitsPerComponent: 8, bytesPerRow: 0, space: CGColorSpaceCreateDeviceGray(),
                            bitmapInfo: CGImageAlphaInfo.none.rawValue)!
        ctx.setFillColor(gray: gray, alpha: 1)
        ctx.fill(CGRect(x: 0, y: 0, width: 32, height: 20))
        try CloudBundle.writeImage(ctx.makeImage()!, type: url.pathExtension == "png" ? .png : .jpeg, to: url)
    }

    static func loadImage(_ url: URL) -> CGImage? {
        guard let src = CGImageSourceCreateWithURL(url as CFURL, nil) else { return nil }
        return CGImageSourceCreateImageAtIndex(src, 0, nil)
    }

    /// Whether the corners are fully transparent and something is drawn.
    static func alphaStats(_ image: CGImage) -> (clear: Bool, inked: Bool) {
        let W = image.width, H = image.height
        var pixels = [UInt8](repeating: 0, count: W * H * 4)
        guard let ctx = CGContext(data: &pixels, width: W, height: H, bitsPerComponent: 8, bytesPerRow: W * 4,
                                  space: CGColorSpace(name: CGColorSpace.sRGB)!, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return (false, false) }
        ctx.draw(image, in: CGRect(x: 0, y: 0, width: W, height: H))
        let corners = [(0, 0), (W - 1, 0), (0, H - 1), (W - 1, H - 1)].allSatisfy { pixels[($0.1 * W + $0.0) * 4 + 3] == 0 }
        var inked = false
        for i in stride(from: 3, to: pixels.count, by: 4) where pixels[i] > 40 { inked = true; break }
        return (corners, inked)
    }
}
