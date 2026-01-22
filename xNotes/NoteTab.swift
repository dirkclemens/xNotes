//
//  NoteTab.swift
//  xNotes
//
//  Created by Dirk Clemens on 15.01.26.
//

import Foundation

struct NoteTab: Identifiable, Codable {
    let id: UUID
    var content: String
    
    init(id: UUID = UUID(), content: String = "") {
        self.id = id
        self.content = content
    }
}
