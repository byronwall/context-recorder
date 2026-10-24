import AppKit
import SwiftUI

/// The sidebar's "In the Cloud" section: sessions pushed from another Mac (or removed from this one) that aren't
/// in the library, each with Download. Hidden until signed in to a configured cloud, and when there are none.
struct CloudOnlySection: View {
    var state: LibraryState
    var cloud = CloudState.shared
    @AppStorage("cloudSectionExpanded") private var expanded = true

    var body: some View {
        let local = Set(state.library.entries.map { CloudBundle.sessionID(for: $0.url) })
        let rows = cloud.cloudOnly(localIDs: local)
        Group {
            if cloud.configured, !rows.isEmpty {
                Section(isExpanded: $expanded) {
                    ForEach(rows) { row in
                        CloudOnlyRow(row: row, root: state.library.downloadRoot) { folder in
                            state.library.refresh()
                            state.open(folder)
                        }
                    }
                } header: {
                    Text("In the Cloud")
                }
            }
        }
        .task { await cloud.refreshRemote() }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            Task { await cloud.refreshRemote() }
        }
    }
}

/// A cloud-only session, laid out like a library row: poster, title, where it came from, and a fixed-size slot on
/// the right for Download, its progress, or why it failed.
struct CloudOnlyRow: View {
    var row: CloudSessionRow
    /// The library folder it downloads into.
    var root: URL
    var downloaded: (URL) -> Void = { _ in }
    /// Drawn off screen by `--cloud-snapshot`.
    var snapshot = false
    var cloud = CloudState.shared

