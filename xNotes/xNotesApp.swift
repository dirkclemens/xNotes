//
//  xNotesApp.swift
//  xNotes
//
//  Created by Dirk Clemens on 15.01.26.
//

import Foundation
import SwiftUI
import Combine

@main
struct xNotesApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
 
    var body: some Scene {
        Settings {
            SettingsView()
        }
    }
}

class KeepWindowOpenState: ObservableObject {
    @Published var keepWindowOpen: Bool {
        didSet {
            UserDefaults.standard.set(keepWindowOpen, forKey: "keepWindowOpen")
        }
    }
    init() {
        self.keepWindowOpen = UserDefaults.standard.bool(forKey: "keepWindowOpen")
    }
}

struct SettingsView: View {
    @AppStorage("keepWindowOpen") private var keepWindowOpen = false
    @AppStorage("editorFontName") private var editorFontName: String = "SF Mono"
    @AppStorage("editorFontSize") private var editorFontSize: Double = 14

    var body: some View {
        Form {
            VStack(alignment: .leading, spacing: 12) {
                Text("Einstellungen").font(.title).padding(.bottom, 10).frame(maxWidth: .infinity, alignment: .leading)

                GroupBox(label: Label("Allgemein", systemImage: "pin")) {
                    Section() {
                        Toggle("Fenster bleibt immer sichtbar", isOn: $keepWindowOpen)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                
                GroupBox(label: Label("Editor", systemImage: "textformat")) {
                    Section() {
                        Picker("Schriftart", selection: $editorFontName) {
                            Text("SF Mono").tag("SF Mono")
                            Text("Menlo").tag("Menlo")
                            Text("Courier New").tag("Courier New")
                            Text("Monaco").tag("Monaco")
                            Text("System Monospaced").tag("__systemMonospaced__")
                            Text("System").tag("__system__")
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        Stepper(value: $editorFontSize, in: 10...32, step: 1) {
                            HStack {
                                Text("Größe")
//                                Spacer()
                                Text("\(Int(editorFontSize)) pt")
                                    .foregroundColor(.secondary)
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding()
        .frame(width: 400)
    }
}
