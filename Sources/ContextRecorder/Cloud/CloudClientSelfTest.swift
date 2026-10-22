import CryptoKit
import Foundation

/// `--self-test cloud-client`: CloudClient and the sign-in against an in-memory stand-in for the Worker's push
/// API and OAuth endpoints (contract §2 and §6), plus PKCE, configuration, path and cloud.json helpers.
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
            let fake = URLSession(configuration: config)
            let base = URL(string: "http://cloud.test/")!
            FakeWorker.reset()

            // Sign-in: discovery, registration, PKCE authorize (a fake browser), code exchange, /api/me.
            CloudAuth.cacheClientId(nil, for: base)
            defer { CloudAuth.cacheClientId(nil, for: base) }
            let browser: CloudAuth.Browser = { authorize in
                let items = URLComponents(url: authorize, resolvingAgainstBaseURL: false)?.queryItems ?? []
                func item(_ n: String) -> String { items.first { $0.name == n }?.value ?? "" }
                FakeWorker.lock.withLock {
                    FakeWorker.state.codes["code-1"] = (item("code_challenge"), item("client_id"), item("redirect_uri"))
                }
                if item("code_challenge_method") != "S256" || item("response_type") != "code" { throw ReviewError("authorize params \(authorize)") }
                return URL(string: "\(CloudAuth.redirectURI)?code=code-1&state=\(item("state"))")!
            }
            let signedIn = try await CloudAuth.signIn(base, session: fake, browser: browser)
            if signedIn.email != "byron@example.com" { f.append("sign-in email \(String(describing: signedIn.email))") }
            if signedIn.clientId != "client-1" || signedIn.refreshToken == nil { f.append("sign-in credentials \(signedIn)") }
            if signedIn.accessExpiry.timeIntervalSinceNow < 3000 { f.append("sign-in expiry \(signedIn.accessExpiry)") }
            if FakeWorker.state.registrations != 1 { f.append("\(FakeWorker.state.registrations) registrations") }
            if FakeWorker.state.registeredBody["client_name"] as? String != CloudAuth.clientName
                || FakeWorker.state.registeredBody["token_endpoint_auth_method"] as? String != "none" {
                f.append("registration body \(FakeWorker.state.registeredBody)")
            }
            _ = try await CloudAuth.signIn(base, session: fake, browser: browser)
            if FakeWorker.state.registrations != 1 { f.append("signing in again registered a new client") }
            // A reply for another request is refused.
            do {
                _ = try await CloudAuth.signIn(base, session: fake) { _ in URL(string: "\(CloudAuth.redirectURI)?code=code-1&state=nope")! }
                f.append("mismatched state accepted")
            } catch {}
            // Keychain-format round trip.
            let encoded = try CloudAuth.encoder.encode(signedIn)
            if try CloudAuth.decoder.decode(CloudCredentials.self, from: encoded) != signedIn { f.append("credentials JSON round trip") }
            let keys = Set(((try JSONSerialization.jsonObject(with: encoded)) as? [String: Any] ?? [:]).keys)
            if keys != ["baseURL", "clientId", "accessToken", "accessExpiry", "refreshToken", "email"] { f.append("credentials keys \(keys)") }

            // Push with the stored sign-in: every request carries the bearer.
            FakeWorker.lock.withLock { FakeWorker.state.bearers = [] }
            let store = MemoryAuthStore(signedIn)
            let provider = CloudTokenProvider(store: store, session: fake)
            var client = CloudClient(baseURL: base, auth: provider, session: fake)
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
            if Set(FakeWorker.state.bearers) != ["Bearer \(signedIn.accessToken)"] { f.append("bearers sent \(Set(FakeWorker.state.bearers))") }

            let second = try await client.push(bundle: bundle)
            if !second.uploaded.isEmpty { f.append("unchanged re-push uploaded \(second.uploaded)") }

            // A blob that disappears before commit: 409, re-upload, commit again.
            FakeWorker.state.dropBeforeCommit = manifest.files.first { $0.path == "a.json" }?.sha256
            let third = try await client.push(bundle: bundle)
            if third.uploaded.count != 1 { f.append("after a 409 uploaded \(third.uploaded), want one file") }
            if FakeWorker.state.commits409 != 1 { f.append("409 path not exercised") }

            // The access token expires on the server: 401 → one refresh → retry. Two pushes at once share it.
            FakeWorker.lock.withLock { FakeWorker.state.tokens.removeAll(); FakeWorker.state.unauthorized = 0 }
            let refreshesBefore = FakeWorker.state.refreshes
            let shared = client
            async let p1 = shared.push(bundle: bundle)
            async let p2 = shared.push(bundle: bundle)
            _ = try await (p1, p2)
            if FakeWorker.state.refreshes - refreshesBefore != 1 { f.append("\(FakeWorker.state.refreshes - refreshesBefore) refreshes for two parallel pushes, want 1") }
            if FakeWorker.state.unauthorized < 1 { f.append("401 path not exercised") }
            if store.load()?.accessToken == signedIn.accessToken { f.append("refreshed token not stored") }
            if store.load()?.refreshToken == signedIn.refreshToken { f.append("rotated refresh token not stored") }

            // Within 60 s of expiry: refreshed before the request, no 401.
            if var near = store.load() {
                near.accessExpiry = Date().addingTimeInterval(30)
                let nearStore = MemoryAuthStore(near)
                FakeWorker.lock.withLock { FakeWorker.state.unauthorized = 0 }
                let before = FakeWorker.state.refreshes
                _ = try await CloudClient(baseURL: base, auth: CloudTokenProvider(store: nearStore, session: fake), session: fake).push(bundle: bundle)
                if FakeWorker.state.refreshes - before != 1 || FakeWorker.state.unauthorized != 0 {
                    f.append("near expiry: \(FakeWorker.state.refreshes - before) refreshes, \(FakeWorker.state.unauthorized) 401s")
                }
            }

            // Sign out revokes at the listed endpoint.
            await CloudAuth.revoke(signedIn, session: fake)
            if FakeWorker.state.revocations != [signedIn.refreshToken ?? ""] { f.append("revocations \(FakeWorker.state.revocations)") }

            // A corrupted upload is refused by the Worker and surfaces as an error.
            FakeWorker.reset(tokens: [store.load()?.accessToken ?? ""])
            FakeWorker.state.corruptUploads = true
            do { _ = try await client.push(bundle: bundle); f.append("corrupt upload accepted") } catch let e as CloudClient.HTTPError {
                if e.status != 400 { f.append("corrupt upload → \(e.status)") }
            }

            // The refresh fails (grant revoked): a clear sign-in error, and the sign-in is forgotten.
            FakeWorker.reset(tokens: [])
            do { _ = try await client.push(bundle: bundle); f.append("push with a dead sign-in succeeded") } catch {
                if error.localizedDescription != "Sign in to your cloud again (Cloud Settings)" { f.append("dead sign-in message: \(error.localizedDescription)") }
            }
            if store.load() != nil { f.append("dead sign-in kept in the store") }

            // CR_CLOUD_TOKEN overrides the stored sign-in and is sent as is.
            let envConfig = CloudConfig.current(environment: ["CR_CLOUD_URL": "http://cloud.test", "CR_CLOUD_TOKEN": " env-tok "])
            if envConfig?.token != "env-tok" || envConfig?.hasCredentials != true { f.append("CR_CLOUD_TOKEN → \(String(describing: envConfig?.token))") }
            if let envConfig {
                FakeWorker.reset(tokens: ["env-tok"])
                let envClient = CloudClient(baseURL: envConfig.url, auth: envConfig.auth, session: fake)
                _ = try await envClient.push(bundle: bundle)
                if Set(FakeWorker.state.bearers) != ["Bearer env-tok"] { f.append("CR_CLOUD_TOKEN bearers \(Set(FakeWorker.state.bearers))") }
                FakeWorker.reset(tokens: [])
                do { _ = try await envClient.push(bundle: bundle); f.append("refused CR_CLOUD_TOKEN succeeded") } catch {
                    if !error.localizedDescription.contains("CR_CLOUD_TOKEN") { f.append("refused CR_CLOUD_TOKEN message: \(error.localizedDescription)") }
                }
            }

            // Signed out against a dev Worker (DEV_IDENTITY): no header, and it works.
            FakeWorker.reset(tokens: [])
            FakeWorker.state.allowAnonymous = true
            let anonymous = CloudClient(baseURL: base, auth: CloudTokenProvider(store: MemoryAuthStore(), session: fake), session: fake)
            _ = try await anonymous.push(bundle: bundle)
            if !FakeWorker.state.bearers.isEmpty { f.append("signed out sent \(FakeWorker.state.bearers)") }
            // …and against a real cloud, a sign-in error.
            FakeWorker.state.allowAnonymous = false
            do { _ = try await anonymous.push(bundle: bundle); f.append("signed-out push succeeded") } catch {
                if (error as? CloudAuthError) != .signInRequired { f.append("signed-out push error: \(error.localizedDescription)") }
            }
        } catch {
            f.append("client: \(error.localizedDescription)")
        }

        // PKCE S256 of a known verifier (checked with `openssl dgst -sha256 -binary | base64`; its digest has + and /).
        if CloudAuth.challenge(for: "dBjftJeZ4CVP-mJ92K9qkArR-BGkz6Ac3Hxz3-QHA7w") != "xUlz1wOw4Ug3fvz-fL_V8h6lLpeNgemdGsvmO_AcpRY" {
            f.append("PKCE S256 challenge")
        }
        let verifier = CloudAuth.randomString()
        if verifier.count != 43 || verifier.contains(where: { !($0.isLetter || $0.isNumber || $0 == "-" || $0 == "_") }) { f.append("verifier \(verifier)") }
        let authorize = CloudAuth.authorizeURL(URL(string: "https://c.example/authorize")!, clientId: "id 1", challenge: "ch", state: "st")
        let query = Dictionary(uniqueKeysWithValues: (URLComponents(url: authorize, resolvingAgainstBaseURL: false)?.queryItems ?? []).map { ($0.name, $0.value ?? "") })
        if query != ["response_type": "code", "client_id": "id 1", "redirect_uri": "contextrecorder://oauth/callback",
                     "code_challenge": "ch", "code_challenge_method": "S256", "state": "st"]
            || !authorize.absoluteString.hasPrefix("https://c.example/authorize?") {
            f.append("authorize URL \(authorize)")
        }
        if CloudAuth.formEncode(["b": "a b&c", "a": "x/y"]) != "a=x%2Fy&b=a%20b%26c" { f.append("form encoding \(CloudAuth.formEncode(["b": "a b&c", "a": "x/y"]))") }
        if !CloudAuth.isLocal(URL(string: "http://localhost:8787")!) || CloudAuth.isLocal(URL(string: "https://sessions.example.com")!) { f.append("isLocal") }

        // Configuration.
        let env = ["CR_CLOUD_URL": "sessions.example.com"]
        let c = CloudConfig.current(environment: env)
        if c?.url.absoluteString != "https://sessions.example.com" { f.append("env url → \(String(describing: c?.url))") }
        if c?.token != nil { f.append("token without CR_CLOUD_TOKEN") }
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

