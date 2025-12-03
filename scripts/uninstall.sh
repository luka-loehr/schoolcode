#!/bin/bash
# Copyright (c) 2025 Luka Löhr
#
# SchoolCode Uninstallation
# Removes all installed components

set -e

# Get script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Source centralized logging
if [[ -f "$SCRIPT_DIR/utils/logging.sh" ]]; then
    source "$SCRIPT_DIR/utils/logging.sh"
fi

# Check if running with sudo
if [ "$EUID" -ne 0 ]; then 
    echo "Error: Please run with sudo: sudo ./uninstall.sh"
    exit 1
fi

# Start operation
if declare -f log_operation_start >/dev/null 2>&1; then
    log_operation_start "UNINSTALL" "Removing SchoolCode"
fi

# Only show prompt if not called from CLI
if [ "$SCHOOLCODE_CLI_UNINSTALL" != "true" ]; then
    echo "SchoolCode Uninstallation"
    echo ""
    echo "This will remove:"
    echo "  - LaunchAgents"
    echo "  - Guest setup scripts"
    echo "  - Admin tools directory"
    echo "  - Logs and temporary files"
    echo ""
    echo -n "Continue? (y/N): "
    read -r response
    if [[ ! "$response" =~ ^[yY]$ ]]; then
        echo "Cancelled."
        exit 0
    fi
    echo ""
fi

# Remove LaunchAgents
launchctl unload /Library/LaunchAgents/com.schoolcode.guestsetup.plist 2>/dev/null || true
rm -f /Library/LaunchAgents/com.schoolcode.guestsetup.plist
rm -f /Library/LaunchAgents/com.schoolcode.guestterminal.plist

# Remove scripts
rm -f /usr/local/bin/guest_login_setup
rm -f /usr/local/bin/guest_setup_auto.sh
rm -f /usr/local/bin/guest_setup_final.sh
rm -f /usr/local/bin/guest_setup_background.sh
rm -f /usr/local/bin/guest_tools_setup.sh
rm -f /usr/local/bin/simple_guest_setup.sh
rm -f /usr/local/bin/open_guest_terminal

# Remove any additional SchoolCode LaunchAgents/Daemons
for plist in /Library/LaunchAgents/com.schoolcode.*.plist /Library/LaunchDaemons/com.schoolcode.*.plist; do
    [ -f "$plist" ] && launchctl unload "$plist" 2>/dev/null || true
    [ -f "$plist" ] && rm -f "$plist"
done

# Remove auto-update version tracking
rm -f /Library/SchoolCode/.installedversion

# Remove SchoolCode installation directory (wrappers, symlinks, configs)
rm -rf /opt/schoolcode

# Remove legacy admin tools directory if present
rm -rf /opt/admin-tools

# Clean up logs
rm -f /tmp/schoolcode-*.log
rm -f /tmp/schoolcode-*.err
rm -rf /var/log/schoolcode

# Remove PATH entries from admin user's shell configs
# (Silent - no output needed)

# Determine the original (admin) user who ran sudo
ORIGINAL_USER="${SUDO_USER:-$(whoami)}"
if [ "$ORIGINAL_USER" = "root" ] || [ -z "$ORIGINAL_USER" ]; then
    ORIGINAL_USER=$(stat -f "%Su" /dev/console 2>/dev/null || echo "")
fi

# Resolve the admin user's home directory on macOS
if [ -n "$ORIGINAL_USER" ]; then
    USER_HOME=$(dscl . -read /Users/"$ORIGINAL_USER" NFSHomeDirectory 2>/dev/null | awk '{print $2}')
fi

# Fallback if dscl didn't return a path
if [ -z "$USER_HOME" ] && [ -n "$ORIGINAL_USER" ]; then
    USER_HOME="/Users/$ORIGINAL_USER"
fi

if [ -n "$USER_HOME" ] && [ -d "$USER_HOME" ]; then
    for shell_config in ".zshrc" ".bashrc" ".bash_profile"; do
        CONFIG_FILE="$USER_HOME/$shell_config"
        if [ -f "$CONFIG_FILE" ]; then
            # Remove the exact block added by installer:
            #   # SchoolCode Tools (added by installer)
            #   export PATH="/opt/schoolcode/bin:$PATH"
            sed -i '' -e '/# SchoolCode Tools (added by installer)/,+1 d' "$CONFIG_FILE" 2>/dev/null || true
        fi
    done
fi

# End operation
if declare -f log_operation_end >/dev/null 2>&1; then
    log_operation_end "UNINSTALL" "SUCCESS"
fi

# Only show completion message if not called from CLI
if [ "$SCHOOLCODE_CLI_UNINSTALL" != "true" ]; then
    echo "Uninstallation completed."
    echo ""
    echo "Note: Homebrew and packages (git, python) were NOT removed."
fi
