#!/bin/bash
# Pip wrapper for Guest users with security controls and bypass prevention
# AdminHub - Version 2.1.0

# Find the actual pip executable
find_actual_pip() {
    # First check if we have a direct symlink
    if [ -L "/opt/admin-tools/actual/bin/pip" ]; then
        local target=$(readlink "/opt/admin-tools/actual/bin/pip")
        if [ -x "$target" ]; then
            echo "$target"
            return
        fi
    fi
    
    # Fallback to pip3 if pip doesn't exist
    if [ -L "/opt/admin-tools/actual/bin/pip3" ]; then
        local target=$(readlink "/opt/admin-tools/actual/bin/pip3")
        if [ -x "$target" ]; then
            echo "$target"
            return
        fi
    fi
    
    # Otherwise search in common locations
    local pip_locations=(
        "/opt/homebrew/opt/python@3.13/libexec/bin/pip"
        "/opt/homebrew/opt/python@3.12/libexec/bin/pip"
        "/opt/homebrew/opt/python@3.11/libexec/bin/pip"
        "/usr/local/opt/python@3.13/libexec/bin/pip"
        "/usr/local/opt/python@3.12/libexec/bin/pip"
        "/usr/local/opt/python@3.11/libexec/bin/pip"
        "/opt/homebrew/bin/pip3"
        "/usr/local/bin/pip3"
        "/Library/Frameworks/Python.framework/Versions/3.13/bin/pip"
        "/Library/Frameworks/Python.framework/Versions/3.12/bin/pip"
        "/Library/Frameworks/Python.framework/Versions/3.11/bin/pip"
    )
    
    for location in "${pip_locations[@]}"; do
        if [ -x "$location" ]; then
            echo "$location"
            return
        fi
    done
    
    # Fallback to which
    which pip3 2>/dev/null || which pip 2>/dev/null || echo ""
}

ACTUAL_PIP=$(find_actual_pip)

if [ -z "$ACTUAL_PIP" ]; then
    echo "❌ Error: pip not found"
    exit 1
fi

# Check if running as Guest
if [[ "$USER" == "Guest" ]]; then
    # Force user installation
    export PIP_USER=1
    export PYTHONUSERBASE="$HOME/.local"
    
    # Security controls: Check for dangerous flags and bypass attempts
    for arg in "$@"; do
        case "$arg" in
            --target|--prefix|--root|-t)
                echo "❌ Error: System installation flags are not allowed for Guest users"
                echo "   All packages will be installed to your user directory"
                echo "   For help: pip help install"
                exit 1
                ;;
            --isolated|--isolated=*)
                echo "❌ Error: --isolated flag is not allowed for Guest users"
                echo "   This flag bypasses security restrictions and could allow system modifications"
                echo "   Use pip normally - packages will be installed safely to your user directory"
                echo "   For help: pip help install"
                exit 1
                ;;
            --no-user-cfg|--no-site-cfg)
                echo "❌ Error: Configuration bypass flags are not allowed for Guest users"
                echo "   These flags can bypass security restrictions"
                echo "   Use pip normally - packages will be installed safely to your user directory"
                exit 1
                ;;
            --upgrade-strategy)
                # Allow but ignore
                ;;
        esac
    done
    
    # Additional comprehensive check for bypass attempts in any argument format
    local full_args="$*"
    if [[ "$full_args" == *"--isolated"* ]] || [[ "$full_args" == *"--no-user-cfg"* ]] || [[ "$full_args" == *"--no-site-cfg"* ]]; then
        echo "❌ Error: Security bypass flags detected and blocked"
        echo "   Flags like --isolated, --no-user-cfg, and --no-site-cfg are not allowed for Guest users"
        echo "   These flags can bypass AdminHub's security restrictions"
        echo "   Use pip normally - packages will be installed safely to your user directory"
        exit 1
    fi
    
    # Check if trying to use sudo
    if [[ -n "${SUDO_USER:-}" ]]; then
        echo "❌ Error: sudo pip is not allowed for Guest users"
        echo "   All packages will be installed to your user directory automatically"
        exit 1
    fi
    
    # Log security attempts for monitoring (optional)
    if [[ "$full_args" == *"--target"* ]] || [[ "$full_args" == *"--prefix"* ]] || [[ "$full_args" == *"--root"* ]] || [[ "$full_args" == *"--isolated"* ]]; then
        echo "[$(date)] SECURITY: Guest user attempted pip bypass: $full_args" >> /var/log/adminhub/security.log 2>/dev/null || true
    fi
    
    # Add --user flag if installing and not already present
    if [[ "$1" == "install" ]] && [[ "$*" != *"--user"* ]]; then
        echo "ℹ️  Note: Installing to user directory (~/.local/)"
        set -- "$1" --user "${@:2}"
    fi
    
    # Ensure PIP_USER environment is set (defense in depth)
    export PIP_USER=1
    export PIP_DISABLE_PIP_VERSION_CHECK=1
    export PYTHONUSERBASE="$HOME/.local"
fi

exec "$ACTUAL_PIP" "$@"
