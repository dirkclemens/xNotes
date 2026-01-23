//  xNotes
//
//  Created by Dirk Clemens on 15.01.26
//

import SwiftUI
import AppKit
import UniformTypeIdentifiers

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
    @AppStorage("keepWindowOpen") private var keepWindowOpen: Bool = false
    var body: some View {
        HStack(spacing: 0) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 2) {
                    ForEach(Array(notesManager.tabs.enumerated()), id: \.element.id) { index, tab in
                        TabButton(
                            tab: tab,
                            index: index,
                            isSelected: notesManager.selectedTabId == tab.id,
                            onSelect: { notesManager.selectedTabId = tab.id },
                            onClose: notesManager.tabs.count > 1 ? { notesManager.removeTab(tab) } : nil,
                            onEditTitle: { (newTitle: String?) in notesManager.updateTitle(for: tab.id, title: newTitle) },
                            onEditColor: { newColor in notesManager.updateColor(for: tab.id, color: newColor) }
                        )
                    }
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
            }
            Button(action: { notesManager.addTab() }) {
                Image(systemName: "plus")
                    .font(.system(size: 11))
                    .frame(width: 16, height: 16)
            }
            .cornerRadius(16)
            .buttonStyle(.glass) //.glassProminent)
            .padding(.trailing, 8)
            Button(action: { keepWindowOpen.toggle() }) {
                Image(systemName: keepWindowOpen ? "pin.fill" : "pin")
                    .font(.system(size: 13))
                    .frame(width: 16, height: 16)
                    .foregroundColor(keepWindowOpen ? .accentColor : .secondary)
            }
            .help(keepWindowOpen ? "Fenster bleibt immer sichtbar" : "Fenster schließt bei Fokusverlust")
            .cornerRadius(16)
            .buttonStyle(.glass)
            .padding(.trailing, 8)
        }
        .padding(4)
        .background(Color(NSColor.windowBackgroundColor))
//        .background(Color(.gray.opacity(0.9)))
    }
}

struct TabButton: View {
    let tab: NoteTab
    let index: Int
    let isSelected: Bool
    let onSelect: () -> Void
    let onClose: (() -> Void)?
    let onEditTitle: (String?) -> Void
    let onEditColor: (Double) -> Void
    @State private var isHovered = false
    @State private var isEditingTitle = false
    @State private var editedTitle: String = ""
    @State private var showColorPicker = false
    @State private var showCloseConfirmation = false
    // Palette mit 10 Hue-Werten
    let colorPalette: [Double] = [0.0, 0.06, 0.12, 0.17, 0.33, 0.5, 0.6, 0.7, 0.8, 0.9]
    var body: some View {
        HStack(spacing: 4) {
            Button(action: { showColorPicker.toggle() }) {
                Image(systemName: "paintpalette")
                    .font(.system(size: 10))
            }
            .buttonStyle(.plain)
            .popover(isPresented: $showColorPicker) {
                HStack(spacing: 8) {
                    ForEach(colorPalette, id: \ .self) { hue in
                        Button(action: {
                            onEditColor(hue)
                            showColorPicker = false
                        }) {
                            Circle()
                                .fill(Color(hue: hue, saturation: 0.99, brightness: 0.99))
                                .frame(width: 28, height: 28)
                                .overlay(
                                    Circle()
                                        .stroke(hue == tab.color ? Color.black : Color.clear, lineWidth: hue == tab.color ? 3 : 0)
                                )
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(12)
            }
            if isEditingTitle {
                TextField("Tab", text: $editedTitle, onCommit: {
                    onEditTitle(editedTitle.isEmpty ? nil : editedTitle)
                    isEditingTitle = false
                })
                .frame(width: 70)
            } else {
                Text(tab.title ?? "Tab \(index + 1)")
                    .lineLimit(1)
                    .font(isSelected ? .system(size: 12, weight: .bold) : .system(size: 12, weight: .regular))
                    .onTapGesture(count: 2) {
                        editedTitle = tab.title ?? "Tab \(index + 1)"
                        isEditingTitle = true
                    }
            }
            if let onClose = onClose {
                Button(action: { showCloseConfirmation = true }) {
                    Image(systemName: "xmark")
                        .font(.system(size: 8))
                        .foregroundColor(.secondary)
                }
                .padding(.leading, 3)
                .padding(.trailing, -4)
                .buttonStyle(.glassProminent)
                .opacity(isHovered ? 1 : 0)
                .alert("Tab wirklich schließen?", isPresented: $showCloseConfirmation) {
                    Button("Abbrechen", role: .cancel) {}
                    Button("Schließen", role: .destructive) {
                        onClose()
                    }
                }
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(Color(hue: tab.color, saturation: 0.8, brightness: 0.9))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(isSelected ? Color.black : Color.clear, lineWidth: isSelected ? 4 : 0)
        )
        .cornerRadius(12)
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
    @State private var localContent: String = ""
    
    var body: some View {
        TextEditor(text: $localContent)
            .font(.system(size: 14))
            .padding(1)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .onAppear { localContent = content }
            .onChange(of: localContent) { _, newValue in content = newValue }
    }
}
