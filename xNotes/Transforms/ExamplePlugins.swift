//
//  ExamplePlugins.swift
//  xNotes
//
//  Seeds the plugin folder with a README and a few example plugins the first time it is created.
//  Users can delete or edit them; they are never written again once the folder exists.
//

import Foundation

enum ExamplePlugins {
    static func installIfNeeded(in folder: URL) {
        let fm = FileManager.default
        guard !fm.fileExists(atPath: folder.path) else { return }
        do {
            try fm.createDirectory(at: folder, withIntermediateDirectories: true)
            for (name, content) in files {
                try content.write(to: folder.appendingPathComponent(name), atomically: true, encoding: .utf8)
            }
        } catch {
            NSLog("[ExamplePlugins] Could not create \(folder.path): \(error)")
        }
    }

    private static let files: [(String, String)] = [
        ("README.md", readme),
        ("title-case.js", titleCase),
        ("tsv-to-markdown-table.js", tsvToMarkdownTable),
        ("wrap-in-code-block.js", wrapInCodeBlock),
    ]

    private static let readme = #"""
    # xNotes Clipboard Transforms

    Every `.js` file in this folder adds an entry to the clipboard context menu.
    Changes are picked up automatically — no restart needed.

    ```js
    /**
     * @title  My Transform          (menu title; default: file name)
     * @group  JSON                  (submenu; existing groups like "Case", "Lines",
     *                                "JSON" … or a new name; default: "Plugins")
     * @id     me.my-transform       (optional, must be unique)
     * @input  Prefix:               (optional: asks for a value → ctx.argument)
     * @description What it does     (optional)
     */
    function transform(input, ctx) {
      // input: the clipboard item text
      // ctx.argument: value entered for @input (or null)
      // ctx.fileName: name of this file
      return input.toUpperCase();   // return null/undefined to leave the text unchanged
    }
    ```

    Notes:
    - Throwing an error (`throw new Error("…")`) shows the message in xNotes.
    - `console.log(…)` writes to the macOS log (Console.app, filter "xNotes plugin").
    - Scripts run in an isolated JavaScript context without file or network access
      and are stopped after 3 seconds.
    - Files that fail to load are listed under Plugins ▸ Load Errors.
    """#

    private static let titleCase = #"""
    /**
     * @title  Title Case
     * @group  Case
     * @id     example.title-case
     * @description Capitalizes the first letter of every word.
     */
    function transform(input) {
      return input.toLowerCase().replace(/(^|[\s\-_/(])(\p{L})/gu,
        (_, sep, ch) => sep + ch.toUpperCase());
    }
    """#

    private static let tsvToMarkdownTable = #"""
    /**
     * @title  Table (TSV/CSV) → Markdown
     * @group  Markdown
     * @id     example.tsv-to-markdown-table
     * @description Converts rows copied from Excel/Numbers (tab separated) or simple CSV into a Markdown table.
     */
    function transform(input) {
      const lines = input.replace(/\r\n?/g, "\n").split("\n").filter(l => l.trim() !== "");
      if (lines.length === 0) return null;

      const sep = lines[0].includes("\t") ? "\t" : (lines[0].includes(";") ? ";" : ",");
      const rows = lines.map(l => l.split(sep).map(c => c.trim().replace(/\|/g, "\\|")));
      const width = Math.max(...rows.map(r => r.length));
      if (width < 2) throw new Error("No columns found (expected tab, ';' or ',' separated text).");

      const pad = r => r.concat(Array(width - r.length).fill(""));
      const line = r => "| " + pad(r).join(" | ") + " |";
      return [line(rows[0]), line(Array(width).fill("---")), ...rows.slice(1).map(line)].join("\n");
    }
    """#

    private static let wrapInCodeBlock = #"""
    /**
     * @title  Wrap in Code Block
     * @group  Markdown
     * @id     example.wrap-in-code-block
     * @input  Language (optional, e.g. swift):
     * @description Wraps the text in a fenced Markdown code block.
     */
    function transform(input, ctx) {
      const lang = (ctx.argument || "").trim();
      return "```" + lang + "\n" + input.replace(/\s+$/, "") + "\n```";
    }
    """#
}
