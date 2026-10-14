import Annotation
import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers

/// Where a session's annotations live: `annotations/<dir>-<name>.json` (the editable drawing) and
/// `.png` (flattened, what Markdown and exports show) beside the untouched original. Deleting the folder
/// and re-processing returns the session to its captures. scripts/process_session.py uses the same names.
struct AnnotationStore {
    let folder: URL

    /// `screenshots/004.png` → `annotations/screenshots-004`.
    func base(for original: String) -> URL {
        let stem = (original as NSString).deletingPathExtension.replacingOccurrences(of: "/", with: "-")
        return folder.appendingPathComponent("annotations").appendingPathComponent(stem)
    }

    func relativePath(of url: URL) -> String? {
        let root = folder.standardizedFileURL.path + "/"
        let path = url.standardizedFileURL.path
        return path.hasPrefix(root) ? String(path.dropFirst(root.count)) : nil
    }

    func load(_ original: String) -> AnnotationDoc? {
        guard let data = try? Data(contentsOf: base(for: original).appendingPathExtension("json")) else { return nil }
        return try? AnnotationDoc.decoded(from: data)
    }

    /// Writes the drawing and its flattened image, or removes both when nothing is left.
    func save(_ doc: AnnotationDoc, original: String, image: CGImage) throws {
        let base = base(for: original)
        let json = base.appendingPathExtension("json"), png = base.appendingPathExtension("png")
        if doc.isEmpty {
            for file in [json, png] where FileManager.default.fileExists(atPath: file.path) { try FileManager.default.removeItem(at: file) }
            return
        }
        try FileManager.default.createDirectory(at: base.deletingLastPathComponent(), withIntermediateDirectories: true)
        guard let flat = Renderer.flatten(doc, onto: image) else { throw ReviewError("Couldn't draw the annotations") }
        // Image first: the JSON is what says "this image is annotated".
        try write(flat, to: png)
        try doc.encoded().write(to: json, options: .atomic)
    }

    func remove(_ original: String) {
        let base = base(for: original)
        for ext in ["json", "png"] { try? FileManager.default.removeItem(at: base.appendingPathExtension(ext)) }
    }

    private func write(_ image: CGImage, to url: URL) throws {
        let temp = url.deletingLastPathComponent().appendingPathComponent(".\(url.lastPathComponent).tmp")
        guard let dest = CGImageDestinationCreateWithURL(temp as CFURL, UTType.png.identifier as CFString, 1, nil) else {
            throw ReviewError("Couldn't write \(url.lastPathComponent)")
        }
        CGImageDestinationAddImage(dest, image, nil)
        guard CGImageDestinationFinalize(dest) else { throw ReviewError("Couldn't write \(url.lastPathComponent)") }
        if FileManager.default.fileExists(atPath: url.path) {
            _ = try FileManager.default.replaceItemAt(url, withItemAt: temp)
        } else {
            try FileManager.default.moveItem(at: temp, to: url)
        }
    }
}
