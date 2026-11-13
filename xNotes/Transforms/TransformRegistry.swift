//
//  TransformRegistry.swift
//  xNotes
//
//  Single source of truth for clipboard transforms: built-ins plus JavaScript plugins
//  from ~/Library/Application Support/<bundle id>/Transforms. Plugins are reloaded
//  automatically when files in that folder change.
//

import Foundation
import AppKit
import Combine

struct TransformMessage: Identifiable, Equatable {
    let id = UUID()
    let text: String
    let isError: Bool
}

@MainActor
final class TransformRegistry: ObservableObject {
    static let shared = TransformRegistry()

    /// Submenus in display order (built-in groups first, then plugin groups alphabetically).
    @Published private(set) var groups: [TransformGroup] = []
    /// Plugins without an explicit `@group`; shown in the "Plugins" submenu.
    @Published private(set) var ungroupedPlugins: [ClipboardTransform] = []
    @Published private(set) var pluginCount = 0
    @Published private(set) var loadErrors: [PluginLoadError] = []
    /// Short-lived feedback shown below the clipboard list.
    @Published private(set) var message: TransformMessage?

    let pluginFolder = AppPaths.transformPlugins
    private var watcher: FolderWatcher?

    private init() {
        ExamplePlugins.installIfNeeded(in: pluginFolder)
        reload()
        watcher = FolderWatcher(url: pluginFolder) { [weak self] in
            MainActor.assumeIsolated {
                self?.reload()
            }
        }
    }

    func reload(announce: Bool = false) {
        let builtins = BuiltinTransforms.all
        let loaded = JavaScriptTransformLoader.loadPlugins(
            in: pluginFolder,
            reservedIds: Set(builtins.map(\.id))
        )
        pluginCount = loaded.transforms.count
        loadErrors = loaded.errors
        ungroupedPlugins = loaded.transforms.filter { $0.group == JavaScriptTransformLoader.defaultGroup }
        groups = Self.makeGroups(
            builtins + loaded.transforms.filter { $0.group != JavaScriptTransformLoader.defaultGroup }
        )

        if announce {
            let errorNote = loaded.errors.isEmpty ? "" : ", \(loaded.errors.count) with errors"
            show("Loaded \(loaded.transforms.count) plugin(s)\(errorNote).", isError: !loaded.errors.isEmpty)
        }
    }

    func openPluginFolder() {
        try? FileManager.default.createDirectory(at: pluginFolder, withIntermediateDirectories: true)
        NSWorkspace.shared.open(pluginFolder)
    }

    func show(_ text: String, isError: Bool = false) {
        let message = TransformMessage(text: text, isError: isError)
        self.message = message
        DispatchQueue.main.asyncAfter(deadline: .now() + (isError ? 6 : 3)) { [weak self] in
            guard let self, self.message?.id == message.id else { return }
            self.message = nil
        }
    }

    private static func makeGroups(_ transforms: [ClipboardTransform]) -> [TransformGroup] {
        let byGroup = Dictionary(grouping: transforms, by: \.group)
        let builtinOrder = BuiltinTransforms.Group.order
        let extraGroups = byGroup.keys
            .filter { !builtinOrder.contains($0) }
            .sorted { $0.localizedStandardCompare($1) == .orderedAscending }

        return (builtinOrder + extraGroups).compactMap { name in
            guard let members = byGroup[name], !members.isEmpty else { return nil }
            // Stable: keep declaration order inside a section.
            let sections = Dictionary(grouping: members, by: \.section)
                .sorted { $0.key < $1.key }
                .map(\.value)
            return TransformGroup(name: name, sections: sections)
        }
    }
}
