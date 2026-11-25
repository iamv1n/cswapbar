import AppKit
import Carbon.HIToolbox
import CSwapBarCore

/// One system-wide hot key, registered with Carbon's `RegisterEventHotKey`.
///
/// Unlike a global `NSEvent` monitor, this needs no Accessibility permission
/// and consumes the key press, so the frontmost app doesn't also receive it.
@MainActor
final class GlobalHotKey {
    enum Status: Equatable {
        case off
        case active
        /// Another app (or macOS) already uses this combination.
        case unavailable
    }

    private(set) var status: Status = .off
    private var ref: EventHotKeyRef?
    private var handler: EventHandlerRef?
    private let action: () -> Void

    private static let signature: OSType = 0x4353_5742   // "CSWB"
    fileprivate static var instances: [UInt32: GlobalHotKey] = [:]
    private static var nextID: UInt32 = 1
    private let id: UInt32

    init(action: @escaping () -> Void) {
        self.action = action
        id = Self.nextID
        Self.nextID += 1
        Self.instances[id] = self
    }

    /// Registers `shortcut`, replacing any previous one. `nil` turns it off.
    @discardableResult
    func set(_ shortcut: KeyShortcut?) -> Status {
        unregister()
        guard let shortcut, shortcut.isValidGlobalShortcut else {
            status = .off
            return status
        }
        installHandlerIfNeeded()
        let hotKeyID = EventHotKeyID(signature: Self.signature, id: id)
        let result = RegisterEventHotKey(shortcut.keyCode, Self.carbonModifiers(shortcut.modifiers),
                                         hotKeyID, GetApplicationEventTarget(), 0, &ref)
        status = result == noErr ? .active : .unavailable
        if result != noErr { ref = nil }
        return status
    }

    func unregister() {
        if let ref { UnregisterEventHotKey(ref) }
        ref = nil
    }

    fileprivate func fire() { action() }

    private func installHandlerIfNeeded() {
        guard handler == nil else { return }
        var spec = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        InstallEventHandler(GetApplicationEventTarget(), hotKeyEventHandler, 1, &spec, nil, &handler)
    }

    static func carbonModifiers(_ modifiers: KeyShortcut.Modifiers) -> UInt32 {
        var flags: UInt32 = 0
        if modifiers.contains(.command) { flags |= UInt32(cmdKey) }
        if modifiers.contains(.shift) { flags |= UInt32(shiftKey) }
        if modifiers.contains(.option) { flags |= UInt32(optionKey) }
        if modifiers.contains(.control) { flags |= UInt32(controlKey) }
        return flags
    }

    static func modifiers(from flags: NSEvent.ModifierFlags) -> KeyShortcut.Modifiers {
        var result: KeyShortcut.Modifiers = []
        if flags.contains(.command) { result.insert(.command) }
        if flags.contains(.shift) { result.insert(.shift) }
        if flags.contains(.option) { result.insert(.option) }
        if flags.contains(.control) { result.insert(.control) }
        return result
    }
}

/// Carbon calls this on the main thread when a registered hot key is pressed.
private func hotKeyEventHandler(_: EventHandlerCallRef?, _ event: EventRef?, _: UnsafeMutableRawPointer?) -> OSStatus {
    guard let event else { return OSStatus(eventNotHandledErr) }
    var hotKeyID = EventHotKeyID()
    let status = GetEventParameter(event, EventParamName(kEventParamDirectObject), EventParamType(typeEventHotKeyID),
                                   nil, MemoryLayout<EventHotKeyID>.size, nil, &hotKeyID)
    guard status == noErr else { return status }
    let id = hotKeyID.id
    MainActor.assumeIsolated {
        GlobalHotKey.instances[id]?.fire()
    }
    return noErr
}
