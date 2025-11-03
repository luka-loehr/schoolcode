<!--
Copyright (c) 2025 Luka Löhr
-->

# SchoolCode

Automated developer tool deployment for macOS Guest accounts.

[![Version](https://img.shields.io/badge/version-3.0.0-blue)](https://github.com/luka-loehr/SchoolCode)
[![macOS](https://img.shields.io/badge/macOS-10.14%2B-success)](https://support.apple.com/macos)
[![License](https://img.shields.io/badge/license-Apache%202.0-green)](LICENSE)

## What is SchoolCode?

SchoolCode provides a safe development environment for students on shared macOS machines. It automatically installs essential developer tools (Python, Homebrew, Git, pip) in Guest accounts with complete system isolation.

## Quick Start

```bash
# Clone and install
git clone https://github.com/luka-loehr/SchoolCode.git
cd SchoolCode
sudo ./schoolcode.sh
```

## Commands

### Installation & Management
```bash
sudo ./schoolcode.sh                    # Install everything
sudo ./schoolcode.sh --install          # Same as above (explicit)
sudo ./schoolcode.sh --uninstall        # Remove SchoolCode (no prompts)
sudo ./schoolcode.sh --status           # Check system health
sudo ./schoolcode.sh --help             # Show help
```

### Advanced Management
```bash
sudo ./scripts/schoolcode-cli.sh status detailed    # Detailed system status
sudo ./scripts/schoolcode-cli.sh repair             # Fix system issues
sudo ./scripts/schoolcode-cli.sh update             # Update everything
sudo ./scripts/schoolcode-cli.sh logs               # View system logs
```

## Requirements

- macOS 10.14+ (Mojave or newer)
- Admin access
- 5GB free disk space
- Internet connection

## What Gets Installed

1. **Compatibility Check** - Validates system requirements
2. **System Repair** - Fixes Xcode CLT, certificates, Git, PATH issues  
3. **Development Tools** - Python (official), Homebrew, Git, pip
4. **Guest Setup** - Configures Guest account environment

## Security

All modifications are temporary and isolated to Guest accounts. Students can experiment freely without affecting the system or other users.

📖 **[Full Documentation](https://luka-loehr.github.io/SchoolCode/)** - Comprehensive guide covering architecture, security, installation, and troubleshooting

## Troubleshooting

```bash
# Check system health
sudo ./schoolcode.sh --status

# Fix system issues
sudo ./scripts/schoolcode-cli.sh repair

# View detailed logs
sudo ./scripts/schoolcode-cli.sh logs
```

## License

Apache License 2.0 - © 2025 Luka Löhr