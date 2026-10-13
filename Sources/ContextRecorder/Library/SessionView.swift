import AVKit
import QuickLook
import SwiftUI

/// One session: the video on a stage, the shared timeline and the "now" strip, marks in the inspector.
struct SessionView: View {
    @Bindable var model: SessionModel
    @Environment(RecorderController.self) private var recorder
    @State private var showInspector = true
    @State private var quickLook: URL?
    @State private var copiedAll = false

    var body: some View {
        if model.data == nil && model.loadError == nil {
            SessionPendingView(folder: model.folder)
                .navigationTitle(title)
                .toolbar { sessionMenu }
        } else {
            loaded
        }
    }

    private var loaded: some View {
        content
            .navigationTitle(title)
            .navigationSubtitle(subtitle)
            .inspector(isPresented: $showInspector) {
                SidePanel(model: model, quickLook: $quickLook)
                    .inspectorColumnWidth(min: 340, ideal: 400, max: 620)
            }
            .toolbar { toolbar }
            .quickLookPreview($quickLook, in: quickLookItems)
    }

    @ViewBuilder private var content: some View {
        if let error = model.loadError {
            ContentUnavailableView("Can't Open Session", systemImage: "exclamationmark.triangle", description: Text(error))
        } else {
            VStack(spacing: 0) {
                Stage(model: model)
                Divider()
                VStack(alignment: .leading, spacing: 14) {
                    NowStrip(model: model)
                    SessionTimeline(model: model).zIndex(1)
                }
                .padding(.horizontal, 20)
                .padding(.top, 14)
                .padding(.bottom, 18)
                .background(.background)
            }
        }
    }

    @ToolbarContentBuilder private var toolbar: some ToolbarContent {
        if recorder.processing.contains(model.folder) {
            ToolbarItem(placement: .primaryAction) {
                HStack(spacing: 6) {
                    ProgressView().controlSize(.small)
                    Text("Processing…").font(.system(size: 12)).foregroundStyle(.secondary)
                }
                .help("Re-processing this session; it refreshes when done")
            }
        }
        ToolbarItemGroup(placement: .primaryAction) {
            Button {
                copy(model.markdown)
                withAnimation { copiedAll = true }
                Task { try? await Task.sleep(for: .seconds(1.4)); withAnimation { copiedAll = false } }
            } label: {
                Label(copiedAll ? "Copied" : "Copy All as Markdown", systemImage: copiedAll ? "checkmark" : "doc.on.doc")
                    .contentTransition(.symbolEffect(.replace))
            }
            .help("Copy every mark as Markdown, for an agent or an issue")
            .disabled(model.marks.isEmpty)
        }
        sessionMenu
        ToolbarItem(placement: .primaryAction) {
            Button { withAnimation { showInspector.toggle() } } label: { Label("Marks", systemImage: "sidebar.trailing") }
                .help(showInspector ? "Hide marks" : "Show marks")
        }
    }

    @ToolbarContentBuilder private var sessionMenu: some ToolbarContent {
        ToolbarItem(placement: .primaryAction) {
            Menu {
                Button("Reveal in Finder", systemImage: "folder") { NSWorkspace.shared.activateFileViewerSelecting([model.folder]) }
                if FileManager.default.fileExists(atPath: model.folder.appendingPathComponent("viewer.html").path) {
                    Button("Open in Browser", systemImage: "safari") { NSWorkspace.shared.open(model.folder.appendingPathComponent("viewer.html")) }
                }
                if FileManager.default.fileExists(atPath: model.folder.appendingPathComponent("session.md").path) {
                    Button("Open session.md", systemImage: "doc.text") { NSWorkspace.shared.open(model.folder.appendingPathComponent("session.md")) }
                }
                Button("Copy Folder Path", systemImage: "link") { copy(model.folder.path) }
                Divider()
                Button(model.data == nil ? "Process Now" : "Process Again", systemImage: "arrow.clockwise") {
                    recorder.process(model.folder)
                }
                .disabled(!recorder.canRecord || recorder.processing.contains(model.folder))
            } label: {
                Label("Session", systemImage: "ellipsis.circle")
            }
            .help(model.folder.path)
        }
    }

