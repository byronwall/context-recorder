import SwiftUI

/// Walks through loading the bundled extension in Chrome: one button opens the page with the folder's path
/// on the clipboard, two clicks and a paste there finish it, and the status turns green when it connects.
struct ChromeExtensionSheet: View {
    @Environment(RecorderController.self) private var recorder
    @Environment(\.dismiss) private var dismiss
    @State private var opened = false
    @State private var copied = false
    private let chrome = ChromeExtension.chromeBundleID

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            VStack(alignment: .leading, spacing: 6) {
                Text("Set Up the Chrome Extension").font(.title2.weight(.semibold))
                Text("Marks made in Chrome then include the element under the pointer, console errors, failed requests and a saved copy of the page.")
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            status

            Button {
                ChromeExtension.install()
                ChromeExtension.copyFolderPath()
                opened = ChromeExtension.openExtensionsPage()
                copied = true
            } label: {
                Label("Copy Folder Path and Open Chrome Extensions", systemImage: "puzzlepiece.extension")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .disabled(chrome == nil)

            VStack(alignment: .leading, spacing: 10) {
                Text("Then, on Chrome's extensions page:").font(.headline)
                step(1, "Turn on **Developer mode** at the top right.")
                step(2, "Click **Load unpacked**, press **⌘⇧G**, paste with **⌘V** and press **Return**, then click **Select**.")
                if copied && !opened {
                    Text("Chrome didn't open the page. Type chrome://extensions in its address bar.")
                        .font(.callout)
                        .foregroundStyle(.orange)
                }
            }

            folderRow

            Text("Chrome asks for this once. When the app updates, the extension reloads itself with the new version.")
                .font(.callout)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            HStack {
                Spacer()
                Button("Done") { dismiss() }.keyboardShortcut(.defaultAction)
            }
        }
        .padding(24)
        .frame(width: 480)
        .onAppear { ChromeExtension.install() }
    }

    @ViewBuilder private var status: some View {
        HStack(spacing: 8) {
            if recorder.chromeConnected {
                Image(systemName: "checkmark.circle.fill").foregroundStyle(.green)
                Text("Connected" + (recorder.chromeExtensionVersion.map { " · version \($0)" } ?? ""))
            } else if chrome == nil {
                Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(.orange)
                Text("Google Chrome isn't installed.")
            } else {
                ProgressView().controlSize(.small)
                Text("Waiting for the extension to connect…").foregroundStyle(.secondary)
            }
            Spacer(minLength: 0)
        }
        .font(.callout.weight(.medium))
        .padding(.horizontal, 12)
        .padding(.vertical, 9)
        .background(.quaternary.opacity(0.5), in: .rect(cornerRadius: 8))
        .animation(.snappy, value: recorder.chromeConnected)
    }

    /// The folder to load, as text to copy and as an icon to drag onto the extensions page.
    private var folderRow: some View {
        HStack(spacing: 8) {
            Image(nsImage: NSWorkspace.shared.icon(forFile: ChromeExtension.folder.path))
                .resizable()
                .frame(width: 22, height: 22)
                .draggable(ChromeExtension.folder)
                .help("Drag onto Chrome's extensions page instead of using Load unpacked")
            Text((ChromeExtension.folder.path as NSString).abbreviatingWithTildeInPath)
                .font(.callout.monospaced())
                .lineLimit(1)
                .truncationMode(.middle)
                .textSelection(.enabled)
            Spacer(minLength: 0)
            Button("Copy") {
                ChromeExtension.copyFolderPath()
                copied = true
            }
            .controlSize(.small)
            Button("Show in Finder") {
                ChromeExtension.install()
                NSWorkspace.shared.activateFileViewerSelecting([ChromeExtension.folder])
            }
            .controlSize(.small)
        }
        .padding(8)
        .background(.quaternary.opacity(0.3), in: .rect(cornerRadius: 8))
    }

    private func step(_ n: Int, _ text: LocalizedStringKey) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 10) {
            Text("\(n)")
                .font(.callout.weight(.semibold).monospacedDigit())
                .frame(width: 20, height: 20)
                .background(.quaternary, in: .circle)
            Text(text).fixedSize(horizontal: false, vertical: true)
        }
    }
}
