//
//  MarkdownEditorTheme.swift
//  MarkdownEditor
//
//  Created by Dirk Clemens on 20.10.25.
//

import AppKit

struct MarkdownEditorTheme: Hashable {
    let backgroundColor: NSColor
    let textColor: NSColor
    let headerColors: [NSColor]
    let boldColor: NSColor
    let italicColor: NSColor
    let strikethroughColor: NSColor
    let codeColor: NSColor
    let codeBackgroundColor: NSColor
    let blockquoteColor: NSColor
    let blockquoteSymbolColor: NSColor
    let tableColor: NSColor
    let imageColor: NSColor
    let imageSymbolColor: NSColor
    let linkColor: NSColor
    let listColor: NSColor
}

let lightTheme = MarkdownEditorTheme(
    backgroundColor: NSColor.textBackgroundColor,
    textColor: NSColor.textColor,
    headerColors: [NSColor.systemBlue, NSColor.systemIndigo, NSColor.systemPurple, NSColor.systemTeal, NSColor.systemGreen, NSColor.systemOrange],
    boldColor: NSColor.textColor,
    italicColor: NSColor.textColor,
    strikethroughColor: NSColor.systemGray,
    codeColor: NSColor.systemRed,
    codeBackgroundColor: NSColor.unemphasizedSelectedContentBackgroundColor,
    blockquoteColor: NSColor.systemGray,
    blockquoteSymbolColor: NSColor.systemOrange,
    tableColor: NSColor.systemPurple,
    imageColor: NSColor.systemBlue,
    imageSymbolColor: NSColor.systemRed,
    linkColor: NSColor.systemBlue,
    listColor: NSColor.systemGreen
)

let darkTheme = MarkdownEditorTheme(
    backgroundColor: NSColor(calibratedRed: 0.13, green: 0.13, blue: 0.22, alpha: 1), // #222
    textColor: NSColor(calibratedWhite: 0.97, alpha: 1), // #f8f8f8
    headerColors: [
        NSColor(calibratedRed: 0.27, green: 0.44, blue: 0.78, alpha: 1), // blue
        NSColor(calibratedRed: 0.20, green: 0.60, blue: 0.86, alpha: 1), // cyan
        NSColor(calibratedRed: 0.36, green: 0.60, blue: 0.80, alpha: 1), // blue-gray
        NSColor(calibratedRed: 0.55, green: 0.70, blue: 0.90, alpha: 1), // light blue
        NSColor(calibratedRed: 0.65, green: 0.75, blue: 0.85, alpha: 1), // pale blue
        NSColor.systemOrange
    ],
    boldColor: NSColor(calibratedWhite: 0.97, alpha: 1),
    italicColor: NSColor(calibratedWhite: 0.90, alpha: 1),
    strikethroughColor: NSColor(calibratedWhite: 0.60, alpha: 1),
    codeColor: NSColor(calibratedRed: 0.20, green: 0.60, blue: 0.86, alpha: 1), // cyan
    codeBackgroundColor: NSColor(calibratedRed: 0.18, green: 0.18, blue: 0.28, alpha: 1), // slightly lighter than bg
    blockquoteColor: NSColor(calibratedRed: 0.36, green: 0.60, blue: 0.80, alpha: 1), // blue-gray
    blockquoteSymbolColor: NSColor.systemOrange,
    tableColor: NSColor(calibratedRed: 0.27, green: 0.44, blue: 0.78, alpha: 1), // blue
    imageColor: NSColor(calibratedRed: 0.20, green: 0.60, blue: 0.86, alpha: 1), // cyan
    imageSymbolColor: NSColor.systemRed,
    linkColor: NSColor(calibratedRed: 0.27, green: 0.44, blue: 0.78, alpha: 1), // blue
    listColor: NSColor.systemGreen
)

