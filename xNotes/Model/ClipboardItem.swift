//
//  ClipboardItem.swift
//  xNotes
//

import Foundation

struct ClipboardItem: Identifiable, Codable, Equatable {
    let id: UUID
    var text: String
    let originalText: String
    let date: Date
    var pinnedSlot: Int?
    let sourceAppName: String?
    let sourceAppBundleId: String?
    /// Pasteboard types (UTIs) the source app offered when the item was copied,
    /// in the source app's order. Empty for items captured by older versions.
    let pasteboardTypes: [String]
    /// Paths of files copied in the Finder (or another app that copies files).
    /// Empty for text entries. `text` then holds the file names, one per line.
    let filePaths: [String]
    /// Formatted versions kept for this entry (stored by `ClipboardRichTextStore`).
    let richTextFormats: [ClipboardRichTextStore.Format]

    init(
        id: UUID = UUID(),
        text: String,
        originalText: String? = nil,
        date: Date = Date(),
        pinnedSlot: Int? = nil,
        sourceAppName: String? = nil,
        sourceAppBundleId: String? = nil,
        pasteboardTypes: [String] = [],
        filePaths: [String] = [],
        richTextFormats: [ClipboardRichTextStore.Format] = []
    ) {
        self.id = id
        self.text = text
        self.originalText = originalText ?? text
        self.date = date
        self.pinnedSlot = pinnedSlot
        self.sourceAppName = sourceAppName
        self.sourceAppBundleId = sourceAppBundleId
        self.pasteboardTypes = pasteboardTypes
        self.filePaths = filePaths
        self.richTextFormats = richTextFormats
    }

    /// Formatting is only valid for the text as copied; edited or transformed
    /// entries are pasted as plain text.
    var canPasteRichText: Bool { !richTextFormats.isEmpty && text == originalText }

    var isFileItem: Bool { !filePaths.isEmpty }

    var fileURLs: [URL] { filePaths.map { URL(fileURLWithPath: $0) } }

    /// Text that searches and filters match against; includes the full paths of files.
    var searchableText: String {
        isFileItem ? text + "\n" + filePaths.joined(separator: "\n") : text
    }

    /// The source app marked the entry as a password or other secret.
    var isMarkedConcealed: Bool {
        pasteboardTypes.contains(where: ClipboardFormats.concealedTypes.contains)
    }

    /// Copied from a password app that doesn't mark its entries (e.g. Apple's Passwords).
    var isFromPasswordApp: Bool {
        sourceAppBundleId.map(ClipboardFormats.passwordSourceApps.contains) ?? false
    }

    var isSensitive: Bool { isMarkedConcealed || isFromPasswordApp }

    enum CodingKeys: String, CodingKey {
        case id, text, originalText, date, pinnedSlot, sourceAppName, sourceAppBundleId, pasteboardTypes, filePaths, richTextFormats
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(UUID.self, forKey: .id)
        text = try c.decode(String.self, forKey: .text)
        originalText = try c.decodeIfPresent(String.self, forKey: .originalText) ?? text
        date = try c.decode(Date.self, forKey: .date)
        pinnedSlot = try c.decodeIfPresent(Int.self, forKey: .pinnedSlot)
        sourceAppName = try c.decodeIfPresent(String.self, forKey: .sourceAppName)
        sourceAppBundleId = try c.decodeIfPresent(String.self, forKey: .sourceAppBundleId)
        pasteboardTypes = try c.decodeIfPresent([String].self, forKey: .pasteboardTypes) ?? []
        filePaths = try c.decodeIfPresent([String].self, forKey: .filePaths) ?? []
        richTextFormats = try c.decodeIfPresent([ClipboardRichTextStore.Format].self, forKey: .richTextFormats) ?? []
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(id, forKey: .id)
        try c.encode(text, forKey: .text)
        try c.encode(originalText, forKey: .originalText)
        try c.encode(date, forKey: .date)
        try c.encode(pinnedSlot, forKey: .pinnedSlot)
        try c.encode(sourceAppName, forKey: .sourceAppName)
        try c.encode(sourceAppBundleId, forKey: .sourceAppBundleId)
        if !pasteboardTypes.isEmpty {
            try c.encode(pasteboardTypes, forKey: .pasteboardTypes)
        }
        if !filePaths.isEmpty {
            try c.encode(filePaths, forKey: .filePaths)
        }
        if !richTextFormats.isEmpty {
            try c.encode(richTextFormats, forKey: .richTextFormats)
        }
    }
}
