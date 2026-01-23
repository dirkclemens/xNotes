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
    
    func colorForTab(tab: NoteTab) -> Color {
        Color(hue: tab.color, saturation: 0.8, brightness: 0.9)
    }
    
    var body: some View {
        HStack(spacing: 0) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 2) {
                    ForEach(Array(notesManager.tabs.enumerated()), id: \.element.id) { index, tab in
                        TabButton(
                            title: tab.title ?? "Tab \(index + 1)",
                            isSelected: notesManager.selectedTabId == tab.id,
                            backgroundColor: colorForTab(tab: tab),
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
            .buttonStyle(.glassProminent)
            .padding(.trailing, 8)
        }
        .padding(4)
        .background(Color(NSColor.windowBackgroundColor))
//        .background(Color(.gray.opacity(0.9)))
    }
}

struct TabButton: View {
    let title: String
    let isSelected: Bool
    let backgroundColor: Color
    let onSelect: () -> Void
    let onClose: (() -> Void)?
    let onEditTitle: (String?) -> Void
    let onEditColor: (Double) -> Void
    @State private var isHovered = false
    @State private var isEditingTitle = false
    @State private var editedTitle: String = ""
    @State private var showColorPicker = false
    var body: some View {
        HStack(spacing: 4) {

            Button(action: { showColorPicker.toggle() }) {
                Image(systemName: "paintpalette")
                    .font(.system(size: 10))
            }
            .buttonStyle(.plain)
            .popover(isPresented: $showColorPicker) {
                ColorPicker(
                    "Farbe wählen",
                    selection: Binding(
                        get: {
                            var hue: CGFloat = 0; var s: CGFloat = 0; var b: CGFloat = 0; var a: CGFloat = 0
                            NSColor(backgroundColor).usingColorSpace(.deviceRGB)?.getHue(&hue, saturation: &s, brightness: &b, alpha: &a)
                            return Color(hue: Double(hue), saturation: 1, brightness: 1)
                        },
                        set: { newColor in
                            // Convert SwiftUI Color to NSColor and extract hue
                            if let nsColor = NSColor(newColor).usingColorSpace(.deviceRGB) {
                                var hue: CGFloat = 0
                                var sat: CGFloat = 0
                                var bri: CGFloat = 0
                                var alpha: CGFloat = 0
                                nsColor.getHue(&hue, saturation: &sat, brightness: &bri, alpha: &alpha)
                                onEditColor(Double(hue))
                            }
                        }
                    ),
                    supportsOpacity: false
                )
                .frame(width: 180)
                .padding()
            }

            if isEditingTitle {
                TextField("Tab", text: $editedTitle, onCommit: {
                    onEditTitle(editedTitle.isEmpty ? nil : editedTitle)
                    isEditingTitle = false
                })
                .frame(width: 70)
            } else {
                Text(title)
                    .lineLimit(1)
                    .onTapGesture(count: 2) {
                        editedTitle = title
                        isEditingTitle = true
                    }
            }

            if let onClose = onClose {
                Button(action: onClose) {
                    Image(systemName: "xmark")
                        .font(.system(size: 8))
                        .foregroundColor(.secondary)
                }
                //.frame(width: 10, height: 10)
                .padding(.leading, 3)
                .padding(.trailing, -4)
                .buttonStyle(.glassProminent)
                .opacity(isHovered ? 1 : 0)
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(backgroundColor)
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
