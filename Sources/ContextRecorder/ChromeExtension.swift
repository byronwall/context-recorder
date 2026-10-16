import AppKit

/// The bundled Chrome extension and the steps that install it.
///
/// Chrome won't let another app install an extension that isn't in the Web Store, so the user loads it
/// once with Load unpacked. The app keeps a copy at a fixed path for that: each launch refreshes the files,
/// and an older extension that connects is told to reload itself, so updates need no clicks.
enum ChromeExtension {
    /// `~/Library/Application Support/Context Recorder/Chrome Extension`: the folder Chrome loads.
    static var folder: URL {
        URL.applicationSupportDirectory.appending(path: "Context Recorder/Chrome Extension", directoryHint: .isDirectory)
    }

    /// The extension shipped with this build: in the app bundle, or `extension/` in the repo for dev runs.
    private static var source: URL? {
        if let bundled = Bundle.main.url(forResource: "ChromeExtension", withExtension: nil) { return bundled }
        let repo = URL(fileURLWithPath: FileManager.default.currentDirectoryPath).appending(path: "extension")
        return FileManager.default.fileExists(atPath: repo.appending(path: "manifest.json").path) ? repo : nil
    }

    static let bundledVersion: String? = source.flatMap(version(in:))

    private static func version(in folder: URL) -> String? {
        guard let data = try? Data(contentsOf: folder.appending(path: "manifest.json")),
              let manifest = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return nil }
        return manifest["version"] as? String
    }

    /// Whether `version` is older than the extension this build ships.
    static func isOlder(_ version: String) -> Bool {
        guard let bundledVersion else { return false }
        return version.compare(bundledVersion, options: .numeric) == .orderedAscending
    }

    /// Copies this build's extension into `folder`. A few small files, so it's done on every launch.
    @discardableResult
    static func install() -> Bool {
        guard let source else { return false }
        let fm = FileManager.default
        do {
            try fm.createDirectory(at: folder, withIntermediateDirectories: true)
            // Replace the files, not the folder: Chrome remembers the extension by this path.
            for item in try fm.contentsOfDirectory(at: folder, includingPropertiesForKeys: nil) {
                try fm.removeItem(at: item)
            }
            for item in try fm.contentsOfDirectory(at: source, includingPropertiesForKeys: nil) {
                try fm.copyItem(at: item, to: folder.appending(path: item.lastPathComponent))
            }
            return true
        } catch {
            NSLog("ContextRecorder: could not install the Chrome extension files: \(error)")
            return false
        }
    }

    /// The Chrome to use: the one that's running, otherwise the first one installed.
    static var chromeBundleID: String? {
        let ids = ["com.google.Chrome", "com.google.Chrome.beta", "com.google.Chrome.dev", "com.google.Chrome.canary"]
        let running = Set(NSWorkspace.shared.runningApplications.compactMap(\.bundleIdentifier))
        return ids.first(where: running.contains)
            ?? ids.first { NSWorkspace.shared.urlForApplication(withBundleIdentifier: $0) != nil }
    }

    /// Opens chrome://extensions in a new tab. Web pages and `open` can't open chrome:// URLs, but Chrome's
    /// AppleScript can (the same Automation permission the app uses to read the active tab).
    @discardableResult
    static func openExtensionsPage() -> Bool {
        guard let id = chromeBundleID else { return false }
        let source = """
        tell application id "\(id)"
            activate
            if (count of windows) = 0 then make new window
            tell front window to make new tab with properties {URL:"chrome://extensions"}
        end tell
        """
        var error: NSDictionary?
        NSAppleScript(source: source)?.executeAndReturnError(&error)
        if let error {
            NSLog("ContextRecorder: could not open chrome://extensions: \(error)")
            // At least bring Chrome forward; the sheet shows the address to type.
            if let app = NSWorkspace.shared.urlForApplication(withBundleIdentifier: id) {
                NSWorkspace.shared.openApplication(at: app, configuration: .init())
            }
            return false
        }
        return true
    }

    static func copyFolderPath() {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(folder.path, forType: .string)
    }
}
