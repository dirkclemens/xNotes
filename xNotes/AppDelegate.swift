//  AppDelegate.swift
//  xNotes
//
//  Created by Dirk Clemens on 15.01.26.
//

import SwiftUI
import AppKit
import ServiceManagement
import UniformTypeIdentifiers

class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem?
    private var popover: NSPopover?
    private var notesManager = NotesManager()
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        
        if let button = statusItem?.button {
            button.image = NSImage(systemSymbolName: "note.text", accessibilityDescription: "Notes")
            button.action = #selector(togglePopover)
            button.target = self
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
        }
        
        popover = NSPopover()
        popover?.contentSize = NSSize(width: 600, height: 400)
        popover?.behavior = .transient
        popover?.contentViewController = NSHostingController(rootView: NotesView(notesManager: notesManager))
    }

    @objc func togglePopover(_ sender: AnyObject?) {
        guard let event = NSApp.currentEvent else { return }
        if event.type == .rightMouseUp {
            showMenu()
            return
        }
        if let button = statusItem?.button {
            if popover?.isShown == true {
                popover?.performClose(nil)
            } else {
                // Wert immer aktuell auslesen:
                let keepOpen = UserDefaults.standard.bool(forKey: "keepWindowOpen")
                popover?.behavior = keepOpen ? .applicationDefined : .transient
                popover?.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
                popover?.contentViewController?.view.window?.makeKey()
            }
        }
    }

    private func showMenu() {
        let menu = NSMenu()
        
        let launchItem = NSMenuItem(title: "Beim Login starten", action: #selector(toggleLaunchOnLogin), keyEquivalent: "l")
        launchItem.state = isLaunchOnLoginEnabled() ? .on : .off
        launchItem.target = self
        menu.addItem(launchItem)
        
        let exportQuickItem = NSMenuItem(title: "Export", action: #selector(exportAllNotesQuick), keyEquivalent: "x")
        exportQuickItem.target = self
        menu.addItem(exportQuickItem)
        
        let exportItem = NSMenuItem(title: "Export nach...", action: #selector(exportAllNotes), keyEquivalent: "e")
        exportItem.target = self
        menu.addItem(exportItem)
        
        let quitItem = NSMenuItem(title: "Beenden", action: #selector(quitApp), keyEquivalent: "q")
        quitItem.target = self
        menu.addItem(quitItem)
        
        statusItem?.menu = menu
        statusItem?.button?.performClick(nil)
        statusItem?.menu = nil
    }

    @objc private func quitApp() {
        NSApp.terminate(nil)
    }

    @objc private func toggleLaunchOnLogin() {
        let enabled = isLaunchOnLoginEnabled()
        setLaunchOnLogin(enabled: !enabled)
    }

    private func isLaunchOnLoginEnabled() -> Bool {
        if #available(macOS 13.0, *) {
            let status = SMAppService.mainApp.status
            switch status {
            case .enabled:
                return true
            default:
                return false
            }
        } else {
            // On older systems, avoid deprecated APIs and report disabled.
            return false
        }
    }

    private func setLaunchOnLogin(enabled: Bool) {
        if #available(macOS 13.0, *) {
            do {
                if enabled {
                    try SMAppService.mainApp.register()
                } else {
                    try SMAppService.mainApp.unregister()
                }
            } catch {
                // You may want to surface this error to the user in UI or logging
                NSLog("Failed to update launch at login: \(error.localizedDescription)")
            }
        } else {
            // On older macOS versions, we do not attempt to manage login items to avoid deprecated APIs.
            NSLog("Launch at login management is unavailable on this macOS version.")
        }
    }
  
    @objc private func exportAllNotes() {
        // Ensure UI work happens on main queue
        self.popover?.performClose(nil)
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.01) {
            let panel = NSSavePanel()
            panel.title = "Notizen exportieren"
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

    private func writeExportFile(to url: URL) {
        let notes = notesManager.tabs
        var exportText = ""
        for (i, tab) in notes.enumerated() {
            let title = tab.title ?? "Tab \(i + 1)"
            exportText += "===== \(title) =====\n"
            exportText += tab.content + "\n\n"
        }
        do {
            try exportText.write(to: url, atomically: true, encoding: .utf8)
        } catch {
            let alert = NSAlert()
            alert.messageText = "Export fehlgeschlagen"
            alert.informativeText = error.localizedDescription
            alert.runModal()
        }
    }
}
