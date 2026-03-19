//
//  SearchBarView.swift
//  xNotes
//

import SwiftUI

struct SearchBarView: View {
    @Binding var query: String
    let resultCount: Int
    let currentIndex: Int?
    let onPrevious: () -> Void
    let onNext: () -> Void
    let onClose: () -> Void

    @FocusState private var isSearchFocused: Bool

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .foregroundColor(.secondary)

            TextField("Search tabs...", text: $query)
                .textFieldStyle(.roundedBorder)
                .focused($isSearchFocused)

            Text(resultLabel)
                .font(.caption)
                .foregroundColor(.secondary)
                .frame(minWidth: 90, alignment: .trailing)

            Button(action: onPrevious) {
                Image(systemName: "chevron.up")
            }
            .disabled(resultCount == 0)

            Button(action: onNext) {
                Image(systemName: "chevron.down")
            }
            .disabled(resultCount == 0)

            Button(action: onClose) {
                Image(systemName: "xmark.circle.fill")
                    .foregroundColor(.secondary)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(.windowBackground)
        .onAppear {
            DispatchQueue.main.async {
                isSearchFocused = true
            }
        }
    }

    private var resultLabel: String {
        guard let currentIndex else {
            return "0 / \(resultCount)"
        }
        return "\(currentIndex + 1) / \(resultCount)"
    }
}
