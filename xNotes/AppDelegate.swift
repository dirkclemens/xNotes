//
//  AppDelegate.swift
//  xNotes
//
//  Created by Dirk Clemens on 15.01.26.
//

import SwiftUI
import AppKit
import ServiceManagement

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
        let jobDict = (SMCopyAllJobDictionaries(kSMDomainUserLaunchd)?.takeRetainedValue() as? [[String: AnyObject]]) ?? []
        let bundleID = Bundle.main.bundleIdentifier ?? ""
        return jobDict.contains { ($0["Label"] as? String) == bundleID }
    }

    private func setLaunchOnLogin(enabled: Bool) {
        guard let bundleID = Bundle.main.bundleIdentifier else { return }
        SMLoginItemSetEnabled(bundleID as CFString, enabled)
    }
}
