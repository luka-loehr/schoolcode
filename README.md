<!--
Copyright (c) 2025 Luka Löhr
-->

# AdminHub

Automated developer tool deployment for macOS Guest accounts.

[![Version](https://img.shields.io/badge/version-2.2.0-blue)](https://github.com/luka-loehr/AdminHub)
[![macOS](https://img.shields.io/badge/macOS-10.14%2B-success)](https://support.apple.com/macos)
[![License](https://img.shields.io/badge/license-Site%20License-blue)](LICENSE)

## Overview

AdminHub automatically provides development tools to Guest users on shared Macs with enterprise-grade security.

**Tools included:**
- Python 3 & Python (latest version from python.org)
- Git
- Homebrew
- pip (with automatic `--user` flag for Guest users)

**Security features:**
- All Guest modifications are user-local only
- System-wide installations are blocked
- Changes reset on logout
- No risk of students breaking tools

## Requirements

- macOS 10.14 (Mojave) or newer
- Admin access
- [Homebrew](https://brew.sh) installed
- Guest account enabled
- 5GB free disk space
- Internet connection (for Python download during installation)

## Installation

```bash
# Clone repository
git clone https://github.com/luka-loehr/AdminHub.git
cd AdminHub

# Install (includes automatic system repairs for old Macs)
sudo ./scripts/adminhub-cli.sh install

# Verify installation
sudo ./scripts/adminhub-cli.sh status
```

All components should show "✅ HEALTHY".

**Note**: Installation automatically downloads and installs the latest Python version from python.org.

## Usage

```bash
sudo ./scripts/adminhub-cli.sh status     # Check if working
sudo ./scripts/adminhub-cli.sh update     # Update AdminHub & all dependencies
sudo ./scripts/adminhub-cli.sh uninstall  # Remove AdminHub
```

The `update` command automatically:
- Pulls latest AdminHub code from GitHub
- Updates Python to the latest version
- Updates Git, Homebrew, and pip
- Re-runs installation to apply changes

If status shows issues, check logs:
```bash
./scripts/adminhub-cli.sh logs error     # View error logs
```

## Architecture

- **Tools Location**: `/opt/admin-tools/`
- **Configuration**: `/etc/adminhub/adminhub.conf`
- **Logs**: `/var/log/adminhub/`
- **LaunchAgent**: `/Library/LaunchAgents/com.adminhub.guestsetup.plist`

## How It Works

1. Admin installs tools to `/opt/admin-tools/`
   - Python is installed from official python.org installer
   - Git is managed via Homebrew
2. Security wrappers prevent system modifications
3. LaunchAgent activates on Guest login
4. Tools added to Guest's PATH (including Python Framework directory)
5. pip configured with `break-system-packages=true` and `user=true`
6. All Guest changes stay in their home directory
7. Everything resets on Guest logout

## Security

AdminHub implements strict security for Guest users:

- **Blocked Operations**:
  - `brew install/uninstall` - No system packages
  - `sudo` commands - Completely disabled
  - System-wide installations - All blocked
  
- **Allowed Operations**:
  - `pip install numpy` - Auto-installs to ~/.local (user flag enforced)
  - `brew list` - View installed packages
  - `python script.py` - Run Python code
  - `git clone` - Work with repositories
  - `python -m venv myenv` - Create virtual environments

All Guest modifications are isolated to their session and automatically cleaned on logout.

For detailed security architecture and rationale, see [SECURITY.md](SECURITY.md).

## Key Features (v2.2.0+)

- **Official Python**: Uses python.org installer instead of Homebrew
- **Auto-updating**: Python automatically fetches latest stable version
- **Dynamic paths**: No hardcoded Python versions - adapts to installed version
- **One-command updates**: `sudo adminhub update` updates everything
- **pip configuration**: Pre-configured for Guest users (user-only installs)
- **Old Mac support**: Comprehensive repairs for systems 4+ years without updates

## Troubleshooting

- **Installation fails**: Check prerequisites and disk space
- **Status shows issues**: Check error logs with `adminhub logs error`
- **Python not found**: Ensure internet connection during installation
- **pip permission errors**: Should not occur - pip is pre-configured
- **Need more commands**: Run `adminhub --help`

## License

**SITE LICENSE** - © 2025 Luka Löhr. All rights reserved.

This software is licensed for use within authorized educational institutions only. 
Each school receives a site license that allows internal use and modification 
but prohibits sharing with other institutions.

**For licensing inquiries, contact: luka.loehr@example.com**

Created for Lessing-Gymnasium Karlsruhe.