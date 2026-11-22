//
//  NotesView.swift
//  xNotes
//

import SwiftUI

struct NotesView: View {
    @EnvironmentObject var notesManager: NotesManager
    @EnvironmentObject var textExpansionStore: TextExpansionStore
    @EnvironmentObject var windowSettings: WindowLevelStateSettings
    @State private var isSearchVisible = false
    @State private var searchQuery = ""
    @State private var searchCursor = 0
    /// Cached so the (potentially large) search isn't re-run on every view update.
    @State private var searchResults: [SearchResult] = []
    @State private var searchFocusRequest = 0
    @State private var activeSearchResult: SearchResult?
    /// Tab action waiting for the "Delete this tab?" confirmation.
    @State private var pendingConfirmation: TabConfirmation?

    private enum TabConfirmation {
        /// The user chose "Delete Tab…".
        case delete(NoteTab)
        /// The user unlocks a tab that is older than the auto-delete period,
        /// so auto-delete would remove it right away.
        case unlockExpired(NoteTab)

        var tab: NoteTab {
            switch self {
            case .delete(let tab), .unlockExpired(let tab): return tab
            }
        }
    }

    private var keepWindowOpen: Binding<Bool> { $windowSettings.keepWindowOpen }

    private enum Page: Int, CaseIterable {
        case main
        case settings
    }
    @State private var page: Page = .main
    
    var body: some View {
        ZStack {
            if page == .main {
                
                HStack(spacing: 0) {
                    SidebarView(
                        keepWindowOpen: keepWindowOpen,
                        onOpenSettings: goToNextPage,
                        onRequestClose: { pendingConfirmation = .delete($0) },
                        onRequestToggleLock: toggleLock
                    )

                    Divider()

                    VStack(spacing: 0) {
                        if let tab = selectedTab {
                            TabContextBar(
                                tab: tab,
                                onSearch: openSearch,
                                onRequestClose: { pendingConfirmation = .delete($0) },
                                onRequestToggleLock: toggleLock
                            )
                        }

                        if isSearchVisible {
                            SearchBarView(
                                query: $searchQuery,
                                resultCount: searchResults.count,
                                currentIndex: currentResultIndex,
                                currentTabTitle: activeSearchResult?.tabTitle,
                                focusRequest: searchFocusRequest,
                                onPrevious: { stepSearch(previous: true) },
                                onNext: { stepSearch(previous: false) },
                                onClose: closeSearch
                            )
                        }

                        Divider()

                        if let tab = selectedTab {
                            SelectedTabContentView(
                                tab: tab,
                                autoFocusEditor: !isSearchVisible,
                                searchHighlight: activeSearchResult?.tabId == tab.id ? activeSearchResult : nil
                            )
                            .id(tab.id)
                        } else {
                            Spacer()
                        }
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
                .alert("Delete this tab?", isPresented: Binding(
                    get: { pendingConfirmation != nil },
                    set: { if !$0 { pendingConfirmation = nil } }
                ), presenting: pendingConfirmation) { confirmation in
                    switch confirmation {
                    case .delete(let tab):
                        Button("Cancel", role: .cancel) {}
                        Button("Delete", role: .destructive) { notesManager.removeTab(tab) }
                    case .unlockExpired(let tab):
                        Button("Keep Locked", role: .cancel) {}
                        Button("Unlock and Keep") { notesManager.unlockRestartingAutoDelete(for: tab.id) }
                        Button("Delete", role: .destructive) { notesManager.removeTab(tab) }
                    }
                } message: { confirmation in
                    Text(confirmationMessage(for: confirmation))
                }

                .transition(.move(edge: .top).combined(with: .opacity))
                .background(.windowBackground)
                .background(ShortcutTabMonitor(isSearchVisible: isSearchVisible))
                .onChange(of: searchQuery) { _, _ in
                    searchCursor = 0
                    refreshSearchResults()
                    applyCurrentSearchResult()
                }
                .onReceive(NotificationCenter.default.publisher(for: ShortcutNotifications.closeSearch)) { _ in
                    closeSearch()
                }
                .onReceive(NotificationCenter.default.publisher(for: ShortcutNotifications.focusSearch)) { _ in
                    openSearch()
                }
                .onReceive(NotificationCenter.default.publisher(for: ShortcutNotifications.findNext)) { _ in
                    if !isSearchVisible {
                        openSearch()
                    } else {
                        stepSearch(previous: false)
                    }
                }
                .onReceive(NotificationCenter.default.publisher(for: ShortcutNotifications.findPrevious)) { _ in
                    if !isSearchVisible {
                        openSearch()
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
                .background(.windowBackground)
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .animation(.easeInOut(duration: 0.6), value: page)
    }

    private var footerButtons: some View {
        HStack {
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
                keepWindowOpen.wrappedValue.toggle()
            }) {
                Image(systemName: keepWindowOpen.wrappedValue ? "pin.fill" : "pin")
                    .foregroundColor(keepWindowOpen.wrappedValue ? .accentColor : .secondary)
                    .font(.system(size: 11))
            }
            .help(keepWindowOpen.wrappedValue ? "Window stays on top" : "Normal window behavior")
            
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
    
    /// Locks right away; unlocking asks first when auto-delete would remove the tab immediately.
    private func toggleLock(_ tab: NoteTab) {
        if tab.isLocked, notesManager.isPastAutoDeleteDeadline(tab) {
            pendingConfirmation = .unlockExpired(tab)
        } else {
            notesManager.updateLocked(for: tab.id, isLocked: !tab.isLocked)
        }
    }

    private func confirmationMessage(for confirmation: TabConfirmation) -> String {
        let title = notesManager.displayTitle(for: confirmation.tab)
        switch confirmation {
        case .delete:
            return "\"\(title)\" and its content will be deleted permanently. This cannot be undone."
        case .unlockExpired(let tab):
            let days = max(1, Int(Date().timeIntervalSince(tab.lastEditedAt) / (24 * 60 * 60)))
            return "\"\(title)\" was last edited \(days) days ago, longer than the auto-delete period of \(notesManager.autoDeleteDays()) days. Unlocking it deletes it and its content permanently. Choose \"Unlock and Keep\" to restart the countdown instead."
        }
    }

    private var selectedTab: NoteTab? {
        guard let selectedId = notesManager.selectedTabId else { return nil }
        return notesManager.tabs.first(where: { $0.id == selectedId })
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

    private func refreshSearchResults() {
        searchResults = notesManager.searchResults(for: searchQuery)
    }

    private var currentResultIndex: Int? {
        guard !searchResults.isEmpty else { return nil }
        let count = searchResults.count
        let normalized = ((searchCursor % count) + count) % count
        return normalized
    }

    private func stepSearch(previous: Bool) {
        // Re-run the search so edits made since the last step are taken into account.
        refreshSearchResults()
        guard !searchResults.isEmpty else { return }
        searchCursor += previous ? -1 : 1
        applyCurrentSearchResult()
    }

    private func applyCurrentSearchResult() {
        let results = searchResults
        guard !results.isEmpty else {
            activeSearchResult = nil
            return
        }
        let count = results.count
        let result = results[((searchCursor % count) + count) % count]
        activeSearchResult = result
        notesManager.selectedTabId = result.tabId
    }

    private func openSearch() {
        isSearchVisible = true
        // Re-focus the field even when the search bar is already visible.
        searchFocusRequest += 1
    }

    private func closeSearch() {
        isSearchVisible = false
        searchQuery = ""
        searchCursor = 0
        searchResults = []
        activeSearchResult = nil
    }
}
