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
    private lazy var tabsStore = TabsFileStore(legacyDefaultsKey: storageKey)
    private let clipboardMaxItemsKey = "clipboardMaxItems"
    private let pasteAsPlainTextKey = "pasteAsPlainText"
    private let pasteNormalizeLFKey = "pasteNormalizeLF"
    private let pasteTrimTrailingWhitespaceKey = "pasteTrimTrailingWhitespace"
    private let tabAutoDeleteDaysKey = "tabAutoDeleteDays"
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
        startClipboardMonitor()
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

    func exportBackupData() throws -> Data {
        let codableTabs = tabs.map { tab in
            NoteTab(
                id: tab.id,
                content: tab.content,
                color: tab.color,
                title: tab.title,
                isLocked: tab.isLocked,
                kind: tab.kind,
                clipboardItems: tab.clipboardItems,
                lastEditedAt: tab.lastEditedAt
            )
        }
        let payload = AppBackup(
            schemaVersion: 1,
            exportedAt: Date(),
            selectedTabId: selectedTabId,
            tabs: codableTabs
        )
        return try JSONEncoder().encode(payload)
    }

    func importBackupData(_ data: Data) throws {
        let payload = try JSONDecoder().decode(AppBackup.self, from: data)
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
        let days = autoDeleteDays()
        guard days > 0 else { return }
        let cutoff = now.addingTimeInterval(-TimeInterval(days * 24 * 60 * 60))
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

        guard let text = pasteboard.string(forType: .string) else { return }
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        if trimmed == lastClipboardString {
            return
        }
        lastClipboardString = trimmed
        appendClipboardItem(trimmed, sourceApp: currentClipboardSourceApp())
    }

    private func appendClipboardItem(_ text: String, sourceApp: NSRunningApplication?) {
        guard let index = tabs.firstIndex(where: { $0.kind == .clipboard }) else { return }
        var items = tabs[index].clipboardItems

        if items.contains(where: { $0.pinnedSlot != nil && $0.text == text }) {
            return
        }

        if let existingIndex = items.firstIndex(where: { $0.text == text }) {
            items.remove(at: existingIndex)
        }
        items.insert(
            ClipboardItem(
                text: text,
                sourceAppName: sourceApp?.localizedName,
                sourceAppBundleId: sourceApp?.bundleIdentifier
            ),
            at: 0
        )

        items = orderedClipboardItems(items)
        items = trimClipboardItems(items)

        tabs[index].clipboardItems = items
        saveWithDelay()
    }

    func clipboardText(for itemId: ClipboardItem.ID) -> String? {
        guard let index = tabs.firstIndex(where: { $0.kind == .clipboard }) else { return nil }
        return tabs[index].clipboardItems.first(where: { $0.id == itemId })?.text
    }

    func appendClipboardItemToTab(itemId: ClipboardItem.ID, tabId: UUID) {
        guard let text = clipboardText(for: itemId) else { return }
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

        let pinnedSlot = items[existingIndex].pinnedSlot
        let originalText = items[existingIndex].originalText
        items[existingIndex] = ClipboardItem(
            id: id,
            text: trimmed,
            originalText: originalText,
            date: items[existingIndex].date,
            pinnedSlot: pinnedSlot,
            sourceAppName: items[existingIndex].sourceAppName,
            sourceAppBundleId: items[existingIndex].sourceAppBundleId
        )
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
            let existingItem = items[existingSlotIndex]
            items[existingSlotIndex] = ClipboardItem(
                id: existingItem.id,
                text: existingItem.text,
                originalText: existingItem.originalText,
                date: existingItem.date,
                pinnedSlot: nil,
                sourceAppName: existingItem.sourceAppName,
                sourceAppBundleId: existingItem.sourceAppBundleId
            )
        }

        guard let targetIndex = items.firstIndex(where: { $0.id == id }) else { return }
        let target = items[targetIndex]
        items[targetIndex] = ClipboardItem(
            id: target.id,
            text: target.text,
            originalText: target.originalText,
            date: target.date,
            pinnedSlot: slot,
            sourceAppName: target.sourceAppName,
            sourceAppBundleId: target.sourceAppBundleId
        )

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
        let target = items[targetIndex]
        items[targetIndex] = ClipboardItem(
            id: target.id,
            text: target.text,
            originalText: target.originalText,
            date: target.date,
            pinnedSlot: nil,
            sourceAppName: target.sourceAppName,
            sourceAppBundleId: target.sourceAppBundleId
        )
        items = orderedClipboardItems(items)
        items = trimClipboardItems(items)
        tabs[index].clipboardItems = items
        saveWithDelay()
    }

    func pastePinnedSlot(_ slot: Int) -> Bool {
        guard (1...9).contains(slot) else { return false }
        guard let index = tabs.firstIndex(where: { $0.kind == .clipboard }) else { return false }
        guard let item = tabs[index].clipboardItems.first(where: { $0.pinnedSlot == slot }) else { return false }
        return pasteTextIntoLastApp(item.text)
    }

    func pasteTextIntoLastApp(_ text: String) -> Bool {
        guard ensureAccessibilityPermission() else { return false }
        let preparedText = prepareTextForPaste(text)

        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(preparedText, forType: .string)
        lastClipboardString = preparedText

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
                for item in tab.clipboardItems where item.text.range(of: trimmed, options: options) != nil {
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
