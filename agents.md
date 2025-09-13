<!--
Copyright (c) 2025 Luka Löhr
-->

# agents.md

This file provides comprehensive guidance to AI agents when working with code in this repository.

## Project Overview

SchoolCode is an automated development tools installer for macOS Guest accounts. It provides a safe, experimental development environment for students on shared macOS machines by automatically deploying essential developer tools to Guest accounts.

**Version**: 3.0.0  
**Target Platform**: macOS 10.14+ (Mojave and newer)  
**Primary Use Case**: Educational environments with shared Macs  

## Technology Stack

- **Shell Scripting**: Bash 3.2+ compatible scripts for automation and system management
- **macOS**: Designed specifically for macOS Guest account environments
- **Homebrew**: Package manager for installing development tools
- **Python**: Official Python from python.org (not Homebrew Python)
- **Git**: Version control system setup via Xcode Command Line Tools
- **Security**: Guest account isolation and temporary modifications
- **Compatibility**: Old Mac support with compatibility checking and system repair

## Development Workflow

### Running Locally
1. Clone the repository
2. Choose installation mode (interactive or automatic)
3. Run installation with sudo privileges
4. Test in a Guest account environment

### Making Changes
1. Edit shell scripts and configuration files
2. Test changes in a Guest account
3. Update documentation if needed
4. Commit changes to Git
5. Push to GitHub

### Installation Modes

#### Interactive Mode (Recommended for Development)
```bash
# Choose what to install
sudo ./setup.sh --interactive
# OR
sudo ./scripts/schoolcode-cli.sh install-interactive
```

#### Automatic Mode (Quick Setup)
```bash
# Install everything automatically
sudo ./setup.sh --auto
# OR
sudo ./scripts/schoolcode-cli.sh install-auto
```

### Key Commands (CLI v2.1.0)

#### Installation Commands
```bash
# Interactive installation (recommended for development)
sudo ./scripts/schoolcode-cli.sh install-interactive

# Automatic installation (production deployment)
sudo ./scripts/schoolcode-cli.sh install-auto

# Guest account setup only
sudo ./scripts/schoolcode-cli.sh guest-setup

# Legacy installation methods
sudo ./setup.sh --interactive
sudo ./setup.sh --auto
```

#### System Management Commands
```bash
# System health and status
sudo ./scripts/schoolcode-cli.sh status               # Basic status
sudo ./scripts/schoolcode-cli.sh status detailed     # Comprehensive status
sudo ./scripts/schoolcode-cli.sh compatibility        # Compatibility check
sudo ./scripts/schoolcode-cli.sh repair               # System repair

# Component management
sudo ./scripts/schoolcode-cli.sh check python        # Check Python installation
sudo ./scripts/schoolcode-cli.sh check homebrew       # Check Homebrew status
sudo ./scripts/schoolcode-cli.sh check git            # Check Git configuration
```

#### Updates & Maintenance Commands
```bash
# Update operations
sudo ./scripts/schoolcode-cli.sh update               # Update everything
sudo ./scripts/schoolcode-cli.sh update dependencies  # Update dependencies only
sudo ./scripts/schoolcode-cli.sh update schoolcode     # Update SchoolCode only

# Maintenance
sudo ./scripts/schoolcode-cli.sh uninstall           # Remove SchoolCode
sudo ./scripts/schoolcode-cli.sh cleanup             # Clean temporary files
```

#### Debugging & Logging Commands
```bash
# Log viewing
sudo ./scripts/schoolcode-cli.sh logs                # View all logs
sudo ./scripts/schoolcode-cli.sh logs error           # View error logs only
sudo ./scripts/schoolcode-cli.sh logs guest           # View guest setup logs
sudo ./scripts/schoolcode-cli.sh logs install         # View installation logs

# Debug mode
sudo ./scripts/schoolcode-cli.sh --verbose install-interactive
sudo ./scripts/schoolcode-cli.sh --dry-run install-auto
```

#### Advanced Commands
```bash
# Force operations
sudo ./scripts/schoolcode-cli.sh --force repair
sudo ./scripts/schoolcode-cli.sh --force install-auto

# Skip repair during installation
sudo ./scripts/schoolcode-cli.sh --no-repair install-auto

# Help and information
sudo ./scripts/schoolcode-cli.sh help                 # Show help
sudo ./scripts/schoolcode-cli.sh version              # Show version info
```

