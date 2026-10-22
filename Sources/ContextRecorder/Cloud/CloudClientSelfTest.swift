import CryptoKit
import Foundation

/// `--self-test cloud-client`: CloudClient against an in-memory stand-in for the Worker's push API
/// (contract §2), plus the configuration, path and cloud.json helpers.
extension CloudSelfTest {
    static func runClient() async -> [String] {
        var f: [String] = []
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("cloud-client-selftest-\(UUID().uuidString.prefix(8))")
        defer { try? FileManager.default.removeItem(at: root) }
        do {
            // A bundle: a small file, the same bytes under another path, and one big enough for multipart.
            let bundle = root.appendingPathComponent("bundle")
            try FileManager.default.createDirectory(at: bundle.appendingPathComponent("thumbs"), withIntermediateDirectories: true)
            try Data(repeating: 7, count: 100).write(to: bundle.appendingPathComponent("a.json"))
            try Data(repeating: 7, count: 100).write(to: bundle.appendingPathComponent("thumbs/0000.jpg"))
            var big = Data(count: 12 * 1024 * 1024 + 123)
            big.withUnsafeMutableBytes { for i in stride(from: 0, to: $0.count, by: 4096) { $0[i] = UInt8(i / 4096 % 251) } }
            try big.write(to: bundle.appendingPathComponent("recording.mp4"))
            let manifest = CloudManifest(sessionId: "2026-01-01_00-00-00", title: "t", recordedAt: nil, duration: 1, markCount: 0,
                                         video: .init(path: "recording.mp4", width: 2, height: 2),
                                         thumbs: .init(interval: 2, count: 1, pattern: "thumbs/%04d.jpg", width: 480),
                                         poster: "thumbs/0000.jpg", skippedPages: [], inputHash: "x",
                                         files: try CloudBundle.listFiles(in: bundle))
            try manifest.encoded().write(to: bundle.appendingPathComponent("manifest.json"))
            let manifestSha = try CloudBundle.sha256(of: bundle.appendingPathComponent("manifest.json"))

            let config = URLSessionConfiguration.ephemeral
            config.protocolClasses = [FakeWorker.self]
            FakeWorker.reset(token: "id-1")
            var client = CloudClient(baseURL: URL(string: "http://cloud.test/")!,
                                     headers: ["CF-Access-Client-Id": "id-1", "CF-Access-Client-Secret": "s"],
                                     session: URLSession(configuration: config))
            client.multipartThreshold = 5 * 1024 * 1024
            client.partSize = 5 * 1024 * 1024

            var progressed: [Int64] = []
            let first = try await client.push(bundle: bundle) { done, _ in progressed.append(done) }
            if Set(first.uploaded) != ["a.json", "recording.mp4"] && Set(first.uploaded) != ["thumbs/0000.jpg", "recording.mp4"] {
                f.append("first push uploaded \(first.uploaded), want the small file once and the video")
            }
            if first.multipart != ["recording.mp4"] { f.append("multipart \(first.multipart)") }
            if FakeWorker.state.parts != 3 { f.append("\(FakeWorker.state.parts) parts, want 3") }
            if first.result.manifestSha256 != manifestSha { f.append("manifestSha256 \(first.result.manifestSha256) ≠ \(manifestSha)") }
            if first.result.url != "http://cloud.test/s/2026-01-01_00-00-00/" { f.append("url \(first.result.url)") }
            if progressed.last != Int64(100 + big.count) { f.append("progress ended at \(progressed.last ?? -1)") }

            let second = try await client.push(bundle: bundle)
            if !second.uploaded.isEmpty { f.append("unchanged re-push uploaded \(second.uploaded)") }

            // A blob that disappears before commit: 409, re-upload, commit again.
            FakeWorker.state.dropBeforeCommit = manifest.files.first { $0.path == "a.json" }?.sha256
            let third = try await client.push(bundle: bundle)
            if third.uploaded.count != 1 { f.append("after a 409 uploaded \(third.uploaded), want one file") }
            if FakeWorker.state.commits409 != 1 { f.append("409 path not exercised") }

            // A corrupted upload is refused by the Worker and surfaces as an error.
            FakeWorker.reset(token: "id-1")
            FakeWorker.state.corruptUploads = true
            do { _ = try await client.push(bundle: bundle); f.append("corrupt upload accepted") } catch let e as CloudClient.HTTPError {
                if e.status != 400 { f.append("corrupt upload → \(e.status)") }
            }

            // Wrong token: a clear message.
            FakeWorker.reset(token: "other")
            do { _ = try await client.push(bundle: bundle); f.append("push with a bad token succeeded") } catch {
                if !error.localizedDescription.contains("service token") { f.append("bad token message: \(error.localizedDescription)") }
            }
        } catch {
            f.append("client: \(error.localizedDescription)")
        }

        // Configuration.
        let env = ["CR_CLOUD_URL": "sessions.example.com", "CR_CLOUD_CLIENT_ID": "cid", "CR_CLOUD_CLIENT_SECRET": "sec"]
        let c = CloudConfig.current(environment: env)
        if c?.url.absoluteString != "https://sessions.example.com" { f.append("env url → \(String(describing: c?.url))") }
        if c?.headers != ["CF-Access-Client-Id": "cid", "CF-Access-Client-Secret": "sec"] { f.append("headers → \(String(describing: c?.headers))") }
        if CloudConfig.current(override: "http://localhost:8787", environment: env)?.url.absoluteString != "http://localhost:8787" { f.append("--cloud override ignored") }
        if CloudSettings.normalized("localhost:8787")?.absoluteString != "http://localhost:8787" { f.append("localhost normalization") }
        if CloudSettings.normalized("ftp://x") != nil { f.append("ftp accepted") }

        // Paths.
        for (input, want) in [("frames/001.jpg", "frames/001.jpg"), ("../2026-10-13_00-57-10/frames/001.jpg", "sources/2026-10-13_00-57-10/frames/001.jpg"),
                              ("annotations/..-src-frames-001.png", "annotations/_-src-frames-001.png"), ("./marks/001.md", "marks/001.md")] {
            let got = CloudBundle.bundlePath(input)
            if got != want { f.append("bundlePath(\(input)) = \(got), want \(want)") }
        }
        if CloudBundle.sessionID(for: URL(fileURLWithPath: "/x/My Session (2)")) != "My-Session--2-" { f.append("sessionID cleanup") }

        // cloud.json round trip.
        let folder = root.appendingPathComponent("session")
        let record = CloudRecord(url: "u", manifestSha256: "m", inputHash: "h", pushedAt: "2026-01-01T00:00:00Z")
        do {
            try record.save(to: folder)
            if CloudRecord.load(folder) != record { f.append("cloud.json round trip") }
        } catch { f.append("cloud.json: \(error)") }
        return f
    }
}

