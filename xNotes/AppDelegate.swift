//  AppDelegate.swift
//  xNotes
//

import SwiftUI
import AppKit
import ServiceManagement
import UniformTypeIdentifiers

class AppDelegate: NSObject, NSApplicationDelegate {
    static var sharedTextExpansionEngine: TextExpansionEngine?
    private var statusItem: NSStatusItem?
    // MENUBAR-PANEL-EXPERIMENT BEGIN
    private var panel: NSPanel?
    private var hostingController: NSHostingController<AnyView>?
    private var globalMouseMonitor: Any?
    private var localMouseMonitor: Any?
    private let panelModeController = PanelModeController()
    // MENUBAR-PANEL-EXPERIMENT END
    private var notesManager = NotesManager()
    private var textExpansionStore = TextExpansionStore.shared
    private var hotkeyManager: HotkeyManager?
    static let closePopoverNotification = Notification.Name("xNotesClosePopover")
    static let reopenPopoverNotification = Notification.Name("xNotesReopenPopover")
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        // no Dock Icon
        // deprecated, use DockIconManager
//        NSApp.setActivationPolicy(.accessory)

        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        
        if let button = statusItem?.button {
            button.image = NSImage(systemSymbolName: "note.text", accessibilityDescription: "Notes")
            button.action = #selector(togglePopover)
            button.target = self
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
        }
        // MENUBAR-PANEL-EXPERIMENT BEGIN
        hostingController = NSHostingController(rootView:
            AnyView(
                PanelRootView()
                    .environmentObject(notesManager)
                    .environmentObject(panelModeController)
                    .environmentObject(textExpansionStore)
            )
        )
        panel = makePanel()
        // MENUBAR-PANEL-EXPERIMENT END
        hotkeyManager = HotkeyManager { [weak self] in
            self?.handleHotkeyTriggered()
        }
        hotkeyManager?.start()