let monokaiDarkTheme = MarkdownEditorTheme(
    backgroundColor: NSColor(calibratedRed: 0.152, green: 0.157, blue: 0.137, alpha: 1), // #272822
    textColor: NSColor(calibratedRed: 0.972, green: 0.972, blue: 0.949, alpha: 1), // #F8F8F2
    headerColors: [
        NSColor(calibratedRed: 0.651, green: 0.886, blue: 0.180, alpha: 1), // #A6E22E
        NSColor(calibratedRed: 0.976, green: 0.149, blue: 0.447, alpha: 1), // #F92672
        NSColor(calibratedRed: 0.992, green: 0.592, blue: 0.122, alpha: 1), // #FD971F
        NSColor(calibratedRed: 0.400, green: 0.851, blue: 0.937, alpha: 1), // #66D9EF
        NSColor(calibratedRed: 0.682, green: 0.506, blue: 1.0, alpha: 1),   // #AE81FF
        NSColor(calibratedRed: 0.972, green: 0.972, blue: 0.949, alpha: 1) // #F8F8F2
    ],
    boldColor: NSColor(calibratedRed: 0.976, green: 0.149, blue: 0.447, alpha: 1), // #F92672
    italicColor: NSColor(calibratedRed: 0.992, green: 0.592, blue: 0.122, alpha: 1), // #FD971F
    strikethroughColor: NSColor(calibratedRed: 0.462, green: 0.443, blue: 0.369, alpha: 1), // #75715E
    codeColor: NSColor(calibratedRed: 0.902, green: 0.859, blue: 0.455, alpha: 1), // #E6DB74
    codeBackgroundColor: NSColor(calibratedRed: 0.243, green: 0.239, blue: 0.196, alpha: 1), // #3E3D32
    blockquoteColor: NSColor(calibratedRed: 0.462, green: 0.443, blue: 0.369, alpha: 1), // #75715E
    blockquoteSymbolColor: NSColor(calibratedRed: 0.682, green: 0.506, blue: 1.0, alpha: 1), // #AE81FF
    tableColor: NSColor(calibratedRed: 0.400, green: 0.851, blue: 0.937, alpha: 1), // #66D9EF
    imageColor: NSColor(calibratedRed: 0.651, green: 0.886, blue: 0.180, alpha: 1), // #A6E22E
    imageSymbolColor: NSColor(calibratedRed: 0.976, green: 0.149, blue: 0.447, alpha: 1), // #F92672
    linkColor: NSColor(calibratedRed: 0.400, green: 0.851, blue: 0.937, alpha: 1), // #66D9EF
    listColor: NSColor(calibratedRed: 0.651, green: 0.886, blue: 0.180, alpha: 1) // #A6E22E
)

let pastelTheme = MarkdownEditorTheme(
    backgroundColor: NSColor(calibratedRed: 1.0, green: 0.97, blue: 0.94, alpha: 1), // #FFF7F0
    textColor: NSColor(calibratedRed: 0.36, green: 0.36, blue: 0.36, alpha: 1), // #5D5D5D
    headerColors: [
        NSColor(calibratedRed: 0.352, green: 0.4345, blue: 0.363, alpha: 1), // #A3C9A8 × 0.55
        NSColor(calibratedRed: 0.55, green: 0.462, blue: 0.484, alpha: 1), // #FFD6E0 × 0.55
        NSColor(calibratedRed: 0.3905, green: 0.506, blue: 0.462, alpha: 1), // #B5EAD7 × 0.55
        NSColor(calibratedRed: 0.44, green: 0.4895, blue: 0.5445, alpha: 1), // #CCE7FF × 0.55
        NSColor(calibratedRed: 0.429, green: 0.4455, blue: 0.506, alpha: 1), // #C7CEEA × 0.55
        NSColor(calibratedRed: 0.55, green: 0.396, blue: 0.385, alpha: 1)  // #FFB7B2 × 0.55
    ],
    boldColor: NSColor(calibratedRed: 0.55, green: 0.396, blue: 0.385, alpha: 1), // #FFB7B2 × 0.55
    italicColor: NSColor(calibratedRed: 0.3905, green: 0.506, blue: 0.462, alpha: 1), // #B5EAD7 × 0.55
    strikethroughColor: NSColor(calibratedRed: 0.429, green: 0.4455, blue: 0.506, alpha: 1), // #C7CEEA × 0.55
    codeColor: NSColor(calibratedRed: 0.1, green: 0.14, blue: 0.88, alpha: 1), // #1A23E0
    codeBackgroundColor: NSColor(calibratedRed: 0.95, green: 0.91, blue: 1.0, alpha: 1), // #F3E8FF
    blockquoteColor: NSColor(calibratedRed: 0.352, green: 0.4345, blue: 0.363, alpha: 1), // #A3C9A8 × 0.55
    blockquoteSymbolColor: NSColor(calibratedRed: 0.55, green: 0.4675, blue: 0.418, alpha: 1), // #FFDAC1 × 0.55
    tableColor: NSColor(calibratedRed: 0.429, green: 0.4455, blue: 0.506, alpha: 1), // #C7CEEA × 0.55
    imageColor: NSColor(calibratedRed: 0.3905, green: 0.506, blue: 0.462, alpha: 1), // #B5EAD7 × 0.55
    imageSymbolColor: NSColor(calibratedRed: 0.55, green: 0.396, blue: 0.385, alpha: 1), // #FFB7B2 × 0.55
    linkColor: NSColor(calibratedRed: 0.352, green: 0.4345, blue: 0.363, alpha: 1), // #A3C9A8 × 0.55
    listColor: NSColor(calibratedRed: 0.55, green: 0.462, blue: 0.484, alpha: 1) // #FFD6E0 × 0.55
)

