import Foundation

/// Talks to the cloud Worker (docs/cloud-sessions.md §2 and §5): announce a manifest, upload the blobs it lacks
/// (one PUT each, or R2 multipart above 90 MB) several at a time, then commit.
struct CloudClient {
    var baseURL: URL
    /// Supplies `Authorization: Bearer`; nil, or signed out, sends no header (a local dev Worker accepts that).
    var auth: CloudTokenProvider?
    var session: URLSession = .shared
    /// Files above this go up in parts.
    var multipartThreshold: Int64 = 90 * 1024 * 1024
    /// R2 wants equal parts of at least 5 MB (all but the last).
    var partSize: Int64 = 64 * 1024 * 1024
    /// Requests in flight at once. A long session has hundreds of thumbnails, and one at a time each waits a
    /// full round trip through the Worker (token, D1, R2), which dominates the push.
    var concurrency = 8
    /// Of those, multipart parts in flight at once (each holds `partSize` bytes in memory).
    var partConcurrency = 3

    struct CommitResult: Codable, Equatable { var url: String; var manifestSha256: String }
    /// How long one step of a push took.
    struct Timing: Equatable {
        var phase: String; var seconds: Double
        /// `Preparing 0.1 s · Making thumbnails 3.5 s · …`, repeated phases added together.
        static func summary(_ timings: [Timing]) -> String {
            var order: [String] = [], sums: [String: Double] = [:]
            for t in timings {
                if sums[t.phase] == nil { order.append(t.phase) }
                sums[t.phase, default: 0] += t.seconds
            }
            return order.map { String(format: "%@ %.1f s", $0, sums[$0]!) }.joined(separator: " · ")
        }
    }
    /// What a push did, for tests and the CLI.
    struct Report {
        var result: CommitResult; var uploaded: [String]; var uploadedBytes: Int64; var multipart: [String]
        var timings: [Timing] = []
    }

    struct HTTPError: LocalizedError {
        var status: Int; var body: String; var path: String
        var errorDescription: String? {
            let detail = body.trimmingCharacters(in: .whitespacesAndNewlines).prefix(300)
            if status == 401 || status == 403 { return CloudAuthError.signInRequired.errorDescription }
            return "Cloud request \(path) failed (\(status))" + (detail.isEmpty ? "" : ": \(detail)")
        }
    }

    typealias Progress = (_ done: Int64, _ total: Int64) -> Void

    /// Pushes the bundle folder written by `CloudBundle.build`.
    func push(bundle: URL, progress: Progress? = nil) async throws -> Report {
        let manifestData = try Data(contentsOf: bundle.appendingPathComponent("manifest.json"))
        let manifest = try JSONDecoder().decode(CloudManifest.self, from: manifestData)
        let id = manifest.sessionId
        struct Missing: Decodable { var missing: [String] }
        var timings: [Timing] = []
        func timed<T>(_ phase: String, _ work: () async throws -> T) async rethrows -> T {
            let start = Date()
            defer { timings.append(Timing(phase: phase, seconds: Date().timeIntervalSince(start))) }
            return try await work()
        }

        let first: Missing = try await timed("Checking") { try await json("POST", "api/sessions/\(id)/push", body: manifestData) }
        var uploaded: [String] = [], multipart: [String] = []
        var bytes: Int64 = 0
        func upload(_ hashes: [String]) async throws {
            // A hash can appear on several paths; one copy of the bytes is enough.
            let files = Dictionary(manifest.files.map { ($0.sha256, $0) }, uniquingKeysWith: { a, _ in a })
            let unknown = hashes.filter { files[$0] == nil }
            if !unknown.isEmpty { throw ReviewError("The cloud asked for blobs that aren't in this bundle: \(unknown.prefix(3).joined(separator: ", "))") }
            let wanted = hashes.reduce(into: [String]()) { if !$0.contains($1) { $0.append($1) } }.compactMap { files[$0] }
            try await uploadAll(wanted, in: bundle, progress: progress)
            for file in wanted {
                uploaded.append(file.path)
                if file.size > multipartThreshold { multipart.append(file.path) }
                bytes += file.size
            }
        }
        try await timed("Uploading") { try await upload(first.missing) }

        // Commit; if blobs vanished in between (409), upload them and try once more.
        for attempt in 0..<2 {
            let (data, status) = try await timed("Committing") { try await request("POST", "api/sessions/\(id)/commit", body: manifestData) }
            if status == 409, attempt == 0, let missing = try? JSONDecoder().decode(Missing.self, from: data) {
                try await timed("Uploading") { try await upload(missing.missing) }
                continue
            }
            try check(status, data, "commit")
            let result = try JSONDecoder().decode(CommitResult.self, from: data)
            return Report(result: result, uploaded: uploaded, uploadedBytes: bytes, multipart: multipart, timings: timings)
        }
        throw ReviewError("The cloud kept reporting missing files on commit")
    }