        AppDelegate.sharedTextExpansionEngine = TextExpansionEngine(store: textExpansionStore)
        AppDelegate.sharedTextExpansionEngine?.start()

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleClosePopover),
            name: AppDelegate.closePopoverNotification,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleReopenPopover),
            name: AppDelegate.reopenPopoverNotification,
            object: nil
        )
    }

    @objc func togglePopover(_ sender: AnyObject?) {
        guard let event = NSApp.currentEvent else { return }
        if event.type == .rightMouseUp {
            showMenu()
            return
        }
        if let button = statusItem?.button {
            // MENUBAR-PANEL-EXPERIMENT BEGIN
            if panel?.isVisible == true {
                closePanel()
            } else {
                showPanel(relativeTo: button)
            }
            // MENUBAR-PANEL-EXPERIMENT END
        }
    }

    // MENUBAR-PANEL-EXPERIMENT BEGIN
    private func makePanel() -> NSPanel {
        let panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 700, height: 500),
            styleMask: [.nonactivatingPanel, .borderless, .resizable],
            backing: .buffered,
            defer: false
        )
        panel.titleVisibility = .hidden
        panel.titlebarAppearsTransparent = true
        panel.isMovableByWindowBackground = true
        panel.isReleasedWhenClosed = false
        panel.hidesOnDeactivate = false
        panel.level = .statusBar
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.minSize = NSSize(width: 620, height: 480)
        panel.setFrameAutosaveName("xNotesPanelFrame")
        panel.contentViewController = hostingController
        return panel
    }

    private func showPanel(relativeTo button: NSStatusBarButton) {
        guard let panel else { return }
        panelModeController.mode = .full
        let keepOpen = UserDefaults.standard.bool(forKey: "keepWindowOpen")

        let buttonRect = button.window?.convertToScreen(button.bounds) ?? .zero
        let panelSize = panel.frame.size
        var x = buttonRect.midX - (panelSize.width / 2)
        var y = buttonRect.minY - panelSize.height - 6

        if let screen = button.window?.screen {
            let visible = screen.visibleFrame
            x = min(max(x, visible.minX), visible.maxX - panelSize.width)
            y = min(max(y, visible.minY), visible.maxY - panelSize.height)
        }

        panel.level = keepOpen ? .floating : .normal
        panel.setFrame(NSRect(x: x, y: y, width: panelSize.width, height: panelSize.height), display: true)
        panel.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)

        if !keepOpen {
            installDismissMonitors()
        }
    }

    private func showPanel(at anchor: NSPoint) {
        guard let panel else { return }
        let keepOpen = UserDefaults.standard.bool(forKey: "keepWindowOpen")

        let panelSize = panel.frame.size
        let screen = NSScreen.screens.first(where: { $0.frame.contains(anchor) }) ?? NSScreen.main
        let visible = screen?.visibleFrame ?? NSScreen.main?.visibleFrame ?? .zero

        var x = anchor.x - (panelSize.width / 2)
        var y = anchor.y - panelSize.height - 6

        if y < visible.minY {
            y = anchor.y + 6
        }
        if y + panelSize.height > visible.maxY {
            y = visible.maxY - panelSize.height
        }
        if x < visible.minX {
            x = visible.minX
        }
        if x + panelSize.width > visible.maxX {
            x = visible.maxX - panelSize.width
        }

        panel.setFrame(NSRect(x: x, y: y, width: panelSize.width, height: panelSize.height), display: true)
        panel.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)

        if !keepOpen {
            installDismissMonitors()
        }
    }

    private func handleHotkeyTriggered() {
        let modeRaw = UserDefaults.standard.string(forKey: "hotkeyMode") ?? PanelMode.full.rawValue
        panelModeController.mode = PanelMode(rawValue: modeRaw) ?? .full
        let anchor = SelectionLocator.preferredAnchorPoint() ?? NSEvent.mouseLocation
        showPanel(at: anchor)
    }

    private func closePanel() {
        panel?.orderOut(nil)
        removeDismissMonitors()
    }

    private func installDismissMonitors() {
        removeDismissMonitors()
        globalMouseMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] _ in
            self?.dismissIfClickOutside()
        }
        localMouseMonitor = NSEvent.addLocalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] event in
            self?.dismissIfClickOutside()
            return event
        }
    }

    private func removeDismissMonitors() {
        if let globalMouseMonitor {
            NSEvent.removeMonitor(globalMouseMonitor)
            self.globalMouseMonitor = nil
        }
        if let localMouseMonitor {
            NSEvent.removeMonitor(localMouseMonitor)
            self.localMouseMonitor = nil
        }
    }

    private func dismissIfClickOutside() {
        guard let panel else { return }
        let mouse = NSEvent.mouseLocation
        if !panel.frame.contains(mouse) {
            closePanel()
        }
    }
    // MENUBAR-PANEL-EXPERIMENT END

    private func showMenu() {
        let menu = NSMenu()
        
        let exportQuickItem = NSMenuItem(title: "Export", action: #selector(exportAllNotesQuick), keyEquivalent: "x")
        exportQuickItem.target = self
        menu.addItem(exportQuickItem)
        
        let exportItem = NSMenuItem(title: "Export As...", action: #selector(exportAllNotes), keyEquivalent: "e")
        exportItem.target = self
        menu.addItem(exportItem)

        menu.addItem(.separator())

        let exportBackupItem = NSMenuItem(title: "Export Backup...", action: #selector(exportBackup), keyEquivalent: "b")
        exportBackupItem.target = self
        menu.addItem(exportBackupItem)

        let importBackupItem = NSMenuItem(title: "Import Backup...", action: #selector(importBackup), keyEquivalent: "i")
        importBackupItem.target = self
        menu.addItem(importBackupItem)

        menu.addItem(.separator())

        let quitItem = NSMenuItem(title: "Quit", action: #selector(quitApp), keyEquivalent: "q")
        quitItem.target = self
        menu.addItem(quitItem)

        if let button = statusItem?.button {
            menu.popUp(positioning: nil, at: NSPoint(x: 0, y: button.bounds.height + 2), in: button)
        }
    }

    @objc private func handleClosePopover() {
        // MENUBAR-PANEL-EXPERIMENT BEGIN
        closePanel()
        // MENUBAR-PANEL-EXPERIMENT END
    }

    @objc private func handleReopenPopover() {
        // MENUBAR-PANEL-EXPERIMENT BEGIN
        NSApp.activate(ignoringOtherApps: true)
        guard let button = statusItem?.button else { return }
        showPanel(relativeTo: button)
        // MENUBAR-PANEL-EXPERIMENT END
    }

    @objc private func quitApp() {
        NSApp.terminate(nil)
    }
  
    @objc private func exportAllNotes() {
        // Ensure UI work happens on main queue
        // MENUBAR-PANEL-EXPERIMENT BEGIN
        self.closePanel()
        // MENUBAR-PANEL-EXPERIMENT END
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.01) {
            let panel = NSSavePanel()
            panel.title = "Export Notes"
            panel.allowedContentTypes = [UTType.plainText]
            panel.nameFieldStringValue = "xNotes-Export.txt"
            panel.canCreateDirectories = true
            panel.begin { [weak self] result in
              guard result == .OK, let url = panel.url else { return }
              self?.writeExportFile(to: url)
            }
        }
    }

    @objc private func exportAllNotesQuick() {
        let fm = FileManager.default
        let docs = fm.urls(for: .desktopDirectory, in: .userDomainMask).first!
        let fileURL = docs.appendingPathComponent("xNotes-Export.txt")
        writeExportFile(to: fileURL)
//        let alert = NSAlert()
//        alert.messageText = "Export abgeschlossen"
//        alert.informativeText = "Die Datei wurde gespeichert unter:\n\(fileURL.path)"
//        alert.runModal()
    }

    @objc private func exportBackup() {
        let panel = NSSavePanel()
        panel.title = "Export Backup"
        panel.allowedContentTypes = [UTType.json]
        panel.nameFieldStringValue = "xNotes-Backup.json"
        panel.canCreateDirectories = true
        panel.begin { [weak self] result in
            guard result == .OK, let url = panel.url, let self else { return }
            do {
                let data = try self.notesManager.exportBackupData()
                try data.write(to: url, options: .atomic)
            } catch {
                self.showErrorAlert(title: "Backup Export Failed", error: error)
            }
        }
    }

    @objc private func importBackup() {
        let panel = NSOpenPanel()
        panel.title = "Import Backup"
        panel.allowedContentTypes = [UTType.json]
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        panel.begin { [weak self] result in
            guard result == .OK, let url = panel.url, let self else { return }
            do {
                let data = try Data(contentsOf: url)
                try self.notesManager.importBackupData(data)
            } catch {
                self.showErrorAlert(title: "Backup Import Failed", error: error)
            }
        }
    }

    private struct ExportNote {
        let title: String
        let content: String
    }

    private func exportSnapshot() -> [ExportNote] {
        let notes = notesManager.tabs
        return notes.enumerated().map { index, tab in
            let title = tab.title ?? "Tab \(index + 1)"
            return ExportNote(title: title, content: tab.content)
        }
    }

    private func writeExportFile(to url: URL) {
        let snapshot = exportSnapshot()
        DispatchQueue.global(qos: .userInitiated).async {
            var exportText = ""
            for note in snapshot {
                exportText += "===== \(note.title) =====\n"
                exportText += note.content + "\n\n"
            }
            do {
                try exportText.write(to: url, atomically: true, encoding: .utf8)
            } catch {
                DispatchQueue.main.async {
                    self.showErrorAlert(title: "Export Failed", error: error)
                }
            }
        }
    }

    private func showErrorAlert(title: String, error: Error) {
        let alert = NSAlert()
        alert.messageText = title
        alert.informativeText = error.localizedDescription
        alert.runModal()
    }
}
