# MarkdownView

A native, blazing-fast macOS Markdown editor built with SwiftUI and NSTextView. Designed for developers who appreciate clean code, native performance, and modern macOS architecture.

## ✨ Features

- **Extreme Performance**: Direct NSTextView integration via NSViewRepresentable for maximum editing performance
- **Native Document Architecture**: DocumentGroup with FileDocument protocol for native document handling
- **Split View Layout**: Editor on left, preview on right with draggable divider
- **Debounced Block-Aware Preview**: Preview updates after a short idle delay to keep typing responsive
- **Structured Markdown Rendering**: Headings, lists, blockquotes, code fences, and table-like rows are rendered with block-aware styling
- **Defensive Layout Fallback**: Automatically falls back to source-preserving preview when rendered output collapses line breaks
- **Large File Support**: Handles files up to 10MB effortlessly with native text engine
- **Zero Dependencies**: Pure Apple frameworks (SwiftUI, AppKit, Foundation)
- **File Associations**: Native support for .md, .markdown, .mdown extensions
- **Dark Mode**: Automatic system appearance support

## 🚀 Quick Start

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

## 📋 Requirements

- **macOS**: 15.0+ (Sequoia)
- **Swift**: 6.1+
- **Xcode**: 16.0+ (Command Line Tools)

## 🛠️ Building from Source

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

## ✅ Testing

```bash
# Run all tests
swift test

# Run preview-specific tests
swift test --filter MarkdownPreviewStateTests
```

## 🎯 Setting as Default Markdown App

### Option 1: Right-Click (Per File)
1. Right-click any Markdown file (.md, .markdown, .mdown)
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

## 🏗️ Architecture

### Design Decisions

| Component | Technology | Rationale |
|-----------|-----------|-----------|
| **Build System** | Swift Package Manager | No Xcode project, CI/CD friendly, reproducible builds |
| **UI Framework** | SwiftUI + DocumentGroup | Native document-based architecture, modern declarative UI |
| **Text Engine** | NSTextView via NSViewRepresentable | Maximum performance, handles large files effortlessly |
| **Preview Engine** | `MarkdownPreviewState` + `AttributedString` Markdown | Debounced parsing with block-aware rendering and collapse-detection fallback |
| **Document Model** | FileDocument | SwiftUI's native document protocol, automatic save/open |
| **Layout** | HSplitView | Native macOS split view with draggable divider |

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
│       ├── ContentView.swift        # Main split view interface
│       ├── MarkdownEditorView.swift # NSTextView NSViewRepresentable bridge
│       ├── MarkdownPreviewState.swift # Debounced parser + block-aware render logic
│       └── MarkdownPreviewView.swift # Preview UI + status/fallback banners
├── Tests/
│   └── MarkdownViewAppTests/
│       ├── MarkdownDocumentTests.swift
│       └── MarkdownPreviewStateTests.swift
└── MarkdownView.app                 # Built app bundle
```

### Markdown Compatibility

- Markdown parsing is powered by Apple Foundation `AttributedString` Markdown APIs.
- Preview rendering is block-aware for readability and uses inline markdown parsing per line to preserve source structure.
- If parser output appears structurally collapsed (for example lost line breaks), preview automatically falls back to source-preserving plain text.
- This app prioritizes native performance and readability over exact GitHub HTML parity for every markdown edge case.

## ⌨️ Keyboard Shortcuts

| Shortcut | Action |
|----------|--------|
| `⌘+O` | Open Markdown file |
| `⌘+S` | Save document |
| `⌘+W` | Close window |
| `⌘+Q` | Quit app |
| `⌘+N` | New document |
| Toolbar Eye Icon | Toggle preview pane |

## 📦 Distribution

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

## 🐛 Troubleshooting

### App Won't Open

```bash
# Remove quarantine attribute
xattr -cr MarkdownView.app

# Or allow in System Settings > Privacy & Security
```

### Markdown Files Not Opening

1. Check **System Settings > Privacy & Security > Files and Folders**
2. Ensure MarkdownView has access to the folder containing your files
3. Try opening via **File > Open** menu instead of double-click

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

## 📝 License

MIT License - See [LICENSE](LICENSE) file for details.

This is a personal project by [@duhman](https://github.com/duhman).

## 🙏 Acknowledgments

- Built with Apple's [AppKit](https://developer.apple.com/documentation/appkit) and [SwiftUI](https://developer.apple.com/documentation/swiftui) frameworks
- Uses native NSTextView for extreme editing performance
- Inspired by the macOS document-based app paradigm

---

**Made with ❤️ for macOS** — Fast, native, no Electron, no bloat.
