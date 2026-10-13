import AppKit
import Foundation

/// Continuous context track: logs a row to activity.jsonl whenever the frontmost app, its window title,
/// or the active Chrome tab changes. Gives the viewer an "what was on screen" lane for the whole recording.
final class ActivityLog {
    struct Entry: Codable {
        var offsetSeconds: Double
        var context: MarkContext
    }

    private let url: URL
    private let offset: () -> Double?
    private var timer: Timer?
    private var observer: NSObjectProtocol?
    private var lastKey = ""

    init(url: URL, offset: @escaping () -> Double?) {
        self.url = url
        self.offset = offset
        FileManager.default.createFile(atPath: url.path, contents: nil)
    }

    func start() {
        observer = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didActivateApplicationNotification, object: nil, queue: .main
        ) { [weak self] _ in
            // Give the new app a beat to bring its window forward.
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { self?.sample() }
        }
        timer = Timer.scheduledTimer(withTimeInterval: 2, repeats: true) { [weak self] _ in self?.sample() }
        sample()
    }

    func stop() {
        timer?.invalidate()
        timer = nil
        if let observer { NSWorkspace.shared.notificationCenter.removeObserver(observer) }
        observer = nil
    }

    private func sample() {
        guard let offset = offset() else { return }
        let ctx = ContextProbe.capture(includeMouse: false)
        let key = [ctx.bundleID, ctx.windowTitle, ctx.browserURL].map { $0 ?? "" }.joined(separator: "|")
        guard key != lastKey else { return }
        lastKey = key
        let enc = JSONEncoder()
        enc.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
        guard var line = try? enc.encode(Entry(offsetSeconds: offset, context: ctx)) else { return }
        line.append(0x0A)
        if let handle = try? FileHandle(forWritingTo: url) {
            handle.seekToEndOfFile()
            handle.write(line)
            try? handle.close()
        }
    }
}
