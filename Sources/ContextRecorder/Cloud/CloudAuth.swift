import AppKit
import AuthenticationServices
import CryptoKit
import Foundation
import Security

/// Sign-in to the cloud Worker (contract §6): OAuth 2.1 with discovery, dynamic registration, PKCE S256 and
/// `ASWebAuthenticationSession`. The result is one private file (`FileAuthStore`); nobody types or sees a token.
struct CloudCredentials: Codable, Equatable {
    var baseURL: String
    var clientId: String
    var accessToken: String
    var accessExpiry: Date
    var refreshToken: String?
    var email: String?

    func matches(_ url: URL) -> Bool { CloudAuth.key(baseURL) == CloudAuth.key(url.absoluteString) }
}

/// Where the sign-in is kept. The app uses a private file; tests use memory.
protocol CloudAuthStore: Sendable {
    func load() -> CloudCredentials?
    func save(_ credentials: CloudCredentials) throws
    func delete()
}

/// `~/Library/Application Support/ContextRecorder/cloud-auth.json`, readable only by you (0600 in a 0700
/// folder). Not the Keychain: for an app signed without an Apple team, a Keychain item is tied to one build,
/// so every rebuild asked for access again. The refresh token only reaches your sessions cloud, and the
/// library page's Signed-in apps list revokes it.
struct FileAuthStore: CloudAuthStore {
    var url: URL = FileAuthStore.defaultURL

    static var defaultURL: URL {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("ContextRecorder/cloud-auth.json")
    }

    func load() -> CloudCredentials? {
        guard let data = try? Data(contentsOf: url) else { return nil }
        return try? CloudAuth.decoder.decode(CloudCredentials.self, from: data)
    }

    func save(_ credentials: CloudCredentials) throws {
        let fm = FileManager.default
        let folder = url.deletingLastPathComponent()
        try fm.createDirectory(at: folder, withIntermediateDirectories: true, attributes: [.posixPermissions: 0o700])
        // Written to a private temp file first, so the token is never readable by others, even briefly.
        let temp = folder.appendingPathComponent(".cloud-auth-\(UUID().uuidString).json")
        guard fm.createFile(atPath: temp.path, contents: try CloudAuth.encoder.encode(credentials), attributes: [.posixPermissions: 0o600]) else {
            throw ReviewError("Couldn't save the cloud sign-in to \(url.path)")
        }
        _ = try fm.replaceItemAt(url, withItemAt: temp)
    }

    func delete() { try? FileManager.default.removeItem(at: url) }
}

final class MemoryAuthStore: CloudAuthStore, @unchecked Sendable {
    private let lock = NSLock()
    private var value: CloudCredentials?
    init(_ value: CloudCredentials? = nil) { self.value = value }
    func load() -> CloudCredentials? { lock.withLock { value } }
    func save(_ credentials: CloudCredentials) throws { lock.withLock { value = credentials } }
    func delete() { lock.withLock { value = nil } }
}

enum CloudAuthError: LocalizedError, Equatable {
    /// Signed out, or the sign-in can't be refreshed any more.
    case signInRequired
    /// `CR_CLOUD_TOKEN` was refused.
    case tokenRefused(Int)
    case cancelled
    case failed(String)

    var errorDescription: String? {
        switch self {
        case .signInRequired: "Sign in to your cloud again (Cloud Settings)"
        case .tokenRefused(let status): "The cloud refused CR_CLOUD_TOKEN (\(status))"
        case .cancelled: "Sign-in was cancelled"
        case .failed(let message): message
        }
    }
}

enum CloudAuth {
    static let redirectURI = "contextrecorder://oauth/callback"
    static let callbackScheme = "contextrecorder"

    static let encoder: JSONEncoder = { let e = JSONEncoder(); e.dateEncodingStrategy = .secondsSince1970; e.outputFormatting = .sortedKeys; return e }()
    static let decoder: JSONDecoder = { let d = JSONDecoder(); d.dateDecodingStrategy = .secondsSince1970; return d }()

    /// Cloud URLs compare without a trailing slash and case-insensitively.
    static func key(_ url: String) -> String {
        var s = url.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        while s.hasSuffix("/") { s.removeLast() }
        return s
    }

    /// A local `wrangler dev` Worker answers as `DEV_IDENTITY` without a token.
    static func isLocal(_ url: URL) -> Bool {
        let host = url.host?.lowercased() ?? ""
        return host == "localhost" || host == "127.0.0.1" || host == "::1" || host.hasSuffix(".localhost")
    }

    // MARK: Metadata (RFC 8414)

    struct Metadata: Decodable, Sendable {
        var authorization_endpoint: URL
        var token_endpoint: URL
        var registration_endpoint: URL?
        var revocation_endpoint: URL?
    }