// Solarized Light Theme
let solarizedLightTheme = MarkdownEditorTheme(
    backgroundColor: NSColor(calibratedRed: 0.992, green: 0.965, blue: 0.890, alpha: 1), // base3 #fdf6e3
    textColor: NSColor(calibratedRed: 0.345, green: 0.431, blue: 0.459, alpha: 1), // base00 #657b83
    headerColors: [
        NSColor(calibratedRed: 0.522, green: 0.600, blue: 0.0, alpha: 1), // yellow #b58900
        NSColor(calibratedRed: 0.796, green: 0.294, blue: 0.086, alpha: 1), // orange #cb4b16
        NSColor(calibratedRed: 0.796, green: 0.0, blue: 0.086, alpha: 1), // red #dc322f
        NSColor(calibratedRed: 0.522, green: 0.0, blue: 0.522, alpha: 1), // magenta #d33682
        NSColor(calibratedRed: 0.345, green: 0.431, blue: 0.459, alpha: 1), // base00 #657b83
        NSColor(calibratedRed: 0.0, green: 0.522, blue: 0.600, alpha: 1) // cyan #2aa198
    ],
    boldColor: NSColor(calibratedRed: 0.796, green: 0.0, blue: 0.086, alpha: 1), // red #dc322f
    italicColor: NSColor(calibratedRed: 0.0, green: 0.522, blue: 0.600, alpha: 1), // cyan #2aa198
    strikethroughColor: NSColor(calibratedRed: 0.345, green: 0.431, blue: 0.459, alpha: 1), // base00 #657b83
    codeColor: NSColor(calibratedRed: 0.0, green: 0.522, blue: 0.600, alpha: 1), // cyan #2aa198
    codeBackgroundColor: NSColor(calibratedRed: 0.933, green: 0.910, blue: 0.792, alpha: 1), // base2 #eee8d5
    blockquoteColor: NSColor(calibratedRed: 0.522, green: 0.600, blue: 0.0, alpha: 1), // yellow #b58900
    blockquoteSymbolColor: NSColor(calibratedRed: 0.0, green: 0.522, blue: 0.600, alpha: 1), // cyan #2aa198
    tableColor: NSColor(calibratedRed: 0.345, green: 0.431, blue: 0.459, alpha: 1), // base00 #657b83
    imageColor: NSColor(calibratedRed: 0.0, green: 0.522, blue: 0.600, alpha: 1), // cyan #2aa198
    imageSymbolColor: NSColor(calibratedRed: 0.796, green: 0.0, blue: 0.086, alpha: 1), // red #dc322f
    linkColor: NSColor(calibratedRed: 0.0, green: 0.522, blue: 0.600, alpha: 1), // cyan #2aa198
    listColor: NSColor(calibratedRed: 0.522, green: 0.600, blue: 0.0, alpha: 1) // yellow #b58900
)

