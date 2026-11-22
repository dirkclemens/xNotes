//
//  NotesManager.swift
//  xNotes
//

import Foundation
import Combine
import AppKit
import ApplicationServices
import Carbon.HIToolbox

@MainActor
class NotesManager: ObservableObject {
    @Published var tabs: [NoteTab] = []
    @Published var selectedTabId: UUID?
    
    private var saveTask: Task<Void, Never>?
    private let saveDelay: TimeInterval = 1.0
    private let storageKey = "savedNotes"
    let richTextStore = ClipboardRichTextStore(
        folderName: DemoMode.isEnabled ? "ClipboardRichText-Demo" : "ClipboardRichText"
    )
    let imageStore = ClipboardImageStore(
        folderName: DemoMode.isEnabled ? "ClipboardImages-Demo" : "ClipboardImages"
    )
    static let clipboardSaveImagesKey = "clipboardSaveImages"
    private lazy var tabsStore = TabsFileStore(
        legacyDefaultsKey: storageKey,
        fileName: DemoMode.isEnabled ? "tabs-demo.json" : "tabs.json"
    )
    private let clipboardMaxItemsKey = "clipboardMaxItems"
    private let pasteAsPlainTextKey = "pasteAsPlainText"
    private let pasteNormalizeLFKey = "pasteNormalizeLF"
    private let pasteTrimTrailingWhitespaceKey = "pasteTrimTrailingWhitespace"
    private let tabAutoDeleteDaysKey = "tabAutoDeleteDays"
    static let clipboardSaveSensitiveKey = "clipboardSaveSensitive"
    private let tabAutoDeleteDefaultDays = 7
    private var clipboardTimer: Timer?
    private var lastClipboardChangeCount: Int = 0
    private var lastClipboardString: String?
    private var lastNonXNotesApp: NSRunningApplication?
    
    init() {
        loadTabs()
        pruneExpiredTabs(persist: false)
        ensureSpecialTabs()
        if tabs.isEmpty {
            tabs = [NoteTab()]
        }
        selectedTabId = tabs.first?.id
        trackLastActiveApp()
        if !DemoMode.isEnabled {
            startClipboardMonitor()
        }
    }
    
    func addTab() {
        let newTab = NoteTab()
        if let index = tabs.firstIndex(where: { $0.kind == .expansions }) {
            tabs.insert(newTab, at: index)
        } else {
            tabs.append(newTab)
        }
        selectedTabId = newTab.id
        saveWithDelay()
    }

    func selectTab(at index: Int) {
        guard index >= 0, index < tabs.count else { return }
        selectedTabId = tabs[index].id
    }

    /// Tabs in the order the sidebar shows them: clipboard and text expansions first, then the notes.
    /// ⌘1…⌘9 follow this order so the shortcuts match what the user sees.
    var sidebarOrderedTabs: [NoteTab] {
        tabs.filter { $0.kind == .clipboard }
            + tabs.filter { $0.kind == .expansions }
            + tabs.filter { $0.kind == .note }
    }
    
    func removeTab(_ tab: NoteTab) {
        guard tab.kind == .note else { return }
        guard tabs.count > 1 else { return }
        
        if let index = tabs.firstIndex(where: { $0.id == tab.id }) {
            tabs.remove(at: index)
            if selectedTabId == tab.id {
                selectedTabId = tabs.first?.id
            }
            saveWithDelay()
        }
    }
    
    func updateContent(for tabId: UUID, content: String) {
        if let index = tabs.firstIndex(where: { $0.id == tabId }) {
            tabs[index].content = content
            tabs[index].lastEditedAt = Date()
            saveWithDelay()
        }
    }
    
    func updateColor(for tabId: UUID, color: Double) {
        if let index = tabs.firstIndex(where: { $0.id == tabId }) {
            tabs[index].color = color
            tabs[index].lastEditedAt = Date()
            saveWithDelay()
        }
    }
    
    func updateTitle(for tabId: UUID, title: String?) {
        if let index = tabs.firstIndex(where: { $0.id == tabId }) {
            guard tabs[index].kind == .note else { return }
            tabs[index].title = title
            tabs[index].lastEditedAt = Date()
            saveWithDelay()
        }
    }

    func updateLocked(for tabId: UUID, isLocked: Bool) {
        if let index = tabs.firstIndex(where: { $0.id == tabId }) {
            guard tabs[index].kind == .note else { return }
            tabs[index].isLocked = isLocked
            saveWithDelay()
        }
    }

