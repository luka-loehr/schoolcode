#!/bin/bash
# Homebrew wrapper for Guest users with security restrictions
# AdminHub - Version 2.1.0

# Find the actual brew executable
find_actual_brew() {
    # First try the backed up original binaries
    if [ -x "/opt/admin-tools/actual-direct-backups/original-brew" ]; then
        echo "/opt/admin-tools/actual-direct-backups/original-brew"
        return
    fi
    
    # Then check if we have a direct symlink
    if [ -L "/opt/admin-tools/actual/bin/brew" ]; then
        local target=$(readlink "/opt/admin-tools/actual/bin/brew")
        if [ -x "$target" ]; then
            echo "$target"
            return
        fi
    fi
    
    # Otherwise search in common locations
    local brew_locations=(
        "/opt/homebrew/bin/brew"
        "/usr/local/bin/brew"
    )
    
    for location in "${brew_locations[@]}"; do
        if [ -x "$location" ]; then
            echo "$location"
            return
        fi
    done
    
    # Fallback to which
    which brew 2>/dev/null || echo ""
}

ACTUAL_BREW=$(find_actual_brew)

if [ -z "$ACTUAL_BREW" ]; then
    echo "❌ Error: Homebrew not found"
    exit 1
fi

# Check if running as Guest - block all access
if [[ "$USER" == "Guest" ]]; then
    echo "❌ Error: Homebrew operations are not allowed for Guest users"
    echo ""
    echo "   Guest users cannot install or manage system packages with Homebrew."
    echo "   This restriction prevents system-wide changes and security bypasses."
    echo ""
    echo "   Available alternatives:"
    echo "   • pip install --user <package>     (install Python packages)"
    echo "   • Use existing installed tools      (git, python, etc.)"
    echo "   • Contact administrator for system package installations"
    
    # Log the attempt
    echo "[$(date)] SECURITY: Guest user attempted Homebrew access: brew $*" >> /var/log/adminhub/security.log 2>/dev/null || true
    
    # Check what command they were trying to run for better guidance
    case "$1" in
        "install")
            echo ""
            echo "   Note: If you need to install '$2', try:"
            echo "   • pip install --user $2    (if it's a Python package)"
            ;;
        "list"|"search"|"info"|"--version"|"--help")
            echo ""
            echo "   Note: Read-only Homebrew commands are also restricted for security."
            echo "   Contact your administrator if you need package information."
            ;;
    esac
    
    exit 1
fi

# For non-Guest users, execute normally
exec "$ACTUAL_BREW" "$@"
