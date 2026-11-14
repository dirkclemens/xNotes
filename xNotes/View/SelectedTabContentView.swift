//
//  SelectedTabContentView.swift
//  xNotes
//

import SwiftUI

struct SelectedTabContentView: View {
    @ObservedObject var tab: NoteTab
    /// When `false` (e.g. while the search bar is active) the editor must not grab keyboard focus.
    var autoFocusEditor: Bool = true
    /// The current search match, if it belongs to this tab.
    var searchHighlight: SearchResult? = nil
    @EnvironmentObject var notesManager: NotesManager
    @EnvironmentObject var textExpansionStore: TextExpansionStore

    var body: some View {
        if tab.kind == .clipboard {
            ClipboardView(items: tab.clipboardItems, highlightedItemId: searchHighlight?.clipboardItemId)
        } else if tab.kind == .expansions {
            TextExpansionView()
        } else {
            TextEditorView(
                content: Binding(
                    get: { tab.content },
                    set: { notesManager.updateContent(for: tab.id, content: $0) }
                ),
                autoFocus: autoFocusEditor,
                highlight: searchHighlight.flatMap { result in
                    result.range.map { MarkdownEditorHighlight(id: result.id, range: $0) }
                }
            )
        }
    }
}
