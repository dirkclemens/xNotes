//
//  MarkdownTokenizer.swift
//  MarkdownEditor
//
//  Zerlegt Markdown-Quelltext in Tokens für das Syntax-Highlighting.
//  Importiert bewusst nur Foundation, damit die Datei ohne Xcode testbar ist
//  (siehe Tests/run.sh).
//

import Foundation

enum MarkdownTokenKind: Hashable {
    // Syntaxzeichen ohne eigene Bedeutung: ** * _ ~~ == ` # [ ] ( ) < > \x
    case markup

    // Blöcke
    case heading(level: Int)      // Text der Überschrift, ohne die #-Zeichen
    case headingID                // {#custom-id}
    case blockquoteMarker         // > (inklusive folgendem Leerzeichen)
    case blockquote               // Text hinter dem Marker
    case listMarker               // -, *, +, 1., 1)
    case taskOpen                 // [ ]
    case taskDone                 // [x] oder [X]
    case horizontalRule           // ---, ***, ___
    case codeFence                // die Zeichen ``` oder ~~~
    case codeInfo                 // Sprachangabe hinter der öffnenden Fence
    case codeBlock                // Inhaltszeilen eines Codeblocks
    case tablePipe                // |
    case tableSeparator           // die ganze Trennzeile | --- | --- |
    case tableHeader              // Zellinhalt der Kopfzeile
    case footnote                 // [^1] und [^1]:
    case definitionMarker         // : am Zeilenanfang einer Definition

    // Inline
    case bold
    case italic
    case boldItalic
    case strikethrough
    case highlight                // ==text==
    case subscriptText            // H~2~O
    case superscriptText          // X^2^
    case inlineCode               // Inhalt zwischen den Backticks
    case linkText
    case linkURL
    case imageMarker              // das ! vor einem Bild
    case imageAlt
    case imageURL
    case emoji                    // :joy:
    case htmlTag                  // <div>, </div>
}

struct MarkdownToken: Equatable {
    let kind: MarkdownTokenKind
    let range: NSRange
}

struct MarkdownTokenizer {

    // MARK: - Muster

    private static func regex(_ pattern: String) -> NSRegularExpression {
        // Die Muster sind Konstanten; ein Fehler hier ist ein Programmierfehler.
        try! NSRegularExpression(pattern: pattern)
    }

