//
//  ClipboardView.swift
//  xNotes
//

import SwiftUI
import AppKit

struct ClipboardView: View {
    let items: [ClipboardItem]
    @ObservedObject var notesManager: NotesManager
    @State private var selection: ClipboardItem.ID?

    var body: some View {
        List(items, selection: $selection) { item in
            HStack(spacing: 6) {
                Image(nsImage: sourceAppIcon(for: item))
                    .resizable()
                    .frame(width: 16, height: 16)

                if let slot = item.pinnedSlot {
                    Text("\(slot)")
                        .font(.system(size: 10, weight: .bold))
                        .frame(width: 16, height: 16)
                        .foregroundColor(.white)
                        .background(Circle().fill(Color.accentColor))
                }

                Text(item.text)
                    .lineLimit(3)
            }
            .help(tooltipText(for: item))
            .textSelection(.enabled)
            .onTapGesture {
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(item.text, forType: .string)
            }
            .contextMenu {
                Button("Paste into Last App") {
                    _ = notesManager.pasteTextIntoLastApp(item.text)
                }
                if item.pinnedSlot == nil {
                    Divider()
                    Button("Pin to Next Free Slot") {
                        notesManager.pinClipboardItemToNextFreeSlot(id: item.id)
                    }
                } else {
                    Button("Unpin") { notesManager.unpinClipboardItem(id: item.id) }
                }
                Divider()
                Button("To Uppercase") {
                    notesManager.replaceClipboardItem(id: item.id, with: item.text.uppercased())
                }
                Button("To Lowercase") {
                    notesManager.replaceClipboardItem(id: item.id, with: item.text.lowercased())
                }
                Button("To snake_case") {
                    notesManager.toSnakeCaseClipboardItem(id: item.id)
                }
                Button("To kebab-case") {
                    notesManager.toKebabCaseClipboardItem(id: item.id)
                }
                Button("To camelCase") {
                    notesManager.toCamelCaseClipboardItem(id: item.id)
                }
                Button("Trim") {
                    notesManager.replaceClipboardItem(id: item.id, with: item.text.trimmingCharacters(in: .whitespacesAndNewlines))
                }
                Button("Collapse Whitespace") {
                    let collapsed = item.text.split(whereSeparator: { $0.isWhitespace }).joined(separator: " ")
                    notesManager.replaceClipboardItem(id: item.id, with: collapsed)
                }
                Divider()
                Button("URL Encode") {
                    notesManager.urlEncodeClipboardItem(id: item.id)
                }
                Button("URL Decode") {
                    notesManager.urlDecodeClipboardItem(id: item.id)
                }
                Button("JSON Pretty Print") {
                    notesManager.jsonPrettyPrintClipboardItem(id: item.id)
                }
                Button("JSON Minify") {
                    notesManager.jsonMinifyClipboardItem(id: item.id)
                }
                Button("Base64 Encode") {
                    notesManager.base64EncodeClipboardItem(id: item.id)
                }
                Button("Base64 Decode") {
                    notesManager.base64DecodeClipboardItem(id: item.id)
                }
                Button("Escape Shell") {
                    notesManager.escapeShellClipboardItem(id: item.id)
                }
                Button("Escape JSON String") {
                    notesManager.escapeJSONStringClipboardItem(id: item.id)
                }
                Button("Wrap in Quotes") {
                    notesManager.wrapInQuotesClipboardItem(id: item.id)
                }
                Button("Remove Quotes") {
                    notesManager.unquoteClipboardItem(id: item.id)
                }
                Divider()
                Button("Sort Lines") {
                    notesManager.sortLinesClipboardItem(id: item.id)
                }
                Button("Unique Lines") {
                    notesManager.uniqueLinesClipboardItem(id: item.id)
                }
                Button("Trim Each Line") {
                    notesManager.trimEachLineClipboardItem(id: item.id)
                }
                Button("Reverse Lines") {
                    notesManager.reverseLinesClipboardItem(id: item.id)
                }
                Button("Line Endings -> LF") {
                    notesManager.convertToLFClipboardItem(id: item.id)
                }
                Button("Line Endings -> CRLF") {
                    notesManager.convertToCRLFClipboardItem(id: item.id)
                }
                Divider()
                Button("Add Prefix") {
                    notesManager.addPrefixClipboardItem(id: item.id)
                }
                Button("Remove Prefix") {
                    notesManager.removePrefixClipboardItem(id: item.id)
                }
                Button("Add Suffix") {
                    notesManager.addSuffixClipboardItem(id: item.id)
                }
                Button("Remove Suffix") {
                    notesManager.removeSuffixClipboardItem(id: item.id)
                }
                Divider()
                Button("Extract Emails") {
                    notesManager.extractEmailsClipboardItem(id: item.id)
                }
                Button("Extract URLs") {
                    notesManager.extractURLsClipboardItem(id: item.id)
                }
                Divider()
                Button("Remove Item") {
                    notesManager.removeClipboardItem(id: item.id)
                }
                Button("Clear Clipboard History") {
                    notesManager.clearClipboardHistory()
                }
            }
        }
        .listStyle(.inset)
    }

    private func tooltipText(for item: ClipboardItem) -> String {
        let source = item.sourceAppName ?? "Unknown"
        return "\(item.originalText)\n────────────────────\nSource: \(source)\nDate: \(tooltipDateFormatter.string(from: item.date))"
    }

    private var tooltipDateFormatter: DateFormatter {
        let f = DateFormatter()
        f.dateStyle = .medium
        f.timeStyle = .medium
        return f
    }

    private func sourceAppIcon(for item: ClipboardItem) -> NSImage {
        if let bundleId = item.sourceAppBundleId,
           let appURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleId) {
            return NSWorkspace.shared.icon(forFile: appURL.path)
        }
        return NSImage(systemSymbolName: "doc.on.clipboard", accessibilityDescription: "Clipboard") ?? NSImage()
    }
}
