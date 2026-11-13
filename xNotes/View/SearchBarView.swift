//
//  SearchBarView.swift
//  xNotes
//

import SwiftUI

struct SearchBarView: View {
    @Binding var query: String
    let resultCount: Int
    let currentIndex: Int?
    let currentTabTitle: String?
    /// Incremented by the parent whenever the search field should (re)gain focus, e.g. on ⌘F.
    let focusRequest: Int
    let onPrevious: () -> Void
    let onNext: () -> Void
    let onClose: () -> Void

    @FocusState private var isSearchFocused: Bool

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .foregroundColor(.secondary)

            TextField("Search tabs & clipboard...", text: $query)
                .textFieldStyle(.roundedBorder)
                .focused($isSearchFocused)
                .onSubmit {
                    onNext()
                    // Keep typing in the search field after pressing Return.
                    isSearchFocused = true
                }

            Text(resultLabel)
                .font(.caption)
                .foregroundColor(.secondary)
                .lineLimit(1)
                .truncationMode(.middle)
                .frame(minWidth: 90, maxWidth: 160, alignment: .trailing)
                .help(currentTabTitle ?? "")

            Button(action: onPrevious) {
                Image(systemName: "chevron.up")
            }
            .disabled(resultCount == 0)
            .focusable(false)
            .help("Previous match (⇧⌘G)")

            Button(action: onNext) {
                Image(systemName: "chevron.down")
            }
            .disabled(resultCount == 0)
            .focusable(false)
            .help("Next match (⌘G / Return)")

            Button(action: onClose) {
                Image(systemName: "xmark.circle.fill")
                    .foregroundColor(.secondary)
            }
            .buttonStyle(.plain)
            .focusable(false)
            .help("Close search (Esc)")
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(.windowBackground)
        .onAppear(perform: requestFocus)
        .onChange(of: focusRequest) { _, _ in
            requestFocus()
        }
    }

    private func requestFocus() {
        DispatchQueue.main.async {
            isSearchFocused = true
        }
    }

    private var resultLabel: String {
        guard let currentIndex else {
            return "0 / \(resultCount)"
        }
        let position = "\(currentIndex + 1) / \(resultCount)"
        if let currentTabTitle, !currentTabTitle.isEmpty {
            return "\(position) · \(currentTabTitle)"
        }
        return position
    }
}