// Solarized Dark Theme
let solarizedDarkTheme = MarkdownEditorTheme(
    backgroundColor: NSColor(calibratedRed: 0.0, green: 0.168, blue: 0.211, alpha: 1), // base03 #002b36
    textColor: NSColor(calibratedRed: 0.514, green: 0.580, blue: 0.588, alpha: 1), // base0 #839496
    headerColors: [
        NSColor(calibratedRed: 0.522, green: 0.600, blue: 0.0, alpha: 1), // yellow #b58900
        NSColor(calibratedRed: 0.796, green: 0.294, blue: 0.086, alpha: 1), // orange #cb4b16
        NSColor(calibratedRed: 0.796, green: 0.0, blue: 0.086, alpha: 1), // red #dc322f
        NSColor(calibratedRed: 0.522, green: 0.0, blue: 0.522, alpha: 1), // magenta #d33682
        NSColor(calibratedRed: 0.514, green: 0.580, blue: 0.588, alpha: 1), // base0 #839496
        NSColor(calibratedRed: 0.0, green: 0.522, blue: 0.600, alpha: 1) // cyan #2aa198
    ],
    boldColor: NSColor(calibratedRed: 0.796, green: 0.0, blue: 0.086, alpha: 1), // red #dc322f
    italicColor: NSColor(calibratedRed: 0.0, green: 0.522, blue: 0.600, alpha: 1), // cyan #2aa198
    strikethroughColor: NSColor(calibratedRed: 0.514, green: 0.580, blue: 0.588, alpha: 1), // base0 #839496
    codeColor: NSColor(calibratedRed: 0.0, green: 0.522, blue: 0.600, alpha: 1), // cyan #2aa198
    codeBackgroundColor: NSColor(calibratedRed: 0.027, green: 0.212, blue: 0.258, alpha: 1), // base02 #073642
    blockquoteColor: NSColor(calibratedRed: 0.522, green: 0.600, blue: 0.0, alpha: 1), // yellow #b58900
    blockquoteSymbolColor: NSColor(calibratedRed: 0.0, green: 0.522, blue: 0.600, alpha: 1), // cyan #2aa198
    tableColor: NSColor(calibratedRed: 0.514, green: 0.580, blue: 0.588, alpha: 1), // base0 #839496
    imageColor: NSColor(calibratedRed: 0.0, green: 0.522, blue: 0.600, alpha: 1), // cyan #2aa198
    imageSymbolColor: NSColor(calibratedRed: 0.796, green: 0.0, blue: 0.086, alpha: 1), // red #dc322f
    linkColor: NSColor(calibratedRed: 0.0, green: 0.522, blue: 0.600, alpha: 1), // cyan #2aa198
    listColor: NSColor(calibratedRed: 0.522, green: 0.600, blue: 0.0, alpha: 1) // yellow #b58900
)

// Dracula Theme
let draculaTheme = MarkdownEditorTheme(
    backgroundColor: NSColor(calibratedRed: 0.157, green: 0.165, blue: 0.212, alpha: 1), // #282a36
    textColor: NSColor(calibratedRed: 0.972, green: 0.972, blue: 0.949, alpha: 1), // #f8f8f2
    headerColors: [
        NSColor(calibratedRed: 0.545, green: 0.914, blue: 0.992, alpha: 1), // cyan #8be9fd
        NSColor(calibratedRed: 0.314, green: 0.980, blue: 0.482, alpha: 1), // green #50fa7b
        NSColor(calibratedRed: 1.0, green: 0.722, blue: 0.424, alpha: 1), // orange #ffb86c
        NSColor(calibratedRed: 1.0, green: 0.475, blue: 0.776, alpha: 1), // pink #ff79c6
        NSColor(calibratedRed: 0.741, green: 0.576, blue: 0.976, alpha: 1), // purple #bd93f9
        NSColor(calibratedRed: 0.945, green: 0.980, blue: 0.549, alpha: 1) // yellow #f1fa8c
    ],
    boldColor: NSColor(calibratedRed: 1.0, green: 0.333, blue: 0.333, alpha: 1), // red #ff5555
    italicColor: NSColor(calibratedRed: 1.0, green: 0.475, blue: 0.776, alpha: 1), // pink #ff79c6
    strikethroughColor: NSColor(calibratedRed: 0.384, green: 0.447, blue: 0.643, alpha: 1), // comment #6272a4
    codeColor: NSColor(calibratedRed: 0.545, green: 0.914, blue: 0.992, alpha: 1), // cyan #8be9fd
    codeBackgroundColor: NSColor(calibratedRed: 0.267, green: 0.278, blue: 0.353, alpha: 1), // selection #44475a
    blockquoteColor: NSColor(calibratedRed: 0.741, green: 0.576, blue: 0.976, alpha: 1), // purple #bd93f9
    blockquoteSymbolColor: NSColor(calibratedRed: 1.0, green: 0.722, blue: 0.424, alpha: 1), // orange #ffb86c
    tableColor: NSColor(calibratedRed: 0.545, green: 0.914, blue: 0.992, alpha: 1), // cyan #8be9fd
    imageColor: NSColor(calibratedRed: 0.314, green: 0.980, blue: 0.482, alpha: 1), // green #50fa7b
    imageSymbolColor: NSColor(calibratedRed: 1.0, green: 0.333, blue: 0.333, alpha: 1), // red #ff5555
    linkColor: NSColor(calibratedRed: 0.545, green: 0.914, blue: 0.992, alpha: 1), // cyan #8be9fd
    listColor: NSColor(calibratedRed: 0.945, green: 0.980, blue: 0.549, alpha: 1) // yellow #f1fa8c
)

