//  AppDelegate.swift
//  xNotes
//

import SwiftUI
import AppKit
import ServiceManagement
import Combine

class AppDelegate: NSObject, NSApplicationDelegate {
    static var sharedTextExpansionEngine: TextExpansionEngine?
    private var statusItem: NSStatusItem?
    
    private var panel: NSPanel?
    private var hostingController: NSHostingController<AnyView>?
    private var globalMouseMonitor: Any?
    private var localMouseMonitor: Any?
    private let panelModeController = PanelModeController()
    
    /// Shared with the Settings scene (export & backup).
    private(set) var notesManager = NotesManager()
    private var textExpansionStore = TextExpansionStore.shared
    private var windowLevelStateSettings = WindowLevelStateSettings()
    private var keepWindowOpenCancellable: AnyCancellable? // <-- Fix: retain Combine subscription
    
    private var hotkeyManager: HotkeyManager?
    static let closePopoverNotification = Notification.Name("xNotesClosePopover")
    static let reopenPopoverNotification = Notification.Name("xNotesReopenPopover")
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        
        if let button = statusItem?.button {
            button.image = NSImage(systemSymbolName: "note.text", accessibilityDescription: "Notes")
            button.action = #selector(togglePopover)
            button.target = self
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
        }
    
        // Initialisiere alle EnvironmentObjects als Properties (bereits vorhanden)
        // Initialisiere hostingController zuerst
        let rootView = AnyView(
            PanelRootView()
                .environmentObject(notesManager)
                .environmentObject(panelModeController)
                .environmentObject(textExpansionStore)
                .environmentObject(windowLevelStateSettings)
        )
        hostingController = NSHostingController(rootView: rootView)
        // Panel erst nach hostingController initialisieren
        panel = makePanel()
        if hostingController == nil {
            print("[AppDelegate] hostingController ist nil!")
        }
        if panel == nil {
            print("[AppDelegate] panel ist nil!")
        }
    
        hotkeyManager = HotkeyManager { [weak self] in
            self?.handleHotkeyTriggered()
        }
        hotkeyManager?.start()

        AppDelegate.sharedTextExpansionEngine = TextExpansionEngine(store: textExpansionStore)
        if !DemoMode.isEnabled {
            AppDelegate.sharedTextExpansionEngine?.start()
        }

        if let position = DemoMode.openTabAtLaunch {
            let tabs = notesManager.sidebarOrderedTabs
            if position <= tabs.count {
                notesManager.selectedTabId = tabs[position - 1].id
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
                guard let self, let button = self.statusItem?.button else { return }
                // Stay visible while another app is active (screenshots are taken from outside).
                self.panel?.hidesOnDeactivate = false
                self.showPanel(relativeTo: button)
                self.removeDismissMonitors()
                self.panel?.orderFrontRegardless()
            }
        }

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
        
        // Observe keepWindowOpen changes and update panel immediately if visible
        keepWindowOpenCancellable = windowLevelStateSettings.$keepWindowOpen.sink { [weak self] newValue in
            guard let self = self, let panel = self.panel else { return }
            panel.level = newValue ? .floating : .normal
            if panel.isVisible {
                if newValue {
                    self.removeDismissMonitors()
                } else {
                    self.installDismissMonitors()
                }
            }
            //NSLog("Updated panel level to \(panel.level) due to keepWindowOpen change: \(newValue)")
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        MainActor.assumeIsolated {
            notesManager.flushPendingSave()
        }
    }

    @objc func togglePopover(_ sender: AnyObject?) {
        guard let event = NSApp.currentEvent else { return }
        if event.type == .rightMouseUp {
            showMenu()
            return
        }
        if let button = statusItem?.button {
    
            if panel?.isVisible == true {
                closePanel()
            } else {
                showPanel(relativeTo: button)
            }
        }
    }

    private func makePanel() -> NSPanel {
        let newPanel = KeyHandlingPanel(
            contentRect: NSRect(x: 0, y: 0, width: 700, height: 500),
//            styleMask: [.nonactivatingPanel, .borderless, .resizable],
            styleMask: [.borderless, .resizable], // remove .nonactivatingPanel
            backing: .buffered,
            defer: false
        )
        newPanel.titleVisibility = .hidden
        newPanel.titlebarAppearsTransparent = true
        newPanel.isMovableByWindowBackground = true
        newPanel.isReleasedWhenClosed = false
        newPanel.hidesOnDeactivate = false
        let keepOpen = windowLevelStateSettings.keepWindowOpen
        newPanel.level = keepOpen ? .floating : .normal
        newPanel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        newPanel.minSize = NSSize(width: 620, height: 480)
        newPanel.setFrameAutosaveName("xNotesPanelFrame")
        newPanel.contentViewController = hostingController
        
        newPanel.isOpaque = false
        newPanel.hasShadow = true
        newPanel.backgroundColor = .clear
        if let contentView = newPanel.contentView {
            contentView.wantsLayer = true
            contentView.layer?.cornerRadius = 16
            contentView.layer?.masksToBounds = true
        }
        
        return newPanel
    }

