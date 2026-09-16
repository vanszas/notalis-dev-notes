<h1 align="center" style="border-bottom: none">
    <b>
        <a href="https://github.com/vanszas/notalis-dev-notes">Notalis</a><br>
    </b>
    ⭐️  The Open Source Knowledge & Notes System  ⭐️ <br>
</h1>

<p align="center">
Notalis is a privacy-first offline knowledge management system with AI assistance.
Organize your notes, documents, and workflows in one place.
</p>

<p align="center">
<a href="https://github.com/vanszas/notalis-dev-notes"><img src="https://img.shields.io/badge/GitHub-repo-blue"></a>
<a href="https://discord.gg/9Q2xaN37tV"><img src="https://img.shields.io/badge/Discord-join-orange"></a>
<a href="https://github.com/vanszas/notalis-dev-notes"><img src="https://img.shields.io/github/stars/vanszas/notalis-dev-notes.svg?style=flat&logo=github&colorB=deeppink&label=stars"></a>
<a href="https://github.com/vanszas/notalis-dev-notes"><img src="https://img.shields.io/github/forks/vanszas/notalis-dev-notes.svg"></a>
</p>

<p align="center">
    <a href="https://github.com/vanszas/notalis-dev-notes"><b>GitHub</b></a> •
    <a href="https://github.com/vanszas/notalis-dev-notes/wiki"><b>Wiki</b></a> •
    <a href="https://discord.gg/9Q2xaN37tV"><b>Discord</b></a> •
    <a href="https://twitter.com/vanszas"><b>Twitter</b></a>
</p>

## Core Features

- **📝 Note Organization** - Flexible document structure with rich text editing
- **🗂️ Database Views** - Gallery, Kanban, Timeline, Form, Feed, Dashboard, Map views
- **🔗 Notion Sync** - Two-way live sync with Notion pages and databases
- **🤖 AI Assistant** - Multi-agent brain selector (Hermes, Codex, Claude, Antigravity)
- **🎨 Flow Canvas** - Infinite canvas flow diagrams (tldraw-inspired)
- **📱 Offline-First** - All data stored locally, secure backup to Google Drive
- **🔄 Smart Navigation** - Breadcrumb parent-child relationship tracking
- **🔐 Privacy-Focused** - No cloud dependencies, 100% local storage

## Installation

### Windows

Download the latest release from [GitHub Releases](https://github.com/vanszas/notalis-dev-notes/releases)

- Download for Windows (x64)
- Extract and run `Notalis.exe`

### Linux

Available via package managers:
- [Flathub](https://flathub.org/apps/io.notalis.Notalis)
- [Snapcraft](https://snapcraft.io/notalis)

### macOS

Coming soon - building for Apple Silicon and Intel

## Quick Start

1. **Create your first workspace** - Launch Notalis and create a new workspace
2. **Import from Notion** - Connect your Notion account and import pages
3. **Use AI Assistant** - Press `Ctrl+Shift+A` to open AI sidebar
4. **Add gallery view** - Type `/gallery` to add interactive card database view
5. **Create flow diagram** - Type `/flow` or `/canvas` for infinite canvas

## AI Features

Notalis supports multiple AI agents for different use cases:

| Agent | Use Case | Description |
|-------|----------|-------------|
| **Hermes Agent** | Writing & Research | Empirical grounding, offline-first, anti-hallucination |
| **Codex CLI** | Technical Tasks | Efficient code generation and system optimization |
| **Claude Code** | Deep Analysis | Systemic reasoning and architectural patterns |
| **Antigravity** | Safety Review | Multi-agent verification and quality assurance |
| **Direct Model** | Standard LLM | Fallback to default model when needed |

### How to Switch Agents

1. Open AI Assistant (`Ctrl+Shift+A`)
2. Click dropdown menu at top-right labeled "Hermes Agent"
3. Select your preferred agent
4. Continue conversation with selected brain

## Project Structure

```
notalis/
├── frontend/appflowy_flutter/     # Flutter UI implementation
│   ├── lib/                       # Dart source code
│   │   ├── ai/                    # AI services & widgets
│   │   ├── plugins/document/      # Document editor & plugins
│   │   └── workspace/             # Workspace management
│   ├── pubspec.yaml               # Flutter dependencies
│   └── build/                     # Build artifacts
├── CMakeLists.txt                 # Root build configuration
├── README.md                      # This file
└── LICENSE                        # AGPL-3.0 License
```

## Architecture

Notalis is built with:

- **Flutter** - Cross-platform UI framework
- **Rust** - Backend services and data synchronization
- **SQLite** - Local database storage
- **Notion API** - External integration layer
- **Local LLM endpoints** - AI processing via 9router protocol

## Data Storage

All user data is stored locally:

- **Windows**: `%APPDATA%\Notalis\data`
- **macOS**: `~/Library/Application Support/Notalis/data`
- **Linux**: `~/.local/share/Notalis/data`

Optional backup to Google Drive mount point (configurable).

## Development

### Prerequisites

- Flutter SDK ≥ 3.27.4
- Rust toolchain
- Node.js ≥ 18.x
- Git

### Setup

```bash
# Clone repository
git clone https://github.com/vanszas/notalis-dev-notes.git
cd notalis

# Install dependencies
flutter pub get

# Run development server
flutter run -d windows
```

### Build Release

```bash
# Build Windows executable
flutter build windows --release

# Output will be in: build/windows/x64/release/runner/Release/Notalis.exe
```

## Contributing

We welcome contributions! Please see our [Contributing Guide](https://github.com/vanszas/notalis-dev-notes/wiki/Contributing) for details.

- Report bugs on [GitHub Issues](https://github.com/vanszas/notalis-dev-notes/issues)
- Feature requests on [GitHub Discussions](https://github.com/vanszas/notalis-dev-notes/discussions)
- Join Discord community for real-time discussion

## Community

- **GitHub**: [@vanszas](https://github.com/vanszas)
- **Discord**: [Join Server](https://discord.gg/9Q2xaN37tV)
- **Twitter**: [@vanszas](https://twitter.com/vanszas)
- **Reddit**: [/r/Notalis](https://www.reddit.com/r/Notalis/)

## License

This project is licensed under the AGPL-3.0 License - see the [LICENSE](LICENSE) file for details.

## Acknowledgments

- Built with ❤️ by the Notalis community
- Special thanks to all contributors

---

*Made with Flutter + Rust. Stay organized, stay private.*
