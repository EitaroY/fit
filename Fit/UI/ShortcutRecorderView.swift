import AppKit
import SwiftUI

/// Click-to-record shortcut field. While recording, a local key monitor
/// captures the next keypress; Esc cancels and plain Delete clears the
/// binding. Recording pauses HotkeyCenter (via notifications) so currently
/// bound combos can be re-captured.
struct ShortcutRecorderView: View {
    let action: SnapAction
    @ObservedObject var store: SettingsStore
    @State private var isRecording = false
    @State private var monitor: Any?

    var body: some View {
        HStack(spacing: 4) {
            Button(action: toggleRecording) {
                Text(label)
                    .font(.body.monospaced())
                    .frame(minWidth: 96)
            }
            .buttonStyle(.bordered)
            .tint(isRecording ? .accentColor : nil)

            Button {
                store.setShortcut(nil, for: action)
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .foregroundStyle(.tertiary)
            }
            .buttonStyle(.plain)
            .disabled(store.shortcut(for: action) == nil)
            .help("Remove shortcut")
        }
        .onDisappear { stopRecording() }
    }

    private var label: String {
        if isRecording { return "Type shortcut…" }
        return store.shortcut(for: action)?.display ?? "None"
    }

    private func toggleRecording() {
        isRecording ? stopRecording() : startRecording()
    }

    private func startRecording() {
        guard monitor == nil else { return }
        isRecording = true
        NotificationCenter.default.post(name: .fitShortcutRecordingBegan, object: nil)
        monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            handle(event)
            return nil // swallow the event
        }
    }

    private func stopRecording() {
        if let monitor {
            NSEvent.removeMonitor(monitor)
            self.monitor = nil
        }
        if isRecording {
            isRecording = false
            NotificationCenter.default.post(name: .fitShortcutRecordingEnded, object: nil)
        }
    }

    private func handle(_ event: NSEvent) {
        let keyCode = UInt32(event.keyCode)
        let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)

        if keyCode == KeyCode.escape {
            stopRecording()
            return
        }
        if keyCode == KeyCode.delete, flags.isEmpty {
            store.setShortcut(nil, for: action)
            stopRecording()
            return
        }
        guard let shortcut = Shortcut(keyCode: keyCode, flags: flags, event: event) else {
            NSSound.beep() // needs ⌘/⌃/⌥ (or a function key)
            return
        }
        store.setShortcut(shortcut, for: action)
        stopRecording()
    }
}

extension Shortcut {
    /// Builds a Shortcut from a recorded key event. Returns nil for combos
    /// too easy to hit accidentally (no ⌘/⌃/⌥ and not a function key).
    init?(keyCode: UInt32, flags: NSEvent.ModifierFlags, event: NSEvent) {
        var carbon: UInt32 = 0
        if flags.contains(.command) { carbon |= CarbonModifier.command }
        if flags.contains(.shift) { carbon |= CarbonModifier.shift }
        if flags.contains(.option) { carbon |= CarbonModifier.option }
        if flags.contains(.control) { carbon |= CarbonModifier.control }

        let hasRealModifier = carbon & ~CarbonModifier.shift != 0
        guard hasRealModifier || KeyCode.functionKeys.contains(keyCode) else { return nil }

        let label = KeyCode.specialLabels[keyCode]
            ?? event.charactersIgnoringModifiers?.uppercased()
            ?? "?"
        self.init(keyCode: keyCode, carbonModifiers: carbon, keyLabel: label)
    }
}
