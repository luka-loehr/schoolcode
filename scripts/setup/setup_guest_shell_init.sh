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
# Use the repository's LaunchAgent file and install with the expected lowercase name
SRC_PLIST="SchoolCode_launchagents/com.SchoolCode.guestsetup.plist"
DST_PLIST="/Library/LaunchAgents/com.schoolcode.guestsetup.plist"
if [ ! -f "$SRC_PLIST" ]; then
    echo "❌ LaunchAgent source not found: $SRC_PLIST"
    exit 1
fi
cp "$SRC_PLIST" "$DST_PLIST"
chmod 644 "$DST_PLIST"

# Load the LaunchAgent
launchctl load "$DST_PLIST" 2>/dev/null || true

# Note: The old com.schoolcode.guestterminal.plist is no longer needed
# Terminal is now opened by the guest_login_setup script

echo ""
echo "✅ Guest shell initialization configured!"
echo ""
echo "Setup runs automatically when the Guest user opens Terminal."
echo "No permission dialogs required! 🎉" 