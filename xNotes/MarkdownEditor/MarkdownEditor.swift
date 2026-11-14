//
//  MarkdownEditor.swift
//  MarkdownEditor
//
//  Created by Dirk Clemens on 20.10.25.
//
//  Taken from https://github.com/dirkclemens/MarkdownEditor (editor only, no preview).
//  xNotes changes: configurable font instead of a fixed monospaced size, optional
//  line numbers, search highlight and focus handling.
//

import SwiftUI
import AppKit

/// A range to select and reveal in the editor without taking keyboard focus.
/// A new `id` triggers the highlight again even for the same range.
struct MarkdownEditorHighlight: Equatable {
    let id: UUID
    let range: NSRange
}

struct MarkdownEditor: NSViewRepresentable {
    @Binding var text: String
    var font: NSFont
    let theme: MarkdownEditorTheme
    var showsLineNumbers: Bool
    let gutterWidth: CGFloat
    let separatorWidth: CGFloat
    /// Range to select and reveal (e.g. the current search match).
    var highlight: MarkdownEditorHighlight?
    /// Makes the text view first responder when it appears and whenever this turns `true`.
    var autoFocus: Bool
    var onTextViewReady: ((NSTextView) -> Void)? = nil

    init(text: Binding<String>,
         font: NSFont = .monospacedSystemFont(ofSize: 14, weight: .regular),
         theme: MarkdownEditorTheme,
         showsLineNumbers: Bool = false,
         gutterWidth: CGFloat = 44,
         separatorWidth: CGFloat = 1.0,
         highlight: MarkdownEditorHighlight? = nil,
         autoFocus: Bool = true,
         onTextViewReady: ((NSTextView) -> Void)? = nil) {
        self._text = text
        self.font = font
        self.theme = theme
        self.showsLineNumbers = showsLineNumbers
        self.gutterWidth = gutterWidth
        self.separatorWidth = separatorWidth
        self.highlight = highlight
        self.autoFocus = autoFocus
        self.onTextViewReady = onTextViewReady
    }

    private var effectiveGutterWidth: CGFloat {
        showsLineNumbers ? gutterWidth : 0
    }

