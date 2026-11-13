//
//  TextEditorView.swift
//  xNotes
//

import SwiftUI

struct TextEditorView: View {
    @Binding var content: String
    var autoFocus: Bool = true
    var highlight: MDEditorHighlight? = nil
    @FocusState private var isFocused: Bool
    
    @AppStorage("editorFontName") private var editorFontName: String = "SF Mono"
    @AppStorage("editorFontSize") private var editorFontSize: Double = 14

    var body: some View {
        MDEditorLiteView(text: $content, highlight: highlight)
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
    
    private var selectedEditorFont: Font {
        switch editorFontName {
        case "__system__":
            return .system(size: CGFloat(editorFontSize))
        case "__systemMonospaced__":
            return .system(size: CGFloat(editorFontSize), design: .monospaced)
        default:
            return .custom(editorFontName, size: CGFloat(editorFontSize))
        }
    }
}
