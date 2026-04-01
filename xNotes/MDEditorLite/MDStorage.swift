//
//  Storage.swift
//  MDEditorLite
//
//  Created by Rudd Fawcett on 10/14/16.
//  Copyright © 2016 Rudd Fawcett. All rights reserved.
//

#if os(iOS)
    import UIKit
#elseif os(macOS)
    import AppKit
#endif

public class MDStorage: NSTextStorage {
    private enum SystemMinimalStyle {
        static let bodyFontSize: CGFloat = 14

        private struct StyleSpec {
            var color: UniversalColor?
            var backgroundColor: UniversalColor?
            var size: CGFloat?
            var traits: String
            var strikethroughStyle: NSUnderlineStyle?

            init(
                color: UniversalColor? = nil,
                backgroundColor: UniversalColor? = nil,
                size: CGFloat? = nil,
                traits: String = "",
                strikethroughStyle: NSUnderlineStyle? = nil
            ) {
                self.color = color
                self.backgroundColor = backgroundColor
                self.size = size
                self.traits = traits
                self.strikethroughStyle = strikethroughStyle
            }
        }

        static let bodyAttributes: [NSAttributedString.Key: Any] = {
            var attributes = makeAttributes(StyleSpec(size: bodyFontSize))
            attributes[.foregroundColor] = defaultTextColor()
            return attributes
        }()

        static let styles: [MDStyle] = [
            MDStyle(element: .h1, attributes: makeAttributes(StyleSpec(color: color(lightHex: "#0566D6", darkHex: "#0566D6"), size: bodyFontSize, traits: "bold"))),
            MDStyle(element: .h2, attributes: makeAttributes(StyleSpec(color: color(lightHex: "#0566D6", darkHex: "#0566D6"), size: bodyFontSize, traits: "bold"))),
            MDStyle(element: .h3, attributes: makeAttributes(StyleSpec(color: color(lightHex: "#0566D6", darkHex: "#0566D6"), size: bodyFontSize, traits: "bold"))),
            MDStyle(element: .h4, attributes: makeAttributes(StyleSpec(color: color(lightHex: "#0566D6", darkHex: "#0566D6"), size: bodyFontSize, traits: "bold"))),
            MDStyle(element: .bold, attributes: makeAttributes(StyleSpec(color: color(lightHex: "#AC1201", darkHex: "#AC1201"), traits: "bold"))),
            MDStyle(element: .italic, attributes: makeAttributes(StyleSpec(color: color(lightHex: "#C678DD", darkHex: "#C678DD"), traits: "italic"))),
            MDStyle(element: .strikethrough, attributes: makeAttributes(StyleSpec(strikethroughStyle: .single))),
            MDStyle(element: .code, attributes: makeAttributes(StyleSpec(color: color(lightHex: "#21863B", darkHex: "#21863B")))),
            MDStyle(element: .codeBlock, attributes: makeAttributes(StyleSpec(color: color(lightHex: "#21863B", darkHex: "#21863B"), backgroundColor: color(lightHex: "#FFF6DC", darkHex: "#FFF6DC")))),
            MDStyle(element: .blockquote, attributes: makeAttributes(StyleSpec(
                backgroundColor: color(lightHex: "#D9D9D9", darkHex: "#A0A0A0"), traits: "bold"))),
            MDStyle(regex: "[@＠][a-zA-Z0-9_]{1,20}".toRegexOrAssertionFailure(), attributes: makeAttributes(StyleSpec(color: color(lightHex: "#78ddd5", darkHex: "#56B6C2")))),
            MDStyle(element: .url, attributes: makeAttributes(StyleSpec(color: color(lightHex: "#017AFF", darkHex: "#017AFF")))),
            MDStyle(element: .image, attributes: makeAttributes(StyleSpec(color: color(lightHex: "#78AEDD", darkHex: "#61AFEF"))))
        ]

        private static func makeAttributes(_ spec: StyleSpec) -> [NSAttributedString.Key: Any] {
            let fontSize = spec.size ?? bodyFontSize
            let baseFont = UniversalFont.systemFont(ofSize: fontSize)
            let font = baseFont.with(traits: spec.traits, size: fontSize) ?? baseFont

            var attributes: [NSAttributedString.Key: Any] = [.font: font]
            if let color = spec.color {
                attributes[.foregroundColor] = color
            }
            if let backgroundColor = spec.backgroundColor {
                attributes[.backgroundColor] = backgroundColor
            }
            if let strikethroughStyle = spec.strikethroughStyle {
                attributes[.strikethroughStyle] = strikethroughStyle.rawValue
            }
            return attributes
        }

