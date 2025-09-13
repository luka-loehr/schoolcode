#!/bin/bash
# Copyright (c) 2025 Luka Löhr

# SchoolCode Setup Launcher
# Choose between interactive and automatic installation

set -e

# Parse command line arguments
MODE=""
SKIP_REPAIR=false
FORCE_REPAIR=false

while [[ $# -gt 0 ]]; do
    case $1 in
        --interactive|-i)
            MODE="interactive"
            shift
            ;;
        --auto|-a)
            MODE="auto"
            shift
            ;;
        --skip-repair)
            SKIP_REPAIR=true
            shift
            ;;
        --force-repair)
            FORCE_REPAIR=true
            shift
            ;;
        -h|--help)
            echo "SchoolCode Setup - Choose your installation method"
            echo ""
            echo "Usage: sudo ./setup.sh [MODE] [OPTIONS]"
            echo ""
            echo "Installation Modes:"
            echo "  --interactive, -i    Interactive installation (choose components)"
            echo "  --auto, -a          Automatic installation (everything at once)"
            echo ""
            echo "Options:"
            echo "  --skip-repair       Skip system repair step (auto mode only)"
            echo "  --force-repair      Run system repair without prompting (auto mode only)"
            echo "  -h, --help          Show this help message"
            echo ""
            echo "Examples:"
            echo "  sudo ./setup.sh --interactive    # Choose what to install"
            echo "  sudo ./setup.sh --auto           # Install everything automatically"
            echo "  sudo ./setup.sh --auto --skip-repair  # Auto install without repair"
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
echo "║        🚀 SchoolCode Setup 🚀           ║"
echo "╚═══════════════════════════════════════╝"
echo ""

# Check if running with sudo
if [ "$EUID" -ne 0 ]; then 
    echo "❌ Please run with sudo: sudo ./setup.sh"
    exit 1
fi

# If no mode specified, show menu
if [[ -z "$MODE" ]]; then
    echo "Choose your installation method:"
    echo ""
    echo "1. 🎯 Interactive Installation"
    echo "   Choose which components to install"
    echo "   Recommended for advanced users"
    echo ""
    echo "2. 🚀 Automatic Installation"
    echo "   Install everything automatically"
    echo "   Recommended for most users"
    echo ""
    read -p "Choose (1-2): " -n 1 -r
    echo
    echo ""
    
    case $REPLY in
        1)
            MODE="interactive"
            ;;
        2)
            MODE="auto"
            ;;
        *)
            echo "Invalid choice. Please run the script again."
            exit 1
            ;;
    esac
fi

# Run the appropriate installation mode
case "$MODE" in
    "interactive")
        echo "🎯 Starting interactive installation..."
        echo ""
        ./scripts/install_interactive.sh
        ;;
    "auto")
        echo "🚀 Starting automatic installation..."
        echo ""
        # Pass through options to auto installer
        local auto_options=""
        if [[ "$SKIP_REPAIR" == "true" ]]; then
            auto_options="--skip-repair"
        elif [[ "$FORCE_REPAIR" == "true" ]]; then
            auto_options="--force-repair"
        fi
        
        if [[ -n "$auto_options" ]]; then
            ./scripts/install_auto.sh $auto_options
        else
            ./scripts/install_auto.sh
        fi
        ;;
    *)
        echo "❌ Invalid installation mode: $MODE"
        exit 1
        ;;
esac 