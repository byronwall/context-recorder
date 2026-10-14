import Foundation

/// A project folder whose grid (`pgm/data`) receives exports. Remembered most-recent first.
struct ExportTarget: Codable, Identifiable, Hashable {
    var folder: String
    var projectID: String?
    var projectName: String?
    var parentNodeID: String?
    var parentTitle: String?
    var lastUsed: Date

    var id: String { folder }
    var url: URL { URL(fileURLWithPath: folder) }
    var name: String { url.lastPathComponent }
    var dataDir: URL { Pgm.dataDir(for: url) }
}

@MainActor
enum ExportTargets {
    private static let key = "pgmExportTargets"

    static func load() -> [ExportTarget] {
        guard let data = UserDefaults.standard.data(forKey: key),
              let list = try? JSONDecoder().decode([ExportTarget].self, from: data) else { return [] }
        return list.sorted { $0.lastUsed > $1.lastUsed }
    }

    static func save(_ target: ExportTarget) {
        var list = load().filter { $0.folder != target.folder }
        list.insert(target, at: 0)
        if let data = try? JSONEncoder().encode(Array(list.prefix(12))) { UserDefaults.standard.set(data, forKey: key) }
    }

    static func remove(_ target: ExportTarget) {
        let list = load().filter { $0.folder != target.folder }
        if let data = try? JSONEncoder().encode(list) { UserDefaults.standard.set(data, forKey: key) }
    }
}

/// `<session>/exports/pgm.json`: which grid nodes this session's marks became, per destination, so a
/// second export updates those nodes instead of making copies.
struct ExportRecord: Codable {
    struct Destination: Codable {
        var dataDir: String
        var projectID: String
        var sessionNodeID: String
        var marks: [String: MarkNode]   // mark index → node
        var exportedAt: Date
    }
    struct MarkNode: Codable {
        var nodeID: String
        var imageIDs: [String]
    }

    var destinations: [Destination] = []

    static func url(for session: URL) -> URL { session.appendingPathComponent("exports/pgm.json") }

    static func load(_ session: URL) -> ExportRecord {
        guard let data = try? Data(contentsOf: url(for: session)) else { return ExportRecord() }
        let dec = JSONDecoder()
        dec.dateDecodingStrategy = .iso8601
        return (try? dec.decode(ExportRecord.self, from: data)) ?? ExportRecord()
    }

    func save(_ session: URL) throws {
        let url = Self.url(for: session)
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        let enc = JSONEncoder()
        enc.outputFormatting = [.prettyPrinted, .sortedKeys]
        enc.dateEncodingStrategy = .iso8601
        try enc.encode(self).write(to: url)
    }

    func destination(dataDir: URL, project: String) -> Destination? {
        destinations.first { $0.dataDir == dataDir.path && $0.projectID == project }
    }

    mutating func set(_ d: Destination) {
        destinations.removeAll { $0.dataDir == d.dataDir && $0.projectID == d.projectID }
        destinations.append(d)
    }
}

/// Sends a session to a grid: one node for the session, one child per mark (context = the mark's
/// Markdown, images = its screenshot and frame). Marks exported before are updated in place: their
/// context and the images this app added are replaced, and anything edited in the grid (title, status,
/// other images) is kept.
struct PgmExporter {
    var session: SessionData
    var folder: URL
    var target: ExportTarget
    var projectID: String
    var marks: [SessionMark]

    enum Step: Equatable { case progress(String, Double), done(created: Int, updated: Int) }