/// The Worker in memory: OAuth (discovery, registration, PKCE code exchange, refresh with rotation, revocation),
/// `/api/me`, and the push API (content-addressed blobs with hash checks, multipart, push/commit).
final class FakeWorker: URLProtocol {
    struct State {
        /// Access tokens the API accepts.
        var tokens: Set<String> = []
        /// Refresh token → client id.
        var refreshTokens: [String: String] = [:]
        /// Code → (challenge, client id, redirect URI), set by the fake browser.
        var codes: [String: (String, String, String)] = [:]
        var allowAnonymous = false
        var registrations = 0
        var registeredBody: [String: Any] = [:]
        var refreshes = 0
        var unauthorized = 0
        var revocations: [String] = []
        var bearers: [String] = []
        var issued = 0
        var blobs: [String: Data] = [:]
        var uploads: [String: [Int: Data]] = [:]
        var parts = 0
        var dropBeforeCommit: String?
        var commits409 = 0
        var corruptUploads = false
    }
    nonisolated(unsafe) static var state = State()
    static let lock = NSLock()
    /// Keeps the refresh tokens and registrations unless `tokens` is given (a fresh server).
    static func reset(tokens: Set<String>? = nil) {
        lock.withLock {
            if let tokens { state = State(tokens: tokens) } else { state = State() }
        }
    }

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