    /// Uploads `files`: small ones as single PUTs and big ones in parts, all from one pool of `concurrency`
    /// requests (at most `partConcurrency` of them parts). Progress is reported as each request finishes.
    private func uploadAll(_ files: [CloudManifest.File], in bundle: URL, progress: Progress?) async throws {
        struct Upload: Decodable { var uploadId: String }
        struct Part: Codable { var partNumber: Int; var etag: String }
        struct PartJob { var file: Int; var number: Int; var offset: Int64; var length: Int64 }
        enum Done { case blob(Int64); case part(file: Int, Part, Int64) }

        let total = files.reduce(Int64(0)) { $0 + $1.size }
        var done: Int64 = 0
        progress?(0, total)

        // Start each multipart upload first, so its parts can share the pool with the small files.
        var small: [Int] = [], parts: [PartJob] = []
        var uploadIds: [Int: String] = [:], etags: [Int: [Part]] = [:]
        for (i, file) in files.enumerated() {
            guard file.size > multipartThreshold else { small.append(i); continue }
            let upload: Upload = try await json("POST", "api/blobs/\(file.sha256)/uploads", body: Data("{}".utf8))
            uploadIds[i] = upload.uploadId
            var offset: Int64 = 0, number = 1
            while offset < file.size {
                let length = min(partSize, file.size - offset)
                parts.append(PartJob(file: i, number: number, offset: offset, length: length))
                offset += length
                number += 1
            }
        }

        try await withThrowingTaskGroup(of: Done.self) { group in
            var running = 0, runningParts = 0
            func fill() {
                while runningParts < max(1, partConcurrency), running < max(1, concurrency), !parts.isEmpty {
                    let job = parts.removeFirst(), file = files[job.file], uploadId = uploadIds[job.file]!
                    let url = bundle.appendingPathComponent(file.path)
                    running += 1; runningParts += 1
                    group.addTask {
                        let handle = try FileHandle(forReadingFrom: url)
                        defer { try? handle.close() }
                        try handle.seek(toOffset: UInt64(job.offset))
                        let chunk = try handle.read(upToCount: Int(job.length)) ?? Data()
                        guard chunk.count == job.length else { throw ReviewError("\(file.path) changed while uploading") }
                        struct ETag: Decodable { var etag: String }
                        let tag: ETag = try await json("PUT", "api/blobs/\(file.sha256)/uploads/\(uploadId)/\(job.number)",
                                                       body: chunk, contentType: "application/octet-stream")
                        return .part(file: job.file, Part(partNumber: job.number, etag: tag.etag), job.length)
                    }
                }
                while running < max(1, concurrency), !small.isEmpty {
                    let file = files[small.removeFirst()]
                    let url = bundle.appendingPathComponent(file.path)
                    running += 1
                    group.addTask {
                        try await send("PUT", "api/blobs/\(file.sha256)", body: try Data(contentsOf: url),
                                       contentType: "application/octet-stream")
                        return .blob(file.size)
                    }
                }
            }
            fill()
            while let result = try await group.next() {
                running -= 1
                switch result {
                case .blob(let size):
                    done += size
                case .part(let i, let part, let size):
                    runningParts -= 1
                    done += size
                    etags[i, default: []].append(part)
                }
                progress?(done, total)
                fill()
            }
        }

        for (i, uploadId) in uploadIds.sorted(by: { $0.key < $1.key }) {
            let list = (etags[i] ?? []).sorted { $0.partNumber < $1.partNumber }
            let body = try JSONEncoder().encode(["parts": list])
            try await send("POST", "api/blobs/\(files[i].sha256)/uploads/\(uploadId)/complete", body: body)
        }
    }

