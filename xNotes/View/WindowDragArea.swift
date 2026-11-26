//
//  WindowDragArea.swift
//  xNotes
//

import SwiftUI
import AppKit

/// Background that moves the window when dragged, used behind empty parts of the sidebar
/// and the context bar. Only active while the window stays on top; otherwise the panel
/// belongs to the menu bar icon and clicks pass through as before.
struct WindowDragArea: NSViewRepresentable {
    let isEnabled: Bool

    func makeNSView(context: Context) -> DragView {
        let view = DragView()
        view.isEnabled = isEnabled
        return view
    }

    func updateNSView(_ nsView: DragView, context: Context) {
        nsView.isEnabled = isEnabled
    }

    final class DragView: NSView {
        var isEnabled = false

        override func mouseDown(with event: NSEvent) {
            if isEnabled, let window {
                window.performDrag(with: event)
            } else {
                super.mouseDown(with: event)
            }
        }
    }
}
