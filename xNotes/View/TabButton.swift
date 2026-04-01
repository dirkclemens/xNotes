//
//  TabButton.swift
//  xNotes
//

import SwiftUI

struct TabButton: View {
    @ObservedObject var tab: NoteTab
    @EnvironmentObject var notesManager: NotesManager
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

    let buttonSize: CGFloat = 12
    
    let colorPalette: [Double] = [
        0.0, 0.05, 0.10, 0.15, 0.20, 0.25, 0.30, 0.35, 0.40, 0.45,
        0.50, 0.55, 0.60, 0.65, 0.70, 0.75, 0.80, 0.85, 0.90, 0.95, 1.0
    ]

    let rainbowColors = [ Color.yellow, Color.orange, Color.red,  Color.purple, Color.blue, Color.green ]
    let grayscaleColors = [ Color.white, Color.gray, Color.black ]
    
    let adaptiveColumn = [
        GridItem(.adaptive(minimum: 12))
    ]
    let rows = [
        GridItem(.fixed(10)),
        GridItem(.fixed(10))
    ]
    
    var body: some View {
        HStack(spacing: 4) {
            if isSelected, let onClose = onClose {
                Button(action: { showCloseConfirmation = true }) {
                    Image(systemName: "xmark")
                        .font(.system(size: 8))
                        .foregroundColor(.secondary)
                }
                .frame(width: buttonSize, height: buttonSize)
                .buttonStyle(.plain)
                .focusable(false)
                .alert("Close this tab?", isPresented: $showCloseConfirmation) {
                    Button("Cancel", role: .cancel) {}
                    Button("Close", role: .destructive) {
                        onClose()
                    }
                }
            }

            if tab.kind != .clipboard && tab.kind != .expansions {
                let circleColor = tab.isLocked ? rainbowColors : grayscaleColors
                let timeLeftDegree = notesManager.autoDeleteRotationDegrees(for: tab)
                
                Circle()
                    .fill(Color(hue: tab.color, saturation: 0.99, brightness: 0.99))
                    .background(
                        Circle()
                            .stroke(.white, lineWidth: 2)
                            .background(
                                Circle()
                                    .stroke(LinearGradient(colors: circleColor, startPoint: .topLeading, endPoint: .bottomTrailing), lineWidth: 8)
                                    .rotationEffect(.degrees(timeLeftDegree))
                            )
                    )
                    .frame(width: 10, height: 10)
                    .padding(.trailing, 4)
            }
            
            if isEditingTitle {
                TextField("Tab", text: $editedTitle, onCommit: {
                    onEditTitle(editedTitle.isEmpty ? nil : editedTitle)
                    isEditingTitle = false
                })
                .frame(width: 70)
            } else {
                if tab.kind == .clipboard {
                    Image(systemName: "list.clipboard")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(isSelected ? .red : .secondary)
                        .help("Clipboard")
                        .accessibilityLabel("Clipboard")
                        .frame(width: 40, height: 16)
                } else if tab.kind == .expansions {
                    Image(systemName: "text.badge.checkmark")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(isSelected ? .blue : .secondary)
                        .help("Text Expansions")
                        .accessibilityLabel("Text Expansions")
                        .frame(width: 40, height: 16)
                } else {
                    Text(displayTitle)
                        .multilineTextAlignment(.center)
                        .lineLimit(1)
                        .font(.system(size: 12, weight: .regular))
                        .foregroundColor(isSelected ? .primary : .secondary)
                        .onTapGesture(count: 2) {
                            guard tab.kind == .note else { return }
                            editedTitle = tab.title ?? ""
                            isEditingTitle = true
                        }
                        .frame(height: 16)
                }
            }

//            Spacer(minLength: 6)

            if isSelected && tab.kind == .note {
                Button(action: { onToggleLock(!tab.isLocked) }) {
                    Image(systemName: tab.isLocked ? "lock.fill" : "lock.open")
                        .font(.system(size: 8))
                        .foregroundColor(.secondary)
                }
                .frame(width: buttonSize, height: buttonSize)
                .buttonStyle(.plain)
                .focusable(false)
                .help(tab.isLocked ? "Unlock tab" : "Lock tab")
            }

            if isSelected && tab.kind == .note {
                Button(action: { showColorPicker.toggle() }) {
                    Image(systemName: "paintpalette")
                        .font(.system(size: 8))
                        .foregroundColor(.secondary)
                }
                .frame(width: buttonSize, height: buttonSize)
                .buttonStyle(.plain)
                .focusable(false)
                .popover(isPresented: $showColorPicker) {
                    HStack(spacing: 2) {
                        ForEach(colorPalette, id: \.self) { hue in
                            Button(action: {
                                onEditColor(hue)
                                showColorPicker = false
                            }) {
                                Circle()
                                    .fill(Color(hue: hue, saturation: 0.99, brightness: 0.99))
                                    .frame(width: 18, height: 18)
                                    .overlay(
                                        Circle().stroke(hue == tab.color ? Color.black : Color.clear, lineWidth: hue == tab.color ? 3 : 0)
                                    )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(8)
                }
            }
        }
        .fixedSize(horizontal: true, vertical: false)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(
            RoundedRectangle(cornerRadius: buttonSize)
                .fill(
                    isSelected
                    ? AnyShapeStyle(Color(NSColor.windowBackgroundColor))
                    : AnyShapeStyle(Color(red: 0.937, green: 0.937, blue: 0.937))
                )
                .shadow(color: isSelected ? .gray : .clear, radius: isSelected ? 2 : 0, x: 0, y: isSelected ? 2 : 0)
        )
        .contentShape(Rectangle())
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
        if tab.kind == .expansions {
            return "Text Expansions"
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
