//
//  ModifierDoubleTapDetector.swift
//  xNotes
//

import AppKit
import ApplicationServices

/// Modifier key that opens the panel when pressed twice (stored in `hotkeyDoubleTapModifier`).
enum DoubleTapModifier: String, CaseIterable, Identifiable {
    case command
    case option
    case control
    case shift

    var id: String { rawValue }

    var flag: NSEvent.ModifierFlags {
        switch self {
        case .command: return .command
        case .option: return .option
        case .control: return .control
        case .shift: return .shift
        }
    }

    var displayName: String {
        switch self {
        case .command: return "⌘ Command"
        case .option: return "⌥ Option"
        case .control: return "⌃ Control"
        case .shift: return "⇧ Shift"
        }
    }
}

/// Recognizes a modifier key pressed twice in quick succession on its own, anywhere in
/// the system. Shortcuts like ⌘C ⌘V don't count: any other key, another modifier or a
/// click in between starts over, and so does holding the key down.
///
/// Watching keys outside xNotes needs the Accessibility permission. Without it the global
/// monitor receives nothing; `start` is called again when the app becomes active, so the
/// shortcut starts working once the permission has been granted.
final class ModifierDoubleTapDetector {
    /// Longest press that still counts as a tap.
    private static let maxTapDuration: TimeInterval = 0.35
    /// Longest pause between the two taps.
    private static let maxTapInterval: TimeInterval = 0.4
    private static let relevantFlags: NSEvent.ModifierFlags = [.command, .option, .control, .shift, .function]

    let modifier: DoubleTapModifier
    private let handler: () -> Void
    private var globalMonitor: Any?
    private var localMonitor: Any?
    private var isMonitoringTrusted = false

    /// When the modifier went down on its own; nil while not pressed or no longer a tap.
    private var pressStart: TimeInterval?
    /// When the first tap ended.
    private var lastTapEnd: TimeInterval?
    /// Set after a key, click or other modifier while keys were held: nothing counts
    /// until all modifiers are released again (⌘C, then letting go of ⌘, is no tap).
    private var waitsForRelease = false

    init(modifier: DoubleTapModifier, handler: @escaping () -> Void) {
        self.modifier = modifier
        self.handler = handler
    }

    var isRunning: Bool { globalMonitor != nil }

    static var hasPermission: Bool { AXIsProcessTrusted() }

    /// Installs the monitors, or re-installs them if the permission was granted since.
    func start() {
        let trusted = Self.hasPermission
        if isRunning && trusted == isMonitoringTrusted { return }
        stop()
        isMonitoringTrusted = trusted
        let events: NSEvent.EventTypeMask = [.flagsChanged, .keyDown, .leftMouseDown, .rightMouseDown, .otherMouseDown]
        globalMonitor = NSEvent.addGlobalMonitorForEvents(matching: events) { [weak self] event in
            MainActor.assumeIsolated { self?.handle(event) }
        }
        // The global monitor doesn't see events going to xNotes itself.
        localMonitor = NSEvent.addLocalMonitorForEvents(matching: events) { [weak self] event in
            self?.handle(event)
            return event
        }
    }

    func stop() {
        if let globalMonitor {
            NSEvent.removeMonitor(globalMonitor)
            self.globalMonitor = nil
        }
        if let localMonitor {
            NSEvent.removeMonitor(localMonitor)
            self.localMonitor = nil
        }
        reset()
    }

    private func handle(_ event: NSEvent) {
        guard event.type == .flagsChanged else {
            reset()
            return
        }
        let pressed = event.modifierFlags.intersection(Self.relevantFlags)
        if waitsForRelease {
            waitsForRelease = !pressed.isEmpty
            return
        }
        if pressed == modifier.flag {
            // The modifier went down alone (or another one was released while it is held).
            if pressStart == nil {
                pressStart = event.timestamp
            }
        } else if pressed.isEmpty {
            guard let start = pressStart else { return }
            pressStart = nil
            guard event.timestamp - start <= Self.maxTapDuration else {
                lastTapEnd = nil
                return
            }
            if let previous = lastTapEnd, start - previous <= Self.maxTapInterval {
                lastTapEnd = nil
                handler()
            } else {
                lastTapEnd = event.timestamp
            }
        } else {
            // Another modifier is involved, e.g. ⌘⇧.
            reset()
        }
    }

    private func reset() {
        pressStart = nil
        lastTapEnd = nil
        waitsForRelease = !NSEvent.modifierFlags.intersection(Self.relevantFlags).isEmpty
    }
}
