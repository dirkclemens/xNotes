//
//  ClipboardItem.swift
//  xNotes
//

import Foundation

struct ClipboardItem: Identifiable, Codable, Equatable {
    let id: UUID
    let text: String
    let originalText: String
    let date: Date
    let pinnedSlot: Int?
    let sourceAppName: String?
    let sourceAppBundleId: String?

    init(
        id: UUID = UUID(),
        text: String,
        originalText: String? = nil,
        date: Date = Date(),
        pinnedSlot: Int? = nil,
        sourceAppName: String? = nil,
        sourceAppBundleId: String? = nil
    ) {
        self.id = id
        self.text = text
        self.originalText = originalText ?? text
        self.date = date
        self.pinnedSlot = pinnedSlot
        self.sourceAppName = sourceAppName
        self.sourceAppBundleId = sourceAppBundleId
    }

    enum CodingKeys: String, CodingKey {
        case id, text, originalText, date, pinnedSlot, sourceAppName, sourceAppBundleId
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
    }
}
