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
}