    func run(progress: @escaping @MainActor (Step) -> Void) async throws {
        let pgm = Pgm(dataDir: target.dataDir)
        var record = ExportRecord.load(folder)
        var dest = record.destination(dataDir: target.dataDir, project: projectID)
        let scratch = FileManager.default.temporaryDirectory.appendingPathComponent("context-recorder-export-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: scratch, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: scratch) }

        let total = Double(marks.count + 1)
        await progress(.progress("Session", 0))

        // Session node: reuse it unless it was deleted from the grid.
        let sessionContext = scratch.appendingPathComponent("session.md")
        try sessionMarkdown.write(to: sessionContext, atomically: true, encoding: .utf8)
        var sessionNode = dest?.sessionNodeID
        if let id = sessionNode, try await pgm.nodeExists(id, project: projectID) {
            try await pgm.setContext(id, project: projectID, file: sessionContext)
        } else {
            sessionNode = try await pgm.createNode(project: projectID, title: sessionTitle,
                                                   parent: target.parentNodeID, contextFile: sessionContext)
            dest = nil   // its mark children went with it
        }
        guard let sessionNode else { return }
        var markNodes = dest?.marks ?? [:]
        var created = 0, updated = 0

        for (i, mark) in marks.enumerated() {
            await progress(.progress("Mark \(mark.index): \(MarkText.title(mark))", Double(i + 1) / total))
            let context = scratch.appendingPathComponent("mark-\(mark.index).md")
            try MarkText.markdown(mark, folder: folder.path).write(to: context, atomically: true, encoding: .utf8)
            let images = imageFiles(for: mark)
            let key = String(mark.index)

            if let prior = markNodes[key], try await pgm.nodeExists(prior.nodeID, project: projectID) {
                try await pgm.setContext(prior.nodeID, project: projectID, file: context)
                for image in prior.imageIDs { try await pgm.removeImage(prior.nodeID, image: image, project: projectID) }
                let added = try await pgm.addImages(prior.nodeID, project: projectID, files: images)
                markNodes[key] = .init(nodeID: prior.nodeID, imageIDs: added)
                updated += 1
            } else {
                let title = String(MarkText.title(mark).prefix(120))
                let id = try await pgm.createNode(project: projectID, title: title, parent: sessionNode, contextFile: context)
                let added = try await pgm.addImages(id, project: projectID, files: images)
                markNodes[key] = .init(nodeID: id, imageIDs: added)
                created += 1
            }
            // Save as we go so a failure halfway through doesn't duplicate the marks already sent.
            record.set(.init(dataDir: target.dataDir.path, projectID: projectID, sessionNodeID: sessionNode,
                             marks: markNodes, exportedAt: .now))
            try record.save(folder)
        }
        record.set(.init(dataDir: target.dataDir.path, projectID: projectID, sessionNodeID: sessionNode,
                         marks: markNodes, exportedAt: .now))
        try record.save(folder)
        await progress(.done(created: created, updated: updated))
    }

    private func imageFiles(for mark: SessionMark) -> [URL] {
        var files: [String] = []
        if let image = mark.image { files.append(image) }
        if mark.isShot, let frame = mark.frame, frame != mark.image { files.append(frame) }
        return files.map { folder.appendingPathComponent($0) }.filter { FileManager.default.fileExists(atPath: $0.path) }
    }

    var sessionTitle: String {
        "Session · " + SessionTitle.title(for: folder)
    }

    private var sessionMarkdown: String {
        let apps = Array(Set(session.activity.compactMap { $0.context?.appName })).sorted()
        var lines = [
            "# \(sessionTitle)", "",
            "Recorded with Context Recorder. Each child node is one mark: what was on screen, what was said and the page context.", "",
            "- **Length:** \(Format.time(session.duration ?? 0))",
            "- **Marks:** \(session.marks.count)",
        ]
        if !apps.isEmpty { lines.append("- **Apps:** \(apps.joined(separator: ", "))") }
        lines.append("- **Folder:** `\(folder.path)`")
        lines.append("- **Video:** `\(folder.path)/recording.mp4`")
        if !session.transcript.isEmpty {
            lines += ["", "## Narration", ""]
            lines += session.transcript.map { "- `\(Format.time($0.start))` \($0.text)" }
        }
        return lines.joined(separator: "\n") + "\n"
    }
}

/// "Oct 12, 2026 · 10:00 PM" from a session folder named yyyy-MM-dd_HH-mm-ss; the folder name otherwise.
enum SessionTitle {
    static func title(for folder: URL) -> String {
        if let custom = SessionInfo.title(folder) { return custom }
        let name = folder.lastPathComponent
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd_HH-mm-ss"
        f.locale = Locale(identifier: "en_US_POSIX")
        guard let date = f.date(from: name) else { return name }
        return date.formatted(.dateTime.month(.abbreviated).day().year()) + " · " + date.formatted(date: .omitted, time: .shortened)
    }
}
