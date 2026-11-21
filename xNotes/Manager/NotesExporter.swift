//
//  NotesExporter.swift
//  xNotes
//

import AppKit
import UniformTypeIdentifiers

/// Text export of all notes and JSON backup export/import, triggered from Settings.
/// Each action reports a short, user-facing result message.
enum NotesExporter {
    enum Outcome {
        case success(String)
        case failure(String)
    }

    /// Target of the one-click export.
    static var desktopExportURL: URL {
        let desktop = FileManager.default.urls(for: .desktopDirectory, in: .userDomainMask).first
            ?? FileManager.default.homeDirectoryForCurrentUser
        return desktop.appendingPathComponent("xNotes-Export.txt")
    }

    // MARK: - Notes as text

    static func exportNotesToDesktop(from notesManager: NotesManager, completion: @escaping (Outcome) -> Void) {
        let url = desktopExportURL
        writeTextExport(of: notesManager, to: url, completion: completion)
    }

    static func exportNotesAs(from notesManager: NotesManager, completion: @escaping (Outcome) -> Void) {
        let panel = NSSavePanel()
        panel.title = "Export Notes"
        panel.allowedContentTypes = [UTType.plainText]
        panel.nameFieldStringValue = "xNotes-Export.txt"
        panel.canCreateDirectories = true
        panel.begin { result in
            guard result == .OK, let url = panel.url else { return }
            writeTextExport(of: notesManager, to: url, completion: completion)
        }
    }

    // MARK: - Backup (JSON)

    static func exportBackup(from notesManager: NotesManager, completion: @escaping (Outcome) -> Void) {
        let panel = NSSavePanel()
        panel.title = "Export Backup"
        panel.allowedContentTypes = [UTType.json]
        panel.nameFieldStringValue = "xNotes-Backup.json"
        panel.canCreateDirectories = true
        panel.begin { result in
            guard result == .OK, let url = panel.url else { return }
            do {
                let data = try notesManager.exportBackupData()
                try data.write(to: url, options: .atomic)
                completion(.success("Backup saved to \(displayPath(url))."))
            } catch {
                completion(.failure("Backup export failed: \(error.localizedDescription)"))
            }
        }
    }

    static func importBackup(into notesManager: NotesManager, completion: @escaping (Outcome) -> Void) {
        let panel = NSOpenPanel()
        panel.title = "Import Backup"
        panel.allowedContentTypes = [UTType.json]
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        panel.begin { result in
            guard result == .OK, let url = panel.url else { return }
            do {
                let data = try Data(contentsOf: url)
                try notesManager.importBackupData(data)
                completion(.success("Backup imported from \(displayPath(url))."))
            } catch {
                completion(.failure("Backup import failed: \(error.localizedDescription)"))
            }
        }
    }

    // MARK: - Helpers

    private static func writeTextExport(of notesManager: NotesManager, to url: URL, completion: @escaping (Outcome) -> Void) {
        let text = exportText(of: notesManager)
        let path = displayPath(url)
        DispatchQueue.global(qos: .userInitiated).async {
            let outcome: Outcome
            do {
                try text.write(to: url, atomically: true, encoding: .utf8)
                outcome = .success("Notes exported to \(path).")
            } catch {
                outcome = .failure("Export failed: \(error.localizedDescription)")
            }
            DispatchQueue.main.async {
                completion(outcome)
            }
        }
    }

    private static func exportText(of notesManager: NotesManager) -> String {
        var text = ""
        for (index, tab) in notesManager.tabs.enumerated() {
            let title = tab.title ?? "Tab \(index + 1)"
            text += "===== \(title) =====\n"
            text += tab.content + "\n\n"
        }
        return text
    }

    /// Path with the home folder shortened to "~".
    private static func displayPath(_ url: URL) -> String {
        (url.path as NSString).abbreviatingWithTildeInPath
    }
}
