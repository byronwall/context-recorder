import SwiftUI

// MARK: Sidebar record card

/// Pinned to the bottom of the sidebar: the Record button when idle, the live controls while recording.
struct RecordCard: View {
    @Environment(RecorderController.self) private var recorder
    var startFromWindow: () -> Void

    var body: some View {
        @Bindable var recorder = recorder
        VStack(alignment: .leading, spacing: 10) {
            switch recorder.phase {
            case .idle:
                Button(action: startFromWindow) {
                    HStack(spacing: 8) {
                        Image(systemName: "record.circle.fill")
                        Text("Record")
                        Spacer(minLength: 0)
                        Text("⌃⌥R").font(.system(size: 11, weight: .medium).monospaced()).opacity(0.75)
                    }
                    .font(.system(size: 13, weight: .semibold))
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(.red)
                .controlSize(.large)
                .disabled(!recorder.canRecord)
                .help(recorder.canRecord ? "Start recording your screen (⌃⌥R)" : "Recording is off in --library dev runs")

                HStack(spacing: 8) {
                    Toggle(isOn: $recorder.recordMicrophone) {
                        Label("Mic", systemImage: recorder.recordMicrophone ? "mic.fill" : "mic.slash")
                            .font(.system(size: 12))
                            .foregroundStyle(.secondary)
                            .fixedSize()
                    }
                    .toggleStyle(.switch)
                    .controlSize(.mini)
                    .help("Record your narration. It's transcribed and attached to each mark.")
                    Spacer(minLength: 0)
                    ChromeBadge(connected: recorder.chromeConnected)
                }
            case .starting, .recording:
                HStack(spacing: 8) {
                    RecordingDot(active: recorder.phase == .recording, size: 18)
                    Text(Format.time(recorder.elapsed))
                        .font(.system(size: 17, weight: .semibold).monospacedDigit())
                        .contentTransition(.numericText())
                    Text(recorder.phase == .starting ? "Starting…" : marksText)
                        .font(.system(size: 11.5))
                        .foregroundStyle(.secondary)
                    Spacer(minLength: 0)
                    Button { recorder.stop() } label: { Label("Stop", systemImage: "stop.fill") }
                        .buttonStyle(.bordered)
                        .tint(.red)
                        .controlSize(.small)
                        .disabled(recorder.phase != .recording)
                        .help("Stop recording (⌃⌥R)")
                }
                RecordingActions(recorder: recorder, size: .small, includeStop: false)
            case .stopping:
                HStack(spacing: 8) {
                    ProgressView().controlSize(.small)
                    Text("Saving recording…").font(.system(size: 12)).foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, minHeight: 50, alignment: .leading)
            }
        }
        .padding(12)
        .background(.background.opacity(0.55), in: .rect(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(.separator.opacity(0.6), lineWidth: 0.5))
        .padding(.horizontal, 10)
        .padding(.bottom, 10)
        .animation(.snappy(duration: 0.25), value: recorder.phase)
    }

    private var marksText: String {
        let n = recorder.liveMarks.count
        return n == 0 ? "No marks yet" : (n == 1 ? "1 mark" : "\(n) marks")
    }
}

// MARK: Live session

/// The session being recorded right now: the clock, the controls and the marks as you make them.
struct LiveSessionView: View {
    @Environment(RecorderController.self) private var recorder
    var folder: URL

    var body: some View {
        ScrollView {
            VStack(spacing: 22) {
                VStack(spacing: 8) {
                    RecordingDot(active: recorder.phase == .recording, size: 40)
                    Text(Format.time(recorder.elapsed))
                        .font(.system(size: 54, weight: .semibold, design: .rounded).monospacedDigit())
                        .contentTransition(.numericText())
                    Text(status)
                        .font(.system(size: 13))
                        .foregroundStyle(.secondary)
                }
                .padding(.top, 36)

                Text("Work in any app. The recording controls are left out of the video; this window is recorded, so you can review the app with the app.")
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 420)

                RecordingActions(recorder: recorder, size: .large)
                    .frame(maxWidth: 420)

                if recorder.phase == .stopping {
                    ProgressView("Saving recording…").controlSize(.small)
                }

                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Text("Marks").font(.system(size: 13, weight: .semibold))
                        Text("\(recorder.liveMarks.count)").foregroundStyle(.secondary)
                        Spacer()
                        HStack(spacing: 4) { KeyHint("⌃⌥M"); Text("mark").foregroundStyle(.tertiary) }
                        HStack(spacing: 4) { KeyHint("⌃⌥S"); Text("region").foregroundStyle(.tertiary) }
                    }
                    .font(.system(size: 11.5))

                    if recorder.liveMarks.isEmpty {
                        Text("Marks show up here as you make them. Frames and narration are added when you stop.")
                            .font(.system(size: 12))
                            .foregroundStyle(.tertiary)
                            .frame(maxWidth: .infinity, minHeight: 80)
                            .background(.quaternary.opacity(0.35), in: .rect(cornerRadius: 10))
                    } else {
                        LazyVGrid(columns: [GridItem(.adaptive(minimum: 220), spacing: 12, alignment: .top)], alignment: .leading, spacing: 12) {
                            ForEach(recorder.liveMarks.reversed(), id: \.index) { mark in
                                LiveMarkCard(mark: mark, folder: folder,
                                             captured: recorder.capturedShots.contains(mark.index))
                                    .transition(.scale(scale: 0.9).combined(with: .opacity))
                            }
                        }
                    }
                }
                .frame(maxWidth: 760)
                .padding(.top, 8)
                .animation(.snappy, value: recorder.liveMarks.count)
            }
            .padding(.horizontal, 28)
            .padding(.bottom, 28)
            .frame(maxWidth: .infinity)
        }
        .background(Color.stage)
        .navigationTitle("Recording")
        .navigationSubtitle(recorder.recordMicrophone ? "Microphone on" : "Microphone off")
    }

    private var status: String {
        switch recorder.phase {
        case .starting: return "Starting…"
        case .stopping: return "Saving…"
        default:
            return [recorder.recordMicrophone ? "Narration on" : "Silent",
                    recorder.chromeConnected ? "Chrome connected" : "No Chrome extension"].joined(separator: " · ")
        }
    }
}