    static func discover(_ base: URL, session: URLSession) async throws -> Metadata {
        let url = base.appendingPathComponent(".well-known/oauth-authorization-server")
        let (data, status) = try await get(url, session: session)
        guard status == 200, let meta = try? JSONDecoder().decode(Metadata.self, from: data) else {
            throw CloudAuthError.failed("This cloud doesn't offer sign-in (\(url.host ?? "") answered \(status)). Is the address right?")
        }
        return meta
    }

    // MARK: Registration (RFC 7591)

    static var clientName: String { "Context Recorder (\(Host.current().localizedName ?? "Mac"))" }

    static func register(_ meta: Metadata, session: URLSession) async throws -> String {
        guard let endpoint = meta.registration_endpoint else { throw CloudAuthError.failed("This cloud doesn't allow registering the app") }
        let body: [String: Any] = [
            "client_name": clientName,
            "redirect_uris": [redirectURI],
            "token_endpoint_auth_method": "none",
            "grant_types": ["authorization_code", "refresh_token"],
            "response_types": ["code"],
        ]
        var req = URLRequest(url: endpoint)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.httpBody = try JSONSerialization.data(withJSONObject: body)
        let (data, response) = try await session.data(for: req)
        struct Client: Decodable { var client_id: String }
        guard (200..<300).contains((response as? HTTPURLResponse)?.statusCode ?? 0),
              let client = try? JSONDecoder().decode(Client.self, from: data) else {
            throw CloudAuthError.failed("Registering the app with the cloud failed: \(String(decoding: data.prefix(200), as: UTF8.self))")
        }
        return client.client_id
    }

    /// Client ids aren't secret; they're kept per cloud URL so signing out and in again doesn't register a new client.
    private static let clientIdsKey = "cloudClientIds"
    static func cachedClientId(_ base: URL) -> String? {
        (UserDefaults.standard.dictionary(forKey: clientIdsKey) as? [String: String])?[key(base.absoluteString)]
    }
    static func cacheClientId(_ id: String?, for base: URL) {
        var all = (UserDefaults.standard.dictionary(forKey: clientIdsKey) as? [String: String]) ?? [:]
        all[key(base.absoluteString)] = id
        UserDefaults.standard.set(all, forKey: clientIdsKey)
    }

    // MARK: PKCE (RFC 7636)

    static func base64URL(_ data: Data) -> String {
        data.base64EncodedString().replacingOccurrences(of: "+", with: "-").replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }

    static func randomString(bytes: Int = 32) -> String {
        var raw = [UInt8](repeating: 0, count: bytes)
        _ = SecRandomCopyBytes(kSecRandomDefault, bytes, &raw)
        return base64URL(Data(raw))
    }

    static func challenge(for verifier: String) -> String { base64URL(Data(SHA256.hash(data: Data(verifier.utf8)))) }

    static func authorizeURL(_ endpoint: URL, clientId: String, challenge: String, state: String) -> URL {
        var parts = URLComponents(url: endpoint, resolvingAgainstBaseURL: false)!
        parts.queryItems = (parts.queryItems ?? []) + [
            URLQueryItem(name: "response_type", value: "code"),
            URLQueryItem(name: "client_id", value: clientId),
            URLQueryItem(name: "redirect_uri", value: redirectURI),
            URLQueryItem(name: "code_challenge", value: challenge),
            URLQueryItem(name: "code_challenge_method", value: "S256"),
            URLQueryItem(name: "state", value: state),
        ]
        return parts.url!
    }

    // MARK: Tokens

    struct TokenReply: Decodable { var access_token: String; var expires_in: Double?; var refresh_token: String? }

    /// Status and body of a failed token request, so callers can tell a dead grant from a network problem.
    struct TokenError: Error { var status: Int; var body: String }

    static func tokenRequest(_ endpoint: URL, _ fields: [String: String], session: URLSession) async throws -> TokenReply {
        var req = URLRequest(url: endpoint)
        req.httpMethod = "POST"
        req.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        req.setValue("application/json", forHTTPHeaderField: "Accept")
        req.httpBody = Data(formEncode(fields).utf8)
        let (data, response) = try await session.data(for: req)
        let status = (response as? HTTPURLResponse)?.statusCode ?? 0
        guard status == 200, let reply = try? JSONDecoder().decode(TokenReply.self, from: data) else {
            throw TokenError(status: status, body: String(decoding: data.prefix(300), as: UTF8.self))
        }
        return reply
    }

    static func formEncode(_ fields: [String: String]) -> String {
        var allowed = CharacterSet.alphanumerics
        allowed.insert(charactersIn: "-._~")
        return fields.sorted { $0.key < $1.key }
            .map { "\($0.key)=\($0.value.addingPercentEncoding(withAllowedCharacters: allowed) ?? "")" }
            .joined(separator: "&")
    }

