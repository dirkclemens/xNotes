//
//  TextEditorView.swift
//  xNotes
//

import SwiftUI
import AppKit

struct TextEditorView: View {
    @Binding var content: String
    var autoFocus: Bool = true
    var highlight: MarkdownEditorHighlight? = nil

    @AppStorage("editorFontName") private var editorFontName: String = "SF Mono"
    @AppStorage("editorFontSize") private var editorFontSize: Double = 14
    @AppStorage("editorTheme") private var editorThemeName: String = MarkdownEditorTheme.systemThemeName
    @AppStorage("editorShowsLineNumbers") private var showsLineNumbers: Bool = false
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        MarkdownEditor(
            text: $content,
            font: editorFont,
            theme: editorTheme,
            showsLineNumbers: showsLineNumbers,
            highlight: highlight,
            autoFocus: autoFocus
        )
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var editorTheme: MarkdownEditorTheme {
        let appearance = NSAppearance(named: colorScheme == .dark ? .darkAqua : .aqua) ?? NSAppearance.currentDrawing()
        return MarkdownEditorTheme.named(editorThemeName, for: appearance)
    }

    private var editorFont: NSFont {
        let size = CGFloat(editorFontSize)
        switch editorFontName {
        case "__system__":
            return .systemFont(ofSize: size)
        case "__systemMonospaced__", "SF Mono":
            // SF Mono is not installed system-wide on every macOS version;
            // the monospaced system font *is* SF Mono.
            return NSFont(name: "SFMono-Regular", size: size) ?? .monospacedSystemFont(ofSize: size, weight: .regular)
        default:
            return NSFont(name: editorFontName, size: size) ?? .monospacedSystemFont(ofSize: size, weight: .regular)
        }
    }
}
