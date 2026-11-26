//
//  ClipboardItemPreview.swift
//  xNotes
//

import SwiftUI
import AppKit

// MARK: - Window

/// Shows the hover preview of a clipboard entry in a small window next to the panel.
/// It replaces the plain tooltip: it appears after a short delay, follows the mouse from
/// row to row without delay once visible, and never takes clicks or keyboard focus.
final class ClipboardPreviewController {
    static let shared = ClipboardPreviewController()

    /// Delay before the first preview appears, like a tooltip.
    private static let showDelay: TimeInterval = 0.5
    /// Grace period when the mouse moves between rows, so the preview doesn't flicker.
    private static let hideDelay: TimeInterval = 0.15
    /// Gap between the panel and the preview.
    private static let gap: CGFloat = 8

    private var window: NSPanel?
    private var hostingView: NSHostingView<AnyView>?
    private var shownItemId: UUID?
    /// Row under the mouse. SwiftUI may report entering the next row before leaving the
    /// previous one, so leaving only counts for the row that is still current.
    private var hoveredItemId: UUID?
    private var pendingShow: DispatchWorkItem?
    private var pendingHide: DispatchWorkItem?
    private var eventMonitor: Any?
    private weak var hostWindow: NSWindow?

    private init() {
        // Clicking, typing or scrolling dismisses the preview, as it does a tooltip.
        eventMonitor = NSEvent.addLocalMonitorForEvents(
            matching: [.leftMouseDown, .rightMouseDown, .otherMouseDown, .keyDown, .scrollWheel]
        ) { [weak self] event in
            self?.hide()
            return event
        }
        let center = NotificationCenter.default
        center.addObserver(forName: NSApplication.didResignActiveNotification, object: nil, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated { self?.hide() }
        }
        center.addObserver(forName: NSWindow.didResignKeyNotification, object: nil, queue: .main) { [weak self] notification in
            MainActor.assumeIsolated {
                guard let self, notification.object as? NSWindow === self.hostWindow else { return }
                self.hide()
            }
        }
    }

    /// The mouse entered a row. `content` builds the preview when it is shown.
    func hoverBegan(itemId: UUID, content: @escaping () -> AnyView) {
        hoveredItemId = itemId
        pendingHide?.cancel()
        pendingShow?.cancel()
        if window?.isVisible == true {
            if shownItemId != itemId {
                show(itemId: itemId, content: content)
            }
            return
        }
        let work = DispatchWorkItem { [weak self] in
            self?.show(itemId: itemId, content: content)
        }
        pendingShow = work
        DispatchQueue.main.asyncAfter(deadline: .now() + Self.showDelay, execute: work)
    }

    /// The mouse left a row.
    func hoverEnded(itemId: UUID) {
        guard hoveredItemId == itemId else { return }
        hoveredItemId = nil
        pendingShow?.cancel()
        pendingShow = nil
        guard window?.isVisible == true else { return }
        pendingHide?.cancel()
        let work = DispatchWorkItem { [weak self] in
            self?.hide()
        }
        pendingHide = work
        DispatchQueue.main.asyncAfter(deadline: .now() + Self.hideDelay, execute: work)
    }

    func hide() {
        pendingShow?.cancel()
        pendingShow = nil
        pendingHide?.cancel()
        pendingHide = nil
        shownItemId = nil
        hoveredItemId = nil
        window?.orderOut(nil)
    }

    private func show(itemId: UUID, content: () -> AnyView) {
        let mouse = NSEvent.mouseLocation
        guard NSApp.isActive, let host = appWindow(at: mouse), host.attachedSheet == nil,
              let screen = host.screen ?? NSScreen.main else { return }
        hostWindow = host

        let (window, hostingView) = makeWindowIfNeeded()
        hostingView.rootView = content()
        let size = hostingView.fittingSize
        let visible = screen.visibleFrame

        // Beside the panel, preferably on the right; inside it if neither side has room.
        var x: CGFloat
        if host.frame.maxX + Self.gap + size.width <= visible.maxX {
            x = host.frame.maxX + Self.gap
        } else if host.frame.minX - Self.gap - size.width >= visible.minX {
            x = host.frame.minX - Self.gap - size.width
        } else {
            x = mouse.x > host.frame.midX ? host.frame.minX + 16 : host.frame.maxX - size.width - 16
        }
        x = min(max(x, visible.minX), visible.maxX - size.width)
        // Top edge a little above the mouse, kept on screen.
        var y = mouse.y + 24 - size.height
        y = min(max(y, visible.minY), visible.maxY - size.height)

        window.setFrame(NSRect(x: x, y: y, width: size.width, height: size.height), display: true)
        window.level = NSWindow.Level(rawValue: max(host.level.rawValue, NSWindow.Level.floating.rawValue) + 1)
        window.orderFront(nil)
        window.invalidateShadow()
        shownItemId = itemId
    }

