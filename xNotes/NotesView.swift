//
//  Created by Dirk Clemens on 15.01.26
//

import SwiftUI
import AppKit
import UniformTypeIdentifiers
import Combine

struct NotesView: View {
    @ObservedObject var notesManager: NotesManager
    
    var body: some View {
        VStack(spacing: 0) {
            TabBarView(notesManager: notesManager)
            
            Divider().frame(height: 1).background(.windowBackground)
            
            if let selectedId = notesManager.selectedTabId,
               let tab = notesManager.tabs.first(where: { $0.id == selectedId }) {
                TextEditorView(
                    content: Binding(
                        get: { tab.content },
                        set: { notesManager.updateContent(for: selectedId, content: $0) }
                    )
                )
            }

//            Divider().frame(height: 1).background(.windowBackground)
//            Spacer().frame(height: 20)
        }
        .frame(width: 600, height: 400)
        .background(.windowBackground)
    }
}

struct TabBarView: View {
    @ObservedObject var notesManager: NotesManager
    @AppStorage("keepWindowOpen") private var keepWindowOpen: Bool = false
    let buttonSize: CGFloat = 18
    
    var body: some View {
        HStack(spacing: 0) {
            ScrollView(.horizontal, showsIndicators: true) {
                HStack(spacing: 2) {
                    ForEach(Array(notesManager.tabs.enumerated()), id: \.element.id) { index, tab in
                        TabButton(
                            notesManager: notesManager,
                            tab: tab,
                            index: index,
                            isSelected: notesManager.selectedTabId == tab.id,
                            onSelect: { notesManager.selectedTabId = tab.id },
                            onClose: notesManager.tabs.count > 1 ? { notesManager.removeTab(tab) } : nil,
                            onEditTitle: { (newTitle: String?) in notesManager.updateTitle(for: tab.id, title: newTitle) },
                            onEditColor: { newColor in notesManager.updateColor(for: tab.id, color: newColor) }
                        )
                        .padding(1)
                    }
                }
            }
            .background(Color(red: 0.937, green: 0.937, blue: 0.937))
//            .background(.regularMaterial)
//            .background(.ultraThickMaterial)
            .cornerRadius(16)
                        
            // Add Tab Button
            Button(action: { notesManager.addTab() }) {
                Image(systemName: "plus")
                    .font(.system(size: 11))
                    .frame(width: buttonSize, height: buttonSize)
            }
            .cornerRadius(16)
            
            // Keep Window Open Toggle
            Button(action: { keepWindowOpen.toggle() }) {
                Image(systemName: keepWindowOpen ? "pin.fill" : "pin")
                    .font(.system(size: 13))
                    .frame(width: buttonSize, height: buttonSize)
                    .foregroundColor(keepWindowOpen ? .accentColor : .secondary)
            }
            .help(keepWindowOpen ? "Fenster bleibt immer sichtbar" : "Fenster schließt bei Fokusverlust")
            .cornerRadius(16)
        }
        .padding(10)
        .background(.windowBackground)
    }
}

struct TabButton: View {
    @ObservedObject var notesManager: NotesManager
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
            // Close Button
            if let onClose = onClose {
                Button(action: { showCloseConfirmation = true }) {
                    Image(systemName: "xmark")
                        .font(.system(size: 8))
                        .foregroundColor(.secondary)
                }
                .frame(width: 12, height: 12)
                .buttonStyle(.plain)
                .opacity(isSelected ? 1.0 : 0.0)
                .alert("Tab wirklich schließen?", isPresented: $showCloseConfirmation) {
                    Button("Abbrechen", role: .cancel) {}
                    Button("Schließen", role: .destructive) {
                        onClose()
                    }
                }
            }
            
            Spacer().frame(width: onClose != nil ? 0 : 12)
            
            // Color Indicator
            Circle()
                .fill(Color(hue: tab.color, saturation: 0.99, brightness: 0.99))
                .frame(width: 8, height: 8)
            
            // Title (editable)
            if isEditingTitle {
                TextField("Tab", text: $editedTitle, onCommit: {
                    onEditTitle(editedTitle.isEmpty ? nil : editedTitle)
                    isEditingTitle = false
                })
                .frame(width: 70)
            } else {
                Text(tab.title ?? "Tab \(index + 1)")
                    .multilineTextAlignment(.center)
                    .lineLimit(1)
                    .font(.system(size: 12, weight: .regular))
                    .foregroundColor(isSelected ? .primary : .secondary)
                    .onTapGesture(count: 2) {
                        editedTitle = tab.title ?? "Tab \(index + 1)"
                        isEditingTitle = true
                    }
            }
            
            Spacer()
            
            // Color Picker Button
            Button(action: { showColorPicker.toggle() }) {
                Image(systemName: "paintpalette")
                    .font(.system(size: 8))
                    .foregroundColor(.secondary)
            }
            .frame(width: 12, height: 12)
            .buttonStyle(.plain)
            .opacity(isSelected ? 1.0 : 0.0)
            .popover(isPresented: $showColorPicker) {
                HStack(spacing: 8) {
                    ForEach(colorPalette, id: \.self) { hue in
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
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(isSelected ? AnyShapeStyle(Color(NSColor.windowBackgroundColor)) :
                        AnyShapeStyle(Color(red: 0.937, green: 0.937, blue: 0.937)))//AnyShapeStyle(.regularMaterial))
                .shadow(color: isSelected ? .gray : .clear, radius: isSelected ? 2 : 0, x: 0, y: isSelected ? 2 : 0)
        )
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
    @FocusState private var isFocused: Bool
    
    @AppStorage("editorFontName") private var editorFontName: String = "SF Mono"
    @AppStorage("editorFontSize") private var editorFontSize: Double = 14
    
    var body: some View {
        TextEditor(text: $content)
            .focused($isFocused)
            .font(selectedEditorFont)
            .lineSpacing(2)
            .multilineTextAlignment(.leading)
            .padding(.horizontal, 4)
            .padding(.bottom, 10)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .onAppear { isFocused = true }
    }
    
    private var selectedEditorFont: Font {
        switch editorFontName {
        case "__system__":
            return .system(size: CGFloat(editorFontSize))
        case "__systemMonospaced__":
            return .system(size: CGFloat(editorFontSize), design: .monospaced)
        default:
            return .custom(editorFontName, size: CGFloat(editorFontSize))
        }
    }
}

