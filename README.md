<!--
Copyright (c) 2025 Luka Löhr
-->

# SchoolCode

Automated, secure developer tool deployment for macOS Guest accounts.

[![Version](https://img.shields.io/badge/version-2.1.0-blue)](https://github.com/luka-loehr/SchoolCode)
[![macOS](https://img.shields.io/badge/macOS-10.14%2B-success)](https://support.apple.com/macos)
[![License](https://img.shields.io/badge/license-Apache%202.0-green)](LICENSE)

## Overview

SchoolCode provides a safe, experimental development environment for students on shared macOS machines. It automatically deploys essential developer tools to Guest accounts, ensuring system integrity and preventing students from accidentally or intentionally breaking the system or tools for others.

## Key Features

*   **Secure Guest Environment**: Students can experiment freely without worrying about breaking system configurations or tools. All changes are temporary and isolated to their session.
*   **Essential Developer Tools**: Provides Homebrew, Python (from python.org), Git, and pip, pre-configured for secure use.
*   **Automated Setup & Updates**: Simplifies deployment and maintenance with one-command installation and comprehensive updates.
*   **Old Mac Compatibility**: Includes features for robust operation on older macOS versions.

## Requirements

*   macOS 10.14 (Mojave) or newer
*   Admin access
*   [Homebrew](https://brew.sh) installed
*   Guest account enabled
*   5GB free disk space
*   Internet connection (for Python download during installation)

## Installation

```bash
# Clone repository
git clone https://github.com/luka-loehr/SchoolCode.git
cd SchoolCode

# Install SchoolCode and its tools (requires sudo)
sudo ./scripts/SchoolCode-cli.sh install
```

## Usage

SchoolCode is managed via its command-line interface:

```bash
# Check system health and status
sudo ./scripts/SchoolCode-cli.sh status

# Update SchoolCode and all managed dependencies
sudo ./scripts/SchoolCode-cli.sh update

# Remove SchoolCode from the system
sudo ./scripts/SchoolCode-cli.sh uninstall

# View error logs
./scripts/SchoolCode-cli.sh logs error

# Get help and see all commands
./scripts/SchoolCode-cli.sh --help
```

## Security

SchoolCode implements strict security measures to ensure a safe and stable environment. Guest user modifications are isolated, temporary, and non-destructive. For a detailed explanation of the security architecture and rationale, including how specific tools are managed, please refer to:

[SECURITY.md](SECURITY.md)

## License

Apache License 2.0 - © 2025 Luka Löhr
