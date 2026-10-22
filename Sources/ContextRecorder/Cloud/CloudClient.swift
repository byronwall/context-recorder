import Foundation
import Security

/// Talks to the cloud Worker (contract §2 and §5): announce a manifest, upload the blobs it lacks
/// (one PUT each, or R2 multipart above 90 MB), then commit.
struct CloudClient {
    var baseURL: URL
    var headers: [String: String] = [:]
    var session: URLSession = .shared
    /// Files above this go up in parts.
    var multipartThreshold: Int64 = 90 * 1024 * 1024
    /// R2 wants equal parts of at least 5 MB (all but the last).
    var partSize: Int64 = 64 * 1024 * 1024

    struct CommitResult: Codable, Equatable { var url: String; var manifestSha256: String }
    /// What a push did, for tests and the CLI.
    struct Report { var result: CommitResult; var uploaded: [String]; var uploadedBytes: Int64; var multipart: [String] }

    struct HTTPError: LocalizedError {
        var status: Int; var body: String; var path: String
        var errorDescription: String? {
            let detail = body.trimmingCharacters(in: .whitespacesAndNewlines).prefix(300)
            if status == 401 || status == 403 { return "The cloud refused the request (\(status)). Check the service token in Cloud Settings." }
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

        let first: Missing = try await json("POST", "api/sessions/\(id)/push", body: manifestData)
        var uploaded: [String] = [], multipart: [String] = []
        var bytes: Int64 = 0
        func upload(_ hashes: [String]) async throws {
            // A hash can appear on several paths; one copy of the bytes is enough.
            let files = Dictionary(manifest.files.map { ($0.sha256, $0) }, uniquingKeysWith: { a, _ in a })
            let wanted = hashes.reduce(into: [String]()) { if !$0.contains($1) { $0.append($1) } }.compactMap { files[$0] }
            let total = wanted.reduce(Int64(0)) { $0 + $1.size }
            var done: Int64 = 0
            progress?(0, total)
            for file in wanted {
                let url = bundle.appendingPathComponent(file.path)
                if file.size > multipartThreshold {
                    try await uploadParts(url, sha: file.sha256, size: file.size) { done += $0; progress?(done, total) }
                    multipart.append(file.path)
                } else {
                    try await send("PUT", "api/blobs/\(file.sha256)", body: try Data(contentsOf: url),
                                   contentType: "application/octet-stream")
                    done += file.size
                    progress?(done, total)
                }
                uploaded.append(file.path)
                bytes += file.size
            }
            let unknown = hashes.filter { files[$0] == nil }
            if !unknown.isEmpty { throw ReviewError("The cloud asked for blobs that aren't in this bundle: \(unknown.prefix(3).joined(separator: ", "))") }
        }
        try await upload(first.missing)

        // Commit; if blobs vanished in between (409), upload them and try once more.
        for attempt in 0..<2 {
            let (data, status) = try await request("POST", "api/sessions/\(id)/commit", body: manifestData)
            if status == 409, attempt == 0, let missing = try? JSONDecoder().decode(Missing.self, from: data) {
                try await upload(missing.missing)
                continue
            }
            try check(status, data, "commit")
            let result = try JSONDecoder().decode(CommitResult.self, from: data)
            return Report(result: result, uploaded: uploaded, uploadedBytes: bytes, multipart: multipart)
        }
        throw ReviewError("The cloud kept reporting missing files on commit")
    }

