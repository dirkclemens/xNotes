//
//  TextEditorView.swift
//  xNotes
//

import SwiftUI
import AppKit

struct TextEditorView: View {
    @Binding var content: String
    var autoFocus: Bool = true
    var highlight: MDEditorHighlight? = nil
    @FocusState private var isFocused: Bool
    
    @AppStorage("editorFontName") private var editorFontName: String = "SF Mono"
    @AppStorage("editorFontSize") private var editorFontSize: Double = 14

    var body: some View {
        MDEditorLiteView(text: $content, font: editorFont, highlight: highlight)
            .scrollContentBackground(.hidden)
            .focused($isFocused)
            .onAppear {
                guard autoFocus else { return }
                DispatchQueue.main.async {
                    // Re-check: search may have been opened in the meantime.
                    if autoFocus {
                        isFocused = true
                    }
                }
            }
            .onChange(of: autoFocus) { _, enabled in
                // Hand focus back to the editor when the search bar closes.
                if enabled {
                    DispatchQueue.main.async {
                        isFocused = true
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
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
