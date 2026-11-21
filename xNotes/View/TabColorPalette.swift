//
//  TabColorPalette.swift
//  xNotes
//

import SwiftUI

/// Row of hue swatches used to pick a note tab's color.
struct TabColorPalette: View {
    let selectedHue: Double
    let onSelect: (Double) -> Void

    static let hues: [Double] = [
        0.0, 0.05, 0.10, 0.15, 0.20, 0.25, 0.30, 0.35, 0.40, 0.45,
        0.50, 0.55, 0.60, 0.65, 0.70, 0.75, 0.80, 0.85, 0.90, 0.95, 1.0
    ]

    var body: some View {
        HStack(spacing: 2) {
            ForEach(Self.hues, id: \.self) { hue in
                Button(action: { onSelect(hue) }) {
                    Circle()
                        .fill(Color.tabColor(hue: hue))
                        .frame(width: 18, height: 18)
                        .overlay(
                            Circle().stroke(hue == selectedHue ? Color.primary : Color.clear, lineWidth: hue == selectedHue ? 3 : 0)
                        )
                }
                .buttonStyle(.plain)
            }
        }
        .padding(8)
    }
}