    // MARK: HTTP

    private func json<T: Decodable>(_ method: String, _ path: String, body: Data?, contentType: String = "application/json") async throws -> T {
        let (data, status) = try await request(method, path, body: body, contentType: contentType)
        try check(status, data, path)
        do { return try JSONDecoder().decode(T.self, from: data) } catch {
            throw ReviewError("Unexpected reply from \(path): \(String(decoding: data.prefix(200), as: UTF8.self))")
        }
    }

    private func send(_ method: String, _ path: String, body: Data?, contentType: String = "application/json") async throws {
        let (data, status) = try await request(method, path, body: body, contentType: contentType)
        try check(status, data, path)
    }

    private func check(_ status: Int, _ data: Data, _ path: String) throws {
        guard (200..<300).contains(status) else { throw HTTPError(status: status, body: String(decoding: data, as: UTF8.self), path: path) }
    }

    /// Sends with the current token; on a 401 refreshes once and retries.
    func request(_ method: String, _ path: String, body: Data?, contentType: String = "application/json") async throws -> (Data, Int) {
        let token = try await auth?.token(for: baseURL)
        let (data, status) = try await attempt(method, path, body: body, contentType: contentType, token: token)
        guard status == 401, let auth else { return (data, status) }
        if token == nil, await !auth.isFixed {
            // Signed out and the cloud wants a sign-in.
            throw CloudAuthError.signInRequired
        }
        let fresh = try await auth.token(for: baseURL, after: token)
        let retry = try await attempt(method, path, body: body, contentType: contentType, token: fresh)
        if retry.1 == 401 { throw CloudAuthError.signInRequired }
        return retry
    }

    private func attempt(_ method: String, _ path: String, body: Data?, contentType: String, token: String?) async throws -> (Data, Int) {
        var req = URLRequest(url: baseURL.appendingPathComponent(path))
        req.httpMethod = method
        req.timeoutInterval = 600
        if let token { req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization") }
        if let body {
            req.httpBody = body
            req.setValue(contentType, forHTTPHeaderField: "Content-Type")
        }
        let (data, response) = try await session.data(for: req)
        // Access answers an unauthenticated request with a redirect to its login page.
        if let http = response as? HTTPURLResponse, let final = http.url, final.host != baseURL.host || final.path.contains("/cdn-cgi/access/") {
            return (Data("redirected to \(final.host ?? "")".utf8), 401)
        }
        return (data, (response as? HTTPURLResponse)?.statusCode ?? 0)
    }
}

// MARK: - Configuration

/// Where to push and how to authenticate. The cloud URL lives in UserDefaults (`cloudURL`); the sign-in lives in
/// a private file (`FileAuthStore`). The CLI also reads `CR_CLOUD_URL`, and `CR_CLOUD_TOKEN` (a raw access token)
/// overrides the stored sign-in.
struct CloudConfig {
    var url: URL
    /// `CR_CLOUD_TOKEN`.
    var token: String?
    var store: CloudAuthStore = FileAuthStore()

    var auth: CloudTokenProvider {
        if let token, !token.isEmpty { return CloudTokenProvider(token: token) }
        // A local dev Worker needs no sign-in, so it never sends the saved one.
        if store is FileAuthStore, CloudAuth.isLocal(url) { return CloudTokenProvider(store: MemoryAuthStore()) }
        return store is FileAuthStore ? .saved : CloudTokenProvider(store: store)
    }

    var client: CloudClient { CloudClient(baseURL: url, auth: auth) }

    /// Signed in to this URL, or a token supplied for it.
    var hasCredentials: Bool {
        if let token, !token.isEmpty { return true }
        return store.load()?.matches(url) == true
    }

    /// `override` (`--cloud <url>`) first, then the environment, then the app's settings.
    static func current(override: String? = nil, environment: [String: String] = ProcessInfo.processInfo.environment) -> CloudConfig? {
        let raw = [override, environment["CR_CLOUD_URL"], CloudSettings.urlString]
            .compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines) }.first { !$0.isEmpty }
        guard let raw, let url = CloudSettings.normalized(raw) else { return nil }
        let token = environment["CR_CLOUD_TOKEN"]?.trimmingCharacters(in: .whitespacesAndNewlines)
        return CloudConfig(url: url, token: token?.isEmpty == false ? token : nil)
    }
}