// Gruvbox Dark Theme
let gruvboxDarkTheme = MarkdownEditorTheme(
    backgroundColor: NSColor(calibratedRed: 0.157, green: 0.157, blue: 0.157, alpha: 1), // #282828
    textColor: NSColor(calibratedRed: 0.922, green: 0.859, blue: 0.698, alpha: 1), // #ebdbb2
    headerColors: [
        NSColor(calibratedRed: 0.800, green: 0.141, blue: 0.114, alpha: 1), // red #cc241d
        NSColor(calibratedRed: 0.600, green: 0.592, blue: 0.129, alpha: 1), // yellow #d79921
        NSColor(calibratedRed: 0.596, green: 0.592, blue: 0.129, alpha: 1), // yellow #d79921
        NSColor(calibratedRed: 0.271, green: 0.533, blue: 0.533, alpha: 1), // blue #458588
        NSColor(calibratedRed: 0.698, green: 0.616, blue: 0.525, alpha: 1), // gray #bdae93
        NSColor(calibratedRed: 0.922, green: 0.859, blue: 0.698, alpha: 1) // #ebdbb2
    ],
    boldColor: NSColor(calibratedRed: 0.800, green: 0.141, blue: 0.114, alpha: 1), // red #cc241d
    italicColor: NSColor(calibratedRed: 0.600, green: 0.592, blue: 0.129, alpha: 1), // yellow #d79921
    strikethroughColor: NSColor(calibratedRed: 0.698, green: 0.616, blue: 0.525, alpha: 1), // gray #bdae93
    codeColor: NSColor(calibratedRed: 0.271, green: 0.533, blue: 0.533, alpha: 1), // blue #458588
    codeBackgroundColor: NSColor(calibratedRed: 0.212, green: 0.200, blue: 0.176, alpha: 1), // #3c3836
    blockquoteColor: NSColor(calibratedRed: 0.698, green: 0.616, blue: 0.525, alpha: 1), // gray #bdae93
    blockquoteSymbolColor: NSColor(calibratedRed: 0.600, green: 0.592, blue: 0.129, alpha: 1), // yellow #d79921
    tableColor: NSColor(calibratedRed: 0.271, green: 0.533, blue: 0.533, alpha: 1), // blue #458588
    imageColor: NSColor(calibratedRed: 0.596, green: 0.592, blue: 0.129, alpha: 1), // yellow #d79921
    imageSymbolColor: NSColor(calibratedRed: 0.800, green: 0.141, blue: 0.114, alpha: 1), // red #cc241d
    linkColor: NSColor(calibratedRed: 0.271, green: 0.533, blue: 0.533, alpha: 1), // blue #458588
    listColor: NSColor(calibratedRed: 0.600, green: 0.592, blue: 0.129, alpha: 1) // yellow #d79921
)

