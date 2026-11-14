//
//  MarkdownHighlighter.swift
//  MarkdownEditor
//
//  Setzt die Darstellungsattribute im NSTextStorage anhand der Tokens
//  aus MarkdownTokenizer.
//
//  xNotes changes: configurable base font, clickable links (`.link`).
//

import AppKit

struct MarkdownHighlighter {
    let theme: MarkdownEditorTheme
    let font: NSFont

    private static let styledAttributes: [NSAttributedString.Key] = [
        .foregroundColor, .backgroundColor, .font, .strikethroughStyle, .underlineStyle, .baselineOffset, .link
    ]

    /// Färbt den gesamten Text neu ein und liefert die verwendeten Tokens.
    @discardableResult
    func apply(to storage: NSTextStorage) -> [MarkdownToken] {
        let tokens = MarkdownTokenizer.tokenize(storage.string)
        style(NSRange(location: 0, length: storage.length), with: tokens, in: storage)
        return tokens
    }

    /// Färbt nur die Zeilen neu ein, deren Tokens sich seit dem letzten Durchlauf geändert haben.
    ///
    /// - Parameters:
    ///   - previous: Tokens des letzten Durchlaufs (vor der Änderung).
    ///   - edit: Geänderter Bereich in heutigen Koordinaten und Längenänderung des Texts
    ///     seit dem letzten Durchlauf.
    /// - Returns: Die neuen Tokens für den nächsten Durchlauf.
    func apply(to storage: NSTextStorage, previous: [MarkdownToken], edit: (range: NSRange, delta: Int)) -> [MarkdownToken] {
        let length = storage.length
        let editStart = min(max(edit.range.location, 0), length)
        let editEndNew = min(max(NSMaxRange(edit.range), editStart), length)
        let editEndOld = editEndNew - edit.delta
        guard editEndOld >= editStart else { return apply(to: storage) }

        // Der Tokenizer läuft immer über den ganzen Text, damit mehrzeilige
        // Konstrukte wie Fences korrekt bleiben.
        let tokens = MarkdownTokenizer.tokenize(storage.string)

        // Gemeinsamer Anfang: unveränderte Tokens vollständig vor der Änderung.
        let common = min(previous.count, tokens.count)
        var prefix = 0
        while prefix < common,
              previous[prefix] == tokens[prefix],
              NSMaxRange(tokens[prefix].range) <= editStart {
            prefix += 1
        }

        // Gemeinsames Ende: Tokens hinter der Änderung, nur um die Längenänderung verschoben.
        var suffix = 0
        while suffix < common - prefix {
            let old = previous[previous.count - 1 - suffix]
            let new = tokens[tokens.count - 1 - suffix]
            guard old.kind == new.kind,
                  old.range.length == new.range.length,
                  old.range.location >= editEndOld,
                  new.range.location >= editEndNew,
                  old.range.location + edit.delta == new.range.location
            else { break }
            suffix += 1
        }

        // Bereich dazwischen: geänderter Text plus alle abweichenden Tokens (alt und neu).
        var dirtyStart = editStart
        var dirtyEnd = editEndNew
        for token in tokens[prefix..<(tokens.count - suffix)] {
            dirtyStart = min(dirtyStart, token.range.location)
            dirtyEnd = max(dirtyEnd, NSMaxRange(token.range))
        }
        // Alte Positionen in heutige Koordinaten übertragen: vor der Änderung unverändert,
        // dahinter um die Längenänderung verschoben, innerhalb auf den geänderten Bereich.
        func mapOld(_ position: Int, isEnd: Bool) -> Int {
            if position < editStart || (isEnd && position == editStart) { return position }
            if position > editEndOld || (!isEnd && position == editEndOld) { return position + edit.delta }
            return isEnd ? editEndNew : editStart
        }
        for token in previous[prefix..<(previous.count - suffix)] {
            dirtyStart = min(dirtyStart, mapOld(token.range.location, isEnd: false))
            dirtyEnd = max(dirtyEnd, mapOld(NSMaxRange(token.range), isEnd: true))
        }
        dirtyStart = max(0, min(dirtyStart, length))
        dirtyEnd = max(dirtyStart, min(dirtyEnd, length))

        let text = storage.string as NSString
        let dirty = text.lineRange(for: NSRange(location: dirtyStart, length: dirtyEnd - dirtyStart))
        let affected = tokens.filter {
            $0.range.location >= dirty.location && NSMaxRange($0.range) <= NSMaxRange(dirty)
        }
        style(dirty, with: affected, in: storage)
        return tokens
    }

    /// Setzt die Attribute im Bereich zurück und wendet die Tokens in Array-Reihenfolge an.
    private func style(_ range: NSRange, with tokens: [MarkdownToken], in storage: NSTextStorage) {
        guard range.length > 0 else { return }
        storage.beginEditing()
        defer { storage.endEditing() }

        for key in Self.styledAttributes {
            storage.removeAttribute(key, range: range)
        }
        storage.addAttribute(.font, value: font, range: range)
        storage.addAttribute(.foregroundColor, value: theme.textColor, range: range)

        for token in tokens {
            apply(token, to: storage)
        }
    }

