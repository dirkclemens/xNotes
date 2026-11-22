//
//  AppBackup.swift
//  xNotes
//

import Foundation

struct AppBackup: Codable {
    let schemaVersion: Int
    let exportedAt: Date
    let selectedTabId: UUID?
    let tabs: [NoteTab]
    /// Formatted versions of clipboard entries (added in 1.3; absent in older backups).
    var clipboardRichText: [ClipboardRichTextEntry]? = nil
}

struct ClipboardRichTextEntry: Codable {
    let itemId: UUID
    let format: ClipboardRichTextStore.Format
    let data: Data
}
