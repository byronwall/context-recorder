import AppKit
import SwiftUI

/// Floating recording controls, shown only while recording: one slim row with the clock, the microphone
/// level, the mark count and Mark / Region / Stop. Our own windows are left out of the capture, so it can
/// stay on screen. Drag it anywhere; hover and click × (or right-click → Hide) to hide it until the next
/// recording (or Recording → Show Recording Controls).
@MainActor
final class RecordingHUDController {
    private let panel: NSPanel

    init(recorder: RecorderController, openSessions: @escaping () -> Void) {
        panel = HUDPanel(contentRect: NSRect(x: 0, y: 0, width: 260, height: 34),
                         styleMask: [.borderless, .nonactivatingPanel],
                         backing: .buffered, defer: false)
        panel.title = "Recording"
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.isMovableByWindowBackground = true
        panel.isFloatingPanel = true
        panel.level = .floating
        panel.hidesOnDeactivate = false
        panel.isReleasedWhenClosed = false
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        let host = NSHostingController(rootView: RecordingHUD(recorder: recorder, openSessions: openSessions,
                                                              hide: { [weak panel] in panel?.orderOut(nil) }))
        host.sizingOptions = .preferredContentSize
        host.view.wantsLayer = true
        host.view.layer?.backgroundColor = .clear
        panel.contentViewController = host
        // New name: frames saved for the old, taller panel would place this one oddly.
        panel.setFrameAutosaveName("RecordingHUD.compact")

        // Follow the recorder: appear when a recording starts, leave when it's saved.
        var wasRecording = false
        observeContinuously { [weak self] in
            let recording = recorder.isRecording
            if recording != wasRecording {
                wasRecording = recording
                if recording { self?.show() } else { self?.panel.orderOut(nil) }
            }
        }
    }

    func show() {
        if panel.frame.origin == .zero || !NSScreen.screens.contains(where: { $0.visibleFrame.intersects(panel.frame) }),
           let screen = NSScreen.main {
            panel.layoutIfNeeded()
            let f = screen.visibleFrame
            panel.setFrameTopLeftPoint(NSPoint(x: f.maxX - panel.frame.width - 16, y: f.maxY - 12))
        }
        panel.orderFrontRegardless()
    }
}

/// A borderless panel still takes clicks on its buttons without activating the app.
private final class HUDPanel: NSPanel {
    override var canBecomeKey: Bool { true }
}

struct RecordingHUD: View {
    var recorder: RecorderController
    var openSessions: () -> Void
    var hide: () -> Void
    @State private var hovering = false

    var body: some View {
        HStack(spacing: 8) {
            ZStack {
                RecordingDot(active: recorder.phase == .recording, size: 16)
                    .opacity(hovering ? 0 : 1)
                Button(action: hide) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 13))
                        .foregroundStyle(.secondary)
                        .frame(width: 16, height: 16)
                        .contentShape(.rect)
                }
                .buttonStyle(.plain)
                .opacity(hovering ? 1 : 0)
                .help("Hide the controls until the next recording (Recording → Show Recording Controls brings them back)")
            }

            Text(clock)
                .font(.system(size: 13, weight: .semibold).monospacedDigit())
                .contentTransition(.numericText())
                .frame(minWidth: 34, alignment: .leading)

            MicMeter(recorder: recorder, bars: 22, height: 14)

            Label {
                Text("\(recorder.liveMarks.count)").monospacedDigit().contentTransition(.numericText())
            } icon: {
                Image(systemName: "flag.fill").font(.system(size: 9))
            }
            .labelStyle(TightLabel())
            .font(.system(size: 11.5, weight: .medium))
            .foregroundStyle(recorder.liveMarks.isEmpty ? .tertiary : .secondary)
            .frame(minWidth: 26, alignment: .leading)
            .help(lastMarkHelp)

            HStack(spacing: 2) {
                HUDButton(symbol: "flag.fill", help: "Mark this moment (⌃⌥M)", bounce: recorder.liveMarks.count) {
                    recorder.mark()
                }
                HUDButton(symbol: "viewfinder", help: "Screenshot a region (⌃⌥S)") { recorder.screenshot() }
                HUDButton(symbol: "stop.fill", help: "Stop recording (⌃⌥R)", tint: .red) { recorder.stop() }
            }
            .disabled(recorder.phase != .recording)
        }
        .padding(.leading, 9)
        .padding(.trailing, 4)
        .frame(height: 32)
        .background(VisualEffect(material: .hudWindow).clipShape(.capsule))
        .overlay(Capsule().strokeBorder(.separator.opacity(0.5), lineWidth: 0.5))
        .fixedSize()
        .onHover { h in withAnimation(.easeOut(duration: 0.14)) { hovering = h } }
        .animation(.snappy(duration: 0.2), value: recorder.liveMarks.count)
        .contextMenu {
            Button("Show Sessions Window", action: openSessions)
            Button(recorder.chromeConnected ? "Chrome Extension Connected" : "Set Up Chrome Extension…") {
                NSApp.sendAction(#selector(AppDelegate.showChromeSetup), to: nil, from: nil)
            }
            Divider()
            Button("Hide Controls", action: hide)
        }
    }

    private var clock: String {
        switch recorder.phase {
        case .starting: return "0:00"
        default: return Format.time(recorder.elapsed)
        }
    }

    private var lastMarkHelp: String {
        guard let mark = recorder.liveMarks.last else { return "No marks yet. ⌃⌥M marks a moment, ⌃⌥S grabs a region." }
        let n = recorder.liveMarks.count
        let app = mark.context.appName.map { " in \($0)" } ?? ""
        return "\(n == 1 ? "1 mark" : "\(n) marks"). Last: #\(mark.index) at \(Format.time(mark.offsetSeconds))\(app)"
    }
}

