//
//  ClipboardOnlyView.swift
//  xNotes
//

import SwiftUI

struct ClipboardOnlyView: View {
    @EnvironmentObject var notesManager: NotesManager

    var body: some View {
        if let tab = notesManager.tabs.first(where: { $0.kind == .clipboard }) {
            ClipboardView(items: tab.clipboardItems)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            Text("No clipboard tab found.")
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
}
