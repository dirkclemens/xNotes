//
//  SelectedTabContentView.swift
//  xNotes
//

import SwiftUI

struct SelectedTabContentView: View {
    @ObservedObject var tab: NoteTab
    @EnvironmentObject var notesManager: NotesManager
    @EnvironmentObject var textExpansionStore: TextExpansionStore

    var body: some View {
        if tab.kind == .clipboard {
            ClipboardView(items: tab.clipboardItems)
        } else if tab.kind == .expansions {
            TextExpansionView()
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
