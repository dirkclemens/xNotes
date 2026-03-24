//
//  PanelRootView.swift
//  xNotes
//

import SwiftUI


struct PanelRootView: View {
    @EnvironmentObject var notesManager: NotesManager
    @EnvironmentObject var modeController: PanelModeController
    @EnvironmentObject var textExpansionStore: TextExpansionStore

    var body: some View {
        switch modeController.mode {
        case .full:
            NotesView()
        case .clipboard:
            ClipboardOnlyView()
        }
    }
}
