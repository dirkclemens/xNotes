//
//  MDEditorDocument.swift
//  MDEditorLite
//

import SwiftUI
import UniformTypeIdentifiers

nonisolated extension UTType {
    static var markdown: UTType {
        if #available(iOS 16.0, macOS 13.0, *) {
            // Use the system-defined Markdown type if available
            if let systemMarkdown = UTType("net.daringfireball.markdown") {
                return systemMarkdown
            }
        }
        // Fallback by filename extension; if that fails, use plain text
        return UTType(filenameExtension: "md") ?? .plainText
    }
}

nonisolated struct MDEditorDocument: FileDocument {
    var text: String

    init(text: String = "Hello, world!") {
        self.text = text
    }

    static var readableContentTypes: [UTType] { [.markdown, .plainText] }

    init(configuration: ReadConfiguration) throws {
        guard let data = configuration.file.regularFileContents,
              let string = String(data: data, encoding: .utf8)
        else {
            throw CocoaError(.fileReadCorruptFile)
        }
        text = string
    }
    
    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        let data = text.data(using: .utf8)!
        return .init(regularFileWithContents: data)
    }
}
