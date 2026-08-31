# MarkdownView

A personal, native macOS viewer for local Markdown files. Built with SwiftUI and AppKit — open a `.md` file and read the rendered preview. No Electron, no bloat.

## Features

- **Viewer-first**: Opening a file shows the rendered preview; the source editor is hidden until you toggle it
- **Native Document Architecture**: DocumentGroup with FileDocument for standard open/save via the File menu
- **GFM tables and images**: Relative images resolve from the file's directory via `baseURL`
- **Debounced preview**: Preview updates after a short idle delay while you edit
- **Optional editor**: Toggle the plain-text editor pane when you need to tweak source
- **Preview size limit**: Full markdown rendering up to ~1 MB; larger files use faster inline-only parsing (see Markdown Compatibility)
- **Zero dependencies**: Pure Apple frameworks (SwiftUI, AppKit, Foundation)
- **File associations**: Native support for `.md`, `.markdown`, `.mdown` extensions
- **Dark mode**: Automatic system appearance support

## Quick Start

```bash
# Clone the repository
git clone https://github.com/duhman/markdownview.git
cd markdownview

# Build the app
./build_app.sh

# Or build and install in one command
./build_app.sh release --install

# Launch MarkdownView
open MarkdownView.app
```

## Requirements

- **macOS**: 15.0+ (Sequoia)
- **Swift**: 6.1+
- **Xcode**: 16.0+ (Command Line Tools)

## Building from Source

### One-Command Build

```bash
./build_app.sh
```

This creates `MarkdownView.app` in the project directory, ready to use.

### Build and Install

```bash
./build_app.sh release --install
```

This builds a release version and copies it to `/Applications/`.

### Manual Build

```bash
# Development build
swift build

# Release build
swift build -c release

# Run directly (for testing)
swift run
```

## Testing

```bash
# Run all tests
swift test

# Run preview-specific tests
swift test --filter MarkdownPreviewStateTests
```

## Setting as Default Markdown App

### Option 1: Right-Click (Per File)
1. Right-click any Markdown file (`.md`, `.markdown`, `.mdown`)
2. Select **Get Info** (⌘+I)
3. Under **Open with:**, select **MarkdownView**
4. Click **Change All...** to apply to all Markdown files

### Option 2: Command Line (All Markdown Files)
```bash
# Install duti if not already installed
brew install duti

# Set MarkdownView as default for all Markdown files
duti -s com.bigmac.markdownview net.daringfireball.markdown all
```

## Architecture

### Design Decisions

| Component | Technology | Rationale |
|-----------|-----------|-----------|
| **Build System** | Swift Package Manager | No Xcode project, CI/CD friendly, reproducible builds |
| **UI Framework** | SwiftUI + DocumentGroup | Native document-based architecture, modern declarative UI |
| **Text Engine** | NSTextView via NSViewRepresentable | Optional editor pane for source editing |
| **Preview Engine** | `MarkdownPreviewState` + `AttributedString` Markdown | Debounced full-markdown parsing with relative URL resolution |
| **Document Model** | FileDocument | SwiftUI's native document protocol, automatic save/open |
| **Layout** | HSplitView | Preview by default; optional editor pane |

### Project Structure

```
markdownview/
├── Package.swift                    # Swift Package Manager manifest
├── build_app.sh                     # App bundling & installation script
├── README.md                        # This file
├── .gitignore                       # Git ignore rules
├── Sources/
│   ├── MarkdownViewApp/
│   │   ├── MarkdownViewApp.swift    # @main App entry point
│   │   └── MarkdownDocument.swift   # FileDocument implementation
│   └── Views/
│       ├── ContentView.swift        # Viewer-first split view
│       ├── MarkdownEditorView.swift # Optional NSTextView editor pane
│       ├── MarkdownPreviewState.swift # Debounced parser + render logic
│       └── MarkdownPreviewView.swift # Preview UI + status banners
├── Tests/
│   └── MarkdownViewAppTests/
│       ├── MarkdownDocumentTests.swift
│       └── MarkdownPreviewStateTests.swift
└── MarkdownView.app                 # Built app bundle
```

### Markdown Compatibility

- Markdown parsing uses Apple Foundation `AttributedString` Markdown APIs (full syntax by default).
- Relative image and link URLs resolve against the opened file's directory.
- Very large files (>1 MB UTF-8) fall back to inline-only parsing to keep preview responsive; tables may not render in that mode.
- Plain-text fallback is reserved for parse failures, not for documents containing tables or images.

## Keyboard Shortcuts

| Shortcut | Action |
|----------|--------|
| `⌘+O` | Open Markdown file |
| `⌘+S` | Save document (File menu) |
| `⌘+W` | Close window |
| `⌘+Q` | Quit app |
| `⌘+N` | New document |
| Toolbar Editor Icon | Toggle source editor pane |

## Distribution

### Local Installation

```bash
# Build and install to Applications
./build_app.sh release --install

# Or manually copy
cp -R MarkdownView.app /Applications/

# Or create symlink
ln -s $(pwd)/MarkdownView.app /Applications/MarkdownView.app
```

### Sharing the App

The built `MarkdownView.app` is self-contained and can be:
- Copied to other Macs running macOS 15+
- Shared via AirDrop, Dropbox, etc.
- Installed by simply dragging to `/Applications`

**Note**: Since the app is ad-hoc signed, users may need to:
1. Right-click the app and select **Open** (first launch only)
2. Or run: `xattr -cr MarkdownView.app` to remove quarantine

## Troubleshooting

### App Won't Open

```bash
# Remove quarantine attribute
xattr -cr MarkdownView.app

# Or allow in System Settings > Privacy & Security
```

### Markdown Files Not Opening

1. Rebuild the app bundle so `Info.plist` document types and entitlements are applied: `./build_app.sh release --install`
2. Relaunch MarkdownView after install (LaunchServices caches handler metadata)
3. Check **System Settings > Privacy & Security > Files and Folders** if a specific folder still blocks access
4. Use **Open With > MarkdownView** once if the file’s type is `public.plain-text` rather than `net.daringfireball.markdown`

Double-click and **File > Open** both grant sandbox access via `com.apple.security.files.user-selected.read-write`; the bundled app declares handlers for `net.daringfireball.markdown` and extension-scoped `public.plain-text`.

### Preview Looks Unexpected

1. Confirm you are running the latest installed app at `/Applications/MarkdownView.app`
2. Rebuild and reinstall: `./build_app.sh release --install`
3. Relaunch the app after install to refresh LaunchServices cache
4. Run `swift test --filter MarkdownPreviewStateTests` to verify preview pipeline checks

### Build Errors

```bash
# Clean build
swift package clean
rm -rf .build/

# Rebuild
./build_app.sh
```

## License

MIT License - See [LICENSE](LICENSE) file for details.

This is a personal project by [@duhman](https://github.com/duhman).

## Acknowledgments

- Built with Apple's [AppKit](https://developer.apple.com/documentation/appkit) and [SwiftUI](https://developer.apple.com/documentation/swiftui) frameworks
- Uses native NSTextView for the optional source editor
- Inspired by the macOS document-based app paradigm

---

**Made with ❤️ for macOS** — Fast, native, no Electron, no bloat.
