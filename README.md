<!--
Copyright (c) 2025 Luka Löhr
-->

# SchoolCode

Automated developer tool deployment for macOS Guest accounts.

[![Version](https://img.shields.io/github/v/release/luka-loehr/SchoolCode?label=version&color=blue&logo=github)](https://github.com/luka-loehr/SchoolCode/releases)
[![macOS](https://img.shields.io/badge/macOS-10.14%2B-success)](https://support.apple.com/macos)
[![License](https://img.shields.io/badge/license-Apache%202.0-green)](LICENSE)

## What is SchoolCode?

SchoolCode automates setup of a complete, isolated development environment for students on shared macOS machines. It installs essential developer tools (Python, Homebrew, Git, pip) with security wrappers that prevent Guest accounts from modifying system-wide packages or using sudo.

## Quick Start

```bash
# Clone and install
git clone https://github.com/luka-loehr/SchoolCode.git
cd SchoolCode
sudo ./schoolcode.sh
```

## Main Interface

### Primary Commands (schoolcode.sh)
The main `schoolcode.sh` script is your primary interface for installation and management:

```bash
sudo ./schoolcode.sh                    # Install everything (full setup)
sudo ./schoolcode.sh --install          # Same as above (explicit)
sudo ./schoolcode.sh --uninstall        # Remove SchoolCode (non-interactive)
sudo ./schoolcode.sh --status           # Check system health
sudo ./schoolcode.sh --logs             # View logs (interactive menu)
sudo ./schoolcode.sh --help             # Show help
```

### Advanced CLI (scripts/schoolcode-cli.sh)

For advanced management, use the CLI tool:

#### System Management
```bash
sudo ./scripts/schoolcode-cli.sh status [detailed]       # Show system status
sudo ./scripts/schoolcode-cli.sh health [detailed]       # Run health checks
sudo ./scripts/schoolcode-cli.sh repair                  # Fix system issues
sudo ./scripts/schoolcode-cli.sh compatibility           # Check system compatibility
```

#### Installation & Updates
```bash
sudo ./scripts/schoolcode-cli.sh install [--no-backup]   # Install SchoolCode
sudo ./scripts/schoolcode-cli.sh uninstall               # Remove SchoolCode
sudo ./scripts/schoolcode-cli.sh update                  # Update all components
```

#### Configuration & Tools
```bash
sudo ./scripts/schoolcode-cli.sh config show             # Show current config
sudo ./scripts/schoolcode-cli.sh config edit             # Edit configuration
sudo ./scripts/schoolcode-cli.sh tools list              # List available tools
sudo ./scripts/schoolcode-cli.sh tools versions          # Show tool versions
sudo ./scripts/schoolcode-cli.sh permissions fix         # Fix file permissions
sudo ./scripts/schoolcode-cli.sh permissions check       # Check permissions
```

#### Guest & Logs
```bash
sudo ./scripts/schoolcode-cli.sh guest setup             # Setup guest environment
sudo ./scripts/schoolcode-cli.sh guest test              # Test guest environment
sudo ./scripts/schoolcode-cli.sh guest cleanup           # Cleanup guest tools

sudo ./scripts/schoolcode-cli.sh logs [type] [lines]     # View logs
```

### Log Viewer

View detailed logs with the log viewer:

```bash
./schoolcode.sh --logs                  # Interactive log menu
./schoolcode.sh --logs errors 50        # Show last 50 error logs
./schoolcode.sh --logs install          # Show latest installation log
./schoolcode.sh --logs guest 100        # Show last 100 guest setup logs
./schoolcode.sh --logs warnings         # Show warnings
./schoolcode.sh --logs today            # Show today's logs
./schoolcode.sh --logs events           # Show structured events (JSON)
./schoolcode.sh --logs metrics          # Show performance metrics (JSON)
./schoolcode.sh --logs tail 200         # Tail main log (200 lines)
```

Or via CLI:
```bash
sudo ./scripts/schoolcode-cli.sh logs all 50             # All logs
sudo ./scripts/schoolcode-cli.sh logs error 20           # Error logs
sudo ./scripts/schoolcode-cli.sh logs guest 30           # Guest logs
sudo ./scripts/schoolcode-cli.sh logs clear              # Clear all logs
sudo ./scripts/schoolcode-cli.sh logs tail               # Live tail logs
```

## Requirements

- macOS 10.14+ (Mojave or newer)
- Administrator (sudo) privileges
- ~2GB free disk space (for installation)
- Internet connection (for downloading tools)

## What Gets Installed

### Core Components
1. **System Compatibility Check** - Validates system requirements and fixes issues
2. **Xcode Command Line Tools** - Required for development (installed via softwareupdate if needed)
3. **Homebrew** - Non-interactive installation via git clone (avoids password prompts)
4. **Python** - Official Python from python.org (with Homebrew fallback)
5. **Git** - System or Homebrew version
6. **pip** - Python package manager

### Security Features
- **Brew Wrapper** - Blocks system-wide package modifications for Guest accounts
- **Pip Wrapper** - Forces user-only package installations
- **Sudo Wrapper** - Prevents sudo usage for Guest users
- **Shell Configuration** - Automatic environment setup for Guest accounts
- **Temporary Workspace** - All Guest modifications are isolated and removable

## Security Model

SchoolCode implements strict Guest account isolation:

### Guest Account Protection
- **No System Modifications**: Security wrappers prevent Guest users from running `sudo` or installing system-wide packages
- **User-Only Packages**: pip installations restricted to user directory (`--user` flag)
- **Temporary Environment**: All Guest account modifications are cleaned on logout
- **Read-Only Tools**: Homebrew limited to read-only commands (list, search, info)

### System Integrity
- **No System File Changes**: Installation only creates tools in `/opt/schoolcode`
- **Reversible Setup**: Complete uninstall removes all traces
- **Admin Control**: Only administrators (via sudo) can install/uninstall

## Features

✅ Automatic system compatibility checking  
✅ Non-interactive Homebrew installation (no password prompts)  
✅ Official Python from python.org with fallback to Homebrew  
✅ Comprehensive error handling and logging  
✅ Guest account isolation with security wrappers  
✅ System repair utilities for fixing common issues  
✅ Detailed health checks and diagnostics  
✅ Interactive and non-interactive modes  
✅ Dry-run capability to preview changes  
✅ Backup and restore functionality  
✅ Complete logging with multiple output formats  

## Common Workflows

### Fresh Installation
```bash
sudo ./schoolcode.sh                           # Full automatic setup
sudo ./schoolcode.sh --status                  # Verify installation
```

### Check System Health
```bash
sudo ./scripts/schoolcode-cli.sh health        # Quick health check
sudo ./scripts/schoolcode-cli.sh health detailed  # Detailed diagnostics
```

### Repair System Issues
```bash
sudo ./scripts/schoolcode-cli.sh repair        # Auto-fix common issues
sudo ./scripts/schoolcode-cli.sh repair --verbose  # See what's being fixed
```

### Update Everything
```bash
sudo ./scripts/schoolcode-cli.sh update        # Update SchoolCode and dependencies
```

### View Installation Problems
```bash
./schoolcode.sh --logs errors                  # Show error logs
./schoolcode.sh --logs install                 # Show latest install log
sudo ./scripts/schoolcode-cli.sh logs tail     # Live tail of logs
```

## Troubleshooting

### Installation Failed
```bash
# Check system health
sudo ./scripts/schoolcode-cli.sh health detailed

# View error logs
./schoolcode.sh --logs errors 100

# Try repair
sudo ./scripts/schoolcode-cli.sh repair

# Check latest install log
./schoolcode.sh --logs install
```

### System Issues
```bash
# Check compatibility
sudo ./scripts/schoolcode-cli.sh compatibility

# Run full repair
sudo ./scripts/schoolcode-cli.sh repair

# Fix permissions
sudo ./scripts/schoolcode-cli.sh permissions fix
```

### Guest Account Problems
```bash
# Test guest environment
sudo ./scripts/schoolcode-cli.sh guest test

# Setup guest account
sudo ./scripts/schoolcode-cli.sh guest setup

# Cleanup guest tools
sudo ./scripts/schoolcode-cli.sh guest cleanup
```

## Version 3.0 Improvements

- **Enhanced Git Handling**: Separate Xcode CLT installation from Homebrew setup
- **Non-Interactive Homebrew**: Installation via git clone to avoid password prompts
- **Official Python Support**: Prefer python.org installer with Homebrew fallback
- **Improved Error Handling**: Better error detection and recovery
- **Enhanced Logging**: Comprehensive logging with multiple output formats
- **Security Wrappers**: Full Guest account isolation with brew/pip/sudo restrictions

## License

Apache License 2.0 - © 2025 Luka Löhr