private struct LiveMarkCard: View {
    var mark: Mark
    var folder: URL
    var captured: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if mark.kind == "screenshot" {
                Thumbnail(url: captured ? mark.screenshot.map { folder.appendingPathComponent($0) } : nil, maxPixel: 480)
                    .frame(height: 110)
                    .clipShape(.rect(cornerRadius: 6))
            }
            HStack(spacing: 8) {
                MarkDisc(index: mark.index, isShot: mark.kind == "screenshot", size: 20)
                Text(mark.kind == "screenshot" ? "Region" : "Mark").font(.system(size: 12, weight: .semibold))
                Spacer(minLength: 0)
                Text(Format.time(mark.offsetSeconds))
                    .font(.system(size: 11.5).monospacedDigit())
                    .foregroundStyle(.secondary)
            }
            HStack(spacing: 6) {
                AppIcon(bundleID: mark.context.bundleID, size: 16)
                VStack(alignment: .leading, spacing: 0) {
                    Text(mark.context.appName ?? "Unknown app").font(.system(size: 11.5, weight: .medium))
                    if let title = mark.context.browserTitle ?? mark.context.windowTitle, !title.isEmpty {
                        Text(title).font(.system(size: 11)).foregroundStyle(.secondary)
                    }
                }
                .lineLimit(1)
                .truncationMode(.middle)
            }
        }
        .padding(10)
        .background(.background, in: .rect(cornerRadius: 10))
        .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(.separator.opacity(0.5), lineWidth: 0.5))
        .accessibilityElement(children: .combine)
    }
}

// MARK: Processing / not processed / failed

/// A session without session.json: processing now (with real progress), failed, or never processed.
struct SessionPendingView: View {
    @Environment(RecorderController.self) private var recorder
    var folder: URL
    @State private var progress = ProcessingProgress()