    func makeNSView(context: Context) -> NSView {
        let coordinator = context.coordinator
        let containerView = NSView()

        let lineNumberView = LineNumberView(separatorWidth: separatorWidth)
        lineNumberView.translatesAutoresizingMaskIntoConstraints = false
        lineNumberView.isHidden = !showsLineNumbers

        let scrollView = NSTextView.scrollableTextView()
        let textView = scrollView.documentView as! NSTextView
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.borderType = .noBorder
        scrollView.autohidesScrollers = true

        textView.isRichText = false
        textView.allowsUndo = true
        textView.textContainerInset = NSSize(width: 8, height: 8)
        textView.textContainer?.lineFragmentPadding = 0

        containerView.addSubview(lineNumberView)
        containerView.addSubview(scrollView)

        let gutterWidthConstraint = lineNumberView.widthAnchor.constraint(equalToConstant: effectiveGutterWidth)
        NSLayoutConstraint.activate([
            lineNumberView.leadingAnchor.constraint(equalTo: containerView.leadingAnchor),
            lineNumberView.topAnchor.constraint(equalTo: containerView.topAnchor),
            lineNumberView.bottomAnchor.constraint(equalTo: containerView.bottomAnchor),
            gutterWidthConstraint,

            scrollView.leadingAnchor.constraint(equalTo: lineNumberView.trailingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: containerView.trailingAnchor),
            scrollView.topAnchor.constraint(equalTo: containerView.topAnchor),
            scrollView.bottomAnchor.constraint(equalTo: containerView.bottomAnchor)
        ])

        coordinator.textView = textView
        coordinator.lineNumberView = lineNumberView
        coordinator.scrollView = scrollView
        coordinator.gutterWidthConstraint = gutterWidthConstraint
        lineNumberView.textView = textView
        lineNumberView.scrollView = scrollView

        textView.delegate = coordinator
        textView.textStorage?.delegate = coordinator

        textView.string = text
        coordinator.applyStyle(to: textView)
        coordinator.highlightNow()

        // Zeilennummern bei jeder Scroll-Bewegung neu zeichnen (Maus, Tastatur, programmatisch).
        scrollView.contentView.postsBoundsChangedNotifications = true
        coordinator.scrollObserver = NotificationCenter.default.addObserver(
            forName: NSView.boundsDidChangeNotification,
            object: scrollView.contentView,
            queue: .main
        ) { [weak lineNumberView] _ in
            MainActor.assumeIsolated {
                lineNumberView?.needsDisplay = true
            }
        }

        coordinator.appliedAutoFocus = autoFocus
        if autoFocus {
            coordinator.focusTextView()
        }

        onTextViewReady?(textView)
        return containerView
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        let coordinator = context.coordinator
        coordinator.parent = self
        guard let textView = coordinator.textView else { return }

        // Nur Änderungen von außen übernehmen (Öffnen, Zurücksetzen). Ein Vergleich mit
        // textView.string wäre falsch: Während einer Tottasten-Eingabe (` ^ ´ auf deutscher
        // Tastatur) enthält die Text View vorläufigen Text, der noch nicht im Binding steht.
        var needsHighlight = false
        if text != coordinator.syncedText {
            coordinator.syncedText = text
            if textView.string != text {
                let selection = textView.selectedRange()
                textView.unmarkText()
                textView.string = text
                let length = (text as NSString).length
                textView.setSelectedRange(NSRange(location: min(selection.location, length), length: 0))
                needsHighlight = true
            }
        }
        if coordinator.appliedTheme != theme || coordinator.appliedFont != font {
            coordinator.applyStyle(to: textView)
            needsHighlight = true
        }
        if needsHighlight {
            coordinator.highlightNow()
            coordinator.lineNumberView?.needsDisplay = true
        }

        coordinator.gutterWidthConstraint?.constant = effectiveGutterWidth
        coordinator.lineNumberView?.isHidden = !showsLineNumbers

        if let highlight, highlight != coordinator.appliedHighlight {
            coordinator.appliedHighlight = highlight
            coordinator.reveal(highlight.range)
        }

        // Fokus nur beim Wechsel auf `true` übernehmen, sonst würde er anderen Feldern
        // (z. B. der Suche oder dem Umbenennen eines Tabs) bei jedem Update entzogen.
        if autoFocus && !coordinator.appliedAutoFocus {
            coordinator.focusTextView()
        }
        coordinator.appliedAutoFocus = autoFocus
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    final class Coordinator: NSObject, NSTextViewDelegate, NSTextStorageDelegate {
        var parent: MarkdownEditor
        var textView: NSTextView?
        var lineNumberView: LineNumberView?
        var scrollView: NSScrollView?
        var gutterWidthConstraint: NSLayoutConstraint?
        nonisolated(unsafe) var scrollObserver: NSObjectProtocol?
        private var pendingHighlight: DispatchWorkItem?
        var appliedTheme: MarkdownEditorTheme?
        var appliedFont: NSFont?
        var appliedHighlight: MarkdownEditorHighlight?
        var appliedAutoFocus = false
        /// Tokens des letzten Highlight-Durchlaufs (Grundlage für das inkrementelle Einfärben).
        private var lastTokens: [MarkdownToken]?
        /// Seit dem letzten Durchlauf geänderter Bereich (heutige Koordinaten) und Längenänderung.
        private var pendingEdit: (range: NSRange, delta: Int)?
        /// Text, der zuletzt zwischen Text View und Binding ausgetauscht wurde.
        var syncedText: String

        init(_ parent: MarkdownEditor) {
            self.parent = parent
            self.syncedText = parent.text
        }

        deinit {
            if let scrollObserver {
                NotificationCenter.default.removeObserver(scrollObserver)
            }
        }

        func textDidChange(_ notification: Notification) {
            guard let textView = notification.object as? NSTextView else { return }
            syncedText = textView.string
            parent.text = syncedText
            lineNumberView?.needsDisplay = true
        }

        func textStorage(_ textStorage: NSTextStorage, didProcessEditing editedMask: NSTextStorageEditActions, range editedRange: NSRange, changeInLength delta: Int) {
            guard editedMask.contains(.editedCharacters) else { return }
            recordEdit(editedRange, delta: delta)
            scheduleHighlight()
        }

        /// Verhindert Gedankenstriche überall und typografische Ersetzungen (Anführungszeichen,
        /// Textersetzungen, Autokorrektur) in Code-Blöcken und Inline-Code.
        func textView(_ textView: NSTextView, didCheckTextIn range: NSRange, types checkingTypes: NSTextCheckingTypes,
                      options: [NSSpellChecker.OptionKey: Any], results: [NSTextCheckingResult],
                      orthography: NSOrthography, wordCount: Int) -> [NSTextCheckingResult] {
            // Bindestrich-Folgen sind in Markdown Syntax (---, | --- |, Setext, Front Matter, Listen),
            // deshalb werden Gedankenstriche nirgends ersetzt – auch nicht im Fließtext.
            let results = results.filter { !$0.resultType.contains(.dash) }

            let substitutions: NSTextCheckingResult.CheckingType = [.quote, .replacement, .correction]
            func isSubstitution(_ result: NSTextCheckingResult) -> Bool {
                !result.resultType.intersection(substitutions).isEmpty
            }
            guard results.contains(where: isSubstitution) else { return results }

            // lastTokens kennt den gerade getippten Text noch nicht (Highlight folgt erst nach 20 ms).
            // Die Attribute dürfen hier nicht geändert werden, sonst verwirft die Text View
            // auch die erlaubten Ersetzungen – deshalb nur tokenisieren, nicht einfärben.
            let tokens: [MarkdownToken]
            if pendingEdit == nil, let lastTokens {
                tokens = lastTokens
            } else {
                tokens = MarkdownTokenizer.tokenize(textView.string)
            }
            let text = textView.string as NSString
            // Die Ranges der Ergebnisse sind relativ zum geprüften Bereich, nicht zum Dokument.
            return results.filter { result in
                !isSubstitution(result)
                    || !MarkdownTokenizer.isCode(at: range.location + result.range.location, in: text, tokens: tokens)
            }
        }

        /// Färbt den gesamten Text neu ein (Start, Theme- oder Schriftwechsel, Text von außen ersetzt).
        func highlightNow() {
            pendingHighlight?.cancel()
            pendingEdit = nil
            guard let storage = textView?.textStorage else { return }
            lastTokens = MarkdownHighlighter(theme: parent.theme, font: parent.font).apply(to: storage)
        }

        /// Färbt nach Texteingaben nur die geänderten Zeilen neu ein.
        func highlightChanges() {
            pendingHighlight?.cancel()
            guard let storage = textView?.textStorage else { return }
            guard let previous = lastTokens, let edit = pendingEdit else {
                highlightNow()
                return
            }
            pendingEdit = nil
            lastTokens = MarkdownHighlighter(theme: parent.theme, font: parent.font)
                .apply(to: storage, previous: previous, edit: edit)
        }

        func scheduleHighlight() {
            pendingHighlight?.cancel()
            let work = DispatchWorkItem { [weak self] in self?.highlightChanges() }
            pendingHighlight = work
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.02, execute: work)
        }

        /// Fasst mehrere Änderungen zwischen zwei Durchläufen zu einem Bereich zusammen.
        private func recordEdit(_ range: NSRange, delta: Int) {
            guard let pending = pendingEdit else {
                pendingEdit = (range, delta)
                return
            }
            // Bisherigen Bereich in die Koordinaten nach dieser Änderung übertragen.
            let oldEditEnd = NSMaxRange(range) - delta
            var shifted = pending.range
            if NSMaxRange(shifted) <= range.location {
                // liegt vor der Änderung – unverändert
            } else if shifted.location >= oldEditEnd {
                shifted.location += delta
            } else {
                let start = min(shifted.location, range.location)
                let end = max(NSMaxRange(shifted) + delta, NSMaxRange(range))
                shifted = NSRange(location: start, length: max(0, end - start))
            }
            pendingEdit = (NSUnionRange(shifted, range), pending.delta + delta)
        }

        /// Setzt alle themenabhängigen Eigenschaften der Text View und der Zeilennummern.
        func applyStyle(to textView: NSTextView) {
            let theme = parent.theme
            let font = parent.font
            textView.backgroundColor = theme.backgroundColor
            scrollView?.backgroundColor = theme.backgroundColor
            textView.insertionPointColor = theme.insertionPointColor
            textView.selectedTextAttributes = [.backgroundColor: theme.selectionColor]
            textView.typingAttributes = [.font: font, .foregroundColor: theme.textColor]
            lineNumberView?.backgroundColor = theme.gutterBackgroundColor
            lineNumberView?.textColor = theme.gutterTextColor
            lineNumberView?.fontSize = font.pointSize
            appliedTheme = theme
            appliedFont = font
        }

        /// Selektiert einen Bereich und scrollt ihn sichtbar, ohne den Fokus zu übernehmen.
        func reveal(_ range: NSRange) {
            // Erst nach dem Layout ausführen, wenn die Text View in einem Fenster hängt.
            DispatchQueue.main.async { [weak self] in
                guard let textView = self?.textView else { return }
                guard NSMaxRange(range) <= (textView.string as NSString).length else { return }
                textView.setSelectedRange(range)
                textView.scrollRangeToVisible(range)
                if textView.window != nil {
                    textView.showFindIndicator(for: range)
                }
            }
        }

        /// Macht die Text View zum First Responder, sobald sie in einem Fenster hängt.
        func focusTextView(retries: Int = 3) {
            DispatchQueue.main.async { [weak self] in
                guard let self, self.parent.autoFocus, let textView = self.textView else { return }
                guard let window = textView.window else {
                    if retries > 0 { self.focusTextView(retries: retries - 1) }
                    return
                }
                if window.firstResponder !== textView {
                    window.makeFirstResponder(textView)
                }
            }
        }
    }
}