    /// Unlocks a tab and restarts its auto-delete countdown, so a tab that was locked
    /// past the auto-delete period isn't removed right after unlocking.
    func unlockRestartingAutoDelete(for tabId: UUID) {
        guard let index = tabs.firstIndex(where: { $0.id == tabId }),
              tabs[index].kind == .note else { return }
        tabs[index].isLocked = false
        tabs[index].lastEditedAt = Date()
        saveWithDelay()
    }

    /// True if the tab is older than the auto-delete period, i.e. auto-delete would
    /// remove it as soon as it is (or once it gets) unlocked.
    func isPastAutoDeleteDeadline(_ tab: NoteTab, now: Date = Date()) -> Bool {
        guard tab.kind == .note else { return false }
        return tab.lastEditedAt < autoDeleteCutoff(now: now)
    }

    func isClipboardTabSelected() -> Bool {
        guard let selectedId = selectedTabId,
              let tab = tabs.first(where: { $0.id == selectedId }) else {
            return false
        }
        return tab.kind == .clipboard
    }
    
    private func saveWithDelay() {
        saveTask?.cancel()
        saveTask = Task {
            try? await Task.sleep(nanoseconds: UInt64(saveDelay * 1_000_000_000))
            guard !Task.isCancelled else { return }
            await MainActor.run {
                self.saveTask = nil
                self.pruneExpiredTabs(persist: false)
                self.saveTabs()
            }
        }
    }
    
    private func saveTabs() {
        tabsStore.save(tabs)
        removeUnusedRichText()
    }

    /// Deletes formatted versions and images of clipboard entries that no longer exist.
    private func removeUnusedRichText() {
        guard let clipboardTab = tabs.first(where: { $0.kind == .clipboard }) else { return }
        let ids = Set(clipboardTab.clipboardItems.map(\.id))
        richTextStore.removeAll(except: ids)
        imageStore.removeAll(except: ids)
    }

    /// Writes pending changes synchronously, e.g. when the app is about to quit.
    func flushPendingSave() {
        guard saveTask != nil else { return }
        saveTask?.cancel()
        saveTask = nil
        pruneExpiredTabs(persist: false)
        tabsStore.saveImmediately(tabs)
    }

    private func loadTabs() {
        #if DEBUG
        if DemoMode.isEnabled {
            tabs = DemoData.tabs()
            return
        }
        #endif
        if let loaded = tabsStore.load() {
            tabs = loaded
        }
    }

    private func ensureSpecialTabs() {
        ensureSpecialTab(
            kind: .clipboard,
            title: "Clipboard",
            color: 0.6,
            insertAt: 0
        )
        ensureSpecialTabAtEnd(
            kind: .expansions,
            title: "Expansions",
            color: 0.12
        )
    }

    private func ensureSpecialTab(kind: NoteTabKind, title: String, color: Double, insertAt: Int) {
        if let index = tabs.firstIndex(where: { $0.kind == kind }) {
            tabs[index].isLocked = true
            tabs[index].title = title
            if index != insertAt {
                let tab = tabs.remove(at: index)
                let target = min(insertAt, tabs.count)
                tabs.insert(tab, at: target)
            }
        } else {
            let tab = NoteTab(
                content: "",
                color: color,
                title: title,
                isLocked: true,
                kind: kind,
                clipboardItems: [],
                lastEditedAt: Date()
            )
            let target = min(insertAt, tabs.count)
            tabs.insert(tab, at: target)
        }
    }

    private func ensureSpecialTabAtEnd(kind: NoteTabKind, title: String, color: Double) {
        if let index = tabs.firstIndex(where: { $0.kind == kind }) {
            tabs[index].isLocked = true
            tabs[index].title = title
            let lastIndex = max(tabs.count - 1, 0)
            if index != lastIndex {
                let tab = tabs.remove(at: index)
                tabs.append(tab)
            }
        } else {
            let tab = NoteTab(
                content: "",
                color: color,
                title: title,
                isLocked: true,
                kind: kind,
                clipboardItems: [],
                lastEditedAt: Date()
            )
            tabs.append(tab)
        }
    }

    /// Images are left out of backups (they would make the JSON huge).
    func exportBackupData() throws -> Data {
        let clipboardItems = tabs.first(where: { $0.kind == .clipboard })?.clipboardItems ?? []
        let richText = clipboardItems.flatMap { item in
            item.richTextFormats.compactMap { format in
                richTextStore.data(format: format, for: item.id)
                    .map { ClipboardRichTextEntry(itemId: item.id, format: format, data: $0) }
            }
        }
        let codableTabs = tabs.map { tab in
            NoteTab(
                id: tab.id,
                content: tab.content,
                color: tab.color,
                title: tab.title,
                isLocked: tab.isLocked,
                kind: tab.kind,
                clipboardItems: tab.clipboardItems.filter { !$0.isImageItem },
                lastEditedAt: tab.lastEditedAt
            )
        }
        let payload = AppBackup(
            schemaVersion: 1,
            exportedAt: Date(),
            selectedTabId: selectedTabId,
            tabs: codableTabs,
            clipboardRichText: richText
        )
        return try JSONEncoder().encode(payload)
    }

