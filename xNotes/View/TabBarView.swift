//
//  TabBarView.swift
//  xNotes
//

import SwiftUI

struct TabBarView: View {
    @EnvironmentObject var notesManager: NotesManager
    
    var body: some View {
        HStack(spacing: 0) {
            ScrollView(.horizontal, showsIndicators: true) {
                LazyHStack(spacing: 2) {
                    ForEach(Array(notesManager.tabs.enumerated()), id: \.element.id) { index, tab in
                        TabButton(
                            tab: tab,
                            index: index,
                            isSelected: notesManager.selectedTabId == tab.id,
                            onSelect: { notesManager.selectedTabId = tab.id },
                            onClose: (notesManager.tabs.count > 1 && !tab.isLocked) ? { notesManager.removeTab(tab) } : nil,
                            onEditTitle: { newTitle in notesManager.updateTitle(for: tab.id, title: newTitle) },
                            onEditColor: { newColor in notesManager.updateColor(for: tab.id, color: newColor) },
                            onToggleLock: { isLocked in notesManager.updateLocked(for: tab.id, isLocked: isLocked) }
                        )
                        .padding(1)
                    }
                }
            }
            .scrollClipDisabled(false)
            .frame(maxWidth: .infinity, alignment: .leading)
            .layoutPriority(1)
            .background(Color(red: 0.937, green: 0.937, blue: 0.937))
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .clipped()
            
            Button(action: { notesManager.addTab() }) {
                Image(systemName: "plus")
                    .padding(6)
                    .background(.windowBackground)
                    .clipShape(Circle())
                    .shadow(color: Color.black.opacity(0.12), radius: 2, x: 0, y: 1)
            }
            .buttonStyle(.plain)
            .padding(.leading, 6)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(Color.clear)
        .frame(height: 36)
    }
}