    var body: some View {
        let job = cloud.downloads[row.id]
        HStack(spacing: 10) {
            poster
                .frame(width: 60, height: 38)
                .clipShape(.rect(cornerRadius: 6))
                .overlay(RoundedRectangle(cornerRadius: 6).strokeBorder(.separator.opacity(0.7), lineWidth: 0.5))
                .overlay(alignment: .bottomTrailing) {
                    Text(Format.time(row.duration))
                        .font(.system(size: 9, weight: .semibold).monospacedDigit())
                        .foregroundStyle(.white)
                        .padding(.horizontal, 4).padding(.vertical, 1)
                        .background(.black.opacity(0.55), in: .rect(cornerRadius: 3))
                        .padding(3)
                }
            VStack(alignment: .leading, spacing: 3) {
                // Wraps rather than truncates: these names are read here before deciding to download.
                Text(title).font(.system(size: 13, weight: .semibold)).lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
                // Unchanged while downloading (the ring on the right shows progress), so the row keeps its height.
                Text(detail)
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
            action(job)
                .frame(width: 22, height: 22)
        }
        .padding(.vertical, 4)
        .help("In the cloud, not on this Mac · recorded \(recorded?.formatted(date: .abbreviated, time: .shortened) ?? row.recordedAt) · \(sizeText)")
        .contextMenu {
            Button("Download to This Mac", systemImage: "icloud.and.arrow.down") { download() }
                .disabled(job != nil)
            Button("Open in Browser", systemImage: "globe") { cloud.openRemote(row) }
        }
    }

    @ViewBuilder private var poster: some View {
        ZStack {
            Rectangle().fill(.quaternary)
            if let image = cloud.posters[row.id] {
                Image(nsImage: image).resizable().scaledToFill()
            } else {
                Image(systemName: "icloud").foregroundStyle(.tertiary)
            }
        }
    }

    @ViewBuilder private func action(_ job: CloudState.Job?) -> some View {
        if let job {
            // Drawn rather than a ProgressView, so it also shows in `--cloud-snapshot`.
            ZStack {
                Circle().stroke(.quaternary, lineWidth: 2.5)
                Circle().trim(from: 0, to: max(0.03, job.fraction)).stroke(.tint, style: StrokeStyle(lineWidth: 2.5, lineCap: .round))
                    .rotationEffect(.degrees(-90))
            }
            .frame(width: 15, height: 15)
            .help(job.phase)
        } else if let error = cloud.downloadErrors[row.id] {
            button(Image(systemName: "exclamationmark.icloud").foregroundStyle(.orange))
                .help("Download failed: \(error). Click to try again.")
        } else {
            button(Image(systemName: "icloud.and.arrow.down"))
                .help("Download to this Mac (\(sizeText))")
                .accessibilityLabel("Download \(title)")
        }
    }

    /// ImageRenderer can't draw an AppKit-backed button, so a snapshot shows its icon alone.
    @ViewBuilder private func button(_ icon: some View) -> some View {
        if snapshot { icon } else { Button(action: download) { icon }.buttonStyle(.borderless) }
    }

    private func download() {
        Task {
            if let folder = await cloud.download(row, into: root) { downloaded(folder) }
        }
    }

    private var recorded: Date? { ISO8601DateFormatter().date(from: row.recordedAt) }

    /// The name given in the app, else when it was recorded (as the library shows it).
    private var title: String {
        if row.title != row.id { return row.title }
        return recorded?.formatted(date: .abbreviated, time: .shortened) ?? row.id
    }

    private var sizeText: String { ByteCountFormatter.string(fromByteCount: row.size, countStyle: .file) }

    private var detail: String {
        let marks = row.markCount == 0 ? "No marks" : (row.markCount == 1 ? "1 mark" : "\(row.markCount) marks")
        return [row.machine.map { "From \($0)" }, marks].compactMap { $0 }.joined(separator: " · ")
    }
}

/// `--cloud-snapshot`: the sidebar's cloud rows drawn with ImageRenderer, so UI checks never open a window or take
/// focus. Lists the configured cloud, downloads the first cloud-only session into `library` through the same
/// CloudState path the Download button uses, and writes before/during/after PNGs.
@MainActor
enum CloudSnapshot {
    static func run(library: URL, out: URL) async throws {
        let cloud = CloudState.shared
        try FileManager.default.createDirectory(at: out, withIntermediateDirectories: true)
        await cloud.refreshRemote()
        if let error = cloud.remoteError { throw ReviewError(error) }
        func local() -> Set<String> { Set(SessionLibrary.sessionFolders(in: library).map { CloudBundle.sessionID(for: $0) }) }
        // Posters load in the background.
        for _ in 0..<100 where cloud.posters.count < cloud.remote.filter({ $0.poster != nil }).count { try await Task.sleep(for: .milliseconds(20)) }

        try render(cloud.cloudOnly(localIDs: local()), library: library, to: out.appendingPathComponent("before.png"))
        guard let first = cloud.cloudOnly(localIDs: local()).first else { throw ReviewError("Nothing in the cloud that isn't in \(library.path)") }
        print("cloud-only: " + cloud.cloudOnly(localIDs: local()).map(\.id).joined(separator: ", "))

        let download = Task { await cloud.download(first, into: library) }
        var during = false
        while cloud.downloads[first.id] == nil || cloud.downloads[first.id]?.fraction == 0 {
            if (try? await Task.sleep(for: .milliseconds(2))) == nil { break }
            if cloud.downloads[first.id] == nil, cloud.downloadErrors[first.id] != nil { break }
        }
        if cloud.downloads[first.id] != nil {
            try render(cloud.cloudOnly(localIDs: local()), library: library, to: out.appendingPathComponent("during.png"))
            during = true
        }
        guard let folder = await download.value else { throw ReviewError(cloud.downloadErrors[first.id] ?? "download failed") }
        print("downloaded \(first.id) → \(folder.path)\(during ? "" : " (too fast for a during frame)")")
        print("status: \(cloud.status(folder)), from \(SessionInfo.downloaded(folder)?.machine ?? "?")")
        try render(cloud.cloudOnly(localIDs: local()), library: library, downloaded: folder, to: out.appendingPathComponent("after.png"))
    }

    private static func render(_ rows: [CloudSessionRow], library: URL, downloaded: URL? = nil, to url: URL) throws {
        let view = VStack(alignment: .leading, spacing: 6) {
            if let downloaded {
                HStack(spacing: 6) {
                    Text(SessionInfo.title(downloaded) ?? downloaded.lastPathComponent).font(.system(size: 13, weight: .semibold))
                    CloudRowBadge(folder: downloaded)
                }
                .padding(.bottom, 8)
            }
            Text("In the Cloud").font(.system(size: 11, weight: .semibold)).foregroundStyle(.secondary)
            ForEach(rows) { CloudOnlyRow(row: $0, root: library, snapshot: true) }
            if rows.isEmpty { Text("(section hidden: nothing left in the cloud only)").font(.system(size: 11)).foregroundStyle(.tertiary) }
        }
        .padding(12)
        .frame(width: 260, alignment: .leading)
        .background(Color(nsColor: .windowBackgroundColor))
        let renderer = ImageRenderer(content: view)
        renderer.scale = 2
        guard let image = renderer.cgImage else { throw ReviewError("Couldn't draw \(url.lastPathComponent)") }
        try CloudBundle.writePNG(image, to: url)
    }
}