        private static func color(lightHex: String, darkHex: String) -> UniversalColor {
            let light = UniversalColor(hexString: lightHex)
            let dark = UniversalColor(hexString: darkHex)
            return dynamicColor(light: light, dark: dark)
        }

        private static func dynamicColor(light: UniversalColor, dark: UniversalColor) -> UniversalColor {
            #if os(iOS)
            if #available(iOS 13.0, *) {
                return UniversalColor { traits in
                    traits.userInterfaceStyle == .dark ? dark : light
                }
            }
            return light
            #elseif os(macOS)
            if #available(macOS 10.15, *) {
                return UniversalColor(name: nil) { appearance in
                    appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua ? dark : light
                }
            }
            return light
            #endif
        }

        private static func defaultTextColor() -> UniversalColor {
            #if os(iOS)
            if #available(iOS 13.0, *) {
                return UniversalColor.label
            }
            return UniversalColor.black
            #elseif os(macOS)
            if #available(macOS 10.15, *) {
                return UniversalColor.labelColor
            }
            return UniversalColor.textColor
            #endif
        }
    }

    /// The underlying text storage implementation.
    var backingStore = NSTextStorage()

    override public var string: String {
        get {
            return backingStore.string
        }
    }

    override public init() {
        super.init()
    }
    
    override public init(attributedString attrStr: NSAttributedString) {
        super.init(attributedString:attrStr)
        backingStore.setAttributedString(attrStr)
    }

    required public init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    required public init(itemProviderData data: Data, typeIdentifier: String) throws {
        fatalError("init(itemProviderData:typeIdentifier:) has not been implemented")
    }
    
    #if os(macOS)
    required public init?(pasteboardPropertyList propertyList: Any, ofType type: String) {
        fatalError("init(pasteboardPropertyList:ofType:) has not been implemented")
    }
    
    required public init?(pasteboardPropertyList propertyList: Any, ofType type: NSPasteboard.PasteboardType) {
        fatalError("init(pasteboardPropertyList:ofType:) has not been implemented")
    }
    #endif

    /// Finds attributes within a given range on a String.
    ///
    /// - parameter location: How far into the String to look.
    /// - parameter range:    The range to find attributes for.
    ///
    /// - returns: The attributes on a String within a certain range.
    override public func attributes(at location: Int, longestEffectiveRange range: NSRangePointer?, in rangeLimit: NSRange) -> [NSAttributedString.Key : Any] {
        return backingStore.attributes(at: location, longestEffectiveRange: range, in: rangeLimit)
    }

    /// Replaces edited characters within a certain range with a new string.
    ///
    /// - parameter range: The range to replace.
    /// - parameter str:   The new string to replace the range with.
    override public func replaceCharacters(in range: NSRange, with str: String) {
        self.beginEditing()
        backingStore.replaceCharacters(in: range, with: str)
        let len = (str as NSString).length
        let change = len - range.length
        self.edited([.editedCharacters, .editedAttributes], range: range, changeInLength: change)
        self.endEditing()
    }

    /// Sets the attributes on a string for a particular range.
    ///
    /// - parameter attrs: The attributes to add to the string for the range.
    /// - parameter range: The range in which to add attributes.
    public override func setAttributes(_ attrs: [NSAttributedString.Key : Any]?, range: NSRange) {
        self.beginEditing()
        backingStore.setAttributes(attrs, range: range)
        self.edited(.editedAttributes, range: range, changeInLength: 0)
        self.endEditing()
    }
    
    /// Retrieves the attributes of a string for a particular range.
    ///
    /// - parameter at: The location to begin with.
    /// - parameter range: The range in which to retrieve attributes.
    public override func attributes(at location: Int, effectiveRange range: NSRangePointer?) -> [NSAttributedString.Key : Any] {
        return backingStore.attributes(at: location, effectiveRange: range)
    }
    
    /// Processes any edits made to the text in the editor.
    override public func processEditing() {
        let backingString = backingStore.string
        if let nsRange = backingString.range(from: NSMakeRange(NSMaxRange(editedRange), 0)) {
            let indexRange = backingString.lineRange(for: nsRange)
            var extendedRange: NSRange = NSUnionRange(editedRange, backingString.nsRange(from: indexRange))
            if let codeBlockRange = expandedRangeForCodeBlock(around: extendedRange, in: backingString as NSString) {
                extendedRange = NSUnionRange(extendedRange, codeBlockRange)
            }
            applyStyles(extendedRange)
        }
        super.processEditing()
    }

    /// Applies styles to a range on the backingString.
    ///
    /// - parameter range: The range in which to apply styles.
    func applyStyles(_ range: NSRange) {
        let backingString = backingStore.string
        backingStore.setAttributes(SystemMinimalStyle.bodyAttributes, range: range)

        for (style) in SystemMinimalStyle.styles {
            style.regex.enumerateMatches(in: backingString, options: .withoutAnchoringBounds, range: range, using: { (match, flags, stop) in
                guard let match = match else { return }
                backingStore.addAttributes(style.attributes, range: match.range(at: 0))
            })
        }

        applyLinks(in: range, backingString: backingString as NSString)
    }

    private func applyLinks(in range: NSRange, backingString: NSString) {
        let urlRegex = "https?://[^\\s)]+".toRegexOrAssertionFailure()
        urlRegex.enumerateMatches(in: backingString as String, options: .withoutAnchoringBounds, range: range) { match, _, _ in
            guard let match = match else { return }
            var matchRange = match.range(at: 0)
            if matchRange.length == 0 { return }

            let raw = backingString.substring(with: matchRange)
            let trimmed = raw.trimmedTrailingURLPunctuation()
            if trimmed.isEmpty { return }

            if trimmed.count != raw.count {
                matchRange.length = (trimmed as NSString).length
            }

            guard let url = URL(string: trimmed) else { return }
            backingStore.addAttribute(.link, value: url, range: matchRange)
        }
    }

    private func expandedRangeForCodeBlock(around range: NSRange, in string: NSString) -> NSRange? {
        let fence = "```"
        let length = string.length
        if length == 0 { return nil }

        let fenceRanges = findFenceRanges(fence, in: string)
        if fenceRanges.isEmpty { return nil }

        let rangeStart = range.location
        var intersectingIndex: Int?
        for (index, fenceRange) in fenceRanges.enumerated() {
            if NSIntersectionRange(fenceRange, range).length > 0 {
                intersectingIndex = index
                break
            }
        }

        let lastBeforeIndex = fenceRanges.lastIndex { $0.location < rangeStart }

        let startIndex: Int?
        let endIndex: Int?

        if let intersectingIndex = intersectingIndex {
            if intersectingIndex % 2 == 0 {
                startIndex = intersectingIndex
                endIndex = intersectingIndex + 1
            } else {
                startIndex = intersectingIndex - 1
                endIndex = intersectingIndex
            }
        } else if let lastBeforeIndex = lastBeforeIndex, lastBeforeIndex % 2 == 0 {
            startIndex = lastBeforeIndex
            endIndex = lastBeforeIndex + 1
        } else {
            return nil
        }

        guard
            let start = startIndex,
            let end = endIndex,
            start >= 0,
            end < fenceRanges.count
        else { return nil }

        let startLine = string.lineRange(for: fenceRanges[start])
        let endLine = string.lineRange(for: fenceRanges[end])
        return NSUnionRange(startLine, endLine)
    }

    private func findFenceRanges(_ fence: String, in string: NSString) -> [NSRange] {
        var ranges: [NSRange] = []
        var searchRange = NSRange(location: 0, length: string.length)
        while searchRange.length > 0 {
            let found = string.range(of: fence, options: [], range: searchRange)
            if found.location == NSNotFound { break }
            ranges.append(found)
            let nextLocation = found.location + found.length
            if nextLocation >= string.length { break }
            searchRange = NSRange(location: nextLocation, length: string.length - nextLocation)
        }
        return ranges
    }
}

private extension String {
    func trimmedTrailingURLPunctuation() -> String {
        let trailing = CharacterSet(charactersIn: ".,;:!?)]}>\"'")
        var endIndex = self.endIndex
        while endIndex > startIndex {
            let prev = self.index(before: endIndex)
            let scalar = self[prev].unicodeScalars
            if scalar.allSatisfy({ trailing.contains($0) }) {
                endIndex = prev
            } else {
                break
            }
        }
        return String(self[..<endIndex])
    }
}
