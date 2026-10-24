import CryptoKit
import Foundation

/// A session in the cloud, as `GET /api/sessions` lists it (docs/cloud-sessions.md §2).
struct CloudSessionRow: Codable, Identifiable, Equatable, Hashable {
    var id: String
    var title: String
    var recordedAt: String
    var duration: Double
    var markCount: Int
    var size: Int64
    var poster: String?
    var pushedAt: String
    /// The Mac that pushed it; nil for pushes from before the manifest named it.
    var machine: String?
}

extension CloudClient {
    func listSessions() async throws -> [CloudSessionRow] {
        try await json("GET", "api/sessions", body: nil)
    }

    /// A session file's API path. `/api/*` reaches the Worker's bearer check; `/s/*` sits behind Access (browsers only).
    static func filePath(_ id: String, _ path: String) -> String { "api/sessions/\(id)/files/\(path)" }

    /// The session's manifest exactly as it was pushed, so its sha256 is the cloud's `manifestSha256`.
    func manifestData(_ id: String) async throws -> Data {
        let (data, status) = try await request("GET", Self.filePath(id, "manifest.json"), body: nil)
        try check(status, data, "manifest.json")
        return data
    }

    /// Bytes `offset…offset+length-1` of a file in the session. A server that ignores the range answers 200 with
    /// the whole file; `whole` says which one came back.
    func fileRange(_ id: String, _ path: String, offset: Int64, length: Int64) async throws -> (data: Data, whole: Bool) {
        let (data, status) = try await request("GET", Self.filePath(id, path), body: nil,
                                               headers: ["Range": "bytes=\(offset)-\(offset + length - 1)"])
        try check(status, data, path)
        return (data, status == 200)
    }
}

/// Downloads a cloud session into the library (docs/cloud-sessions.md §7): every file in its manifest, checked
/// against its sha256, into a hidden `.<id>.partial` folder that becomes `<id>` when complete. The result is
/// an ordinary session folder: the cloud copy is already flat (one video, edited-time marks and drawings).
@MainActor
enum CloudPull {
    /// Big files come down in pieces this size, so a dropped connection costs one piece, not the whole video.
    nonisolated static let chunkSize: Int64 = 32 * 1024 * 1024

    static func partialFolder(_ id: String, in root: URL) -> URL { root.appendingPathComponent(".\(id).partial") }

    @discardableResult
    static func run(id: String, config: CloudConfig, client: CloudClient? = nil, into root: URL = Session.root,
                    progress: ((String, Double) -> Void)? = nil) async throws -> URL {
        let client = client ?? config.client
        let fm = FileManager.default
        let target = root.appendingPathComponent(id)
        guard CloudBundle.sessionID(for: target) == id else { throw ReviewError("\(id) isn't a session id") }
        if fm.fileExists(atPath: target.path) { throw ReviewError("\(id) is already in your library") }

        progress?("Reading the cloud copy", 0)
        let manifestData = try await client.manifestData(id)
        let manifest = try JSONDecoder().decode(CloudManifest.self, from: manifestData)
        guard manifest.sessionId == id else { throw ReviewError("The cloud sent the manifest for \(manifest.sessionId), not \(id)") }
        for file in manifest.files where !isSafe(file.path) { throw ReviewError("The cloud copy lists an unsafe path: \(file.path)") }

        // A partial folder from an earlier attempt is kept: files already there and intact aren't fetched again.
        let partial = partialFolder(id, in: root)
        try fm.createDirectory(at: partial, withIntermediateDirectories: true)
        let total = max(1, manifest.files.reduce(Int64(0)) { $0 + $1.size })
        var done: Int64 = 0
        func report() {
            let text = "Downloading \(ByteCountFormatter.string(fromByteCount: done, countStyle: .file)) of \(ByteCountFormatter.string(fromByteCount: total, countStyle: .file))"
            progress?(text, 0.02 + 0.95 * Double(done) / Double(total))
        }
        for file in manifest.files {
            let url = partial.appendingPathComponent(file.path)
            try await fetch(file, id: id, to: url, client: client) { done += $0; report() }
        }

        // Where it came from; then the folder appears in the library in one step.
        progress?("Finishing", 0.98)
        if manifest.title != id { try SessionInfo.setTitle(manifest.title, for: partial) }
        let iso = ISO8601DateFormatter()
        iso.timeZone = .current
        try SessionInfo.setDownloaded(.init(machine: manifest.machine, cloud: config.url.absoluteString, at: iso.string(from: .now)), for: partial)
        try fm.moveItem(at: partial, to: target)

        // Recorded as pushed and current, so it doesn't offer to push straight back what just came down.
        let manifestSha = SHA256.hash(data: manifestData).map { String(format: "%02x", $0) }.joined()
        let record = CloudRecord(url: config.url.appendingPathComponent("s/\(id)/").absoluteString, manifestSha256: manifestSha,
                                 inputHash: try CloudBundle.inputHash(session: target), pushedAt: iso.string(from: .now))
        try record.save(to: target)
        progress?("Downloaded", 1)
        return target
    }

