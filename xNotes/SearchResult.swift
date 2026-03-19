//
//  SearchResult.swift
//  xNotes
//

import Foundation

struct SearchResult: Identifiable, Equatable {
    let id = UUID()
    let tabId: UUID
    let tabTitle: String
    let snippet: String
}
