# ClipMind — Smart Clipboard for macOS

Remembers everything you copy — text, code, links and images — so you can search it, pin it and file it.

- **History** – captures text, code (auto-detected), URLs and images; duplicates are merged
- **Search** – instant, multi-word, also matches titles, source app and folder names (⌘F)
- **Pin** – pinned clips stay on top and are never auto-deleted
- **Folders** – organise snippets; drag clips onto a folder or right-click → Move to Folder
- **Snippets** – give any text clip a title and edit its content
- **Quick panel** – menu-bar icon or **⌘⇧V** from anywhere; type, ↑/↓, Return to copy
- **Private** – stored locally in `~/Library/Application Support/ClipMind`; clips flagged as
  concealed by password managers are never recorded

## Build & run
    ./build.sh            # universal app → build/ClipMind.app
    ./build.sh --install  # also copies it to /Applications
Requires macOS 14+ and Xcode command-line tools. The app is ad-hoc signed; on first launch of a
copy from elsewhere, right-click → Open.
