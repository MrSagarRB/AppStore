# QuickNote — Instant Notes for macOS

Open a tiny floating note with a keyboard shortcut. Jot snippets, temporary thoughts and reminders
without leaving the app you're in — everything saves automatically.

- **⌃⌥N** (from anywhere) opens a new floating note and puts the cursor in it. It doesn't steal focus
  from the app you were using.
- **Auto-sized text** – short thoughts big, longer ones smaller, always centered like a sticky note
- **7 colors, 4 fonts** (bold, handwritten, serif, typewriter) — hover a note for the controls
- **Reminders** – the note pops up on screen when the time comes (10 min … tomorrow 9 AM, or a custom time)
- **Temporary notes** – auto-delete after 1 hour / 1 day / 1 week
- **Float above windows** (default) or sit with your other windows; notes follow you across Spaces
  and appear over full-screen apps
- **⌃⌥H** hides / shows every note at once; **⌘W** closes the focused note (it stays saved)
- **All Notes** window: search, filter (On Desktop / Reminders / Temporary), reopen or delete
- Notes remember where you left them and reappear after a restart. Stored locally with SwiftData in
  `~/Library/Application Support/QuickNote`.

## Build & install
    ./build.sh            # → build/QuickNote.app and build/QuickNote.dmg (drag-to-Applications installer)
    ./build.sh --install  # also copies the app straight into /Applications

Requires macOS 14+ and Xcode command-line tools. Uses `icon.png` for the app icon if present
(see `../tools/prepare-icon.swift`), otherwise the built-in drawn icon.

Debug flags: `--demo` (in-memory sample notes), `--library` (open All Notes), `--new-note`,
`--test-timers` (exercise reminders and auto-delete).
