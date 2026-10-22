import AVKit
import SwiftUI

/// One session: the video on a stage, the shared timeline and the "now" strip, marks in the inspector.
struct SessionView: View {
    @Bindable var model: SessionModel
    var title: String
    @Environment(RecorderController.self) private var recorder
    @State private var showInspector = true
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
            .frame(minWidth: 0, minHeight: 0)
            .navigationTitle(title)
            .navigationSubtitle(subtitle)
            .inspector(isPresented: $showInspector) {
                SidePanel(model: model)
                    .inspectorColumnWidth(min: 340, ideal: 360, max: 620)
            }
            // Over the stage, timeline and inspector: the image gets the whole session area.
            .overlay {
                if let viewer = model.viewer {
                    ImageViewerOverlay(viewer: viewer)
                        .transition(.opacity.combined(with: .scale(scale: 0.985)))
                }
            }
            .toolbar { toolbar }
            .sheet(item: $model.export) { ExportSheet(model: $0) }
    }

    @ViewBuilder private var content: some View {
        if let error = model.loadError {
            ContentUnavailableView("Can't Open Session", systemImage: "exclamationmark.triangle", description: Text(error))
        } else {
            VStack(spacing: 0) {
                Group {
                    if model.stage == .canvas { CanvasStage(model: model) } else { Stage(model: model) }
                }
                .overlay(alignment: .top) {
                    StatusPill(model: model).padding(.top, 10)
                        .animation(.snappy, value: model.reviewStatus)
                        .animation(.snappy, value: model.regionMode)
                        .animation(.snappy, value: model.canvasBuilding)
                }
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
        ToolbarItem(placement: .principal) {
            if model.canvas != nil {
                Picker("Stage", selection: $model.stage) {
                    ForEach(SessionModel.StageMode.allCases) { Text($0.rawValue).tag($0) }
                }
                .pickerStyle(.segmented)
                .help("Switch between the video and the canvas (C)")
            } else {
                Button { model.buildCanvas() } label: {
                    Label(model.canvasOutdated ? "Rebuild Canvas" : "Build Canvas", systemImage: "rectangle.split.3x1")
                }
                    .help("Lay this recording out in space: scrolled pages become tall columns")
                    .disabled(model.canvasBuilding || model.data == nil)
            }
        }
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
            Button { model.export = ExportSheetModel(session: model) } label: {
                Label("Export to Product Grid", systemImage: "square.and.arrow.up")
            }
            .help("Send this session's marks to a project's Product Grid")
            .disabled(model.marks.isEmpty)

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
        if CloudState.shared.configured, model.data != nil, !recorder.processing.contains(model.folder) {
            ToolbarItem(placement: .primaryAction) {
                CloudPushButton(folder: model.folder, editToken: model.annotations.count &+ (model.edits?.segments.count ?? 0) &* 1000)
            }
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
                Divider()
                if model.canvas != nil {
                    Button("Rebuild Canvas", systemImage: "arrow.clockwise") { model.rebuildCanvas() }
                    Button("Rebuild from a Chosen Area…", systemImage: "crop") { model.chooseCanvasBox() }
                    Button("Delete Canvas", systemImage: "trash") { model.deleteCanvas() }
                } else {
                    Button("Build Canvas", systemImage: "rectangle.split.3x1") { model.buildCanvas() }
                    Button("Build from a Chosen Area…", systemImage: "crop") { model.chooseCanvasBox() }
                }
                Divider()
                Button("Copy Folder Path", systemImage: "link") { copy(model.folder.path) }
                if model.data != nil, CloudState.shared.configured {
                    Divider()
                    CloudMenuItems(folder: model.folder)
                }
                Divider()
                Button("Undo", systemImage: "arrow.uturn.backward") { model.undoEdit() }
                    .disabled(!model.canUndoEdit)
                Button("Redo", systemImage: "arrow.uturn.forward") { model.redoEdit() }
                    .disabled(!model.canRedoEdit)
                Button("Restore Original Recording", systemImage: "film") { model.restoreOriginal() }
                    .disabled(model.edits == nil)
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
                .overlay { AnnotationLayer(model: model) }
                .overlay {
                    if model.regionMode { RegionPicker(model: model) }
                }
                .clipShape(.rect(cornerRadius: 10))
                .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(.black.opacity(0.12), lineWidth: 0.5))
                .overlay {
                    if model.regionMode {
                        RoundedRectangle(cornerRadius: 10).strokeBorder(Color.shot, lineWidth: 2)
                    } else if model.drawMode {
                        RoundedRectangle(cornerRadius: 10).strokeBorder(Color.accentColor, lineWidth: 2)
                    }
                }
                .shadow(color: .black.opacity(0.18), radius: 18, y: 8)
                .shadow(color: .black.opacity(0.08), radius: 2, y: 1)
                .padding(.horizontal, 28)
                .padding(.top, 22)
                .padding(.bottom, 74)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .onTapGesture { if !model.regionMode && !model.drawMode { model.togglePlay() } }
                .accessibilityLabel("Recording")
                .accessibilityAddTraits(.startsMediaSession)

            Transport(model: model)
                .padding(.bottom, 16)
                .opacity(hovering || !model.isPlaying ? 1 : 0)
                .animation(.easeOut(duration: 0.2), value: hovering || !model.isPlaying)
        }
        .overlay(alignment: .top) {
            if model.drawMode && model.reviewStatus == nil && model.reviewError == nil {
                DrawToolbar(model: model).padding(.top, 10)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onHover { hovering = $0 }
    }
}

/// What's happening: picking a region, saving, building the canvas, or an error.
struct StatusPill: View {
    var model: SessionModel

    var body: some View {
        if model.reviewStatus != nil || model.regionMode || model.canvasSelecting || model.reviewError != nil || model.canvasBuilding
            || model.canvasError != nil || (model.stage == .canvas && model.canvasStale) {
            Group {
                if let status = model.reviewStatus {
                    HStack(spacing: 7) { ProgressView().controlSize(.small); Text(status) }
                } else if model.canvasSelecting {
                    HStack(spacing: 7) {
                        Image(systemName: "camera.viewfinder").foregroundStyle(Color.shot)
                        Text("Drag over the canvas to capture a region as a mark · Esc to cancel")
                    }
                } else if model.regionMode && model.regionPurpose == .canvasBox {
                    HStack(spacing: 7) {
                        Image(systemName: "rectangle.split.3x1").foregroundStyle(Color.accentColor)
                        Text("Drag around the page content to build the canvas · click for the whole frame · Esc to cancel")
                    }
                } else if model.regionMode {
                    HStack(spacing: 7) {
                        Image(systemName: "camera.viewfinder").foregroundStyle(Color.shot)
                        Text("Drag over the video to capture a region · click for the whole frame · Esc to cancel")
                    }
                } else if let p = model.canvasProgress {
                    HStack(spacing: 7) {
                        ProgressView(value: p).progressViewStyle(.circular).controlSize(.small)
                        Text("Building canvas… \(Int(p * 100))%").monospacedDigit()
                        Button("Cancel") { model.cancelCanvasBuild() }.buttonStyle(.plain).foregroundStyle(.secondary)
                    }
                } else if let error = model.reviewError ?? model.canvasError {
                    HStack(spacing: 7) {
                        Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(.red)
                        Text(error).lineLimit(2)
                        Button { model.reviewError = nil; model.canvasError = nil } label: { Image(systemName: "xmark") }.buttonStyle(.plain)
                            .accessibilityLabel("Dismiss")
                    }
                } else {
                    HStack(spacing: 7) {
                        Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(.orange)
                        Text("The recording changed since this canvas was built.")
                        Button("Rebuild") { model.rebuildCanvas() }
                    }
                }
            }
            .font(.system(size: 12, weight: .medium))
            .padding(.horizontal, 12).padding(.vertical, 7)
            .glassEffect(.regular, in: .capsule)
            .transition(.move(edge: .top).combined(with: .opacity))
        }
    }
}

/// Drag out a rectangle on the video; a click (no drag) takes the whole frame.
struct RegionPicker: View {
    var model: SessionModel
    @State private var start: CGPoint?
    @State private var end: CGPoint?

    var body: some View {
        GeometryReader { geo in
            let rect = selection
            ZStack(alignment: .topLeading) {
                // Dim everything outside the selection.
                Rectangle()
                    .fill(.black.opacity(rect == nil ? 0.12 : 0.4))
                    .reverseMask { if let rect { Rectangle().frame(width: rect.width, height: rect.height).offset(x: rect.minX, y: rect.minY) } }
                if let rect {
                    Rectangle()
                        .strokeBorder(.white, style: StrokeStyle(lineWidth: 1.5, dash: [5, 3]))
                        .frame(width: rect.width, height: rect.height)
                        .offset(x: rect.minX, y: rect.minY)
                    Text("\(Int(rect.width / geo.size.width * (model.videoSize?.width ?? geo.size.width))) × \(Int(rect.height / geo.size.height * (model.videoSize?.height ?? geo.size.height)))")
                        .font(.system(size: 10, weight: .semibold).monospacedDigit())
                        .foregroundStyle(.white)
                        .padding(.horizontal, 5).padding(.vertical, 2)
                        .background(.black.opacity(0.6), in: .rect(cornerRadius: 4))
                        .offset(x: rect.minX, y: max(0, rect.minY - 20))
                }
            }
            .contentShape(.rect)
            .gesture(DragGesture(minimumDistance: 0)
                .onChanged { g in start = start ?? g.startLocation; end = g.location }
                .onEnded { _ in finish(size: geo.size) })
            .onContinuousHover { phase in
                if case .active = phase { NSCursor.crosshair.set() } else { NSCursor.arrow.set() }
            }
        }
    }

    private var selection: CGRect? {
        guard let start, let end else { return nil }
        return CGRect(x: min(start.x, end.x), y: min(start.y, end.y), width: abs(end.x - start.x), height: abs(end.y - start.y))
    }

    private func finish(size: CGSize) {
        let rect = selection
        start = nil; end = nil
        model.regionMode = false
        NSCursor.arrow.set()
        let purpose = model.regionPurpose
        model.regionPurpose = .shot
        var region: CGRect?
        if let rect, rect.width > 6, rect.height > 6 {
            let clipped = rect.intersection(CGRect(origin: .zero, size: size))
            region = CGRect(x: clipped.minX / size.width, y: clipped.minY / size.height,
                            width: clipped.width / size.width, height: clipped.height / size.height)
        }
        switch purpose {
        case .shot: Task { await model.addReviewShot(region: region) }
        case .canvasBox: model.buildCanvas(region: region)
        }
    }
}

extension View {
    /// Cuts `mask` out of this view.
    func reverseMask<Mask: View>(@ViewBuilder _ mask: () -> Mask) -> some View {
        self.mask {
            Rectangle().overlay(alignment: .topLeading) { mask().blendMode(.destinationOut) }.compositingGroup()
        }
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

    func sizeThatFits(_ proposal: ProposedViewSize, nsView: AVPlayerView, context: Context) -> CGSize? {
        proposal.replacingUnspecifiedDimensions()
    }
}

/// QuickTime-style floating controls in Liquid Glass.
struct Transport: View {
    var model: SessionModel

    var body: some View {
        // Narrow windows drop the 5-second skips (← → still work) before anything gets clipped.
        ViewThatFits(in: .horizontal) {
            controls(compact: false)
            controls(compact: true)
        }
    }

    private func controls(compact: Bool) -> some View {
        HStack(spacing: 4) {
            control("flag", "Add a mark here (M)") { Task { await model.addReviewMark() } }
            control("camera.viewfinder", "Capture a region of this frame (S)") { model.startShot() }
            control(model.drawMode ? "pencil.tip.crop.circle.fill" : "pencil.tip.crop.circle", "Draw on the video (E)") { model.enterDrawMode(!model.drawMode) }

            Divider().frame(height: 18).padding(.horizontal, compact ? 2 : 6)

            control("backward.end.fill", "Previous mark (K)") { model.step(-1) }
            if !compact { control("gobackward.5", "Back 5 seconds (←)") { model.skip(-5) } }
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
            if !compact { control("goforward.5", "Forward 5 seconds (→)") { model.skip(5) } }
            control("forward.end.fill", "Next mark (J)") { model.step(1) }

            Divider().frame(height: 18).padding(.horizontal, compact ? 2 : 6)

            Text("\(Format.time(model.currentTime))  /  \(Format.time(model.duration))")
                .font(.system(size: 12, weight: .medium).monospacedDigit())
                .foregroundStyle(.secondary)
                .frame(minWidth: 84)
                .fixedSize()
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
        .fixedSize()
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
        let ctx = model.contextAt(model.focusTime)
        let said = model.sentenceAt(model.focusTime)
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
