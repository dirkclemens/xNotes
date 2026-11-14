//
//  MarkdownEditorTheme+xNotes.swift
//  xNotes
//
//  Theme catalog for the settings and resolution of dynamic system colors
//  for the current appearance (light/dark).
//

import AppKit

extension MarkdownEditorTheme {
    /// Default theme: the MarkdownEditor light theme on the regular window background,
    /// following the system appearance.
    static let systemThemeName = "System"

    /// Theme names in the order they appear in the settings.
    static let availableThemeNames: [String] = [systemThemeName] + catalog.keys.sorted()

    private static let catalog: [String: MarkdownEditorTheme] = [
        "Dark": darkTheme,
        "Dracula": draculaTheme,
        "Gruvbox Dark": gruvboxDarkTheme,
        "Light": lightTheme,
        "Monokai": monokaiDarkTheme,
        "Nord": nordTheme,
        "One Dark": oneDarkTheme,
        "Pastel": pastelTheme,
        "Solarized Dark": solarizedDarkTheme,
        "Solarized Light": solarizedLightTheme,
        "Tomorrow Night": tomorrowNightTheme
    ]

    private static let systemTheme = lightTheme.with(backgroundColor: .windowBackgroundColor)

    /// The theme with the given name, with all colors resolved for `appearance`.
    /// Unknown names fall back to the system theme.
    static func named(_ name: String, for appearance: NSAppearance) -> MarkdownEditorTheme {
        (catalog[name] ?? systemTheme).resolved(for: appearance)
    }

    private func with(backgroundColor: NSColor) -> MarkdownEditorTheme {
        MarkdownEditorTheme(
            backgroundColor: backgroundColor,
            textColor: textColor,
            headerColors: headerColors,
            boldColor: boldColor,
            italicColor: italicColor,
            strikethroughColor: strikethroughColor,
            codeColor: codeColor,
            codeBackgroundColor: codeBackgroundColor,
            blockquoteColor: blockquoteColor,
            blockquoteSymbolColor: blockquoteSymbolColor,
            tableColor: tableColor,
            imageColor: imageColor,
            imageSymbolColor: imageSymbolColor,
            linkColor: linkColor,
            listColor: listColor
        )
    }

    /// Dynamic system colors (e.g. `NSColor.textColor`) are converted to fixed sRGB values.
    /// Otherwise derived colors such as `markupColor` (created via `blended`) would keep
    /// whatever appearance was current when they were computed, and a light/dark switch
    /// would not be noticed as a theme change.
    func resolved(for appearance: NSAppearance) -> MarkdownEditorTheme {
        var result = self
        appearance.performAsCurrentDrawingAppearance {
            func r(_ color: NSColor) -> NSColor { color.usingColorSpace(.sRGB) ?? color }
            result = MarkdownEditorTheme(
                backgroundColor: r(backgroundColor),
                textColor: r(textColor),
                headerColors: headerColors.map(r),
                boldColor: r(boldColor),
                italicColor: r(italicColor),
                strikethroughColor: r(strikethroughColor),
                codeColor: r(codeColor),
                codeBackgroundColor: r(codeBackgroundColor),
                blockquoteColor: r(blockquoteColor),
                blockquoteSymbolColor: r(blockquoteSymbolColor),
                tableColor: r(tableColor),
                imageColor: r(imageColor),
                imageSymbolColor: r(imageSymbolColor),
                linkColor: r(linkColor),
                listColor: r(listColor)
            )
        }
        return result
    }
}
