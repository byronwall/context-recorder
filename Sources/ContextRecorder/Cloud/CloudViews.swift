import AppKit
import SwiftUI

/// Push state shared by the sidebar, the session toolbar and the settings sheet. Everything cloud in the
/// UI is hidden until a cloud URL is configured.
@MainActor @Observable
final class CloudState {
    static let shared = CloudState()

    struct Job: Equatable { var phase: String; var fraction: Double }
    enum Status: Equatable { case notPushed, current(CloudRecord), outdated(CloudRecord) }

    private(set) var configured = CloudConfig.current() != nil
    private(set) var jobs: [URL: Job] = [:]
    private(set) var errors: [URL: String] = [:]
    var showSettings = false
    /// Bumped after each push so statuses are read again.
    private(set) var revision = 0

    @ObservationIgnored private var cache: [URL: (key: String, status: Status)] = [:]

    /// Something the cloud copy is built from changed in the app; statuses are read again.
    func localChange() { if configured { revision += 1 } }

    func reloadConfig() {
        configured = CloudConfig.current() != nil
        revision += 1
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

    func push(_ folder: URL) {
        guard jobs[folder] == nil else { return }
        guard let config = CloudConfig.current() else { showSettings = true; return }
        errors[folder] = nil
        jobs[folder] = Job(phase: "Preparing", fraction: 0)
        Task {
            do {
                _ = try await CloudPush.run(session: folder, config: config) { [weak self] phase, f in
                    self?.jobs[folder] = Job(phase: phase, fraction: f)
                }
            } catch {
                errors[folder] = error.localizedDescription
            }
            jobs[folder] = nil
            revision += 1
        }
    }

    func open(_ folder: URL) {
        if let url = record(folder).flatMap({ URL(string: $0.url) }) { NSWorkspace.shared.open(url) }
    }

    func copyLink(_ folder: URL) {
        guard let url = record(folder)?.url else { return }
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(url, forType: .string)
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
            HStack(spacing: 6) {
                ProgressView(value: job.fraction).frame(width: 64)
                Text(job.phase).font(.system(size: 12)).foregroundStyle(.secondary).lineLimit(1)
                    .frame(width: 150, alignment: .leading)
            }
            .help("Pushing this session to the cloud")
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
                    Image(systemName: "checkmark.icloud").font(.system(size: 10, weight: .semibold)).foregroundStyle(.secondary)
                        .help("In the cloud").accessibilityLabel("In the cloud")
                case .outdated:
                    Image(systemName: "exclamationmark.icloud").font(.system(size: 10, weight: .semibold)).foregroundStyle(.orange)
                        .help("Cloud copy out of date").accessibilityLabel("Cloud copy out of date")
                }
            }
        }
    }
}

/// Cloud URL and the Access service token (kept in the Keychain).
struct CloudSettingsSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var url = CloudSettings.urlString ?? ""
    @State private var clientId = CloudSettings.token()?.id ?? ""
    @State private var secret = CloudSettings.token()?.secret ?? ""
    @State private var error: String?

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
                TextField("Service token ID", text: $clientId, prompt: Text("CF-Access-Client-Id"))
                SecureField("Service token secret", text: $secret, prompt: Text("CF-Access-Client-Secret"))
            }
            .formStyle(.columns)
            Text("The service token is stored in your Keychain. It isn't needed for a local Worker (wrangler dev).")
                .font(.callout)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            if let error {
                Text(error).font(.callout).foregroundStyle(.orange)
            }
            HStack {
                Spacer()
                Button("Cancel") { dismiss() }.keyboardShortcut(.cancelAction)
                Button("Save") { save() }.keyboardShortcut(.defaultAction)
            }
        }
        .padding(24)
        .frame(width: 460)
    }

    private func save() {
        let trimmed = url.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty, CloudSettings.normalized(trimmed) == nil {
            error = "That isn't a web address."
            return
        }
        do {
            CloudSettings.urlString = trimmed.isEmpty ? nil : CloudSettings.normalized(trimmed)?.absoluteString
            try CloudSettings.setToken(id: clientId, secret: secret)
            CloudState.shared.reloadConfig()
            dismiss()
        } catch {
            self.error = error.localizedDescription
        }
    }
}
