//
//  TabButton.swift
//  xNotes
//

import SwiftUI

struct TabButton: View {
    @ObservedObject var notesManager: NotesManager
    @ObservedObject var tab: NoteTab
    let index: Int
    let isSelected: Bool
    let onSelect: () -> Void
    let onClose: (() -> Void)?
    let onEditTitle: (String?) -> Void
    let onEditColor: (Double) -> Void
    let onToggleLock: (Bool) -> Void

    @State private var isHovered = false
    @State private var isEditingTitle = false
    @State private var editedTitle: String = ""
    @State private var showColorPicker = false
    @State private var showCloseConfirmation = false

    let colorPalette: [Double] = [0.0, 0.06, 0.12, 0.17, 0.33, 0.5, 0.6, 0.7, 0.8, 0.9]

    var body: some View {
        HStack(spacing: 4) {
            if isSelected, let onClose = onClose {
                Button(action: { showCloseConfirmation = true }) {
                    Image(systemName: "xmark")
                        .font(.system(size: 8))
                        .foregroundColor(.secondary)
                }
                .frame(width: 12, height: 12)
                .buttonStyle(.plain)
                .focusable(false)
                .alert("Close this tab?", isPresented: $showCloseConfirmation) {
                    Button("Cancel", role: .cancel) {}
                    Button("Close", role: .destructive) {
                        onClose()
                    }
                }
            }

            Circle()
                .fill(Color(hue: tab.color, saturation: 0.99, brightness: 0.99))
                .frame(width: 8, height: 8)

            if isEditingTitle {
                TextField("Tab", text: $editedTitle, onCommit: {
                    onEditTitle(editedTitle.isEmpty ? nil : editedTitle)
                    isEditingTitle = false
                })
                .frame(width: 70)
            } else {
                Text(displayTitle)
                    .multilineTextAlignment(.center)
                    .lineLimit(1)
                    .font(.system(size: 12, weight: .regular))
                    .foregroundColor(isSelected ? .primary : .secondary)
                    .onTapGesture(count: 2) {
                        guard tab.kind != .clipboard else { return }
                        editedTitle = tab.title ?? ""
                        isEditingTitle = true
                    }
            }

            Spacer()

            if isSelected {
                Button(action: { onToggleLock(!tab.isLocked) }) {
                    Image(systemName: tab.isLocked ? "lock.fill" : "lock.open")
                        .font(.system(size: 8))
                        .foregroundColor(.secondary)
                }
                .frame(width: 12, height: 12)
                .buttonStyle(.plain)
                .focusable(false)
                .help(tab.isLocked ? "Unlock tab" : "Lock tab")
            }

            if isSelected && tab.kind != .clipboard {
                Button(action: { showColorPicker.toggle() }) {
                    Image(systemName: "paintpalette")
                        .font(.system(size: 8))
                        .foregroundColor(.secondary)
                }
                .frame(width: 12, height: 12)
                .buttonStyle(.plain)
                .focusable(false)
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
                                        Circle().stroke(hue == tab.color ? Color.black : Color.clear, lineWidth: hue == tab.color ? 3 : 0)
                                    )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(12)
                }
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(
                    isSelected
                    ? AnyShapeStyle(Color(NSColor.windowBackgroundColor))
                    : AnyShapeStyle(Color(red: 0.937, green: 0.937, blue: 0.937))
                )
                .shadow(color: isSelected ? .gray : .clear, radius: isSelected ? 2 : 0, x: 0, y: isSelected ? 2 : 0)
        )
        .onHover { hovering in
            isHovered = hovering
        }
        .onTapGesture {
            onSelect()
        }
    }

    private var displayTitle: String {
        if tab.kind == .clipboard {
            return "Clipboard"
        }
        if let title = tab.title, !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return title
        }
        let lines = tab.content.components(separatedBy: .newlines)
        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmed.isEmpty {
                return trimmed
            }
        }
        return "Tab \(index + 1)"
    }
}
