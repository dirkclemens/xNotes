//
//  SelectedTabContentView.swift
//  xNotes
//

import SwiftUI

struct SelectedTabContentView: View {
    @ObservedObject var tab: NoteTab
    @ObservedObject var notesManager: NotesManager
    @ObservedObject var textExpansionStore: TextExpansionStore

    var body: some View {
        switch tab.kind {
        case .clipboard:
            ClipboardView(items: tab.clipboardItems, notesManager: notesManager)
        case .expansions:
            TextExpansionView(store: textExpansionStore)
        case .note:
            TextEditorView(
                content: Binding(
                    get: { tab.content },
                    set: { notesManager.updateContent(for: tab.id, content: $0) }
                )
            )
        }
    }
}
