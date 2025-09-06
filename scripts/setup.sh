#!/bin/bash
# Copyright (c) 2025 Luka Löhr

# SchoolCode Quick Installation
# Installs everything needed in one step

set -e

echo "╔═══════════════════════════════════════╗"
echo "║        🚀 SchoolCode Setup 🚀           ║"
echo "╚═══════════════════════════════════════╝"
echo ""

# Check if running with sudo
if [ "$EUID" -ne 0 ]; then 
    echo "❌ Please run with sudo: sudo ./setup.sh"
    exit 1
fi

# Step 1: Main installation
echo "📦 Step 1/2: Installing development tools..."
SCHOOLCODE_CLI_INSTALL="${SCHOOLCODE_CLI_INSTALL:-false}" ./scripts/install_SchoolCode.sh

# Step 2: Activate Guest setup
echo ""
echo "🔧 Step 2/2: Activating Guest account setup..."
./scripts/setup/setup_guest_shell_init.sh

echo ""
echo "═══════════════════════════════════════════"
echo "✅ Installation completed!"
echo "═══════════════════════════════════════════"
echo ""
echo "🎯 Next steps:"
echo "   1. Log in as Guest user"
echo "   2. Terminal opens automatically"
echo "   3. All tools are immediately available!"
echo ""
echo "📝 For problems: see README.md" 