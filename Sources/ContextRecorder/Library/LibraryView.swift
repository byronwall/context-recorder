import SwiftUI

struct LibraryView: View {
    @Bindable var state: LibraryState

    var body: some View {
        NavigationSplitView {
            SessionSidebar(state: state)
                .navigationSplitViewColumnWidth(min: 220, ideal: 240, max: 360)
        } detail: {
            if let model = state.model {
                if state.isLive(model.folder) {
                    LiveSessionView(folder: model.folder)
                } else {
                    SessionView(model: model, title: state.library.entries.first { $0.url == model.folder }?.title
                                    ?? SessionTitle.title(for: model.folder))
                        .id(ObjectIdentifier(model))
                }
            } else if state.selection.count > 1 {
                MultipleSelection(state: state)
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
            if let first = found.first { state.open(first) }
            return !found.isEmpty
        }
        .sheet(isPresented: $state.showShortcuts) { ShortcutsSheet() }
        .confirmationDialog(trashTitle, isPresented: Binding(get: { !state.confirmTrash.isEmpty },
                                                             set: { if !$0 { state.confirmTrash = [] } })) {
            Button("Move to Trash", role: .destructive) { state.trashConfirmed() }
        } message: {
            Text("The recording, screenshots and notes go to the Trash. You can put them back from there.")
        }
    }

    private var trashTitle: String {
        let n = state.confirmTrash.count
        if n == 1, let url = state.confirmTrash.first {
            let name = state.library.entries.first { $0.url == url }?.title ?? url.lastPathComponent
            return "Move “\(name)” to the Trash?"
        }
        return "Move \(n) sessions to the Trash?"
    }
}

/// Shown when several sessions are selected: what they add up to, and the one thing to do with them.
struct MultipleSelection: View {
    var state: LibraryState

    var body: some View {
        let entries = state.library.entries.filter { state.selection.contains($0.url) }
        let duration = entries.compactMap(\.duration).reduce(0, +)
        let marks = entries.map(\.markCount).reduce(0, +)
        ContentUnavailableView {
            Label("\(entries.count) Sessions Selected", systemImage: "rectangle.stack")
        } description: {
            Text("\(Format.time(duration)) of recording · \(marks == 1 ? "1 mark" : "\(marks) marks")")
        } actions: {
            Button("Join into One Session", systemImage: "rectangle.stack.badge.plus") { state.join(state.selection) }
                .buttonStyle(.borderedProminent)
                .disabled(state.joinStatus?.hasSuffix("…") == true)
                .help("Play these sessions end to end, oldest first, as a new session. The originals are kept as they are.")
            Button("Move to Trash", systemImage: "trash", role: .destructive) { state.requestTrash(state.selection) }
                .keyboardShortcut(.delete, modifiers: .command)
            if let status = state.joinStatus {
                Text(status).font(.callout).foregroundStyle(.secondary)
            }
        }
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
                        SessionRow(entry: entry, status: status(of: entry), state: state)
                            .tag(entry.url)
                    }
                }
            }
        }
        .listStyle(.sidebar)
        .contextMenu(forSelectionType: URL.self) { urls in
            menu(for: urls)
        }
        .onDeleteCommand { state.requestTrash(state.selection) }
        .onKeyPress(.return) {
            guard state.renaming == nil, state.selection.count == 1, let url = state.selection.first else { return .ignored }
            state.renaming = url
            return .handled
        }
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
            state.open(folder)
        }
    }

    private func status(of entry: SessionEntry) -> SessionRow.Status {
        let r = state.recorder
        if state.isLive(entry.url) { return .recording(r.elapsed) }
        if r.processing.contains(entry.url) { return .processing }
        if r.failed.contains(entry.url) { return .failed }
        return entry.processed ? .ready : .unprocessed
    }

    @ViewBuilder private func menu(for urls: Set<URL>) -> some View {
        let entries = state.library.entries.filter { urls.contains($0.url) }
        if entries.count == 1, let entry = entries.first {
            Button("Rename…", systemImage: "pencil") { state.open(entry.url); state.renaming = entry.url }
            Divider()
            Button("Reveal in Finder", systemImage: "folder") { NSWorkspace.shared.activateFileViewerSelecting([entry.url]) }
            if FileManager.default.fileExists(atPath: entry.url.appendingPathComponent("viewer.html").path) {
                Button("Open in Browser", systemImage: "safari") { NSWorkspace.shared.open(entry.url.appendingPathComponent("viewer.html")) }
            }
            if !state.isLive(entry.url) {
                Button(entry.processed ? "Process Again" : "Process Now", systemImage: "arrow.clockwise") { state.recorder.process(entry.url) }
                    .disabled(!state.recorder.canRecord || state.recorder.processing.contains(entry.url))
            }
        } else if !entries.isEmpty {
            Button("Join into One Session", systemImage: "rectangle.stack.badge.plus") { state.join(entries.map(\.url)) }
            Button("Reveal in Finder", systemImage: "folder") { NSWorkspace.shared.activateFileViewerSelecting(entries.map(\.url)) }
        }
        let external = entries.filter { state.library.isExternal($0) }
        if !external.isEmpty {
            Button(external.count == 1 ? "Remove from Library" : "Remove \(external.count) from Library", systemImage: "minus.circle") {
                state.selection.subtract(external.map(\.url))
                external.forEach { state.library.remove($0) }
            }
        }
        let trashable = entries.filter { !state.isLive($0.url) && !state.recorder.processing.contains($0.url) }
        if !trashable.isEmpty {
            Divider()
            Button(trashable.count == 1 ? "Move to Trash" : "Move \(trashable.count) Sessions to Trash", systemImage: "trash",
                   role: .destructive) { state.requestTrash(trashable.map(\.url)) }
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
    var state: LibraryState

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
                    if state.renaming == entry.url {
                        RenameField(entry: entry, state: state)
                    } else {
                        Text(rowTitle)
                            .font(.system(size: 13, weight: .semibold))
                            .lineLimit(1)
                    }
                }
                HStack(spacing: 5) {
                    Text(detail)
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                    if entry.narrated {
                        Image(systemName: "waveform")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundStyle(.secondary)
                            .help("Narrated: has a transcript")
                            .accessibilityLabel("Narrated")
                    }
                    Spacer(minLength: 0)
                    HStack(spacing: -3) {
                        ForEach(entry.appBundleIDs.prefix(4), id: \.self) { AppIcon(bundleID: $0, size: 14) }
                    }
                }
            }
        }
        .padding(.vertical, 4)
        .help(entry.url.path)
        .accessibilityElement(children: state.renaming == entry.url ? .contain : .combine)
    }

    private var liveElapsed: Double? {
        if case .recording(let t) = status { return t }
        return nil
    }

    private var time: String? { entry.date?.formatted(date: .omitted, time: .shortened) }

    /// The name given with Rename, else the time it was recorded.
    private var rowTitle: String { entry.customTitle ?? time ?? entry.url.lastPathComponent }

    private var detail: String {
        let n = entry.markCount
        let count = n == 0 ? "No marks" : (n == 1 ? "1 mark" : "\(n) marks")
        let marks: String
        switch status {
        case .recording: return "Recording…"
        case .processing: marks = n > 0 ? "Processing · \(count)" : "Processing…"
        case .failed: marks = "Processing failed"
        case .unprocessed: marks = n > 0 ? "Not processed · \(count)" : "Not processed"
        case .ready: marks = count
        }
        // A named session still shows when it was recorded.
        if entry.customTitle != nil, let time { return "\(time) · \(marks)" }
        return marks
    }
}

