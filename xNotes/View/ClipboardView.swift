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
    @AppStorage("clipboardLineLimit") private var clipboardLineLimit: Int = 4
    @AppStorage(ClipboardRowMetrics.fontSizeKey) private var fontSize: Double = ClipboardRowMetrics.defaultFontSize
    @AppStorage("clipboardShowsScrollBar") private var showsScrollBar = true

    private var metrics: ClipboardRowMetrics { ClipboardRowMetrics(fontSize: fontSize) }

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
        .onDisappear {
            ClipboardPreviewController.shared.hide()
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
                    .frame(width: metrics.iconSize, height: metrics.iconSize)
                    .alignmentGuide(.firstTextBaseline) { $0[.bottom] - metrics.baselineOffset }
                    .padding(.trailing, metrics.iconGap)
                if let slot = item.pinnedSlot {
                    Text("\(slot)")
                        .font(.system(size: metrics.symbolSize, weight: .bold))
                        .frame(width: metrics.iconSize, height: metrics.iconSize)
                        .foregroundColor(.white)
                        .background(Circle().fill(Color.accentColor))
                        .alignmentGuide(.firstTextBaseline) { $0[.bottom] - metrics.baselineOffset }
                }
                if item.isImageItem {
                    imageThumbnail(for: item)
                }
                if let firstPath = item.filePaths.first {
                    Image(nsImage: NSWorkspace.shared.icon(forFile: firstPath))
                        .resizable()
                        .frame(width: metrics.iconSize, height: metrics.iconSize)
                        .alignmentGuide(.firstTextBaseline) { $0[.bottom] - metrics.baselineOffset }
                }
                if item.isLink {
                    Image(systemName: "link")
                        .font(.system(size: metrics.symbolSize))
                        .foregroundStyle(.secondary)
                        .alignmentGuide(.firstTextBaseline) { $0[.bottom] - metrics.baselineOffset }
                }
                if item.canPasteRichText {
                    Image(systemName: "textformat")
                        .font(.system(size: metrics.symbolSize))
                        .foregroundStyle(.secondary)
                        .alignmentGuide(.firstTextBaseline) { $0[.bottom] - metrics.baselineOffset }
                }
                if item.isSensitive {
                    Image(systemName: "key.fill")
                        .font(.system(size: metrics.symbolSize))
                        .foregroundStyle(.orange)
                        .alignmentGuide(.firstTextBaseline) { $0[.bottom] - metrics.baselineOffset }
                }
                rowText(for: item)
                    .font(.system(size: metrics.fontSize))
                    .lineLimit(clipboardLineLimit)
            }
            // Whole row width, so the preview also shows right of short text.
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
            .onHover { hovering in
                updatePreview(for: item, hovering: hovering)
            }
            .listRowInsets(EdgeInsets(top: 1, leading: 0, bottom: 1, trailing: 10))
        }
        .listStyle(.inset)
        // `.never` also hides the bar when "Show scroll bars: Always" is set in System Settings.
        .scrollIndicators(showsScrollBar ? .automatic : .never)
        // Keeps rows and scroll bar away from the window's rounded corner.
        .padding(.trailing, 6)
        .padding(.bottom, 10)
        .environment(\.defaultMinListRowHeight, metrics.rowHeight)
        .focusable(true)
        // The selection already shows focus; the ring would frame the padded list.
        .focusEffectDisabled()
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

    /// Small preview of an image entry; falls back to a symbol if the file is missing.
    @ViewBuilder
    private func imageThumbnail(for item: ClipboardItem) -> some View {
        if let thumbnail = notesManager.imageStore.thumbnail(for: item.id) {
            Image(nsImage: thumbnail)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(maxWidth: metrics.thumbnailSize.width, maxHeight: metrics.thumbnailSize.height, alignment: .leading)
                .clipShape(RoundedRectangle(cornerRadius: 3))
                .overlay(RoundedRectangle(cornerRadius: 3).strokeBorder(Color.secondary.opacity(0.3), lineWidth: 0.5))
                // Text baseline slightly below the middle, so icon and text sit vertically centered.
                .alignmentGuide(.firstTextBaseline) { $0[VerticalAlignment.center] + metrics.fontSize / 3 }
        } else {
            Image(systemName: "photo")
                .font(.system(size: metrics.fontSize))
                .foregroundStyle(.secondary)
                .alignmentGuide(.firstTextBaseline) { $0[.bottom] - metrics.baselineOffset }
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

    /// Shows the hover preview (instead of a tooltip) for the row under the mouse.
    private func updatePreview(for item: ClipboardItem, hovering: Bool) {
        let preview = ClipboardPreviewController.shared
        guard hovering else {
            preview.hoverEnded(itemId: item.id)
            return
        }
        preview.hoverBegan(itemId: item.id) { [notesManager, pasteAsPlainText] in
            // The entry may have changed since (title fetched, edited).
            let current = notesManager.clipboardItem(id: item.id) ?? item
            return AnyView(ClipboardItemPreview(item: current, notesManager: notesManager, pasteAsPlainText: pasteAsPlainText))
        }
    }

    private func sourceAppIcon(for item: ClipboardItem) -> NSImage {
        if let bundleId = item.sourceAppBundleId,
           let appURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleId) {
            return NSWorkspace.shared.icon(forFile: appURL.path)
        }
        return NSImage(systemSymbolName: "doc.on.clipboard", accessibilityDescription: "Clipboard") ?? NSImage()
    }
}

/// Sizes of a clipboard list row, all derived from the font size set in Settings,
/// so row height, icons and thumbnails grow with the text. 12 pt is the original layout.
struct ClipboardRowMetrics {
    static let fontSizeKey = "clipboardFontSize"
    static let defaultFontSize: Double = 12
    static let fontSizeRange: ClosedRange<Double> = 10...24

    let fontSize: CGFloat

    init(fontSize: Double) {
        self.fontSize = CGFloat(min(max(fontSize, Self.fontSizeRange.lowerBound), Self.fontSizeRange.upperBound))
    }

    private var scale: CGFloat { fontSize / CGFloat(Self.defaultFontSize) }

    /// Minimum row height: one and a half times the text size (18 pt at 12 pt).
    var rowHeight: CGFloat { (fontSize * 1.5).rounded() }
    /// App and file icons.
    var iconSize: CGFloat { (14 * scale).rounded() }
    /// Small markers (pin number, link, formatting, key).
    var symbolSize: CGFloat { (9 * scale).rounded() }
    /// Extra space between the source app icon and what follows it.
    var iconGap: CGFloat { (3 * scale).rounded() }
    /// Lifts icons so they sit centered on the first text line.
    var baselineOffset: CGFloat { 3 * scale }
    var thumbnailSize: CGSize { CGSize(width: 64 * scale, height: 36 * scale) }
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