    /// The app's own window under the mouse (the panel the list is in).
    private func appWindow(at point: NSPoint) -> NSWindow? {
        let number = NSWindow.windowNumber(at: point, belowWindowWithWindowNumber: 0)
        return NSApp.windows.first { $0.windowNumber == number && $0 !== window && $0.isVisible }
    }

    private func makeWindowIfNeeded() -> (NSPanel, NSHostingView<AnyView>) {
        if let window, let hostingView {
            return (window, hostingView)
        }
        let panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 380, height: 200),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: true
        )
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.ignoresMouseEvents = true
        panel.hidesOnDeactivate = true
        panel.isReleasedWhenClosed = false
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .transient, .ignoresCycle]

        let background = NSVisualEffectView()
        background.material = .popover
        background.blendingMode = .behindWindow
        background.state = .active
        background.maskImage = Self.roundedMask(radius: 12)

        let hosting = NSHostingView(rootView: AnyView(EmptyView()))
        hosting.translatesAutoresizingMaskIntoConstraints = false
        background.addSubview(hosting)
        NSLayoutConstraint.activate([
            hosting.leadingAnchor.constraint(equalTo: background.leadingAnchor),
            hosting.trailingAnchor.constraint(equalTo: background.trailingAnchor),
            hosting.topAnchor.constraint(equalTo: background.topAnchor),
            hosting.bottomAnchor.constraint(equalTo: background.bottomAnchor),
        ])
        panel.contentView = background

        window = panel
        hostingView = hosting
        return (panel, hosting)
    }

    /// Stretchable mask with rounded corners for the blurred background.
    private static func roundedMask(radius: CGFloat) -> NSImage {
        let edge = radius * 2 + 1
        let image = NSImage(size: NSSize(width: edge, height: edge), flipped: false) { rect in
            NSColor.black.setFill()
            NSBezierPath(roundedRect: rect, xRadius: radius, yRadius: radius).fill()
            return true
        }
        image.capInsets = NSEdgeInsets(top: radius, left: radius, bottom: radius, right: radius)
        image.resizingMode = .stretch
        return image
    }
}

// MARK: - Content

/// What the hover preview shows: where the entry came from, its content (text, link,
/// files or a large image) and the details the tooltip used to list.
struct ClipboardItemPreview: View {
    let item: ClipboardItem
    let notesManager: NotesManager
    let pasteAsPlainText: Bool

    @State private var previewImage: NSImage?

    private static let textWidth: CGFloat = 380
    private static let imageWidth: CGFloat = 480
    private static let maxImageHeight: CGFloat = 340
    private static let maxPreviewLines = 24
    private static let maxPreviewCharacters = 2_000
    private static let maxFiles = 8