/// The Worker's push API in memory: content-addressed blobs with hash checks, multipart, push/commit.
final class FakeWorker: URLProtocol {
    struct State {
        var token = ""
        var blobs: [String: Data] = [:]
        var uploads: [String: [Int: Data]] = [:]
        var parts = 0
        var dropBeforeCommit: String?
        var commits409 = 0
        var corruptUploads = false
    }
    nonisolated(unsafe) static var state = State()
    static let lock = NSLock()
    static func reset(token: String) { lock.withLock { state = State(token: token) } }

    override class func canInit(with request: URLRequest) -> Bool { request.url?.host == "cloud.test" }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
    override func stopLoading() {}

    override func startLoading() {
        let (status, body) = Self.lock.withLock { Self.handle(request) }
        let response = HTTPURLResponse(url: request.url!, statusCode: status, httpVersion: "HTTP/1.1",
                                       headerFields: ["Content-Type": "application/json"])!
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: body)
        client?.urlProtocolDidFinishLoading(self)
    }

    private static func sha(_ d: Data) -> String { SHA256.hash(data: d).map { String(format: "%02x", $0) }.joined() }
    private static func json(_ v: Any) -> Data { (try? JSONSerialization.data(withJSONObject: v)) ?? Data() }

    private static func body(_ r: URLRequest) -> Data {
        if let b = r.httpBody { return b }
        guard let stream = r.httpBodyStream else { return Data() }
        stream.open()
        defer { stream.close() }
        var out = Data()
        var buf = [UInt8](repeating: 0, count: 1 << 16)
        while stream.hasBytesAvailable {
            let n = stream.read(&buf, maxLength: buf.count)
            if n <= 0 { break }
            out.append(buf, count: n)
        }
        return out
    }

    private static func handle(_ r: URLRequest) -> (Int, Data) {
        guard r.value(forHTTPHeaderField: "CF-Access-Client-Id") == state.token else { return (403, Data("forbidden".utf8)) }
        let parts = r.url!.path.split(separator: "/").map(String.init)   // ["api", ...]
        let method = r.httpMethod ?? "GET"
        let data = body(r)
        func manifestHashes() -> [String] {
            ((try? JSONDecoder().decode(CloudManifest.self, from: data))?.files.map(\.sha256)) ?? []
        }
        switch (method, parts.count, parts.dropFirst().first) {
        case ("POST", 4, "sessions") where parts[3] == "push":
            let missing = Array(Set(manifestHashes().filter { state.blobs[$0] == nil })).sorted()
            return (200, json(["missing": missing]))
        case ("POST", 4, "sessions") where parts[3] == "commit":
            if let drop = state.dropBeforeCommit { state.blobs[drop] = nil; state.dropBeforeCommit = nil }
            let missing = Array(Set(manifestHashes().filter { state.blobs[$0] == nil })).sorted()
            if !missing.isEmpty { state.commits409 += 1; return (409, json(["missing": missing])) }
            return (200, json(["url": "http://cloud.test/s/\(parts[2])/", "manifestSha256": sha(data)]))
        case ("PUT", 3, "blobs"):
            let bytes = state.corruptUploads ? data + Data([0]) : data
            guard sha(bytes) == parts[2] else { return (400, Data("hash mismatch".utf8)) }
            state.blobs[parts[2]] = bytes
            return (204, Data())
        case ("POST", 4, "blobs") where parts[3] == "uploads":
            let id = "u\(state.uploads.count + 1)"
            state.uploads[id] = [:]
            return (200, json(["uploadId": id]))
        case ("PUT", 6, "blobs"):
            guard let n = Int(parts[5]), state.uploads[parts[4]] != nil else { return (404, Data()) }
            state.uploads[parts[4]]?[n] = data
            state.parts += 1
            return (200, json(["etag": "e\(n)"]))
        case ("POST", 6, "blobs") where parts[5] == "complete":
            struct Done: Decodable { struct P: Decodable { var partNumber: Int; var etag: String }; var parts: [P] }
            guard let done = try? JSONDecoder().decode(Done.self, from: data), let stored = state.uploads[parts[4]] else { return (400, Data()) }
            let joined = done.parts.sorted { $0.partNumber < $1.partNumber }.reduce(Data()) { $0 + (stored[$1.partNumber] ?? Data()) }
            guard sha(joined) == parts[2], done.parts.allSatisfy({ $0.etag == "e\($0.partNumber)" }) else { return (400, Data("hash mismatch".utf8)) }
            state.blobs[parts[2]] = joined
            return (204, Data())
        default:
            return (404, Data())
        }
    }
}
