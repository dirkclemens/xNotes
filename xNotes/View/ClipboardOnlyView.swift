//
//  ClipboardOnlyView.swift
//  xNotes
//

import SwiftUI

struct ClipboardOnlyView: View {
    @EnvironmentObject var notesManager: NotesManager
    @State private var filter = ""
    @FocusState private var isFilterFocused: Bool

    var body: some View {
        if let tab = notesManager.tabs.first(where: { $0.kind == .clipboard }) {
            ClipboardOnlyContent(tab: tab, filter: $filter, isFilterFocused: $isFilterFocused)
        } else {
            Text("No clipboard tab found.")
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
}

/// Observes the clipboard tab directly so new clipboard items appear immediately.
private struct ClipboardOnlyContent: View {
    @ObservedObject var tab: NoteTab
    @Binding var filter: String
    var isFilterFocused: FocusState<Bool>.Binding
    @EnvironmentObject var notesManager: NotesManager

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 8) {
                Image(systemName: "line.3.horizontal.decrease.circle")
                    .foregroundColor(.secondary)
                TextField("Filter clipboard...", text: $filter)
                    .textFieldStyle(.roundedBorder)
                    .focused(isFilterFocused)
                    .onSubmit(pasteFirstMatch)
                    .help("Return pastes the first match into the last app")
                if !filter.isEmpty {
                    Text("\(filteredItems.count) / \(tab.clipboardItems.count)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Button {
                        filter = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.secondary)
                    }
                    .buttonStyle(.plain)
                    .focusable(false)
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(
                // Invisible button so ⌘F focuses the filter field.
                Button("") { isFilterFocused.wrappedValue = true }
                    .keyboardShortcut("f", modifiers: .command)
                    .opacity(0)
                    .allowsHitTesting(false)
            )

            Divider()

            ClipboardView(items: filteredItems)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    private var filteredItems: [ClipboardItem] {
        let trimmed = filter.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return tab.clipboardItems }
        return tab.clipboardItems.filter {
            $0.text.range(of: trimmed, options: [.caseInsensitive, .diacriticInsensitive]) != nil
        }
    }

    private func pasteFirstMatch() {
        guard let item = filteredItems.first else { return }
        _ = notesManager.pasteTextIntoLastApp(item.text)
    }
}
