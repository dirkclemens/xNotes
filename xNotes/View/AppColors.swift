//
//  AppColors.swift
//  xNotes
//

import SwiftUI
import AppKit

extension Color {
    /// Background of the sidebar.
    /// Keeps the original light gray (0.937) in light mode and adapts in dark mode.
    static let tabStripBackground = Color(nsColor: NSColor(name: "tabStripBackground") { appearance in
        let isDark = appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
        return isDark ? NSColor(white: 0.16, alpha: 1) : NSColor(white: 0.937, alpha: 1)
    })

    /// The saturated color of a note tab (hue 0…1).
    static func tabColor(hue: Double) -> Color {
        Color(hue: hue, saturation: 0.99, brightness: 0.99)
    }

    /// Text color in a tab's hue that stays readable on a light tint of the same hue.
    static func tabForeground(hue: Double) -> Color {
        Color(nsColor: NSColor(name: nil) { appearance in
            let isDark = appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
            return NSColor(hue: hue, saturation: isDark ? 0.55 : 0.9, brightness: isDark ? 1.0 : 0.55, alpha: 1)
        })
    }

    /// Colors of the tab border: rainbow for locked tabs, grayscale for unlocked ones.
    static let tabBorderRainbow: [Color] = [.yellow, .orange, .red, .purple, .blue, .green]
    static let tabBorderGrayscale: [Color] = [.white, .gray, .black]
}
