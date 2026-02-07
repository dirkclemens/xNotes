//
//  NoteTab.swift
//  xNotes
//
//  Created by Dirk Clemens on 15.01.26.
//

import Foundation
import Combine

class NoteTab: ObservableObject, Identifiable, Codable {
    let id: UUID
    @Published var content: String
    @Published var color: Double // hue 0...1
    @Published var title: String?
    @Published var isLocked: Bool
    
    init(id: UUID = UUID(), content: String = "", color: Double = 0.0, title: String? = nil, isLocked: Bool = false) {
        self.id = id
        self.content = content
        self.color = color // 0.0 = Standardfarbe (rot)
        self.title = title
        self.isLocked = isLocked
    }
    
    // Codable
    enum CodingKeys: String, CodingKey { case id, content, color, title, isLocked }
    required convenience init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let id = try c.decode(UUID.self, forKey: .id)
        let content = try c.decode(String.self, forKey: .content)
        let color = try c.decode(Double.self, forKey: .color)
        let title = try c.decodeIfPresent(String.self, forKey: .title)
        let isLocked = try c.decodeIfPresent(Bool.self, forKey: .isLocked) ?? false
        self.init(id: id, content: content, color: color, title: title, isLocked: isLocked)
    }
    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(id, forKey: .id)
        try c.encode(content, forKey: .content)
        try c.encode(color, forKey: .color)
        try c.encode(title, forKey: .title)
        try c.encode(isLocked, forKey: .isLocked)
    }
}