enum CloudSettings {
    static let urlKey = "cloudURL"
    /// The app's defaults domain, so `swift run` (which has its own domain) sees the app's setting too.
    static let appDomain = "com.byronwall.ContextRecorder"

    static var urlString: String? {
        get {
            let own = UserDefaults.standard.string(forKey: urlKey)
            if let own, !own.isEmpty { return own }
            return UserDefaults(suiteName: appDomain)?.string(forKey: urlKey)
        }
        set {
            let value = newValue?.trimmingCharacters(in: .whitespacesAndNewlines)
            if let value, !value.isEmpty { UserDefaults.standard.set(value, forKey: urlKey) } else { UserDefaults.standard.removeObject(forKey: urlKey) }
        }
    }

    /// `sessions.example.com` → `https://sessions.example.com/`; nil when it isn't an http(s) URL.
    static func normalized(_ raw: String) -> URL? {
        var s = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !s.isEmpty else { return nil }
        if !s.contains("://") { s = (s.hasPrefix("localhost") || s.hasPrefix("127.") ? "http://" : "https://") + s }
        guard let url = URL(string: s), let scheme = url.scheme?.lowercased(), ["http", "https"].contains(scheme), url.host != nil else { return nil }
        return url
    }
}

// MARK: - exports/cloud.json

/// What was last pushed: `<session>/exports/cloud.json`.
struct CloudRecord: Codable, Equatable {
    var url: String
    var manifestSha256: String
    var inputHash: String
    var pushedAt: String

    static func url(_ session: URL) -> URL { session.appendingPathComponent("exports/cloud.json") }

    static func load(_ session: URL) -> CloudRecord? {
        guard let data = try? Data(contentsOf: url(session)) else { return nil }
        return try? JSONDecoder().decode(CloudRecord.self, from: data)
    }

    func save(to session: URL) throws {
        let file = Self.url(session)
        try FileManager.default.createDirectory(at: file.deletingLastPathComponent(), withIntermediateDirectories: true)
        let enc = JSONEncoder()
        enc.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        try enc.encode(self).write(to: file, options: .atomic)
    }
}

// MARK: - Push = bundle + upload + record

@MainActor
enum CloudPush {
    /// Builds the cloud copy in a temporary folder, pushes it, writes exports/cloud.json and cleans up.
    static func run(session: URL, config: CloudConfig, progress: ((String, Double) -> Void)? = nil) async throws -> (CloudRecord, CloudClient.Report) {
        let temp = FileManager.default.temporaryDirectory
            .appendingPathComponent("ContextRecorder-cloud/\(CloudBundle.sessionID(for: session))-\(UUID().uuidString.prefix(8))")
        defer { try? FileManager.default.removeItem(at: temp) }
        // Each build phase lasts until the next one starts.
        var timings: [CloudClient.Timing] = []
        var phase: (name: String, start: Date)?
        func enter(_ name: String?) {
            if let phase { timings.append(.init(phase: phase.name, seconds: Date().timeIntervalSince(phase.start))) }
            phase = name.map { ($0, Date()) }
        }
        let manifest = try await CloudBundle.build(session: session, to: temp) { name, f in
            if name != "Done", name != phase?.name { enter(name) }
            progress?(name == "Done" ? "Uploading" : name, f * 0.5)
        }
        enter(nil)
        var report = try await config.client.push(bundle: temp) { done, total in
            let f = total > 0 ? Double(done) / Double(total) : 1
            progress?("Uploading \(ByteCountFormatter.string(fromByteCount: done, countStyle: .file)) of \(ByteCountFormatter.string(fromByteCount: total, countStyle: .file))", 0.5 + 0.48 * f)
        }
        report.timings = timings + report.timings
        let iso = ISO8601DateFormatter()
        iso.timeZone = .current
        let record = CloudRecord(url: report.result.url, manifestSha256: report.result.manifestSha256,
                                 inputHash: manifest.inputHash, pushedAt: iso.string(from: .now))
        try record.save(to: session)
        progress?("Pushed", 1)
        return (record, report)
    }
}
