<!--
Copyright (c) 2025 Luka Löhr
-->

# AI Agent Guide for SchoolCode

**Version**: 3.0.0  
**Target Platform**: macOS 10.14+ (Mojave and newer)  
**Primary Use Case**: Educational environments with shared Macs  

## 🎯 Quick Reference for AI Agents

### Essential Commands (Updated)
```bash
# Main Interface (RECOMMENDED)
sudo ./schoolcode.sh                    # Install everything
sudo ./schoolcode.sh --install          # Same as above (explicit)
sudo ./schoolcode.sh --uninstall        # Remove SchoolCode (no prompts)
sudo ./schoolcode.sh --interactive      # Compatibility alias for the main install flow
sudo ./schoolcode.sh --status           # Check system health
sudo ./schoolcode.sh --help             # Show help

# Advanced CLI (Legacy)
sudo ./scripts/schoolcode-cli.sh install-auto      # Legacy alias for install
sudo ./scripts/schoolcode-cli.sh install-interactive # Legacy alias for install
sudo ./scripts/schoolcode-cli.sh status detailed   # Detailed status
sudo ./scripts/schoolcode-cli.sh repair            # Fix system issues
sudo ./scripts/schoolcode-cli.sh uninstall         # Remove SchoolCode
sudo ./scripts/schoolcode-cli.sh logs error        # View error logs
```

### Key Files to Understand
- `schoolcode.sh` - Main entry point (NEW - use this first)
- `scripts/schoolcode-cli.sh` - CLI interface (legacy)
- `scripts/install.sh` - Core installation logic
- `system_repair.sh` - System repair functionality
- `old_mac_compatibility.sh` - Compatibility checking
- `scripts/utils/logging.sh` - Logging system
- `scripts/utils/ui.sh` - Shared Gum-backed terminal UI layer
- `scripts/utils/gum.sh` - Vendored Gum runtime resolver
- `vendor/gum/` - Pinned Gum binaries for macOS
- `scripts/setup/` - Guest account management

## 🏗️ Architecture Overview

### File Organization
```
SchoolCode/
├── schoolcode.sh                       # Main entry point (NEW)
├── scripts/
│   ├── schoolcode-cli.sh               # CLI interface (legacy)
│   ├── install.sh                      # Core installation
│   ├── uninstall.sh                    # Uninstall system
│   ├── utils/                          # Utility scripts
│   │   ├── logging.sh                  # Centralized logging
│   │   ├── config.sh                   # Configuration management
│   │   ├── ui.sh                       # Shared CLI presentation layer
│   │   ├── gum.sh                      # Vendored Gum resolver
│   │   ├── monitoring.sh               # System health monitoring
│   │   ├── homebrew_repair.sh          # Homebrew-specific repairs
│   │   ├── install_official_python.sh  # Python installation
│   │   └── python_utils.sh             # Python management
│   └── setup/                          # Guest account setup
│       ├── guest_login_setup.sh
│       ├── guest_tools_setup.sh
│       └── setup_guest_shell_init.sh
├── system_repair.sh                    # System repair utility
├── old_mac_compatibility.sh            # Compatibility checker
├── vendor/gum/                         # Pinned Gum binaries
└── tests/                              # Test suite
```

## 🚀 AI Agent Workflow

### 1. **Understanding the System**
```bash
# Start with main interface
./schoolcode.sh --help

# Check current status
sudo ./schoolcode.sh --status

# Understand installation process
sudo ./schoolcode.sh --interactive
```

### 2. **Making Changes**
```bash
# Test changes with dry-run (legacy alias still supported)
sudo ./scripts/schoolcode-cli.sh --dry-run install-auto

# Test in Guest account
sudo ./schoolcode.sh --install
# Then switch to Guest account and test

# Check system health after changes
sudo ./schoolcode.sh --status
```

### 3. **Debugging Issues**
```bash
# Check system health
sudo ./schoolcode.sh --status

# View error logs
sudo ./scripts/schoolcode-cli.sh logs error

# Run system repair
sudo ./scripts/schoolcode-cli.sh repair

# Check compatibility
./old_mac_compatibility.sh
```

## 🔧 Common Tasks for AI Agents

### Adding New Installation Components
1. Add to `scripts/install.sh` core installation logic
4. Update CLI commands in `scripts/schoolcode-cli.sh`
5. Test both installation modes
6. Update documentation

### Fixing System Issues
1. Add repair logic to `system_repair.sh`
2. Test repair function independently
3. Integrate into installation flow
4. Add CLI command for manual repair
5. Update troubleshooting documentation

### Adding New CLI Commands
1. Add command function to `scripts/schoolcode-cli.sh`
2. Add to help text and examples
3. Add to main command dispatcher
4. Test command functionality
5. Update README.md with new command

## 🛡️ Security Guidelines

### Core Security Principles
- **Guest Account Isolation**: All changes must be temporary and isolated to Guest accounts
- **No System Modification**: Never modify system-level configurations
- **Temporary Changes**: All modifications must be reversible
- **Cleanup on Logout**: Ensure all changes are removed when Guest account logs out
- Prefer macOS account isolation and normal filesystem permissions over custom blocking wrappers unless there is a real privilege gap to close.

### Security Implementation
```bash
# Secure file creation
touch /tmp/schoolcode_secure_file
chmod 600 /tmp/schoolcode_secure_file
chown guest:staff /tmp/schoolcode_secure_file

# Validate user context
if [ "$(whoami)" != "guest" ]; then
    echo "Error: Must run as guest user"
    exit 1
fi
```