    /// Whole seconds, so the saved JSON (seconds since 1970) reads back as the same date.
    static func expiry(_ reply: TokenReply) -> Date {
        Date(timeIntervalSince1970: (Date().timeIntervalSince1970 + (reply.expires_in ?? 3600)).rounded(.down))
    }

    /// `GET /api/me` → the email the cloud knows the person by.
    static func fetchEmail(_ base: URL, token: String, session: URLSession) async -> String? {
        var req = URLRequest(url: base.appendingPathComponent("api/me"))
        req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        struct Me: Decodable { var id: String }
        guard let (data, response) = try? await session.data(for: req), (response as? HTTPURLResponse)?.statusCode == 200 else { return nil }
        return (try? JSONDecoder().decode(Me.self, from: data))?.id
    }

    private static func get(_ url: URL, session: URLSession) async throws -> (Data, Int) {
        var req = URLRequest(url: url)
        req.setValue("application/json", forHTTPHeaderField: "Accept")
        let (data, response) = try await session.data(for: req)
        return (data, (response as? HTTPURLResponse)?.statusCode ?? 0)
    }

    // MARK: Sign in

    /// Opens the authorize URL and returns the redirect it ends on. The app passes `WebAuthenticator`; tests fake it.
    typealias Browser = @MainActor (_ authorize: URL) async throws -> URL

    /// Discovery → registration (once per cloud URL) → PKCE authorize in the browser → code exchange → `/api/me`.
    @MainActor
    static func signIn(_ base: URL, session: URLSession = .shared, browser: Browser) async throws -> CloudCredentials {
        let meta = try await discover(base, session: session)
        let cached = cachedClientId(base)
        let clientId: String
        if let cached { clientId = cached } else { clientId = try await register(meta, session: session) }
        cacheClientId(clientId, for: base)
        let verifier = randomString(), state = randomString(bytes: 16)
        let authorize = authorizeURL(meta.authorization_endpoint, clientId: clientId, challenge: challenge(for: verifier), state: state)
        do {
            let callback = try await browser(authorize)
            let items = URLComponents(url: callback, resolvingAgainstBaseURL: false)?.queryItems ?? []
            func item(_ name: String) -> String? { items.first { $0.name == name }?.value }
            if let error = item("error") {
                throw CloudAuthError.failed("The cloud declined the sign-in: \(item("error_description") ?? error)")
            }
            guard item("state") == state else { throw CloudAuthError.failed("The sign-in reply didn't match this request; try again.") }
            guard let code = item("code") else { throw CloudAuthError.failed("The sign-in reply had no code.") }
            let reply: TokenReply
            do {
                reply = try await tokenRequest(meta.token_endpoint, [
                    "grant_type": "authorization_code", "code": code, "client_id": clientId,
                    "code_verifier": verifier, "redirect_uri": redirectURI,
                ], session: session)
            } catch let e as TokenError {
                throw CloudAuthError.failed("The cloud didn't accept the sign-in (\(e.status)): \(e.body.prefix(200))")
            }
            let email = await fetchEmail(base, token: reply.access_token, session: session)
            return CloudCredentials(baseURL: base.absoluteString, clientId: clientId, accessToken: reply.access_token,
                                    accessExpiry: expiry(reply), refreshToken: reply.refresh_token, email: email)
        } catch {
            // A client the cloud forgot (or a bad registration) would fail every time; register afresh next time.
            if let e = error as? CloudAuthError, e == .cancelled {} else if cached != nil { cacheClientId(nil, for: base) }
            throw error
        }
    }

    /// Best-effort RFC 7009 revocation of the refresh token, when the cloud lists an endpoint.
    static func revoke(_ credentials: CloudCredentials, session: URLSession = .shared) async {
        guard let base = URL(string: credentials.baseURL), let meta = try? await discover(base, session: session),
              let endpoint = meta.revocation_endpoint else { return }
        var req = URLRequest(url: endpoint)
        req.httpMethod = "POST"
        req.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        req.httpBody = Data(formEncode(["token": credentials.refreshToken ?? credentials.accessToken, "client_id": credentials.clientId]).utf8)
        req.timeoutInterval = 10
        _ = try? await session.data(for: req)
    }
}

// MARK: - The browser

/// `ASWebAuthenticationSession`, sharing Safari's cookies so the Access sign-in is reused.
@MainActor
final class WebAuthenticator: NSObject, ASWebAuthenticationPresentationContextProviding {
    private var session: ASWebAuthenticationSession?
    private var fallbackWindow: NSWindow?

