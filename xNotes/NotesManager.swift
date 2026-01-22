//
//  NotesManager.swift
//  xNotes
//
//  Created by Dirk Clemens on 15.01.26.
//

import Foundation
import Combine

class NotesManager: ObservableObject {
    @Published var tabs: [NoteTab] = []
    @Published var selectedTabId: UUID?
    
    private var saveTask: Task<Void, Never>?
    private let saveDelay: TimeInterval = 1.0
    private let storageKey = "savedNotes"
    
    init() {
        loadTabs()
        if tabs.isEmpty {
            tabs = [NoteTab()]
        }
        selectedTabId = tabs.first?.id
    }
    
    func addTab() {
        let newTab = NoteTab()
        tabs.append(newTab)
        selectedTabId = newTab.id
        saveWithDelay()
    }
    
    func removeTab(_ tab: NoteTab) {
        guard tabs.count > 1 else { return }
        
        if let index = tabs.firstIndex(where: { $0.id == tab.id }) {
            tabs.remove(at: index)
            if selectedTabId == tab.id {
                selectedTabId = tabs.first?.id
            }
            saveWithDelay()
        }
    }
    
    func updateContent(for tabId: UUID, content: String) {
        if let index = tabs.firstIndex(where: { $0.id == tabId }) {
            tabs[index].content = content
            saveWithDelay()
        }
    }
    
    private func saveWithDelay() {
        saveTask?.cancel()
        saveTask = Task {
            try? await Task.sleep(nanoseconds: UInt64(saveDelay * 1_000_000_000))
            guard !Task.isCancelled else { return }
            await MainActor.run {
                self.saveTabs()
            }
        }
    }
    
    private func saveTabs() {
        if let encoded = try? JSONEncoder().encode(tabs) {
            UserDefaults.standard.set(encoded, forKey: storageKey)
        }
    }
    
    private func loadTabs() {
        if let data = UserDefaults.standard.data(forKey: storageKey),
           let decoded = try? JSONDecoder().decode([NoteTab].self, from: data) {
            tabs = decoded
        }
    }
}
