#!/bin/bash
# Copyright (c) 2025 Luka Löhr

# Setup Guest Shell Initialization
# Configures a LaunchAgent that sets up the Guest shell on every login

set -e

echo "🔧 Setting up Guest shell initialization..."

# Check if running as root
if [ "$EUID" -ne 0 ]; then 
    echo "❌ Please run with sudo"
    exit 1
fi

# Copy the auto-setup script
echo "📋 Installing auto-setup script..."
cp scripts/guest_setup_auto.sh /usr/local/bin/
chmod 755 /usr/local/bin/guest_setup_auto.sh

# Copy the login-setup script
echo "📋 Installing login-setup script..."
cp scripts/setup/guest_login_setup.sh /usr/local/bin/guest_login_setup
chmod 755 /usr/local/bin/guest_login_setup

# Install the LaunchAgent
echo "🤖 Installing LaunchAgent..."
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

chown root:wheel "$DST_PLIST" 2>/dev/null || true
chmod 644 "$DST_PLIST"

# Load the LaunchAgent
# Do not attempt to load for the current user; it will load automatically on login per-user

# Note: The old com.schoolcode.guestterminal.plist is no longer needed
# Terminal is now opened by the guest_login_setup script

echo ""
echo "✅ Guest shell initialization configured!"
echo ""
echo "Setup runs automatically when the Guest user opens Terminal."
echo "No permission dialogs required! 🎉" 