## Architecture & Structure

### File Organization
```
SchoolCode/
├── docs/                           # Documentation
│   └── INSTALLATION.md             # Detailed installation guide
├── scripts/                        # Core scripts
│   ├── schoolcode-cli.sh           # Main CLI interface (v2.1.0)
│   ├── setup.sh                    # Installation mode launcher
│   ├── install.sh                  # Core installation script
│   ├── install_auto.sh             # Automatic installation
│   ├── install_interactive.sh      # Interactive installation
│   ├── guest_setup_auto.sh         # Guest account automation
│   ├── update.sh                   # Update system
│   ├── uninstall.sh                # Uninstall system
│   ├── utils/                      # Utility scripts
│   │   ├── logging.sh              # Centralized logging system
│   │   ├── config.sh               # Configuration management
│   │   ├── monitoring.sh           # System health monitoring
│   │   ├── fix_homebrew_permissions.sh
│   │   ├── homebrew_repair.sh      # Homebrew-specific repairs
│   │   ├── install_official_python.sh
│   │   ├── python_utils.sh         # Python management utilities
│   │   └── update_dependencies.sh  # Dependency updates
│   └── setup/                      # Guest account setup
│       ├── guest_login_setup.sh
│       ├── guest_tools_setup.sh
│       └── setup_guest_shell_init.sh
├── SchoolCode_launchagents/        # macOS LaunchAgents
│   └── com.SchoolCode.guestsetup.plist
├── tests/                          # Test suite
│   └── test_installation.sh        # Installation tests
├── system_repair.sh                # System repair utility
├── old_mac_compatibility.sh        # Compatibility checker
├── test_schoolcode.py              # Python test suite
├── README.md                       # User documentation
├── agents.md                       # AI agent guidance (this file)
├── SECURITY.md                     # Security documentation
├── LICENSE                         # Apache 2.0 license
└── version.txt                     # Version information (3.0.0)
```

### Key Components

1. **Installation System**: 
   - `setup.sh` - Mode launcher (interactive/automatic)
   - `install_auto.sh` - One-time automatic setup
   - `install_interactive.sh` - Component selection interface
   - `install.sh` - Core installation logic

2. **Compatibility & Repair**:
   - `old_mac_compatibility.sh` - System compatibility checking
   - `system_repair.sh` - System issue repair utility

3. **CLI Interface**: 
   - `schoolcode-cli.sh` - Main command-line interface
   - Supports all installation modes and system management

4. **Guest Account Management**:
   - `scripts/setup/` - Guest environment configuration
   - Security wrappers and isolation

5. **Utilities**:
   - `scripts/utils/` - Logging, monitoring, configuration
   - Centralized error handling and system health checks

## Important Development Notes

1. **Security First**: All modifications must be temporary and isolated to Guest accounts
2. **Guest Account Focus**: Designed specifically for educational environments
3. **Zero Maintenance**: Students should not need to maintain the system
4. **Tool Isolation**: Each tool should be independently manageable
5. **Cleanup**: All changes must be reversible and temporary
6. **Compatibility**: Always check macOS version compatibility before making changes
7. **Error Handling**: Use centralized logging system for all scripts

## AI Agent Guidelines

### Modern AI Agent Workflow

#### 1. **Code Analysis & Understanding**
- **Start with `codebase_search`**: Use semantic search to understand the system architecture and component relationships
- **Read key files first**: Always examine `scripts/schoolcode-cli.sh`, `scripts/install.sh`, and `system_repair.sh` before making changes
- **Use `grep` strategically**: Search for specific patterns, function definitions, and error handling across the codebase
- **Check dependencies**: Understand how scripts interact with each other through `source` statements and function calls

#### 2. **Compatibility & System Requirements**
- **Always run compatibility check first**: `./old_mac_compatibility.sh` before any modifications
- **Test on multiple macOS versions**: Ensure changes work on macOS 10.14+ (Mojave) through current versions
- **Consider architecture differences**: Test on both Intel and Apple Silicon Macs
- **Validate system requirements**: Check for Homebrew, Xcode CLT, and other dependencies