    private var quickLookItems: [URL] {
        model.marks.flatMap { m in [m.image, m.frame].compactMap { model.url($0) } }
            .reduce(into: [URL]()) { if !$0.contains($1) { $0.append($1) } }
    }

    private var title: String {
        let name = model.folder.lastPathComponent
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd_HH-mm-ss"
        f.locale = Locale(identifier: "en_US_POSIX")
        guard let date = f.date(from: name) else { return name }
        return date.formatted(.dateTime.month(.abbreviated).day().year()) + " · " + date.formatted(date: .omitted, time: .shortened)
    }

    private var subtitle: String {
        guard model.data != nil else { return "" }
        let marks = model.marks.count
        let apps = model.appCount
        return [
            Format.time(model.duration),
            marks == 1 ? "1 mark" : "\(marks) marks",
            apps == 1 ? "1 app" : "\(apps) apps",
            model.transcript.isEmpty ? "Silent" : "Narrated",
        ].joined(separator: " · ")
    }
}

func copy(_ text: String) {
    NSPasteboard.general.clearContents()
    NSPasteboard.general.setString(text, forType: .string)
}

// MARK: Stage

/// The recording as a card on the under-page gray, with a floating glass transport.
struct Stage: View {
    var model: SessionModel
    @State private var hovering = false

    var body: some View {
        let aspect = model.videoSize.map { $0.width / $0.height } ?? 16 / 10
        ZStack(alignment: .bottom) {
            Color.stage
            PlayerSurface(player: model.player)
                .aspectRatio(aspect, contentMode: .fit)
                .clipShape(.rect(cornerRadius: 10))
                .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(.black.opacity(0.12), lineWidth: 0.5))
                .shadow(color: .black.opacity(0.18), radius: 18, y: 8)
                .shadow(color: .black.opacity(0.08), radius: 2, y: 1)
                .padding(.horizontal, 28)
                .padding(.top, 22)
                .padding(.bottom, 74)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .onTapGesture { model.togglePlay() }
                .accessibilityLabel("Recording")
                .accessibilityAddTraits(.startsMediaSession)

            Transport(model: model)
                .padding(.bottom, 16)
                .opacity(hovering || !model.isPlaying ? 1 : 0)
                .animation(.easeOut(duration: 0.2), value: hovering || !model.isPlaying)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onHover { hovering = $0 }
    }
}

struct PlayerSurface: NSViewRepresentable {
    var player: AVPlayer

    func makeNSView(context: Context) -> AVPlayerView {
        let view = AVPlayerView()
        view.controlsStyle = .none
        view.videoGravity = .resizeAspect
        view.player = player
        return view
    }

    func updateNSView(_ view: AVPlayerView, context: Context) {
        if view.player !== player { view.player = player }
    }
}

/// QuickTime-style floating controls in Liquid Glass.
struct Transport: View {
    var model: SessionModel

