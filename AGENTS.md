# Repository Guidelines

## Project Structure & Module Organization
- `xNotes/` contains the macOS app source.
- `xNotes/Manager/` holds app-level services and state (e.g., `NotesManager`).
- `xNotes/Model/` contains data models and persistence payloads.
- `xNotes/View/` contains SwiftUI views.
- The Markdown editor comes from the Swift package [MarkdownEditorKit](https://github.com/dirkclemens/MarkdownEditorKit) (shared with MarkdownEditor). Fix editor bugs there, tag a new version and update the package in Xcode (File › Packages › Update to Latest Package Versions). `xNotes/MarkdownEditor/MarkdownEditorTheme+xNotes.swift` holds the xNotes additions ("System" theme, theme lookup).
- `xNotes/Transforms/` contains clipboard text transforms: built-ins, the JavaScript plugin loader, and `TransformRegistry`.
- `xNotes/Assets.xcassets/` stores app assets.

## Build, Test, and Development Commands
- Xcode: open `xNotes.xcodeproj` and run the `xNotes` scheme.
- CLI build (optional):
  ```sh
  xcodebuild -project xNotes.xcodeproj -scheme xNotes -configuration Debug build
  ```
- There is no automated test target in this repo.

## Coding Style & Naming Conventions
- Language: Swift (SwiftUI + AppKit).
- Indentation: 4 spaces, no tabs.
- Types use `PascalCase` (e.g., `NotesManager`), variables/functions use `camelCase`.
- Prefer small, focused methods in managers; keep UI logic inside views.
- No formatter or linter is configured; follow existing file style.

## Testing Guidelines
- No test framework is currently set up.
- If you add tests, keep them near the relevant module and document how to run them.

## Commit & Pull Request Guidelines
- No commit convention is enforced. Use short, imperative subject lines (e.g., “Add clipboard append menu”).
- PRs should include:
  - A brief summary of changes.
  - Screenshots or GIFs for UI changes.
  - Notes on any data or settings migrations.

## Data & Configuration Notes
- Notes and clipboard state are stored in `~/Library/Application Support/<bundle id>/tabs.json` (see `TabsFileStore`); older builds used `UserDefaults` and are migrated on first launch.
- Settings are stored in `UserDefaults` (`@AppStorage`).
- Clipboard transform plugins are `.js` files in `~/Library/Application Support/<bundle id>/Transforms/` (format: see the README seeded there and `JavaScriptTransformLoader`). New built-in transforms go into `BuiltinTransforms.all`; the context menu is generated from `TransformRegistry`.
- The target uses `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor`; code that runs off the main thread must be marked `nonisolated`.
- Formatted versions (RTF/HTML) of clipboard entries live in `~/Library/Application Support/<bundle id>/ClipboardRichText/<item id>.<rtf|html>` (`ClipboardRichTextStore`); files of removed entries are deleted on save.
- Clipboard images live in `~/Library/Application Support/<bundle id>/ClipboardImages/<item id>.png` plus `-thumb.png` (`ClipboardImageStore`); they are not included in backups.
- Backups are JSON payloads (`AppBackup`). If you add fields, keep decoding backward-compatible.
