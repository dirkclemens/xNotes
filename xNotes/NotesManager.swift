//
//  NotesManager.swift
//  xNotes
//
//  Created by Dirk Clemens on 15.01.26.
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
    private let clipboardMaxItemsKey = "clipboardMaxItems"
    private let pasteAsPlainTextKey = "pasteAsPlainText"
    private let pasteNormalizeLFKey = "pasteNormalizeLF"
    private let pasteTrimTrailingWhitespaceKey = "pasteTrimTrailingWhitespace"
    private var clipboardTimer: Timer?
    private var lastClipboardChangeCount: Int = 0
    private var lastClipboardString: String?
    private var lastNonXNotesApp: NSRunningApplication?
    
    init() {
        loadTabs()
        ensureClipboardTab()
        if tabs.isEmpty {
            tabs = [NoteTab()]
        }
        selectedTabId = tabs.first?.id
        trackLastActiveApp()
        startClipboardMonitor()
    }
    
    func addTab() {
        let newTab = NoteTab()
        if let index = tabs.firstIndex(where: { $0.kind == .clipboard }) {
            tabs.insert(newTab, at: min(index + 1, tabs.count))
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
        guard tab.kind != .clipboard else { return }
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
            saveWithDelay()
        }
    }
    
    func updateColor(for tabId: UUID, color: Double) {
        if let index = tabs.firstIndex(where: { $0.id == tabId }) {
            tabs[index].color = color
            saveWithDelay()
        }
    }
    
    func updateTitle(for tabId: UUID, title: String?) {
        if let index = tabs.firstIndex(where: { $0.id == tabId }) {
            guard tabs[index].kind != .clipboard else { return }
            tabs[index].title = title
            saveWithDelay()
        }
    }

    func updateLocked(for tabId: UUID, isLocked: Bool) {
        if let index = tabs.firstIndex(where: { $0.id == tabId }) {
            guard tabs[index].kind != .clipboard else { return }
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
                self.saveTabs()
            }
        }
    }
    
    private func saveTabs() {
        let codableTabs = tabs.map { tab in
            NoteTab(
                id: tab.id,
                content: tab.content,
                color: tab.color,
                title: tab.title,
                isLocked: tab.isLocked,
                kind: tab.kind,
                clipboardItems: tab.clipboardItems
            )
        }
        if let encoded = try? JSONEncoder().encode(codableTabs) {
            UserDefaults.standard.set(encoded, forKey: storageKey)
        }
    }
    private func loadTabs() {
        if let data = UserDefaults.standard.data(forKey: storageKey),
           let decoded = try? JSONDecoder().decode([NoteTab].self, from: data) {
            tabs = decoded.map {
                NoteTab(
                    id: $0.id,
                    content: $0.content,
                    color: $0.color,
                    title: $0.title,
                    isLocked: $0.isLocked,
                    kind: $0.kind,
                    clipboardItems: $0.clipboardItems
                )
            }
        }
    }

    private func ensureClipboardTab() {
        if let index = tabs.firstIndex(where: { $0.kind == .clipboard }) {
            tabs[index].isLocked = true
            tabs[index].title = "Clipboard"
            if index != 0 {
                let clipboardTab = tabs.remove(at: index)
                tabs.insert(clipboardTab, at: 0)
            }
        } else {
            let clipboardTab = NoteTab(
                content: "",
                color: 0.6,
                title: "Clipboard",
                isLocked: true,
                kind: .clipboard,
                clipboardItems: []
            )
            tabs.insert(clipboardTab, at: 0)
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
                clipboardItems: tab.clipboardItems
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
                clipboardItems: $0.clipboardItems
            )
        }
        ensureClipboardTab()
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

    func urlEncodeClipboardItem(id: ClipboardItem.ID) {
        transformClipboardItem(id: id) { text in
            text.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed)
        }
    }

    func urlDecodeClipboardItem(id: ClipboardItem.ID) {
        transformClipboardItem(id: id) { text in
            text.removingPercentEncoding
        }
    }

    func jsonPrettyPrintClipboardItem(id: ClipboardItem.ID) {
        transformClipboardItem(id: id) { text in
            guard let data = text.data(using: .utf8),
                  let object = try? JSONSerialization.jsonObject(with: data),
                  let pretty = try? JSONSerialization.data(withJSONObject: object, options: [.prettyPrinted, .sortedKeys]) else {
                return nil
            }
            return String(data: pretty, encoding: .utf8)
        }
    }

    func jsonMinifyClipboardItem(id: ClipboardItem.ID) {
        transformClipboardItem(id: id) { text in
            guard let data = text.data(using: .utf8),
                  let object = try? JSONSerialization.jsonObject(with: data),
                  let compact = try? JSONSerialization.data(withJSONObject: object, options: [.sortedKeys]) else {
                return nil
            }
            return String(data: compact, encoding: .utf8)
        }
    }

    func base64EncodeClipboardItem(id: ClipboardItem.ID) {
        transformClipboardItem(id: id) { text in
            Data(text.utf8).base64EncodedString()
        }
    }

    func base64DecodeClipboardItem(id: ClipboardItem.ID) {
        transformClipboardItem(id: id) { text in
            guard let data = Data(base64Encoded: text),
                  let decoded = String(data: data, encoding: .utf8) else {
                return nil
            }
            return decoded
        }
    }

    func sortLinesClipboardItem(id: ClipboardItem.ID) {
        transformClipboardItem(id: id) { text in
            text.components(separatedBy: .newlines)
                .sorted { $0.localizedCaseInsensitiveCompare($1) == .orderedAscending }
                .joined(separator: "\n")
        }
    }

    func uniqueLinesClipboardItem(id: ClipboardItem.ID) {
        transformClipboardItem(id: id) { text in
            var seen = Set<String>()
            return text.components(separatedBy: .newlines)
                .filter { seen.insert($0).inserted }
                .joined(separator: "\n")
        }
    }

    func trimEachLineClipboardItem(id: ClipboardItem.ID) {
        transformClipboardItem(id: id) { text in
            text.components(separatedBy: .newlines)
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .joined(separator: "\n")
        }
    }

    func convertToLFClipboardItem(id: ClipboardItem.ID) {
        transformClipboardItem(id: id) { text in
            text.replacingOccurrences(of: "\r\n", with: "\n")
                .replacingOccurrences(of: "\r", with: "\n")
        }
    }

    func convertToCRLFClipboardItem(id: ClipboardItem.ID) {
        transformClipboardItem(id: id) { text in
            let lf = text.replacingOccurrences(of: "\r\n", with: "\n")
                .replacingOccurrences(of: "\r", with: "\n")
            return lf.replacingOccurrences(of: "\n", with: "\r\n")
        }
    }

    func escapeShellClipboardItem(id: ClipboardItem.ID) {
        transformClipboardItem(id: id) { text in
            "'\(text.replacingOccurrences(of: "'", with: "'\"'\"'"))'"
        }
    }

    func escapeJSONStringClipboardItem(id: ClipboardItem.ID) {
        transformClipboardItem(id: id) { text in
            guard let data = try? JSONEncoder().encode(text),
                  let encoded = String(data: data, encoding: .utf8) else {
                return nil
            }
            return encoded
        }
    }

    func toSnakeCaseClipboardItem(id: ClipboardItem.ID) {
        transformClipboardItem(id: id) { text in
            let words = self.words(from: text)
            return words.joined(separator: "_")
        }
    }

    func toKebabCaseClipboardItem(id: ClipboardItem.ID) {
        transformClipboardItem(id: id) { text in
            let words = self.words(from: text)
            return words.joined(separator: "-")
        }
    }

    func toCamelCaseClipboardItem(id: ClipboardItem.ID) {
        transformClipboardItem(id: id) { text in
            let words = self.words(from: text)
            guard let first = words.first else { return nil }
            let tail = words.dropFirst().map { $0.prefix(1).uppercased() + $0.dropFirst() }
            return ([first] + tail).joined()
        }
    }

    func reverseLinesClipboardItem(id: ClipboardItem.ID) {
        transformClipboardItem(id: id) { text in
            text.components(separatedBy: .newlines).reversed().joined(separator: "\n")
        }
    }

    func wrapInQuotesClipboardItem(id: ClipboardItem.ID) {
        transformClipboardItem(id: id) { text in
            "\"\(text)\""
        }
    }

    func unquoteClipboardItem(id: ClipboardItem.ID) {
        transformClipboardItem(id: id) { text in
            if text.hasPrefix("\""), text.hasSuffix("\""), text.count >= 2 {
                return String(text.dropFirst().dropLast())
            }
            if text.hasPrefix("'"), text.hasSuffix("'"), text.count >= 2 {
                return String(text.dropFirst().dropLast())
            }
            return nil
        }
    }

    func addPrefixClipboardItem(id: ClipboardItem.ID) {
        guard let prefix = promptForText(title: "Add Prefix", message: "Prefix:") else { return }
        transformClipboardItem(id: id) { text in
            "\(prefix)\(text)"
        }
    }

    func removePrefixClipboardItem(id: ClipboardItem.ID) {
        guard let prefix = promptForText(title: "Remove Prefix", message: "Prefix:") else { return }
        transformClipboardItem(id: id) { text in
            text.hasPrefix(prefix) ? String(text.dropFirst(prefix.count)) : nil
        }
    }

    func addSuffixClipboardItem(id: ClipboardItem.ID) {
        guard let suffix = promptForText(title: "Add Suffix", message: "Suffix:") else { return }
        transformClipboardItem(id: id) { text in
            "\(text)\(suffix)"
        }
    }

    func removeSuffixClipboardItem(id: ClipboardItem.ID) {
        guard let suffix = promptForText(title: "Remove Suffix", message: "Suffix:") else { return }
        transformClipboardItem(id: id) { text in
            text.hasSuffix(suffix) ? String(text.dropLast(suffix.count)) : nil
        }
    }

    func extractEmailsClipboardItem(id: ClipboardItem.ID) {
        transformClipboardItem(id: id) { text in
            self.extractedEmails(in: text)
                .joined(separator: "\n")
        }
    }

    func extractURLsClipboardItem(id: ClipboardItem.ID) {
        transformClipboardItem(id: id) { text in
            self.extractedURLs(in: text)
                .joined(separator: "\n")
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

    private func transformClipboardItem(id: ClipboardItem.ID, transform: (String) -> String?) {
        guard let current = clipboardText(for: id) else { return }
        guard let updated = transform(current), updated != current else { return }
        replaceClipboardItem(id: id, with: updated)
    }

    private func words(from text: String) -> [String] {
        let parts = text
            .replacingOccurrences(of: "_", with: " ")
            .replacingOccurrences(of: "-", with: " ")
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .flatMap { chunk -> [String] in
                guard !chunk.isEmpty else { return [] }
                let split = chunk.replacingOccurrences(
                    of: "([a-z0-9])([A-Z])",
                    with: "$1 $2",
                    options: .regularExpression
                )
                return split.split(separator: " ").map { $0.lowercased() }
            }
        return parts.filter { !$0.isEmpty }
    }

    private func promptForText(title: String, message: String) -> String? {
        let alert = NSAlert()
        alert.messageText = title
        alert.informativeText = message
        alert.addButton(withTitle: "OK")
        alert.addButton(withTitle: "Cancel")
        let field = NSTextField(frame: NSRect(x: 0, y: 0, width: 280, height: 24))
        alert.accessoryView = field
        let result = alert.runModal()
        guard result == .alertFirstButtonReturn else { return nil }
        return field.stringValue
    }

    private func extractedEmails(in text: String) -> [String] {
        let pattern = #"[A-Z0-9a-z._%+\-]+@[A-Za-z0-9.\-]+\.[A-Za-z]{2,}"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return [] }
        let range = NSRange(text.startIndex..<text.endIndex, in: text)
        let matches = regex.matches(in: text, range: range).compactMap { result -> String? in
            guard let r = Range(result.range, in: text) else { return nil }
            return String(text[r])
        }
        return Array(NSOrderedSet(array: matches)) as? [String] ?? matches
    }

    private func extractedURLs(in text: String) -> [String] {
        guard let detector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.link.rawValue) else { return [] }
        let range = NSRange(text.startIndex..<text.endIndex, in: text)
        let urls = detector.matches(in: text, options: [], range: range).compactMap { result -> String? in
            guard let url = result.url else { return nil }
            if url.scheme?.lowercased() == "mailto" { return nil }
            return url.absoluteString
        }
        return Array(NSOrderedSet(array: urls)) as? [String] ?? urls
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
        let needle = trimmed.lowercased()
        var results: [SearchResult] = []

        for (index, tab) in tabs.enumerated() where tab.kind == .note {
            let title = resolvedTitle(for: tab, index: index)
            let haystackTitle = title.lowercased()
            let haystackContent = tab.content.lowercased()
            guard haystackTitle.contains(needle) || haystackContent.contains(needle) else { continue }
            let snippet = makeSnippet(content: tab.content, needle: trimmed)
            results.append(SearchResult(tabId: tab.id, tabTitle: title, snippet: snippet))
        }
        return results
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

    private func makeSnippet(content: String, needle: String) -> String {
        let nsContent = content as NSString
        let range = nsContent.range(of: needle, options: .caseInsensitive)
        guard range.location != NSNotFound else {
            return content.prefix(120).description
        }
        let start = max(0, range.location - 30)
        let end = min(nsContent.length, range.location + range.length + 60)
        return nsContent.substring(with: NSRange(location: start, length: end - start))
            .replacingOccurrences(of: "\n", with: " ")
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
