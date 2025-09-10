#!/bin/bash
# Copyright (c) 2025 Luka Löhr

# SchoolCode Tools Activator
# This script activates the tools immediately in the current shell

# Check if script is called with source
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    echo "❌ This script must be called with source!"
    echo ""
    echo "Please run:"
    echo "  source activate_tools.sh"
    echo ""
    echo "or:"
    echo "  . activate_tools.sh"
    exit 1
fi

echo "🔄 Activating SchoolCode tools..."
echo "© 2025 Luka Löhr"

# Add to PATH
export PATH="/opt/admin-tools/bin:$PATH"

# Check if tools are available
if command -v python3 &> /dev/null && [ -L "/opt/admin-tools/bin/python3" ]; then
    echo "✅ Tools activated!"
    echo ""
    echo "Available commands:"
    
    if [ -L "/opt/admin-tools/bin/brew" ]; then
        echo "  • brew ($(brew --version 2>&1 | head -1))"
    fi
    
    echo "  • python3 ($(python3 --version 2>&1))"
    
    if [ -L "/opt/admin-tools/bin/python" ]; then
        echo "  • python ($(python --version 2>&1))"
    fi
    
    echo "  • git ($(git --version))"
    
    if [ -L "/opt/admin-tools/bin/pip3" ]; then
        echo "  • pip3 ($(pip3 --version 2>/dev/null || echo 'Check permissions'))"
    fi
    
    if [ -L "/opt/admin-tools/bin/pip" ]; then
        echo "  • pip ($(pip --version 2>/dev/null || echo 'Check permissions'))"
    fi
    
    echo ""
    echo "🎉 You can now use all tools in THIS terminal!"
    echo ""
    echo "Note: This activation applies only to the current terminal session."
    echo "New terminals will have the tools automatically if install.sh was run"
else
    echo "❌ Tools not found. Please run: sudo ./install.sh"
fi 