final class LineNumberView: NSView {
    weak var textView: NSTextView?
    weak var scrollView: NSScrollView?
    let separatorWidth: CGFloat

    var backgroundColor: NSColor = .controlBackgroundColor {
        didSet { needsDisplay = true }
    }
    var textColor: NSColor = .secondaryLabelColor {
        didSet { needsDisplay = true }
    }
    var fontSize: CGFloat = 14 {
        didSet { needsDisplay = true }
    }

    init(separatorWidth: CGFloat = 1.0) {
        self.separatorWidth = separatorWidth
        super.init(frame: .zero)
    }

    override init(frame frameRect: NSRect) {
        self.separatorWidth = 1.0
        super.init(frame: frameRect)
    }

    required init?(coder: NSCoder) {
        self.separatorWidth = 1.0
        super.init(coder: coder)
    }

    // Oben links als Ursprung – entspricht dem Koordinatensystem der Text View.
    override var isFlipped: Bool { true }

    override func draw(_ dirtyRect: NSRect) {
        backgroundColor.setFill()
        dirtyRect.fill()

        NSColor.separatorColor.setStroke()
        let separatorPath = NSBezierPath()
        let separatorX = bounds.maxX - separatorWidth / 2.0
        separatorPath.move(to: NSPoint(x: separatorX, y: bounds.minY))
        separatorPath.line(to: NSPoint(x: separatorX, y: bounds.maxY))
        separatorPath.lineWidth = separatorWidth
        separatorPath.stroke()

        guard let textView,
              let scrollView,
              let layoutManager = textView.layoutManager,
              let textContainer = textView.textContainer,
              let storage = textView.textStorage
        else { return }

        let attributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.monospacedSystemFont(ofSize: fontSize, weight: .regular),
            .foregroundColor: textColor
        ]
        let text = storage.string as NSString
        let visibleRect = scrollView.documentVisibleRect
        let origin = textView.textContainerOrigin
        let visibleContainerRect = visibleRect.offsetBy(dx: -origin.x, dy: -origin.y)

