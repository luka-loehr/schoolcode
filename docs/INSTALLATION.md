# SchoolCode Installation Script v3.0 - Documentation

## Overview

The SchoolCode Installation Script v3.0 is a completely rewritten, production-ready installer with enterprise-grade features including comprehensive error handling, logging, rollback capabilities, and enhanced security.

## Key Improvements Over v2

### 🛡️ **Enhanced Security**
- **Input Validation**: All user inputs are sanitized and validated
- **Secure Path Handling**: Eliminated `eval` usage and command injection vulnerabilities
- **macOS Compatibility**: Uses `dscl` instead of `getent` for secure user home detection
- **Privilege Management**: Minimized sudo usage with proper permission checks

### 🔧 **Robust Error Handling**
- **Error Trapping**: Comprehensive error detection with line-specific reporting
- **Automatic Cleanup**: Removes partial installations on failure
- **Rollback Support**: Can restore from backup if installation fails
- **Recovery Options**: Interactive prompts for recovery actions

### 📊 **Professional Logging**
- **Multi-level Logging**: DEBUG, INFO, WARN, ERROR, SUCCESS levels
- **Persistent Logs**: Saved to `/var/log/schoolcode/` with timestamps
- **Verbose Mode**: Optional detailed output for troubleshooting
- **Progress Indicators**: Visual feedback for long-running operations

### 🎯 **Modular Architecture**
- **Organized Functions**: Separated into logical sections (logging, error handling, installation, verification)
- **Reusable Components**: Functions can be easily tested and maintained
- **Clear Dependencies**: Well-defined function relationships
- **Configuration Section**: Centralized settings for easy customization

### 🚀 **Advanced Features**
- **Dry Run Mode**: Test installation without making changes
- **Custom Prefixes**: Install to different locations
- **Backup Creation**: Automatic backup before modifications
- **Force Mode**: Skip confirmation prompts for automation
- **Quiet Mode**: Suppress output for scripted installations
- **Color Support**: Enhanced readability with color-coded output

## Installation Options

### Basic Installation
```bash
sudo ./scripts/install.sh
```

### Advanced Options

#### Dry Run (Test Mode)
See what would be installed without making changes:
```bash
sudo ./scripts/install.sh --dry-run --verbose
```

#### Custom Installation Directory
Install to a different location:
```bash
sudo ./scripts/install.sh --prefix /usr/local/schoolcode
```

#### Automated Installation
Skip all prompts (useful for CI/CD):
```bash
sudo ./scripts/install.sh --force --quiet
```

#### Custom Log Location
Specify where to save the installation log:
```bash
sudo ./scripts/install.sh --log /path/to/custom.log
```

#### No Backup Mode
Skip backup creation (faster but less safe):
```bash
sudo ./scripts/install.sh --no-backup
```

## Command Line Options

| Option | Short | Description |
|--------|-------|-------------|
| `--help` | `-h` | Display help message and exit |
| `--verbose` | `-v` | Enable detailed output and debug logging |
| `--quiet` | `-q` | Suppress all non-error output |
| `--dry-run` | `-d` | Simulate installation without making changes |
| `--force` | `-f` | Skip confirmation prompts |
| `--log PATH` | `-l PATH` | Custom log file location |
| `--no-backup` | | Skip backup creation |
| `--prefix PATH` | | Custom installation directory |
| `--no-color` | | Disable colored output |

## Installation Process

### Phase 1: Initialization
1. **Parse Arguments**: Process command-line options
2. **Initialize Logging**: Set up log file and handlers
3. **Check Privileges**: Verify sudo/root access
4. **System Requirements**: Check macOS version and disk space

### Phase 2: Preparation
1. **Create Backup**: Save existing installation (if any)
2. **Verify Dependencies**: Check for required commands
3. **Install Missing Tools**: Attempt to install missing dependencies

### Phase 3: Core Installation
1. **Homebrew Setup**: Install/repair Homebrew package manager
2. **Python Installation**: Install Python via Homebrew or official installer
3. **Tool Setup**: Create directory structure and symlinks
4. **Security Wrappers**: Set up Guest user security wrappers

### Phase 4: Configuration
1. **PATH Configuration**: Update shell configuration files
2. **Guest Setup**: Create LaunchAgent for Guest users
3. **Pip Configuration**: Set up pip for user installations