    // Block-Muster. Sie werden immer nur auf den Bereich einer einzelnen Zeile
    // (ohne Zeilenende) angewendet; ^ und $ passen dabei an den Bereichsgrenzen.
    static let fenceOpen           = regex(#"^ {0,3}(`{3,}|~{3,})[ \t]*(.*)$"#)
    static let tableSeparator      = regex(#"^\s*\|?\s*:?-+:?\s*(\|\s*:?-+:?\s*)*\|?\s*$"#)
    static let horizontalRule      = regex(#"^ {0,3}([-*_])([ \t]*\1){2,}[ \t]*$"#)
    static let setextUnderline     = regex(#"^ {0,3}(=+|-+)[ \t]*$"#)
    static let atxHeading          = regex(#"^ {0,3}(#{1,6})(?:[ \t]+(.*?))?[ \t]*$"#)
    static let headingID           = regex(#"\{#[^}\s]+\}$"#)
    static let blockquote          = regex(#"^ {0,3}((?:>[ ]?)+)(.*)$"#)
    static let listItem            = regex(#"^([ \t]*)([-*+]|\d{1,9}[.)])([ \t]+)(.*)$"#)
    static let footnoteDefinition  = regex(#"^ {0,3}(\[\^[^\]\s]+\]:)(.*)$"#)
    static let referenceDefinition = regex(#"^ {0,3}\[([^\]]+)\]:[ \t]*(\S+)(.*)$"#)
    static let definition          = regex(#"^:[ \t]+(.*)$"#)

    // Inline-Muster. Sie werden verankert (.anchored) an der aktuellen Position geprüft.
    static let htmlTag = regex(#"</?[A-Za-z][^>]*>"#)
    static let bareURL = regex(#"https?://[^\s<>]+"#)
    static let emoji   = regex(#":[a-z0-9_+-]+:"#)
    static let autolinkURL   = regex(#"^[A-Za-z][A-Za-z0-9+.\-]{1,31}://[^\s<>]*$"#)
    static let autolinkEmail = regex(#"^[^\s@<>]+@[^\s@<>]+\.[^\s@<>]+$"#)

    // MARK: - Zeichen

    private static let backslash: unichar = 0x5C   // \
    private static let backtick: unichar  = 0x60   // `
    private static let tilde: unichar     = 0x7E   // ~
    private static let pipe: unichar      = 0x7C   // |
    private static let newline: unichar   = 0x0A
    private static let space: unichar     = 0x20
    private static let tab: unichar       = 0x09
    private static let asterisk: unichar  = 0x2A   // *
    private static let underscore: unichar = 0x5F  // _
    private static let exclamation: unichar = 0x21 // !
    private static let openBracket: unichar = 0x5B // [
    private static let closeBracket: unichar = 0x5D // ]
    private static let openParen: unichar = 0x28   // (
    private static let closeParen: unichar = 0x29  // )
    private static let lessThan: unichar  = 0x3C   // <
    private static let greaterThan: unichar = 0x3E // >
    private static let equals: unichar    = 0x3D   // =
    private static let caret: unichar     = 0x5E   // ^
    private static let colon: unichar     = 0x3A   // :
    private static let letterH: unichar   = 0x68   // h

    // MARK: - Zerlegung

    private enum LineKind {
        case start, blank, paragraph, code, definition, other
    }

    /// Zerlegt den gesamten Text in Tokens.
    /// Reihenfolge: Die Tokens sind so sortiert, dass ein späteres Token ein
    /// früheres überlagern darf (erst der Block, dann die Inline-Elemente darin,
    /// äußere Inline-Elemente vor inneren).
    static func tokenize(_ text: String) -> [MarkdownToken] {
        // Eine echte NSString-Kopie: schneller UTF-16-Zugriff für alle folgenden Schritte.
        let ns = NSString(string: text)
        let string = ns as String
        let lines = lineRanges(of: ns)

        var tokens: [MarkdownToken] = []
        tokens.reserveCapacity(lines.count * 2)

        var fence: (char: unichar, length: Int)? = nil
        var inList = false
        var inTable = false
        var previous: LineKind = .start

        var index = 0
        while index < lines.count {
            let line = lines[index]

            // 1. In einer Fence
            if let open = fence {
                if let marker = closingFence(ns, line, char: open.char, minLength: open.length) {
                    emit(.codeFence, marker, &tokens)
                    fence = nil
                    previous = .other
                } else {
                    emit(.codeBlock, line, &tokens)
                    previous = .code
                }
                index += 1
                continue
            }

            let blank = isBlank(ns, line)
            if !blank && !startsWithWhitespace(ns, line) {
                inList = false
            }

            // 2. Fence öffnen
            if let match = fenceOpen.firstMatch(in: string, range: line) {
                let marker = match.range(at: 1)
                let info = trimmed(ns, match.range(at: 2))
                let char = ns.character(at: marker.location)
                let infoHasBacktick = info.length > 0
                    && ns.range(of: "`", options: .literal, range: info).location != NSNotFound
                if !(char == backtick && infoHasBacktick) {
                    emit(.codeFence, marker, &tokens)
                    emit(.codeInfo, info, &tokens)
                    fence = (char, marker.length)
                    previous = .other
                    index += 1
                    continue
                }
            }

            // 3. Leerzeile
            if blank {
                inTable = false
                previous = .blank
                index += 1
                continue
            }

            let hasPipe = containsPipe(ns, line)

            // 4. Tabellenzeile
            if inTable {
                if hasPipe {
                    tableRow(ns, line, header: false, into: &tokens)
                    previous = .other
                    index += 1
                    continue
                }
                inTable = false
            }

            // 5. Tabellenkopf
            if hasPipe, index + 1 < lines.count, isTableSeparator(ns, string, lines[index + 1]) {
                tableRow(ns, line, header: true, into: &tokens)
                emit(.tableSeparator, lines[index + 1], &tokens)
                inTable = true
                previous = .other
                index += 2
                continue
            }

            // 6. Eingerückter Code
            if !inList, startsWithCodeIndent(ns, line),
               previous == .start || previous == .blank || previous == .code {
                emit(.codeBlock, line, &tokens)
                previous = .code
                index += 1
                continue
            }

            // 7. Horizontale Linie (8. Setext-Unterstreichung hat Vorrang)
            let isSetextUnderline = previous == .paragraph
                && setextUnderline.firstMatch(in: string, range: line) != nil
            if !isSetextUnderline, horizontalRule.firstMatch(in: string, range: line) != nil {
                emit(.horizontalRule, line, &tokens)
                previous = .other
                index += 1
                continue
            }

            // 8. Setext-Unterstreichung ohne vorausgeschaute Absatzzeile
            //    (der Normalfall wird in Regel 15 per Vorausschau erledigt)
            if isSetextUnderline {
                emit(.markup, trimmed(ns, line), &tokens)
                previous = .other
                index += 1
                continue
            }

            // 9. ATX-Überschrift
            if let match = atxHeading.firstMatch(in: string, range: line) {
                let hashes = match.range(at: 1)
                emit(.markup, hashes, &tokens)
                var content = match.range(at: 2)
                if content.location != NSNotFound, content.length > 0 {
                    if let id = headingID.firstMatch(in: string, range: content) {
                        let before = NSRange(location: content.location, length: id.range.location - content.location)
                        content = trimmed(ns, before)
                        emit(.heading(level: hashes.length), content, &tokens)
                        emit(.headingID, id.range, &tokens)
                    } else {
                        emit(.heading(level: hashes.length), content, &tokens)
                    }
                    parseInline(ns, range: content, into: &tokens)
                }
                previous = .other
                index += 1
                continue
            }

            // 10. Zitat
            if let match = blockquote.firstMatch(in: string, range: line) {
                let content = match.range(at: 2)
                emit(.blockquoteMarker, match.range(at: 1), &tokens)
                emit(.blockquote, content, &tokens)
                parseInline(ns, range: content, into: &tokens)
                previous = .other
                index += 1
                continue
            }

            // 11. Listenpunkt
            if let match = listItem.firstMatch(in: string, range: line) {
                emit(.listMarker, match.range(at: 2), &tokens)
                var rest = match.range(at: 4)
                if rest.length >= 3 {
                    let boxRange = NSRange(location: rest.location, length: 3)
                    let box = ns.substring(with: boxRange)
                    let boxEnds = rest.length == 3 || isWhitespace(ns.character(at: rest.location + 3))
                    if boxEnds, box == "[ ]" || box == "[x]" || box == "[X]" {
                        emit(box == "[ ]" ? .taskOpen : .taskDone, boxRange, &tokens)
                        rest = NSRange(location: rest.location + 3, length: rest.length - 3)
                    }
                }
                parseInline(ns, range: rest, into: &tokens)
                inList = true
                previous = .other
                index += 1
                continue
            }

            // 12. Fußnoten-Definition
            if let match = footnoteDefinition.firstMatch(in: string, range: line) {
                emit(.footnote, match.range(at: 1), &tokens)
                parseInline(ns, range: match.range(at: 2), into: &tokens)
                previous = .other
                index += 1
                continue
            }

            // 13. Referenz-Definition
            if let match = referenceDefinition.firstMatch(in: string, range: line) {
                let label = match.range(at: 1)
                emit(.markup, NSRange(location: label.location - 1, length: 1), &tokens)
                emit(.linkText, label, &tokens)
                emit(.markup, NSRange(location: NSMaxRange(label), length: 2), &tokens)
                emit(.linkURL, match.range(at: 2), &tokens)
                previous = .other
                index += 1
                continue
            }

            // 14. Definition
            if previous == .paragraph || previous == .definition,
               let match = definition.firstMatch(in: string, range: line) {
                emit(.definitionMarker, NSRange(location: line.location, length: 1), &tokens)
                parseInline(ns, range: match.range(at: 1), into: &tokens)
                previous = .definition
                index += 1
                continue
            }

            // 15. Absatz – mit Vorausschau auf eine Setext-Unterstreichung (Regel 8)
            if index + 1 < lines.count,
               let underline = setextUnderline.firstMatch(in: string, range: lines[index + 1]) {
                let marker = underline.range(at: 1)
                let level = ns.character(at: marker.location) == equals ? 1 : 2
                let content = trimmed(ns, line)
                emit(.heading(level: level), content, &tokens)
                parseInline(ns, range: content, into: &tokens)
                emit(.markup, marker, &tokens)
                previous = .other
                index += 2
                continue
            }

            parseInline(ns, range: line, into: &tokens)
            previous = .paragraph
            index += 1
        }

        return tokens
    }

    // MARK: - Blöcke: Hilfsfunktionen

    /// Bereiche aller Zeilen ohne Zeilenende.
    private static func lineRanges(of text: NSString) -> [NSRange] {
        var ranges: [NSRange] = []
        var position = 0
        let length = text.length
        while position < length {
            var start = 0, end = 0, contentsEnd = 0
            text.getLineStart(&start, end: &end, contentsEnd: &contentsEnd,
                              for: NSRange(location: position, length: 0))
            ranges.append(NSRange(location: start, length: contentsEnd - start))
            position = end
        }
        return ranges
    }

    private static func emit(_ kind: MarkdownTokenKind, _ range: NSRange, _ tokens: inout [MarkdownToken]) {
        guard range.location != NSNotFound, range.length > 0 else { return }
        tokens.append(MarkdownToken(kind: kind, range: range))
    }

    private static func isBlank(_ text: NSString, _ range: NSRange) -> Bool {
        for i in range.location..<NSMaxRange(range) {
            let c = text.character(at: i)
            if c != space && c != tab { return false }
        }
        return true
    }

    private static func startsWithWhitespace(_ text: NSString, _ range: NSRange) -> Bool {
        guard range.length > 0 else { return false }
        let c = text.character(at: range.location)
        return c == space || c == tab
    }

    private static func startsWithCodeIndent(_ text: NSString, _ range: NSRange) -> Bool {
        guard range.length > 0 else { return false }
        if text.character(at: range.location) == tab { return true }
        guard range.length >= 4 else { return false }
        for i in range.location..<(range.location + 4) where text.character(at: i) != space {
            return false
        }
        return true
    }

    /// Bereich ohne Leerzeichen und Tabs am Anfang und Ende.
    private static func trimmed(_ text: NSString, _ range: NSRange) -> NSRange {
        guard range.location != NSNotFound else { return range }
        var start = range.location
        var end = NSMaxRange(range)
        while start < end, isWhitespace(text.character(at: start)) { start += 1 }
        while end > start, isWhitespace(text.character(at: end - 1)) { end -= 1 }
        return NSRange(location: start, length: end - start)
    }

    private static func containsPipe(_ text: NSString, _ range: NSRange) -> Bool {
        text.range(of: "|", options: .literal, range: range).location != NSNotFound
    }

    private static func isTableSeparator(_ text: NSString, _ string: String, _ range: NSRange) -> Bool {
        containsPipe(text, range) && tableSeparator.firstMatch(in: string, range: range) != nil
    }

    /// Prüft, ob die Zeile eine passende schließende Fence ist, und liefert den Bereich der Fence-Zeichen.
    private static func closingFence(_ text: NSString, _ line: NSRange, char: unichar, minLength: Int) -> NSRange? {
        let end = NSMaxRange(line)
        var i = line.location
        var indent = 0
        while i < end, text.character(at: i) == space, indent < 3 {
            i += 1
            indent += 1
        }
        let start = i
        while i < end, text.character(at: i) == char { i += 1 }
        let length = i - start
        guard length >= minLength else { return nil }
        while i < end {
            let c = text.character(at: i)
            if c != space && c != tab { return nil }
            i += 1
        }
        return NSRange(location: start, length: length)
    }

    /// Gibt Pipes und Zellinhalte einer Tabellenzeile aus.
    private static func tableRow(_ text: NSString, _ line: NSRange, header: Bool, into tokens: inout [MarkdownToken]) {
        let end = NSMaxRange(line)
        var pipes: [Int] = []
        var i = line.location
        while i < end {
            let c = text.character(at: i)
            if c == backslash {
                i += 2
                continue
            }
            if c == pipe { pipes.append(i) }
            i += 1
        }
        for position in pipes {
            emit(.tablePipe, NSRange(location: position, length: 1), &tokens)
        }
        var cellStart = line.location
        for boundary in pipes + [end] {
            let cell = trimmed(text, NSRange(location: cellStart, length: boundary - cellStart))
            if cell.length > 0 {
                if header { emit(.tableHeader, cell, &tokens) }
                parseInline(text, range: cell, into: &tokens)
            }
            cellStart = boundary + 1
        }
    }

    // MARK: - Inline

    private static func parseInline(_ text: NSString, range: NSRange, into tokens: inout [MarkdownToken]) {
        guard range.location != NSNotFound, range.length > 0 else { return }
        let end = NSMaxRange(range)
        var i = range.location

        while i < end {
            let c = text.character(at: i)

            switch c {
            case backslash:
                // 1. Escape
                if i + 1 < end, isASCIIPunctuation(text.character(at: i + 1)) {
                    emit(.markup, NSRange(location: i, length: 2), &tokens)
                    i += 2
                    continue
                }

            case backtick:
                // 2. Code-Span
                let n = runLength(text, from: i, end: end, char: c)
                if let close = findBacktickClose(text, from: i + n, end: end, length: n) {
                    emit(.markup, NSRange(location: i, length: n), &tokens)
                    emit(.inlineCode, NSRange(location: i + n, length: close - i - n), &tokens)
                    emit(.markup, NSRange(location: close, length: n), &tokens)
                    i = close + n
                } else {
                    i += n
                }
                continue

            case exclamation:
                // 3. Bild
                if i + 1 < end, text.character(at: i + 1) == openBracket,
                   let link = parseLink(text, bracket: i + 1, end: end) {
                    emit(.imageMarker, NSRange(location: i, length: 1), &tokens)
                    emit(.markup, NSRange(location: i + 1, length: 1), &tokens)
                    emit(.imageAlt, link.text, &tokens)
                    emit(.markup, NSRange(location: NSMaxRange(link.text), length: 2), &tokens)
                    emit(.imageURL, link.url, &tokens)
                    emit(.markup, NSRange(location: link.end - 1, length: 1), &tokens)
                    i = link.end
                    continue
                }

            case openBracket:
                // 4. Fußnoten-Verweis
                if let footnoteEnd = parseFootnoteReference(text, bracket: i, end: end) {
                    emit(.footnote, NSRange(location: i, length: footnoteEnd - i), &tokens)
                    i = footnoteEnd
                    continue
                }
                // 5. Link
                if let link = parseLink(text, bracket: i, end: end) {
                    emit(.markup, NSRange(location: i, length: 1), &tokens)
                    emit(.linkText, link.text, &tokens)
                    emit(.markup, NSRange(location: NSMaxRange(link.text), length: 2), &tokens)
                    emit(.linkURL, link.url, &tokens)
                    emit(.markup, NSRange(location: link.end - 1, length: 1), &tokens)
                    parseInline(text, range: link.text, into: &tokens)
                    i = link.end
                    continue
                }
                // 6. Referenz-Link
                if let link = parseReferenceLink(text, bracket: i, end: end) {
                    emit(.markup, NSRange(location: i, length: 1), &tokens)
                    emit(.linkText, link.text, &tokens)
                    emit(.markup, NSRange(location: NSMaxRange(link.text), length: 2), &tokens)
                    emit(.linkURL, link.url, &tokens)
                    emit(.markup, NSRange(location: link.end - 1, length: 1), &tokens)
                    parseInline(text, range: link.text, into: &tokens)
                    i = link.end
                    continue
                }

            case lessThan:
                // 7. Autolink
                if let url = parseAutolink(text, bracket: i, end: end) {
                    emit(.markup, NSRange(location: i, length: 1), &tokens)
                    emit(.linkURL, url, &tokens)
                    emit(.markup, NSRange(location: NSMaxRange(url), length: 1), &tokens)
                    i = NSMaxRange(url) + 1
                    continue
                }
                // 8. HTML-Tag
                if let match = htmlTag.firstMatch(in: text as String, options: .anchored,
                                                  range: NSRange(location: i, length: end - i)) {
                    emit(.htmlTag, match.range, &tokens)
                    i = NSMaxRange(match.range)
                    continue
                }

            case letterH:
                // 9. Nackte URL
                if i + 4 < end, text.character(at: i + 1) == 0x74, // t
                   i == 0 || !isAlphanumeric(text.character(at: i - 1)),
                   let match = bareURL.firstMatch(in: text as String, options: .anchored,
                                                  range: NSRange(location: i, length: end - i)) {
                    let url = trimURL(text, match.range)
                    emit(.linkURL, url, &tokens)
                    i = NSMaxRange(url)
                    continue
                }

            case asterisk, underscore:
                // 10. Hervorhebung
                let n = runLength(text, from: i, end: end, char: c)
                if n <= 3, canOpenEmphasis(text, at: i, length: n, end: end, char: c),
                   let close = findClosingRun(text, char: c, length: n, from: i + n, end: end, emphasis: true) {
                    let content = NSRange(location: i + n, length: close - i - n)
                    let kind: MarkdownTokenKind = n == 1 ? .italic : (n == 2 ? .bold : .boldItalic)
                    emit(.markup, NSRange(location: i, length: n), &tokens)
                    emit(kind, content, &tokens)
                    emit(.markup, NSRange(location: close, length: n), &tokens)
                    parseInline(text, range: content, into: &tokens)
                    i = close + n
                } else {
                    i += n
                }
                continue

            case tilde:
                let n = runLength(text, from: i, end: end, char: c)
                // 11. Durchgestrichen
                if n == 2, i + 2 < end, !isWhitespace(text.character(at: i + 2)),
                   let close = findClosingRun(text, char: c, length: 2, from: i + 2, end: end, emphasis: false) {
                    let content = NSRange(location: i + 2, length: close - i - 2)
                    emit(.markup, NSRange(location: i, length: 2), &tokens)
                    emit(.strikethrough, content, &tokens)
                    emit(.markup, NSRange(location: close, length: 2), &tokens)
                    parseInline(text, range: content, into: &tokens)
                    i = close + 2
                    continue
                }
                // 13. Tiefgestellt
                if n == 1, let close = findTightClose(text, char: c, from: i + 1, end: end) {
                    emit(.markup, NSRange(location: i, length: 1), &tokens)
                    emit(.subscriptText, NSRange(location: i + 1, length: close - i - 1), &tokens)
                    emit(.markup, NSRange(location: close, length: 1), &tokens)
                    i = close + 1
                    continue
                }
                i += n
                continue

            case equals:
                // 12. Markierung
                let n = runLength(text, from: i, end: end, char: c)
                if n == 2, i + 2 < end, !isWhitespace(text.character(at: i + 2)),
                   let close = findClosingRun(text, char: c, length: 2, from: i + 2, end: end, emphasis: false) {
                    let content = NSRange(location: i + 2, length: close - i - 2)
                    emit(.markup, NSRange(location: i, length: 2), &tokens)
                    emit(.highlight, content, &tokens)
                    emit(.markup, NSRange(location: close, length: 2), &tokens)
                    parseInline(text, range: content, into: &tokens)
                    i = close + 2
                } else {
                    i += n
                }
                continue

            case caret:
                // 14. Hochgestellt
                if let close = findTightClose(text, char: c, from: i + 1, end: end) {
                    emit(.markup, NSRange(location: i, length: 1), &tokens)
                    emit(.superscriptText, NSRange(location: i + 1, length: close - i - 1), &tokens)
                    emit(.markup, NSRange(location: close, length: 1), &tokens)
                    i = close + 1
                    continue
                }

            case colon:
                // 15. Emoji
                let previousOK = i == 0 || {
                    let p = text.character(at: i - 1)
                    return !isAlphanumeric(p) && p != colon
                }()
                if previousOK,
                   let match = emoji.firstMatch(in: text as String, options: .anchored,
                                                range: NSRange(location: i, length: end - i)) {
                    emit(.emoji, match.range, &tokens)
                    i = NSMaxRange(match.range)
                    continue
                }

            default:
                break
            }

            i += 1
        }
    }

    // MARK: - Inline: Hilfsfunktionen

    private static func runLength(_ text: NSString, from start: Int, end: Int, char: unichar) -> Int {
        var i = start
        while i < end, text.character(at: i) == char { i += 1 }
        return i - start
    }

    /// Sucht die nächste Folge von genau `length` Backticks.
    private static func findBacktickClose(_ text: NSString, from start: Int, end: Int, length: Int) -> Int? {
        var i = start
        while i < end {
            if text.character(at: i) == backtick {
                let n = runLength(text, from: i, end: end, char: backtick)
                if n == length { return i }
                i += n
            } else {
                i += 1
            }
        }
        return nil
    }

    private static func canOpenEmphasis(_ text: NSString, at i: Int, length: Int, end: Int, char: unichar) -> Bool {
        guard i + length < end, !isWhitespace(text.character(at: i + length)) else { return false }
        if char == underscore, i > 0, isAlphanumeric(text.character(at: i - 1)) { return false }
        return true
    }

    /// Sucht eine schließende Folge von genau `length` Zeichen `char`.
    /// Escapes und Code-Spans werden übersprungen. Mit `emphasis` gelten
    /// zusätzlich die Regeln für * und _ (kein Leerzeichen davor, bei _ kein
    /// Buchstabe oder Ziffer danach).
    private static func findClosingRun(_ text: NSString, char: unichar, length: Int, from start: Int, end: Int, emphasis: Bool) -> Int? {
        var i = start
        while i < end {
            let c = text.character(at: i)
            if c == backslash {
                i += 2
                continue
            }
            if c == backtick {
                let n = runLength(text, from: i, end: end, char: backtick)
                if let close = findBacktickClose(text, from: i + n, end: end, length: n) {
                    i = close + n
                } else {
                    i += n
                }
                continue
            }
            if c == char {
                let n = runLength(text, from: i, end: end, char: char)
                if n == length, i > start, !isWhitespace(text.character(at: i - 1)) {
                    let afterIndex = i + n
                    let afterOK = !emphasis || char != underscore
                        || afterIndex >= text.length || !isAlphanumeric(text.character(at: afterIndex))
                    if afterOK { return i }
                }
                i += n
                continue
            }
            i += 1
        }
        return nil
    }

    /// Für Tief- und Hochgestellt: schließendes Zeichen, Inhalt ohne Leerzeichen, nicht leer.
    private static func findTightClose(_ text: NSString, char: unichar, from start: Int, end: Int) -> Int? {
        var i = start
        while i < end {
            let c = text.character(at: i)
            if c == char { return i > start ? i : nil }
            if isWhitespace(c) { return nil }
            i += 1
        }
        return nil
    }

    /// Passende schließende Klammer; berücksichtigt Verschachtelung und Escapes.
    private static func findMatching(_ text: NSString, open: unichar, close: unichar, from start: Int, end: Int) -> Int? {
        var depth = 1
        var i = start
        while i < end {
            let c = text.character(at: i)
            if c == backslash {
                i += 2
                continue
            }
            if c == open {
                depth += 1
            } else if c == close {
                depth -= 1
                if depth == 0 { return i }
            }
            i += 1
        }
        return nil
    }

    /// `[text](url)` ab der öffnenden eckigen Klammer.
    private static func parseLink(_ text: NSString, bracket: Int, end: Int) -> (text: NSRange, url: NSRange, end: Int)? {
        guard let closeBracketIndex = findMatching(text, open: openBracket, close: closeBracket, from: bracket + 1, end: end),
              closeBracketIndex + 1 < end,
              text.character(at: closeBracketIndex + 1) == openParen,
              let closeParenIndex = findMatching(text, open: openParen, close: closeParen, from: closeBracketIndex + 2, end: end)
        else { return nil }
        let label = NSRange(location: bracket + 1, length: closeBracketIndex - bracket - 1)
        let url = NSRange(location: closeBracketIndex + 2, length: closeParenIndex - closeBracketIndex - 2)
        return (label, url, closeParenIndex + 1)
    }

    /// `[text][ref]` ab der öffnenden eckigen Klammer.
    private static func parseReferenceLink(_ text: NSString, bracket: Int, end: Int) -> (text: NSRange, url: NSRange, end: Int)? {
        guard let closeBracketIndex = findMatching(text, open: openBracket, close: closeBracket, from: bracket + 1, end: end),
              closeBracketIndex + 1 < end,
              text.character(at: closeBracketIndex + 1) == openBracket
        else { return nil }
        let refStart = closeBracketIndex + 2
        var i = refStart
        while i < end {
            let c = text.character(at: i)
            if c == closeBracket { break }
            if c == openBracket { return nil }
            i += 1
        }
        guard i < end else { return nil }
        let label = NSRange(location: bracket + 1, length: closeBracketIndex - bracket - 1)
        let reference = NSRange(location: refStart, length: i - refStart)
        return (label, reference, i + 1)
    }

    /// `[^label]` – liefert die Position hinter der schließenden Klammer.
    private static func parseFootnoteReference(_ text: NSString, bracket: Int, end: Int) -> Int? {
        guard bracket + 1 < end, text.character(at: bracket + 1) == caret else { return nil }
        var i = bracket + 2
        while i < end {
            let c = text.character(at: i)
            if c == closeBracket { return i > bracket + 2 ? i + 1 : nil }
            if isWhitespace(c) || c == openBracket { return nil }
            i += 1
        }
        return nil
    }

    /// `<scheme://…>` oder `<name@domain.tld>` – liefert den Bereich zwischen den spitzen Klammern.
    private static func parseAutolink(_ text: NSString, bracket: Int, end: Int) -> NSRange? {
        var i = bracket + 1
        while i < end {
            let c = text.character(at: i)
            if c == greaterThan { break }
            if isWhitespace(c) || c == lessThan { return nil }
            i += 1
        }
        guard i < end, i > bracket + 1 else { return nil }
        let content = NSRange(location: bracket + 1, length: i - bracket - 1)
        let string = text as String
        if autolinkURL.firstMatch(in: string, range: content) != nil
            || autolinkEmail.firstMatch(in: string, range: content) != nil {
            return content
        }
        return nil
    }

    /// Entfernt Satzzeichen am Ende einer nackten URL. Eine schließende Klammer
    /// bleibt erhalten, wenn sie eine öffnende Klammer in der URL schließt.
    private static func trimURL(_ text: NSString, _ range: NSRange) -> NSRange {
        var end = NSMaxRange(range)
        let trailing: Set<unichar> = [0x2E, 0x2C, 0x3B, 0x3A, 0x21, 0x3F, asterisk, underscore, tilde] // . , ; : ! ? * _ ~
        while end > range.location {
            let c = text.character(at: end - 1)
            if trailing.contains(c) {
                end -= 1
            } else if c == closeParen {
                var open = 0, close = 0
                for k in range.location..<end {
                    let ch = text.character(at: k)
                    if ch == openParen { open += 1 } else if ch == closeParen { close += 1 }
                }
                if close > open { end -= 1 } else { break }
            } else {
                break
            }
        }
        return NSRange(location: range.location, length: end - range.location)
    }

    // MARK: - Zeichenklassen

    private static func isWhitespace(_ c: unichar) -> Bool {
        c == space || c == tab || c == newline || c == 0x0D || c == 0xA0
    }

    private static func isASCIIPunctuation(_ c: unichar) -> Bool {
        (0x21...0x2F).contains(c) || (0x3A...0x40).contains(c)
            || (0x5B...0x60).contains(c) || (0x7B...0x7E).contains(c)
    }

    private static func isAlphanumeric(_ c: unichar) -> Bool {
        if c < 0x80 {
            return (0x30...0x39).contains(c) || (0x41...0x5A).contains(c) || (0x61...0x7A).contains(c)
        }
        guard let scalar = Unicode.Scalar(c) else { return false }
        return CharacterSet.alphanumerics.contains(scalar)
    }
}

// MARK: - Code-Kontext

extension MarkdownTokenizer {
    /// Prüft, ob `position` in einem Code-Block oder in Inline-Code liegt.
    ///
    /// Grundlage sind die Tokens zum aktuellen Text. Zusätzlich zählt ein noch nicht
    /// geschlossener Code-Span in derselben Zeile (`` `print(" ``), weil er beim Tippen
    /// noch kein inlineCode-Token hat.
    static func isCode(at position: Int, in text: NSString, tokens: [MarkdownToken]) -> Bool {
        guard position >= 0, position <= text.length else { return false }
        for token in tokens where token.kind == .codeBlock || token.kind == .inlineCode {
            if token.range.location <= position && position < NSMaxRange(token.range) {
                return true
            }
        }
        return isInOpenCodeSpan(at: position, in: text)
    }

    /// Läuft die Zeile bis `position` ab und merkt sich, ob ein Backtick-Lauf geöffnet,
    /// aber noch nicht mit einem gleich langen Lauf geschlossen wurde.
    private static func isInOpenCodeSpan(at position: Int, in text: NSString) -> Bool {
        let backtick: unichar = 0x60
        let backslash: unichar = 0x5C
        var index = text.lineRange(for: NSRange(location: position, length: 0)).location
        var openRun: Int?
        while index < position {
            let character = text.character(at: index)
            if character == backslash && openRun == nil {
                index += 2
                continue
            }
            guard character == backtick else {
                index += 1
                continue
            }
            var run = 0
            while index < position && text.character(at: index) == backtick {
                run += 1
                index += 1
            }
            if openRun == nil {
                openRun = run
            } else if openRun == run {
                openRun = nil
            }
        }
        return openRun != nil
    }
}
