import AppKit
import SwiftUI

/// Push and sign-in state shared by the sidebar, the session toolbar and the settings sheet. Everything cloud
/// in the UI is hidden until a cloud URL is configured.
@MainActor @Observable
final class CloudState {
    static let shared = CloudState()

    struct Job: Equatable { var phase: String; var fraction: Double }
    enum Status: Equatable { case notPushed, current(CloudRecord), outdated(CloudRecord) }

    private(set) var configured = CloudConfig.current() != nil
    /// The stored sign-in (for whichever cloud URL it was made against).
    private(set) var stored: CloudCredentials?
    private(set) var signingIn = false
    private(set) var jobs: [URL: Job] = [:]
    private(set) var errors: [URL: String] = [:]
    var showSettings = false
    /// Bumped after each push so statuses are read again.
    private(set) var revision = 0

    /// Every session in the cloud (docs/cloud-sessions.md §7); the sidebar lists the ones this Mac doesn't have.
    private(set) var remote: [CloudSessionRow] = []
    private(set) var remoteError: String?
    private(set) var loadingRemote = false
    /// Downloads under way and failed ones, by session id.
    private(set) var downloads: [String: Job] = [:]
    private(set) var downloadErrors: [String: String] = [:]
    /// Posters of cloud-only sessions, fetched with the sign-in.
    private(set) var posters: [String: NSImage] = [:]
    /// A push that replaces a copy another Mac pushed, waiting for a yes.
    var confirmPush: URL?

    @ObservationIgnored private var cache: [URL: (key: String, status: Status)] = [:]
    @ObservationIgnored private var signInTask: Task<CloudCredentials, Error>?
    @ObservationIgnored private var authenticator: WebAuthenticator?

    private init() {
        stored = FileAuthStore().load()
    }

    /// Signed in to the configured cloud.
    var signedIn: Bool { currentAccount != nil }
    var email: String? { currentAccount?.email }
    private var currentAccount: CloudCredentials? { CloudConfig.current().flatMap { account(for: $0.url) } }

    func account(for url: URL) -> CloudCredentials? { stored.flatMap { $0.matches(url) ? $0 : nil } }

    /// Browser sign-in to `url`; a second caller waits for the sign-in already under way.
    @discardableResult
    func signIn(to url: URL) async throws -> CloudCredentials {
        if let signInTask { return try await signInTask.value }
        let auth = WebAuthenticator()
        authenticator = auth
        signingIn = true
        let task = Task { @MainActor in
            try await CloudAuth.signIn(url) { authorize in
                try Task.checkCancellation()
                return try await auth.open(authorize)
            }
        }
        signInTask = task
        defer { signingIn = false; signInTask = nil; authenticator = nil }
        do {
            let credentials = try await task.value
            try await CloudTokenProvider.saved.signedIn(credentials)
            stored = credentials
            revision += 1
            Task { await refreshRemote() }
            return credentials
        } catch is CancellationError {
            throw CloudAuthError.cancelled
        }
    }

    func cancelSignIn() {
        signInTask?.cancel()
        authenticator?.cancel()
    }

    /// Forgets the sign-in (the address stays) and asks the cloud to revoke it.
    func signOut() {
        stored = nil
        remote = []
        Task.detached {
            if let old = await CloudTokenProvider.saved.signOut() { await CloudAuth.revoke(old) }
        }
    }

    /// Something the cloud copy is built from changed in the app; statuses are read again.
    func localChange() { if configured { revision += 1 } }

    func reloadConfig() {
        configured = CloudConfig.current() != nil
        revision += 1
        Task { await refreshRemote() }
    }

