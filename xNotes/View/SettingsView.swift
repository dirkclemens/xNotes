//
//  SettingsView.swift
//  xNotes
//

import SwiftUI
import AppKit
import UniformTypeIdentifiers

struct SettingsView: View {
    @StateObject private var loginItemManager = LoginItemManager()
    @ObservedObject var textExpansionStore: TextExpansionStore
    
    @AppStorage("showDockIcon") private var showDockIcon = false
    @AppStorage("keepWindowOpen") private var keepWindowOpen = false
    @AppStorage("editorFontName") private var editorFontName: String = "SF Mono"
    @AppStorage("editorFontSize") private var editorFontSize: Double = 14
    @AppStorage("clipboardMaxItems") private var clipboardMaxItems: Int = 200
    @AppStorage("pasteAsPlainText") private var pasteAsPlainText: Bool = false
    @AppStorage("pasteNormalizeLF") private var pasteNormalizeLF: Bool = true
    @AppStorage("pasteTrimTrailingWhitespace") private var pasteTrimTrailingWhitespace: Bool = true
    @AppStorage("hotkeyEnabled") private var hotkeyEnabled: Bool = false
    @AppStorage("hotkeyKeyCode") private var hotkeyKeyCode: Int = -1
    @AppStorage("hotkeyModifiers") private var hotkeyModifiers: Int = 0
    @AppStorage("hotkeyMode") private var hotkeyMode: String = PanelMode.full.rawValue
    @AppStorage("textExpansionEnabled") private var textExpansionEnabled: Bool = false

    var body: some View {
        Form {
            Section("General") {
                Toggle("Keep Window Open", isOn: $keepWindowOpen)
                Toggle("Show Dock icon", isOn: $showDockIcon)
                    .onChange(of: showDockIcon) { _, value in
                        DockIconManager.apply(showDockIcon: value)
                    }
                Toggle("Launch at login", isOn: Binding(
                    get: { loginItemManager.isEnabled },
                    set: { loginItemManager.setEnabled($0) }
                ))
                if let error = loginItemManager.lastError {
                    Text(error)
                        .font(.caption)
                        .foregroundStyle(.red)
            }
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

            Section("Global Hotkey") {
                Toggle("Enable global hotkey", isOn: $hotkeyEnabled)
                HotkeyRecorderView(keyCode: $hotkeyKeyCode, modifiers: $hotkeyModifiers)
                    .disabled(!hotkeyEnabled)
                Picker("Action", selection: $hotkeyMode) {
                    Text("Open Panel").tag(PanelMode.full.rawValue)
                    Text("Open Clipboard").tag(PanelMode.clipboard.rawValue)
                }
                .pickerStyle(.menu)
                .disabled(!hotkeyEnabled)
                Text("The panel opens near the current selection when possible, otherwise near the mouse pointer.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section("Text Expansions") {
                Toggle("Enable text expansions", isOn: $textExpansionEnabled)
                HStack {
                    Button("Export Rules") {
                        exportTextExpansions()
                    }
                    Button("Import Rules") {
                        importTextExpansions()
                    }
                }
                Text("Expansions are stored locally and applied system-wide.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .padding(1)
//        .frame(width: 520)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(.windowBackground)
    }

    private func exportTextExpansions() {
        let panel = NSSavePanel()
        panel.title = "Export Text Expansions"
        panel.allowedContentTypes = [UTType.json]
        panel.nameFieldStringValue = "xNotes-TextExpansions.json"
        panel.canCreateDirectories = true
        panel.begin { result in
            guard result == .OK, let url = panel.url else { return }
            do {
                let data = try JSONEncoder().encode(textExpansionStore.rules)
                try data.write(to: url, options: .atomic)
            } catch {
                NSLog("Export text expansions failed: %@", error.localizedDescription)
            }
        }
    }

    private func importTextExpansions() {
        let panel = NSOpenPanel()
        panel.title = "Import Text Expansions"
        panel.allowedContentTypes = [UTType.json]
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        panel.begin { result in
            guard result == .OK, let url = panel.url else { return }
            do {
                let data = try Data(contentsOf: url)
                let decoded = try JSONDecoder().decode([TextExpansionRule].self, from: data)
                textExpansionStore.rules = decoded
            } catch {
                NSLog("Import text expansions failed: %@", error.localizedDescription)
            }
        }
    }
}
