//
//  NotesManager+ClipboardTransforms.swift
//  xNotes
//
//  Applies clipboard transforms (built-in or plugin) to clipboard history items.
//  The transforms themselves live in `Transforms/`.
//

import Foundation
import AppKit

extension NotesManager {
    func editClipboardItem(id: ClipboardItem.ID, with text: String) {
        replaceClipboardItem(id: id, with: text, updatePasteboard: false)
    }

    func applyTransform(_ transform: ClipboardTransform, toClipboardItem id: ClipboardItem.ID) {
        guard let original = clipboardText(for: id) else { return }

        var argument: String?
        if case .prompt(let label) = transform.input {
            guard let value = promptForText(title: transform.title, message: label) else { return }
            argument = value
        }

        Task { @MainActor in
            let result = await TransformExecutor.run(transform, text: original, argument: argument)
            let registry = TransformRegistry.shared
            switch result {
            case .success(let output?) where output != original:
                // The item may have been edited or removed while the transform was running.
                guard self.clipboardText(for: id) == original else { return }
                self.replaceClipboardItem(id: id, with: output)
            case .success:
                registry.show("“\(transform.title)” did not change the text.")
            case .failure(let error):
                registry.show(error.localizedDescription, isError: true)
            }
        }
    }

    // MARK: - Helpers

    private func promptForText(title: String, message: String) -> String? {
        let alert = NSAlert()
        alert.messageText = title
        alert.informativeText = message
        alert.addButton(withTitle: "OK")
        alert.addButton(withTitle: "Cancel")
        let field = NSTextField(frame: NSRect(x: 0, y: 0, width: 280, height: 24))
        alert.accessoryView = field
        let result = alert.runModal()
        guard result == .alertFirstButtonReturn else { return nil }
        return field.stringValue
    }
}
