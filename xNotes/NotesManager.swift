//
//  NotesManager.swift
//  xNotes
//
//  Created by Dirk Clemens on 15.01.26.
//

import Foundation
import Combine

@MainActor
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
    
    func updateColor(for tabId: UUID, color: Double) {
        if let index = tabs.firstIndex(where: { $0.id == tabId }) {
            tabs[index].color = color
            saveWithDelay()
        }
    }
    
    func updateTitle(for tabId: UUID, title: String?) {
        if let index = tabs.firstIndex(where: { $0.id == tabId }) {
            tabs[index].title = title
            saveWithDelay()
        }
    }

    func updateLocked(for tabId: UUID, isLocked: Bool) {
        if let index = tabs.firstIndex(where: { $0.id == tabId }) {
            tabs[index].isLocked = isLocked
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
        let codableTabs = tabs.map { tab in
            NoteTab(id: tab.id, content: tab.content, color: tab.color, title: tab.title, isLocked: tab.isLocked)
        }
        if let encoded = try? JSONEncoder().encode(codableTabs) {
            UserDefaults.standard.set(encoded, forKey: storageKey)
        }
    }
    private func loadTabs() {
        if let data = UserDefaults.standard.data(forKey: storageKey),
           let decoded = try? JSONDecoder().decode([NoteTab].self, from: data) {
            tabs = decoded.map { NoteTab(id: $0.id, content: $0.content, color: $0.color, title: $0.title, isLocked: $0.isLocked) }
        }
    }
}
