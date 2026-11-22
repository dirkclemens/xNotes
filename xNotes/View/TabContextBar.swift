//
//  TabContextBar.swift
//  xNotes
//

import SwiftUI

/// Slim header above the selected tab's content: title, last edit and, for notes,
/// color and tab actions.
struct TabContextBar: View {
    @ObservedObject var tab: NoteTab
    let onSearch: () -> Void
    let onRequestClose: (NoteTab) -> Void
    let onRequestToggleLock: (NoteTab) -> Void

    @EnvironmentObject var notesManager: NotesManager
    @EnvironmentObject var textExpansionStore: TextExpansionStore

    @State private var isEditingTitle = false
    @State private var editedTitle = ""
    @State private var showColorPicker = false
    @FocusState private var isTitleFocused: Bool

    var body: some View {
        HStack(spacing: 8) {
            titleView
            meta
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
                .lineLimit(1)

            Spacer(minLength: 8)

            iconButton("magnifyingglass", help: "Search (⌘F)", action: onSearch)

            if tab.kind == .note {
                colorButton
                actionsMenu
            }
        }
        .padding(.leading, 14)
        .padding(.trailing, 10)
        .frame(height: 38)
        .onChange(of: tab.id) { _, _ in
            isEditingTitle = false
        }
    }

    // MARK: - Title

    @ViewBuilder
    private var titleView: some View {
        if isEditingTitle {
            TextField("Title", text: $editedTitle)
                .textFieldStyle(.plain)
                .font(.system(size: 14, weight: .semibold))
                .focused($isTitleFocused)
                .frame(maxWidth: 220)
                .onSubmit(commitTitle)
                .onExitCommand { isEditingTitle = false }
                .onChange(of: isTitleFocused) { _, focused in
                    if !focused && isEditingTitle { commitTitle() }
                }
        } else {
            Text(notesManager.displayTitle(for: tab))
                .font(.system(size: 14, weight: .semibold))
                .lineLimit(1)
                .truncationMode(.tail)
                .onTapGesture(count: 2) {
                    if tab.kind == .note { beginEditingTitle() }
                }
                .help(tab.kind == .note ? "Double-click to rename" : "")
        }
    }

    private func beginEditingTitle() {
        editedTitle = tab.title ?? ""
        isEditingTitle = true
        DispatchQueue.main.async { isTitleFocused = true }
    }

    private func commitTitle() {
        let trimmed = editedTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        notesManager.updateTitle(for: tab.id, title: trimmed.isEmpty ? nil : trimmed)
        isEditingTitle = false
    }

    // MARK: - Meta line

    @ViewBuilder
    private var meta: some View {
        switch tab.kind {
        case .note:
            // Refresh periodically so "2 minutes ago" keeps up without edits.
            TimelineView(.periodic(from: .now, by: 30)) { context in
                Text("Edited \(relativeDate(tab.lastEditedAt, now: context.date))")
                    .help(autoDeleteHint(now: context.date))
            }
        case .clipboard:
            let pinned = tab.clipboardItems.filter { $0.pinnedSlot != nil }.count
            Text(pinned > 0
                 ? "\(tab.clipboardItems.count) items · \(pinned) pinned"
                 : "\(tab.clipboardItems.count) items")
        case .expansions:
            let active = textExpansionStore.rules.filter(\.isEnabled).count
            Text("\(active) of \(textExpansionStore.rules.count) active")
        }
    }

    private func relativeDate(_ date: Date, now: Date) -> String {
        if now.timeIntervalSince(date) < 60 { return "just now" }
        return Self.relativeFormatter.localizedString(for: date, relativeTo: now)
    }

    private func autoDeleteHint(now: Date) -> String {
        guard !tab.isLocked else { return "Locked – never deleted automatically" }
        let deadline = tab.lastEditedAt.addingTimeInterval(TimeInterval(notesManager.autoDeleteDays() * 24 * 60 * 60))
        return "Deleted automatically \(Self.relativeFormatter.localizedString(for: deadline, relativeTo: now)) unless edited or locked"
    }

    private static let relativeFormatter: RelativeDateTimeFormatter = {
        let f = RelativeDateTimeFormatter()
        f.unitsStyle = .full
        return f
    }()

    // MARK: - Note actions

    private var colorButton: some View {
        Button(action: { showColorPicker.toggle() }) {
            Circle()
                .fill(Color.tabColor(hue: tab.color))
                .frame(width: 12, height: 12)
                .overlay(Circle().stroke(Color.primary.opacity(0.2), lineWidth: 0.5))
                .frame(width: 26, height: 26)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .focusable(false)
        .help("Change Color")
        .popover(isPresented: $showColorPicker) {
            TabColorPalette(selectedHue: tab.color) { hue in
                notesManager.updateColor(for: tab.id, color: hue)
                showColorPicker = false
            }
        }
    }

    private var actionsMenu: some View {
        Menu {
            Button("Rename…", action: beginEditingTitle)
            Button(tab.isLocked ? "Unlock Tab" : "Lock Tab") { onRequestToggleLock(tab) }
            Divider()
            Button("Delete Tab…") { onRequestClose(tab) }
                .disabled(tab.isLocked || notesManager.tabs.count <= 1)
        } label: {
            Image(systemName: "ellipsis.circle")
                .font(.system(size: 13))
                .foregroundStyle(.secondary)
        }
        .menuStyle(.borderlessButton)
        .menuIndicator(.hidden)
        .fixedSize()
        .frame(width: 26, height: 26)
        .help("More")
    }

    private func iconButton(_ systemName: String, help: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
                .frame(width: 26, height: 26)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .focusable(false)
        .help(help)
    }
}