    var body: some View {
        VStack(spacing: 18) {
            if recorder.processing.contains(folder) {
                processingBody
            } else if recorder.failed.contains(folder) {
                failedBody
            } else {
                unprocessedBody
            }
        }
        .padding(32)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.stage)
        .task(id: folder) {
            while !Task.isCancelled {
                progress = ProcessingProgress(folder: folder)
                try? await Task.sleep(for: .milliseconds(500))
            }
        }
    }

    @ViewBuilder private var processingBody: some View {
        Image(systemName: "waveform.badge.magnifyingglass")
            .font(.system(size: 40, weight: .light))
            .foregroundStyle(.secondary)
            .symbolEffect(.pulse)
        Text("Processing").font(.title2.weight(.semibold))
        VStack(alignment: .leading, spacing: 10) {
            ForEach(progress.steps) { step in
                HStack(spacing: 10) {
                    Group {
                        switch step.state {
                        case .done: Image(systemName: "checkmark.circle.fill").foregroundStyle(.green)
                        case .skipped: Image(systemName: "minus.circle").foregroundStyle(.tertiary)
                        case .active: ProgressView().controlSize(.small)
                        case .waiting: Image(systemName: "circle").foregroundStyle(.quaternary)
                        }
                    }
                    .frame(width: 18)
                    Text(step.title)
                        .foregroundStyle(step.state == .waiting ? .tertiary : (step.state == .skipped ? .secondary : .primary))
                    Spacer(minLength: 0)
                    if let detail = step.detail {
                        Text(detail).foregroundStyle(.secondary).monospacedDigit()
                    }
                }
                .font(.system(size: 13))
            }
        }
        .padding(16)
        .frame(width: 340)
        .background(.background, in: .rect(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(.separator.opacity(0.5), lineWidth: 0.5))
        Text("The session opens here as soon as it's ready.")
            .font(.system(size: 12))
            .foregroundStyle(.secondary)
        logButton
    }

    @ViewBuilder private var failedBody: some View {
        Image(systemName: "exclamationmark.triangle")
            .font(.system(size: 40, weight: .light))
            .foregroundStyle(.orange)
        Text("Processing Didn't Finish").font(.title2.weight(.semibold))
        Text(ProcessingProgress.scriptMissing
             ? "process_session.py wasn't found. Rebuild the app with scripts/build-app.sh."
             : "The video and marks are saved. The last lines of the log are below.")
            .foregroundStyle(.secondary)
            .multilineTextAlignment(.center)
        if !progress.logTail.isEmpty {
            ScrollView {
                Text(progress.logTail)
                    .font(.system(size: 11).monospaced())
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(10)
            }
            .frame(maxWidth: 560, maxHeight: 160)
            .background(.background, in: .rect(cornerRadius: 8))
            .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(.separator.opacity(0.5), lineWidth: 0.5))
        }
        HStack {
            Button("Try Again", systemImage: "arrow.clockwise") { recorder.process(folder) }
                .buttonStyle(.borderedProminent)
                .disabled(!recorder.canRecord)
            logButton
        }
    }

    @ViewBuilder private var unprocessedBody: some View {
        Image(systemName: "film.stack")
            .font(.system(size: 40, weight: .light))
            .foregroundStyle(.secondary)
        Text("Not Processed Yet").font(.title2.weight(.semibold))
        Text("The recording is saved but hasn't been transcribed or turned into a session yet. This happens when the app quits while it's working.")
            .foregroundStyle(.secondary)
            .multilineTextAlignment(.center)
            .frame(maxWidth: 440)
        Button("Process Now", systemImage: "wand.and.stars") { recorder.process(folder) }
            .buttonStyle(.borderedProminent)
            .disabled(!recorder.canRecord)
    }

    @ViewBuilder private var logButton: some View {
        let log = folder.appendingPathComponent("process.log")
        if FileManager.default.fileExists(atPath: log.path) {
            Button("Show Log") { NSWorkspace.shared.open(log) }
                .buttonStyle(.link)
        }
    }
}

/// Progress read straight from the files process_session.py writes, in order:
/// audio.wav → transcript.json → marks/ → frames/NNN.jpg → session.json.
struct ProcessingProgress: Equatable {
    enum State: Equatable { case waiting, active, done, skipped }
    struct Step: Identifiable, Equatable {
        var title: String
        var state: State
        var detail: String?
        var id: String { title }
    }

    var steps: [Step] = []
    var logTail = ""

    static var scriptMissing: Bool { RecorderController.processScriptURL() == nil }

    init() {}

    init(folder: URL) {
        let fm = FileManager.default
        func has(_ name: String) -> Bool { fm.fileExists(atPath: folder.appendingPathComponent(name).path) }
        let marks = (try? String(contentsOf: folder.appendingPathComponent("marks.jsonl"), encoding: .utf8))?
            .split(separator: "\n").count ?? 0
        let frames = (try? fm.contentsOfDirectory(atPath: folder.appendingPathComponent("frames").path))?
            .filter { $0.hasSuffix(".jpg") }.count ?? 0
        let transcribed = has("marks")          // created right after transcription
        let finished = has("session.json")

        steps = [
            Step(title: "Video saved", state: has("recording.mp4") ? .done : .active),
            Step(title: "Transcribing narration",
                 state: transcribed ? (has("transcript.json") ? .done : .skipped) : .active,
                 detail: transcribed && !has("transcript.json") ? "Silent" : nil),
            Step(title: "Pulling frames for marks",
                 state: finished ? .done : (transcribed ? .active : .waiting),
                 detail: marks > 0 && transcribed ? "\(min(frames, marks)) of \(marks)" : (marks == 0 ? "No marks" : nil)),
            Step(title: "Building the session", state: finished ? .done : .waiting),
        ]
        if let log = try? String(contentsOf: folder.appendingPathComponent("process.log"), encoding: .utf8) {
            logTail = log.split(separator: "\n", omittingEmptySubsequences: true).suffix(12).joined(separator: "\n")
        }
    }
}
