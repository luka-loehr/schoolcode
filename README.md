# SchoolCode

Automated developer tool deployment for macOS Guest accounts.

[![Version](https://img.shields.io/github/v/release/luka-loehr/schoolcode?label=version&color=blue&logo=github)](https://github.com/luka-loehr/schoolcode/releases)
[![macOS](https://img.shields.io/badge/macOS-10.14%2B-success)](https://support.apple.com/macos)
[![License](https://img.shields.io/badge/license-Apache%202.0-green)](LICENSE)

## Overview

SchoolCode automates setup of a complete development environment for students on shared macOS machines. It installs Python, Homebrew, Git, and pip with security wrappers that prevent Guest accounts from modifying system packages or using sudo.

## Requirements

- macOS 10.14+ (Mojave or newer)
- Administrator (sudo) privileges
- ~2GB free disk space
- Internet connection

## Quick Start

```bash
# Clone and install into the system path used by the auto-update daemon
sudo mkdir -p /Library/SchoolCode
sudo git clone https://github.com/luka-loehr/schoolcode.git /Library/SchoolCode/repo
cd /Library/SchoolCode/repo
sudo ./schoolcode.sh
```

Verify installation:
```bash
sudo ./schoolcode.sh --status
```

## System location and release tracking

- The auto-update daemon expects the repository at `/Library/SchoolCode/repo`. Install from that path so the update script and LaunchDaemon can reach the git checkout without user logins.
- The installer records the last installed release in `/Library/SchoolCode/.installedversion` so updates only trigger when a newer tagged release is available. The file lives outside the git working copy, so hard resets will not remove it.

## Auto-update LaunchDaemon

The installer now writes and loads the auto-update LaunchDaemon automatically, so a standard `sudo ./schoolcode.sh` run sets up periodic updates without any extra steps. `sudo ./schoolcode.sh --status` will report an error if the LaunchDaemon is missing or unloaded.

If you need to reinstall it manually, use:

```bash
sudo cp SchoolCode_launchagents/com.schoolcode.autoupdate.plist /Library/LaunchDaemons/
sudo chown root:wheel /Library/LaunchDaemons/com.schoolcode.autoupdate.plist
sudo launchctl load -w /Library/LaunchDaemons/com.schoolcode.autoupdate.plist
```

The daemon runs `/Library/SchoolCode/repo/scripts/system_update.sh`, checks GitHub releases, and only performs a `git reset --hard` when a newer release tag exists. Update logs live in `/var/log/schoolcode/daemon_update.log`.

## Basic Commands

```bash
sudo ./schoolcode.sh                    # Install everything
sudo ./schoolcode.sh --status           # Check system health
sudo ./schoolcode.sh --uninstall        # Remove SchoolCode
sudo ./schoolcode.sh --logs             # View logs interactively
sudo ./schoolcode.sh --help             # Show help
```

## What Gets Installed

- **Xcode Command Line Tools** - Required development tools
- **Homebrew** - Package manager (non-interactive installation)
- **Python** - Official Python from python.org
- **Git** - Version control
- **pip** - Python package manager
- **Security Wrappers** - Prevents Guest users from modifying system packages

## Security Model

Guest accounts are fully isolated:
- Cannot use `sudo` or install system-wide packages
- pip restricted to user-only installations (`--user` flag)
- Homebrew limited to read-only commands
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
├── scripts/
│   ├── schoolcode-cli.sh            # Advanced CLI tool
│   ├── install.sh                   # Installation logic
│   ├── uninstall.sh                 # Removal script
│   ├── utils/                       # Utility functions
│   └── setup/                       # Guest configuration
├── tests/                           # Test suite
└── README.md                        # This file
```

## License

Apache License 2.0 - © 2025 Luka Löhr


> Auto-update test note added at 2025-12-03 10:43:30
