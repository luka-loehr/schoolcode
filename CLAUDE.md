<!--
Copyright (c) 2025 Luka Löhr
-->

# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

SchoolCode is a macOS system administration tool that automatically provides developer tools (Python, Git, Homebrew) to Guest accounts on shared computers, primarily for educational environments. Version 2.1.0 adds comprehensive support for older Macs (4+ years without updates).

## Key Commands

### Installation & Management
```bash
# Install SchoolCode (requires sudo)
sudo ./scripts/SchoolCode-cli.sh install

# Check system status - all components should show "✅ HEALTHY"
sudo ./scripts/SchoolCode-cli.sh status

# Update to latest version from GitHub
./scripts/SchoolCode-cli.sh update

# View logs (error/info/debug)
./scripts/SchoolCode-cli.sh logs error
./scripts/SchoolCode-cli.sh logs info
./scripts/SchoolCode-cli.sh logs debug

# Monitor system health continuously
./scripts/SchoolCode-cli.sh monitor

# Fix permissions issues
sudo ./scripts/SchoolCode-cli.sh permissions fix

# Uninstall
sudo ./scripts/SchoolCode-cli.sh uninstall
```

### Development & Debugging
```bash
# Check old Mac compatibility
./scripts/utils/old_mac_compatibility.sh

# Run system repairs manually (for old Macs)
sudo ./scripts/utils/system_repair.sh

# Fix Homebrew issues
sudo ./scripts/utils/homebrew_repair.sh

# View detailed health report
sudo ./scripts/SchoolCode-cli.sh health detailed

# List available tools
./scripts/SchoolCode-cli.sh tools list

# Show configuration
./scripts/SchoolCode-cli.sh config show
```

### No Automated Tests
This project uses manual testing via the CLI status and health commands. There are no unit tests, integration tests, or linting commands.

## Architecture & Code Structure

### Core Components

1. **CLI Management System** (`scripts/SchoolCode-cli.sh`)
   - Central management interface for all SchoolCode operations (v2.1.0)
   - Bash 3.2 compatible (macOS default)
   - Modular command structure with subcommands
   - Commands: install, uninstall, update, status, health, logs, monitor, config, tools, permissions, guest

2. **Installation Pipeline**
   - `scripts/install_SchoolCode.sh`: Main installation orchestrator
     - Runs compatibility check for old Macs
     - Executes system repairs if needed
     - Repairs Homebrew before tool setup
     - Verifies symlink creation
   - `scripts/uninstall.sh`: Clean uninstallation process
   - `scripts/update_SchoolCode.sh`: GitHub-based update mechanism

3. **Old Mac Support** (v2.1.0)
   - `scripts/utils/old_mac_compatibility.sh`: System compatibility checker
     - Validates macOS version (10.14+)
     - Checks disk space, RAM, Ruby version
     - Generates compatibility report
   - `scripts/utils/system_repair.sh`: Automatic system fixes
     - Updates certificates
     - Fixes Git configuration
     - Repairs directory permissions
     - Cleans system caches
   - `scripts/utils/homebrew_repair.sh`: Comprehensive Homebrew fixes
     - Handles Ruby compatibility issues
     - Cleans legacy installations
     - Fixes OpenSSL conflicts
     - Creates Python symlinks

4. **Utility Modules** (`scripts/utils/`)
   - `logging.sh`: Centralized logging with rotation and severity levels
   - `config.sh`: Configuration management and validation
   - `monitoring.sh`: Health monitoring with old Mac awareness
   - `activate_tools.sh`: Tool activation for Guest users
   - `fix_homebrew_permissions.sh`: Homebrew permission management
   - All modules follow strict bash error handling (`set -euo pipefail`)

5. **Guest Setup Pipeline**
   - `launchagents/com.schoolcode.guestsetup.plist`: Triggers on Guest login
   - `scripts/setup/guest_login_setup.sh`: Main setup orchestrator
   - `scripts/setup/guest_tools_setup.sh`: Tool installation with improved symlink creation
   - `scripts/setup/setup_guest_shell_init.sh`: Shell environment configuration

### Important Paths
- Tool storage: `/opt/admin-tools/`
- Configuration: `/etc/schoolcode/schoolcode.conf`
- Logs: `/var/log/schoolcode/`
- LaunchAgent: `/Library/LaunchAgents/com.schoolcode.guestsetup.plist`

### Bash Compatibility
- **MUST** maintain compatibility with Bash 3.2 (macOS default)
- Avoid bash 4+ features (associative arrays, mapfile, etc.)
- Use POSIX-compliant constructs where possible
- Test on macOS with `/bin/bash --version` (should be 3.2.x)

### Error Handling Pattern
All scripts follow this pattern:
```bash
#!/bin/bash
set -euo pipefail  # Strict error handling

# Source utilities
source "$(dirname "$0")/utils/logging.sh"
source "$(dirname "$0")/utils/config.sh"

# Check prerequisites
check_sudo || exit 1
check_homebrew || exit 1

# Perform operations with extensive logging
log_info "Starting operation..."
# ... main logic ...

# Cleanup on exit (if needed)
trap cleanup EXIT
```

### Logging Standards
- Use `log_error`, `log_info`, `log_debug` from `logging.sh`
- Logs stored in `/var/log/schoolcode/` with automatic rotation
- Always log significant operations and state changes
- Include context in error messages

### Version Management
- Current version: 2.1.0
- Version string in `scripts/SchoolCode-cli.sh` (line 10)
- Git tags follow format: `v2.1.0`
- Update mechanism pulls from `main` branch

### Old Mac Considerations
When working on this codebase, consider:
- macOS versions back to 10.14 (Mojave)
- Ruby 2.3.x compatibility (use HOMEBREW_FORCE_VENDOR_RUBY)
- Limited system resources (4GB RAM minimum)
- Outdated certificates and Git configs
- Legacy Homebrew installations in various locations