#### 3. **Security-First Development**
- **Never modify system-level configurations**: All changes must be temporary and isolated
- **Use Guest account isolation**: All user-facing features must work within Guest account constraints
- **Implement proper cleanup**: Ensure all modifications are reversible and temporary
- **Follow principle of least privilege**: Use minimal required permissions for all operations

#### 4. **Error Handling & Logging**
- **Use centralized logging**: Always use `scripts/utils/logging.sh` for consistent error reporting
- **Implement proper error propagation**: Use `set -euo pipefail` and proper return codes
- **Provide clear error messages**: Include actionable guidance for users when errors occur
- **Log all significant operations**: Track installation steps, repairs, and system changes

#### 5. **Testing & Validation**
- **Test in fresh Guest account**: Always validate changes in a clean Guest account environment
- **Verify all installation modes**: Test both interactive and automatic installation flows
- **Run comprehensive tests**: Use both shell script tests (`tests/test_installation.sh`) and Python tests (`test_schoolcode.py`)
- **Test error conditions**: Validate error handling and recovery mechanisms
- **Check cleanup functionality**: Ensure proper cleanup on logout and uninstall

### AI Agent Tool Usage Patterns

#### Code Analysis Workflow
```bash
# 1. Understand the system architecture
codebase_search("How does the installation system work?", [])

# 2. Find specific functionality
grep("function.*install", "scripts/")

# 3. Examine error handling patterns
grep("set -euo pipefail", "scripts/")

# 4. Check for security measures
grep("sudo.*guest", "scripts/")
```

#### Testing Workflow
```bash
# 1. Run compatibility check
run_terminal_cmd("./old_mac_compatibility.sh")

# 2. Test installation modes
run_terminal_cmd("sudo ./scripts/schoolcode-cli.sh install-interactive")

# 3. Check system status
run_terminal_cmd("sudo ./scripts/schoolcode-cli.sh status detailed")

# 4. Run test suite
run_terminal_cmd("python3 test_schoolcode.py")
```

#### Debugging Workflow
```bash
# 1. Check logs for errors
run_terminal_cmd("sudo ./scripts/schoolcode-cli.sh logs error")

# 2. Examine system health
run_terminal_cmd("sudo ./scripts/schoolcode-cli.sh status")

# 3. Run system repair if needed
run_terminal_cmd("sudo ./scripts/schoolcode-cli.sh repair")

# 4. Test specific components
run_terminal_cmd("sudo ./scripts/schoolcode-cli.sh compatibility")
```

### Common Tasks for AI Agents

#### Adding New Installation Components
1. Add to `install.sh` core installation logic
2. Update `install_auto.sh` to include new component
3. Add option to `install_interactive.sh` menu
4. Update CLI commands in `schoolcode-cli.sh`
5. Test both installation modes
6. Update documentation

#### Fixing System Issues
1. Add repair logic to `system_repair.sh`
2. Test repair function independently
3. Integrate into installation flow
4. Add CLI command for manual repair
5. Update troubleshooting documentation

#### Adding New CLI Commands
1. Add command function to `schoolcode-cli.sh`
2. Add to help text and examples
3. Add to main command dispatcher
4. Test command functionality
5. Update README.md with new command

### File Modification Guidelines

#### Scripts to Modify Carefully
- `system_repair.sh` - Critical for system functionality
- `old_mac_compatibility.sh` - Required for installation
- `scripts/schoolcode-cli.sh` - Main user interface
- `scripts/install.sh` - Core installation logic

#### Safe to Modify
- `scripts/install_interactive.sh` - User interface only
- `scripts/install_auto.sh` - Wrapper script
- Documentation files (README.md, agents.md)
- Utility scripts in `scripts/utils/`

### Debugging Tips for AI Agents

#### Check System Status
```bash
# Full system status
sudo ./scripts/schoolcode-cli.sh status detailed

# Compatibility check
sudo ./scripts/schoolcode-cli.sh compatibility

# System repair
sudo ./scripts/schoolcode-cli.sh repair
```

#### View Logs
```bash
# All logs
sudo ./scripts/schoolcode-cli.sh logs

# Error logs only
sudo ./scripts/schoolcode-cli.sh logs error

# Guest setup logs
sudo ./scripts/schoolcode-cli.sh logs guest
```

