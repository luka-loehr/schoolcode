#!/bin/bash
# Copyright (c) 2025 Luka Löhr

# SchoolCode Interactive Installation
# Allows users to choose which components to install

set -e

echo "╔═══════════════════════════════════════╗"
echo "║    🚀 SchoolCode Interactive Setup 🚀   ║"
echo "╚═══════════════════════════════════════╝"
echo ""

# Check if running with sudo
if [ "$EUID" -ne 0 ]; then 
    echo "❌ Please run with sudo: sudo ./scripts/install_interactive.sh"
    exit 1
fi

# Function to ask yes/no question
ask_yes_no() {
    local prompt="$1"
    local default="${2:-n}"
    
    if [[ "$default" == "y" ]]; then
        prompt="$prompt [Y/n]: "
    else
        prompt="$prompt [y/N]: "
    fi
    
    read -p "$prompt" -n 1 -r
    echo
    
    if [[ -z "$REPLY" ]]; then
        REPLY="$default"
    fi
    
    [[ "$REPLY" =~ ^[Yy]$ ]]
}

# Function to show menu
show_menu() {
    echo ""
    echo "═══════════════════════════════════════════"
    echo "           Installation Options"
    echo "═══════════════════════════════════════════"
    echo ""
    echo "1. 🔍 Compatibility Check"
    echo "   Check if your Mac is compatible with SchoolCode"
    echo ""
    echo "2. 🔧 System Repair"
    echo "   Fix common system issues (Xcode CLT, certificates, etc.)"
    echo ""
    echo "3. 📦 Install SchoolCode Tools"
    echo "   Install Python, Homebrew, and development tools"
    echo ""
    echo "4. 🔧 Setup Guest Account"
    echo "   Configure Guest user environment"
    echo ""
    echo "5. 🚀 Install Everything (Recommended)"
    echo "   Run all steps in sequence"
    echo ""
    echo "6. ❌ Exit"
    echo ""
}

# Function to run compatibility check
run_compatibility_check() {
    echo ""
    echo "🔍 Running compatibility check..."
    echo ""
    if ./old_mac_compatibility.sh; then
        echo ""
        echo "✅ Compatibility check passed!"
    else
        echo ""
        echo "❌ Compatibility check failed!"
        echo "   Please check the compatibility report and fix issues"
        return 1
    fi
}

# Function to run system repair
run_system_repair() {
    echo ""
    echo "🔧 Running system repair..."
    echo ""
    echo "This will check and repair:"
    echo "  • Xcode Command Line Tools installation"
    echo "  • System certificates"
    echo "  • Git configuration"
    echo "  • PATH issues"
    echo "  • DNS problems"
    echo ""
    if ask_yes_no "Continue with system repair?"; then
        ./system_repair.sh
        echo ""
        echo "✅ System repair completed!"
    else
        echo "Skipping system repair"
    fi
}

# Function to install tools
install_tools() {
    echo ""
    echo "📦 Installing SchoolCode tools..."
    echo ""
    if SCHOOLCODE_CLI_INSTALL=true ./scripts/install.sh; then
        echo ""
        echo "✅ Tools installation completed!"
    else
        echo ""
        echo "❌ Tools installation failed!"
        return 1
    fi
}

# Function to setup guest account
setup_guest() {
    echo ""
    echo "🔧 Setting up Guest account..."
    echo ""
    if ./scripts/setup/setup_guest_shell_init.sh; then
        echo ""
        echo "✅ Guest account setup completed!"
    else
        echo ""
        echo "❌ Guest account setup failed!"
        return 1
    fi
}

# Function to install everything
install_everything() {
    echo ""
    echo "🚀 Installing everything..."
    echo ""
    
    # Step 1: Compatibility check
    echo "Step 1/4: Compatibility check..."
    if ! run_compatibility_check; then
        echo "❌ Installation stopped due to compatibility issues"
        return 1
    fi
    
    # Step 2: System repair
    echo ""
    echo "Step 2/4: System repair..."
    if ask_yes_no "Run system repair?" "y"; then
        run_system_repair
    fi
    
    # Step 3: Install tools
    echo ""
    echo "Step 3/4: Installing tools..."
    if ! install_tools; then
        echo "❌ Installation stopped due to tools installation failure"
        return 1
    fi
    
    # Step 4: Setup guest
    echo ""
    echo "Step 4/4: Setting up Guest account..."
    if ! setup_guest; then
        echo "❌ Installation stopped due to guest setup failure"
        return 1
    fi
    
    echo ""
    echo "🎉 Complete installation finished!"
}

# Main interactive loop
main() {
    while true; do
        show_menu
        read -p "Choose an option (1-6): " choice
        
        case $choice in
            1)
                run_compatibility_check
                ;;
            2)
                run_system_repair
                ;;
            3)
                install_tools
                ;;
            4)
                setup_guest
                ;;
            5)
                install_everything
                break
                ;;
            6)
                echo "Goodbye! 👋"
                exit 0
                ;;
            *)
                echo "Invalid option. Please choose 1-6."
                ;;
        esac
        
        echo ""
        read -p "Press Enter to continue..."
    done
}

# Run main function
main