    private var width: CGFloat { item.isImageItem ? Self.imageWidth : Self.textWidth }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            header
            if let warning = sensitiveWarning {
                Label(warning, systemImage: "key.fill")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.orange)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.orange.opacity(0.12), in: RoundedRectangle(cornerRadius: 6))
            }
            content
            Divider()
            details
        }
        .padding(14)
        .frame(width: width, alignment: .leading)
    }

    // MARK: Header

    private var header: some View {
        HStack(spacing: 8) {
            Image(nsImage: sourceAppIcon)
                .resizable()
                .frame(width: 22, height: 22)
            VStack(alignment: .leading, spacing: 1) {
                Text(item.sourceAppName ?? "Unknown App")
                    .font(.system(size: 12, weight: .semibold))
                Text(Self.relativeFormatter.localizedString(for: item.date, relativeTo: Date()))
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: 8)
            if let slot = item.pinnedSlot {
                Text("⌥\(slot)")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Capsule().fill(Color.accentColor))
            }
            Text(kindLabel)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(.secondary)
                .padding(.horizontal, 7)
                .padding(.vertical, 2)
                .background(Capsule().fill(Color.primary.opacity(0.07)))
        }
    }

    private var kindLabel: String {
        if item.isImageItem { return "Image" }
        if item.isFileItem { return item.filePaths.count == 1 ? "File" : "\(item.filePaths.count) Files" }
        if item.isLink { return "Link" }
        if item.canPasteRichText { return "Formatted Text" }
        return "Text"
    }

    private var sensitiveWarning: String? {
        if item.isMarkedConcealed { return "Sensitive – marked as a password by the source app" }
        if item.isFromPasswordApp { return "Sensitive – copied from a password app" }
        return nil
    }

    // MARK: Content

    @ViewBuilder
    private var content: some View {
        if let info = item.imageInfo {
            imageContent(info)
        } else if item.isFileItem {
            filesContent
        } else if let url = item.linkURL {
            linkContent(url)
        } else {
            textBox(item.text, lineLimit: Self.maxPreviewLines)
        }
        if item.isTextItem, item.text != item.originalText {
            VStack(alignment: .leading, spacing: 4) {
                Text("Original")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.secondary)
                textBox(item.originalText, lineLimit: 6)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func imageContent(_ info: ClipboardImageInfo) -> some View {
        let size = displaySize(for: info)
        return Group {
            if let image = previewImage ?? notesManager.imageStore.thumbnail(for: item.id) {
                Image(nsImage: image)
                    .resizable()
                    .interpolation(.high)
                    .aspectRatio(contentMode: .fit)
            } else {
                Image(systemName: "photo")
                    .font(.system(size: 32))
                    .foregroundStyle(.secondary)
            }
        }
        .frame(width: size.width, height: size.height)
        .background(Color.primary.opacity(0.04))
        .clipShape(RoundedRectangle(cornerRadius: 6))
        .overlay(RoundedRectangle(cornerRadius: 6).strokeBorder(Color.secondary.opacity(0.3), lineWidth: 0.5))
        .frame(maxWidth: .infinity)
        .task(id: item.id) {
            let url = notesManager.imageStore.imageURL(for: item.id)
            let maxPixels = Int(max(size.width, size.height) * 2)
            let image = await Task.detached(priority: .userInitiated) {
                ClipboardImageStore.previewImage(at: url, maxPixels: maxPixels)
            }.value
            if let image {
                previewImage = NSImage(cgImage: image, size: .zero)
            }
        }
    }

    /// Fits the image into the preview without enlarging small images.
    private func displaySize(for info: ClipboardImageInfo) -> CGSize {
        let maxWidth = Self.imageWidth - 28
        let width = CGFloat(max(info.width, 1))
        let height = CGFloat(max(info.height, 1))
        let scale = min(maxWidth / width, Self.maxImageHeight / height, 1)
        return CGSize(width: max(width * scale, 24), height: max(height * scale, 24))
    }

    private var filesContent: some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach(Array(item.fileURLs.prefix(Self.maxFiles)), id: \.self) { url in
                fileRow(url)
            }
            if item.filePaths.count > Self.maxFiles {
                Text("… and \(item.filePaths.count - Self.maxFiles) more")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func fileRow(_ url: URL) -> some View {
        let values = try? url.resourceValues(forKeys: [.localizedTypeDescriptionKey, .fileSizeKey, .isDirectoryKey])
        let folder = (url.deletingLastPathComponent().path as NSString).abbreviatingWithTildeInPath
        return HStack(spacing: 8) {
            Image(nsImage: NSWorkspace.shared.icon(forFile: url.path))
                .resizable()
                .frame(width: 30, height: 30)
                .opacity(values == nil ? 0.4 : 1)
            VStack(alignment: .leading, spacing: 1) {
                Text(url.lastPathComponent)
                    .font(.system(size: 12, weight: .medium))
                    .lineLimit(1)
                    .truncationMode(.middle)
                if let values {
                    Text(fileDetails(values))
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                } else {
                    Text("No longer exists – can't be pasted")
                        .font(.system(size: 11))
                        .foregroundStyle(.red)
                }
                Text(folder)
                    .font(.system(size: 10))
                    .foregroundStyle(.tertiary)
                    .lineLimit(1)
                    .truncationMode(.head)
            }
        }
    }

    private func fileDetails(_ values: URLResourceValues) -> String {
        var details = [values.localizedTypeDescription ?? (values.isDirectory == true ? "Folder" : "File")]
        if values.isDirectory != true, let size = values.fileSize {
            details.append(ByteCountFormatter.string(fromByteCount: Int64(size), countStyle: .file))
        }
        return details.joined(separator: " · ")
    }

    private func linkContent(_ url: URL) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            if let title = item.linkTitle {
                Text(title)
                    .font(.system(size: 13, weight: .semibold))
                    .lineLimit(3)
            }
            Text(url.absoluteString)
                .font(.system(size: 11))
                .foregroundStyle(Color.accentColor)
                .lineLimit(4)
                .truncationMode(.middle)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    /// The text in a light box, cut after a few lines with a note on what is left.
    private func textBox(_ text: String, lineLimit: Int) -> some View {
        let lines = text.components(separatedBy: .newlines)
        var shown = lines.prefix(lineLimit).joined(separator: "\n")
        if shown.count > Self.maxPreviewCharacters {
            shown = String(shown.prefix(Self.maxPreviewCharacters)) + "…"
        }
        let hiddenLines = max(lines.count - lineLimit, 0)
        return VStack(alignment: .leading, spacing: 4) {
            Text(shown.isEmpty ? " " : shown)
                .font(.system(size: 12))
                .lineLimit(lineLimit + 4)
                .fixedSize(horizontal: false, vertical: true)
            if hiddenLines > 0 {
                Text("+ \(hiddenLines) more \(hiddenLines == 1 ? "line" : "lines")")
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
            }
        }
        .padding(8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.primary.opacity(0.05), in: RoundedRectangle(cornerRadius: 6))
    }

    // MARK: Details

    private var details: some View {
        Grid(alignment: .leadingFirstTextBaseline, horizontalSpacing: 10, verticalSpacing: 4) {
            ForEach(detailRows, id: \.label) { row in
                GridRow {
                    Text(row.label)
                        .foregroundStyle(.secondary)
                        .gridColumnAlignment(.trailing)
                    Text(row.value)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .font(.system(size: 11))
    }

    private struct DetailRow {
        let label: String
        let value: String
    }

    private var detailRows: [DetailRow] {
        var rows = [DetailRow(label: "Copied", value: Self.dateFormatter.string(from: item.date))]
        if let bundleId = item.sourceAppBundleId {
            rows.append(DetailRow(label: "App ID", value: bundleId))
        }
        if let info = item.imageInfo {
            let size = ByteCountFormatter.string(fromByteCount: Int64(info.byteCount), countStyle: .file)
            rows.append(DetailRow(label: "Image", value: "\(info.width) × \(info.height) pixels"))
            rows.append(DetailRow(label: "Stored", value: "PNG, \(size)"))
            rows.append(DetailRow(label: "Copied as", value: info.originalFormat))
        } else if item.isTextItem {
            if let url = item.linkURL {
                rows.append(DetailRow(label: "Link", value: linkInfo(for: url)))
            } else {
                rows.append(DetailRow(label: "Size", value: sizeDescription(for: item.text)))
            }
            if let formatting = formattingInfo {
                rows.append(DetailRow(label: "Formatting", value: formatting))
            }
            if item.text != item.originalText {
                rows.append(DetailRow(label: "Edited", value: "Pastes the edited text"))
            }
        }
        let formats = ClipboardFormats.displayNames(for: item.pasteboardTypes)
        if !formats.isEmpty {
            rows.append(DetailRow(label: "Formats", value: formats.joined(separator: ", ")))
        }
        if let slot = item.pinnedSlot {
            rows.append(DetailRow(label: "Pinned", value: "Slot \(slot), paste with ⌥\(slot)"))
        }
        return rows
    }

    private func linkInfo(for url: URL) -> String {
        var parts = [url.scheme?.lowercased() == "http" ? "Not encrypted (http)" : "Encrypted (https)"]
        if item.linkTitle == nil {
            parts.append("no title, Markdown links use the domain")
        }
        return parts.joined(separator: ", ")
    }

    /// Which formatted versions are kept and whether a paste uses them.
    private var formattingInfo: String? {
        guard !item.richTextFormats.isEmpty else { return nil }
        let formats = item.richTextFormats.map { format -> String in
            guard let bytes = notesManager.richTextStore.byteCount(format: format, for: item.id) else {
                return format.displayName
            }
            return "\(format.displayName) \(ByteCountFormatter.string(fromByteCount: Int64(bytes), countStyle: .file))"
        }.joined(separator: ", ")
        let usage: String
        if !item.canPasteRichText {
            usage = "not used, the text was edited"
        } else if pasteAsPlainText {
            usage = "not used, Paste as Plain Text is on"
        } else {
            usage = "pastes with formatting"
        }
        return "\(formats) – \(usage)"
    }

    private func sizeDescription(for text: String) -> String {
        let characters = text.count
        let lines = text.reduce(into: 1) { count, character in
            if character.isNewline { count += 1 }
        }
        let words = text.split(whereSeparator: { $0.isWhitespace || $0.isNewline }).count
        var parts = ["\(characters) \(characters == 1 ? "character" : "characters")"]
        parts.append("\(words) \(words == 1 ? "word" : "words")")
        if lines > 1 {
            parts.append("\(lines) lines")
        }
        return parts.joined(separator: ", ")
    }

    private var sourceAppIcon: NSImage {
        if let bundleId = item.sourceAppBundleId,
           let appURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleId) {
            return NSWorkspace.shared.icon(forFile: appURL.path)
        }
        return NSImage(systemSymbolName: "doc.on.clipboard", accessibilityDescription: "Clipboard") ?? NSImage()
    }

    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .medium
        return formatter
    }()

    private static let relativeFormatter: RelativeDateTimeFormatter = {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .full
        return formatter
    }()
}
