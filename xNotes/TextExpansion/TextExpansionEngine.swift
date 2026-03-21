//
//  TextExpansionEngine.swift
//  xNotes
//

import Foundation
import AppKit
import Combine
import Carbon.HIToolbox

final class TextExpansionEngine {
    private let store: TextExpansionStore
    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    private var buffer: String = ""
    private let maxBufferLength: Int = 64
    private var rules: [TextExpansionRule] = []
    private var cancellable: AnyCancellable?
    private var isInjecting = false

    init(store: TextExpansionStore) {
        self.store = store
        self.rules = store.rules
            .filter { $0.isEnabled && !$0.trigger.isEmpty }
            .sorted { $0.trigger.count > $1.trigger.count }

        cancellable = store.$rules.sink { [weak self] rules in
            guard let self else { return }
            self.rules = rules
                .filter { $0.isEnabled && !$0.trigger.isEmpty }
                .sorted { $0.trigger.count > $1.trigger.count }
        }
    }

    func start() {
        guard eventTap == nil else { return }
        _ = ensureAccessibilityPermission()

        let mask = (1 << CGEventType.keyDown.rawValue)
        let callback: CGEventTapCallBack = { proxy, type, event, refcon in
            guard let refcon else { return Unmanaged.passUnretained(event) }
            let engine = Unmanaged<TextExpansionEngine>.fromOpaque(refcon).takeUnretainedValue()
            return engine.handleEvent(proxy: proxy, type: type, event: event)
        }

        let refcon = Unmanaged.passUnretained(self).toOpaque()
        eventTap = CGEvent.tapCreate(
            tap: .cgAnnotatedSessionEventTap,
            place: .tailAppendEventTap,
            options: .defaultTap,
            eventsOfInterest: CGEventMask(mask),
            callback: callback,
            userInfo: refcon
        )

        guard let eventTap else {
            NSLog("TextExpansionEngine: failed to create event tap.")
            return
        }

        runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, eventTap, 0)
        if let runLoopSource {
            CFRunLoopAddSource(CFRunLoopGetMain(), runLoopSource, .commonModes)
        }
        CGEvent.tapEnable(tap: eventTap, enable: true)
    }

    func stop() {
        if let runLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), runLoopSource, .commonModes)
            self.runLoopSource = nil
        }
        if let eventTap {
            CFMachPortInvalidate(eventTap)
            self.eventTap = nil
        }
        buffer = ""
    }

    private func handleEvent(proxy: CGEventTapProxy, type: CGEventType, event: CGEvent) -> Unmanaged<CGEvent>? {
        if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
            if let eventTap {
                CGEvent.tapEnable(tap: eventTap, enable: true)
            }
            return Unmanaged.passUnretained(event)
        }

        guard type == .keyDown else {
            return Unmanaged.passUnretained(event)
        }

        if isInjecting {
            return Unmanaged.passUnretained(event)
        }

        if IsSecureEventInputEnabled() {
            buffer = ""
            return Unmanaged.passUnretained(event)
        }

        let flags = event.flags
        if flags.contains(.maskCommand) || flags.contains(.maskControl) || flags.contains(.maskAlternate) {
            buffer = ""
            return Unmanaged.passUnretained(event)
        }

        let keyCode = event.getIntegerValueField(.keyboardEventKeycode)
        if keyCode == 51 { // backspace
            if !buffer.isEmpty {
                buffer.removeLast()
            }
            return Unmanaged.passUnretained(event)
        }

        if let inserted = eventInsertedString(event) {
            buffer.append(inserted)
            if buffer.count > maxBufferLength {
                buffer = String(buffer.suffix(maxBufferLength))
            }

            if let match = matchedRule(in: buffer) {
                buffer = ""
                triggerExpansion(match)
            }
        }

        return Unmanaged.passUnretained(event)
    }

    private func eventInsertedString(_ event: CGEvent) -> String? {
        var length = 0
        var buffer = [UniChar](repeating: 0, count: 8)
        event.keyboardGetUnicodeString(maxStringLength: buffer.count, actualStringLength: &length, unicodeString: &buffer)
        guard length > 0 else { return nil }
        return String(utf16CodeUnits: buffer, count: length)
    }

    private func matchedRule(in buffer: String) -> TextExpansionRule? {
        for rule in rules {
            if buffer.hasSuffix(rule.trigger) {
                return rule
            }
        }
        return nil
    }

    private func triggerExpansion(_ rule: TextExpansionRule) {
        guard !rule.replacement.isEmpty else { return }
        isInjecting = true

        let source = CGEventSource(stateID: .combinedSessionState)
        let backspaceKeyCode = CGKeyCode(51)

        for _ in 0..<rule.trigger.count {
            let keyDown = CGEvent(keyboardEventSource: source, virtualKey: backspaceKeyCode, keyDown: true)
            let keyUp = CGEvent(keyboardEventSource: source, virtualKey: backspaceKeyCode, keyDown: false)
            keyDown?.post(tap: .cghidEventTap)
            keyUp?.post(tap: .cghidEventTap)
        }

        let replacement = rule.replacement
        let chars = Array(replacement.utf16)
        if let keyDown = CGEvent(keyboardEventSource: source, virtualKey: 0, keyDown: true),
           let keyUp = CGEvent(keyboardEventSource: source, virtualKey: 0, keyDown: false) {
            keyDown.keyboardSetUnicodeString(stringLength: chars.count, unicodeString: chars)
            keyUp.keyboardSetUnicodeString(stringLength: chars.count, unicodeString: chars)
            keyDown.post(tap: .cghidEventTap)
            keyUp.post(tap: .cghidEventTap)
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) { [weak self] in
            self?.isInjecting = false
        }
    }

    private func ensureAccessibilityPermission() -> Bool {
        if AXIsProcessTrusted() {
            return true
        }
        let options: NSDictionary = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as NSString: true]
        _ = AXIsProcessTrustedWithOptions(options)
        NSLog("Accessibility permission is required for text expansions.")
        return false
    }
}
