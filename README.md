<!--
Copyright (c) 2025 Luka Löhr
-->

# SchoolCode

Automated, secure developer tool deployment for macOS Guest accounts.

[![Version](https://img.shields.io/badge/version-3.0.0-blue)](https://github.com/luka-loehr/SchoolCode)
[![macOS](https://img.shields.io/badge/macOS-10.14%2B-success)](https://support.apple.com/macos)
[![License](https://img.shields.io/badge/license-Apache%202.0-green)](LICENSE)

## Overview

SchoolCode provides a safe, experimental development environment for students on shared macOS machines. It automatically deploys essential developer tools to Guest accounts, ensuring system integrity and preventing students from accidentally or intentionally breaking the system or tools for others.

## Key Features

*   **Secure Guest Environment**: Students can experiment freely without worrying about breaking system configurations or tools. All changes are temporary and isolated to their session.
*   **Essential Developer Tools**: Provides Homebrew, Python (from python.org), Git, and pip, pre-configured for secure use.
*   **Flexible Installation**: Choose between interactive mode (full control) or automatic mode (one-click setup).
*   **System Compatibility**: Comprehensive compatibility checker ensures your Mac meets requirements.
*   **System Repair**: Automatically fixes common issues like Xcode CLT, certificates, Git configuration, and PATH problems.
*   **Old Mac Support**: Robust operation on macOS versions back to 10.14 (Mojave) with compatibility flags.
*   **Automated Updates**: One-command updates for SchoolCode and all managed dependencies.

## Requirements

*   macOS 10.14 (Mojave) or newer
*   Admin access
*   [Homebrew](https://brew.sh) installed
*   Guest account enabled
*   5GB free disk space
*   Internet connection (for Python download during installation)

## Installation

### Quick Start (Recommended)

```bash
# Clone repository
git clone https://github.com/luka-loehr/SchoolCode.git
cd SchoolCode

# Automatic installation (recommended)
sudo ./schoolcode.sh

# Or interactive mode for more control
sudo ./schoolcode.sh --interactive
```

### Installation Modes

#### 🚀 Automatic Installation (One-time setup)
Installs everything automatically with minimal prompts:

```bash
# Automatic installation
sudo ./schoolcode.sh

# Or via CLI (legacy)
sudo ./scripts/schoolcode-cli.sh install-auto

# Skip system repair
sudo ./scripts/schoolcode-cli.sh install-auto --no-repair

# Force system repair
sudo ./scripts/schoolcode-cli.sh install-auto --force
```

#### 🎯 Interactive Installation (Choose components)
Allows you to choose which components to install:

```bash
# Interactive installation
sudo ./schoolcode.sh --interactive

# Or via CLI (legacy)
sudo ./scripts/schoolcode-cli.sh install-interactive
```

### What Gets Installed

1. **🔍 Compatibility Check** - Validates your Mac meets requirements
2. **🔧 System Repair** - Fixes Xcode CLT, certificates, Git, PATH issues
3. **📦 Development Tools** - Installs Python, Homebrew, Git, pip
4. **🔧 Guest Setup** - Configures Guest account environment

## Usage

SchoolCode is managed via its central hub interface:

### 🎛️ SchoolCode Hub (Recommended)
```bash
# Automatic installation (everything at once)
sudo ./schoolcode.sh

# Interactive mode (choose components)
sudo ./schoolcode.sh --interactive

# Check system status
sudo ./schoolcode.sh --status

# Show help
./schoolcode.sh --help
```

### 🔧 Advanced CLI Commands (Legacy)
```bash
# Installation commands
sudo ./scripts/schoolcode-cli.sh install-interactive
sudo ./scripts/schoolcode-cli.sh install-auto

# System management
sudo ./scripts/schoolcode-cli.sh status
sudo ./scripts/schoolcode-cli.sh compatibility
sudo ./scripts/schoolcode-cli.sh repair
sudo ./scripts/schoolcode-cli.sh update
sudo ./scripts/schoolcode-cli.sh uninstall

# Logging
sudo ./scripts/schoolcode-cli.sh logs
sudo ./scripts/schoolcode-cli.sh logs error
sudo ./scripts/schoolcode-cli.sh logs guest
```

### Guest Account Management
```bash
# Setup guest environment (run as Guest user)
sudo ./scripts/schoolcode-cli.sh guest setup

# Test guest environment
sudo ./scripts/schoolcode-cli.sh guest test

# Cleanup guest tools
sudo ./scripts/schoolcode-cli.sh guest cleanup
```

## Troubleshooting

### Common Issues

**Compatibility Check Fails:**
```bash
# Check detailed compatibility report
sudo ./scripts/schoolcode-cli.sh compatibility report
# Report saved to: /tmp/schoolcode_compatibility_report.txt
```

**System Repair Needed:**
```bash
# Run system repair
sudo ./scripts/schoolcode-cli.sh repair

# Or run individual repairs
sudo ./scripts/schoolcode-cli.sh repair xcode
```

**Check System Status:**
```bash
# View system health
sudo ./scripts/schoolcode-cli.sh status

# View detailed status
sudo ./scripts/schoolcode-cli.sh status detailed
```

**View Logs:**
```bash
# All logs
sudo ./scripts/schoolcode-cli.sh logs

# Error logs only
sudo ./scripts/schoolcode-cli.sh logs error

# Guest setup logs
sudo ./scripts/schoolcode-cli.sh logs guest
```

### Installation Modes

- **Interactive Mode**: Use when you want to choose which components to install
- **Automatic Mode**: Use for quick, one-time setup
- **Skip Repair**: Use `--no-repair` if system repair causes issues
- **Force Repair**: Use `--force` to ensure system repair runs

## Security

SchoolCode implements strict security measures to ensure a safe and stable environment. Guest user modifications are isolated, temporary, and non-destructive. For a detailed explanation of the security architecture and rationale, including how specific tools are managed, please refer to:

[SECURITY.md](SECURITY.md)

## License

Apache License 2.0 - © 2025 Luka Löhr
