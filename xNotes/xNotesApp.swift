//
//  xNotesApp.swift
//  xNotes
//

import SwiftUI

@main
struct xNotesApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    init() {
        let showDockIcon = UserDefaults.standard.bool(forKey: "showDockIcon")
        DockIconManager.apply(showDockIcon: showDockIcon)
    }
    
    var body: some Scene {
        Settings {
            SettingsView()
                .environmentObject(TextExpansionStore.shared)
        }
    }
}

