//
//  NotesView.swift
//  xNotes
//

import SwiftUI

struct NotesView: View {
    @EnvironmentObject var notesManager: NotesManager
    @EnvironmentObject var textExpansionStore: TextExpansionStore
    @State private var isSearchVisible = false
    @State private var searchQuery = ""
    @State private var searchCursor = 0

    @AppStorage("keepWindowOpen") private var keepWindowOpen: Bool = false

    private enum Page: Int, CaseIterable {
        case main
        case settings
    }
    @State private var page: Page = .main
    
    var body: some View {
        ZStack {
            if page == .main {
                
                VStack(spacing: 0) {
                    TabBarView()
                    
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
                        SelectedTabContentView(tab: tab)
                    }
                    
                    Divider().frame(height: 1).background(.windowBackground)
                    footerButtons
                        .padding(12)
                }
//                .frame(width: 600, height: 500)
                .transition(.move(edge: .top).combined(with: .opacity))
                .background(.windowBackground)
                .background(ShortcutTabMonitor())
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
            
            if page == .settings {
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Image(systemName: "note.text")
                            .font(.system(size: 16, weight: .semibold))
                        Text("xNotes - Settings")
                            .font(.system(size: 13, weight: .semibold))
                        Spacer()
                    }
                    SettingsView()
                    Divider()
                    footerButtons
                }
                .padding(12)
//                .frame(width: 260)
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .animation(.easeInOut(duration: 0.6), value: page)
    }

    private var footerButtons: some View {
        HStack {
//            SettingsLink {
//                Image(systemName: "gear")
//                    .font(.system(size: 12))
//            }
            if (page == .settings) {
                Button(action: {
                    goToPreviousPage()
                }) {
                    Image(systemName: "chevron.backward.circle")
                        .font(.system(size: 12))
                }
            } else {
                
                Button(action: {
                    goToNextPage()
                }) {
                    Image(systemName: "gear")
                        .font(.system(size: 12))
                }
            }
            
            Button(action: {
                keepWindowOpen.toggle()
            }) {
                Image(systemName: keepWindowOpen ? "pin.fill" : "pin")
                    .foregroundColor(keepWindowOpen ? .accentColor : .secondary)
                    .font(.system(size: 11))
            }
            .help(keepWindowOpen ? "Window stays on top" : "Normal window behavior")
            
            Spacer()
            Button(action: { NSApp.terminate(nil) }) {
                Image(systemName: "power")
                    .font(.system(size: 12))
            }
            .foregroundColor(.secondary)
            .help(NSLocalizedString("QuitMenuTitle", comment: ""))
        }
        .font(.caption)
    }
    
    private func goToPreviousPage() {
        guard let previous = Page(rawValue: page.rawValue - 1) else { return }
        withAnimation(.easeInOut(duration: 0.2)) {
            page = previous
        }
    }

    private func goToNextPage() {
        guard let next = Page(rawValue: page.rawValue + 1) else { return }
        withAnimation(.easeInOut(duration: 0.2)) {
            page = next
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
