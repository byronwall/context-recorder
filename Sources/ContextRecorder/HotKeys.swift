import Carbon
import Foundation

/// Global hotkeys via Carbon's RegisterEventHotKey. No Accessibility permission required.
final class HotKeys {
    static let shared = HotKeys()

    private var handlers: [UInt32: () -> Void] = [:]
    private var refs: [EventHotKeyRef?] = []
    private var nextID: UInt32 = 1
    private var installed = false

    /// keyCode is a virtual key code (kVK_ANSI_M etc.), modifiers are Carbon masks (controlKey | optionKey ...).
    func register(keyCode: Int, modifiers: Int, handler: @escaping () -> Void) {
        installHandlerIfNeeded()
        let id = nextID
        nextID += 1
        handlers[id] = handler
        var ref: EventHotKeyRef?
        let hotKeyID = EventHotKeyID(signature: OSType(0x4358_5452), id: id) // 'CXTR'
        let status = RegisterEventHotKey(UInt32(keyCode), UInt32(modifiers), hotKeyID, GetApplicationEventTarget(), 0, &ref)
        if status != noErr {
            NSLog("ContextRecorder: failed to register hotkey \(keyCode) (status \(status))")
        }
        refs.append(ref)
    }

    fileprivate func fire(_ id: UInt32) {
        handlers[id]?()
    }

    private func installHandlerIfNeeded() {
        guard !installed else { return }
        installed = true
        var spec = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        InstallEventHandler(GetApplicationEventTarget(), { _, event, _ -> OSStatus in
            var hotKeyID = EventHotKeyID()
            GetEventParameter(event, EventParamName(kEventParamDirectObject), EventParamType(typeEventHotKeyID),
                              nil, MemoryLayout<EventHotKeyID>.size, nil, &hotKeyID)
            DispatchQueue.main.async { HotKeys.shared.fire(hotKeyID.id) }
            return noErr
        }, 1, &spec, nil, nil)
    }
}
