//
//  HotkeyRecorderView.swift
//  xNotes
//

import SwiftUI
import AppKit
import Carbon
import Carbon.HIToolbox

struct HotkeyRecorderView: View {
    @Binding var keyCode: Int
    @Binding var modifiers: Int

    @State private var isRecording = false
    @State private var monitor: Any?

    var body: some View {
        HStack {
            Text(displayString)
                .frame(minWidth: 140, alignment: .leading)
                .foregroundColor(isRecording ? .primary : .secondary)

            Button(isRecording ? "Press keys..." : "Record") {
                toggleRecording()
            }

            Button("Clear") {
                keyCode = -1
                modifiers = 0
            }
            .disabled(keyCode < 0)
        }
        .onDisappear {
            stopRecording()
        }
    }

    private var displayString: String {
        guard keyCode >= 0 else { return "Not set" }
        return HotkeyFormatter.format(keyCode: UInt16(keyCode), modifiers: modifiers)
    }

    private func toggleRecording() {
        if isRecording {
            stopRecording()
        } else {
            startRecording()
        }
    }

    private func startRecording() {
        guard monitor == nil else { return }
        isRecording = true
        monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
            if event.keyCode == 53 { // ESC
                stopRecording()
                return nil
            }
            let allowedFlags: NSEvent.ModifierFlags = [.command, .option, .control, .shift]
            let normalizedFlags = flags.intersection(allowedFlags)
            guard !normalizedFlags.isEmpty else {
                return nil
            }
            keyCode = Int(event.keyCode)
            modifiers = Int(normalizedFlags.rawValue)
            stopRecording()
            return nil
        }
        NSApp.activate(ignoringOtherApps: true)
    }

    private func stopRecording() {
        if let monitor {
            NSEvent.removeMonitor(monitor)
            self.monitor = nil
        }
        isRecording = false
    }
}

enum HotkeyFormatter {
    static func format(keyCode: UInt16, modifiers: Int) -> String {
        let flags = NSEvent.ModifierFlags(rawValue: UInt(modifiers))
        var parts: [String] = []
        if flags.contains(.control) { parts.append("⌃") }
        if flags.contains(.option) { parts.append("⌥") }
        if flags.contains(.shift) { parts.append("⇧") }
        if flags.contains(.command) { parts.append("⌘") }
        let key = keyCodeToString(keyCode)
        return parts.joined() + key
    }

    private static func keyCodeToString(_ keyCode: UInt16) -> String {
        guard let source = TISCopyCurrentKeyboardLayoutInputSource()?.takeRetainedValue(),
              let rawLayoutData = TISGetInputSourceProperty(source, kTISPropertyUnicodeKeyLayoutData) else {
            return "Key \(keyCode)"
        }

        let layoutData = unsafeBitCast(rawLayoutData, to: CFData.self)
        guard let layoutPtr = CFDataGetBytePtr(layoutData) else {
            return "Key \(keyCode)"
        }

        var deadKeyState: UInt32 = 0
        var chars = [UniChar](repeating: 0, count: 4)
        var length = 0
        let status = UCKeyTranslate(
            UnsafePointer<UCKeyboardLayout>(OpaquePointer(layoutPtr)),
            keyCode,
            UInt16(kUCKeyActionDisplay),
            0,
            UInt32(LMGetKbdType()),
            UInt32(kUCKeyTranslateNoDeadKeysBit),
            &deadKeyState,
            4,
            &length,
            &chars
        )
        if status == noErr, length > 0 {
            return String(utf16CodeUnits: chars, count: length).uppercased()
        }
        return "Key \(keyCode)"
    }
}
