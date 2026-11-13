//
//  ClipboardTransform.swift
//  xNotes
//

import Foundation

/// A text transformation offered in the clipboard context menu.
/// Built-in transforms and plugins share this type, so the menu is generated from data.
nonisolated struct ClipboardTransform: Identifiable, Sendable {
    enum Input: Equatable {
        case none
        /// Ask the user for a value before running (e.g. "Prefix").
        case prompt(label: String)
    }

    enum Source: Equatable {
        case builtin
        case javascript(URL)
    }

    let id: String
    let title: String
    /// Name of the submenu the transform appears in.
    let group: String
    /// Transforms of the same group are separated by a divider when the section changes.
    let section: Int
    let input: Input
    let source: Source
    let help: String?
    /// Returns the transformed text, or `nil` when the transform does not apply (no change).
    let run: @Sendable (_ text: String, _ argument: String?) throws -> String?

    init(
        id: String,
        title: String,
        group: String,
        section: Int = 0,
        input: Input = .none,
        source: Source = .builtin,
        help: String? = nil,
        run: @escaping @Sendable (_ text: String, _ argument: String?) throws -> String?
    ) {
        self.id = id
        self.title = title
        self.group = group
        self.section = section
        self.input = input
        self.source = source
        self.help = help
        self.run = run
    }

    /// Menu title; transforms that ask for input get an ellipsis.
    var menuTitle: String {
        input == .none ? title : "\(title)…"
    }
}

nonisolated struct TransformError: LocalizedError, Sendable {
    let message: String
    var errorDescription: String? { message }
}

/// Submenu model derived from the registered transforms.
nonisolated struct TransformGroup: Identifiable {
    let name: String
    let sections: [[ClipboardTransform]]
    var id: String { name }
}
