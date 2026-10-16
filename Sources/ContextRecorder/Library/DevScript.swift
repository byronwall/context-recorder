import AppKit

/// `--script "<step>; <step>; …"` (dev library mode only): real NSEvents sent through the Sessions
/// window's `sendEvent`, so hit-testing, the key monitor and first-responder routing all run as they do
/// for a person. Nothing is posted system-wide, so other apps never see these events.
///
/// Points are window-content points from the top-left. Steps:
///   wait <seconds>
///   click <x> <y> [count]          left click; count 2 = double-click
///   drag <x1> <y1> <x2> <y2> [middle] [cmd|shift|opt…]
///   move <x> <y>                   pointer moves there (hover)
///   wheel <x> <y> <dy>             mouse wheel (line units)
///   swipe <x> <y> <dx> <dy>        trackpad two-finger scroll (precise deltas)
///   key <name|char> [cmd|shift|opt…]   names: esc return space left right up down delete tab
///   keyup <name|char>
///   appkey <name|char> [mods]      a key through NSApp, so the window's key monitor (C, space, ←/→, J/K) sees it
///   type <text…>
///   flag <name>                    writes tmp/ui-test/flags/<name> (a screenshot cue) plus <name>.png (the
///                                  window drawn in-process) and waits up to 5 s
///                                  for the harness to delete it
///
/// `CR_SCRIPT_LOG=1` prints each step to stderr as it starts.
@MainActor
enum DevScript {
    static func run(_ script: String, in window: NSWindow, flags: URL) async {
        for raw in script.split(separator: ";") {
            let parts = raw.split(separator: " ").map(String.init)
            guard let cmd = parts.first else { continue }
            if ProcessInfo.processInfo.environment["CR_SCRIPT_LOG"] != nil { fputs("script: \(raw)\n", stderr) }
            let a = Array(parts.dropFirst())
            func n(_ i: Int) -> CGFloat { CGFloat(Double(a[i]) ?? 0) }
            switch cmd {
            case "wait": try? await Task.sleep(for: .seconds(Double(a.first ?? "0.3") ?? 0.3))
            case "click":
                let count = a.count > 2 ? Int(a[2]) ?? 1 : 1
                for i in 1...count {
                    mouse(.leftMouseDown, at: CGPoint(x: n(0), y: n(1)), in: window, clicks: i)
                    mouse(.leftMouseUp, at: CGPoint(x: n(0), y: n(1)), in: window, clicks: i)
                }
            case "drag":
                let middle = a.contains("middle")
                let mods = modifiers(a.dropFirst(4))
                let from = CGPoint(x: n(0), y: n(1)), to = CGPoint(x: n(2), y: n(3))
                mouse(middle ? .otherMouseDown : .leftMouseDown, at: from, in: window, mods: mods)
                for i in 1...16 {
                    let t = CGFloat(i) / 16
                    mouse(middle ? .otherMouseDragged : .leftMouseDragged,
                          at: CGPoint(x: from.x + (to.x - from.x) * t, y: from.y + (to.y - from.y) * t), in: window, mods: mods)
                    try? await Task.sleep(for: .milliseconds(8))
                }
                mouse(middle ? .otherMouseUp : .leftMouseUp, at: to, in: window, mods: mods)
            case "move": mouse(.mouseMoved, at: CGPoint(x: n(0), y: n(1)), in: window)
            case "wheel": scroll(at: CGPoint(x: n(0), y: n(1)), dx: 0, dy: n(2), precise: false, in: window)
            case "swipe": scroll(at: CGPoint(x: n(0), y: n(1)), dx: n(2), dy: n(3), precise: true, in: window)
            case "key", "keyup":
                guard let name = a.first else { continue }
                key(name, up: cmd == "keyup", mods: modifiers(a.dropFirst()), in: window)
            case "appkey":
                guard let name = a.first else { continue }
                key(name, up: false, mods: modifiers(a.dropFirst()), in: window, throughApp: true)
            case "type":
                // Into the focused text view the way the input system delivers committed text. Synthetic
                // key-downs into an NSTextView go through the input method and stall this task.
                let text = a.joined(separator: " ")
                if let view = window.firstResponder as? NSTextView {
                    view.insertText(text, replacementRange: view.selectedRange())
                } else {
                    for ch in text { key(String(ch), up: false, mods: [], in: window); key(String(ch), up: true, mods: [], in: window) }
                }
            case "flag":
                try? FileManager.default.createDirectory(at: flags, withIntermediateDirectories: true)
                let file = flags.appendingPathComponent(a.first ?? "flag")
                // The window drawn in-process too, for when the screen is locked and screencapture can't
                // read windows. Layer effects such as glass come out flatter than on screen.
                snapshot(window, to: file.appendingPathExtension("png"))
                try? Data().write(to: file)
                // The harness deletes the flag once its screenshot is taken; hold still until then.
                for _ in 0..<100 where FileManager.default.fileExists(atPath: file.path) {
                    try? await Task.sleep(for: .milliseconds(50))
                }
            default: fputs("DevScript: unknown step \(cmd)\n", stderr)
            }
            // Let SwiftUI and the canvas settle between steps.
            try? await Task.sleep(for: .milliseconds(60))
        }
    }

