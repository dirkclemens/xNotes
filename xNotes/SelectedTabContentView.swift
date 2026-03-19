//
//  SelectedTabContentView.swift
//  xNotes
//

import SwiftUI

struct SelectedTabContentView: View {
    @ObservedObject var tab: NoteTab
    @ObservedObject var notesManager: NotesManager

    var body: some View {
        if tab.kind == .clipboard {
            ClipboardView(items: tab.clipboardItems, notesManager: notesManager)
        } else {
            TextEditorView(
                content: Binding(
                    get: { tab.content },
                    set: { notesManager.updateContent(for: tab.id, content: $0) }
                )
            )
        }
    }
}
