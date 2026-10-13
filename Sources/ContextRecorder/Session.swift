import Foundation

struct Mark: Codable {
    var index: Int
    var kind: String          // "mark" (context only; frame pulled from video later) or "screenshot" (region still)
    var offsetSeconds: Double // seconds into recording.mp4
    var wallTime: String      // ISO-8601
    var screenshot: String?   // relative path within the session folder
    var region: [String: Double]? // screenshot area in display points, top-left origin (x, y, width, height)
    var context: MarkContext
}

/// A recording session on disk. Marks are appended to marks.jsonl as they happen so nothing is lost on a crash.
final class Session {
    let folder: URL
    let startedAt = Date()
    private(set) var marks: [Mark] = []
    private let iso = ISO8601DateFormatter()

    var videoURL: URL { folder.appendingPathComponent("recording.mp4") }
    var marksURL: URL { folder.appendingPathComponent("marks.jsonl") }
    var screenshotsDir: URL { folder.appendingPathComponent("screenshots") }

    static var root: URL {
        FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Movies/ContextRecorder")
    }

    init() throws {
        let fmt = DateFormatter()
        fmt.dateFormat = "yyyy-MM-dd_HH-mm-ss"
        folder = Self.root.appendingPathComponent(fmt.string(from: Date()))
        try FileManager.default.createDirectory(at: screenshotsDir, withIntermediateDirectories: true)
        FileManager.default.createFile(atPath: marksURL.path, contents: nil)
    }

    func nextIndex() -> Int { marks.count + 1 }

    func add(_ mark: Mark) {
        marks.append(mark)
        let enc = JSONEncoder()
        enc.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
        guard var line = try? enc.encode(mark) else { return }
        line.append(0x0A)
        if let handle = try? FileHandle(forWritingTo: marksURL) {
            handle.seekToEndOfFile()
            handle.write(line)
            try? handle.close()
        }
    }

    func timestamp() -> String { iso.string(from: Date()) }
}
