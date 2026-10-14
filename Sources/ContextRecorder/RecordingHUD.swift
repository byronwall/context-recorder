import AppKit
import SwiftUI

/// Floating recording controls, shown only while recording. Our own windows are left out of the
/// capture, so it can stay on screen. Closing it hides it until the next recording (or Recording →
/// Show Recording Controls).
@MainActor
final class RecordingHUDController {
    private let panel: NSPanel

    init(recorder: RecorderController, openSessions: @escaping () -> Void) {
        panel = NSPanel(contentRect: NSRect(x: 0, y: 0, width: 300, height: 170),
                        styleMask: [.titled, .closable, .fullSizeContentView, .nonactivatingPanel, .utilityWindow],
                        backing: .buffered, defer: false)
        panel.title = "Recording"
        panel.titleVisibility = .hidden
        panel.titlebarAppearsTransparent = true
        panel.isMovableByWindowBackground = true
        panel.isFloatingPanel = true
        panel.level = .floating
        panel.hidesOnDeactivate = false
        panel.isReleasedWhenClosed = false
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.standardWindowButton(.miniaturizeButton)?.isHidden = true
        panel.standardWindowButton(.zoomButton)?.isHidden = true
        let host = NSHostingController(rootView: RecordingHUD(recorder: recorder, openSessions: openSessions))
        host.sizingOptions = .preferredContentSize
        panel.contentViewController = host
        panel.setFrameAutosaveName("RecordingHUD")

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
            panel.setFrameTopLeftPoint(NSPoint(x: f.maxX - panel.frame.width - 20, y: f.maxY - 20))
        }
        panel.orderFrontRegardless()
    }
}

struct RecordingHUD: View {
    var recorder: RecorderController
    var openSessions: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .center, spacing: 10) {
                RecordingDot(active: recorder.phase == .recording)
                VStack(alignment: .leading, spacing: 0) {
                    Text(Format.time(recorder.elapsed))
                        .font(.system(size: 24, weight: .semibold).monospacedDigit())
                        .contentTransition(.numericText())
                    Text(caption)
                        .font(.system(size: 11.5))
                        .foregroundStyle(.secondary)
                }
                Spacer(minLength: 0)
                ChromeBadge(connected: recorder.chromeConnected)
            }

            RecordingActions(recorder: recorder, size: .regular)

            Divider()

            HStack(spacing: 8) {
                LastMarkLine(mark: recorder.liveMarks.last)
                Spacer(minLength: 0)
                Button(action: openSessions) {
                    Image(systemName: "rectangle.stack")
                        .font(.system(size: 13))
                        .frame(width: 24, height: 22)
                        .contentShape(.rect)
                }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
                .help("Show the Sessions window")
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 30)
        .padding(.bottom, 14)
        .frame(width: 320)
        .background(VisualEffect(material: .hudWindow).ignoresSafeArea())
    }

    private var caption: String {
        switch recorder.phase {
        case .starting: return "Starting…"
        case .stopping: return "Saving…"
        default:
            let n = recorder.liveMarks.count
            let marks = n == 0 ? "No marks yet" : (n == 1 ? "1 mark" : "\(n) marks")
            return marks + (recorder.recordMicrophone ? " · Mic on" : " · Mic off")
        }
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

/// Whether the Chrome extension is connected.
struct ChromeBadge: View {
    var connected: Bool

    var body: some View {
        HStack(spacing: 5) {
            Circle().fill(connected ? Color.green : Color.secondary.opacity(0.5)).frame(width: 6, height: 6)
            Text(connected ? "Chrome" : "No Chrome")
        }
        .font(.system(size: 11, weight: .medium))
        .foregroundStyle(connected ? .primary : .secondary)
        .padding(.horizontal, 8)
        .padding(.vertical, 3)
        .background(.quaternary.opacity(0.6), in: .capsule)
        .help(connected ? "Browser extension connected: marks in Chrome include page context"
                        : "Browser extension not connected: marks get app and window context only")
    }
}

/// "⚑ #3 · 1:17 · Google Chrome", or a hint before the first mark.
struct LastMarkLine: View {
    var mark: Mark?

    var body: some View {
        if let mark {
            HStack(spacing: 6) {
                MarkDisc(index: mark.index, isShot: mark.kind == "screenshot", size: 16)
                Text(Format.time(mark.offsetSeconds)).monospacedDigit().foregroundStyle(.secondary)
                AppIcon(bundleID: mark.context.bundleID, size: 14)
                Text(mark.context.appName ?? "")
                    .lineLimit(1)
            }
            .font(.system(size: 11.5))
            .transition(.opacity)
        } else {
            Text("⌃⌥M marks a moment · ⌃⌥S grabs a region")
                .font(.system(size: 11))
                .foregroundStyle(.tertiary)
        }
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