// Nord Theme
let nordTheme = MarkdownEditorTheme(
    backgroundColor: NSColor(calibratedRed: 0.180, green: 0.204, blue: 0.251, alpha: 1), // #2e3440
    textColor: NSColor(calibratedRed: 0.847, green: 0.871, blue: 0.914, alpha: 1), // #d8dee9
    headerColors: [
        NSColor(calibratedRed: 0.561, green: 0.737, blue: 0.733, alpha: 1), // frost #8fbcbb
        NSColor(calibratedRed: 0.749, green: 0.380, blue: 0.416, alpha: 1), // aurora #bf616a
        NSColor(calibratedRed: 0.816, green: 0.529, blue: 0.439, alpha: 1), // aurora #d08770
        NSColor(calibratedRed: 0.922, green: 0.796, blue: 0.545, alpha: 1), // aurora #ebcb8b
        NSColor(calibratedRed: 0.639, green: 0.745, blue: 0.549, alpha: 1), // aurora #a3be8c
        NSColor(calibratedRed: 0.706, green: 0.557, blue: 0.737, alpha: 1) // aurora #b48ead
    ],
    boldColor: NSColor(calibratedRed: 0.749, green: 0.380, blue: 0.416, alpha: 1), // aurora #bf616a
    italicColor: NSColor(calibratedRed: 0.561, green: 0.737, blue: 0.733, alpha: 1), // frost #8fbcbb
    strikethroughColor: NSColor(calibratedRed: 0.561, green: 0.737, blue: 0.733, alpha: 1), // frost #8fbcbb
    codeColor: NSColor(calibratedRed: 0.561, green: 0.737, blue: 0.733, alpha: 1), // frost #8fbcbb
    codeBackgroundColor: NSColor(calibratedRed: 0.212, green: 0.243, blue: 0.302, alpha: 1), // #3b4252
    blockquoteColor: NSColor(calibratedRed: 0.922, green: 0.796, blue: 0.545, alpha: 1), // aurora #ebcb8b
    blockquoteSymbolColor: NSColor(calibratedRed: 0.639, green: 0.745, blue: 0.549, alpha: 1), // aurora #a3be8c
    tableColor: NSColor(calibratedRed: 0.561, green: 0.737, blue: 0.733, alpha: 1), // frost #8fbcbb
    imageColor: NSColor(calibratedRed: 0.639, green: 0.745, blue: 0.549, alpha: 1), // aurora #a3be8c
    imageSymbolColor: NSColor(calibratedRed: 0.749, green: 0.380, blue: 0.416, alpha: 1), // aurora #bf616a
    linkColor: NSColor(calibratedRed: 0.561, green: 0.737, blue: 0.733, alpha: 1), // frost #8fbcbb
    listColor: NSColor(calibratedRed: 0.922, green: 0.796, blue: 0.545, alpha: 1) // aurora #ebcb8b
)

// One Dark Theme
let oneDarkTheme = MarkdownEditorTheme(
    backgroundColor: NSColor(calibratedRed: 0.157, green: 0.173, blue: 0.204, alpha: 1), // #282c34
    textColor: NSColor(calibratedRed: 0.671, green: 0.698, blue: 0.749, alpha: 1), // #abb2bf
    headerColors: [
        NSColor(calibratedRed: 0.380, green: 0.686, blue: 0.937, alpha: 1), // blue #61afef
        NSColor(calibratedRed: 0.337, green: 0.714, blue: 0.761, alpha: 1), // cyan #56b6c2
        NSColor(calibratedRed: 0.596, green: 0.765, blue: 0.475, alpha: 1), // green #98c379
        NSColor(calibratedRed: 0.820, green: 0.604, blue: 0.400, alpha: 1), // orange #d19a66
        NSColor(calibratedRed: 0.780, green: 0.420, blue: 0.867, alpha: 1), // purple #c678dd
        NSColor(calibratedRed: 0.878, green: 0.424, blue: 0.459, alpha: 1) // red #e06c75
    ],
    boldColor: NSColor(calibratedRed: 0.878, green: 0.424, blue: 0.459, alpha: 1), // red #e06c75
    italicColor: NSColor(calibratedRed: 0.337, green: 0.714, blue: 0.761, alpha: 1), // cyan #56b6c2
    strikethroughColor: NSColor(calibratedRed: 0.671, green: 0.698, blue: 0.749, alpha: 1), // #abb2bf
    codeColor: NSColor(calibratedRed: 0.380, green: 0.686, blue: 0.937, alpha: 1), // blue #61afef
    codeBackgroundColor: NSColor(calibratedRed: 0.204, green: 0.220, blue: 0.251, alpha: 1), // #313640
    blockquoteColor: NSColor(calibratedRed: 0.820, green: 0.604, blue: 0.400, alpha: 1), // orange #d19a66
    blockquoteSymbolColor: NSColor(calibratedRed: 0.780, green: 0.420, blue: 0.867, alpha: 1), // purple #c678dd
    tableColor: NSColor(calibratedRed: 0.380, green: 0.686, blue: 0.937, alpha: 1), // blue #61afef
    imageColor: NSColor(calibratedRed: 0.596, green: 0.765, blue: 0.475, alpha: 1), // green #98c379
    imageSymbolColor: NSColor(calibratedRed: 0.878, green: 0.424, blue: 0.459, alpha: 1), // red #e06c75
    linkColor: NSColor(calibratedRed: 0.380, green: 0.686, blue: 0.937, alpha: 1), // blue #61afef
    listColor: NSColor(calibratedRed: 0.820, green: 0.604, blue: 0.400, alpha: 1) // orange #d19a66
)

