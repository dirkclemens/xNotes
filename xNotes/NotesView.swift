//
//  NotesView.swift
//  xNotes
//
//  Created by Dirk Clemens on 15.01.26.
//

import SwiftUI

struct NotesView: View {
    @ObservedObject var notesManager: NotesManager
    
    var body: some View {
        VStack(spacing: 0) {
            TabBarView(notesManager: notesManager)
            
            if let selectedId = notesManager.selectedTabId,
               let tab = notesManager.tabs.first(where: { $0.id == selectedId }) {
                TextEditorView(
                    content: Binding(
                        get: { tab.content },
                        set: { notesManager.updateContent(for: selectedId, content: $0) }
                    )
                )
            }
        }
        .frame(width: 600, height: 400)
    }
}

struct TabBarView: View {
    @ObservedObject var notesManager: NotesManager
    
    var body: some View {
        HStack(spacing: 0) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 2) {
                    ForEach(Array(notesManager.tabs.enumerated()), id: \.element.id) { index, tab in
                        TabButton(
                            title: "Tab \(index + 1)",
                            isSelected: notesManager.selectedTabId == tab.id,
                            onSelect: { notesManager.selectedTabId = tab.id },
                            onClose: notesManager.tabs.count > 1 ? { notesManager.removeTab(tab) } : nil
                        )
                    }
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
            }
            
            Button(action: { notesManager.addTab() }) {
                Image(systemName: "plus")
                    .font(.system(size: 11))
                    .frame(width: 20, height: 20)
            }
            .buttonStyle(.plain)
            .padding(.trailing, 8)
        }
        .background(Color(NSColor.controlBackgroundColor))
    }
}

struct TabButton: View {
    let title: String
    let isSelected: Bool
    let onSelect: () -> Void
    let onClose: (() -> Void)?
    
    @State private var isHovered = false
    
    var body: some View {
        HStack(spacing: 4) {
            Text(title)
                .font(.system(size: 11))
                .lineLimit(1)
            
            if let onClose = onClose {
                Button(action: onClose) {
                    Image(systemName: "xmark")
                        .font(.system(size: 8))
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
                .opacity(isHovered ? 1 : 0)
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(isSelected ? Color(NSColor.selectedContentBackgroundColor) : Color.clear)
        .cornerRadius(4)
        .onHover { hovering in
            isHovered = hovering
        }
        .onTapGesture {
            onSelect()
        }
    }
}

struct TextEditorView: View {
    @Binding var content: String
    
    var body: some View {
        TextEditor(text: $content)
            .font(.system(size: 13))
            .padding(8)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
