#!/bin/bash
# Copyright (c) 2025 Luka Löhr
#
# Setup Guest Shell Initialization
# Configures a LaunchAgent that sets up the Guest shell on every login

set -euo pipefail

# Get the project root directory
PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

# Source logging utilities
if [[ -f "$PROJECT_ROOT/scripts/utils/logging.sh" ]]; then
    source "$PROJECT_ROOT/scripts/utils/logging.sh"
fi

# Check for quiet mode
QUIET_MODE="${SCHOOLCODE_QUIET:-false}"

log_msg() {
    [[ "$QUIET_MODE" != "true" ]] && echo "$1"
    # Use centralized logging if available
    if declare -f log_guest >/dev/null 2>&1; then
        log_guest "INFO" "$1"
    fi
    return 0
}

log_operation_start "GUEST_SETUP" "Configuring Guest shell initialization"
log_msg "Setting up Guest shell initialization..."

# Check if running as root
if [ "$EUID" -ne 0 ]; then 
    echo "Please run with sudo" >&2
    exit 1
fi

# Copy the auto-setup script
log_msg "Installing auto-setup script..."
cp "$PROJECT_ROOT/scripts/guest_setup_auto.sh" /usr/local/bin/guest_setup_auto.sh
chmod 755 /usr/local/bin/guest_setup_auto.sh

# Copy the login-setup script
log_msg "Installing login-setup script..."
cp "$PROJECT_ROOT/scripts/setup/guest_login_setup.sh" /usr/local/bin/guest_login_setup
chmod 755 /usr/local/bin/guest_login_setup

# Install the LaunchAgent
log_msg "Installing LaunchAgent..."
DST_PLIST="/Library/LaunchAgents/com.schoolcode.guestsetup.plist"

# Write a clean LaunchAgent (no UserName in LaunchAgents)
cat > "$DST_PLIST" << 'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>com.schoolcode.guestsetup</string>
    <key>ProgramArguments</key>
    <array>
        <string>/usr/local/bin/guest_login_setup</string>
    </array>
    <key>RunAtLoad</key>
    <true/>
    <key>LimitLoadToSessionType</key>
    <string>Aqua</string>
    <key>StandardOutPath</key>
    <string>/tmp/schoolcode-setup.log</string>
    <key>StandardErrorPath</key>
    <string>/tmp/schoolcode-setup.err</string>
</dict>
</plist>
EOF

chown root:wheel "$DST_PLIST"
chmod 644 "$DST_PLIST"

# Validate the installed artifacts explicitly so callers do not report success
# after a partial copy/write failure.
[[ -x /usr/local/bin/guest_setup_auto.sh ]]
[[ -x /usr/local/bin/guest_login_setup ]]
[[ -f "$DST_PLIST" ]]

if [[ "$QUIET_MODE" != "true" ]]; then
    echo ""
    echo "Guest shell initialization configured."
    echo ""
    echo "Setup runs automatically when the Guest user opens Terminal."
    echo "No permission dialogs required."
fi

log_operation_end "GUEST_SETUP" "SUCCESS"
