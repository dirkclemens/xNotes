//
//  SidebarTile.swift
//  xNotes
//

import SwiftUI

/// A note in the sidebar: a tile tinted in the tab's color, showing the title's first letter.
struct SidebarTile: View {
    @ObservedObject var tab: NoteTab
    let title: String
    let isSelected: Bool
    /// Rotates the border gradient; encodes the time left until auto-delete (0 for locked tabs).
    let borderRotationDegrees: Double
    let showsRainbowBorder: Bool
    /// When the tab will be deleted automatically (nil when locked); shown in the tooltip.
    let autoDeleteDeadline: Date?
    let autoDeleteDays: Int
    let onSelect: () -> Void
    let onToggleLock: () -> Void
    let onClose: (() -> Void)?

    @State private var isHovered = false

    static let size: CGFloat = 34
    private let cornerRadius: CGFloat = 10

    var body: some View {
        Button(action: onSelect) {
            Text(initial)
                .font(.system(size: 14, weight: .bold, design: .rounded))
                .foregroundStyle(Color.tabForeground(hue: tab.color))
                .frame(width: Self.size, height: Self.size)
                .background(
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .fill(Color.tabColor(hue: tab.color).opacity(fillOpacity))
                )
                .overlay(border)
                .contentShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
        }
        .buttonStyle(.plain)
        .focusable(false)
        .overlay(alignment: .bottomTrailing) {
            if tab.isLocked {
                lockBadge
            }
        }
        .overlay(alignment: .leading) {
            if isSelected {
                Capsule()
                    .fill(Color.tabColor(hue: tab.color))
                    .frame(width: 3, height: 18)
                    .offset(x: -10)
            }
        }
        .onHover { isHovered = $0 }
        // Built in the body, so it's current when hovering re-renders the tile.
        .help(tooltip)
        .accessibilityLabel(title)
        .contextMenu {
            Button(tab.isLocked ? "Unlock Tab" : "Lock Tab", action: onToggleLock)
            Divider()
            Button("Delete Tab…") { onClose?() }
                .disabled(onClose == nil)
        }
    }

    private var fillOpacity: Double {
        if isSelected { return 0.32 }
        return isHovered ? 0.24 : 0.16
    }

    @ViewBuilder
    private var border: some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
        if showsRainbowBorder {
            let colors = tab.isLocked ? Color.tabBorderRainbow : Color.tabBorderGrayscale
            shape.strokeBorder(
                AngularGradient(
                    colors: colors + [colors[0]],
                    center: .center,
                    angle: .degrees(borderRotationDegrees)
                ),
                lineWidth: isSelected ? 2.5 : 1.5
            )
        } else if isSelected {
            shape.strokeBorder(Color.tabColor(hue: tab.color), lineWidth: 2)
        }
    }

    private var lockBadge: some View {
        Image(systemName: "lock.fill")
            .font(.system(size: 7, weight: .bold))
            .foregroundStyle(.secondary)
            .frame(width: 13, height: 13)
            .background(Circle().fill(.background))
            .overlay(Circle().stroke(Color.secondary.opacity(0.35), lineWidth: 0.5))
            .offset(x: 3, y: 3)
            .allowsHitTesting(false)
    }

    private var tooltip: String {
        guard tab.kind == .note else { return title }
        guard let deadline = autoDeleteDeadline else {
            return "\(title)\nLocked – never deleted automatically"
        }
        let now = Date()
        var lines = [title]
        if deadline > now {
            lines.append("Deleted automatically \(AutoDeleteFormat.relative(deadline, now: now))")
            lines.append("(\(AutoDeleteFormat.absolute(deadline)), unless edited or locked)")
        } else {
            lines.append("Will be deleted automatically any moment – edit or lock it to keep it")
        }
        lines.append("The gray border turns towards the deletion (\(autoDeleteDays)-day period)")
        return lines.joined(separator: "\n")
    }

    /// First letter of the title, skipping Markdown markers such as "# ".
    private var initial: String {
        let markers: Set<Character> = ["#", "*", "-", ">", "_", "`", "~", "[", "]", "(", ")"]
        let first = title.first { !$0.isWhitespace && !markers.contains($0) }
        return first.map { String($0).uppercased() } ?? "?"
    }
}
