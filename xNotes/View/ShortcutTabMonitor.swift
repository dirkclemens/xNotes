//
//  ShortcutTabMonitor.swift
//  xNotes
//

import SwiftUI
import AppKit

struct ShortcutTabMonitor: NSViewRepresentable {
    @EnvironmentObject var notesManager: NotesManager
    /// While the search bar is visible, Escape closes the search instead of the panel.
    var isSearchVisible: Bool = false

    func makeCoordinator() -> Coordinator {
        Coordinator(notesManager: notesManager)
    }

    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        context.coordinator.hostView = view
        context.coordinator.isSearchVisible = isSearchVisible
        context.coordinator.installMonitor()
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        context.coordinator.notesManager = notesManager
        context.coordinator.isSearchVisible = isSearchVisible
    }

    class Coordinator: NSObject {
        var notesManager: NotesManager
        var isSearchVisible = false
        /// Used to limit shortcuts to the window that hosts this view
        /// (not the Settings window or sheets such as "Edit Item").
        weak var hostView: NSView?
        private var monitor: Any?

        init(notesManager: NotesManager) {
            self.notesManager = notesManager
        }

        func installMonitor() {
            guard monitor == nil else { return }
            monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
                guard let self else { return event }
                guard let window = self.hostView?.window, event.window === window else { return event }

                if event.keyCode == 53, self.isSearchVisible { // kVK_Escape
                    NotificationCenter.default.post(name: ShortcutNotifications.closeSearch, object: nil)
                    return nil
                }

                guard let chars = event.charactersIgnoringModifiers, chars.count == 1 else { return event }
                let lower = chars.lowercased()

                if event.modifierFlags.contains(.command), lower == "f" {
                    NotificationCenter.default.post(name: ShortcutNotifications.focusSearch, object: nil)
                    return nil
                }
                if event.modifierFlags.contains(.command), lower == "g" {
                    if event.modifierFlags.contains(.shift) {
                        NotificationCenter.default.post(name: ShortcutNotifications.findPrevious, object: nil)
                    } else {
                        NotificationCenter.default.post(name: ShortcutNotifications.findNext, object: nil)
                    }
                    return nil
                }

                guard let digit = Int(chars), digit >= 0 && digit <= 9 else { return event }

                if event.modifierFlags.contains(.option) {
                    if digit >= 1 && digit <= 9, self.notesManager.isClipboardTabSelected() {
                        if self.notesManager.pastePinnedSlot(digit) {
                            return nil
                        }
                    }
                    return event
                }

                if event.modifierFlags.contains(.command) {
                    guard digit >= 1 && digit <= 9 else { return event }
                    let index = digit - 1
                    if index < self.notesManager.tabs.count {
                        self.notesManager.selectedTabId = self.notesManager.tabs[index].id
                        return nil
                    }
                }

                return event
            }
        }

        deinit {
            if let monitor {
                NSEvent.removeMonitor(monitor)
            }
        }
    }
}
