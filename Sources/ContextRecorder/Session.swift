import Foundation

struct Mark: Codable {
    var index: Int
    var kind: String          // "mark" (context only; frame pulled from video later) or "screenshot" (region still)
    var offsetSeconds: Double // seconds into recording.mp4
    var wallTime: String      // ISO-8601
    var screenshot: String?   // relative path within the session folder
    var region: [String: Double]? // screenshot area in display points, top-left origin (x, y, width, height)
    var context: MarkContext
    var browser: JSONValue?   // page snapshot from the Chrome extension (element under mouse, recent events)
}

/// A recording session on disk. Marks are appended to marks.jsonl as they happen so nothing is lost on a crash.
final class Session {
    let folder: URL
    let startedAt = Date()
    private(set) var marks: [Mark] = []
    private let iso = ISO8601DateFormatter()

    var videoURL: URL { folder.appendingPathComponent("recording.mp4") }
    var marksURL: URL { folder.appendingPathComponent("marks.jsonl") }
    var browserURL: URL { folder.appendingPathComponent("browser.jsonl") }
    var screenshotsDir: URL { folder.appendingPathComponent("screenshots") }

    static var root: URL {
        FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Movies/ContextRecorder")
    }

    init(root: URL = Session.root) throws {
        let fmt = DateFormatter()
        fmt.dateFormat = "yyyy-MM-dd_HH-mm-ss"
        folder = root.appendingPathComponent(fmt.string(from: Date()))
        try FileManager.default.createDirectory(at: screenshotsDir, withIntermediateDirectories: true)
        FileManager.default.createFile(atPath: marksURL.path, contents: nil)
    }

    func nextIndex() -> Int { marks.count + 1 }

    func add(_ mark: Mark) {
        marks.append(mark)
        Self.appendLine(mark, to: marksURL)
    }

    /// Streamed page event from the Chrome extension, stamped with its offset into the recording.
    func addBrowserEvent(_ event: JSONValue, offset: Double) {
        Self.appendLine(BrowserEvent(offsetSeconds: offset, event: event), to: browserURL)
    }

    private struct BrowserEvent: Encodable {
        var offsetSeconds: Double
        var event: JSONValue
    }

    static func appendLine<T: Encodable>(_ value: T, to url: URL) {
        let enc = JSONEncoder()
        enc.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
        guard var line = try? enc.encode(value) else { return }
        line.append(0x0A)
        if !FileManager.default.fileExists(atPath: url.path) {
            FileManager.default.createFile(atPath: url.path, contents: nil)
        }
        if let handle = try? FileHandle(forWritingTo: url) {
            handle.seekToEndOfFile()
            handle.write(line)
            try? handle.close()
        }
    }

    func timestamp() -> String { iso.string(from: Date()) }
}