/// Icon-only control for the slim HUD: a 26×26 hit area with a hover fill.
private struct HUDButton: View {
    var symbol: String
    var help: String
    var tint: Color = .primary
    var bounce: Int = 0
    var action: () -> Void
    @State private var hovering = false
    @Environment(\.isEnabled) private var isEnabled

    var body: some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(tint.opacity(isEnabled ? 0.9 : 0.35))
                .symbolEffect(.bounce, value: bounce)
                .frame(width: 26, height: 26)
                .background(Circle().fill(.primary.opacity(hovering && isEnabled ? 0.1 : 0)))
                .contentShape(.circle)
        }
        .buttonStyle(PressScale())
        .onHover { h in withAnimation(.easeOut(duration: 0.14)) { hovering = h } }
        .help(help)
    }
}

private struct PressScale: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.9 : 1)
            .animation(.easeOut(duration: 0.1), value: configuration.isPressed)
    }
}

private struct TightLabel: LabelStyle {
    func makeBody(configuration: Configuration) -> some View {
        HStack(spacing: 3) { configuration.icon; configuration.title }
    }
}

/// Live microphone level as a short scrolling strip, newest on the right, so you can see the mic is
/// hearing you while you talk. Says "Mic off" for a silent recording and "No audio" when the mic should be
/// recording but nothing is arriving. Fixed size in every state, so nothing around it moves.
struct MicMeter: View {
    var recorder: RecorderController
    var bars = 18
    var height: CGFloat = 14
    private let pitch: CGFloat = 3   // bar 2 pt + gap 1 pt

    var body: some View {
        Group {
            if !recorder.recordingMic {
                status("Mic off", symbol: "mic.slash", color: .secondary)
                    .help("This recording has no narration. Turn on Mic before recording to capture it.")
            } else if recorder.micStalled {
                status("No audio", symbol: "mic.badge.xmark", color: .orange)
                    .help("The microphone isn't delivering audio. Check the input device and Microphone permission in System Settings.")
            } else {
                strip.help("Microphone level")
            }
        }
        .frame(width: CGFloat(bars) * pitch, height: height)
        .accessibilityElement()
        .accessibilityLabel(recorder.recordingMic ? (recorder.micStalled ? "Microphone: no audio" : "Microphone level") : "Microphone off")
    }

    private var strip: some View {
        let levels = recorder.micLevels.suffix(bars)
        return Canvas { context, size in
            let offset = bars - levels.count
            for (i, level) in levels.enumerated() {
                let h = max(2, CGFloat(level) * size.height)
                let rect = CGRect(x: CGFloat(offset + i) * pitch, y: (size.height - h) / 2, width: pitch - 1, height: h)
                // Green once there's real sound; room tone stays grey so a live but quiet mic still shows.
                let heard = level > 0.15
                context.fill(Path(roundedRect: rect, cornerRadius: 1),
                             with: .color(heard ? Color.green.opacity(0.9) : Color.secondary.opacity(0.6)))
            }
            // Empty slots before the first value: a quiet baseline, so the strip has its full width from the start.
            for i in 0..<offset {
                context.fill(Path(CGRect(x: CGFloat(i) * pitch, y: size.height / 2 - 0.5, width: pitch - 1, height: 1)),
                             with: .color(.secondary.opacity(0.35)))
            }
        }
    }

