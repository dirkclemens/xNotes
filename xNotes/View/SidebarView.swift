//
//  SidebarView.swift
//  xNotes
//

import SwiftUI

/// Vertical tab rail: clipboard and text expansions on top, note tiles below,
/// window and app controls at the bottom.
struct SidebarView: View {
    @EnvironmentObject var notesManager: NotesManager
    @Binding var keepWindowOpen: Bool
    let onOpenSettings: () -> Void
    let onRequestClose: (NoteTab) -> Void

    @AppStorage("tabRainbowBorder") private var showsRainbowBorder = true

    static let width: CGFloat = 56

    var body: some View {
        VStack(spacing: 6) {
            ForEach(specialTabs) { tab in
                SidebarSystemButton(
                    kind: tab.kind,
                    isSelected: notesManager.selectedTabId == tab.id,
                    action: { notesManager.selectedTabId = tab.id }
                )
            }

            Divider()
                .frame(width: 24)
                .padding(.vertical, 2)

            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: 10) {
                    ForEach(noteTabs) { tab in
                        SidebarTile(
                            tab: tab,
                            title: notesManager.displayTitle(for: tab),
                            isSelected: notesManager.selectedTabId == tab.id,
                            borderRotationDegrees: notesManager.autoDeleteRotationDegrees(for: tab),
                            showsRainbowBorder: showsRainbowBorder,
                            onSelect: { notesManager.selectedTabId = tab.id },
                            onToggleLock: { notesManager.updateLocked(for: tab.id, isLocked: !tab.isLocked) },
                            onClose: canClose(tab) ? { onRequestClose(tab) } : nil
                        )
                    }

                    Button(action: { notesManager.addTab() }) {
                        Image(systemName: "plus")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(.secondary)
                            .frame(width: SidebarTile.size, height: SidebarTile.size)
                            .overlay(
                                RoundedRectangle(cornerRadius: 10, style: .continuous)
                                    .strokeBorder(Color.secondary.opacity(0.4), style: StrokeStyle(lineWidth: 1.2, dash: [3, 3]))
                            )
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .focusable(false)
                    .help("New Tab")
                }
                .padding(.vertical, 6)
                .frame(maxWidth: .infinity)
            }

            Divider()
                .frame(width: 24)

            SidebarIconButton(
                systemName: keepWindowOpen ? "pin.fill" : "pin",
                isActive: keepWindowOpen,
                help: keepWindowOpen ? "Window stays on top" : "Normal window behavior",
                action: { keepWindowOpen.toggle() }
            )
            SidebarIconButton(systemName: "gear", help: "Settings", action: onOpenSettings)
            SidebarIconButton(
                systemName: "power",
                help: NSLocalizedString("QuitMenuTitle", comment: ""),
                action: { NSApp.terminate(nil) }
            )
        }
        .padding(.vertical, 10)
        .frame(width: Self.width)
        .frame(maxHeight: .infinity)
        .background(Color.tabStripBackground)
    }

    private var specialTabs: [NoteTab] {
        notesManager.sidebarOrderedTabs.filter { $0.kind != .note }
    }

    private var noteTabs: [NoteTab] {
        notesManager.sidebarOrderedTabs.filter { $0.kind == .note }
    }

    private func canClose(_ tab: NoteTab) -> Bool {
        notesManager.tabs.count > 1 && !tab.isLocked
    }
}

/// Clipboard / text expansion entry at the top of the sidebar.
private struct SidebarSystemButton: View {
    let kind: NoteTabKind
    let isSelected: Bool
    let action: () -> Void

    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            Image(systemName: kind == .clipboard ? "list.clipboard" : "text.badge.checkmark")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(iconColor)
                .frame(width: SidebarTile.size, height: SidebarTile.size)
                .background(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(background)
                        .shadow(color: .black.opacity(isSelected ? 0.15 : 0), radius: 1.5, y: 1)
                )
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .focusable(false)
        .onHover { isHovered = $0 }
        .help(title)
        .accessibilityLabel(title)
    }

    private var title: String {
        kind == .clipboard ? "Clipboard" : "Text Expansions"
    }

    private var iconColor: Color {
        guard isSelected else { return .secondary }
        return kind == .clipboard ? .red : .blue
    }

    private var background: AnyShapeStyle {
        if isSelected { return AnyShapeStyle(.background) }
        if isHovered { return AnyShapeStyle(Color.secondary.opacity(0.12)) }
        return AnyShapeStyle(Color.clear)
    }
}

/// Small icon button at the bottom of the sidebar.
private struct SidebarIconButton: View {
    let systemName: String
    var isActive = false
    let help: String
    let action: () -> Void

    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 12))
                .foregroundStyle(isActive ? Color.accentColor : Color.secondary)
                .frame(width: 28, height: 24)
                .background(
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .fill(Color.secondary.opacity(isHovered ? 0.12 : 0))
                )
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .focusable(false)
        .onHover { isHovered = $0 }
        .help(help)
    }
}