## 🧪 Testing Framework

### Test Commands
```bash
# Run shell script tests
./tests/test_installation.sh

# Test installation modes
sudo ./schoolcode.sh --install
sudo ./schoolcode.sh --interactive

# Test uninstall
sudo ./schoolcode.sh --uninstall
```

### Test Categories
- **Functional Tests**: Installation modes, system repair, guest setup
- **Security Tests**: Guest account isolation, permission management
- **Compatibility Tests**: macOS version compatibility, architecture support
- **Error Handling Tests**: Network failures, permission issues, recovery

## 📊 Monitoring & Health Checks

### Health Check Components
- **schoolcode_tools**: ✅ HEALTHY / ⚠️ DEGRADED / ❌ UNHEALTHY
- **guest_setup**: ✅ HEALTHY / ⚠️ DEGRADED / ❌ UNHEALTHY  
- **launchagent**: ✅ HEALTHY / ⚠️ DEGRADED / ❌ UNHEALTHY
- **homebrew**: ✅ HEALTHY / ⚠️ DEGRADED / ❌ UNHEALTHY
- **permissions**: ✅ HEALTHY / ⚠️ DEGRADED / ❌ UNHEALTHY
- **disk_space**: ✅ HEALTHY / ⚠️ DEGRADED / ❌ UNHEALTHY

### Monitoring Commands
```bash
# Basic health check
sudo ./schoolcode.sh --status

# Detailed health check
sudo ./scripts/schoolcode-cli.sh status detailed

# JSON output for parsing
sudo ./scripts/schoolcode-cli.sh status json

# Monitor continuously
sudo ./scripts/schoolcode-cli.sh monitor 30
```

## 🔍 Debugging Guide

### Common Issues & Solutions

#### Installation Failures
```bash
# Check compatibility
./old_mac_compatibility.sh

# Run system repair
sudo ./scripts/schoolcode-cli.sh repair

# Check logs
sudo ./scripts/schoolcode-cli.sh logs error
```

#### Guest Account Issues
```bash
# Check guest setup
sudo ./scripts/schoolcode-cli.sh guest status

# Test guest environment
sudo ./scripts/schoolcode-cli.sh guest test

# Cleanup guest tools
sudo ./scripts/schoolcode-cli.sh guest cleanup
```

#### Homebrew Issues
```bash
# Repair Homebrew
sudo ./scripts/utils/homebrew_repair.sh

# Fix permissions
sudo ./scripts/utils/fix_homebrew_permissions.sh

# Check Homebrew status
brew doctor
```

### Log Locations
- **Main logs**: `/var/log/schoolcode/schoolcode.log`
- **Error logs**: `/var/log/schoolcode/schoolcode-error.log`
- **Guest logs**: `/var/log/schoolcode/guest-setup.log`
- **Installation logs**: `/var/log/schoolcode/install_YYYYMMDD_HHMMSS.log`

## 📝 Development Best Practices

### Code Style
- Use `set -euo pipefail` for strict error handling
- Use `BASH_SOURCE[0]` instead of `$0` for script path detection
- Implement proper return codes and error propagation
- Use centralized logging system (`scripts/utils/logging.sh`)

### Error Handling
```bash
# Proper error handling pattern
if ! command -v tool &>/dev/null; then
    log_error "Tool not found: tool"
    return 1
fi

# With cleanup
cleanup() {
    rm -f /tmp/temp_file
    log_info "Cleanup completed"
}
trap cleanup EXIT
```

### Path Construction
```bash
# Robust path detection
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# Dynamic path construction
if [[ -d "/opt/homebrew/bin" ]]; then
    export PATH="/opt/homebrew/bin:$PATH"
fi
```

## 🎯 AI Agent Quick Actions

### When User Reports Issues
1. **Check Status**: `sudo ./schoolcode.sh --status`
2. **View Logs**: `sudo ./scripts/schoolcode-cli.sh logs error`
3. **Run Repair**: `sudo ./scripts/schoolcode-cli.sh repair`
4. **Test Installation**: `sudo ./schoolcode.sh --install`

### When Adding Features
1. **Understand Current**: Read relevant scripts
2. **Test Changes**: Use dry-run and Guest account testing
3. **Update Documentation**: Update README.md and agents.md
4. **Commit Changes**: Use descriptive commit messages

### When Debugging
1. **Check Health**: `sudo ./schoolcode.sh --status`
2. **View Logs**: `sudo ./scripts/schoolcode-cli.sh logs`
3. **Run Compatibility**: `./old_mac_compatibility.sh`
4. **Test Components**: Individual script testing

## 📚 Additional Resources

- **SECURITY.md**: Detailed security architecture
- **docs/INSTALLATION.md**: Comprehensive installation guide
- **tests/**: Test suite for validation
- **scripts/utils/**: Utility functions and helpers

## 🚨 Critical Rules for AI Agents

1. **Always test in Guest account** after making changes
2. **Never modify system files** (`/etc`, `/usr`, `/System`, `/Library`)
3. **Use centralized logging** for all operations
4. **Implement proper cleanup** for temporary files
5. **Validate permissions** before file operations
6. **Test both installation modes** (automatic and interactive)
7. **Check system health** after modifications
8. **Use `--force` flag** for non-interactive operations when needed

---

**Remember**: SchoolCode is designed for educational environments. Always prioritize security, isolation, and ease of use for students.
