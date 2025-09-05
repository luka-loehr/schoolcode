#!/bin/bash
# Binary protection wrapper - secures direct binary access
# AdminHub - Version 2.1.0

# Determine what binary this wrapper represents based on its path
WRAPPER_PATH="$(readlink -f "$0" 2>/dev/null || realpath "$0" 2>/dev/null || echo "$0")"
BINARY_NAME="$(basename "$WRAPPER_PATH")"

# Map binary names to AdminHub wrappers
get_adminhub_wrapper() {
    case "$BINARY_NAME" in
        "brew")
            echo "/opt/admin-tools/bin/brew"
            ;;
        "git")
            echo "/opt/admin-tools/bin/git"
            ;;
        "pip"|"pip3")
            echo "/opt/admin-tools/bin/pip"
            ;;
        "python"|"python3"|"python3.13"|"python3.12"|"python3.11")
            echo "/opt/admin-tools/bin/python"
            ;;
        *)
            echo ""
            ;;
    esac
}

ADMINHUB_WRAPPER=$(get_adminhub_wrapper)

# Check if running as Guest user
if [[ "$USER" == "Guest" ]]; then
    if [[ -n "$ADMINHUB_WRAPPER" && -x "$ADMINHUB_WRAPPER" ]]; then
        echo "❌ Error: Direct access to $BINARY_NAME is not allowed for Guest users"
        echo "   Use the AdminHub-provided command instead:"
        case "$BINARY_NAME" in
            "brew")
                echo "   • Contact administrator for system package installations"
                echo "   • Use pip install --user <package> for Python packages"
                ;;
            "git")
                echo "   • git <command>  (uses secure AdminHub git wrapper)"
                ;;
            "pip"|"pip3")
                echo "   • pip install <package>  (installs safely to ~/.local/)"
                ;;
            "python"|"python3"|"python3.13"|"python3.12"|"python3.11")
                echo "   • python <script.py>     (uses secure AdminHub python wrapper)"
                echo "   • python -c '<code>'     (with security restrictions)"
                ;;
        esac
        echo ""
        echo "   This restriction prevents bypassing AdminHub security controls."
        
        # Log the attempt
        echo "[$(date)] SECURITY: Guest user attempted direct binary access: $WRAPPER_PATH $*" >> /var/log/adminhub/security.log 2>/dev/null || true
        exit 1
    else
        echo "❌ Error: Binary $BINARY_NAME is not available for Guest users"
        echo "   Contact your administrator if you need access to this tool."
        
        # Log the attempt
        echo "[$(date)] SECURITY: Guest user attempted unavailable binary: $WRAPPER_PATH $*" >> /var/log/adminhub/security.log 2>/dev/null || true
        exit 1
    fi
fi

# For non-Guest users, try to find and execute the original binary
# Look for backup first
ORIGINAL_BINARY="/opt/admin-tools/actual-direct-backups/original-$BINARY_NAME"
if [[ -x "$ORIGINAL_BINARY" ]]; then
    exec "$ORIGINAL_BINARY" "$@"
fi

# Fallback to AdminHub wrapper even for non-Guest users (for consistency)
if [[ -n "$ADMINHUB_WRAPPER" && -x "$ADMINHUB_WRAPPER" ]]; then
    exec "$ADMINHUB_WRAPPER" "$@"
fi

# Last resort - show error
echo "❌ Error: Cannot find original binary for $BINARY_NAME"
echo "   AdminHub installation may be corrupted. Contact administrator."
exit 1
