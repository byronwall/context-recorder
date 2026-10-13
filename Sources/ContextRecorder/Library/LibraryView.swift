import SwiftUI

struct LibraryView: View {
    @Bindable var state: LibraryState

    var body: some View {
        NavigationSplitView {
            SessionSidebar(state: state)
                .navigationSplitViewColumnWidth(min: 220, ideal: 260, max: 340)
        } detail: {
            if let model = state.model {
                if state.isLive(model.folder) {
                    LiveSessionView(folder: model.folder)
                } else {
                    SessionView(model: model)
                        .id(ObjectIdentifier(model))
                }
            } else {
                ContentUnavailableView {
                    Label("No Session Selected", systemImage: "play.rectangle")
                } description: {
                    Text(state.library.entries.isEmpty
                         ? "Press Record (or ⌃⌥R anywhere) to capture your screen. Sessions appear here."
                         : "Choose a session from the sidebar.")
                }
            }
        }
        .dropDestination(for: URL.self) { urls, _ in
            let found = urls.flatMap { state.library.add(folder: $0) }
            if let first = found.first { state.selection = first }
            return !found.isEmpty
        }
        .sheet(isPresented: $state.showShortcuts) { ShortcutsSheet() }
    }
}

// MARK: Sidebar

struct SessionSidebar: View {
    @Bindable var state: LibraryState

    var body: some View {
        List(selection: $state.selection) {
            ForEach(groups, id: \.title) { group in
                Section(group.title) {
                    ForEach(group.entries) { entry in
                        SessionRow(entry: entry, status: status(of: entry))
                            .tag(entry.url)
                            .contextMenu { menu(for: entry) }
                    }
                }
            }
        }
        .listStyle(.sidebar)
        .overlay {
            if state.library.entries.isEmpty {
                ContentUnavailableView("No Sessions", systemImage: "record.circle",
                                       description: Text("Recordings are saved to ~/Movies/ContextRecorder."))
            }
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            RecordCard(startFromWindow: state.startFromWindow)
        }
        // A new recording shows up at the top of the list and is opened, so you see it live.
        .onChange(of: state.recorder.recordingFolder) { _, folder in
            guard let folder, state.recorder.isRecording else { return }
            state.library.refresh()
            state.selection = folder
        }
    }

    private func status(of entry: SessionEntry) -> SessionRow.Status {
        let r = state.recorder
        if state.isLive(entry.url) { return .recording(r.elapsed) }
        if r.processing.contains(entry.url) { return .processing }
        if r.failed.contains(entry.url) { return .failed }
        return entry.processed ? .ready : .unprocessed
    }

    @ViewBuilder private func menu(for entry: SessionEntry) -> some View {
        Button("Reveal in Finder") { NSWorkspace.shared.activateFileViewerSelecting([entry.url]) }
        if FileManager.default.fileExists(atPath: entry.url.appendingPathComponent("viewer.html").path) {
            Button("Open in Browser") { NSWorkspace.shared.open(entry.url.appendingPathComponent("viewer.html")) }
        }
        if !state.isLive(entry.url) {
            Button(entry.processed ? "Process Again" : "Process Now") { state.recorder.process(entry.url) }
                .disabled(!state.recorder.canRecord || state.recorder.processing.contains(entry.url))
        }
        Divider()
        if state.library.isExternal(entry) {
            Button("Remove from Library") {
                if state.selection == entry.url { state.selection = nil }
                state.library.remove(entry)
            }
        } else if !state.isLive(entry.url) {
            Button("Move to Trash", role: .destructive) {
                NSWorkspace.shared.recycle([entry.url]) { _, error in
                    if let error { NSLog("ContextRecorder: trash failed: \(error)"); return }
                    Task { @MainActor in
                        if state.selection == entry.url { state.selection = nil }
                        state.library.refresh()
                    }
                }
            }
            .disabled(state.recorder.processing.contains(entry.url))
        }
    }

    private struct Group { var title: String; var entries: [SessionEntry] }

    /// Today / Yesterday / weekday / full date, newest first.
    private var groups: [Group] {
        let cal = Calendar.current
        var out: [Group] = []
        for e in state.library.entries {
            let title: String
            if let d = e.date {
                if cal.isDateInToday(d) { title = "Today" }
                else if cal.isDateInYesterday(d) { title = "Yesterday" }
                else if let days = cal.dateComponents([.day], from: cal.startOfDay(for: d), to: cal.startOfDay(for: .now)).day, days < 7 {
                    title = d.formatted(.dateTime.weekday(.wide))
                } else {
                    title = d.formatted(.dateTime.month(.wide).day().year())
                }
            } else {
                title = "Other"
            }
            if out.last?.title == title { out[out.count - 1].entries.append(e) } else { out.append(Group(title: title, entries: [e])) }
        }
        return out
    }
}

struct SessionRow: View {
    enum Status: Equatable { case recording(Double), processing, failed, unprocessed, ready }
    var entry: SessionEntry
    var status: Status

