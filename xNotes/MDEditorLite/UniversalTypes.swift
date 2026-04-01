//
//  UniversalTypes.swift
//  MDEditorLite
//
//  Created by Christian Tietze on 2017-07-21.
//  Copyright © 2017 Rudd Fawcett. All rights reserved.
//

#if os(iOS)
    import UIKit
    import struct UIKit.CGFloat
    public typealias UniversalColor = UIColor
    public typealias UniversalFont = UIFont
    public typealias UniversalFontDescriptor = UIFontDescriptor
    public typealias UniversalTraits = UIFontDescriptor.SymbolicTraits
#elseif os(macOS)
    import AppKit
    import struct AppKit.CGFloat
    public typealias UniversalColor = NSColor
    public typealias UniversalFont = NSFont
    public typealias UniversalFontDescriptor = NSFontDescriptor
    public typealias UniversalTraits = NSFontDescriptor.SymbolicTraits
#endif

extension UniversalFont {
    func with(traits: String, size: CGFloat) -> UniversalFont? {
        guard let traits = getTraits(from: traits) else {
            return self
        }
        let descriptor = fontDescriptor.withSymbolicTraits(traits)
        return UniversalFont(descriptor: descriptor, size: size)
    }
    
    private func getTraits(from traits: String) -> UniversalTraits? {
        #if os(iOS)
        switch traits {
            case "italic": return .traitItalic
            case "bold": return .traitBold
            case "expanded": return .traitExpanded
            case "condensed": return .traitCondensed
            default: return nil
        }
        #elseif os(macOS)
        switch traits {
            case "italic": return .italic
            case "bold": return .bold
            case "expanded": return .expanded
            case "condensed": return .condensed
            default: return nil
        }
        #endif
    }
}

extension UniversalColor {
    /// Converts a hex color code to UIColor.
    /// http://stackoverflow.com/a/33397427/6669540
    ///
    /// - parameter hexString: The hex code.
    convenience init(hexString: String) {
        let hex = hexString.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int = UInt64()
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (255, 0, 0, 0)
        }
        self.init(red: CGFloat(r) / 255, green: CGFloat(g) / 255, blue: CGFloat(b) / 255, alpha: CGFloat(a) / 255)
    }
}
