import AppKit

@main
struct RegionSelectorCheck {
    enum Gesture: String, CaseIterable {
        case escape, rightClick, fullScreen, region
    }

    static func require(_ condition: @autoclosure () -> Bool, _ message: String) {
        guard condition() else {
            fputs("FAIL: \(message)\n", stderr)
            exit(1)
        }
    }

    static func main() {
        let app = NSApplication.shared
        app.setActivationPolicy(.accessory)
        app.finishLaunching()
        RunLoop.main.run(until: Date().addingTimeInterval(0.05))
        guard let previousApp = NSWorkspace.shared.frontmostApplication, NSScreen.main != nil else {
            fputs("A logged-in macOS desktop is required.\n", stderr)
            exit(1)
        }
        require(!app.isActive, "test executable activated during launch")
        require(previousApp.processIdentifier != ProcessInfo.processInfo.processIdentifier,
                "check must start in the background")
        var activations = 0
        let notifications = NSWorkspace.shared.notificationCenter
        let observer = notifications.addObserver(forName: NSWorkspace.didActivateApplicationNotification,
                             object: nil, queue: .main) { _ in
            activations += 1
        }
        defer { notifications.removeObserver(observer) }
        let selector = RegionSelector()

        for gesture in Gesture.allCases {
            var completed = false
            var selection: NSRect?
            selector.begin {
                selection = $0
                completed = true
            }
            RunLoop.main.run(until: Date().addingTimeInterval(0.05))
            guard let panel = app.windows.first(where: { $0.isVisible }) as? NSPanel else {
                require(false, "\(gesture): selector did not show a panel")
                return
            }
            require(panel.styleMask.contains(.nonactivatingPanel), "\(gesture): panel can activate the app")
            require(panel.isKeyWindow, "\(gesture): panel cannot receive Escape before a click")
            require(!panel.canBecomeMain, "\(gesture): panel can become the main window")
            require(NSWorkspace.shared.frontmostApplication?.processIdentifier == previousApp.processIdentifier,
                    "\(gesture): showing the selector changed the foreground app")
                require(activations == 0, "\(gesture): showing the selector switched foreground apps")

            func mouse(_ type: NSEvent.EventType, at point: NSPoint) {
                let event = NSEvent.mouseEvent(with: type, location: point, modifierFlags: [],
                                               timestamp: ProcessInfo.processInfo.systemUptime,
                                               windowNumber: panel.windowNumber, context: nil,
                                               eventNumber: 0, clickCount: 1, pressure: 0)!
                panel.sendEvent(event)
            }

            let start = NSPoint(x: 20, y: 30)
            var expected: NSRect?
            switch gesture {
            case .escape:
                let event = NSEvent.keyEvent(with: .keyDown, location: .zero, modifierFlags: [],
                                             timestamp: ProcessInfo.processInfo.systemUptime,
                                             windowNumber: panel.windowNumber, context: nil,
                                             characters: "\u{1b}", charactersIgnoringModifiers: "\u{1b}",
                                             isARepeat: false, keyCode: 53)!
                panel.sendEvent(event)
            case .rightClick:
                mouse(.rightMouseDown, at: start)
            case .fullScreen:
                expected = panel.frame
                mouse(.leftMouseDown, at: start)
                mouse(.leftMouseUp, at: start)
            case .region:
                let end = NSPoint(x: 100, y: 90)
                expected = panel.convertToScreen(NSRect(x: 20, y: 30, width: 80, height: 60))
                mouse(.leftMouseDown, at: start)
                mouse(.leftMouseDragged, at: end)
                mouse(.leftMouseUp, at: end)
            }

            require(!panel.isVisible, "\(gesture): selector remained visible after dismissal")
            RunLoop.main.run(until: Date().addingTimeInterval(0.15))
            require(completed, "\(gesture): completion did not run")
            require(selection == expected, "\(gesture): incorrect selection \(String(describing: selection))")
            require(NSWorkspace.shared.frontmostApplication?.processIdentifier == previousApp.processIdentifier,
                    "\(gesture): dismissal changed the foreground app")
                require(activations == 0, "\(gesture): selector switched foreground apps")
            print("PASS: \(gesture.rawValue) preserves foreground app and selection")
        }
    }
}