    private func status(_ text: String, symbol: String, color: Color) -> some View {
        HStack(spacing: 3) {
            Image(systemName: symbol)
            Text(text).lineLimit(1)
        }
        .font(.system(size: 10.5, weight: .medium))
        .foregroundStyle(color)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// MARK: Shared pieces (HUD + Sessions window)

/// Mark / Region / Stop. The same buttons, in the same order, everywhere you can record.
struct RecordingActions: View {
    var recorder: RecorderController
    var size: ControlSize = .regular
    var includeStop = true

    var body: some View {
        HStack(spacing: 8) {
            Button { recorder.mark() } label: {
                Label("Mark", systemImage: "flag.fill").frame(maxWidth: .infinity)
            }
            .help("Mark this moment (⌃⌥M)")
            Button { recorder.screenshot() } label: {
                Label("Region", systemImage: "viewfinder").frame(maxWidth: .infinity)
            }
            .help("Screenshot a region (⌃⌥S)")
            if includeStop {
                Button { recorder.stop() } label: {
                    Label("Stop", systemImage: "stop.fill").frame(maxWidth: .infinity)
                }
                .tint(.red)
                .help("Stop recording (⌃⌥R)")
            }
        }
        .controlSize(size)
        .buttonStyle(.bordered)
        .disabled(recorder.phase != .recording)
    }
}

/// Red dot with a soft pulsing halo while recording. The pulse is a phase animator so it stays on the
/// halo: a `repeatForever` started with `withAnimation` would also animate unrelated layout changes forever.
struct RecordingDot: View {
    var active: Bool
    var size: CGFloat = 22

    var body: some View {
        ZStack {
            Circle().fill(Color.red.opacity(0.22))
                .phaseAnimator([false, true]) { halo, expanded in
                    halo.scaleEffect(expanded && active ? 1 : 0.6)
                        .opacity(expanded && active ? 0.25 : 1)
                } animation: { _ in .easeInOut(duration: 0.9) }
            Circle().fill(active ? Color.red : Color.orange).frame(width: size * 0.45, height: size * 0.45)
        }
        .frame(width: size, height: size)
        .accessibilityHidden(true)
    }
}

/// Whether the Chrome extension is connected. Clicking it opens the setup sheet.
struct ChromeBadge: View {
    var connected: Bool

    var body: some View {
        Button {
            NSApp.sendAction(#selector(AppDelegate.showChromeSetup), to: nil, from: nil)
        } label: {
            label
        }
        .buttonStyle(.plain)
        .help(connected ? "Browser extension connected: marks in Chrome include page context"
                        : "Browser extension not connected: marks get app and window context only. Click to set it up.")
    }

    private var label: some View {
        HStack(spacing: 5) {
            Circle().fill(connected ? Color.green : Color.secondary.opacity(0.5)).frame(width: 6, height: 6)
            Text(connected ? "Chrome" : "No Chrome")
        }
        .font(.system(size: 11, weight: .medium))
        .foregroundStyle(connected ? .primary : .secondary)
        .padding(.horizontal, 8)
        .padding(.vertical, 3)
        .background(.quaternary.opacity(0.6), in: .capsule)
        .contentShape(.capsule)
    }
}

/// Small key-combination chip, e.g. ⌃⌥R.
struct KeyHint: View {
    var keys: String
    init(_ keys: String) { self.keys = keys }

    var body: some View {
        Text(keys)
            .font(.system(size: 10.5, weight: .medium).monospaced())
            .padding(.horizontal, 5)
            .padding(.vertical, 1.5)
            .background(.quaternary.opacity(0.7), in: .rect(cornerRadius: 4))
            .foregroundStyle(.secondary)
    }
}

struct VisualEffect: NSViewRepresentable {
    var material: NSVisualEffectView.Material

    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = material
        view.blendingMode = .behindWindow
        view.state = .active
        return view
    }

    func updateNSView(_ view: NSVisualEffectView, context: Context) { view.material = material }
}