    func open(_ url: URL) async throws -> URL {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<URL, Error>) in
            let session = ASWebAuthenticationSession(url: url, callback: .customScheme(CloudAuth.callbackScheme)) { [weak self] callback, error in
                Task { @MainActor in
                    self?.session = nil
                    self?.fallbackWindow = nil
                }
                if let callback { continuation.resume(returning: callback); return }
                if let error = error as? ASWebAuthenticationSessionError, error.code == .canceledLogin {
                    continuation.resume(throwing: CloudAuthError.cancelled)
                } else {
                    continuation.resume(throwing: CloudAuthError.failed("Sign-in failed: \(error?.localizedDescription ?? "no reply")"))
                }
            }
            session.prefersEphemeralWebBrowserSession = false
            session.presentationContextProvider = self
            self.session = session
            if !session.start() {
                self.session = nil
                continuation.resume(throwing: CloudAuthError.failed("Couldn't open the sign-in window"))
            }
        }
    }

    func cancel() { session?.cancel() }

    nonisolated func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        if Thread.isMainThread { return MainActor.assumeIsolated { anchor() } }
        return DispatchQueue.main.sync { MainActor.assumeIsolated { anchor() } }
    }

    private func anchor() -> ASPresentationAnchor {
        if let window = NSApp.keyWindow ?? NSApp.mainWindow ?? NSApp.windows.first(where: \.isVisible) { return window }
        let window = NSWindow(contentRect: .zero, styleMask: [], backing: .buffered, defer: true)
        fallbackWindow = window
        return window
    }
}

// MARK: - Tokens for requests

/// Hands out the access token for requests, refreshing it once on a 401 or within 60 s of expiry. An actor, and
/// one in-flight refresh at a time, so parallel uploads don't race to spend the same refresh token.
actor CloudTokenProvider {
    static let saved = CloudTokenProvider(store: FileAuthStore())

    private let store: CloudAuthStore?
    private let fixed: String?
    private let session: URLSession
    private var cached: CloudCredentials??
    private var refreshing: Task<CloudCredentials, Error>?
    private(set) var refreshCount = 0

    init(store: CloudAuthStore, session: URLSession = .shared) { self.store = store; self.fixed = nil; self.session = session }
    /// `CR_CLOUD_TOKEN`: a raw access token, never refreshed.
    init(token: String) { self.store = nil; self.fixed = token; self.session = .shared }

    var isFixed: Bool { fixed != nil }

    private func credentials() -> CloudCredentials? {
        if let cached { return cached }
        let loaded = store?.load()
        cached = .some(loaded)
        return loaded
    }

    func signedIn(_ credentials: CloudCredentials) throws {
        try store?.save(credentials)
        cached = .some(credentials)
    }

    func signOut() -> CloudCredentials? {
        let old = credentials()
        store?.delete()
        cached = .some(nil)
        return old
    }

    /// The token to send to `base`, or nil when signed out (fine for a local dev Worker).
    func token(for base: URL) async throws -> String? {
        if let fixed { return fixed }
        guard let creds = credentials(), creds.matches(base) else { return nil }
        if creds.accessExpiry.timeIntervalSinceNow > 60 { return creds.accessToken }
        return try await refresh(base).accessToken
    }

    /// After a 401 for `rejected`: refresh (unless another request already did) and return the new token.
    func token(for base: URL, after rejected: String?) async throws -> String {
        if fixed != nil { throw CloudAuthError.tokenRefused(401) }
        guard let creds = credentials(), creds.matches(base) else { throw CloudAuthError.signInRequired }
        if let rejected, creds.accessToken != rejected { return creds.accessToken }
        return try await refresh(base).accessToken
    }

    private func refresh(_ base: URL) async throws -> CloudCredentials {
        if let refreshing { return try await refreshing.value }
        guard let creds = credentials(), let refreshToken = creds.refreshToken else { throw CloudAuthError.signInRequired }
        let session = self.session
        let task = Task { () throws -> CloudCredentials in
            let meta = try await CloudAuth.discover(base, session: session)
            do {
                let reply = try await CloudAuth.tokenRequest(meta.token_endpoint, [
                    "grant_type": "refresh_token", "refresh_token": refreshToken, "client_id": creds.clientId,
                ], session: session)
                var next = creds
                next.accessToken = reply.access_token
                next.accessExpiry = CloudAuth.expiry(reply)
                next.refreshToken = reply.refresh_token ?? refreshToken
                return next
            } catch let e as CloudAuth.TokenError where (400..<500).contains(e.status) {
                throw CloudAuthError.signInRequired
            }
        }
        refreshing = task
        refreshCount += 1
        defer { refreshing = nil }
        do {
            let next = try await task.value
            try? store?.save(next)
            cached = .some(next)
            return next
        } catch CloudAuthError.signInRequired {
            // The grant is gone; forget it so the next push starts a fresh sign-in. The address stays.
            store?.delete()
            cached = .some(nil)
            throw CloudAuthError.signInRequired
        }
    }
}