    func importBackupData(_ data: Data) throws {
        let payload = try JSONDecoder().decode(AppBackup.self, from: data)
        for entry in payload.clipboardRichText ?? [] {
            richTextStore.save(entry.data, format: entry.format, for: entry.itemId)
        }
        tabs = payload.tabs.map {
            NoteTab(
                id: $0.id,
                content: $0.content,
                color: $0.color,
                title: $0.title,
                isLocked: $0.isLocked,
                kind: $0.kind,
                clipboardItems: $0.clipboardItems,
                lastEditedAt: $0.lastEditedAt
            )
        }
        pruneExpiredTabs(persist: false)
        ensureSpecialTabs()
        if tabs.isEmpty {
            tabs = [NoteTab()]
        }
        if let candidate = payload.selectedTabId,
           tabs.contains(where: { $0.id == candidate }) {
            selectedTabId = candidate
        } else {
            selectedTabId = tabs.first?.id
        }
        saveTabs()
    }

    private func pruneExpiredTabs(persist: Bool = true, now: Date = Date()) {
        guard autoDeleteDays() > 0 else { return }
        let cutoff = autoDeleteCutoff(now: now)
        let expiredIds = Set<UUID>(
            tabs.compactMap { tab in
                guard tab.kind == .note, !tab.isLocked else { return nil }
                return tab.lastEditedAt < cutoff ? tab.id : nil
            }
        )
        guard !expiredIds.isEmpty else { return }
        tabs.removeAll { expiredIds.contains($0.id) }
        if let selected = selectedTabId, expiredIds.contains(selected) {
            selectedTabId = tabs.first?.id
        }
        if persist {
            saveWithDelay()
        }
    }

    private func autoDeleteCutoff(now: Date) -> Date {
        now.addingTimeInterval(-TimeInterval(autoDeleteDays() * 24 * 60 * 60))
    }

    func autoDeleteDays() -> Int {
        let value = UserDefaults.standard.integer(forKey: tabAutoDeleteDaysKey)
        if value <= 0 { return tabAutoDeleteDefaultDays }
        return value
    }

    func autoDeleteRotationDegrees(for tab: NoteTab, now: Date = Date()) -> Double {
        guard tab.kind == .note, !tab.isLocked else { return 0 }
        let days = autoDeleteDays()
        guard days > 0 else { return 0 }
        let total = TimeInterval(days * 24 * 60 * 60)
        let elapsed = max(0, now.timeIntervalSince(tab.lastEditedAt))
        let remaining = max(0, total - elapsed)
        let fraction = remaining / total
        return fraction * 360
    }

