import AppKit
import CoreGraphics
import Foundation

/// Snapshot of "what was I looking at" when a mark is made.
struct MarkContext: Codable {
    var appName: String?
    var bundleID: String?
    var pid: Int32?
    var windowTitle: String?
    var windowBounds: [String: Double]?
    var mouse: [String: Double]?
    var browserURL: String?
    var browserTitle: String?
}

enum ContextProbe {
    static let chromeBundleIDs: Set<String> = [
        "com.google.Chrome", "com.google.Chrome.canary", "com.google.Chrome.beta", "com.google.Chrome.dev",
    ]

    static func capture(includeMouse: Bool = true) -> MarkContext {
        var ctx = MarkContext()
        let app = NSWorkspace.shared.frontmostApplication
        ctx.appName = app?.localizedName
        ctx.bundleID = app?.bundleIdentifier
        ctx.pid = app?.processIdentifier

        if includeMouse {
            let mouse = NSEvent.mouseLocation
            ctx.mouse = ["x": mouse.x, "y": mouse.y]
        }

        if let pid = app?.processIdentifier {
            // Window titles from CGWindowList are available because we hold Screen Recording permission.
            let windows = CGWindowListCopyWindowInfo([.optionOnScreenOnly, .excludeDesktopElements], kCGNullWindowID)
                as? [[String: Any]] ?? []
            if let front = windows.first(where: {
                ($0[kCGWindowOwnerPID as String] as? Int32) == pid && ($0[kCGWindowLayer as String] as? Int) == 0
            }) {
                ctx.windowTitle = front[kCGWindowName as String] as? String
                if let b = front[kCGWindowBounds as String] as? [String: Double] { ctx.windowBounds = b }
            }
        }

        if let bid = ctx.bundleID, chromeBundleIDs.contains(bid) {
            let (url, title) = chromeActiveTab(bundleID: bid)
            ctx.browserURL = url
            ctx.browserTitle = title
        }
        return ctx
    }

    /// Uses AppleScript (Automation permission, prompted once) to read Chrome's active tab.
    private static func chromeActiveTab(bundleID: String) -> (String?, String?) {
        let source = """
        tell application id "\(bundleID)"
            if (count of windows) = 0 then return ""
            set t to active tab of front window
            return (URL of t) & linefeed & (title of t)
        end tell
        """
        var error: NSDictionary?
        guard let result = NSAppleScript(source: source)?.executeAndReturnError(&error).stringValue else {
            if let error { NSLog("ContextRecorder: Chrome AppleScript failed: \(error)") }
            return (nil, nil)
        }
        let parts = result.components(separatedBy: "\n")
        return (parts.first, parts.count > 1 ? parts.dropFirst().joined(separator: "\n") : nil)
    }
}
