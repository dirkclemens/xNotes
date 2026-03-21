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
    private let handler: () -> Void

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
            self?.refreshRegistration()
        }
    }

    func stop() {
        unregister()
        if let defaultsObserver {
            NotificationCenter.default.removeObserver(defaultsObserver)
            self.defaultsObserver = nil
        }
    }

    private func refreshRegistration() {
        let defaults = UserDefaults.standard
        let enabled = defaults.bool(forKey: "hotkeyEnabled")
        let keyCode = (defaults.object(forKey: "hotkeyKeyCode") as? Int) ?? -1
        let modifiers = (defaults.object(forKey: "hotkeyModifiers") as? Int) ?? 0

        guard enabled, keyCode >= 0, modifiers != 0 else {
            unregister()
            return
        }

        register(keyCode: UInt32(keyCode), modifiers: carbonModifiers(from: modifiers))
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
