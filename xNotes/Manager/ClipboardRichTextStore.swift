//
//  ClipboardRichTextStore.swift
//  xNotes
//

import AppKit

/// Formatted versions (RTF, HTML) of clipboard entries, one file per entry and format in
/// `Application Support/<bundle id>/ClipboardRichText/`. They are kept out of `tabs.json`,
/// which is rewritten on every edit, because formatted copies (e.g. from web pages) get large.
final class ClipboardRichTextStore {
    enum Format: String, CaseIterable, Codable {
        case rtf
        case html

        var pasteboardType: NSPasteboard.PasteboardType {
            switch self {
            case .rtf: return .rtf
            case .html: return .html
            }
        }

        var displayName: String {
            switch self {
            case .rtf: return "RTF"
            case .html: return "HTML"
            }
        }
    }

    /// Larger formatted versions are dropped; the entry is then kept as plain text only.
    static let maxBytesPerFormat = 1_000_000

    private let folderURL: URL

    init(folderName: String) {
        folderURL = AppPaths.applicationSupport.appendingPathComponent(folderName, isDirectory: true)
    }

    /// The formatted versions on the pasteboard that are small enough to keep.
    static func formats(on pasteboard: NSPasteboard) -> [Format: Data] {
        var result: [Format: Data] = [:]
        for format in Format.allCases {
            if let data = pasteboard.data(forType: format.pasteboardType),
               !data.isEmpty, data.count <= maxBytesPerFormat {
                result[format] = data
            }
        }
        return result
    }

    func save(_ data: Data, format: Format, for id: UUID) {
        do {
            try FileManager.default.createDirectory(at: folderURL, withIntermediateDirectories: true)
            try data.write(to: fileURL(for: id, format: format), options: .atomic)
        } catch {
            NSLog("[ClipboardRichTextStore] Failed to save \(format.rawValue) for \(id): \(error)")
        }
    }

    func data(format: Format, for id: UUID) -> Data? {
        try? Data(contentsOf: fileURL(for: id, format: format))
    }

    func byteCount(format: Format, for id: UUID) -> Int? {
        let values = try? fileURL(for: id, format: format).resourceValues(forKeys: [.fileSizeKey])
        return values?.fileSize
    }

    /// Deletes the files of entries that are gone (removed, trimmed, replaced by a newer copy).
    func removeAll(except keptIds: Set<UUID>) {
        guard let files = try? FileManager.default.contentsOfDirectory(at: folderURL, includingPropertiesForKeys: nil) else {
            return
        }
        for file in files {
            let name = file.deletingPathExtension().lastPathComponent
            guard let id = UUID(uuidString: name), !keptIds.contains(id) else { continue }
            try? FileManager.default.removeItem(at: file)
        }
    }

    private func fileURL(for id: UUID, format: Format) -> URL {
        folderURL.appendingPathComponent("\(id.uuidString).\(format.rawValue)")
    }
}