    /// One file: skipped when already complete and intact, otherwise fetched (or continued) a piece at a time.
    private static func fetch(_ file: CloudManifest.File, id: String, to url: URL, client: CloudClient,
                              received: (Int64) -> Void) async throws {
        let fm = FileManager.default
        try fm.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        var have = (try? fm.attributesOfItem(atPath: url.path)[.size] as? Int64) ?? 0
        if have == file.size, (try? CloudBundle.sha256(of: url)) == file.sha256 { received(file.size); return }
        if have > file.size { have = 0 }
        if have == 0 { fm.createFile(atPath: url.path, contents: nil) }
        received(have)
        let handle = try FileHandle(forWritingTo: url)
        defer { try? handle.close() }
        try handle.truncate(atOffset: UInt64(have))
        while have < file.size {
            let (data, whole) = try await client.fileRange(id, file.path, offset: have, length: min(chunkSize, file.size - have))
            if whole {
                // No range support: start over with the whole file.
                received(-have)
                try handle.truncate(atOffset: 0)
                have = 0
            }
            guard !data.isEmpty else { throw ReviewError("The cloud sent nothing for \(file.path)") }
            try handle.write(contentsOf: data)
            have += Int64(data.count)
            received(Int64(data.count))
        }
        try handle.close()
        guard have == file.size, try CloudBundle.sha256(of: url) == file.sha256 else {
            try? fm.removeItem(at: url)
            throw ReviewError("\(file.path) didn't match its checksum; try the download again")
        }
    }

    /// Relative, `/`-separated, no `..`, and never one of the session's own bookkeeping files.
    nonisolated static func isSafe(_ path: String) -> Bool {
        let parts = path.split(separator: "/", omittingEmptySubsequences: false)
        guard !path.isEmpty, !path.hasPrefix("/"), !path.contains("\\"),
              parts.allSatisfy({ !$0.isEmpty && $0 != "." && $0 != ".." }) else { return false }
        return !["session-info.json", "exports"].contains(String(parts[0]))
    }
}

extension SessionInfo {
    /// `session-info.json` → `downloaded`: a session that came down from the cloud rather than being recorded here.
    struct Downloaded: Codable, Equatable {
        /// The Mac that pushed it, when the cloud copy says.
        var machine: String?
        var cloud: String
        var at: String
    }

    static func downloaded(_ folder: URL) -> Downloaded? {
        struct File: Decodable { var downloaded: Downloaded? }
        guard let data = try? Data(contentsOf: url(folder)) else { return nil }
        return (try? JSONDecoder().decode(File.self, from: data))?.downloaded
    }

    static func setDownloaded(_ value: Downloaded, for folder: URL) throws {
        var obj = (try? Data(contentsOf: url(folder))).flatMap { try? JSONSerialization.jsonObject(with: $0) as? [String: Any] } ?? [:]
        obj["downloaded"] = try JSONSerialization.jsonObject(with: JSONEncoder().encode(value))
        let data = try JSONSerialization.data(withJSONObject: obj, options: [.prettyPrinted, .sortedKeys])
        try data.write(to: url(folder), options: .atomic)
    }
}
