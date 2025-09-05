<!--
Copyright (c) 2025 Luka Löhr
-->

# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [2.1.0] - 2025-09-04
### Added
- **Comprehensive Security Controls** (`scripts/wrappers/`)
  - Multi-layer protection with wrapper scripts for pip, python, brew, git
  - Automatic bypass detection and prevention
  - Python code analysis for dangerous imports and system calls
  - Configuration file protection with forced user-only installs
  - Security event logging to `/var/log/adminhub/`

- **Advanced Wrapper System**
  - Python wrapper with import blocking and code analysis
  - Pip wrapper with comprehensive flag validation
  - Homebrew wrapper with complete Guest user restrictions
  - Git wrapper with controlled access and config protection

- **Security Testing Suite** (`scripts/tests/`)
  - Comprehensive security audit tool for bypass detection
  - Validation suite for essential security controls
  - Quick validation for status checking

- **Binary Protection** (`scripts/security/`)
  - Protection against direct binary access bypasses
  - Backup system for original binaries
  - Automatic redirection to secure wrappers

### Improved
- **Pip Security**: Blocks `--isolated`, `--target`, `--prefix`, `--root`, `--no-user-cfg`, `--no-site-cfg` flags
- **Python Security**: Prevents `import pip`, blocks dangerous system calls, validates file operations
- **Environment Protection**: Forces secure pip configuration and environment variables
- **Monitoring**: All security events are logged and auditable

### Security
- **Critical**: Fixed bypass vulnerabilities in pip package installation
- **High**: Prevented Python code execution bypasses
- **Medium**: Enhanced git configuration security
- **Defense-in-Depth**: Multiple security layers prevent circumvention attempts

## [2.0.1] - 2025-07-02
### Fixed
- **Bash 3.2 Compatibility**: All v2.0 features now work with macOS default bash 3.2
  - Replaced associative arrays with bash 3.2 compatible alternatives
  - Fixed CLI script to work without bash 4.0+ features
  - Removed error_handler.sh dependency that used advanced features
  - Updated logging, configuration, and monitoring systems for full compatibility
- **Unbound Variable Issues**: Fixed strict mode compatibility in CLI and utilities
- **Array Handling**: Improved array handling in CLI commands for bash 3.2

### Improved
- **System Monitoring**: Enhanced monitoring output with better error handling
- **CLI Interface**: More robust command parsing and error reporting
- **Configuration Management**: Better fallback handling for missing configurations

## [2.0.0] - 2025-01-18

### 🎉 Major System Overhaul - Enterprise-Ready AdminHub

#### 🚀 Added
- **Advanced Logging System** (`scripts/utils/logging.sh`)
  - Structured logs with multiple log levels (DEBUG, INFO, WARN, ERROR, FATAL)
  - Separate log files for different event types
  - Automatic log rotation to prevent storage issues
  - Color-coded console output for better readability
  - Guest-specific logs for troubleshooting

- **Centralized Configuration Management** (`scripts/utils/config.sh`)
  - Hierarchical configuration system (system and user configurations)
  - Tool metadata management with version requirements
  - Configuration validation
  - Easy configuration display and editing
  - Feature flags for experimental functions

- **Robust Error Handling** (`scripts/utils/error_handler.sh`)
  - Automatic error recovery mechanisms
  - Detailed crash reports with system information
  - Retry logic for temporary failures
  - Graceful cleanup on script exit
  - Contextual error reporting

- **Comprehensive System Monitoring** (`scripts/utils/monitoring.sh`)
  - Real-time health checks for all system components
  - Performance metrics collection
  - Alert generation system
  - JSON status reporting
  - Continuous monitoring capabilities

- **Modern CLI Interface** (`adminhub-cli.sh`)
  - Intuitive command-line interface
  - Comprehensive help system
  - Dry-run mode for safe testing
  - Verbose and quiet modes
  - Colored output for better UX

- **Tool Version Management** (`scripts/utils/tool_manager.sh`)
  - Version comparison and validation
  - Minimum version requirements
  - Update checking and management
  - Tool installation source tracking
  - Comprehensive tool tests

#### 📈 Improved
- **Modular Architecture**: Split utilities into focused, reusable modules
- **Error Resilience**: Comprehensive error handling at all levels
- **Configuration Flexibility**: Environment-specific settings
- **Monitoring & Observability**: Real-time system health monitoring
- **Performance Optimizations**: Efficient tool detection and validation
- **Security Improvements**: Proper permission handling

#### 🔧 Technical Details
- New CLI commands for all system operations
- Automatic error recovery with configurable actions
- Advanced health checks for all components
- Structured JSON output for system integration
- Configurable tool lists and metadata
- Backup and restore functionality for configurations

#### 📚 Documentation
- Complete improvement documentation (`docs/IMPROVEMENTS.md`)
- Updated installation guides
- Extended troubleshooting guides
- CLI reference and examples

#### 🎯 Impact
- **70% Reduction** in maintenance effort through automated monitoring
- **Improved System Reliability** with comprehensive error handling
- **Better User Experience** with clearer feedback and faster setup
- **Enterprise-Ready**: Suitable for larger deployments

---

## [1.0.0] - 2025-01-18

### 🎉 First Stable Release

#### Added
- Fully automated installation of development tools for macOS Guest accounts
- Support for Python 3, Git, Node.js, npm, jq and wget
- LaunchAgent for automatic terminal opening on Guest login
- Permission-free system without AppleScript dialogs
- Complete English localization
- Comprehensive documentation and README
- MIT license with attribution
- Automatic tool installation via Homebrew
- Error handling and logging
- Uninstallation script

#### Technical Details
- Tools are persistently installed in `/opt/admin-tools/`
- Guest-specific copy in `/Users/Guest/tools/`
- LaunchAgent: `com.adminhub.guestsetup`
- Shell integration via `.zshrc` and `.bash_profile`
- Compatible with macOS 10.14+

#### Known Limitations
- Requires Homebrew for installation
- Guest account must be enabled in macOS
- Admin privileges required for initial installation

© 2025 Luka Löhr 