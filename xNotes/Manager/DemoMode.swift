//
//  DemoMode.swift
//  xNotes
//
//  Debug-only demo mode for screenshots without private data.
//
//  Enable with the launch argument `-DemoMode YES`
//  (Xcode: Product ▸ Scheme ▸ Edit Scheme… ▸ Run ▸ Arguments).
//  Add `-DemoOpenTab <n>` to open the panel right after launch with the n-th tab of the
//  sidebar selected (1 = clipboard), e.g. for scripted screenshots.
//
//  In demo mode:
//  - tabs are loaded from built-in sample data and saved to `tabs-demo.json`
//    (your real `tabs.json` is never read or written),
//  - text expansion rules are sample data and are not saved,
//  - clipboard monitoring and the system-wide text expander are disabled.
//
//  Release builds ignore the flag.
//

import AppKit

enum DemoMode {
    static var isEnabled: Bool {
        #if DEBUG
        return UserDefaults.standard.bool(forKey: "DemoMode")
        #else
        return false
        #endif
    }

    /// Sidebar position (1-based) of the tab to show in a panel opened at launch.
    static var openTabAtLaunch: Int? {
        #if DEBUG
        guard isEnabled else { return nil }
        let value = UserDefaults.standard.integer(forKey: "DemoOpenTab")
        return value > 0 ? value : nil
        #else
        return nil
        #endif
    }
}

#if DEBUG
enum DemoData {
    static func tabs(now: Date = Date()) -> [NoteTab] {
        [
            NoteTab(
                color: 0.6,
                title: "Clipboard",
                isLocked: true,
                kind: .clipboard,
                clipboardItems: clipboardItems(now: now),
                lastEditedAt: now
            ),
            NoteTab(
                content: weeklyPlan,
                color: 0.58,
                title: "Weekly Plan",
                isLocked: true,
                lastEditedAt: now
            ),
            NoteTab(
                content: projectIdeas,
                color: 0.33,
                title: "Project Ideas",
                lastEditedAt: now.addingTimeInterval(-2 * 24 * 3600)
            ),
            NoteTab(
                content: meetingNotes,
                color: 0.08,
                lastEditedAt: now.addingTimeInterval(-4 * 24 * 3600)
            ),
            NoteTab(
                content: recipe,
                color: 0.9,
                title: "Shakshuka",
                isLocked: true,
                lastEditedAt: now
            ),
            NoteTab(
                color: 0.12,
                title: "Expansions",
                isLocked: true,
                kind: .expansions,
                lastEditedAt: now
            ),
        ]
    }

    /// A drawn sample chart as clipboard image, stored in the demo image folder.
    static func sampleImageItem(store: ClipboardImageStore, now: Date) -> ClipboardItem? {
        let id = UUID(uuidString: "D3A0C0DE-0000-4000-8000-000000000001")!
        guard let png = sampleChartPNG(),
              let processed = ClipboardImageStore.process(png),
              store.save(processed, for: id) else { return nil }
        return ClipboardItem(
            id: id,
            text: "Image \(processed.info.width) × \(processed.info.height)",
            date: now.addingTimeInterval(-8 * 60),
            sourceAppName: "Preview",
            sourceAppBundleId: "com.apple.Preview",
            pasteboardTypes: ["public.png"],
            imageInfo: processed.info
        )
    }

    private static func sampleChartPNG() -> Data? {
        let width = 1200, height = 720
        guard let rep = NSBitmapImageRep(
            bitmapDataPlanes: nil, pixelsWide: width, pixelsHigh: height, bitsPerSample: 8,
            samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB,
            bytesPerRow: 0, bitsPerPixel: 0
        ) else { return nil }
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
        let bounds = NSRect(x: 0, y: 0, width: width, height: height)
        NSGradient(starting: NSColor(calibratedRed: 0.20, green: 0.45, blue: 0.95, alpha: 1),
                   ending: NSColor(calibratedRed: 0.55, green: 0.30, blue: 0.90, alpha: 1))?
            .draw(in: bounds, angle: 35)
        let values: [CGFloat] = [0.35, 0.55, 0.45, 0.70, 0.62, 0.88]
        let barWidth: CGFloat = 110, gap: CGFloat = 60, baseY: CGFloat = 90
        for (index, value) in values.enumerated() {
            let x = 120 + CGFloat(index) * (barWidth + gap)
            NSColor.white.withAlphaComponent(0.85).setFill()
            NSBezierPath(roundedRect: NSRect(x: x, y: baseY, width: barWidth, height: value * 480), xRadius: 14, yRadius: 14).fill()
        }
        NSString(string: "Q3 Revenue").draw(at: NSPoint(x: 120, y: 620), withAttributes: [
            .font: NSFont.systemFont(ofSize: 56, weight: .bold),
            .foregroundColor: NSColor.white,
        ])
        NSGraphicsContext.restoreGraphicsState()
        return rep.representation(using: .png, properties: [:])
    }

