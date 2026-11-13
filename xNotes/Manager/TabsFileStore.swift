//
//  TabsFileStore.swift
//  xNotes
//

import Foundation

/// Persists tabs (including clipboard history) as a JSON file in Application Support.
///
/// Older versions stored the same JSON blob in `UserDefaults` under `legacyDefaultsKey`.
/// On first load the blob is migrated into the file and removed from `UserDefaults`
/// once the file has been written and read back successfully.
struct TabsFileStore {
    private let legacyDefaultsKey: String
    private let fileURL: URL
    private let writeQueue = DispatchQueue(label: "xNotes.TabsFileStore.write", qos: .utility)

    init(legacyDefaultsKey: String, fileName: String = "tabs.json") {
        self.legacyDefaultsKey = legacyDefaultsKey
        self.fileURL = AppPaths.applicationSupport.appendingPathComponent(fileName)
    }

    func load() -> [NoteTab]? {
        if let data = try? Data(contentsOf: fileURL) {
            if let tabs = try? JSONDecoder().decode([NoteTab].self, from: data) {
                return tabs
            }
            NSLog("[TabsFileStore] Could not decode \(fileURL.path); falling back to legacy storage.")
        }
        return migrateFromUserDefaults()
    }

    /// Writes asynchronously; data is encoded on the caller's thread so the snapshot is consistent.
    func save(_ tabs: [NoteTab]) {
        guard let data = try? JSONEncoder().encode(tabs) else { return }
        writeQueue.async {
            write(data)
        }
    }

    /// Writes synchronously, e.g. right before the app terminates.
    func saveImmediately(_ tabs: [NoteTab]) {
        guard let data = try? JSONEncoder().encode(tabs) else { return }
        _ = writeQueue.sync {
            write(data)
        }
    }

    @discardableResult
    nonisolated private func write(_ data: Data) -> Bool {
        do {
            try FileManager.default.createDirectory(
                at: fileURL.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )
            try data.write(to: fileURL, options: .atomic)
            return true
        } catch {
            NSLog("[TabsFileStore] Failed to write \(fileURL.path): \(error)")
            return false
        }
    }

    private func migrateFromUserDefaults() -> [NoteTab]? {
        let defaults = UserDefaults.standard
        guard let data = defaults.data(forKey: legacyDefaultsKey),
              let tabs = try? JSONDecoder().decode([NoteTab].self, from: data) else {
            return nil
        }
        let migrated = writeQueue.sync { write(data) }
        if migrated,
           let readBack = try? Data(contentsOf: fileURL),
           (try? JSONDecoder().decode([NoteTab].self, from: readBack)) != nil {
            defaults.removeObject(forKey: legacyDefaultsKey)
        }
        return tabs
    }
}