    private func uploadParts(_ url: URL, sha: String, size: Int64, sent: (Int64) -> Void) async throws {
        struct Upload: Decodable { var uploadId: String }
        struct Part: Codable { var partNumber: Int; var etag: String }
        let upload: Upload = try await json("POST", "api/blobs/\(sha)/uploads", body: Data("{}".utf8))
        let handle = try FileHandle(forReadingFrom: url)
        defer { try? handle.close() }
        var parts: [Part] = []
        var offset: Int64 = 0
        var number = 1
        while offset < size {
            try handle.seek(toOffset: UInt64(offset))
            let chunk = try handle.read(upToCount: Int(min(partSize, size - offset))) ?? Data()
            guard !chunk.isEmpty else { break }
            struct ETag: Decodable { var etag: String }
            let tag: ETag = try await json("PUT", "api/blobs/\(sha)/uploads/\(upload.uploadId)/\(number)", body: chunk,
                                           contentType: "application/octet-stream")
            parts.append(Part(partNumber: number, etag: tag.etag))
            offset += Int64(chunk.count)
            number += 1
            sent(Int64(chunk.count))
        }
        let body = try JSONEncoder().encode(["parts": parts])
        try await send("POST", "api/blobs/\(sha)/uploads/\(upload.uploadId)/complete", body: body)
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

    func request(_ method: String, _ path: String, body: Data?, contentType: String = "application/json") async throws -> (Data, Int) {
        var req = URLRequest(url: baseURL.appendingPathComponent(path))
        req.httpMethod = method
        req.timeoutInterval = 600
        for (k, v) in headers { req.setValue(v, forHTTPHeaderField: k) }
        if let body {
            req.httpBody = body
            req.setValue(contentType, forHTTPHeaderField: "Content-Type")
        }
        let (data, response) = try await session.data(for: req)
        // Access answers an unauthenticated request with a redirect to its login page.
        if let http = response as? HTTPURLResponse, let final = http.url, final.host != baseURL.host || final.path.contains("/cdn-cgi/access/") {
            throw HTTPError(status: 401, body: "redirected to \(final.host ?? "")", path: path)
        }
        return (data, (response as? HTTPURLResponse)?.statusCode ?? 0)
    }
}

// MARK: - Configuration

/// Where to push and how to authenticate. The cloud URL lives in UserDefaults (`cloudURL`), the Access
/// service token in the Keychain (service `ContextRecorder.Cloud`); the CLI also reads `CR_CLOUD_URL`,
/// `CR_CLOUD_CLIENT_ID` and `CR_CLOUD_CLIENT_SECRET`.
struct CloudConfig {
    var url: URL
    var clientId: String?
    var clientSecret: String?

    var headers: [String: String] {
        guard let clientId, !clientId.isEmpty, let clientSecret, !clientSecret.isEmpty else { return [:] }
        return ["CF-Access-Client-Id": clientId, "CF-Access-Client-Secret": clientSecret]
    }

    var client: CloudClient { CloudClient(baseURL: url, headers: headers) }

    /// `override` (`--cloud <url>`) first, then the environment, then the app's settings.
    static func current(override: String? = nil, environment: [String: String] = ProcessInfo.processInfo.environment) -> CloudConfig? {
        let raw = [override, environment["CR_CLOUD_URL"], CloudSettings.urlString]
            .compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines) }.first { !$0.isEmpty }
        guard let raw, let url = CloudSettings.normalized(raw) else { return nil }
        let token = CloudSettings.token()
        return CloudConfig(url: url,
                           clientId: environment["CR_CLOUD_CLIENT_ID"] ?? token?.id,
                           clientSecret: environment["CR_CLOUD_CLIENT_SECRET"] ?? token?.secret)
    }
}

enum CloudSettings {
    static let urlKey = "cloudURL"
    static let keychainService = "ContextRecorder.Cloud"
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

    /// The service token: the Keychain item's account is the client id, its data the secret.
    static func token() -> (id: String, secret: String)? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecReturnAttributes as String: true,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]
        var item: CFTypeRef?
        guard SecItemCopyMatching(query as CFDictionary, &item) == errSecSuccess, let dict = item as? [String: Any],
              let id = dict[kSecAttrAccount as String] as? String, let data = dict[kSecValueData as String] as? Data,
              let secret = String(data: data, encoding: .utf8) else { return nil }
        return (id, secret)
    }

    /// Replaces the stored token; empty values remove it.
    static func setToken(id: String, secret: String) throws {
        let base: [String: Any] = [kSecClass as String: kSecClassGenericPassword, kSecAttrService as String: keychainService]
        SecItemDelete(base as CFDictionary)
        let id = id.trimmingCharacters(in: .whitespacesAndNewlines), secret = secret.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !id.isEmpty, !secret.isEmpty else { return }
        var add = base
        add[kSecAttrAccount as String] = id
        add[kSecValueData as String] = Data(secret.utf8)
        add[kSecAttrLabel as String] = "Context Recorder cloud service token"
        let status = SecItemAdd(add as CFDictionary, nil)
        guard status == errSecSuccess else { throw ReviewError("Couldn't save the service token to the Keychain (\(status))") }
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
        let manifest = try await CloudBundle.build(session: session, to: temp) { phase, f in progress?(phase == "Done" ? "Uploading" : phase, f * 0.5) }
        let report = try await config.client.push(bundle: temp) { done, total in
            let f = total > 0 ? Double(done) / Double(total) : 1
            progress?("Uploading \(ByteCountFormatter.string(fromByteCount: done, countStyle: .file)) of \(ByteCountFormatter.string(fromByteCount: total, countStyle: .file))", 0.5 + 0.48 * f)
        }
        let iso = ISO8601DateFormatter()
        iso.timeZone = .current
        let record = CloudRecord(url: report.result.url, manifestSha256: report.result.manifestSha256,
                                 inputHash: manifest.inputHash, pushedAt: iso.string(from: .now))
        try record.save(to: session)
        progress?("Pushed", 1)
        return (record, report)
    }
}
