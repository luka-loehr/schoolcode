# SchoolCode — Dev environment setup for shared school Macs

[![macOS](https://img.shields.io/badge/macOS-10.14%2B-007AFF?style=flat&logo=apple&logoColor=white)](https://support.apple.com/macos)
[![Version](https://img.shields.io/github/v/release/luka-loehr/schoolcode?label=version&color=blue&logo=github&style=flat)](https://github.com/luka-loehr/schoolcode/releases)
[![License](https://img.shields.io/badge/License-Apache%202.0-green?style=flat)](LICENSE)

**SchoolCode** sets up a complete development environment on shared school Macs in one command. It installs Python, Homebrew, Git, and pip in a way that fits standard macOS account permissions and Homebrew ownership.

The CLI uses a vendored [Charm Gum](https://github.com/charmbracelet/gum) runtime that is committed into this repository, so the terminal interface does not depend on a separate system package or network fetch at install time.

## Requirements

- macOS 10.14+ (Mojave or newer)
- Administrator (sudo) privileges
- ~2GB free disk space
- Internet connection

## Quick Start

```bash
# Clone the repository
git clone https://github.com/luka-loehr/schoolcode.git
cd schoolcode
sudo ./schoolcode.sh
```

Verify installation:
```bash
sudo ./schoolcode.sh --status
```

## Basic Commands

```bash
sudo ./schoolcode.sh                    # Install everything
sudo ./schoolcode.sh --interactive      # Compatibility alias for guided install
sudo ./schoolcode.sh --status           # Check system health
sudo ./schoolcode.sh --uninstall        # Remove SchoolCode
sudo ./schoolcode.sh --logs             # View logs
sudo ./schoolcode.sh --help             # Show help
```

## What Gets Installed

- **Xcode Command Line Tools** - Required development tools
- **Homebrew** - Package manager (non-interactive installation)
- **Python** - Official Python from python.org
- **Git** - Version control
- **pip** - Python package manager
- **Pip Shims** - Resolve the active pip binary consistently for the shared environment
- **Vendored Gum Runtime** - Shared terminal UI runtime for SchoolCode commands

## Security Model

SchoolCode leans on standard macOS account isolation and normal filesystem permissions:
- Cannot administer the Mac or change system settings
- pip restricted to user-only installations (`--user` flag)
- Homebrew remains owned by the installing account in the default prefix
- All modifications cleaned on logout

## Advanced Usage

For granular control, use the CLI tool:

```bash
# System management
sudo ./scripts/schoolcode-cli.sh status [detailed]
sudo ./scripts/schoolcode-cli.sh health [detailed]
sudo ./scripts/schoolcode-cli.sh repair

# Guest account
sudo ./scripts/schoolcode-cli.sh guest setup
sudo ./scripts/schoolcode-cli.sh guest test

# Configuration
sudo ./scripts/schoolcode-cli.sh config show
sudo ./scripts/schoolcode-cli.sh tools list
```

## Troubleshooting

**Installation problems:**
```bash
sudo ./schoolcode.sh --status           # Check system health
./schoolcode.sh --logs errors           # View error logs
sudo ./scripts/schoolcode-cli.sh repair # Auto-fix issues
```

**Guest account issues:**
```bash
sudo ./scripts/schoolcode-cli.sh guest test
sudo ./scripts/schoolcode-cli.sh guest setup
```

## Project Structure

```
SchoolCode/
├── schoolcode.sh                    # Main entry point
├── system_repair.sh                # Compatibility wrapper for repair utility
├── old_mac_compatibility.sh        # Compatibility wrapper for checker
├── scripts/
│   ├── schoolcode-cli.sh            # Advanced CLI tool
│   ├── install.sh                   # Installation logic
│   ├── uninstall.sh                 # Removal script
│   ├── utils/                       # Utility functions
│   └── setup/                       # Guest configuration
├── vendor/gum/                      # Vendored Gum binaries for macOS
├── tests/                           # Test suite
└── README.md                        # This file
```

## License

Apache 2.0

---

Developed by [Luka Löhr](https://github.com/luka-loehr)
