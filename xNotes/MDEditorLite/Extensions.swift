//
//  Extensions.swift
//  MDEditorLite
//
//  Created by Rudd Fawcett on 10/14/16.
//  Copyright © 2016 Rudd Fawcett. All rights reserved.
//

import Foundation

extension String {
    /// Converts a Range<String.Index> to an NSRange.
    /// http://stackoverflow.com/a/30404532/6669540
    ///
    /// - parameter range: The Range<String.Index>.
    ///
    /// - returns: The equivalent NSRange.
    func nsRange(from range: Range<String.Index>) -> NSRange {
        let from = range.lowerBound.samePosition(in: utf16)
        let to = range.upperBound.samePosition(in: utf16)
        return NSRange(location: utf16.distance(from: utf16.startIndex, to: from!),
                       length: utf16.distance(from: from!, to: to!))
    }

    /// Converts a String to a NSRegularExpression.
    ///
    /// - returns: The NSRegularExpression.
    func toRegex() throws -> NSRegularExpression {
        try NSRegularExpression(pattern: self, options: .anchorsMatchLines)
    }

    func toRegexOrAssertionFailure() -> NSRegularExpression {
        do {
            return try toRegex()
        } catch {
            assertionFailure("Invalid regex pattern: \(self). Error: \(error)")
            return NSRegularExpression()
        }
    }

    /// Converts a NSRange to a Range<String.Index>.
    /// http://stackoverflow.com/a/30404532/6669540
    ///
    /// - parameter range: The NSRange.
    ///
    /// - returns: The equivalent Range<String.Index>.
    func range(from nsRange: NSRange) -> Range<String.Index>? {
        guard
            let from16 = utf16.index(utf16.startIndex, offsetBy: nsRange.location, limitedBy: utf16.endIndex),
            let to16 = utf16.index(from16, offsetBy: nsRange.length, limitedBy: utf16.endIndex),
            let from = String.Index(from16, within: self),
            let to = String.Index(to16, within: self)
            else { return nil }
        return from ..< to
    }
}


