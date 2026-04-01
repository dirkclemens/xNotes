//
//  ClipboardView.swift
//  xNotes
//

import SwiftUI
import AppKit

struct ClipboardView: View {
    let items: [ClipboardItem]
    @EnvironmentObject var notesManager: NotesManager
    @State private var selection: ClipboardItem.ID?
    @State private var pendingSelection: ClipboardItem.ID?

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
                Text(item.text).lineLimit(4)
            }
            .help(tooltipText(for: item))
            .contentShape(Rectangle())
        }
        .listStyle(.inset)
        .focusable(true)
        .contextMenu(forSelectionType: ClipboardItem.ID.self, menu: { selectedIds in
            if let selectedId = selectedIds.first,
               let item = items.first(where: { $0.id == selectedId }) {
                Button("Paste into Last App") {
                    _ = notesManager.pasteTextIntoLastApp(item.text)
                }
                Menu("Append to Tab") {
                    if noteTabs.isEmpty {
                        Button("No Note Tabs") {}
                            .disabled(true)
                    } else {
                        ForEach(noteTabs) { tab in
                            Button(notesManager.displayTitle(for: tab)) {
                                notesManager.appendClipboardItemToTab(itemId: item.id, tabId: tab.id)
                            }
                        }
                    }
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
            } else {
                Button("No Selection") {}
                    .disabled(true)
            }
        }, primaryAction: { selectedIds in
            guard let selectedId = selectedIds.first,
                  let item = items.first(where: { $0.id == selectedId }) else { return }
            _ = notesManager.pasteTextIntoLastApp(item.text)
        })
        .onDeleteCommand {
            guard let id = selection else { return }
            let preferredNext = preferredSelectionAfterDelete(currentId: id, items: items)
            pendingSelection = preferredNext
            notesManager.removeClipboardItem(id: id)
        }
        .onChange(of: items) { _, newItems in
            if let pending = pendingSelection {
                if newItems.contains(where: { $0.id == pending }) {
                    selection = pending
                } else {
                    selection = newItems.first?.id
                }
                pendingSelection = nil
                return
            }
            guard let selected = selection else {
                selection = newItems.first?.id
                return
            }
            if !newItems.contains(where: { $0.id == selected }) {
                selection = newItems.first?.id
            }
        }
    }

    private func tooltipText(for item: ClipboardItem) -> String {
        let source = item.sourceAppName ?? "Unknown"
        return "\(item.originalText)\n────────────────────\nSource: \(source)\nDate: \(tooltipDateFormatter.string(from: item.date))"
    }

    private var noteTabs: [NoteTab] {
        notesManager.tabs.filter { $0.kind == .note }
    }

    private func preferredSelectionAfterDelete(currentId: ClipboardItem.ID, items: [ClipboardItem]) -> ClipboardItem.ID? {
        guard let index = items.firstIndex(where: { $0.id == currentId }) else { return nil }
        if index > 0 {
            return items[index - 1].id
        }
        if index + 1 < items.count {
            return items[index + 1].id
        }
        return nil
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
