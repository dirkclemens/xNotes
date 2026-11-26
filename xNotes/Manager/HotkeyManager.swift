//
//  HotkeyManager.swift
//  xNotes
//

import Foundation
import AppKit
import Carbon.HIToolbox

@MainActor
final class HotkeyManager {
    private var hotKeyRef: EventHotKeyRef?
    private var eventHandlerRef: EventHandlerRef?
    private var defaultsObserver: NSObjectProtocol?
    private var activationObserver: NSObjectProtocol?
    private var doubleTapDetector: ModifierDoubleTapDetector?
    private let handler: () -> Void

    /// How the panel is opened: a key combination or a modifier pressed twice.
    enum Trigger: String {
        case keyCombination
        case doubleTap
    }

    static let triggerKey = "hotkeyTrigger"
    static let doubleTapModifierKey = "hotkeyDoubleTapModifier"

    init(handler: @escaping () -> Void) {
        self.handler = handler
    }

    func start() {
        registerEventHandlerIfNeeded()
        refreshRegistration()
        defaultsObserver = NotificationCenter.default.addObserver(
            forName: UserDefaults.didChangeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            // The observer is delivered on the main queue, so we're on the main actor here.
            MainActor.assumeIsolated {
                self?.refreshRegistration()
            }
        }
        // Returning from System Settings: the Accessibility permission may have been granted.
        activationObserver = NotificationCenter.default.addObserver(
            forName: NSApplication.didBecomeActiveNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.doubleTapDetector?.start()
            }
        }
    }

    func stop() {
        unregister()
        if let defaultsObserver {
            NotificationCenter.default.removeObserver(defaultsObserver)
            self.defaultsObserver = nil
        }
        if let activationObserver {
            NotificationCenter.default.removeObserver(activationObserver)
            self.activationObserver = nil
        }
        stopDoubleTap()
    }

    private func refreshRegistration() {
        let defaults = UserDefaults.standard
        let enabled = defaults.bool(forKey: "hotkeyEnabled")
        let keyCode = (defaults.object(forKey: "hotkeyKeyCode") as? Int) ?? -1
        let modifiers = (defaults.object(forKey: "hotkeyModifiers") as? Int) ?? 0
        let trigger = defaults.string(forKey: Self.triggerKey).flatMap(Trigger.init) ?? .keyCombination

        guard enabled else {
            unregister()
            stopDoubleTap()
            return
        }

        switch trigger {
        case .doubleTap:
            unregister()
            let modifier = defaults.string(forKey: Self.doubleTapModifierKey).flatMap(DoubleTapModifier.init) ?? .command
            startDoubleTap(modifier: modifier)
        case .keyCombination:
            stopDoubleTap()
            guard keyCode >= 0, modifiers != 0 else {
                unregister()
                return
            }
            // Defaults change often (any setting); only re-register when needed.
            let combination = (UInt32(keyCode), carbonModifiers(from: modifiers))
            if hotKeyRef != nil, registeredCombination.map({ $0 == combination }) == true { return }
            register(keyCode: combination.0, modifiers: combination.1)
            registeredCombination = combination
        }
    }

    private var registeredCombination: (UInt32, UInt32)?

    private func startDoubleTap(modifier: DoubleTapModifier) {
        if doubleTapDetector?.modifier != modifier {
            doubleTapDetector?.stop()
            doubleTapDetector = ModifierDoubleTapDetector(modifier: modifier) { [weak self] in
                self?.handler()
            }
        }
        doubleTapDetector?.start()
    }

    private func stopDoubleTap() {
        doubleTapDetector?.stop()
        doubleTapDetector = nil
    }

    private func register(keyCode: UInt32, modifiers: UInt32) {
        unregister()

        let hotKeyID = EventHotKeyID(signature: Self.signature, id: 1)
        let status = RegisterEventHotKey(
            keyCode,
            modifiers,
            hotKeyID,
            GetEventDispatcherTarget(),
            0,
            &hotKeyRef
        )
        if status != noErr {
            hotKeyRef = nil
        }
    }

    private func unregister() {
        registeredCombination = nil
        if let hotKeyRef {
            UnregisterEventHotKey(hotKeyRef)
            self.hotKeyRef = nil
        }
    }

    private func registerEventHandlerIfNeeded() {
        guard eventHandlerRef == nil else { return }

        var eventType = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        let status = InstallEventHandler(
            GetEventDispatcherTarget(),
            { _, _, _ in
                if let manager = HotkeyManager.activeManager {
                    manager.handler()
                }
                return noErr
            },
            1,
            &eventType,
            nil,
            &eventHandlerRef
        )
        if status != noErr {
            eventHandlerRef = nil
        }
        HotkeyManager.activeManager = self
    }

    private func carbonModifiers(from cocoaModifiers: Int) -> UInt32 {
        let flags = NSEvent.ModifierFlags(rawValue: UInt(cocoaModifiers))
        var carbon: UInt32 = 0
        if flags.contains(.command) { carbon |= UInt32(cmdKey) }
        if flags.contains(.option) { carbon |= UInt32(optionKey) }
        if flags.contains(.control) { carbon |= UInt32(controlKey) }
        if flags.contains(.shift) { carbon |= UInt32(shiftKey) }
        return carbon
    }

    private static let signature: OSType = 0x584E5473 // "XNTs"
    private static var activeManager: HotkeyManager?
}
