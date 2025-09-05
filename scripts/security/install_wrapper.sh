#!/bin/bash
# Install wrapper - blocks dangerous install commands for Guest users
# AdminHub - Version 2.1.0

# Check if running as Guest
if [[ "$USER" == "Guest" ]]; then
    echo "❌ Error: Direct install commands are not allowed for Guest users"
    echo ""
    echo "   Guest users cannot use direct install commands for security reasons."
    echo "   This prevents system-wide modifications and ensures"
    echo "   a clean environment for all users."
    echo ""
    echo "   Use the appropriate package manager instead:"
    echo "   • pip install --user <package>     (for Python packages)"
    echo "   • npm install <package>            (for Node.js packages)"
    echo "   • yarn add <package>               (for Node.js packages)"
    echo "   • Contact administrator for system packages"
    
    # Log the attempt
    echo "[$(date)] SECURITY: Guest user attempted direct install: $0 $*" >> /var/log/adminhub/security.log 2>/dev/null || true
    
    exit 1
fi

# For non-Guest users, try to find and execute the original install command
# Look for backup first
ORIGINAL_INSTALL="/opt/admin-tools/actual-direct-backups/original-install"
if [[ -x "$ORIGINAL_INSTALL" ]]; then
    exec "$ORIGINAL_INSTALL" "$@"
fi

# Fallback to system install
if command -v install >/dev/null 2>&1; then
    exec install "$@"
fi

# Last resort - show error
echo "❌ Error: Cannot find install command"
echo "   AdminHub installation may be corrupted. Contact administrator."
exit 1
