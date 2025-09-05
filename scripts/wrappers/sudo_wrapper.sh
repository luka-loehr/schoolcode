#!/bin/bash
# Sudo wrapper - completely blocks sudo for Guest users
# AdminHub - Version 2.1.0

# Check if running as Guest
if [[ "$USER" == "Guest" ]]; then
    echo "❌ Error: sudo is not available for Guest users"
    echo ""
    echo "   Guest users cannot use sudo for security reasons."
    echo "   This prevents system-wide modifications and ensures"
    echo "   a clean environment for all users."
    echo ""
    echo "   If you need to install packages, use:"
    echo "   • pip install --user <package>     (for Python packages)"
    echo "   • npm install <package>            (for Node.js packages)"
    echo "   • Contact administrator for system packages"
    
    # Log the attempt
    echo "[$(date)] SECURITY: Guest user attempted sudo: sudo $*" >> /var/log/adminhub/security.log 2>/dev/null || true
    
    exit 1
fi

# For non-Guest users, try to find and execute the original sudo
# Look for backup first
ORIGINAL_SUDO="/opt/admin-tools/actual-direct-backups/original-sudo"
if [[ -x "$ORIGINAL_SUDO" ]]; then
    exec "$ORIGINAL_SUDO" "$@"
fi

# Fallback to system sudo
if command -v sudo >/dev/null 2>&1; then
    exec sudo "$@"
fi

# Last resort - show error
echo "❌ Error: Cannot find sudo command"
echo "   AdminHub installation may be corrupted. Contact administrator."
exit 1
