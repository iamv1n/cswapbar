import AppKit
import CSwapBarCore
import SwiftUI

/// Click, then press a key combination. Esc cancels.
///
/// While recording, the global hot key is suspended (`isRecordingShortcut`)
/// so pressing the current shortcut records it instead of toggling Privacy Mode.
struct ShortcutRecorder: View {
    @Bindable var model: AppModel
    @Binding var shortcut: KeyShortcut
    @Binding var isEnabled: Bool
    /// What the shortcut does, for VoiceOver.
    var purpose: String = "Privacy Mode"
    @Environment(\.theme) private var theme
    @State private var recording = false
    @State private var monitor: Any?
    @State private var hint: String?

    var body: some View {
        HStack(spacing: 8) {
            if let hint, recording {
                Text(hint)
                    .font(theme.type.footnote)
                    .foregroundStyle(theme.warning)
                    .lineLimit(1)
                    .fixedSize()
            }
            Button(action: toggle) {
                Text(recording ? "Press keys…" : shortcut.displayString)
                    .font(theme.type.font(13, .semibold))
                    .tracking(1.5)
                    .foregroundStyle(recording ? theme.accent : theme.text)
                    .lineLimit(1)
                    .fixedSize()
                    .padding(.horizontal, 12)
                    .padding(.vertical, 5)
                    .frame(minWidth: 92)
                    .background(Color.primary.opacity(0.06), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .strokeBorder(recording ? theme.accent : theme.border, lineWidth: recording ? 1.5 : 1))
            }
            .buttonStyle(.quiet)
            .accessibilityLabel(recording ? "Recording shortcut. Press keys, or Escape to cancel."
                                          : "\(purpose) shortcut, \(shortcut.displayString). Click to change.")
        }
        .onDisappear(perform: stop)
    }

    private func toggle() {
        recording ? stop() : start()
    }

    private func start() {
        recording = true
        hint = nil
        model.isRecordingShortcut = true
        monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            MainActor.assumeIsolated { handle(event) }
            return nil
        }
    }

    private func handle(_ event: NSEvent) {
        let modifiers = GlobalHotKey.modifiers(from: event.modifierFlags)
        let keyCode = UInt32(event.keyCode)
        if keyCode == 53, modifiers.isEmpty {   // Esc
            stop()
            return
        }
        let shortcut = KeyShortcut(
            keyCode: keyCode, modifiers: modifiers,
            keyLabel: KeyShortcut.label(forKeyCode: keyCode, characters: event.charactersIgnoringModifiers))
        guard shortcut.isValidGlobalShortcut else {
            hint = "Include ⌘, ⌃ or ⌥"
            return
        }
        self.shortcut = shortcut
        isEnabled = true
        stop()
    }

    private func stop() {
        if let monitor { NSEvent.removeMonitor(monitor) }
        monitor = nil
        recording = false
        hint = nil
        if model.isRecordingShortcut { model.isRecordingShortcut = false }
    }
}
