//
//  AppPaths.swift
//  xNotes
//

import Foundation

enum AppPaths {
    /// ~/Library/Application Support/<bundle id>/
    static var applicationSupport: URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? URL(fileURLWithPath: NSHomeDirectory()).appendingPathComponent("Library/Application Support")
        return base.appendingPathComponent(Bundle.main.bundleIdentifier ?? "xNotes", isDirectory: true)
    }

    /// Folder for user-provided clipboard transform plugins.
    static var transformPlugins: URL {
        applicationSupport.appendingPathComponent("Transforms", isDirectory: true)
    }
}