    func displayTitle(for tab: NoteTab) -> String {
        if tab.kind == .clipboard {
            return "Clipboard"
        }
        if tab.kind == .expansions {
            return "Text Expansions"
        }
        if let title = tab.title, !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return title
        }
        let lines = tab.content.components(separatedBy: .newlines)
        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmed.isEmpty {
                return trimmed
            }
        }
        if let index = tabs.firstIndex(where: { $0.id == tab.id }) {
            return "Tab \(index + 1)"
        }
        return "Tab"
    }

    private func startClipboardMonitor() {
        lastClipboardChangeCount = NSPasteboard.general.changeCount
        clipboardTimer?.invalidate()
        clipboardTimer = Timer.scheduledTimer(withTimeInterval: 0.7, repeats: true) { [weak self] _ in
            guard let self else { return }
            Task { @MainActor in
                self.pollClipboard()
            }
        }
        if let timer = clipboardTimer {
            RunLoop.main.add(timer, forMode: .common)
        }
    }

    private func pollClipboard() {
        let pasteboard = NSPasteboard.general
        let changeCount = pasteboard.changeCount
        guard changeCount != lastClipboardChangeCount else { return }
        lastClipboardChangeCount = changeCount

        let types = (pasteboard.types ?? []).map(\.rawValue)
        let sourceApp = currentClipboardSourceApp()
        guard shouldRecord(pasteboardTypes: types, sourceBundleId: sourceApp?.bundleIdentifier) else { return }

        // Files (Finder copies them together with their names as text): keep the paths.
        if let urls = pasteboard.readObjects(forClasses: [NSURL.self], options: [.urlReadingFileURLsOnly: true]) as? [URL],
           !urls.isEmpty {
            let paths = urls.map(\.path)
            let key = paths.joined(separator: "\n")
            guard key != lastClipboardString else { return }
            lastClipboardString = key
            appendClipboardItem(
                urls.map(\.lastPathComponent).joined(separator: "\n"),
                sourceApp: sourceApp,
                pasteboardTypes: types,
                filePaths: paths
            )
            return
        }

        // Images: screenshots and "Copy Image". Text that comes with a picture of itself
        // (Word, Numbers, …) stays text; a bare URL next to an image is the image's address.
        let string = pasteboard.string(forType: .string)
        if string.map({ ClipboardFormats.webURL(in: $0) != nil }) ?? true,
           let imageData = ClipboardImageStore.imageData(on: pasteboard) {
            guard saveImagesEnabled else { return }
            Task.detached(priority: .userInitiated) {
                let processed = ClipboardImageStore.process(imageData)
                await MainActor.run {
                    guard let processed else { return }
                    self.appendImageItem(processed, sourceApp: sourceApp, pasteboardTypes: types)
                }
            }
            return
        }

        guard let text = string else { return }
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        if trimmed == lastClipboardString {
            return
        }
        lastClipboardString = trimmed
        appendClipboardItem(
            trimmed,
            sourceApp: sourceApp,
            pasteboardTypes: types,
            richText: ClipboardRichTextStore.formats(on: pasteboard),
            link: ClipboardFormats.copiedLink(on: pasteboard)
        )
    }

    private var saveImagesEnabled: Bool {
        UserDefaults.standard.object(forKey: Self.clipboardSaveImagesKey) as? Bool ?? true
    }

    private func appendImageItem(
        _ image: ClipboardImageStore.ProcessedImage,
        sourceApp: NSRunningApplication?,
        pasteboardTypes: [String]
    ) {
        let key = Self.imageClipboardKey(image.info.hash)
        guard key != lastClipboardString else { return }
        lastClipboardString = key
        guard let index = tabs.firstIndex(where: { $0.kind == .clipboard }) else { return }
        var items = tabs[index].clipboardItems

        let isSame: (ClipboardItem) -> Bool = { $0.imageInfo?.hash == image.info.hash }
        if items.contains(where: { $0.pinnedSlot != nil && isSame($0) }) {
            return
        }
        if let existingIndex = items.firstIndex(where: isSame) {
            items.remove(at: existingIndex)
        }

        let item = ClipboardItem(
            text: "Image \(image.info.width) × \(image.info.height)",
            sourceAppName: sourceApp?.localizedName,
            sourceAppBundleId: sourceApp?.bundleIdentifier,
            pasteboardTypes: pasteboardTypes,
            imageInfo: image.info
        )
        guard imageStore.save(image, for: item.id) else { return }
        items.insert(item, at: 0)

        items = orderedClipboardItems(items)
        items = trimClipboardItems(items)
        tabs[index].clipboardItems = items
        saveWithDelay()
    }

    /// Marks an image as already seen, so xNotes' own pastes aren't recorded again.
    private static func imageClipboardKey(_ hash: String) -> String { "image:" + hash }

    /// Follows the nspasteboard.org markers: transient and auto-generated content is
    /// never recorded, concealed content (passwords) only if enabled in Settings.
    /// Copies from password apps that don't mark their entries count as concealed.
    private func shouldRecord(pasteboardTypes types: [String], sourceBundleId: String?) -> Bool {
        if types.contains(where: { ClipboardFormats.transientTypes.contains($0) || ClipboardFormats.autoGeneratedTypes.contains($0) }) {
            return false
        }
        let fromPasswordApp = sourceBundleId.map(ClipboardFormats.passwordSourceApps.contains) ?? false
        if fromPasswordApp || types.contains(where: ClipboardFormats.concealedTypes.contains) {
            return UserDefaults.standard.bool(forKey: Self.clipboardSaveSensitiveKey)
        }
        return true
    }

    private func appendClipboardItem(
        _ text: String,
        sourceApp: NSRunningApplication?,
        pasteboardTypes: [String],
        filePaths: [String] = [],
        richText: [ClipboardRichTextStore.Format: Data] = [:],
        link: (url: String, title: String?)? = nil
    ) {
        guard let index = tabs.firstIndex(where: { $0.kind == .clipboard }) else { return }
        var items = tabs[index].clipboardItems

        let isSame: (ClipboardItem) -> Bool = { $0.text == text && $0.filePaths == filePaths }
        if items.contains(where: { $0.pinnedSlot != nil && isSame($0) }) {
            return
        }

        if let existingIndex = items.firstIndex(where: isSame) {
            items.remove(at: existingIndex)
        }
        items.insert(
            ClipboardItem(
                text: text,
                sourceAppName: sourceApp?.localizedName,
                sourceAppBundleId: sourceApp?.bundleIdentifier,
                pasteboardTypes: pasteboardTypes,
                filePaths: filePaths,
                richTextFormats: ClipboardRichTextStore.Format.allCases.filter { richText[$0] != nil },
                copiedLinkURL: link?.url,
                copiedLinkTitle: link?.title
            ),
            at: 0
        )
        for (format, data) in richText {
            richTextStore.save(data, format: format, for: items[0].id)
        }

        items = orderedClipboardItems(items)
        items = trimClipboardItems(items)

        tabs[index].clipboardItems = items
        saveWithDelay()
    }

    func clipboardText(for itemId: ClipboardItem.ID) -> String? {
        guard let index = tabs.firstIndex(where: { $0.kind == .clipboard }) else { return nil }
        return tabs[index].clipboardItems.first(where: { $0.id == itemId })?.text
    }

    func clipboardItem(id: ClipboardItem.ID) -> ClipboardItem? {
        tabs.first(where: { $0.kind == .clipboard })?.clipboardItems.first(where: { $0.id == id })
    }

    func appendClipboardItemToTab(itemId: ClipboardItem.ID, tabId: UUID) {
        // Notes are Markdown text; images can't go there.
        guard let item = clipboardItem(id: itemId), !item.isImageItem else { return }
        // Files go into the note as their full paths, links as Markdown links.
        if item.isFileItem {
            appendText(item.filePaths.joined(separator: "\n"), toTab: tabId)
        } else if item.isLink {
            Task {
                if let markdownLink = await markdownLink(forItem: itemId) {
                    appendText(markdownLink, toTab: tabId)
                }
            }
        } else {
            appendText(item.text, toTab: tabId)
        }
    }

    /// `[Title](url)` for a link entry. Without a known title the page is loaded once
    /// to read it (and the title is kept); if that fails, the domain is used.
    func markdownLink(forItem itemId: ClipboardItem.ID) async -> String? {
        guard let item = clipboardItem(id: itemId), let url = item.linkURL else { return nil }
        if item.linkTitle == nil, item.text == item.originalText {
            TransformRegistry.shared.show("Loading page title…")
            if let title = await LinkTitleFetcher.title(for: url) {
                setLinkTitle(title, forItem: itemId)
            }
        }
        return clipboardItem(id: itemId)?.markdownLink ?? item.markdownLink
    }

    private func setLinkTitle(_ title: String, forItem itemId: ClipboardItem.ID) {
        guard let index = tabs.firstIndex(where: { $0.kind == .clipboard }),
              let itemIndex = tabs[index].clipboardItems.firstIndex(where: { $0.id == itemId }) else { return }
        tabs[index].clipboardItems[itemIndex].copiedLinkTitle = title
        saveWithDelay()
    }

    private func appendText(_ text: String, toTab tabId: UUID) {
        guard let index = tabs.firstIndex(where: { $0.id == tabId }) else { return }
        guard tabs[index].kind == .note else { return }
        let existing = tabs[index].content
        let separator = existing.isEmpty ? "" : "\n"
        tabs[index].content = existing + separator + text
        tabs[index].lastEditedAt = Date()
        saveWithDelay()
    }

    func replaceClipboardItem(id: ClipboardItem.ID, with text: String, updatePasteboard: Bool = true) {
        guard let index = tabs.firstIndex(where: { $0.kind == .clipboard }) else { return }
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        var items = tabs[index].clipboardItems
        guard let existingIndex = items.firstIndex(where: { $0.id == id }) else { return }

        if let duplicateIndex = items.firstIndex(where: { $0.text == trimmed }), duplicateIndex != existingIndex {
            items.remove(at: duplicateIndex)
        }

        items[existingIndex].text = trimmed
        items = orderedClipboardItems(items)
        items = trimClipboardItems(items)

        tabs[index].clipboardItems = items
        saveWithDelay()

        if updatePasteboard {
            lastClipboardString = trimmed
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(trimmed, forType: .string)
        }
    }

    func removeClipboardItem(id: ClipboardItem.ID) {
        guard let index = tabs.firstIndex(where: { $0.kind == .clipboard }) else { return }
        var items = tabs[index].clipboardItems
        items.removeAll { $0.id == id && $0.pinnedSlot == nil }
        tabs[index].clipboardItems = items
        saveWithDelay()
    }

    func clearClipboardHistory() {
        guard let index = tabs.firstIndex(where: { $0.kind == .clipboard }) else { return }
        tabs[index].clipboardItems.removeAll { $0.pinnedSlot == nil }
        saveWithDelay()
    }

    func pinClipboardItem(id: ClipboardItem.ID, slot: Int) {
        guard (1...9).contains(slot) else { return }
        guard let index = tabs.firstIndex(where: { $0.kind == .clipboard }) else { return }
        var items = tabs[index].clipboardItems

        if let existingSlotIndex = items.firstIndex(where: { $0.pinnedSlot == slot }) {
            items[existingSlotIndex].pinnedSlot = nil
        }

        guard let targetIndex = items.firstIndex(where: { $0.id == id }) else { return }
        items[targetIndex].pinnedSlot = slot

        items = orderedClipboardItems(items)
        items = trimClipboardItems(items)
        tabs[index].clipboardItems = items
        saveWithDelay()
    }

    func pinClipboardItemToNextFreeSlot(id: ClipboardItem.ID) {
        guard let index = tabs.firstIndex(where: { $0.kind == .clipboard }) else { return }
        let items = tabs[index].clipboardItems
        let usedSlots = Set(items.compactMap { $0.pinnedSlot })
        let nextSlot = (1...9).first { !usedSlots.contains($0) }
        guard let slot = nextSlot else { return }
        pinClipboardItem(id: id, slot: slot)
    }

    func unpinClipboardItem(id: ClipboardItem.ID) {
        guard let index = tabs.firstIndex(where: { $0.kind == .clipboard }) else { return }
        var items = tabs[index].clipboardItems
        guard let targetIndex = items.firstIndex(where: { $0.id == id }) else { return }
        items[targetIndex].pinnedSlot = nil
        items = orderedClipboardItems(items)
        items = trimClipboardItems(items)
        tabs[index].clipboardItems = items
        saveWithDelay()
    }

    func pastePinnedSlot(_ slot: Int) -> Bool {
        guard (1...9).contains(slot) else { return false }
        guard let index = tabs.firstIndex(where: { $0.kind == .clipboard }) else { return false }
        guard let item = tabs[index].clipboardItems.first(where: { $0.pinnedSlot == slot }) else { return false }
        return pasteClipboardItemIntoLastApp(item)
    }

    /// Puts the item on the clipboard the way it was copied: files as files, text as text.
    /// `text` overrides the item's text (e.g. its original before edits).
    /// Files that no longer exist are left out and reported; returns false if nothing is left.
    @discardableResult
    func writeClipboardItemToPasteboard(_ item: ClipboardItem, text: String? = nil) -> Bool {
        var item = item
        if item.isFileItem {
            guard let existing = itemKeepingExistingFiles(item) else { return false }
            item = existing
        }
        if let imageInfo = item.imageInfo {
            guard let png = imageStore.imageData(for: item.id) else {
                NSSound.beep()
                TransformRegistry.shared.show("The image file of this entry is missing.", isError: true)
                return false
            }
            let pasteboard = NSPasteboard.general
            pasteboard.clearContents()
            pasteboard.setData(png, forType: .png)
            // Older apps only read TIFF.
            if let tiff = NSBitmapImageRep(data: png)?.tiffRepresentation {
                pasteboard.setData(tiff, forType: .tiff)
            }
            lastClipboardString = Self.imageClipboardKey(imageInfo.hash)
            return true
        }
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        if item.isFileItem {
            // Like the Finder: each file as a file URL plus its name as text, so text-only
            // targets get the names instead of nothing.
            let pasteboardItems = item.fileURLs.map { url -> NSPasteboardItem in
                let pasteboardItem = NSPasteboardItem()
                pasteboardItem.setString(url.absoluteString, forType: .fileURL)
                pasteboardItem.setString(url.lastPathComponent, forType: .string)
                return pasteboardItem
            }
            pasteboard.writeObjects(pasteboardItems)
            lastClipboardString = item.filePaths.joined(separator: "\n")
        } else {
            let value = text ?? item.text
            pasteboard.setString(value, forType: .string)
            // The formatted versions and the link belong to the text as copied.
            if value == item.originalText {
                for format in item.richTextFormats {
                    if let data = richTextStore.data(format: format, for: item.id) {
                        pasteboard.setData(data, forType: format.pasteboardType)
                    }
                }
                if let url = item.linkURL {
                    pasteboard.setString(url.absoluteString, forType: .URL)
                    if let title = item.linkTitle {
                        pasteboard.setString(title, forType: ClipboardFormats.urlNameType)
                    }
                }
            }
            lastClipboardString = value
        }
        return true
    }

    /// The item reduced to the files that still exist. Missing files are reported in the
    /// clipboard banner; returns nil (and beeps) when none of them exists any more.
    /// Otherwise the Finder would only get the names and create a text clipping.
    private func itemKeepingExistingFiles(_ item: ClipboardItem) -> ClipboardItem? {
        let existing = item.filePaths.filter { FileManager.default.fileExists(atPath: $0) }
        let missing = item.filePaths.filter { !existing.contains($0) }
        guard !missing.isEmpty else { return item }

        let missingNames = missing.map { ($0 as NSString).lastPathComponent }
        if existing.isEmpty {
            NSSound.beep()
            let message = missing.count == 1
                ? "“\(missingNames[0])” no longer exists at its original location."
                : "None of the \(missing.count) files exists at its original location any more."
            TransformRegistry.shared.show(message, isError: true)
            return nil
        }
        TransformRegistry.shared.show(
            "Skipped \(missing.count) missing \(missing.count == 1 ? "file" : "files"): \(missingNames.joined(separator: ", "))",
            isError: true
        )
        return ClipboardItem(
            id: item.id,
            text: existing.map { ($0 as NSString).lastPathComponent }.joined(separator: "\n"),
            date: item.date,
            sourceAppName: item.sourceAppName,
            sourceAppBundleId: item.sourceAppBundleId,
            pasteboardTypes: item.pasteboardTypes,
            filePaths: existing
        )
    }

    /// Pastes the item into the last active app: files as files; text with its formatting
    /// unless "Paste as Plain Text" is on (`asPlainText` overrides the setting).
    func pasteClipboardItemIntoLastApp(_ item: ClipboardItem, asPlainText: Bool? = nil) -> Bool {
        if item.isTextItem {
            let plain = asPlainText ?? UserDefaults.standard.bool(forKey: pasteAsPlainTextKey)
            // Links go on the clipboard as links too, so Mail, Notes etc. can show the title.
            guard !plain, item.canPasteRichText || (item.isLink && item.text == item.originalText) else {
                return pasteTextIntoLastApp(item.text)
            }
        }
        guard ensureAccessibilityPermission() else { return false }
        guard writeClipboardItemToPasteboard(item) else { return false }
        return sendPasteToLastApp()
    }

    /// Puts derived text (e.g. a Markdown link) on the clipboard without adding it to the history.
    func copyTextToPasteboard(_ text: String) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
        lastClipboardString = text
    }

    func pasteTextIntoLastApp(_ text: String) -> Bool {
        guard ensureAccessibilityPermission() else { return false }
        let preparedText = prepareTextForPaste(text)

        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(preparedText, forType: .string)
        lastClipboardString = preparedText

        return sendPasteToLastApp()
    }

    /// Hides the panel, activates the last app and sends ⌘V.
    private func sendPasteToLastApp() -> Bool {
        NotificationCenter.default.post(name: AppDelegate.closePopoverNotification, object: nil)

        let targetApp = resolvePasteTargetApp()
        guard let target = targetApp else { return false }
        NSLog("Paste target: %@", target.localizedName ?? "Unknown App")
        _ = target.activate(options: [.activateAllWindows])
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
            let source = CGEventSource(stateID: .combinedSessionState)
            let keyDown = CGEvent(keyboardEventSource: source, virtualKey: CGKeyCode(kVK_ANSI_V), keyDown: true)
            keyDown?.flags = .maskCommand
            let keyUp = CGEvent(keyboardEventSource: source, virtualKey: CGKeyCode(kVK_ANSI_V), keyDown: false)
            keyUp?.flags = .maskCommand
            keyDown?.post(tap: .cghidEventTap)
            keyUp?.post(tap: .cghidEventTap)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                NotificationCenter.default.post(name: AppDelegate.reopenPopoverNotification, object: nil)
            }
        }

        return true
    }

    func searchResults(for query: String) -> [SearchResult] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return [] }
        let options: String.CompareOptions = [.caseInsensitive, .diacriticInsensitive]
        var results: [SearchResult] = []

        for (index, tab) in tabs.enumerated() {
            switch tab.kind {
            case .note:
                let title = resolvedTitle(for: tab, index: index)
                let ranges = matchRanges(of: trimmed, in: tab.content, options: options)
                if ranges.isEmpty {
                    if title.range(of: trimmed, options: options) != nil {
                        results.append(SearchResult(tabId: tab.id, tabTitle: title, clipboardItemId: nil, range: nil))
                    }
                } else {
                    for range in ranges {
                        results.append(SearchResult(tabId: tab.id, tabTitle: title, clipboardItemId: nil, range: range))
                    }
                }
            case .clipboard:
                let title = displayTitle(for: tab)
                for item in tab.clipboardItems where item.searchableText.range(of: trimmed, options: options) != nil {
                    results.append(SearchResult(tabId: tab.id, tabTitle: title, clipboardItemId: item.id, range: nil))
                }
            case .expansions:
                continue
            }
        }
        return results
    }

    private func matchRanges(of needle: String, in content: String, options: String.CompareOptions) -> [NSRange] {
        let nsContent = content as NSString
        var ranges: [NSRange] = []
        var searchRange = NSRange(location: 0, length: nsContent.length)
        while searchRange.length > 0 {
            let found = nsContent.range(of: needle, options: options, range: searchRange)
            guard found.location != NSNotFound, found.length > 0 else { break }
            ranges.append(found)
            let nextLocation = found.location + found.length
            searchRange = NSRange(location: nextLocation, length: nsContent.length - nextLocation)
        }
        return ranges
    }

    private func ensureAccessibilityPermission() -> Bool {
        if AXIsProcessTrusted() {
            return true
        }
        let options: NSDictionary = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as NSString: true]
        _ = AXIsProcessTrustedWithOptions(options)
        NSLog("Accessibility permission is required to paste into other apps.")
        return false
    }

    private func resolvePasteTargetApp() -> NSRunningApplication? {
        if let app = lastNonXNotesApp {
            return app
        }
        if let frontmost = NSWorkspace.shared.frontmostApplication,
           frontmost.bundleIdentifier != Bundle.main.bundleIdentifier {
            return frontmost
        }
        return nil
    }

    private func prepareTextForPaste(_ text: String) -> String {
        guard UserDefaults.standard.bool(forKey: pasteAsPlainTextKey) else {
            return text
        }

        var result = text
        if UserDefaults.standard.object(forKey: pasteNormalizeLFKey) == nil {
            UserDefaults.standard.set(true, forKey: pasteNormalizeLFKey)
        }
        if UserDefaults.standard.object(forKey: pasteTrimTrailingWhitespaceKey) == nil {
            UserDefaults.standard.set(true, forKey: pasteTrimTrailingWhitespaceKey)
        }
        if UserDefaults.standard.bool(forKey: pasteNormalizeLFKey) {
            result = result.replacingOccurrences(of: "\r\n", with: "\n")
                .replacingOccurrences(of: "\r", with: "\n")
        }
        if UserDefaults.standard.bool(forKey: pasteTrimTrailingWhitespaceKey) {
            result = result
                .components(separatedBy: "\n")
                .map { $0.replacingOccurrences(of: #"[ \t]+$"#, with: "", options: .regularExpression) }
                .joined(separator: "\n")
        }
        return result
    }

    private func resolvedTitle(for tab: NoteTab, index: Int) -> String {
        if let title = tab.title, !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return title
        }
        for line in tab.content.components(separatedBy: .newlines) {
            let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmed.isEmpty {
                return trimmed
            }
        }
        return "Tab \(index + 1)"
    }

    private func currentClipboardSourceApp() -> NSRunningApplication? {
        if let frontmost = NSWorkspace.shared.frontmostApplication,
           frontmost.bundleIdentifier != Bundle.main.bundleIdentifier {
            return frontmost
        }
        return lastNonXNotesApp
    }

    private func orderedClipboardItems(_ items: [ClipboardItem]) -> [ClipboardItem] {
        let pinned = items
            .filter { $0.pinnedSlot != nil }
            .sorted { ($0.pinnedSlot ?? 0) < ($1.pinnedSlot ?? 0) }
        let unpinned = items
            .filter { $0.pinnedSlot == nil }
            .sorted { $0.date > $1.date }
        return pinned + unpinned
    }

    private func trimClipboardItems(_ items: [ClipboardItem]) -> [ClipboardItem] {
        let maxItems = resolvedClipboardMaxItems()
        if items.count <= maxItems {
            return items
        }
        let pinned = items.filter { $0.pinnedSlot != nil }
        let remaining = max(0, maxItems - pinned.count)
        let unpinned = items.filter { $0.pinnedSlot == nil }
        return pinned + Array(unpinned.prefix(remaining))
    }

    private func trackLastActiveApp() {
        let center = NSWorkspace.shared.notificationCenter
        center.addObserver(forName: NSWorkspace.didActivateApplicationNotification, object: nil, queue: .main) { [weak self] notification in
            guard let self else { return }
            guard let app = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication else { return }
            guard app.bundleIdentifier != Bundle.main.bundleIdentifier else { return }
            Task { @MainActor in
                self.lastNonXNotesApp = app
            }
        }
    }

    private func resolvedClipboardMaxItems() -> Int {
        let value = UserDefaults.standard.integer(forKey: clipboardMaxItemsKey)
        if value <= 0 {
            return 200
        }
        return max(10, value)
    }
}