    private func apply(_ token: MarkdownToken, to storage: NSTextStorage) {
        let range = token.range
        guard NSMaxRange(range) <= storage.length else { return }

        func color(_ value: NSColor) {
            storage.addAttribute(.foregroundColor, value: value, range: range)
        }
        func background(_ value: NSColor) {
            storage.addAttribute(.backgroundColor, value: value, range: range)
        }
        func traits(_ value: NSFontDescriptor.SymbolicTraits) {
            addTraits(value, in: range, storage: storage)
        }

        switch token.kind {
        case .markup:
            color(theme.markupColor)
        case .heading(let level):
            color(theme.headerColors[max(1, min(level, 6, theme.headerColors.count)) - 1])
            traits(.bold)
        case .headingID:
            color(theme.markupColor)
        case .blockquoteMarker:
            color(theme.blockquoteSymbolColor)
            traits(.bold)
        case .blockquote:
            color(theme.blockquoteColor)
        case .listMarker:
            color(theme.listColor)
            traits(.bold)
        case .taskOpen:
            color(theme.listColor)
        case .taskDone:
            color(theme.taskDoneColor)
        case .horizontalRule:
            color(theme.horizontalRuleColor)
        case .codeFence:
            color(theme.markupColor)
            background(theme.codeBackgroundColor)
        case .codeInfo:
            color(theme.listColor)
            background(theme.codeBackgroundColor)
        case .codeBlock:
            color(theme.codeColor)
            background(theme.codeBackgroundColor)
        case .tablePipe, .tableSeparator:
            color(theme.tableColor)
        case .tableHeader:
            traits(.bold)
        case .footnote:
            color(theme.footnoteColor)
        case .definitionMarker:
            color(theme.listColor)
            traits(.bold)
        case .bold:
            color(theme.boldColor)
            traits(.bold)
        case .italic:
            color(theme.italicColor)
            traits(.italic)
        case .boldItalic:
            color(theme.boldColor)
            traits([.bold, .italic])
        case .strikethrough:
            color(theme.strikethroughColor)
            storage.addAttribute(.strikethroughStyle, value: NSUnderlineStyle.single.rawValue, range: range)
        case .highlight:
            background(theme.highlightBackgroundColor)
        case .subscriptText, .superscriptText:
            color(theme.italicColor)
        case .inlineCode:
            color(theme.codeColor)
            background(theme.codeBackgroundColor)
        case .linkText:
            color(theme.linkColor)
            storage.addAttribute(.underlineStyle, value: NSUnderlineStyle.single.rawValue, range: range)
        case .linkURL:
            color(theme.markupColor)
            addLink(in: range, storage: storage)
        case .imageURL:
            color(theme.markupColor)
        case .imageMarker:
            color(theme.imageSymbolColor)
            traits(.bold)
        case .imageAlt:
            color(theme.imageColor)
            traits(.italic)
        case .emoji:
            color(theme.emojiColor)
        case .htmlTag:
            color(theme.htmlColor)
        }
    }

    /// Macht eine URL anklickbar (http, https, mailto); `<…>` von Autolinks wird nicht mitgenommen.
    private func addLink(in range: NSRange, storage: NSTextStorage) {
        let raw = (storage.string as NSString).substring(with: range)
            .trimmingCharacters(in: CharacterSet(charactersIn: "<>").union(.whitespaces))
        guard let url = URL(string: raw), let scheme = url.scheme?.lowercased() else {
            if raw.contains("@"), !raw.contains(":"), let mail = URL(string: "mailto:" + raw) {
                storage.addAttribute(.link, value: mail, range: range)
            }
            return
        }
        guard ["http", "https", "mailto"].contains(scheme) else { return }
        storage.addAttribute(.link, value: url, range: range)
    }

    /// Ergänzt Schrift-Eigenschaften, ohne vorhandene zu verlieren (fett + kursiv ergibt fett-kursiv).
    /// Die Schrift bleibt dabei in ihrer Familie.
    private func addTraits(_ traits: NSFontDescriptor.SymbolicTraits, in range: NSRange, storage: NSTextStorage) {
        var changes: [(NSFont, NSRange)] = []
        storage.enumerateAttribute(.font, in: range) { value, subRange, _ in
            guard let font = value as? NSFont else { return }
            let descriptor = font.fontDescriptor.withSymbolicTraits(font.fontDescriptor.symbolicTraits.union(traits))
            changes.append((NSFont(descriptor: descriptor, size: font.pointSize) ?? font, subRange))
        }
        for (font, subRange) in changes {
            storage.addAttribute(.font, value: font, range: subRange)
        }
    }
}