    /// Pushed or not, and whether the local session changed since. Cheap when nothing changed: the
    /// input hash is recomputed only when one of its files' timestamps moves.
    func status(_ folder: URL) -> Status {
        let fm = FileManager.default
        var parts = ["\(revision)"]
        for name in ["exports/cloud.json", "session.json", "edits.json", "annotations.json", "session-info.json", "annotations"] {
            let date = (try? fm.attributesOfItem(atPath: folder.appendingPathComponent(name).path)[.modificationDate] as? Date)?.timeIntervalSince1970
            parts.append(date.map { String($0) } ?? "-")
        }
        let key = parts.joined(separator: "|")
        if let hit = cache[folder], hit.key == key { return hit.status }
        let status: Status
        if let record = CloudRecord.load(folder) {
            let hash = try? CloudBundle.inputHash(session: folder)
            status = hash == record.inputHash ? .current(record) : .outdated(record)
        } else {
            status = .notPushed
        }
        cache[folder] = (key, status)
        return status
    }

    func record(_ folder: URL) -> CloudRecord? {
        switch status(folder) {
        case .notPushed: nil
        case .current(let r), .outdated(let r): r
        }
    }

    func isPushing(_ folder: URL) -> Bool { jobs[folder] != nil }

    /// Pushing a session that came down from another Mac replaces that Mac's copy, so it asks first once it changed.
    func push(_ folder: URL, confirmed: Bool = false) {
        guard jobs[folder] == nil else { return }
        guard let config = CloudConfig.current() else { showSettings = true; return }
        if !confirmed, SessionInfo.downloaded(folder) != nil, status(folder).isOutdated {
            confirmPush = folder
            return
        }
        errors[folder] = nil
        // Signed out: sign in first, then push. A local dev Worker needs no sign-in.
        let needsSignIn = account(for: config.url) == nil && config.token == nil && !CloudAuth.isLocal(config.url)
        jobs[folder] = Job(phase: needsSignIn ? "Signing in…" : "Preparing", fraction: 0)
        Task {
            do {
                if needsSignIn { try await signIn(to: config.url) }
                let (_, report) = try await CloudPush.run(session: folder, config: config) { [weak self] phase, f in
                    self?.jobs[folder] = Job(phase: phase, fraction: f)
                }
                NSLog("ContextRecorder: pushed %@ (%@ in %d files): %@", folder.lastPathComponent,
                      ByteCountFormatter.string(fromByteCount: report.uploadedBytes, countStyle: .file), report.uploaded.count,
                      CloudClient.Timing.summary(report.timings))
            } catch CloudAuthError.cancelled {
            } catch {
                errors[folder] = error.localizedDescription
                // A dead sign-in was forgotten by the token provider; show it signed out.
                if case CloudAuthError.signInRequired = error { stored = FileAuthStore().load() }
            }
            jobs[folder] = nil
            revision += 1
        }
    }

    func open(_ folder: URL) {
        if let url = record(folder).flatMap({ URL(string: $0.url) }) { NSWorkspace.shared.open(url) }
    }

    /// The cloud's home page: every pushed session.
    func openLibrary() {
        guard let url = CloudConfig.current()?.url else { showSettings = true; return }
        NSWorkspace.shared.open(url)
    }

    func copyLink(_ folder: URL) {
        guard let url = record(folder)?.url else { return }
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(url, forType: .string)
    }

    // MARK: Sessions from other Macs

    /// Signed in (or a local dev Worker), so the cloud's list can be read without a browser sign-in.
    var canListRemote: Bool {
        guard let config = CloudConfig.current() else { return false }
        return account(for: config.url) != nil || config.token != nil || CloudAuth.isLocal(config.url)
    }

    /// Cloud sessions with no folder of that name in the library, newest recording first (as the cloud lists them).
    func cloudOnly(localIDs: Set<String>) -> [CloudSessionRow] {
        remote.filter { !localIDs.contains($0.id) || downloads[$0.id] != nil }
    }

    func refreshRemote() async {
        guard let config = CloudConfig.current(), canListRemote, !loadingRemote else {
            if !canListRemote { remote = []; remoteError = nil }
            return
        }
        loadingRemote = true
        defer { loadingRemote = false }
        do {
            remote = try await config.client.listSessions()
            remoteError = nil
            for row in remote where posters[row.id] == nil { Task { await loadPoster(row, config: config) } }
        } catch {
            remoteError = error.localizedDescription
            if case CloudAuthError.signInRequired = error { stored = FileAuthStore().load() }
        }
    }

