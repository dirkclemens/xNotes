//
//  NotesView.swift
//  xNotes
//

import SwiftUI

struct NotesView: View {
    @ObservedObject var notesManager: NotesManager
    @State private var isSearchVisible = false
    @State private var searchQuery = ""
    @State private var searchCursor = 0

    var body: some View {
        VStack(spacing: 0) {
            TabBarView(notesManager: notesManager)

            if isSearchVisible {
                SearchBarView(
                    query: $searchQuery,
                    resultCount: searchResults.count,
                    currentIndex: currentResultIndex,
                    onPrevious: { stepSearch(previous: true) },
                    onNext: { stepSearch(previous: false) },
                    onClose: closeSearch
                )
            }

            Divider().frame(height: 1).background(.windowBackground)

            if let selectedId = notesManager.selectedTabId,
               let tab = notesManager.tabs.first(where: { $0.id == selectedId }) {
                SelectedTabContentView(tab: tab, notesManager: notesManager)
            }
        }
        .frame(width: 600, height: 400)
        .background(.windowBackground)
        .background(ShortcutTabMonitor(notesManager: notesManager))
        .onChange(of: searchQuery) { _, _ in
            searchCursor = 0
            applyCurrentSearchResult()
        }
        .onReceive(NotificationCenter.default.publisher(for: ShortcutNotifications.focusSearch)) { _ in
            isSearchVisible = true
        }
        .onReceive(NotificationCenter.default.publisher(for: ShortcutNotifications.findNext)) { _ in
            if !isSearchVisible {
                isSearchVisible = true
            } else {
                stepSearch(previous: false)
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: ShortcutNotifications.findPrevious)) { _ in
            if !isSearchVisible {
                isSearchVisible = true
            } else {
                stepSearch(previous: true)
            }
        }
    }

    private var searchResults: [SearchResult] {
        notesManager.searchResults(for: searchQuery)
    }

    private var currentResultIndex: Int? {
        guard !searchResults.isEmpty else { return nil }
        let count = searchResults.count
        let normalized = ((searchCursor % count) + count) % count
        return normalized
    }

    private func stepSearch(previous: Bool) {
        guard !searchResults.isEmpty else { return }
        searchCursor += previous ? -1 : 1
        applyCurrentSearchResult()
    }

    private func applyCurrentSearchResult() {
        guard let idx = currentResultIndex else { return }
        notesManager.selectedTabId = searchResults[idx].tabId
    }

    private func closeSearch() {
        isSearchVisible = false
        searchQuery = ""
        searchCursor = 0
    }
}
