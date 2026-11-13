//
//  AppColors.swift
//  xNotes
//

import SwiftUI
import AppKit

extension Color {
    /// Background of the tab strip and of unselected tabs.
    /// Keeps the original light gray (0.937) in light mode and adapts in dark mode.
    static let tabStripBackground = Color(nsColor: NSColor(name: "tabStripBackground") { appearance in
        let isDark = appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
        return isDark ? NSColor(white: 0.16, alpha: 1) : NSColor(white: 0.937, alpha: 1)
    })
}
