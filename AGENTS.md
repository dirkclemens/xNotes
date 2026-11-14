# Repository Guidelines

## Project Structure & Module Organization
- `xNotes/` contains the macOS app source.
- `xNotes/Manager/` holds app-level services and state (e.g., `NotesManager`).
- `xNotes/Model/` contains data models and persistence payloads.
- `xNotes/View/` contains SwiftUI views.
- `xNotes/MarkdownEditor/` provides the Markdown editor (editor component taken from github.com/dirkclemens/MarkdownEditor, without preview; xNotes additions in `MarkdownEditorTheme+xNotes.swift`).
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
- Backups are JSON payloads (`AppBackup`). If you add fields, keep decoding backward-compatible.