#### Test Installation Modes
```bash
# Test interactive mode
sudo ./scripts/schoolcode-cli.sh install-interactive

# Test automatic mode
sudo ./scripts/schoolcode-cli.sh install-auto

# Test with options
sudo ./scripts/schoolcode-cli.sh install-auto --no-repair
```

## Installation Flow Architecture

### Interactive Installation Flow
```
1. User runs: sudo ./setup.sh --interactive
2. Launches: scripts/install_interactive.sh
3. Shows menu with options:
   - Compatibility Check
   - System Repair
   - Install Tools
   - Setup Guest Account
   - Install Everything (runs 1-4)
4. User selects components to install
5. Each component runs independently
```

### Automatic Installation Flow
```
1. User runs: sudo ./setup.sh --auto
2. Launches: scripts/install_auto.sh
3. Runs in sequence:
   - Compatibility Check (required)
   - System Repair (optional, configurable)
   - Install Tools (required)
   - Setup Guest Account (required)
4. Minimal user interaction
```

### Core Installation Logic
```
scripts/install.sh:
- Integrates compatibility checker
- Installs Python (official from python.org)
- Installs Homebrew
- Sets up tool symlinks
- Creates security wrappers
- Configures Guest environment
```

## Security Guidelines for AI Agents

### Core Security Principles

#### **Guest Account Isolation**
- **Temporary modifications only**: All changes must be reversible and isolated to Guest accounts
- **No system-level changes**: Never modify system configurations, preferences, or core system files
- **Session-based isolation**: Changes should only persist for the current Guest session
- **Cleanup on logout**: Ensure all modifications are removed when Guest account logs out

#### **Permission Management**
- **Principle of least privilege**: Use minimal required permissions for all operations
- **Validate permissions**: Always check permissions before performing operations
- **Secure file operations**: Use appropriate file permissions and ownership
- **Avoid world-writable files**: Never create files with overly permissive permissions

#### **System Integrity Protection**
- **No system modification**: Never edit system-level configurations or preferences
- **Security wrappers**: All tools must be wrapped to prevent system modification
- **Temporary directories**: Use `/tmp` or user-specific temporary directories
- **Isolated environments**: Ensure tools run in isolated environments

### Security Implementation Guidelines

#### **File System Security**
```bash
# Secure file creation
touch /tmp/schoolcode_secure_file
chmod 600 /tmp/schoolcode_secure_file
chown guest:staff /tmp/schoolcode_secure_file

# Secure directory creation
mkdir -p /tmp/schoolcode_secure_dir
chmod 700 /tmp/schoolcode_secure_dir
chown guest:staff /tmp/schoolcode_secure_dir
```

#### **Process Security**
```bash
# Run with minimal privileges
sudo -u guest command

# Validate user context
if [ "$(whoami)" != "guest" ]; then
    echo "Error: Must run as guest user"
    exit 1
fi

# Check for security violations
if [ -w "/etc" ] || [ -w "/usr" ] || [ -w "/System" ]; then
    echo "Error: Dangerous write permissions detected"
    exit 1
fi
```

#### **Network Security**
```bash
# Validate SSL certificates
curl --cacert /etc/ssl/cert.pem https://example.com

# Use secure protocols only
# Avoid HTTP, use HTTPS
# Validate download integrity with checksums
```

### Security Wrapper Implementation

#### **Tool Wrapper Template**
```bash
#!/bin/bash
# Security wrapper for [TOOL_NAME]
# Prevents system modification while allowing normal usage

set -euo pipefail

# Security checks
check_security() {
    # Prevent system modification
    if [[ "$1" =~ ^(/etc|/usr|/System|/Library) ]]; then
        echo "Error: System modification not allowed in Guest account"
        exit 1
    fi
    
    # Validate permissions
    if [ ! -w "$(dirname "$1")" ]; then
        echo "Error: Insufficient permissions"
        exit 1
    fi
}

# Main tool execution
main() {
    # Security validation
    for arg in "$@"; do
        check_security "$arg"
    done
    
    # Execute original tool with security constraints
    exec /usr/local/bin/original_tool "$@"
}

main "$@"
```

### Security Testing Requirements

#### **Security Validation Tests**
- **Permission testing**: Verify tools cannot modify system files
- **Isolation testing**: Ensure Guest account isolation is maintained
- **Cleanup testing**: Validate all temporary files are removed
- **Wrapper testing**: Test security wrappers prevent unauthorized access

