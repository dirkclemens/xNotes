//
//  ClipboardView.swift
//  xNotes
//

import SwiftUI
import AppKit
import UniformTypeIdentifiers

struct ClipboardView: View {
    let items: [ClipboardItem]
    /// Clipboard item matched by the search bar; gets selected and scrolled into view.
    var highlightedItemId: ClipboardItem.ID? = nil
    @EnvironmentObject var notesManager: NotesManager
    @ObservedObject private var transformRegistry = TransformRegistry.shared
    @State private var selection: ClipboardItem.ID?
    @State private var pendingSelection: ClipboardItem.ID?
    @State private var editItem: ClipboardItem?
    @AppStorage("pasteAsPlainText") private var pasteAsPlainText = false
    /// Row under the mouse. Its tooltip is rebuilt on hover so file checks are current.
    @State private var hoveredItemId: ClipboardItem.ID?
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
        .overlay(alignment: .bottom) {
            if let message = transformRegistry.message {
                TransformMessageBanner(message: message)
                    .padding(8)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .animation(.easeInOut(duration: 0.2), value: transformRegistry.message)
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
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Image(nsImage: sourceAppIcon(for: item))
                    .resizable()
                    .frame(width: 14, height: 14)
                    .alignmentGuide(.firstTextBaseline) { $0[.bottom] - 3 }
                if let slot = item.pinnedSlot {
                    Text("\(slot)")
                        .font(.system(size: 9, weight: .bold))
                        .frame(width: 14, height: 14)
                        .foregroundColor(.white)
                        .background(Circle().fill(Color.accentColor))
                        .alignmentGuide(.firstTextBaseline) { $0[.bottom] - 3 }
                }
                if item.isImageItem {
                    imageThumbnail(for: item)
                }
                if let firstPath = item.filePaths.first {
                    Image(nsImage: NSWorkspace.shared.icon(forFile: firstPath))
                        .resizable()
                        .frame(width: 14, height: 14)
                        .alignmentGuide(.firstTextBaseline) { $0[.bottom] - 3 }
                }
                if item.isLink {
                    Image(systemName: "link")
                        .font(.system(size: 9))
                        .foregroundStyle(.secondary)
                        .alignmentGuide(.firstTextBaseline) { $0[.bottom] - 3 }
                }
                if item.canPasteRichText {
                    Image(systemName: "textformat")
                        .font(.system(size: 9))
                        .foregroundStyle(.secondary)
                        .alignmentGuide(.firstTextBaseline) { $0[.bottom] - 3 }
                }
                if item.isSensitive {
                    Image(systemName: "key.fill")
                        .font(.system(size: 9))
                        .foregroundStyle(.orange)
                        .alignmentGuide(.firstTextBaseline) { $0[.bottom] - 3 }
                }
                rowText(for: item)
                    .font(.system(size: 12))
                    .lineLimit(clipboardLineLimit)
            }
            .help(tooltipText(for: item))
            .onHover { hovering in
                if hovering {
                    hoveredItemId = item.id
                } else if hoveredItemId == item.id {
                    hoveredItemId = nil
                }
            }
            .contentShape(Rectangle())
            .listRowInsets(EdgeInsets(top: 1, leading: 6, bottom: 1, trailing: 6))
        }
        .listStyle(.inset)
        .environment(\.defaultMinListRowHeight, 18)
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
            _ = notesManager.pasteClipboardItemIntoLastApp(item)
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
            _ = notesManager.pasteClipboardItemIntoLastApp(item)
        }
        if item.canPasteRichText {
            if pasteAsPlainText {
                Button("Paste with Formatting") {
                    _ = notesManager.pasteClipboardItemIntoLastApp(item, asPlainText: false)
                }
            } else {
                Button("Paste as Plain Text") {
                    _ = notesManager.pasteClipboardItemIntoLastApp(item, asPlainText: true)
                }
            }
        }
        Button("Insert to Clipboard") {
            notesManager.writeClipboardItemToPasteboard(item, text: item.originalText)
        }
        if let url = item.linkURL {
            Button("Open Link") {
                NSWorkspace.shared.open(url)
            }
            Button("Paste as Markdown Link") {
                Task {
                    if let markdownLink = await notesManager.markdownLink(forItem: item.id) {
                        _ = notesManager.pasteTextIntoLastApp(markdownLink)
                    }
                }
            }
            Button("Copy as Markdown Link") {
                Task {
                    if let markdownLink = await notesManager.markdownLink(forItem: item.id) {
                        notesManager.copyTextToPasteboard(markdownLink)
                        transformRegistry.show("Copied \(markdownLink)")
                    }
                }
            }
        }
        if item.isImageItem {
            Button("Open in Preview") {
                openImageInPreview(item)
            }
            Button("Save Image As…") {
                saveImage(item)
            }
        }
        if item.isFileItem {
            Button(item.filePaths.count == 1 ? "Show in Finder" : "Show Files in Finder") {
                NSWorkspace.shared.activateFileViewerSelecting(item.fileURLs)
            }
            .disabled(!item.filePaths.contains { FileManager.default.fileExists(atPath: $0) })
        }

        Divider()

        if item.isTextItem {
            Button("Edit Item…") {
                editItem = item
            }
        }
        if !item.isImageItem {
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

        if item.isTextItem {
            Divider()
            transformMenus(for: item)
        }

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
        ForEach(transformRegistry.groups) { group in
            Menu(group.name) {
                ForEach(Array(group.sections.enumerated()), id: \.offset) { index, section in
                    if index > 0 {
                        Divider()
                    }
                    ForEach(section) { transform in
                        transformButton(transform, item: item)
                    }
                }
            }
        }

        Menu("Plugins") {
            ForEach(transformRegistry.ungroupedPlugins) { transform in
                transformButton(transform, item: item)
            }
            if !transformRegistry.ungroupedPlugins.isEmpty {
                Divider()
            }
            if !transformRegistry.loadErrors.isEmpty {
                Menu("Load Errors (\(transformRegistry.loadErrors.count))") {
                    ForEach(transformRegistry.loadErrors) { error in
                        Button("\(error.fileName): \(error.message)") {}
                            .disabled(true)
                    }
                }
            }
            Button("Open Plugins Folder") {
                transformRegistry.openPluginFolder()
            }
            Button("Reload Plugins") {
                transformRegistry.reload(announce: true)
            }
        }
    }

    private func transformButton(_ transform: ClipboardTransform, item: ClipboardItem) -> some View {
        Button(transform.menuTitle) {
            notesManager.applyTransform(transform, toClipboardItem: item.id)
        }
    }

    private func tooltipText(for item: ClipboardItem) -> String {
        var info: [String] = []
        if item.isMarkedConcealed {
            info.append("⚠︎ Sensitive: marked as a password by the source app")
        } else if item.isFromPasswordApp {
            info.append("⚠︎ Sensitive: copied from a password app")
        }
        info.append("Source: \(item.sourceAppName ?? "Unknown")")
        if let bundleId = item.sourceAppBundleId {
            info.append("App ID: \(bundleId)")
        }
        info.append("Copied: \(Self.tooltipDateFormatter.string(from: item.date))")
        let formats = ClipboardFormats.displayNames(for: item.pasteboardTypes)
        if !formats.isEmpty {
            info.append("Formats: \(formats.joined(separator: ", "))")
        }
        if let image = item.imageInfo {
            let size = ByteCountFormatter.string(fromByteCount: Int64(image.byteCount), countStyle: .file)
            info.append("Image: \(image.width) × \(image.height) pixels, stored as PNG (\(size))")
            info.append("Copied as: \(image.originalFormat)")
        } else if item.isFileItem {
            // Checking the files touches the disk, so only for the row under the mouse.
            if hoveredItemId == item.id {
                info.append(contentsOf: fileInfoLines(for: item))
            } else {
                info.append("\(item.filePaths.count) \(item.filePaths.count == 1 ? "file" : "files")")
            }
        } else {
            if let url = item.linkURL {
                info.append(linkInfo(for: url, hasTitle: item.linkTitle != nil))
            } else {
                info.append("Size: \(sizeDescription(for: item.text))")
            }
            if let formatting = formattingInfo(for: item) {
                info.append(formatting)
            }
        }
        if item.text != item.originalText {
            info.append("Edited or transformed (original shown above)")
        }
        if let slot = item.pinnedSlot {
            info.append("Pinned to slot \(slot) (⌥\(slot))")
        }
        let content: String
        if item.isImageItem {
            content = "Image"
        } else if item.isFileItem {
            content = item.filePaths.joined(separator: "\n")
        } else if let title = item.linkTitle, let url = item.linkURL {
            content = "\(title)\n\(url.absoluteString)"
        } else {
            content = item.originalText
        }
        return "\(content)\n────────────────────\n\(info.joined(separator: "\n"))"
    }

    /// Small preview of an image entry; falls back to a symbol if the file is missing.
    @ViewBuilder
    private func imageThumbnail(for item: ClipboardItem) -> some View {
        if let thumbnail = notesManager.imageStore.thumbnail(for: item.id) {
            Image(nsImage: thumbnail)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(maxWidth: 64, maxHeight: 36, alignment: .leading)
                .clipShape(RoundedRectangle(cornerRadius: 3))
                .overlay(RoundedRectangle(cornerRadius: 3).strokeBorder(Color.secondary.opacity(0.3), lineWidth: 0.5))
                // Text baseline slightly below the middle, so icon and text sit vertically centered.
                .alignmentGuide(.firstTextBaseline) { $0[VerticalAlignment.center] + 4 }
        } else {
            Image(systemName: "photo")
                .foregroundStyle(.secondary)
                .alignmentGuide(.firstTextBaseline) { $0[.bottom] - 3 }
        }
    }

    /// Opens a copy, so edits in Preview don't change the stored clipboard image.
    private func openImageInPreview(_ item: ClipboardItem) {
        guard let data = notesManager.imageStore.imageData(for: item.id) else {
            transformRegistry.show("The image file of this entry is missing.", isError: true)
            return
        }
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent(imageFileName(for: item))
        do {
            try data.write(to: url, options: .atomic)
            NSWorkspace.shared.open(url)
        } catch {
            transformRegistry.show("Couldn't open the image: \(error.localizedDescription)", isError: true)
        }
    }

    private func saveImage(_ item: ClipboardItem) {
        guard let data = notesManager.imageStore.imageData(for: item.id) else {
            transformRegistry.show("The image file of this entry is missing.", isError: true)
            return
        }
        let panel = NSSavePanel()
        panel.title = "Save Image"
        panel.allowedContentTypes = [.png]
        panel.nameFieldStringValue = imageFileName(for: item)
        panel.canCreateDirectories = true
        panel.begin { result in
            guard result == .OK, let url = panel.url else { return }
            do {
                try data.write(to: url, options: .atomic)
            } catch {
                transformRegistry.show("Couldn't save the image: \(error.localizedDescription)", isError: true)
            }
        }
    }

    /// e.g. "Clipboard Image 2026-11-22 at 14.05.12.png", like macOS screenshots.
    private func imageFileName(for item: ClipboardItem) -> String {
        "Clipboard Image \(Self.imageFileDateFormatter.string(from: item.date)).png"
    }

    private static let imageFileDateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "yyyy-MM-dd 'at' HH.mm.ss"
        return f
    }()

    /// Link title (if any) followed by the domain in gray; plain text otherwise.
    private func rowText(for item: ClipboardItem) -> Text {
        guard let title = item.linkTitle, let host = item.linkURL?.host else {
            return Text(item.text)
        }
        return Text(title) + Text("  \(host)").foregroundColor(.secondary)
    }

    private func linkInfo(for url: URL, hasTitle: Bool) -> String {
        var parts = ["Link to \(url.host ?? url.absoluteString)"]
        if url.scheme?.lowercased() == "http" {
            parts.append("not encrypted (http)")
        }
        if !hasTitle {
            parts.append("no title")
        }
        return parts.joined(separator: ", ")
    }

    /// Which formatted versions are kept and whether a paste uses them.
    private func formattingInfo(for item: ClipboardItem) -> String? {
        guard !item.richTextFormats.isEmpty else { return nil }
        let formats = item.richTextFormats.map { format -> String in
            // File sizes only for the row under the mouse (disk access).
            guard hoveredItemId == item.id,
                  let bytes = notesManager.richTextStore.byteCount(format: format, for: item.id) else {
                return format.displayName
            }
            return "\(format.displayName) \(ByteCountFormatter.string(fromByteCount: Int64(bytes), countStyle: .file))"
        }.joined(separator: ", ")
        let usage: String
        if !item.canPasteRichText {
            usage = "not used, the text was edited"
        } else if pasteAsPlainText {
            usage = "Paste as Plain Text is on"
        } else {
            usage = "pastes with formatting"
        }
        return "Formatting: \(formats) – \(usage)"
    }

    /// Kind and size per file, or a note when it no longer exists.
    private func fileInfoLines(for item: ClipboardItem) -> [String] {
        let keys: Set<URLResourceKey> = [.localizedTypeDescriptionKey, .fileSizeKey, .isDirectoryKey]
        var lines = ["\(item.filePaths.count) \(item.filePaths.count == 1 ? "file" : "files"):"]
        var missing = 0
        for url in item.fileURLs.prefix(10) {
            guard let values = try? url.resourceValues(forKeys: keys) else {
                missing += 1
                lines.append("  \(url.lastPathComponent) – no longer exists")
                continue
            }
            var details = [values.localizedTypeDescription ?? (values.isDirectory == true ? "Folder" : "File")]
            if values.isDirectory != true, let size = values.fileSize {
                details.append(ByteCountFormatter.string(fromByteCount: Int64(size), countStyle: .file))
            }
            lines.append("  \(url.lastPathComponent) – \(details.joined(separator: ", "))")
        }
        if item.filePaths.count > 10 {
            lines.append("  … and \(item.filePaths.count - 10) more")
        }
        if missing > 0 {
            lines.append("⚠︎ Missing files can't be pasted")
        }
        return lines
    }

    private func sizeDescription(for text: String) -> String {
        let characters = text.count
        let lines = text.reduce(into: 1) { count, character in
            if character.isNewline { count += 1 }
        }
        let words = text.split(whereSeparator: { $0.isWhitespace || $0.isNewline }).count
        var parts = ["\(characters) \(characters == 1 ? "character" : "characters")"]
        parts.append("\(words) \(words == 1 ? "word" : "words")")
        if lines > 1 {
            parts.append("\(lines) lines")
        }
        return parts.joined(separator: ", ")
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

/// Short, non-blocking feedback after running a transform (errors, "no change", plugin reload).
private struct TransformMessageBanner: View {
    let message: TransformMessage

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: message.isError ? "exclamationmark.triangle.fill" : "info.circle")
                .foregroundColor(message.isError ? .orange : .secondary)
            Text(message.text)
                .font(.caption)
                .lineLimit(3)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8))
        .shadow(color: .black.opacity(0.15), radius: 4, y: 1)
    }
}
