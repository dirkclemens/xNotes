//
//  EditClipboardItemView.swift
//  xNotes
//

import SwiftUI

struct EditClipboardItemView: View {
    let item: ClipboardItem
    @EnvironmentObject var notesManager: NotesManager
    @Environment(\.dismiss) private var dismiss

    @State private var draft: String
    @FocusState private var isFocused: Bool

    init(item: ClipboardItem) {
        self.item = item
        self._draft = State(initialValue: item.text)
    }

    var body: some View {
        VStack(spacing: 12) {
            TextEditor(text: $draft)
                .font(.system(.body, design: .monospaced))
                .focused($isFocused)
                .frame(minHeight: 120)
                .textSelection(.enabled)
                .overlay(
                    RoundedRectangle(cornerRadius: 4)
                        .stroke(Color.secondary.opacity(0.3), lineWidth: 1)
                )
            HStack {
                Spacer()
                Button("Cancel") {
                    dismiss()
                }
                .keyboardShortcut(.cancelAction)
                Button("Save") {
                    notesManager.editClipboardItem(id: item.id, with: draft)
                    dismiss()
                }
                .keyboardShortcut(.defaultAction)
                .disabled(!canSave)
            }
        }
        .padding()
        .frame(width: 420, height: 200)
        .onAppear {
            isFocused = true
        }
    }

    private var canSave: Bool {
        !draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
}

