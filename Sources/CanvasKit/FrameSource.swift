import Accelerate
import AVFoundation
import CoreGraphics
import CoreVideo

/// An 8-bit grayscale image, row-major, no padding.
public struct GrayImage: Sendable {
    public let width: Int
    public let height: Int
    public var pixels: [UInt8]

    public init(width: Int, height: Int, pixels: [UInt8]) {
        precondition(pixels.count == width * height)
        self.width = width
        self.height = height
        self.pixels = pixels
    }

    /// Half size in each direction (box filter); cheap enough to run on every frame.
    public func halved() -> GrayImage {
        let w = width / 2, h = height / 2
        var out = [UInt8](repeating: 0, count: w * h)
        pixels.withUnsafeBufferPointer { src in
            out.withUnsafeMutableBufferPointer { dst in
                for y in 0..<h {
                    let r0 = (2 * y) * width, r1 = r0 + width, o = y * w
                    for x in 0..<w {
                        let s = Int(src[r0 + 2 * x]) + Int(src[r0 + 2 * x + 1]) + Int(src[r1 + 2 * x]) + Int(src[r1 + 2 * x + 1])
                        dst[o + x] = UInt8(s >> 2)
                    }
                }
            }
        }
        return GrayImage(width: w, height: h, pixels: out)
    }
}

/// One decoded video frame, cropped to the content box.
public final class DecodedFrame: @unchecked Sendable {
    public let ref: FrameRef
    /// The content box in grayscale at full resolution.
    public let gray: GrayImage
    /// Half resolution, for change detection.
    public let small: GrayImage
    private let pixelBuffer: CVPixelBuffer
    private let box: PixelRect

    init(ref: FrameRef, pixelBuffer: CVPixelBuffer, box: PixelRect) {
        self.ref = ref
        self.pixelBuffer = pixelBuffer
        self.box = box
        gray = Self.grayCrop(pixelBuffer, box)
        small = gray.halved()
    }

    /// Rows `y0 ..< y1` of the content box, in color.
    public func colorRows(_ y0: Int, _ y1: Int) -> CGImage? {
        CVPixelBufferLockBaseAddress(pixelBuffer, .readOnly)
        defer { CVPixelBufferUnlockBaseAddress(pixelBuffer, .readOnly) }
        guard let base = CVPixelBufferGetBaseAddress(pixelBuffer), y1 > y0 else { return nil }
        let rowBytes = CVPixelBufferGetBytesPerRow(pixelBuffer)
        let h = y1 - y0, w = box.width
        var data = Data(count: w * 4 * h)
        data.withUnsafeMutableBytes { dst in
            for row in 0..<h {
                let src = base + (box.y + y0 + row) * rowBytes + box.x * 4
                memcpy(dst.baseAddress! + row * w * 4, src, w * 4)
            }
        }
        guard let provider = CGDataProvider(data: data as CFData) else { return nil }
        return CGImage(width: w, height: h, bitsPerComponent: 8, bitsPerPixel: 32, bytesPerRow: w * 4,
                       space: CGColorSpace(name: CGColorSpace.sRGB)!,
                       bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.noneSkipFirst.rawValue | CGBitmapInfo.byteOrder32Little.rawValue),
                       provider: provider, decode: nil, shouldInterpolate: false, intent: .defaultIntent)
    }

    public func colorImage() -> CGImage? { colorRows(0, box.height) }

    private static func grayCrop(_ pb: CVPixelBuffer, _ box: PixelRect) -> GrayImage {
        CVPixelBufferLockBaseAddress(pb, .readOnly)
        defer { CVPixelBufferUnlockBaseAddress(pb, .readOnly) }
        let rowBytes = CVPixelBufferGetBytesPerRow(pb)
        var out = [UInt8](repeating: 0, count: box.width * box.height)
        guard let base = CVPixelBufferGetBaseAddress(pb) else { return GrayImage(width: box.width, height: box.height, pixels: out) }
        var src = vImage_Buffer(data: base + box.y * rowBytes + box.x * 4, height: vImagePixelCount(box.height),
                                width: vImagePixelCount(box.width), rowBytes: rowBytes)
        out.withUnsafeMutableBytes { raw in
            var dst = vImage_Buffer(data: raw.baseAddress, height: vImagePixelCount(box.height),
                                    width: vImagePixelCount(box.width), rowBytes: box.width)
            // BGRA in memory: luma ≈ 0.11 B + 0.59 G + 0.30 R.
            let matrix: [Int16] = [29, 150, 77, 0]
            _ = vImageMatrixMultiply_ARGB8888ToPlanar8(&src, &dst, matrix, 256, nil, 0, vImage_Flags(kvImageNoFlags))
        }
        return GrayImage(width: box.width, height: box.height, pixels: out)
    }
}

/// Decodes a video in presentation order with exact presentation times, through AVFoundation, so frame
/// times match what AVPlayer shows for the same file.
public final class FrameSource {
    public let size: CGSize
    public let duration: Double
    /// Estimated from the track's nominal rate; the decoded count is authoritative.
    public let estimatedFrameCount: Int
    private let reader: AVAssetReader
    private let output: AVAssetReaderTrackOutput
    private let box: PixelRect
    private var nextIndex = 0

    public init(url: URL, box: PixelRect?) async throws {
        let asset = AVURLAsset(url: url)
        guard let track = try await asset.loadTracks(withMediaType: .video).first else {
            throw CanvasError("No video track in \(url.lastPathComponent)")
        }
        let natural = try await track.load(.naturalSize)
        size = natural
        duration = try await asset.load(.duration).seconds
        let fps = try await track.load(.nominalFrameRate)
        estimatedFrameCount = max(1, Int((duration * Double(fps > 0 ? fps : 15)).rounded()))
        let full = PixelRect(x: 0, y: 0, width: Int(natural.width), height: Int(natural.height))
        var b = box ?? full
        // Clamp into the frame and keep even sizes so half-resolution images line up.
        b.x = max(0, min(b.x, full.width - 2))
        b.y = max(0, min(b.y, full.height - 2))
        b.width = max(2, min(b.width, full.width - b.x)) & ~1
        b.height = max(2, min(b.height, full.height - b.y)) & ~1
        self.box = b
        reader = try AVAssetReader(asset: asset)
        output = AVAssetReaderTrackOutput(track: track, outputSettings: [
            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA,
        ])
        output.alwaysCopiesSampleData = true
        reader.add(output)
        guard reader.startReading() else { throw CanvasError(reader.error?.localizedDescription ?? "Couldn't read the video") }
    }

    /// The content box after clamping to the video.
    public var contentBox: PixelRect { box }

    public func next() throws -> DecodedFrame? {
        while let sample = output.copyNextSampleBuffer() {
            guard let pb = CMSampleBufferGetImageBuffer(sample) else { continue }
            let pts = CMSampleBufferGetPresentationTimeStamp(sample)
            let frame = DecodedFrame(ref: FrameRef(index: nextIndex, time: pts.seconds), pixelBuffer: pb, box: box)
            nextIndex += 1
            return frame
        }
        if reader.status == .failed { throw CanvasError(reader.error?.localizedDescription ?? "Decoding failed") }
        return nil
    }

    public func cancel() { reader.cancelReading() }
}

public struct CanvasError: LocalizedError {
    public var message: String
    public init(_ message: String) { self.message = message }
    public var errorDescription: String? { message }
}
