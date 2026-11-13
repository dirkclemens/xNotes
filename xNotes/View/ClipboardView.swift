//
//  ClipboardView.swift
//  xNotes
//

import SwiftUI
import AppKit

struct ClipboardView: View {
    let items: [ClipboardItem]
    /// Clipboard item matched by the search bar; gets selected and scrolled into view.
    var highlightedItemId: ClipboardItem.ID? = nil
    @EnvironmentObject var notesManager: NotesManager
    @State private var selection: ClipboardItem.ID?
    @State private var pendingSelection: ClipboardItem.ID?
    @State private var editItem: ClipboardItem?
    @AppStorage("clipboardLineLimit") private var clipboardLineLimit: Int = 4

    var body: some View {
        ScrollViewReader { proxy in
            clipboardList
                .onAppear {
                    revealHighlightedItem(using: proxy)
                }
                .onChange(of: highlightedItemId) { _, _ in
                    revealHighlightedItem(using: proxy)
                }
        }
    }

    private func revealHighlightedItem(using proxy: ScrollViewProxy) {
        guard let id = highlightedItemId, items.contains(where: { $0.id == id }) else { return }
        selection = id
        DispatchQueue.main.async {
            proxy.scrollTo(id, anchor: .center)
        }
    }

    private var clipboardList: some View {
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
                Text(item.text).lineLimit(clipboardLineLimit)
            }
            .help(tooltipText(for: item))
            .contentShape(Rectangle())
        }
        .listStyle(.inset)
        .focusable(true)
        .sheet(item: $editItem) { item in
            EditClipboardItemView(item: item)
        }
        .contextMenu(forSelectionType: ClipboardItem.ID.self, menu: { selectedIds in
            if let selectedId = selectedIds.first,
               let item = items.first(where: { $0.id == selectedId }) {
                itemMenu(for: item)
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

    // MARK: - Context menu

    @ViewBuilder
    private func itemMenu(for item: ClipboardItem) -> some View {
        Button("Paste into Last App") {
            _ = notesManager.pasteTextIntoLastApp(item.text)
        }
        Button("Insert to Clipboard") {
            let pasteboard = NSPasteboard.general
            pasteboard.clearContents()
            let text: NSString = item.originalText as NSString
            pasteboard.writeObjects([text])
        }

        Divider()

        Button("Edit Item…") {
            editItem = item
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
            Button("Pin to Next Free Slot") {
                notesManager.pinClipboardItemToNextFreeSlot(id: item.id)
            }
        } else {
            Button("Unpin") {
                notesManager.unpinClipboardItem(id: item.id)
            }
        }

        Divider()

        transformMenus(for: item)

        Divider()

        Button("Remove Item") {
            notesManager.removeClipboardItem(id: item.id)
        }
        Button("Clear Clipboard History") {
            notesManager.clearClipboardHistory()
        }
    }

    @ViewBuilder
    private func transformMenus(for item: ClipboardItem) -> some View {
        let id = item.id

        Menu("Case") {
            Button("UPPERCASE") {
                notesManager.replaceClipboardItem(id: id, with: item.text.uppercased())
            }
            Button("lowercase") {
                notesManager.replaceClipboardItem(id: id, with: item.text.lowercased())
            }
            Divider()
            Button("snake_case") { notesManager.toSnakeCaseClipboardItem(id: id) }
            Button("kebab-case") { notesManager.toKebabCaseClipboardItem(id: id) }
            Button("camelCase") { notesManager.toCamelCaseClipboardItem(id: id) }
            Divider()
            Button("Replace `_` and `-` with Spaces") {
                notesManager.removeUnderscoreAndHyphenClipboardItem(id: id)
            }
        }

        Menu("Whitespace") {
            Button("Trim") {
                notesManager.replaceClipboardItem(id: id, with: item.text.trimmingCharacters(in: .whitespacesAndNewlines))
            }
            Button("Trim Each Line") { notesManager.trimEachLineClipboardItem(id: id) }
            Button("Collapse Whitespace") {
                let collapsed = item.text.split(whereSeparator: { $0.isWhitespace }).joined(separator: " ")
                notesManager.replaceClipboardItem(id: id, with: collapsed)
            }
        }

        Menu("Lines") {
            Button("Sort Lines") { notesManager.sortLinesClipboardItem(id: id) }
            Button("Unique Lines") { notesManager.uniqueLinesClipboardItem(id: id) }
            Button("Reverse Lines") { notesManager.reverseLinesClipboardItem(id: id) }
            Divider()
            Button("Line Endings → LF") { notesManager.convertToLFClipboardItem(id: id) }
            Button("Line Endings → CRLF") { notesManager.convertToCRLFClipboardItem(id: id) }
        }

        Menu("Encode & Decode") {
            Button("URL Encode") { notesManager.urlEncodeClipboardItem(id: id) }
            Button("URL Decode") { notesManager.urlDecodeClipboardItem(id: id) }
            Divider()
            Button("Base64 Encode") { notesManager.base64EncodeClipboardItem(id: id) }
            Button("Base64 Decode") { notesManager.base64DecodeClipboardItem(id: id) }
            Divider()
            Button("HTML → Markdown") { notesManager.convertHtmlToMarkdownClipboardItem(id: id) }
        }

        Menu("JSON") {
            Button("Pretty Print") { notesManager.jsonPrettyPrintClipboardItem(id: id) }
            Button("Minify") { notesManager.jsonMinifyClipboardItem(id: id) }
            Button("Escape as JSON String") { notesManager.escapeJSONStringClipboardItem(id: id) }
        }

        Menu("Quotes & Escaping") {
            Button("Wrap in Quotes") { notesManager.wrapInQuotesClipboardItem(id: id) }
            Button("Remove Quotes") { notesManager.unquoteClipboardItem(id: id) }
            Divider()
            Button("Escape for Shell") { notesManager.escapeShellClipboardItem(id: id) }
        }

        Menu("Prefix & Suffix") {
            Button("Add Prefix…") { notesManager.addPrefixClipboardItem(id: id) }
            Button("Remove Prefix…") { notesManager.removePrefixClipboardItem(id: id) }
            Divider()
            Button("Add Suffix…") { notesManager.addSuffixClipboardItem(id: id) }
            Button("Remove Suffix…") { notesManager.removeSuffixClipboardItem(id: id) }
        }

        Menu("Extract") {
            Button("Emails") { notesManager.extractEmailsClipboardItem(id: id) }
            Button("URLs") { notesManager.extractURLsClipboardItem(id: id) }
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

    private var tooltipDateFormatter: DateFormatter { Self.tooltipDateFormatter }

    private static let tooltipDateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateStyle = .medium
        f.timeStyle = .medium
        return f
    }()

    private func sourceAppIcon(for item: ClipboardItem) -> NSImage {
        if let bundleId = item.sourceAppBundleId,
           let appURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleId) {
            return NSWorkspace.shared.icon(forFile: appURL.path)
        }
        return NSImage(systemSymbolName: "doc.on.clipboard", accessibilityDescription: "Clipboard") ?? NSImage()
    }
}
