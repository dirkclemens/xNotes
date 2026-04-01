//
//  TextEditorView.swift
//  xNotes
//

import SwiftUI

struct TextEditorView: View {
    @Binding var content: String
    @FocusState private var isFocused: Bool
    
    @AppStorage("editorFontName") private var editorFontName: String = "SF Mono"
    @AppStorage("editorFontSize") private var editorFontSize: Double = 14

    var body: some View {
        MDEditorLiteView(text: $content)
            .scrollContentBackground(.hidden)
            .focused($isFocused)
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