    private func loadPoster(_ row: CloudSessionRow, config: CloudConfig) async {
        guard let poster = row.poster,
              let (data, status) = try? await config.client.request("GET", "s/\(row.id)/\(poster)", body: nil),
              (200..<300).contains(status), let image = NSImage(data: data) else { return }
        posters[row.id] = image
    }

    /// Downloads into the library; returns the new folder so the caller can open it.
    func download(_ row: CloudSessionRow, into root: URL) async -> URL? {
        guard downloads[row.id] == nil, let config = CloudConfig.current() else { return nil }
        downloadErrors[row.id] = nil
        downloads[row.id] = Job(phase: "Starting", fraction: 0)
        defer { downloads[row.id] = nil }
        do {
            let folder = try await CloudPull.run(id: row.id, config: config, into: root) { [weak self] phase, f in
                self?.downloads[row.id] = Job(phase: phase, fraction: f)
            }
            revision += 1
            return folder
        } catch {
            downloadErrors[row.id] = error.localizedDescription
            if case CloudAuthError.signInRequired = error { stored = FileAuthStore().load() }
            return nil
        }
    }

    func openRemote(_ row: CloudSessionRow) {
        guard let base = CloudConfig.current()?.url else { return }
        NSWorkspace.shared.open(base.appendingPathComponent("s/\(row.id)/"))
    }
}

/// Push to Cloud / Push Again for the sidebar's context menu and the session's menu.
struct CloudMenuItems: View {
    var folder: URL
    var cloud = CloudState.shared

    var body: some View {
        if cloud.configured {
            let status = cloud.status(folder)
            Button(status == .notPushed ? "Push to Cloud" : "Push Again", systemImage: "icloud.and.arrow.up") { cloud.push(folder) }
                .disabled(cloud.isPushing(folder))
            if status != .notPushed {
                Button("Open Cloud Copy", systemImage: "globe") { cloud.open(folder) }
                Button("Copy Cloud Link", systemImage: "link") { cloud.copyLink(folder) }
            }
            Button("Open Cloud Library", systemImage: "square.grid.2x2") { cloud.openLibrary() }
        }
    }
}

/// The session toolbar's push control: progress while pushing, otherwise a button that says whether the
/// cloud copy is missing, out of date or current.
struct CloudPushButton: View {
    var folder: URL
    /// Read so the button re-checks when the open session is cut or drawn on.
    var editToken: Int
    var cloud = CloudState.shared

    var body: some View {
        let _ = editToken
        if let job = cloud.jobs[folder] {
            // A ring and a percentage in a fixed width, so the toolbar doesn't jump; the step is in the tooltip.
            HStack(spacing: 6) {
                ProgressView(value: job.fraction).progressViewStyle(.circular).controlSize(.small)
                Text("Pushing \(Int((job.fraction * 100).rounded()))%").font(.system(size: 12)).monospacedDigit()
                    .foregroundStyle(.secondary).lineLimit(1)
            }
            .frame(width: 112, alignment: .leading)
            .help("Pushing to the cloud: \(job.phase)")
        } else {
            let status = cloud.status(folder)
            let error = cloud.errors[folder]
            Button { cloud.push(folder) } label: {
                switch status {
                case .notPushed: Label("Push to Cloud", systemImage: "icloud.and.arrow.up")
                case .current: Label("Push Again", systemImage: "checkmark.icloud")
                case .outdated: Label("Cloud Copy Out of Date", systemImage: "exclamationmark.icloud")
                }
            }
            .labelStyle(.titleAndIcon)
            .foregroundStyle(error != nil || status.isOutdated ? AnyShapeStyle(.orange) : AnyShapeStyle(.primary))
            .help(error.map { "Push failed: \($0)" } ?? help(status))
        }
    }

    private func help(_ status: CloudState.Status) -> String {
        switch status {
        case .notPushed: "Upload a copy of this session, cuts and drawings included, to your cloud"
        case .current(let r): "Pushed \(r.pushedAt). Push again to replace the cloud copy."
        case .outdated(let r): "The session changed since it was pushed (\(r.pushedAt)). Push Again replaces the cloud copy."
        }
    }
}

