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
    /// Link and title the source app put on the clipboard (e.g. Safari's address bar or
    /// "Copy Link"); nil for plain text, even if it is a URL (see `linkURL`).
    let copiedLinkURL: String?
    let copiedLinkTitle: String?

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
        richTextFormats: [ClipboardRichTextStore.Format] = [],
        copiedLinkURL: String? = nil,
        copiedLinkTitle: String? = nil
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
        self.copiedLinkURL = copiedLinkURL
        self.copiedLinkTitle = copiedLinkTitle
    }

    /// The web link this entry stands for: the copied link, or the text itself if it is
    /// a single http(s) URL. Edited entries only count if their new text is a URL.
    var linkURL: URL? {
        if text == originalText, let copiedLinkURL, let url = URL(string: copiedLinkURL) {
            return url
        }
        return ClipboardFormats.webURL(in: text)
    }

    /// Page or link title from the source app, as long as the entry is unedited.
    var linkTitle: String? {
        guard text == originalText, linkURL != nil,
              let title = copiedLinkTitle?.trimmingCharacters(in: .whitespacesAndNewlines),
              !title.isEmpty, title != text else { return nil }
        return title
    }

    var isLink: Bool { linkURL != nil }

    /// What the list shows: the link title if there is one, otherwise the text.
    var displayText: String { linkTitle ?? text }

    /// `[Title](url)` if there is a title, otherwise `<url>`.
    var markdownLink: String? {
        guard let url = linkURL else { return nil }
        let address = url.absoluteString
            .replacingOccurrences(of: " ", with: "%20")
            .replacingOccurrences(of: "(", with: "%28")
            .replacingOccurrences(of: ")", with: "%29")
        guard let title = linkTitle else { return "<\(address)>" }
        let escapedTitle = title
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "[", with: "\\[")
            .replacingOccurrences(of: "]", with: "\\]")
            .replacingOccurrences(of: "\n", with: " ")
        return "[\(escapedTitle)](\(address))"
    }

    /// Formatting is only valid for the text as copied; edited or transformed
    /// entries are pasted as plain text.
    var canPasteRichText: Bool { !richTextFormats.isEmpty && text == originalText }

    var isFileItem: Bool { !filePaths.isEmpty }

    var fileURLs: [URL] { filePaths.map { URL(fileURLWithPath: $0) } }

    /// Text that searches and filters match against; includes the full paths of files.
    var searchableText: String {
        if isFileItem {
            return text + "\n" + filePaths.joined(separator: "\n")
        }
        if let linkTitle, let linkURL {
            return text + "\n" + linkTitle + "\n" + linkURL.absoluteString
        }
        return text
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
        case copiedLinkURL = "linkURL"
        case copiedLinkTitle = "linkTitle"
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
        copiedLinkURL = try c.decodeIfPresent(String.self, forKey: .copiedLinkURL)
        copiedLinkTitle = try c.decodeIfPresent(String.self, forKey: .copiedLinkTitle)
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
        try c.encodeIfPresent(copiedLinkURL, forKey: .copiedLinkURL)
        try c.encodeIfPresent(copiedLinkTitle, forKey: .copiedLinkTitle)
    }
}
