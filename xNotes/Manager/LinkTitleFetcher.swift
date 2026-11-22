//
//  LinkTitleFetcher.swift
//  xNotes
//

import Foundation

/// Loads a web page once to read its title (Open Graph title, else `<title>`).
/// Only used when the user asks for a Markdown link of an entry without a known title.
nonisolated enum LinkTitleFetcher {
    private static let timeout: TimeInterval = 5
    /// Titles sit in the page head; larger pages are cut off before parsing.
    private static let maxParsedBytes = 512 * 1024

    static func title(for url: URL) async -> String? {
        guard let scheme = url.scheme?.lowercased(), scheme == "http" || scheme == "https" else { return nil }
        var request = URLRequest(url: url, timeoutInterval: timeout)
        request.setValue("text/html", forHTTPHeaderField: "Accept")
        guard let (data, response) = try? await URLSession.shared.data(for: request),
              let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else { return nil }
        let head = data.prefix(maxParsedBytes)
        guard let html = String(data: head, encoding: .utf8) ?? String(data: head, encoding: .isoLatin1) else { return nil }
        return title(inHTML: html)
    }

    static func title(inHTML html: String) -> String? {
        let patterns = [
            #"<meta[^>]+property\s*=\s*["']og:title["'][^>]+content\s*=\s*"([^"]*)""#,
            #"<meta[^>]+property\s*=\s*["']og:title["'][^>]+content\s*=\s*'([^']*)'"#,
            #"<meta[^>]+content\s*=\s*"([^"]*)"[^>]+property\s*=\s*["']og:title["']"#,
            #"<title[^>]*>(.*?)</title>"#,
        ]
        for pattern in patterns {
            guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive, .dotMatchesLineSeparators]),
                  let match = regex.firstMatch(in: html, range: NSRange(html.startIndex..., in: html)),
                  let range = Range(match.range(at: 1), in: html) else { continue }
            let title = decodeEntities(String(html[range]))
                .components(separatedBy: .whitespacesAndNewlines)
                .filter { !$0.isEmpty }
                .joined(separator: " ")
            if !title.isEmpty { return title }
        }
        return nil
    }

    private static func decodeEntities(_ text: String) -> String {
        guard text.contains("&") else { return text }
        let named = ["&amp;": "&", "&lt;": "<", "&gt;": ">", "&quot;": "\"", "&apos;": "'", "&#39;": "'", "&nbsp;": " ",
                     "&ndash;": "–", "&mdash;": "—", "&hellip;": "…", "&auml;": "ä", "&ouml;": "ö", "&uuml;": "ü",
                     "&Auml;": "Ä", "&Ouml;": "Ö", "&Uuml;": "Ü", "&szlig;": "ß",
                     "&eacute;": "é", "&Eacute;": "É", "&egrave;": "è", "&ecirc;": "ê", "&aacute;": "á",
                     "&agrave;": "à", "&acirc;": "â", "&iacute;": "í", "&oacute;": "ó", "&ocirc;": "ô",
                     "&uacute;": "ú", "&ucirc;": "û", "&ccedil;": "ç", "&ntilde;": "ñ", "&euro;": "€",
                     "&copy;": "©", "&reg;": "®", "&trade;": "™", "&laquo;": "«", "&raquo;": "»",
                     "&bdquo;": "„", "&ldquo;": "“", "&rdquo;": "”", "&lsquo;": "‘", "&rsquo;": "’",
                     "&middot;": "·", "&bull;": "•", "&vert;": "|"]
        var result = text
        // Numeric entities: &#228; and &#xE4;
        if let regex = try? NSRegularExpression(pattern: "&#(x?)([0-9a-fA-F]+);") {
            for match in regex.matches(in: result, range: NSRange(result.startIndex..., in: result)).reversed() {
                guard let whole = Range(match.range, in: result),
                      let hexFlag = Range(match.range(at: 1), in: result),
                      let digits = Range(match.range(at: 2), in: result),
                      let value = UInt32(result[digits], radix: result[hexFlag].isEmpty ? 10 : 16),
                      let scalar = Unicode.Scalar(value) else { continue }
                result.replaceSubrange(whole, with: String(Character(scalar)))
            }
        }
        for (entity, character) in named {
            result = result.replacingOccurrences(of: entity, with: character)
        }
        return result
    }
}
