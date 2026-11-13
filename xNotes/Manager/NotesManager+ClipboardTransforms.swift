//
//  NotesManager+ClipboardTransforms.swift
//  xNotes
//
//  Text transformations offered in the clipboard item context menu.
//

import Foundation
import AppKit

extension NotesManager {
    func editClipboardItem(id: ClipboardItem.ID, with text: String) {
        replaceClipboardItem(id: id, with: text, updatePasteboard: false)
    }

    func convertHtmlToMarkdownClipboardItem(id: ClipboardItem.ID) {
        transformClipboardItem(id: id) { text in
            htmlToMarkdown(text)
        }
    }

    func urlEncodeClipboardItem(id: ClipboardItem.ID) {
        transformClipboardItem(id: id) { text in
            text.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed)
        }
    }

    func urlDecodeClipboardItem(id: ClipboardItem.ID) {
        transformClipboardItem(id: id) { text in
            text.removingPercentEncoding
        }
    }

    func jsonPrettyPrintClipboardItem(id: ClipboardItem.ID) {
        transformClipboardItem(id: id) { text in
            guard let data = text.data(using: .utf8),
                  let object = try? JSONSerialization.jsonObject(with: data),
                  let pretty = try? JSONSerialization.data(withJSONObject: object, options: [.prettyPrinted, .sortedKeys]) else {
                return nil
            }
            return String(data: pretty, encoding: .utf8)
        }
    }

    func jsonMinifyClipboardItem(id: ClipboardItem.ID) {
        transformClipboardItem(id: id) { text in
            guard let data = text.data(using: .utf8),
                  let object = try? JSONSerialization.jsonObject(with: data),
                  let compact = try? JSONSerialization.data(withJSONObject: object, options: [.sortedKeys]) else {
                return nil
            }
            return String(data: compact, encoding: .utf8)
        }
    }

    func base64EncodeClipboardItem(id: ClipboardItem.ID) {
        transformClipboardItem(id: id) { text in
            Data(text.utf8).base64EncodedString()
        }
    }

    func base64DecodeClipboardItem(id: ClipboardItem.ID) {
        transformClipboardItem(id: id) { text in
            guard let data = Data(base64Encoded: text),
                  let decoded = String(data: data, encoding: .utf8) else {
                return nil
            }
            return decoded
        }
    }

    func sortLinesClipboardItem(id: ClipboardItem.ID) {
        transformClipboardItem(id: id) { text in
            text.components(separatedBy: .newlines)
                .sorted { $0.localizedCaseInsensitiveCompare($1) == .orderedAscending }
                .joined(separator: "\n")
        }
    }

    func uniqueLinesClipboardItem(id: ClipboardItem.ID) {
        transformClipboardItem(id: id) { text in
            var seen = Set<String>()
            return text.components(separatedBy: .newlines)
                .filter { seen.insert($0).inserted }
                .joined(separator: "\n")
        }
    }

    func trimEachLineClipboardItem(id: ClipboardItem.ID) {
        transformClipboardItem(id: id) { text in
            text.components(separatedBy: .newlines)
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .joined(separator: "\n")
        }
    }

    func convertToLFClipboardItem(id: ClipboardItem.ID) {
        transformClipboardItem(id: id) { text in
            text.replacingOccurrences(of: "\r\n", with: "\n")
                .replacingOccurrences(of: "\r", with: "\n")
        }
    }

    func convertToCRLFClipboardItem(id: ClipboardItem.ID) {
        transformClipboardItem(id: id) { text in
            let lf = text.replacingOccurrences(of: "\r\n", with: "\n")
                .replacingOccurrences(of: "\r", with: "\n")
            return lf.replacingOccurrences(of: "\n", with: "\r\n")
        }
    }

    func escapeShellClipboardItem(id: ClipboardItem.ID) {
        transformClipboardItem(id: id) { text in
            "'\(text.replacingOccurrences(of: "'", with: "'\"'\"'"))'"
        }
    }

    func escapeJSONStringClipboardItem(id: ClipboardItem.ID) {
        transformClipboardItem(id: id) { text in
            guard let data = try? JSONEncoder().encode(text),
                  let encoded = String(data: data, encoding: .utf8) else {
                return nil
            }
            return encoded
        }
    }

    func toSnakeCaseClipboardItem(id: ClipboardItem.ID) {
        transformClipboardItem(id: id) { text in
            let words = self.words(from: text)
            return words.joined(separator: "_")
        }
    }

    func toKebabCaseClipboardItem(id: ClipboardItem.ID) {
        transformClipboardItem(id: id) { text in
            let words = self.words(from: text)
            return words.joined(separator: "-")
        }
    }

    func toCamelCaseClipboardItem(id: ClipboardItem.ID) {
        transformClipboardItem(id: id) { text in
            let words = self.words(from: text)
            guard let first = words.first else { return nil }
            let tail = words.dropFirst().map { $0.prefix(1).uppercased() + $0.dropFirst() }
            return ([first] + tail).joined()
        }
    }

    func removeUnderscoreAndHyphenClipboardItem(id: ClipboardItem.ID) {
        transformClipboardItem(id: id) { text in
            text
                .replacingOccurrences(of: "_", with: " ")
                .replacingOccurrences(of: "-", with: " ")
        }
    }

    func reverseLinesClipboardItem(id: ClipboardItem.ID) {
        transformClipboardItem(id: id) { text in
            text.components(separatedBy: .newlines).reversed().joined(separator: "\n")
        }
    }

    func wrapInQuotesClipboardItem(id: ClipboardItem.ID) {
        transformClipboardItem(id: id) { text in
            "\"\(text)\""
        }
    }

    func unquoteClipboardItem(id: ClipboardItem.ID) {
        transformClipboardItem(id: id) { text in
            if text.hasPrefix("\""), text.hasSuffix("\""), text.count >= 2 {
                return String(text.dropFirst().dropLast())
            }
            if text.hasPrefix("'"), text.hasSuffix("'"), text.count >= 2 {
                return String(text.dropFirst().dropLast())
            }
            return nil
        }
    }

    func addPrefixClipboardItem(id: ClipboardItem.ID) {
        guard let prefix = promptForText(title: "Add Prefix", message: "Prefix:") else { return }
        transformClipboardItem(id: id) { text in
            "\(prefix)\(text)"
        }
    }

    func removePrefixClipboardItem(id: ClipboardItem.ID) {
        guard let prefix = promptForText(title: "Remove Prefix", message: "Prefix:") else { return }
        transformClipboardItem(id: id) { text in
            text.hasPrefix(prefix) ? String(text.dropFirst(prefix.count)) : nil
        }
    }

    func addSuffixClipboardItem(id: ClipboardItem.ID) {
        guard let suffix = promptForText(title: "Add Suffix", message: "Suffix:") else { return }
        transformClipboardItem(id: id) { text in
            "\(text)\(suffix)"
        }
    }

    func removeSuffixClipboardItem(id: ClipboardItem.ID) {
        guard let suffix = promptForText(title: "Remove Suffix", message: "Suffix:") else { return }
        transformClipboardItem(id: id) { text in
            text.hasSuffix(suffix) ? String(text.dropLast(suffix.count)) : nil
        }
    }

    func extractEmailsClipboardItem(id: ClipboardItem.ID) {
        transformClipboardItem(id: id) { text in
            self.extractedEmails(in: text)
                .joined(separator: "\n")
        }
    }

    func extractURLsClipboardItem(id: ClipboardItem.ID) {
        transformClipboardItem(id: id) { text in
            self.extractedURLs(in: text)
                .joined(separator: "\n")
        }
    }

    // MARK: - Helpers

    private func transformClipboardItem(id: ClipboardItem.ID, transform: (String) -> String?) {
        guard let current = clipboardText(for: id) else { return }
        guard let updated = transform(current), updated != current else { return }
        replaceClipboardItem(id: id, with: updated)
    }

    private func htmlToMarkdown(_ html: String) -> String {
        var markdown = html

        // Tables must be converted before inline tag stripping, so their cell
        // content can still benefit from bold/italic/code/link conversion below.
        markdown = convertHTMLTables(markdown)

        // Helper that allows `.` to match across newlines (needed for block elements).
        func regexReplace(_ pattern: String, template: String, in text: String) -> String {
            guard let regex = try? NSRegularExpression(
                pattern: pattern,
                options: [.caseInsensitive, .dotMatchesLineSeparators])
            else { return text }
            let range = NSRange(text.startIndex..<text.endIndex, in: text)
            return regex.stringByReplacingMatches(in: text, range: range, withTemplate: template)
        }

        // Code blocks first (so their inner tags are not converted).
        markdown = regexReplace(#"<pre[^>]*>(.*?)</pre>"#, template: "```\n$1\n```", in: markdown)

        // Headings.
        markdown = regexReplace(#"<h1[^>]*>(.*?)</h1>"#, template: "# $1\n\n", in: markdown)
        markdown = regexReplace(#"<h2[^>]*>(.*?)</h2>"#, template: "## $1\n\n", in: markdown)
        markdown = regexReplace(#"<h3[^>]*>(.*?)</h3>"#, template: "### $1\n\n", in: markdown)
        markdown = regexReplace(#"<h4[^>]*>(.*?)</h4>"#, template: "#### $1\n\n", in: markdown)
        markdown = regexReplace(#"<h5[^>]*>(.*?)</h5>"#, template: "##### $1\n\n", in: markdown)
        markdown = regexReplace(#"<h6[^>]*>(.*?)</h6>"#, template: "###### $1\n\n", in: markdown)

        // Links: [text](url)
        markdown = regexReplace(#"<a[^>]*href=["']([^"']*)["'][^>]*>(.*?)</a>"#, template: "[$2]($1)", in: markdown)

        // Images: ![alt](src)
        markdown = regexReplace(#"<img[^>]*src=["']([^"']*)["'][^>]*>"#, template: "![$1]", in: markdown)

        // Blockquotes.
        markdown = regexReplace(#"<blockquote[^>]*>(.*?)</blockquote>"#, template: "> $1\n\n", in: markdown)

        // Lists.
        markdown = regexReplace(#"<li[^>]*>(.*?)</li>"#, template: "- $1\n", in: markdown)
        markdown = regexReplace(#"</?(ul|ol)[^>]*>"#, template: "", in: markdown)

        // Horizontal rules.
        markdown = regexReplace(#"<hr\s*/?>"#, template: "\n---\n", in: markdown)

        // Inline code.
        markdown = regexReplace(#"<code[^>]*>(.*?)</code>"#, template: "`$1`", in: markdown)

        // Bold / strong.
        markdown = regexReplace(#"</?(b|strong)[^>]*>"#, template: "**", in: markdown)

        // Italic / emphasis.
        markdown = regexReplace(#"</?(i|em)[^>]*>"#, template: "*", in: markdown)

        // Paragraphs and line breaks.
        markdown = regexReplace(#"</p>"#, template: "\n\n", in: markdown)
        markdown = regexReplace(#"<p[^>]*>"#, template: "", in: markdown)
        markdown = regexReplace(#"<br\s*/?>"#, template: "\n", in: markdown)

        // Strip any remaining tags.
        markdown = regexReplace(#"<[^>]+>"#, template: "", in: markdown)

        // Decode common HTML entities.
        markdown = markdown.replacingOccurrences(of: "&nbsp;", with: " ")
        markdown = markdown.replacingOccurrences(of: "&amp;", with: "&")
        markdown = markdown.replacingOccurrences(of: "&lt;", with: "<")
        markdown = markdown.replacingOccurrences(of: "&gt;", with: ">")
        markdown = markdown.replacingOccurrences(of: "&quot;", with: "\"")
        markdown = markdown.replacingOccurrences(of: "&#39;", with: "'")
        markdown = markdown.replacingOccurrences(of: "&#x27;", with: "'")
        markdown = markdown.replacingOccurrences(of: "&#x22;", with: "\"")

        // Collapse excessive blank lines.
        markdown = regexReplace(#"\n{3,}"#, template: "\n\n", in: markdown)

        return markdown.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func convertHTMLTables(_ html: String) -> String {
        guard let regex = try? NSRegularExpression(
            pattern: #"<table[^>]*>(.*?)</table>"#,
            options: [.caseInsensitive, .dotMatchesLineSeparators])
        else { return html }

        var result = ""
        var lastEnd = 0
        let fullRange = NSRange(html.startIndex..<html.endIndex, in: html)

        for match in regex.matches(in: html, range: fullRange) {
            let tableRange = match.range
            let innerRange = match.range(at: 1)

            // Append text before this table.
            result += (html as NSString).substring(
                with: NSRange(location: lastEnd, length: tableRange.location - lastEnd))

            let inner = (html as NSString).substring(with: innerRange)
            result += renderTable(inner)

            lastEnd = tableRange.location + tableRange.length
        }

        result += (html as NSString).substring(from: lastEnd)
        return result
    }

    private func renderTable(_ inner: String) -> String {
        guard let rowRegex = try? NSRegularExpression(
            pattern: #"<tr[^>]*>(.*?)</tr>"#,
            options: [.caseInsensitive, .dotMatchesLineSeparators])
        else { return "" }

        let rowRange = NSRange(inner.startIndex..<inner.endIndex, in: inner)
        var rows: [[String]] = []

        for match in rowRegex.matches(in: inner, range: rowRange) {
            let cellRange = match.range(at: 1)
            let cellContent = (inner as NSString).substring(with: cellRange)

            guard let cellRegex = try? NSRegularExpression(
                pattern: #"<t[hd][^>]*>(.*?)</t[hd]>"#,
                options: [.caseInsensitive, .dotMatchesLineSeparators])
            else { continue }

            let cellFullRange = NSRange(cellContent.startIndex..<cellContent.endIndex, in: cellContent)
            var cells: [String] = []

            for cellMatch in cellRegex.matches(in: cellContent, range: cellFullRange) {
                let cRange = cellMatch.range(at: 1)
                var cellText = (cellContent as NSString).substring(with: cRange)
                cellText = cellText.trimmingCharacters(in: .whitespacesAndNewlines)
                cells.append(cellText)
            }

            if !cells.isEmpty {
                rows.append(cells)
            }
        }

        guard !rows.isEmpty else { return "" }

        var md = ""
        for (rowIndex, row) in rows.enumerated() {
            md += "| " + row.joined(separator: " | ") + " |\n"
            if rowIndex == 0 {
                md += "| " + row.map { _ in "---" }.joined(separator: " | ") + " |\n"
            }
        }
        md += "\n"
        return md
    }

    private func words(from text: String) -> [String] {
        let parts = text
            .replacingOccurrences(of: "_", with: " ")
            .replacingOccurrences(of: "-", with: " ")
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .flatMap { chunk -> [String] in
                guard !chunk.isEmpty else { return [] }
                let split = chunk.replacingOccurrences(
                    of: "([a-z0-9])([A-Z])",
                    with: "$1 $2",
                    options: .regularExpression
                )
                return split.split(separator: " ").map { $0.lowercased() }
            }
        return parts.filter { !$0.isEmpty }
    }

    private func promptForText(title: String, message: String) -> String? {
        let alert = NSAlert()
        alert.messageText = title
        alert.informativeText = message
        alert.addButton(withTitle: "OK")
        alert.addButton(withTitle: "Cancel")
        let field = NSTextField(frame: NSRect(x: 0, y: 0, width: 280, height: 24))
        alert.accessoryView = field
        let result = alert.runModal()
        guard result == .alertFirstButtonReturn else { return nil }
        return field.stringValue
    }

    private func extractedEmails(in text: String) -> [String] {
        let pattern = #"[A-Z0-9a-z._%+\-]+@[A-Za-z0-9.\-]+\.[A-Za-z]{2,}"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return [] }
        let range = NSRange(text.startIndex..<text.endIndex, in: text)
        let matches = regex.matches(in: text, range: range).compactMap { result -> String? in
            guard let r = Range(result.range, in: text) else { return nil }
            return String(text[r])
        }
        return Array(NSOrderedSet(array: matches)) as? [String] ?? matches
    }

    private func extractedURLs(in text: String) -> [String] {
        guard let detector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.link.rawValue) else { return [] }
        let range = NSRange(text.startIndex..<text.endIndex, in: text)
        let urls = detector.matches(in: text, options: [], range: range).compactMap { result -> String? in
            guard let url = result.url else { return nil }
            if url.scheme?.lowercased() == "mailto" { return nil }
            return url.absoluteString
        }
        return Array(NSOrderedSet(array: urls)) as? [String] ?? urls
    }
}
