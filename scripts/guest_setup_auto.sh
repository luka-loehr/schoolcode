#!/bin/bash
# Copyright (c) 2025 Luka Löhr

# SchoolCode Guest Auto Setup
# Runs automatically when the Guest user opens Terminal

# Only run for Guest user
if [[ "$(whoami)" != "Guest" ]]; then
    return 0 2>/dev/null || exit 0
fi

# Check if already initialized in this session
if [[ "$SCHOOLCODE_INITIALIZED" == "true" ]]; then
    return 0 2>/dev/null || exit 0
fi

# Mark as initialized
export SCHOOLCODE_INITIALIZED="true"

# Check if this is an interactive terminal
if [[ ! -t 0 ]]; then
    return 0 2>/dev/null || exit 0
fi

# Admin tools directory
ADMIN_TOOLS_DIR="/opt/admin-tools"
GUEST_TOOLS_DIR="/Users/Guest/tools"

# Check if setup is needed (tools directory doesn't exist)
if [[ ! -d "$GUEST_TOOLS_DIR/bin" ]]; then
    clear
    echo "╔════════════════════════════════════════╗"
    echo "║     🚀 SchoolCode Guest Setup 🚀         ║"
    echo "║        © 2025 Luka Löhr                ║"
    echo "╚════════════════════════════════════════╝"
    echo ""
    echo "Setting up development tools..."
    echo ""
    
    # Check if admin tools exist
    if [[ ! -d "$ADMIN_TOOLS_DIR/bin" ]]; then
        echo "⚠️  Admin tools not found!"
        echo "Please contact administrator."
        echo ""
        echo "Administrator must run:"
        echo "  cd /path/to/SchoolCode && sudo ./setup.sh"
        exit 1
    fi
    
    # Create Guest tools directory
    echo "📁 Creating tools directory..."
    mkdir -p "$GUEST_TOOLS_DIR/bin"
    
    # Copy tools
    echo "📋 Copying development tools..."
    cp -R "$ADMIN_TOOLS_DIR/bin/"* "$GUEST_TOOLS_DIR/bin/" 2>/dev/null || {
        echo "❌ Error copying tools!"
        echo "Please contact administrator."
        exit 1
    }
    
    # Set PATH - include official Python directory and user pip packages
    # Source Python utils to find dynamic version
    if [ -f "/opt/admin-tools/utils/python_utils.sh" ]; then
        source "/opt/admin-tools/utils/python_utils.sh" 2>/dev/null || true
    fi
    
    # Get Python bin directory dynamically
    PYTHON_BIN_DIR=""
    if declare -f get_python_bin_dir >/dev/null 2>&1; then
        PYTHON_BIN_DIR=$(get_python_bin_dir 2>/dev/null || echo "")
    fi
    
    if [[ -n "$PYTHON_BIN_DIR" ]]; then
        export PATH="$GUEST_TOOLS_DIR/bin:$PYTHON_BIN_DIR:$PATH"
    else
        export PATH="$GUEST_TOOLS_DIR/bin:$PATH"
    fi
    
    # Add user pip install directory to PATH
    export PATH="$HOME/.local/bin:$PATH"
    
    # Apply security environment for Guest
    if [ -f "/opt/admin-tools/wrappers/guest_security_env.sh" ]; then
        source "/opt/admin-tools/wrappers/guest_security_env.sh"
    fi
    
    echo ""
    echo "✅ Setup completed!"
    echo ""
    echo "Available tools:"
    echo "  • brew    - Homebrew package manager"
    echo "  • python3 - Python 3 programming"
    echo "  • python  - Python programming"
    echo "  • git     - Version control"
    echo "  • pip3    - Python 3 packages"
    echo "  • pip     - Python packages"
    echo ""
    echo "Happy coding! 🎉"
    echo ""
else
    # Tools already set up, just set PATH - include official Python directory and user pip packages
    # Source Python utils to find dynamic version
    if [ -f "/opt/admin-tools/utils/python_utils.sh" ]; then
        source "/opt/admin-tools/utils/python_utils.sh" 2>/dev/null || true
    fi
    
    # Get Python bin directory dynamically
    PYTHON_BIN_DIR=""
    if declare -f get_python_bin_dir >/dev/null 2>&1; then
        PYTHON_BIN_DIR=$(get_python_bin_dir 2>/dev/null || echo "")
    fi
    
    if [[ -n "$PYTHON_BIN_DIR" ]]; then
        export PATH="$GUEST_TOOLS_DIR/bin:$PYTHON_BIN_DIR:$PATH"
    else
        export PATH="$GUEST_TOOLS_DIR/bin:$PATH"
    fi
    
    # Add user pip install directory to PATH
    export PATH="$HOME/.local/bin:$PATH"
    
    # Show welcome message only once per session
    if [[ "$SCHOOLCODE_WELCOME_SHOWN" != "true" ]]; then
        export SCHOOLCODE_WELCOME_SHOWN="true"
        echo ""
        echo "✨ SchoolCode tools are ready!"
        echo "Available: brew, python3, python, git, pip3, pip"
        echo "© 2025 Luka Löhr"
        echo ""
    fi
fi 