#### **Security Audit Checklist**
- [ ] All modifications are temporary and reversible
- [ ] No system-level configurations are modified
- [ ] Guest account isolation is maintained
- [ ] Security wrappers are properly implemented
- [ ] File permissions are appropriate
- [ ] Cleanup scripts function correctly
- [ ] Network operations use secure protocols
- [ ] Error handling doesn't expose sensitive information

### Common Security Mistakes to Avoid

#### **File System Mistakes**
- **Modifying system directories**: Never write to `/etc`, `/usr`, `/System`, or `/Library`
- **Creating world-writable files**: Avoid `chmod 777` or similar overly permissive permissions
- **Hardcoding system paths**: Use dynamic path resolution for portability
- **Ignoring file ownership**: Ensure proper ownership of created files

#### **Process Security Mistakes**
- **Running as root unnecessarily**: Use minimal required privileges
- **Ignoring user context**: Always validate the user context before operations
- **Skipping permission checks**: Always validate permissions before file operations
- **Not validating input**: Sanitize all user input and command arguments

#### **Network Security Mistakes**
- **Using insecure protocols**: Always use HTTPS, never HTTP
- **Ignoring certificate validation**: Always validate SSL certificates
- **Not verifying downloads**: Always verify download integrity with checksums
- **Exposing sensitive data**: Never log or expose sensitive information

### Security Monitoring

#### **Security Logging**
```bash
# Log security events
log_security_event() {
    local event="$1"
    local details="$2"
    echo "$(date): SECURITY: $event - $details" >> /var/log/schoolcode/security.log
}

# Monitor for security violations
monitor_security() {
    # Check for unauthorized system modifications
    if [ -w "/etc" ] || [ -w "/usr" ] || [ -w "/System" ]; then
        log_security_event "DANGEROUS_PERMISSIONS" "System directories writable"
        return 1
    fi
    
    # Check for security wrapper integrity
    if [ ! -f "/usr/local/bin/tool_wrapper" ]; then
        log_security_event "WRAPPER_MISSING" "Security wrapper not found"
        return 1
    fi
}
```

#### **Security Incident Response**
1. **Immediate isolation**: Stop all operations if security violation detected
2. **Log the incident**: Record all details in security log
3. **Assess impact**: Determine scope of potential security issue
4. **Implement fix**: Address the security vulnerability
5. **Verify resolution**: Test that security issue is resolved
6. **Document lessons learned**: Update security guidelines based on incident

## Code Style Guidelines

- Use clear, descriptive variable names
- Add comprehensive error handling with centralized logging
- Include detailed logging for debugging
- Follow shell scripting best practices (Bash 3.2+ compatible)
- Comment complex logic and security measures
- Use `set -euo pipefail` for strict error handling
- Implement proper return codes and error propagation

## Architecture Diagrams

### System Architecture Overview
```
┌─────────────────────────────────────────────────────────────┐
│                    SchoolCode Architecture                   │
├─────────────────────────────────────────────────────────────┤
│  User Interface Layer                                       │
│  ├── CLI Interface (schoolcode-cli.sh)                     │
│  ├── Interactive Mode (install_interactive.sh)             │
│  └── Automatic Mode (install_auto.sh)                      │
├─────────────────────────────────────────────────────────────┤
│  Core Installation Layer                                   │
│  ├── Installation Engine (install.sh)                      │
│  ├── Compatibility Checker (old_mac_compatibility.sh)     │
│  └── System Repair (system_repair.sh)                      │
├─────────────────────────────────────────────────────────────┤
│  Guest Account Management                                   │
│  ├── Guest Setup (guest_setup_auto.sh)                    │
│  ├── Login Configuration (guest_login_setup.sh)           │
│  ├── Tools Setup (guest_tools_setup.sh)                   │
│  └── Shell Initialization (setup_guest_shell_init.sh)     │
├─────────────────────────────────────────────────────────────┤
│  Utility Layer                                             │
│  ├── Logging System (logging.sh)                          │
│  ├── Configuration Management (config.sh)                 │
│  ├── System Monitoring (monitoring.sh)                    │
│  ├── Python Utilities (python_utils.sh)                  │
│  └── Homebrew Management (homebrew_repair.sh)              │
├─────────────────────────────────────────────────────────────┤
│  Security Layer                                            │
│  ├── Security Wrappers                                     │
│  ├── Permission Management                                 │
│  ├── Guest Account Isolation                               │
│  └── Cleanup Scripts                                       │
└─────────────────────────────────────────────────────────────┘
```

