//
//  SettingsView.swift
//  xNotes
//

import SwiftUI
import MarkdownEditorKit
import AppKit
import UniformTypeIdentifiers

struct SettingsView: View {
    @StateObject private var loginItemManager = LoginItemManager()
    @EnvironmentObject var textExpansionStore: TextExpansionStore
    @EnvironmentObject var notesManager: NotesManager
    /// Result of the last export/backup action, shown below the buttons.
    @State private var exportOutcome: NotesExporter.Outcome?

    @AppStorage("showDockIcon") private var showDockIcon = false
    @AppStorage("keepWindowOpen") private var keepWindowOpen = false
    @AppStorage("editorFontName") private var editorFontName: String = "SF Mono"
    @AppStorage("editorFontSize") private var editorFontSize: Double = 14
    @AppStorage("editorTheme") private var editorThemeName: String = MarkdownEditorTheme.systemThemeName
    @AppStorage("editorShowsLineNumbers") private var editorShowsLineNumbers: Bool = false
    @AppStorage("clipboardMaxItems") private var clipboardMaxItems: Int = 200
    @AppStorage("clipboardLineLimit") private var clipboardLineLimit: Int = 4
    @AppStorage("pasteAsPlainText") private var pasteAsPlainText: Bool = false
    @AppStorage("pasteNormalizeLF") private var pasteNormalizeLF: Bool = true
    @AppStorage("pasteTrimTrailingWhitespace") private var pasteTrimTrailingWhitespace: Bool = true
    @AppStorage("hotkeyEnabled") private var hotkeyEnabled: Bool = false
    @AppStorage("hotkeyKeyCode") private var hotkeyKeyCode: Int = -1
    @AppStorage("hotkeyModifiers") private var hotkeyModifiers: Int = 0
    @AppStorage("hotkeyMode") private var hotkeyMode: String = PanelMode.full.rawValue
    @AppStorage("textExpansionEnabled") private var textExpansionEnabled: Bool = false
    @AppStorage("tabAutoDeleteDays") private var tabAutoDeleteDays: Int = 7
    @AppStorage("tabRainbowBorder") private var tabRainbowBorder: Bool = true
    @AppStorage(NotesManager.clipboardSaveSensitiveKey) private var clipboardSaveSensitive: Bool = false
    @AppStorage(AppDelegate.statusMenuClipboardCountKey) private var statusMenuClipboardCount: Int = AppDelegate.statusMenuClipboardCountDefault

    var body: some View {
        Form {
            Section("General") {
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

                Picker("Theme", selection: $editorThemeName) {
                    ForEach(MarkdownEditorTheme.availableThemeNames, id: \.self) { name in
                        Text(name).tag(name)
                    }
                }
                .pickerStyle(.menu)

                Toggle("Show line numbers", isOn: $editorShowsLineNumbers)
            }

            Section("Tabs") {
                Toggle("Rainbow border around tabs", isOn: $tabRainbowBorder)
                Text("Locked tabs get a rainbow border, unlocked ones a gray one that turns as auto-delete approaches.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Stepper(value: $tabAutoDeleteDays, in: 1...365, step: 1) {
                    HStack {
                        Text("Auto-delete Unlocked Tabs")
                        Spacer()
                        Text("\(tabAutoDeleteDays) days")
                            .foregroundColor(.secondary)
                    }
                }
                Text("Unlocked tabs are deleted after this duration since the last edit.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
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

                Stepper(value: $clipboardLineLimit, in: 1...12, step: 1) {
                    HStack {
                        Text("Max Lines per Item")
                        Spacer()
                        Text("\(clipboardLineLimit)")
                            .foregroundColor(.secondary)
                    }
                }

                Stepper(value: $statusMenuClipboardCount, in: 0...30, step: 1) {
                    HStack {
                        Text("Entries in Menu Bar Menu")
                        Spacer()
                        Text(statusMenuClipboardCount == 0 ? "Off" : "\(statusMenuClipboardCount)")
                            .foregroundColor(.secondary)
                    }
                }
                .help("Latest clipboard entries shown when you right-click the menu bar icon")

                Toggle("Save Sensitive Entries", isOn: $clipboardSaveSensitive)
                Text("Password managers mark copied passwords as sensitive. When off, xNotes doesn't record them. Entries marked as temporary or auto-generated are never recorded.")
                    .font(.caption)
                    .foregroundStyle(.secondary)

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

            Section("Export & Backup") {
                LabeledContent("Notes as Text") {
                    HStack {
                        Button("Export to Desktop") {
                            NotesExporter.exportNotesToDesktop(from: notesManager) { exportOutcome = $0 }
                        }
                        .help("Saves ~/Desktop/xNotes-Export-YYYYMMDD.txt; a second export on the same day replaces it")
                        Button("Export As…") {
                            NotesExporter.exportNotesAs(from: notesManager) { exportOutcome = $0 }
                        }
                    }
                }
                LabeledContent("Backup (JSON)") {
                    HStack {
                        Button("Export Backup…") {
                            NotesExporter.exportBackup(from: notesManager) { exportOutcome = $0 }
                        }
                        Button("Import Backup…") {
                            NotesExporter.importBackup(into: notesManager) { exportOutcome = $0 }
                        }
                    }
                }
                switch exportOutcome {
                case .success(let message):
                    Text(message)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                case .failure(let message):
                    Text(message)
                        .font(.caption)
                        .foregroundStyle(.red)
                case nil:
                    Text("A backup contains all tabs and the clipboard history. Importing replaces the current tabs.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .formStyle(.grouped)
        .padding(1)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onChange(of: textExpansionEnabled) { _, enabled in
            if enabled {
                AppDelegate.sharedTextExpansionEngine?.start()
            } else {
                AppDelegate.sharedTextExpansionEngine?.stop()
            }
        }
    }

    private func exportTextExpansions() {
        let panel = NSSavePanel()
        panel.title = "Export Text Expansions"
        panel.allowedContentTypes = [UTType.json]
        panel.nameFieldStringValue = NotesExporter.datedFileName("xNotes-TextExpansions", extension: "json")
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
