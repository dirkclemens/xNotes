//
//  SearchResult.swift
//  xNotes
//

import Foundation

struct SearchResult: Identifiable, Equatable {
    let id = UUID()
    let tabId: UUID
    let tabTitle: String
    /// Set when the match is inside a clipboard history item.
    let clipboardItemId: UUID?
    /// Range of the match inside the note content (UTF-16 based, for NSTextView).
    /// `nil` for title-only matches and clipboard matches.
    let range: NSRange?
}