### Phase 5: Verification
1. **Directory Check**: Verify all directories created
2. **Tool Testing**: Test each tool for functionality
3. **Report Generation**: Display installation summary

## Error Recovery

### Automatic Recovery Features
- **Rollback on Failure**: Automatically offers to restore from backup
- **Partial Cleanup**: Removes incomplete installations
- **Log Preservation**: Keeps logs even after failure
- **Graceful Degradation**: Continues with warnings for non-critical failures

### Manual Recovery Options
If installation fails:
1. Check the log file for specific errors
2. Run with `--verbose` for more details
3. Try `--dry-run` to identify issues
4. Use `--force` to bypass confirmations

## System Requirements

### Minimum Requirements
- macOS 10.14 (Mojave) or later
- 2GB free disk space
- Administrator (sudo) privileges
- Internet connection for downloads

### Recommended
- macOS 12.0 (Monterey) or later
- 4GB free disk space
- Stable internet connection
- Homebrew pre-installed

## Security Features

### Guest User Protection
- **Command Blocking**: Dangerous brew/pip commands blocked for Guest users
- **User Installations**: Forces `--user` flag for pip in Guest accounts
- **Read-only Access**: Guest users get read-only brew access
- **Isolated Workspace**: Creates separate workspace for Guest users

### Installation Security
- **Input Validation**: All user inputs are validated
- **Path Sanitization**: Prevents path injection attacks
- **Secure Downloads**: Uses HTTPS for all downloads
- **Permission Management**: Sets appropriate file permissions

## Logging System

### Log Levels
- **DEBUG**: Detailed diagnostic information
- **INFO**: General informational messages
- **WARN**: Warning messages for non-critical issues
- **ERROR**: Error messages for failures
- **SUCCESS**: Success confirmations

### Log Locations
- Default: `/var/log/schoolcode/install_YYYYMMDD_HHMMSS.log`
- Fallback: `/tmp/schoolcode_install_$$.log`
- Custom: Specified via `--log` option

### Log Format
```
[YYYY-MM-DD HH:MM:SS] [LEVEL] Message
```

## Troubleshooting

### Common Issues

#### "Homebrew not found"
**Solution**: The script will offer to install Homebrew automatically

#### "Insufficient disk space"
**Solution**: Free up at least 2GB of disk space

#### "Command Line Tools outdated"
**Solution**: Update via System Preferences or run:
```bash
xcode-select --install
```

#### "Permission denied"
**Solution**: Ensure you're running with sudo:
```bash
sudo ./scripts/install.sh
```

### Debug Mode
For maximum diagnostic information:
```bash
sudo ./scripts/install.sh --verbose --dry-run
```

## Uninstallation

To remove SchoolCode:
```bash
# Remove installation directory
sudo rm -rf /opt/schoolcode

# Remove LaunchAgent
sudo rm -f /Library/LaunchAgents/com.schoolcode.guestsetup.plist

# Remove guest setup script
sudo rm -f /usr/local/bin/guest_setup_auto.sh

# Clean up PATH (edit shell config files)
# Remove SchoolCode PATH entries from:
# - ~/.zshrc
# - ~/.bashrc
# - ~/.bash_profile
```

## Development

### Testing
```bash
# Syntax check
bash -n scripts/install.sh

# Dry run test
sudo ./scripts/install.sh --dry-run --verbose

# Full test with custom prefix
sudo ./scripts/install.sh --prefix /tmp/test_schoolcode --verbose
```

### Contributing
1. Test changes with dry-run mode
2. Ensure backward compatibility
3. Update documentation
4. Add appropriate logging
5. Handle errors gracefully

## Version History

### v3.0.0 (Current)
- Complete rewrite with modular architecture
- Enhanced error handling and recovery
- Comprehensive logging system
- Security improvements
- macOS compatibility fixes
- Backup and rollback support

### v2.1.0
- Added old Mac support
- Homebrew repair functionality
- Guest user security wrappers

### v1.0.0
- Initial release
- Basic installation functionality

## Support

### Getting Help
- Check installation logs in `/var/log/schoolcode/`
- Run with `--verbose` for detailed output
- Create an issue on GitHub with log files

### Contact
- GitHub: https://github.com/luka-loehr/SchoolCode
- Issues: https://github.com/luka-loehr/SchoolCode/issues

## License

Copyright (c) 2025 Luka Löhr
Licensed under the Apache License 2.0
