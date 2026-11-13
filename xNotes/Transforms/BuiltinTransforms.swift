//
//  BuiltinTransforms.swift
//  xNotes
//
//  The transforms that ship with the app. Pure functions, safe to run off the main thread.
//

import Foundation

nonisolated enum BuiltinTransforms {
    enum Group {
        static let textCase = "Case"
        static let whitespace = "Whitespace"
        static let lines = "Lines"
        static let encode = "Encode & Decode"
        static let json = "JSON"
        static let quotes = "Quotes & Escaping"
        static let affix = "Prefix & Suffix"
        static let extract = "Extract"

        /// Order of the built-in submenus. Plugin-only groups are appended after these.
        static let order = [textCase, whitespace, lines, encode, json, quotes, affix, extract]
    }

    static let all: [ClipboardTransform] = [
        // Case
        ClipboardTransform(id: "case.upper", title: "UPPERCASE", group: Group.textCase) { text, _ in
            text.uppercased()
        },
        ClipboardTransform(id: "case.lower", title: "lowercase", group: Group.textCase) { text, _ in
            text.lowercased()
        },
        ClipboardTransform(id: "case.snake", title: "snake_case", group: Group.textCase, section: 1) { text, _ in
            words(from: text).joined(separator: "_")
        },
        ClipboardTransform(id: "case.kebab", title: "kebab-case", group: Group.textCase, section: 1) { text, _ in
            words(from: text).joined(separator: "-")
        },
        ClipboardTransform(id: "case.camel", title: "camelCase", group: Group.textCase, section: 1) { text, _ in
            let parts = words(from: text)
            guard let first = parts.first else { return nil }
            let tail = parts.dropFirst().map { $0.prefix(1).uppercased() + $0.dropFirst() }
            return ([first] + tail).joined()
        },
        ClipboardTransform(id: "case.separators-to-spaces", title: "Replace `_` and `-` with Spaces", group: Group.textCase, section: 2) { text, _ in
            text.replacingOccurrences(of: "_", with: " ")
                .replacingOccurrences(of: "-", with: " ")
        },

        // Whitespace
        ClipboardTransform(id: "ws.trim", title: "Trim", group: Group.whitespace) { text, _ in
            text.trimmingCharacters(in: .whitespacesAndNewlines)
        },
        ClipboardTransform(id: "ws.trim-lines", title: "Trim Each Line", group: Group.whitespace) { text, _ in
            text.components(separatedBy: .newlines)
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .joined(separator: "\n")
        },
        ClipboardTransform(id: "ws.collapse", title: "Collapse Whitespace", group: Group.whitespace) { text, _ in
            text.split(whereSeparator: { $0.isWhitespace }).joined(separator: " ")
        },

        // Lines
        ClipboardTransform(id: "lines.sort", title: "Sort Lines", group: Group.lines) { text, _ in
            text.components(separatedBy: .newlines)
                .sorted { $0.localizedCaseInsensitiveCompare($1) == .orderedAscending }
                .joined(separator: "\n")
        },
        ClipboardTransform(id: "lines.unique", title: "Unique Lines", group: Group.lines) { text, _ in
            var seen = Set<String>()
            return text.components(separatedBy: .newlines)
                .filter { seen.insert($0).inserted }
                .joined(separator: "\n")
        },
        ClipboardTransform(id: "lines.reverse", title: "Reverse Lines", group: Group.lines) { text, _ in
            text.components(separatedBy: .newlines).reversed().joined(separator: "\n")
        },
        ClipboardTransform(id: "lines.lf", title: "Line Endings → LF", group: Group.lines, section: 1) { text, _ in
            normalizedToLF(text)
        },
        ClipboardTransform(id: "lines.crlf", title: "Line Endings → CRLF", group: Group.lines, section: 1) { text, _ in
            normalizedToLF(text).replacingOccurrences(of: "\n", with: "\r\n")
        },

        // Encode & Decode
        ClipboardTransform(id: "encode.url", title: "URL Encode", group: Group.encode) { text, _ in
            text.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed)
        },
        ClipboardTransform(id: "decode.url", title: "URL Decode", group: Group.encode) { text, _ in
            text.removingPercentEncoding
        },
        ClipboardTransform(id: "encode.base64", title: "Base64 Encode", group: Group.encode, section: 1) { text, _ in
            Data(text.utf8).base64EncodedString()
        },
        ClipboardTransform(id: "decode.base64", title: "Base64 Decode", group: Group.encode, section: 1) { text, _ in
            guard let data = Data(base64Encoded: text.trimmingCharacters(in: .whitespacesAndNewlines)),
                  let decoded = String(data: data, encoding: .utf8) else {
                throw TransformError(message: "The text is not valid Base64 (UTF-8).")
            }
            return decoded
        },
        ClipboardTransform(id: "convert.html-markdown", title: "HTML → Markdown", group: Group.encode, section: 2) { text, _ in
            htmlToMarkdown(text)
        },

        // JSON
        ClipboardTransform(id: "json.pretty", title: "Pretty Print", group: Group.json) { text, _ in
            try reserializeJSON(text, options: [.prettyPrinted, .sortedKeys])
        },
        ClipboardTransform(id: "json.minify", title: "Minify", group: Group.json) { text, _ in
            try reserializeJSON(text, options: [.sortedKeys])
        },
        ClipboardTransform(id: "json.escape-string", title: "Escape as JSON String", group: Group.json) { text, _ in
            guard let data = try? JSONEncoder().encode(text) else { return nil }
            return String(data: data, encoding: .utf8)
        },

        // Quotes & Escaping
        ClipboardTransform(id: "quotes.wrap", title: "Wrap in Quotes", group: Group.quotes) { text, _ in
            "\"\(text)\""
        },
        ClipboardTransform(id: "quotes.remove", title: "Remove Quotes", group: Group.quotes) { text, _ in
            for quote in ["\"", "'"] where text.count >= 2 && text.hasPrefix(quote) && text.hasSuffix(quote) {
                return String(text.dropFirst().dropLast())
            }
            return nil
        },
        ClipboardTransform(id: "escape.shell", title: "Escape for Shell", group: Group.quotes, section: 1) { text, _ in
            "'\(text.replacingOccurrences(of: "'", with: "'\"'\"'"))'"
        },

        // Prefix & Suffix
        ClipboardTransform(id: "affix.add-prefix", title: "Add Prefix", group: Group.affix, input: .prompt(label: "Prefix:")) { text, prefix in
            "\(prefix ?? "")\(text)"
        },
        ClipboardTransform(id: "affix.remove-prefix", title: "Remove Prefix", group: Group.affix, input: .prompt(label: "Prefix:")) { text, prefix in
            guard let prefix, !prefix.isEmpty, text.hasPrefix(prefix) else { return nil }
            return String(text.dropFirst(prefix.count))
        },
        ClipboardTransform(id: "affix.add-suffix", title: "Add Suffix", group: Group.affix, section: 1, input: .prompt(label: "Suffix:")) { text, suffix in
            "\(text)\(suffix ?? "")"
        },
        ClipboardTransform(id: "affix.remove-suffix", title: "Remove Suffix", group: Group.affix, section: 1, input: .prompt(label: "Suffix:")) { text, suffix in
            guard let suffix, !suffix.isEmpty, text.hasSuffix(suffix) else { return nil }
            return String(text.dropLast(suffix.count))
        },

        // Extract
        ClipboardTransform(id: "extract.emails", title: "Emails", group: Group.extract) { text, _ in
            let emails = extractedEmails(in: text)
            return emails.isEmpty ? nil : emails.joined(separator: "\n")
        },
        ClipboardTransform(id: "extract.urls", title: "URLs", group: Group.extract) { text, _ in
            let urls = extractedURLs(in: text)
            return urls.isEmpty ? nil : urls.joined(separator: "\n")
        },
    ]

    // MARK: - Helpers

    fileprivate static func normalizedToLF(_ text: String) -> String {
        text.replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\r", with: "\n")
    }

    fileprivate static func reserializeJSON(_ text: String, options: JSONSerialization.WritingOptions) throws -> String? {
        guard let data = text.data(using: .utf8),
              let object = try? JSONSerialization.jsonObject(with: data, options: [.fragmentsAllowed]) else {
            throw TransformError(message: "The text is not valid JSON.")
        }
        let output = try JSONSerialization.data(withJSONObject: object, options: options.union(.fragmentsAllowed))
        return String(data: output, encoding: .utf8)
    }

    fileprivate static func htmlToMarkdown(_ html: String) -> String {
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

    fileprivate static func convertHTMLTables(_ html: String) -> String {
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

    fileprivate static func renderTable(_ inner: String) -> String {
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

    fileprivate static func words(from text: String) -> [String] {
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

    fileprivate static func extractedEmails(in text: String) -> [String] {
        let pattern = #"[A-Z0-9a-z._%+\-]+@[A-Za-z0-9.\-]+\.[A-Za-z]{2,}"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return [] }
        let range = NSRange(text.startIndex..<text.endIndex, in: text)
        let matches = regex.matches(in: text, range: range).compactMap { result -> String? in
            guard let r = Range(result.range, in: text) else { return nil }
            return String(text[r])
        }
        return Array(NSOrderedSet(array: matches)) as? [String] ?? matches
    }

    fileprivate static func extractedURLs(in text: String) -> [String] {
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