extension CloudState.Status {
    var isOutdated: Bool { if case .outdated = self { true } else { false } }
}

/// A small icon in a sidebar row: pushing, pushed, or pushed but out of date.
struct CloudRowBadge: View {
    var folder: URL
    var cloud = CloudState.shared

    var body: some View {
        if cloud.configured {
            if cloud.isPushing(folder) {
                ProgressView().controlSize(.mini).help("Pushing to the cloud")
            } else {
                switch cloud.status(folder) {
                case .notPushed: EmptyView()
                case .current:
                    if let from = SessionInfo.downloaded(folder) {
                        let help = "Downloaded from " + (from.machine ?? "another Mac")
                        Image(systemName: "icloud.and.arrow.down").font(.system(size: 10, weight: .semibold)).foregroundStyle(.secondary)
                            .help(help).accessibilityLabel(help)
                    } else {
                        Image(systemName: "checkmark.icloud").font(.system(size: 10, weight: .semibold)).foregroundStyle(.secondary)
                            .help("In the cloud").accessibilityLabel("In the cloud")
                    }
                case .outdated:
                    Image(systemName: "exclamationmark.icloud").font(.system(size: 10, weight: .semibold)).foregroundStyle(.orange)
                        .help("Cloud copy out of date").accessibilityLabel("Cloud copy out of date")
                }
            }
        }
    }
}

/// Cloud address and the account signed in to it. Sign-in happens in the browser; no tokens are shown.
struct CloudSettingsSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var url = CloudSettings.urlString ?? ""
    @State private var error: String?
    var cloud = CloudState.shared

    private var address: URL? { CloudSettings.normalized(url) }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 6) {
                Text("Cloud").font(.title2.weight(.semibold))
                Text("Push sessions to your own Cloudflare Worker to watch and share them anywhere. Leave the URL empty to hide cloud features.")
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Form {
                TextField("Cloud URL", text: $url, prompt: Text("https://sessions.example.com"))
                LabeledContent("Account") { account }
            }
            .formStyle(.columns)
            Text("Signing in opens your browser. A local Worker (wrangler dev) doesn't need it.")
                .font(.callout)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            if let error {
                Text(error).font(.callout).foregroundStyle(.orange).fixedSize(horizontal: false, vertical: true)
            }
            HStack {
                Spacer()
                Button("Cancel") { dismiss() }.keyboardShortcut(.cancelAction)
                Button("Done") { save() }.keyboardShortcut(.defaultAction)
            }
        }
        .padding(24)
        .frame(width: 460)
    }

    @ViewBuilder private var account: some View {
        if cloud.signingIn {
            HStack(spacing: 8) {
                ProgressView().controlSize(.small)
                Text("Waiting for the browser…").foregroundStyle(.secondary)
                Button("Cancel") { cloud.cancelSignIn() }
            }
        } else if let address, let signedIn = cloud.account(for: address) {
            HStack(spacing: 8) {
                Text("Signed in as \(signedIn.email ?? "you")").lineLimit(1).truncationMode(.middle)
                    .help(signedIn.email ?? "")
                Button("Sign Out") { error = nil; cloud.signOut() }
            }
        } else {
            Button("Sign In") { signIn() }.disabled(address == nil)
        }
    }

    /// Saves the address, then signs in to it.
    private func signIn() {
        guard let address else { return }
        error = nil
        CloudSettings.urlString = address.absoluteString
        cloud.reloadConfig()
        Task {
            do { try await cloud.signIn(to: address) } catch CloudAuthError.cancelled {} catch {
                self.error = error.localizedDescription
            }
        }
    }

    private func save() {
        let trimmed = url.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty, address == nil {
            error = "That isn't a web address."
            return
        }
        CloudSettings.urlString = trimmed.isEmpty ? nil : address?.absoluteString
        cloud.reloadConfig()
        dismiss()
    }
}
