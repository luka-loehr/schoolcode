#!/bin/bash
# Copyright (c) 2025 Luka Löhr

# SchoolCode Automatic Installation
# One-time setup that installs everything automatically

set -e

# Parse command line arguments
SKIP_REPAIR=false
FORCE_REPAIR=false

while [[ $# -gt 0 ]]; do
    case $1 in
        --skip-repair)
            SKIP_REPAIR=true
            shift
            ;;
        --force-repair)
            FORCE_REPAIR=true
            shift
            ;;
        -h|--help)
            echo "SchoolCode Automatic Installation"
            echo ""
            echo "Usage: sudo ./scripts/install_auto.sh [OPTIONS]"
            echo ""
            echo "Options:"
            echo "  --skip-repair     Skip system repair step"
            echo "  --force-repair    Run system repair without prompting"
            echo "  -h, --help        Show this help message"
            exit 0
            ;;
        *)
            echo "Unknown option: $1"
            echo "Use --help for usage information"
            exit 1
            ;;
    esac
done

echo "╔═══════════════════════════════════════╗"
echo "║      🚀 SchoolCode Auto Setup 🚀       ║"
echo "╚═══════════════════════════════════════╝"
echo ""

# Check if running with sudo
if [ "$EUID" -ne 0 ]; then 
    echo "❌ Please run with sudo: sudo ./scripts/install_auto.sh"
    exit 1
fi

echo "This will automatically install SchoolCode with all components:"
echo "  • Compatibility check"
echo "  • System repair (if needed)"
echo "  • Development tools installation"
echo "  • Guest account setup"
echo ""

# Ask for confirmation
read -p "Continue with automatic installation? (y/N): " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "Installation cancelled"
    exit 0
fi

echo ""
echo "Starting automatic installation..."
echo ""

# Step 1: Compatibility check
echo "🔍 Step 1/4: Checking system compatibility..."
if ! ./old_mac_compatibility.sh; then
    echo ""
    echo "❌ Compatibility check failed!"
    echo "   Please check the compatibility report and fix issues before proceeding"
    echo "   Report location: /tmp/schoolcode_compatibility_report.txt"
    exit 1
fi
echo "✅ Compatibility check passed!"

# Step 2: System repair
echo ""
echo "🔧 Step 2/4: System repair..."

if [[ "$SKIP_REPAIR" == "true" ]]; then
    echo "Skipping system repair (--skip-repair flag used)"
elif [[ "$FORCE_REPAIR" == "true" ]]; then
    echo "Running system repair (--force-repair flag used)..."
    ./system_repair.sh
    echo "✅ System repair completed!"
else
    echo "Running system repair..."
    ./system_repair.sh
    echo "✅ System repair completed!"
fi

# Step 3: Install tools
echo ""
echo "📦 Step 3/4: Installing development tools..."
if ! SCHOOLCODE_CLI_INSTALL=true ./scripts/install.sh; then
    echo ""
    echo "❌ Tools installation failed!"
    exit 1
fi
echo "✅ Tools installation completed!"

# Step 4: Setup guest account
echo ""
echo "🔧 Step 4/4: Setting up Guest account..."
if ! ./scripts/setup/setup_guest_shell_init.sh; then
    echo ""
    echo "❌ Guest account setup failed!"
    exit 1
fi
echo "✅ Guest account setup completed!"

# Final success message
echo ""
echo "═══════════════════════════════════════════"
echo "🎉 SchoolCode Installation Complete! 🎉"
echo "═══════════════════════════════════════════"
echo ""
echo "Next steps:"
echo "  1. Log in as Guest user"
echo "  2. Terminal opens automatically with all tools ready"
echo "  3. Start coding! 🚀"
echo ""
echo "Available commands:"
echo "  • python3 - Python programming"
echo "  • pip3    - Python package manager"
echo "  • git     - Version control"
echo "  • brew    - Package manager (read-only for Guest)"
echo ""
echo "For troubleshooting:"
echo "  • Check status: sudo ./scripts/schoolcode-cli.sh status"
echo "  • View logs: sudo ./scripts/schoolcode-cli.sh logs"
echo "  • Run repair: sudo ./scripts/schoolcode-cli.sh repair"
echo ""
