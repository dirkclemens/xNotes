//
//  ClipboardOnlyView.swift
//  xNotes
//

import SwiftUI

struct ClipboardOnlyView: View {
    @ObservedObject var notesManager: NotesManager

    var body: some View {
        if let tab = notesManager.tabs.first(where: { $0.kind == .clipboard }) {
            ClipboardView(items: tab.clipboardItems, notesManager: notesManager)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            Text("Clipboard is empty")
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
}