### Installation Flow Diagram
```
┌─────────────────┐    ┌──────────────────┐    ┌─────────────────┐
│   User Input    │───▶│   Mode Selection  │───▶│  Compatibility  │
│                 │    │                  │    │     Check       │
└─────────────────┘    └──────────────────┘    └─────────────────┘
                                                         │
                                                         ▼
┌─────────────────┐    ┌──────────────────┐    ┌─────────────────┐
│   Installation  │◀───│  System Repair   │◀───│   Validation    │
│   Execution     │    │   (if needed)    │    │                 │
└─────────────────┘    └──────────────────┘    └─────────────────┘
         │
         ▼
┌─────────────────┐    ┌──────────────────┐    ┌─────────────────┐
│  Guest Account  │───▶│   Tool Setup     │───▶│   Verification  │
│     Setup       │    │                  │    │                 │
└─────────────────┘    └──────────────────┘    └─────────────────┘
```

### Security Architecture
```
┌─────────────────────────────────────────────────────────────┐
│                    Security Architecture                     │
├─────────────────────────────────────────────────────────────┤
│  Guest Account Environment                                  │
│  ├── Isolated File System Access                           │
│  ├── Temporary Directory Usage                             │
│  ├── Limited System Access                                 │
│  └── Session-Based Modifications                           │
├─────────────────────────────────────────────────────────────┤
│  Security Wrappers                                          │
│  ├── Tool Execution Monitoring                             │
│  ├── System Modification Prevention                       │
│  ├── Permission Validation                                 │
│  └── Access Control Enforcement                            │
├─────────────────────────────────────────────────────────────┤
│  System Protection                                          │
│  ├── No System-Level Changes                               │
│  ├── Reversible Modifications                              │
│  ├── Cleanup on Logout                                     │
│  └── Integrity Monitoring                                  │
└─────────────────────────────────────────────────────────────┘
```

## Quick Reference for AI Agents

### Essential Commands
```bash
# System Status
sudo ./scripts/schoolcode-cli.sh status detailed

# Compatibility Check
./old_mac_compatibility.sh

# System Repair
sudo ./scripts/schoolcode-cli.sh repair

# Installation (Interactive)
sudo ./scripts/schoolcode-cli.sh install-interactive

# Installation (Automatic)
sudo ./scripts/schoolcode-cli.sh install-auto

# Testing
python3 test_schoolcode.py
./tests/test_installation.sh

# Logging
sudo ./scripts/schoolcode-cli.sh logs error
```

### Key Files to Understand
- `scripts/schoolcode-cli.sh` - Main CLI interface
- `scripts/install.sh` - Core installation logic
- `system_repair.sh` - System repair functionality
- `old_mac_compatibility.sh` - Compatibility checking
- `scripts/utils/logging.sh` - Logging system
- `scripts/setup/` - Guest account management

### Critical Security Rules
1. **Never modify system files** (`/etc`, `/usr`, `/System`, `/Library`)
2. **All changes must be temporary** and reversible
3. **Use Guest account isolation** for all user-facing features
4. **Implement proper cleanup** on logout
5. **Validate permissions** before all operations
6. **Use security wrappers** for all tools
7. **Test in Guest account** environment

### Development Workflow
1. **Understand**: Use `codebase_search` to understand architecture
2. **Plan**: Create todo list for complex changes
3. **Test**: Run compatibility check and existing tests
4. **Develop**: Make changes with proper error handling
5. **Validate**: Test in Guest account environment
6. **Document**: Update relevant documentation
7. **Deploy**: Commit and push changes

## Testing Framework

### Test Suite Overview

SchoolCode includes a comprehensive testing framework with both shell script and Python test suites:

#### Python Test Suite (`test_schoolcode.py`)
- **Unit tests**: Individual component testing
- **Integration tests**: End-to-end workflow testing
- **Compatibility tests**: Cross-platform validation
- **Security tests**: Guest account isolation validation

#### Shell Script Tests (`tests/test_installation.sh`)
- **Installation flow tests**: Both interactive and automatic modes
- **System repair tests**: Error condition handling
- **Cleanup tests**: Temporary file and configuration cleanup
- **Permission tests**: Security wrapper validation