        func drawNumber(_ number: Int, in fragmentRect: NSRect) {
            let label = "\(number)" as NSString
            let size = label.size(withAttributes: attributes)
            let y = fragmentRect.minY + origin.y - visibleRect.minY
            label.draw(at: NSPoint(x: bounds.width - size.width - 10, y: y), withAttributes: attributes)
        }

        let glyphRange = layoutManager.glyphRange(forBoundingRect: visibleContainerRect, in: textContainer)
        if glyphRange.length > 0 {
            var lineNumber: Int? = nil
            layoutManager.enumerateLineFragments(forGlyphRange: glyphRange) { rect, _, _, fragmentGlyphRange, _ in
                let charIndex = layoutManager.characterIndexForGlyph(at: fragmentGlyphRange.location)
                // Nummer der Zeile vor dem ersten sichtbaren Fragment – nur einmal zählen.
                var current = lineNumber ?? Self.countNewlines(in: text, upTo: charIndex)
                let startsLine = charIndex == 0 || text.character(at: charIndex - 1) == 0x0A
                if startsLine {
                    current += 1
                    drawNumber(current, in: rect)
                }
                lineNumber = current
            }
        }

        // Leere letzte Zeile nach einem abschließenden Zeilenumbruch (oder leeres Dokument).
        let extraRect = layoutManager.extraLineFragmentRect
        if extraRect.height > 0,
           text.length == 0 || text.character(at: text.length - 1) == 0x0A,
           extraRect.intersects(visibleContainerRect) {
            drawNumber(Self.countNewlines(in: text, upTo: text.length) + 1, in: extraRect)
        }
    }

    /// Anzahl der Zeilenumbrüche vor `index`.
    private static func countNewlines(in text: NSString, upTo index: Int) -> Int {
        var count = 0
        var buffer = [unichar](repeating: 0, count: 4096)
        var position = 0
        while position < index {
            let length = min(buffer.count, index - position)
            text.getCharacters(&buffer, range: NSRange(location: position, length: length))
            for i in 0..<length where buffer[i] == 0x0A {
                count += 1
            }
            position += length
        }
        return count
    }
}