    var body: some View {
        HStack(spacing: 4) {
            control("backward.end.fill", "Previous mark (K)") { model.step(-1) }
            control("gobackward.5", "Back 5 seconds (←)") { model.skip(-5) }
            Button { model.togglePlay() } label: {
                Image(systemName: model.isPlaying ? "pause.fill" : "play.fill")
                    .font(.system(size: 20, weight: .semibold))
                    .frame(width: 40, height: 34)
                    .contentTransition(.symbolEffect(.replace.downUp))
                    .contentShape(.rect)
            }
            .buttonStyle(.plain)
            .help("Play or pause (Space)")
            .accessibilityLabel(model.isPlaying ? "Pause" : "Play")
            control("goforward.5", "Forward 5 seconds (→)") { model.skip(5) }
            control("forward.end.fill", "Next mark (J)") { model.step(1) }

            Divider().frame(height: 18).padding(.horizontal, 6)

            Text("\(Format.time(model.currentTime))  /  \(Format.time(model.duration))")
                .font(.system(size: 12, weight: .medium).monospacedDigit())
                .foregroundStyle(.secondary)
                .frame(minWidth: 84)
                .accessibilityLabel("\(Format.time(model.currentTime)) of \(Format.time(model.duration))")

            Menu {
                Picker("Speed", selection: Binding(get: { model.rate }, set: { model.rate = $0 })) {
                    ForEach([Float(0.5), 1, 1.5, 2], id: \.self) { r in Text(rateText(r)).tag(r) }
                }
                .pickerStyle(.inline)
            } label: {
                Text(rateText(model.rate))
                    .font(.system(size: 11, weight: .semibold).monospacedDigit())
                    .frame(width: 34, height: 22)
            }
            .menuStyle(.button)
            .buttonStyle(.plain)
            .menuIndicator(.hidden)
            .fixedSize()
            .help("Playback speed")
        }
        .foregroundStyle(.primary)
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .glassEffect(.regular, in: .capsule)
    }

    private func control(_ symbol: String, _ help: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 13, weight: .semibold))
                .frame(width: 30, height: 30)
                .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .help(help)
        .accessibilityLabel(help)
    }

    private func rateText(_ r: Float) -> String { r == 1 ? "1×" : (r == 0.5 ? "½×" : "\(Format.number(Double(r)))×") }
}

// MARK: Now strip

/// What was on screen and what was being said at the playhead.
struct NowStrip: View {
    var model: SessionModel

    var body: some View {
        let ctx = model.contextAt(model.currentTime)
        let said = model.sentenceAt(model.currentTime)
        HStack(alignment: .center, spacing: 16) {
            HStack(spacing: 10) {
                AppIcon(bundleID: ctx?.bundleID, size: 30)
                VStack(alignment: .leading, spacing: 1) {
                    Text(ctx?.appName ?? "No activity recorded")
                        .font(.system(size: 13, weight: .semibold))
                        .lineLimit(1)
                    HStack(spacing: 6) {
                        if let w = ctx?.browserTitle ?? ctx?.windowTitle, !w.isEmpty { Text(w).lineLimit(1) }
                        if let u = ctx?.browserURL, let url = URL(string: u) {
                            // A Link's label doesn't inherit lineLimit on macOS; without it a long URL wraps
                            // onto many lines and pushes the timeline down.
                            Link(destination: url) {
                                Text(u.replacingOccurrences(of: "https://", with: "").replacingOccurrences(of: "http://", with: ""))
                                    .lineLimit(1)
                                    .truncationMode(.middle)
                            }
                            .layoutPriority(-1)
                            .help(u)
                        }
                    }
                    .font(.system(size: 11.5))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
                }
            }
            .frame(minWidth: 220, maxWidth: 380, alignment: .leading)
            .accessibilityElement(children: .combine)

            Divider().frame(height: 30)

            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Image(systemName: model.transcript.isEmpty ? "mic.slash" : "quote.opening")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.tertiary)
                Group {
                    if model.transcript.isEmpty {
                        Text("Silent recording").foregroundStyle(.tertiary)
                    } else if let said {
                        Text(said.text).foregroundStyle(.primary)
                            .id(said.start)
                            .transition(.opacity)
                    } else {
                        Text("…").foregroundStyle(.tertiary)
                    }
                }
                .font(.system(size: 13))
                .lineLimit(2)
                .animation(.easeOut(duration: 0.2), value: said)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .accessibilityElement(children: .combine)
            .accessibilityLabel(said.map { "Said: \($0.text)" } ?? "Nothing said")
        }
        // Fixed height (two lines of narration) so the timeline below never shifts as the playhead moves.
        .frame(height: 38)
    }
}