    private static func snapshot(_ window: NSWindow, to url: URL) {
        guard let view = window.contentView?.superview ?? window.contentView,
              let rep = view.bitmapImageRepForCachingDisplay(in: view.bounds) else { return }
        view.cacheDisplay(in: view.bounds, to: rep)
        try? rep.representation(using: .png, properties: [:])?.write(to: url)
    }

    private static func windowPoint(_ p: CGPoint, _ window: NSWindow) -> CGPoint {
        CGPoint(x: p.x, y: (window.contentView?.bounds.height ?? 0) - p.y)
    }

    private static func modifiers<S: Sequence>(_ words: S) -> NSEvent.ModifierFlags where S.Element == String {
        var f: NSEvent.ModifierFlags = []
        for w in words {
            if w.contains("cmd") { f.insert(.command) }
            if w.contains("shift") { f.insert(.shift) }
            if w.contains("opt") { f.insert(.option) }
        }
        return f
    }

    private static func mouse(_ type: NSEvent.EventType, at p: CGPoint, in window: NSWindow, clicks: Int = 1, mods: NSEvent.ModifierFlags = []) {
        guard let e = NSEvent.mouseEvent(with: type, location: windowPoint(p, window), modifierFlags: mods,
                                         timestamp: ProcessInfo.processInfo.systemUptime, windowNumber: window.windowNumber,
                                         context: nil, eventNumber: 0, clickCount: clicks, pressure: type == .leftMouseUp ? 0 : 1)
        else { return }
        // Middle-button events need the button number, which mouseEvent(with:) can't set.
        if type == .otherMouseDown || type == .otherMouseDragged || type == .otherMouseUp, let cg = e.cgEvent {
            cg.setIntegerValueField(.mouseEventButtonNumber, value: 2)
            if let other = NSEvent(cgEvent: cg) { window.sendEvent(other); return }
        }
        window.sendEvent(e)
    }

    private static func scroll(at p: CGPoint, dx: CGFloat, dy: CGFloat, precise: Bool, in window: NSWindow) {
        let screen = window.convertPoint(toScreen: windowPoint(p, window))
        let flippedY = (NSScreen.screens.first?.frame.height ?? 0) - screen.y
        guard let cg = CGEvent(scrollWheelEvent2Source: nil, units: precise ? .pixel : .line, wheelCount: 2,
                               wheel1: Int32(dy), wheel2: Int32(dx), wheel3: 0) else { return }
        cg.location = CGPoint(x: screen.x, y: flippedY)
        if precise { cg.setIntegerValueField(.scrollWheelEventIsContinuous, value: 1) }
        if let e = NSEvent(cgEvent: cg) { window.sendEvent(e) }
    }

    private static let codes: [String: (UInt16, String)] = [
        "esc": (53, "\u{1b}"), "return": (36, "\r"), "space": (49, " "), "tab": (48, "\t"), "delete": (51, "\u{7f}"),
        "left": (123, "\u{F702}"), "right": (124, "\u{F703}"), "up": (126, "\u{F700}"), "down": (125, "\u{F701}"),
    ]

    private static func key(_ name: String, up: Bool, mods: NSEvent.ModifierFlags, in window: NSWindow, throughApp: Bool = false) {
        let (code, chars) = codes[name] ?? (keyCode(name), name)
        guard let e = NSEvent.keyEvent(with: up ? .keyUp : .keyDown, location: .zero, modifierFlags: mods,
                                       timestamp: ProcessInfo.processInfo.systemUptime, windowNumber: window.windowNumber,
                                       context: nil, characters: chars, charactersIgnoringModifiers: chars, isARepeat: false, keyCode: code)
        else { return }
        // Command keys go through performKeyEquivalent first, as NSApplication does. Straight to the window
        // rather than NSApp, so it works while another app is frontmost.
        if throughApp { NSApp.sendEvent(e); return }
        if !up, mods.contains(.command), window.performKeyEquivalent(with: e) { return }
        window.sendEvent(e)
    }

    /// ANSI key codes for letters and digits, so the app's keyCode switches see real values.
    private static func keyCode(_ ch: String) -> UInt16 {
        let map: [Character: UInt16] = [
            "a": 0, "s": 1, "d": 2, "f": 3, "h": 4, "g": 5, "z": 6, "x": 7, "c": 8, "v": 9, "b": 11, "q": 12, "w": 13, "e": 14,
            "r": 15, "y": 16, "t": 17, "1": 18, "2": 19, "3": 20, "4": 21, "6": 22, "5": 23, "=": 24, "9": 25, "7": 26, "-": 27,
            "8": 28, "0": 29, "o": 31, "u": 32, "i": 34, "p": 35, "l": 37, "j": 38, "k": 40, "n": 45, "m": 46, "+": 24,
        ]
        return ch.lowercased().first.flatMap { map[$0] } ?? 0
    }
}