// Tomorrow Night Theme
let tomorrowNightTheme = MarkdownEditorTheme(
    backgroundColor: NSColor(calibratedRed: 0.114, green: 0.122, blue: 0.129, alpha: 1), // #1d1f21
    textColor: NSColor(calibratedRed: 0.773, green: 0.784, blue: 0.776, alpha: 1), // #c5c8c6
    headerColors: [
        NSColor(calibratedRed: 0.506, green: 0.635, blue: 0.745, alpha: 1), // blue #81a2be
        NSColor(calibratedRed: 0.710, green: 0.741, blue: 0.408, alpha: 1), // green #b5bd68
        NSColor(calibratedRed: 0.871, green: 0.576, blue: 0.373, alpha: 1), // orange #de935f
        NSColor(calibratedRed: 0.698, green: 0.580, blue: 0.733, alpha: 1), // purple #b294bb
        NSColor(calibratedRed: 0.800, green: 0.400, blue: 0.400, alpha: 1), // red #cc6666
        NSColor(calibratedRed: 0.941, green: 0.780, blue: 0.455, alpha: 1) // yellow #f0c674
    ],
    boldColor: NSColor(calibratedRed: 0.800, green: 0.400, blue: 0.400, alpha: 1), // red #cc6666
    italicColor: NSColor(calibratedRed: 0.710, green: 0.741, blue: 0.408, alpha: 1), // green #b5bd68
    strikethroughColor: NSColor(calibratedRed: 0.698, green: 0.580, blue: 0.733, alpha: 1), // purple #b294bb
    codeColor: NSColor(calibratedRed: 0.506, green: 0.635, blue: 0.745, alpha: 1), // blue #81a2be
    codeBackgroundColor: NSColor(calibratedRed: 0.200, green: 0.216, blue: 0.224, alpha: 1), // #323437
    blockquoteColor: NSColor(calibratedRed: 0.941, green: 0.780, blue: 0.455, alpha: 1), // yellow #f0c674
    blockquoteSymbolColor: NSColor(calibratedRed: 0.710, green: 0.741, blue: 0.408, alpha: 1), // green #b5bd68
    tableColor: NSColor(calibratedRed: 0.506, green: 0.635, blue: 0.745, alpha: 1), // blue #81a2be
    imageColor: NSColor(calibratedRed: 0.710, green: 0.741, blue: 0.408, alpha: 1), // green #b5bd68
    imageSymbolColor: NSColor(calibratedRed: 0.800, green: 0.400, blue: 0.400, alpha: 1), // red #cc6666
    linkColor: NSColor(calibratedRed: 0.506, green: 0.635, blue: 0.745, alpha: 1), // blue #81a2be
    listColor: NSColor(calibratedRed: 0.941, green: 0.780, blue: 0.455, alpha: 1) // yellow #f0c674
)

extension MarkdownEditorTheme {
    /// Gedimmte Farbe für Syntaxzeichen (**, #, `, Klammern).
    var markupColor: NSColor {
        textColor.blended(withFraction: 0.5, of: backgroundColor) ?? .secondaryLabelColor
    }
    var insertionPointColor: NSColor { textColor }
    var selectionColor: NSColor {
        textColor.blended(withFraction: 0.75, of: backgroundColor) ?? .selectedTextBackgroundColor
    }
    var gutterBackgroundColor: NSColor { backgroundColor }
    var gutterTextColor: NSColor { markupColor }
    var horizontalRuleColor: NSColor { markupColor }
    var highlightBackgroundColor: NSColor { NSColor.systemYellow.withAlphaComponent(0.35) }
    var footnoteColor: NSColor { linkColor }
    var emojiColor: NSColor { listColor }
    var htmlColor: NSColor { markupColor }
    var taskDoneColor: NSColor { markupColor }
}