### Testing Workflow for AI Agents

#### 1. **Pre-Change Testing**
```bash
# Run full test suite before making changes
python3 test_schoolcode.py
./tests/test_installation.sh

# Check system compatibility
./old_mac_compatibility.sh

# Verify current system status
sudo ./scripts/schoolcode-cli.sh status detailed
```

#### 2. **Component-Specific Testing**
```bash
# Test installation components
sudo ./scripts/schoolcode-cli.sh install-interactive
sudo ./scripts/schoolcode-cli.sh install-auto

# Test system repair
sudo ./scripts/schoolcode-cli.sh repair

# Test guest account setup
sudo ./scripts/schoolcode-cli.sh guest-setup
```

#### 3. **Error Condition Testing**
```bash
# Test with invalid permissions
sudo ./scripts/schoolcode-cli.sh --dry-run install-auto

# Test with missing dependencies
sudo ./scripts/schoolcode-cli.sh compatibility

# Test cleanup functionality
sudo ./scripts/schoolcode-cli.sh cleanup
```

#### 4. **Guest Account Testing**
```bash
# Switch to Guest account and test
# (Manual step - AI agents should document this requirement)
sudo ./scripts/schoolcode-cli.sh guest-setup
# Then test tools in Guest account environment
```

### Test Categories

#### **Functional Tests**
- Installation modes (interactive/automatic)
- System repair functionality
- Guest account setup
- Tool installation and configuration
- Update mechanisms

#### **Security Tests**
- Guest account isolation
- Permission management
- Temporary file cleanup
- Security wrapper functionality
- System integrity preservation

#### **Compatibility Tests**
- macOS version compatibility (10.14+)
- Architecture compatibility (Intel/Apple Silicon)
- Dependency validation
- System requirement checking

#### **Error Handling Tests**
- Network failure scenarios
- Permission denied conditions
- Disk space limitations
- Corrupted installation states
- Recovery mechanisms

### Test Data and Fixtures

#### **Test Environments**
- Fresh macOS installations
- Various macOS versions (10.14+)
- Both Intel and Apple Silicon architectures
- Different system configurations
- Guest account environments

#### **Test Scenarios**
- Clean installation
- Partial installation recovery
- Update scenarios
- Uninstall and cleanup
- Error condition recovery

### Continuous Testing

#### **Automated Test Triggers**
- Pre-commit hooks for basic validation
- CI/CD pipeline for comprehensive testing
- Regular compatibility testing
- Security audit testing

#### **Manual Testing Requirements**
- Guest account functionality validation
- Cross-platform compatibility testing
- User experience testing
- Performance testing under load

## Deployment

- Changes are deployed via Git
- No build process required
- Installation scripts handle all setup
- Updates are managed through the CLI
- Version information in `version.txt`

## Troubleshooting & Debugging

### Common Issues & Solutions

#### **Installation Failures**
- **Compatibility failures**: Check `/tmp/schoolcode_compatibility_report.txt`
- **Permission issues**: Ensure running with `sudo` and check file permissions
- **Network failures**: Verify internet connection and proxy settings
- **Disk space**: Ensure at least 5GB free space available
- **Homebrew conflicts**: Run `sudo ./scripts/schoolcode-cli.sh repair`

#### **System Issues**
- **System repair needed**: Run `sudo ./scripts/schoolcode-cli.sh repair`
- **Xcode CLT missing**: Install via `xcode-select --install`
- **Certificate issues**: Run system repair to fix certificate problems
- **PATH corruption**: System repair will restore proper PATH configuration

#### **Guest Account Issues**
- **Guest account disabled**: Enable in System Preferences > Users & Groups
- **Permission denied**: Check Guest account permissions and security settings
- **Tool access issues**: Verify security wrappers are properly installed
- **Cleanup failures**: Check cleanup scripts and temporary file permissions

### Advanced Debugging Techniques

