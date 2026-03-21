//
//  PanelRootView.swift
//  xNotes
//

import SwiftUI
import Combine

struct PanelRootView: View {
    @ObservedObject var notesManager: NotesManager
    @ObservedObject var modeController: PanelModeController
    @ObservedObject var textExpansionStore: TextExpansionStore

    var body: some View {
        switch modeController.mode {
        case .full:
            NotesView(notesManager: notesManager, textExpansionStore: textExpansionStore)
        case .clipboard:
            ClipboardOnlyView(notesManager: notesManager)
        }
    }
}
