import Foundation
import Observation

/// One session folder in the sidebar. Summary fields come from session.json when it exists.
struct SessionEntry: Identifiable, Hashable {
    var url: URL
    var date: Date?
    var processed: Bool          // session.json exists
    var duration: Double?
    var markCount: Int
    var shotCount: Int
    var thumbnail: URL?
    var appBundleIDs: [String] = []   // apps used, in order of first appearance
    var modified: Date?

    var id: URL { url }

    var title: String {
        guard let date else { return url.lastPathComponent }
        return date.formatted(.dateTime.month(.abbreviated).day().year().hour().minute())
    }
}

/// Every session under ~/Movies/ContextRecorder plus any folders the user opened or dropped in.
/// Polls every couple of seconds so new recordings and re-processing show up without a reload button.
@MainActor @Observable
final class SessionLibrary {
    private(set) var entries: [SessionEntry] = []
    /// Bumped when a session's session.json changes, so an open session can reload itself.
    private(set) var changeToken = 0
    var recordingFolder: URL?      // the session being recorded right now, if any

    private var timer: Timer?
    private static let extraFoldersKey = "libraryFolders"

    /// Folders opened or dropped in. Saved, except in dev runs where they only last the session.
    @ObservationIgnored private var devFolders: [URL] = []
    var extraFolders: [URL] {
        get {
            guard includeDefaultRoot else { return devFolders }
            return (UserDefaults.standard.stringArray(forKey: Self.extraFoldersKey) ?? []).map { URL(fileURLWithPath: $0) }
        }
        set {
            guard includeDefaultRoot else { devFolders = newValue; return }
            UserDefaults.standard.set(newValue.map(\.path), forKey: Self.extraFoldersKey)
        }
    }

    /// false for `--library <folder>` dev runs, so only that folder is listed.
    let includeDefaultRoot: Bool

    init(includeDefaultRoot: Bool = true) {
        self.includeDefaultRoot = includeDefaultRoot
        refresh()
        timer = Timer.scheduledTimer(withTimeInterval: 2, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.refresh() }
        }
    }

    /// Adds a session folder (or a folder of sessions) that lives outside the default root.
    /// Returns the session folders it contributed, so the caller can select one.
    @discardableResult
    func add(folder: URL) -> [URL] {
        let found = Self.sessionFolders(in: folder)
        guard !found.isEmpty else { return [] }
        if !(includeDefaultRoot && folder.path.hasPrefix(Session.root.path)), !extraFolders.contains(folder) {
            extraFolders.append(folder)
        }
        refresh()
        return found
    }

    func remove(_ entry: SessionEntry) {
        extraFolders.removeAll { $0 == entry.url || entry.url.path.hasPrefix($0.path + "/") }
        refresh()
    }

    func isExternal(_ entry: SessionEntry) -> Bool { !entry.url.path.hasPrefix(Session.root.path + "/") }

    func refresh() {
        let roots = (includeDefaultRoot ? [Session.root] : []) + extraFolders
        let folders = roots.flatMap(Self.sessionFolders(in:))
        var seen = Set<URL>()
        let old = Dictionary(entries.map { ($0.url, $0) }, uniquingKeysWith: { a, _ in a })
        var next: [SessionEntry] = []
        var changed = false
        for url in folders where seen.insert(url.standardizedFileURL).inserted {
            let modified = Self.modified(url.appendingPathComponent("session.json"))
            if let prior = old[url], prior.modified == modified {
                next.append(prior)
            } else {
                next.append(Self.entry(for: url, modified: modified))
                if old[url] != nil { changed = true }
            }
        }
        next.sort { ($0.date ?? .distantPast, $0.url.path) > ($1.date ?? .distantPast, $1.url.path) }
        if next != entries { entries = next }
        if changed { changeToken += 1 }
    }

    // MARK: Scanning

    static func isSession(_ url: URL) -> Bool {
        let fm = FileManager.default
        return ["session.json", "marks.jsonl", "recording.mp4"].contains {
            fm.fileExists(atPath: url.appendingPathComponent($0).path)
        }
    }

    static func sessionFolders(in folder: URL) -> [URL] {
        if isSession(folder) { return [folder] }
        let children = (try? FileManager.default.contentsOfDirectory(
            at: folder, includingPropertiesForKeys: [.isDirectoryKey], options: [.skipsHiddenFiles])) ?? []
        return children.filter { $0.hasDirectoryPath && isSession($0) }
    }

    private static func modified(_ url: URL) -> Date? {
        (try? FileManager.default.attributesOfItem(atPath: url.path))?[.modificationDate] as? Date
    }

    private static let nameFormat: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd_HH-mm-ss"
        f.locale = Locale(identifier: "en_US_POSIX")
        return f
    }()

    private struct Summary: Decodable {
        struct M: Decodable { var kind: String?; var image: String? }
        struct A: Decodable { struct C: Decodable { var bundleID: String? }; var context: C? }
        var duration: Double?
        var marks: [M]?
        var activity: [A]?
    }

    private static func entry(for url: URL, modified: Date?) -> SessionEntry {
        let date = nameFormat.date(from: url.lastPathComponent)
            ?? (try? url.resourceValues(forKeys: [.creationDateKey]))?.creationDate
        var e = SessionEntry(url: url, date: date, processed: modified != nil, duration: nil,
                             markCount: 0, shotCount: 0, thumbnail: nil, modified: modified)
        if modified != nil,
           let data = try? Data(contentsOf: url.appendingPathComponent("session.json")),
           let s = try? JSONDecoder().decode(Summary.self, from: data) {
            e.duration = s.duration
            e.markCount = s.marks?.count ?? 0
            e.shotCount = s.marks?.filter { $0.kind == "screenshot" }.count ?? 0
            e.thumbnail = s.marks?.first?.image.map { url.appendingPathComponent($0) }
            for id in (s.activity ?? []).compactMap({ $0.context?.bundleID }) where !e.appBundleIDs.contains(id) {
                e.appBundleIDs.append(id)
            }
        } else if let raw = try? String(contentsOf: url.appendingPathComponent("marks.jsonl"), encoding: .utf8) {
            e.markCount = raw.split(separator: "\n").count
        }
        return e
    }
}