#### **Systematic Debugging Approach**
```bash
# 1. Check overall system health
sudo ./scripts/schoolcode-cli.sh status detailed

# 2. Run compatibility check
sudo ./scripts/schoolcode-cli.sh compatibility

# 3. Check specific components
sudo ./scripts/schoolcode-cli.sh check python
sudo ./scripts/schoolcode-cli.sh check homebrew
sudo ./scripts/schoolcode-cli.sh check git

# 4. Examine logs for errors
sudo ./scripts/schoolcode-cli.sh logs error
sudo ./scripts/schoolcode-cli.sh logs guest
sudo ./scripts/schoolcode-cli.sh logs install

# 5. Run system repair if needed
sudo ./scripts/schoolcode-cli.sh repair

# 6. Test installation modes
sudo ./scripts/schoolcode-cli.sh --dry-run install-auto
sudo ./scripts/schoolcode-cli.sh install-interactive
```

#### **Verbose Debugging**
```bash
# Enable verbose output for detailed debugging
sudo ./scripts/schoolcode-cli.sh --verbose install-interactive

# Dry run to test without making changes
sudo ./scripts/schoolcode-cli.sh --dry-run install-auto

# Force operations when needed
sudo ./scripts/schoolcode-cli.sh --force repair
```

#### **Log Analysis**
```bash
# View all logs with timestamps
sudo ./scripts/schoolcode-cli.sh logs | tail -50

# Filter for specific errors
sudo ./scripts/schoolcode-cli.sh logs error | grep -i "failed\|error"

# Check guest account setup logs
sudo ./scripts/schoolcode-cli.sh logs guest | tail -20

# Monitor real-time installation logs
sudo tail -f /var/log/schoolcode/schoolcode.log
```

### AI Agent Debugging Best Practices

#### **Before Making Changes**
1. **Document current state**: Run `sudo ./scripts/schoolcode-cli.sh status detailed`
2. **Check compatibility**: Run `./old_mac_compatibility.sh`
3. **Review logs**: Check for existing issues with `sudo ./scripts/schoolcode-cli.sh logs error`
4. **Test current functionality**: Verify existing features work before modifications

#### **During Development**
1. **Use dry-run mode**: Test changes with `--dry-run` flag
2. **Enable verbose logging**: Use `--verbose` for detailed output
3. **Test incrementally**: Make small changes and test frequently
4. **Document changes**: Keep track of modifications and their impact

#### **After Making Changes**
1. **Run full test suite**: Execute both Python and shell script tests
2. **Test in Guest account**: Validate changes in actual Guest environment
3. **Check system health**: Verify no regressions with status command
4. **Review logs**: Ensure no new errors introduced

### Common AI Agent Pitfalls

#### **Security Mistakes**
- **Modifying system files**: Never edit system-level configurations
- **Skipping permission checks**: Always validate permissions before operations
- **Ignoring Guest isolation**: Ensure all changes respect Guest account boundaries
- **Hardcoding paths**: Use dynamic path resolution for portability

#### **Compatibility Issues**
- **Assuming modern macOS**: Always check compatibility for older versions
- **Ignoring architecture differences**: Test on both Intel and Apple Silicon
- **Skipping dependency checks**: Verify all required tools are available
- **Not testing cleanup**: Ensure all changes are reversible

#### **Error Handling Problems**
- **Silent failures**: Always implement proper error reporting
- **Incomplete cleanup**: Ensure temporary files are properly removed
- **Poor error messages**: Provide actionable guidance for users
- **Ignoring return codes**: Use proper exit codes for script success/failure

### Log Locations & Analysis

#### **Primary Log Files**
- **Main logs**: `/var/log/schoolcode/schoolcode.log`
- **Error logs**: `/var/log/schoolcode/schoolcode-error.log`
- **Guest logs**: `/var/log/schoolcode/guest-setup.log`
- **Installation logs**: `/var/log/schoolcode/install.log`

#### **Temporary Files**
- **Compatibility report**: `/tmp/schoolcode_compatibility_report.txt`
- **Installation cache**: `/tmp/schoolcode_install_cache/`
- **Guest setup files**: `/tmp/schoolcode_guest_setup/`

#### **Log Analysis Tools**
```bash
# Search for specific patterns
grep -i "error\|failed" /var/log/schoolcode/schoolcode.log

# View recent activity
tail -100 /var/log/schoolcode/schoolcode.log

# Monitor real-time activity
tail -f /var/log/schoolcode/schoolcode.log

# Check for specific components
grep -i "python\|homebrew\|git" /var/log/schoolcode/schoolcode.log
```