    private static func form(_ data: Data) -> [String: String] {
        var c = URLComponents()
        c.percentEncodedQuery = String(decoding: data, as: UTF8.self)
        return Dictionary((c.queryItems ?? []).map { ($0.name, $0.value ?? "") }, uniquingKeysWith: { a, _ in a })
    }

    private static func issue(_ client: String) -> Data {
        state.issued += 1
        let access = "acc-\(state.issued)", refresh = "ref-\(state.issued)"
        state.tokens.insert(access)
        state.refreshTokens[refresh] = client
        return json(["access_token": access, "token_type": "bearer", "expires_in": 3600, "refresh_token": refresh])
    }

    private static func handleOAuth(_ r: URLRequest, _ method: String, _ path: String, _ data: Data) -> (Int, Data)? {
        switch (method, path) {
        case ("GET", "/.well-known/oauth-authorization-server"):
            return (200, json(["issuer": "http://cloud.test", "authorization_endpoint": "http://cloud.test/authorize",
                               "token_endpoint": "http://cloud.test/token", "registration_endpoint": "http://cloud.test/register",
                               "revocation_endpoint": "http://cloud.test/revoke"]))
        case ("POST", "/register"):
            state.registrations += 1
            state.registeredBody = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any] ?? [:]
            guard state.registeredBody["redirect_uris"] as? [String] == [CloudAuth.redirectURI] else { return (400, Data()) }
            return (201, json(["client_id": "client-\(state.registrations)"]))
        case ("POST", "/token"):
            let f = form(data)
            switch f["grant_type"] {
            case "authorization_code":
                guard let code = f["code"], let (challenge, client, redirect) = state.codes.removeValue(forKey: code),
                      client == f["client_id"], redirect == f["redirect_uri"],
                      CloudAuth.challenge(for: f["code_verifier"] ?? "") == challenge else { return (400, json(["error": "invalid_grant"])) }
                return (200, issue(client))
            case "refresh_token":
                guard let token = f["refresh_token"], let client = state.refreshTokens.removeValue(forKey: token), client == f["client_id"] else {
                    return (400, json(["error": "invalid_grant"]))
                }
                state.refreshes += 1
                return (200, issue(client))
            default: return (400, json(["error": "unsupported_grant_type"]))
            }
        case ("POST", "/revoke"):
            let f = form(data)
            state.revocations.append(f["token"] ?? "")
            return (200, Data())
        default: return nil
        }
    }

    private static func handle(_ r: URLRequest) -> (Int, Data) {
        let method = r.httpMethod ?? "GET"
        let data = body(r)
        if let reply = handleOAuth(r, method, r.url!.path, data) { return reply }
        let header = r.value(forHTTPHeaderField: "Authorization")
        if let header { state.bearers.append(header) }
        let token = header.flatMap { $0.hasPrefix("Bearer ") ? String($0.dropFirst(7)) : nil }
        guard token.map(state.tokens.contains) ?? state.allowAnonymous else {
            state.unauthorized += 1
            return (401, json(["error": "invalid_token"]))
        }
        let parts = r.url!.path.split(separator: "/").map(String.init)   // ["api", ...]
        if parts == ["api", "me"] { return (200, json(["id": "byron@example.com", "via": token == nil ? "dev" : "oauth"])) }
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