    static let textExpansionRules: [TextExpansionRule] = [
        TextExpansionRule(trigger: ";sig", replacement: "Best regards,\nAlex Example\nexample.com"),
        TextExpansionRule(trigger: ";addr", replacement: "Example Street 1\n12345 Sample City"),
        TextExpansionRule(trigger: ";mail", replacement: "alex@example.com"),
        TextExpansionRule(trigger: ";thx", replacement: "Thanks a lot for your quick reply!"),
        TextExpansionRule(trigger: ";swift", replacement: "```swift\n\n```"),
        TextExpansionRule(trigger: ";date", replacement: "2026-01-15", isEnabled: false),
    ]

    private static func clipboardItems(now: Date) -> [ClipboardItem] {
        func item(
            _ text: String,
            minutesAgo: Double,
            app: String,
            bundleId: String,
            pinned: Int? = nil,
            linkTitle: String? = nil,
            filePaths: [String] = []
        ) -> ClipboardItem {
            ClipboardItem(
                text: text,
                date: now.addingTimeInterval(-minutesAgo * 60),
                pinnedSlot: pinned,
                sourceAppName: app,
                sourceAppBundleId: bundleId,
                pasteboardTypes: linkTitle != nil ? ["public.utf8-plain-text", "public.url", "public.url-name"] : ["public.utf8-plain-text"],
                filePaths: filePaths,
                copiedLinkURL: linkTitle != nil ? text : nil,
                copiedLinkTitle: linkTitle
            )
        }
        return [
            item("alex@example.com", minutesAgo: 600, app: "Mail", bundleId: "com.apple.mail", pinned: 1),
            item("Example Street 1, 12345 Sample City", minutesAgo: 900, app: "Contacts", bundleId: "com.apple.AddressBook", pinned: 2),
            item("https://example.com/docs/getting-started?ref=xnotes", minutesAgo: 2, app: "Safari", bundleId: "com.apple.Safari", linkTitle: "Getting Started – Example Docs"),
            item("Calculator.app", minutesAgo: 4, app: "Finder", bundleId: "com.apple.finder", filePaths: ["/System/Applications/Calculator.app"]),
            item("{\"name\":\"xNotes\",\"version\":\"1.1.0\",\"features\":[\"tabs\",\"clipboard\",\"plugins\"]}", minutesAgo: 5, app: "Terminal", bundleId: "com.apple.Terminal"),
            item("git log --oneline --graph --decorate -20", minutesAgo: 12, app: "Terminal", bundleId: "com.apple.Terminal"),
            item("let filtered = items.filter { $0.isPinned }", minutesAgo: 25, app: "Xcode", bundleId: "com.apple.dt.Xcode"),
            item("Name\tRole\tCity\nAnna\tDesign\tBerlin\nBen\tEngineering\tHamburg", minutesAgo: 40, app: "Numbers", bundleId: "com.apple.iWork.Numbers"),
            item("Quarterly review moved to Thursday, 10:00 – Room 3.14", minutesAgo: 75, app: "Calendar", bundleId: "com.apple.iCal"),
            item("user_profile_settings", minutesAgo: 120, app: "Xcode", bundleId: "com.apple.dt.Xcode"),
            item("<p>Hello <strong>world</strong>, see <a href=\"https://example.com\">the docs</a>.</p>", minutesAgo: 180, app: "Safari", bundleId: "com.apple.Safari"),
        ]
    }

    private static let weeklyPlan = """
    # Weekly Plan

    ## Monday
    - Review **pull requests**
    - Prepare release notes for *v1.1*

    ## Wednesday
    - Team sync at 10:00
    - Write `README` section about plugins

    ## Friday
    - ~~Clean up old branches~~
    - Ship it 🚀

    > Focus on one thing at a time.
    """

    private static let projectIdeas = """
    # Project Ideas

    1. Menu bar weather widget
    2. Markdown → slides converter
    3. Habit tracker with streaks

    ## Snippet

    ```
    func greet(_ name: String) -> String {
        "Hello, \\(name)!"
    }
    ```

    Inspiration: https://example.com/ideas
    """

    private static let meetingNotes = """
    Meeting Notes – Design Review

    Attendees: @anna @ben @chris

    - New onboarding flow approved
    - **Action:** Ben updates the icons
    - Next review in two weeks
    """

    private static let recipe = """
    # Shakshuka

    ## Ingredients
    - 4 eggs
    - 1 can chopped tomatoes
    - 1 red pepper, 1 onion, 2 garlic cloves
    - Cumin, paprika, salt, pepper

    ## Steps
    1. Sauté onion, pepper and garlic
    2. Add tomatoes and spices, simmer 10 min
    3. Make wells, crack in the eggs, cover until set
    """
}
#endif
