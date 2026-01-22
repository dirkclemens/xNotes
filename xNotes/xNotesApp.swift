//
//  xNotesApp.swift
//  xNotes
//
//  Created by Dirk Clemens on 15.01.26.
//

import SwiftUI

@main
struct xNotesApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    var body: some Scene {
        Settings {
            EmptyView()
        }
    }
}