/// Inline name editor. Return saves, Esc cancels, an empty name goes back to the date.
struct RenameField: View {
    var entry: SessionEntry
    var state: LibraryState
    @State private var text = ""
    @FocusState private var focused: Bool

    var body: some View {
        TextField("Name", text: $text, prompt: Text(entry.date?.formatted(date: .omitted, time: .shortened) ?? "Name"))
            .accessibilityLabel("Session name")
            .textFieldStyle(.plain)
            .font(.system(size: 13, weight: .semibold))
            .focused($focused)
            .onAppear {
                text = entry.customTitle ?? ""
                DispatchQueue.main.async { focused = true }
            }
            .onSubmit { commit() }
            .onExitCommand { state.renaming = nil }
            .onChange(of: focused) { _, isFocused in if !isFocused, state.renaming == entry.url { commit() } }
    }

    private func commit() {
        guard state.renaming == entry.url else { return }
        state.renaming = nil
        try? state.library.rename(entry.url, to: text)
    }
}

/// Square-cropped, downsampled image loaded off the main thread.
struct Thumbnail: View {
    var url: URL?
    var maxPixel: CGFloat = 400
    /// Change it to reload the same file (an annotated copy rewritten in place).
    var revision = 0
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
        .task(id: "\(url?.path ?? "")#\(revision)") { image = await ImageCache.shared.image(url, maxPixel: maxPixel) }
    }
}

/// Downsampled images keyed by file, size and modification date: annotated copies are rewritten in place.
actor ImageCache {
    static let shared = ImageCache()
    private var cache: [String: NSImage] = [:]

    func image(_ url: URL?, maxPixel: CGFloat) -> NSImage? {
        guard let url else { return nil }
        let modified = (try? url.resourceValues(forKeys: [.contentModificationDateKey]))?.contentModificationDate
        let key = "\(url.path)@\(Int(maxPixel))@\(modified?.timeIntervalSince1970 ?? 0)"
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
        ("M", "Add a mark at the playhead"),
        ("S", "Capture a region of the current frame"),
        ("→  ←", "Skip 5 seconds forward or back"),
        ("I  O", "Start or end a selection at the playhead"),
        ("⇧ drag", "Select a range on the timeline"),
        ("⌫", "Cut the selected range"),
        ("⌘Z  ⇧⌘Z", "Undo or redo a cut or drawing"),
        ("E", "Draw on the video (E or Esc to finish)"),
        ("S R A T H D", "In draw mode: select, rectangle, arrow, text, highlight, draw"),
        ("V R A T H P C", "Image viewer: select, rectangle, arrow, text, highlight, freehand, crop"),
        ("⌘Z  ⇧⌘Z", "Image viewer: undo, redo"),
        ("Esc", "Close the image viewer"),
        ("Return", "Rename the selected session"),
        ("⌘⌫", "Move the selected sessions to the Trash"),
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