    private func showPanel(relativeTo button: NSStatusBarButton) {
        guard let panel else { return }
        panelModeController.mode = .full
        let keepOpen = windowLevelStateSettings.keepWindowOpen // <-- use direct binding
        
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
        panel.makeFirstResponder(self.hostingController?.view)

        if !keepOpen {
            installDismissMonitors()
        }
    }

    private func showPanel(at anchor: NSPoint) {
        guard let panel else { return }
        let keepOpen = windowLevelStateSettings.keepWindowOpen // <-- use direct binding
        
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

        panel.level = keepOpen ? .floating : .normal
        panel.setFrame(NSRect(x: x, y: y, width: panelSize.width, height: panelSize.height), display: true)
        panel.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        panel.makeFirstResponder(self.hostingController?.view)

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

    private func showMenu() {
        let menu = NSMenu()

        // Clipboard: latest entries (count set in Settings ▸ Clipboard; 0 hides the section).
        // Export and backup actions live in Settings ▸ Export & Backup.
        if let clipboardTab = notesManager.tabs.first(where: { $0.kind == .clipboard }) {
            let latestItems = Array(clipboardTab.clipboardItems.prefix(Self.statusMenuClipboardCount()))
            if !latestItems.isEmpty {
                let clipboardHeader = NSMenuItem(title: "Clipboard", action: nil, keyEquivalent: "")
                clipboardHeader.isEnabled = false
                menu.addItem(clipboardHeader)

                for item in latestItems {
                    let firstLine = item.displayText.components(separatedBy: .newlines).first ?? ""
                    let displayTitle = firstLine.isEmpty ? "(empty)" : String(firstLine.prefix(60))
                    let menuItem = NSMenuItem(title: displayTitle, action: #selector(pasteClipboardMenuItem(_:)), keyEquivalent: "")
                    menuItem.target = self
                    menuItem.representedObject = item.id
                    if item.isFileItem {
                        menuItem.toolTip = item.filePaths.joined(separator: "\n")
                    } else if let title = item.linkTitle, let url = item.linkURL {
                        menuItem.toolTip = "\(title)\n\(url.absoluteString)"
                    } else {
                        menuItem.toolTip = item.text
                    }

                    var icon: NSImage?
                    if item.isImageItem, let thumbnail = notesManager.imageStore.thumbnail(for: item.id) {
                        icon = thumbnail.copy() as? NSImage
                    } else if let firstPath = item.filePaths.first {
                        icon = NSWorkspace.shared.icon(forFile: firstPath)
                    } else if let bundleId = item.sourceAppBundleId,
                       let appURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleId) {
                        icon = NSWorkspace.shared.icon(forFile: appURL.path)
                    }
                    if icon == nil {
                        icon = NSImage(named: NSImage.infoName)
                    }

                    if let icon = icon {
                        icon.size = NSSize(width: 16, height: 16)
                        let attachment = NSTextAttachment()
                        attachment.image = icon
                        attachment.bounds = NSRect(x: 0, y: -1.5, width: 16, height: 16)
                        let attrString = NSMutableAttributedString(attachment: attachment)
                        attrString.append(NSAttributedString(string: "  \(displayTitle)"))
                        menuItem.attributedTitle = attrString
                    }

                    menu.addItem(menuItem)
                }
                menu.addItem(.separator())
            }
        }

        let quitItem = NSMenuItem(title: "Quit", action: #selector(quitApp), keyEquivalent: "q")
        quitItem.target = self
        menu.addItem(quitItem)

        // Popping the menu up manually inside the status bar button makes it inherit
        // the menu bar's (often dark) appearance. Attaching it to the status item for
        // this one click lets macOS show it like its own status menus, which follow
        // the system appearance.
        guard let statusItem, let button = statusItem.button else { return }
        menu.appearance = NSApp.effectiveAppearance
        statusItem.menu = menu
        button.performClick(nil) // runs the menu's tracking loop and returns when it closes
        statusItem.menu = nil    // restore left-click → panel, right-click → togglePopover
    }

    @objc private func handleClosePopover() {
        closePanel()
    }

    @objc private func handleReopenPopover() {
        NSApp.activate(ignoringOtherApps: true)
        guard let button = statusItem?.button else { return }
        showPanel(relativeTo: button)
    }

    /// UserDefaults key / default for the number of clipboard entries in the status menu.
    static let statusMenuClipboardCountKey = "statusMenuClipboardCount"
    static let statusMenuClipboardCountDefault = 10

    private static func statusMenuClipboardCount() -> Int {
        let stored = UserDefaults.standard.object(forKey: statusMenuClipboardCountKey) as? Int
        return max(0, stored ?? statusMenuClipboardCountDefault)
    }

    @objc private func quitApp() {
        NSApp.terminate(nil)
    }

    @objc private func pasteClipboardMenuItem(_ sender: NSMenuItem) {
        guard let id = sender.representedObject as? ClipboardItem.ID,
              let item = notesManager.clipboardItem(id: id) else { return }
        _ = notesManager.pasteClipboardItemIntoLastApp(item)
    }
}
