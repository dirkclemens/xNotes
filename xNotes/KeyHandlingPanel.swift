import AppKit

/// A panel that can become key and intercepts common close keys (Esc, ⌘W).
final class KeyHandlingPanel: NSPanel {
    // Allow the panel to become key/main so it can receive keyboard events
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }

    override func keyDown(with event: NSEvent) {
        // Escape key
        if event.keyCode == 53 { // kVK_Escape
            NotificationCenter.default.post(name: AppDelegate.closePopoverNotification, object: nil)
            return
        }
        // Command-W (close)
        if event.modifierFlags.contains(.command), let characters = event.charactersIgnoringModifiers, characters.lowercased() == "w" {
            NotificationCenter.default.post(name: AppDelegate.closePopoverNotification, object: nil)
            return
        }
        super.keyDown(with: event)
    }

    /// Convenience initializer matching NSPanel's designated initializer.
//    convenience init(contentRect: NSRect, styleMask: NSWindow.StyleMask, backing: NSWindow.BackingStoreType, defer flag: Bool) {
//        self.init(contentRect: contentRect, styleMask: styleMask, backing: backing, defer: flag, screen: nil)
//    }
}