    var body: some View {
        HStack(spacing: 10) {
            Thumbnail(url: entry.thumbnail, maxPixel: 200)
                .frame(width: 60, height: 38)
                .clipShape(.rect(cornerRadius: 6))
                .overlay(RoundedRectangle(cornerRadius: 6).strokeBorder(.separator.opacity(0.7), lineWidth: 0.5))
                .overlay(alignment: .bottomTrailing) {
                    if let d = liveElapsed ?? entry.duration {
                        Text(Format.time(d))
                            .font(.system(size: 9, weight: .semibold).monospacedDigit())
                            .foregroundStyle(.white)
                            .padding(.horizontal, 4).padding(.vertical, 1)
                            .background(.black.opacity(0.55), in: .rect(cornerRadius: 3))
                            .padding(3)
                    }
                }
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 5) {
                    switch status {
                    case .recording:
                        Circle().fill(.red).frame(width: 7, height: 7)
                    case .processing:
                        ProgressView().controlSize(.mini)
                    case .failed:
                        Image(systemName: "exclamationmark.triangle.fill").font(.system(size: 9)).foregroundStyle(.orange)
                    default:
                        EmptyView()
                    }
                    Text(timeTitle)
                        .font(.system(size: 13, weight: .semibold))
                        .lineLimit(1)
                }
                HStack(spacing: 5) {
                    Text(detail)
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                    Spacer(minLength: 0)
                    HStack(spacing: -3) {
                        ForEach(entry.appBundleIDs.prefix(4), id: \.self) { AppIcon(bundleID: $0, size: 14) }
                    }
                }
            }
        }
        .padding(.vertical, 4)
        .help(entry.url.path)
        .accessibilityElement(children: .combine)
    }

    private var liveElapsed: Double? {
        if case .recording(let t) = status { return t }
        return nil
    }

    private var timeTitle: String {
        guard let d = entry.date else { return entry.url.lastPathComponent }
        return d.formatted(date: .omitted, time: .shortened)
    }

    private var detail: String {
        let marks = entry.markCount
        let count = marks == 1 ? "1 mark" : "\(marks) marks"
        switch status {
        case .recording: return "Recording…"
        case .processing: return marks > 0 ? "Processing · \(count)" : "Processing…"
        case .failed: return "Processing failed"
        case .unprocessed: return marks > 0 ? "Not processed · \(count)" : "Not processed"
        case .ready: break
        }
        return marks == 0 ? "No marks" : (marks == 1 ? "1 mark" : "\(marks) marks")
    }
}

/// Square-cropped, downsampled image loaded off the main thread.
struct Thumbnail: View {
    var url: URL?
    var maxPixel: CGFloat = 400
    @State private var image: NSImage?

    var body: some View {
        ZStack {
            Rectangle().fill(.quaternary)
            if let image {
                Image(nsImage: image).resizable().scaledToFill()
            } else {
                Image(systemName: "photo").foregroundStyle(.tertiary)
            }
        }
        .task(id: url) { image = await ImageCache.shared.image(url, maxPixel: maxPixel) }
    }
}

/// Downsampled images keyed by file and size. Session images don't change once written.
actor ImageCache {
    static let shared = ImageCache()
    private var cache: [String: NSImage] = [:]

    func image(_ url: URL?, maxPixel: CGFloat) -> NSImage? {
        guard let url else { return nil }
        let key = "\(url.path)@\(Int(maxPixel))"
        if let hit = cache[key] { return hit }
        guard let src = CGImageSourceCreateWithURL(url as CFURL, nil),
              let cg = CGImageSourceCreateThumbnailAtIndex(src, 0, [
                  kCGImageSourceCreateThumbnailFromImageAlways: true,
                  kCGImageSourceThumbnailMaxPixelSize: maxPixel,
                  kCGImageSourceCreateThumbnailWithTransform: true,
              ] as CFDictionary) else { return nil }
        let image = NSImage(cgImage: cg, size: NSSize(width: cg.width, height: cg.height))
        cache[key] = image
        return image
    }
}

struct ShortcutsSheet: View {
    @Environment(\.dismiss) private var dismiss
    private let rows: [(String, String)] = [
        ("Space", "Play or pause"),
        ("J", "Next mark"),
        ("K", "Previous mark"),
        ("→  ←", "Skip 5 seconds forward or back"),
        ("Esc", "Close Quick Look"),
        ("⌃⌥R", "Start or stop recording (anywhere)"),
        ("⌃⌥M", "Mark this moment (anywhere)"),
        ("⌃⌥S", "Region screenshot (anywhere)"),
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Keyboard Shortcuts").font(.title2.weight(.semibold))
            Grid(alignment: .leading, horizontalSpacing: 24, verticalSpacing: 8) {
                ForEach(rows, id: \.0) { key, action in
                    GridRow {
                        Text(key).font(.body.monospaced()).foregroundStyle(.secondary)
                        Text(action)
                    }
                }
            }
            HStack {
                Spacer()
                Button("Done") { dismiss() }.keyboardShortcut(.defaultAction)
            }
        }
        .padding(24)
        .frame(width: 420)
    }
}
