//
//  TextExpansionRule.swift
//  xNotes
//

import Foundation

struct TextExpansionRule: Identifiable, Codable, Equatable {
    let id: UUID
    var trigger: String
    var replacement: String
    var isEnabled: Bool

    init(
        id: UUID = UUID(),
        trigger: String,
        replacement: String,
        isEnabled: Bool = true
    ) {
        self.id = id
        self.trigger = trigger
        self.replacement = replacement
        self.isEnabled = isEnabled
    }
}
