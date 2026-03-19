//
//  SettingsView.swift
//  xNotes
//

import SwiftUI

struct SettingsView: View {
    @AppStorage("keepWindowOpen") private var keepWindowOpen = false
    @AppStorage("editorFontName") private var editorFontName: String = "SF Mono"
    @AppStorage("editorFontSize") private var editorFontSize: Double = 14
    @AppStorage("clipboardMaxItems") private var clipboardMaxItems: Int = 200
    @AppStorage("pasteAsPlainText") private var pasteAsPlainText: Bool = false
    @AppStorage("pasteNormalizeLF") private var pasteNormalizeLF: Bool = true
    @AppStorage("pasteTrimTrailingWhitespace") private var pasteTrimTrailingWhitespace: Bool = true

    var body: some View {
        Form {
            Section("General") {
                Toggle("Keep Window Open", isOn: $keepWindowOpen)
            }

            Section("Editor") {
                Picker("Font", selection: $editorFontName) {
                    Text("SF Mono").tag("SF Mono")
                    Text("Menlo").tag("Menlo")
                    Text("Courier New").tag("Courier New")
                    Text("Monaco").tag("Monaco")
                    Text("System Monospaced").tag("__systemMonospaced__")
                    Text("System").tag("__system__")
                }
                .pickerStyle(.menu)

                Stepper(value: $editorFontSize, in: 10...32, step: 1) {
                    LabeledContent("Size") {
                        Text("\(Int(editorFontSize)) pt")
                            .foregroundColor(.secondary)
                    }
                }
            }

            Section {
                Stepper(value: $clipboardMaxItems, in: 50...1000, step: 10) {
                    HStack {
                        Text("Max Entries")
                        Spacer()
                        Text("\(clipboardMaxItems)")
                            .foregroundColor(.secondary)
                    }
                }

                Toggle("Paste as Plain Text", isOn: $pasteAsPlainText)
                Toggle("Normalize Line Endings to LF", isOn: $pasteNormalizeLF)
                    .disabled(!pasteAsPlainText)
                Toggle("Trim Trailing Whitespace", isOn: $pasteTrimTrailingWhitespace)
                    .disabled(!pasteAsPlainText)
            } header: {
                Text("Clipboard")
            } footer: {
                Text("Normalization applies to paste actions triggered from xNotes.")
            }

        }
        .formStyle(.grouped)
        .padding(20)
        .frame(width: 520)
    }
}
