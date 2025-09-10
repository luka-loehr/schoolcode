<!--
Copyright (c) 2025 Luka Löhr
-->

# agents.md

This file provides guidance to AI agents when working with code in this repository.

## Project Overview

SchoolCode is an automated development tools installer for macOS Guest accounts. It provides a safe, experimental development environment for students on shared macOS machines by automatically deploying essential developer tools to Guest accounts.

## Technology Stack

- **Shell Scripting**: Bash scripts for automation and system management
- **macOS**: Designed specifically for macOS Guest account environments
- **Homebrew**: Package manager for installing development tools
- **Python**: Python installation and configuration
- **Git**: Version control system setup
- **Security**: Guest account isolation and temporary modifications

## Development Workflow

### Running Locally
1. Clone the repository
2. Run the installation script with sudo privileges
3. Test in a Guest account environment

### Making Changes
1. Edit shell scripts and configuration files
2. Test changes in a Guest account
3. Commit changes to Git
4. Push to GitHub

### Key Commands
```bash
# Install SchoolCode and its tools
sudo ./scripts/schoolcode-cli.sh install

# Check system health and status
sudo ./scripts/schoolcode-cli.sh status

# Update SchoolCode and all managed dependencies
sudo ./scripts/schoolcode-cli.sh update

# Remove SchoolCode from the system
sudo ./scripts/schoolcode-cli.sh uninstall
```

## Architecture & Structure

### File Organization
```
SchoolCode/
├── scripts/
│   └── scripts/schoolcode-cli.sh    # Main CLI script
├── config/
│   └── config.sh           # Configuration settings
├── tools/
│   ├── homebrew/           # Homebrew installation scripts
│   ├── python/             # Python installation scripts
│   └── git/                # Git configuration scripts
├── docs/
│   ├── SECURITY.md         # Security documentation
│   └── INSTALLATION.md     # Installation guide
└── README.md               # Project documentation
```

### Key Components

1. **CLI Interface**: Command-line tool for managing SchoolCode
2. **Tool Installers**: Individual scripts for each development tool
3. **Configuration Management**: Centralized configuration system
4. **Security Layer**: Guest account isolation and cleanup
5. **Update System**: Automated dependency updates

## Important Development Notes

1. **Security First**: All modifications must be temporary and isolated to Guest accounts
2. **Guest Account Focus**: Designed specifically for educational environments
3. **Zero Maintenance**: Students should not need to maintain the system
4. **Tool Isolation**: Each tool should be independently manageable
5. **Cleanup**: All changes must be reversible and temporary

## Security Considerations

- **Guest Account Isolation**: All changes are temporary and isolated
- **No System Modification**: Never modify system-level configurations
- **Temporary Files**: Use temporary directories for all installations
- **Cleanup Scripts**: Ensure proper cleanup on logout
- **Permission Management**: Use appropriate file permissions

## Code Style Guidelines

- Use clear, descriptive variable names
- Add comprehensive error handling
- Include detailed logging for debugging
- Follow shell scripting best practices
- Comment complex logic and security measures

## Testing

- Test all changes in a fresh Guest account
- Verify tool installations work correctly
- Ensure cleanup scripts function properly
- Test error conditions and edge cases
- Validate security measures

## Deployment

- Changes are deployed via Git
- No build process required
- Installation scripts handle all setup
- Updates are managed through the CLI

## Troubleshooting

- Check logs in `/tmp/SchoolCode/`
- Verify Guest account permissions
- Ensure internet connectivity for downloads
- Check disk space requirements
- Validate macOS version compatibility
