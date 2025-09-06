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
cp launchagents/com.schoolcode.guestsetup.plist /Library/LaunchAgents/
chmod 644 /Library/LaunchAgents/com.schoolcode.guestsetup.plist

# Load the LaunchAgent
launchctl load /Library/LaunchAgents/com.schoolcode.guestsetup.plist 2>/dev/null || true

# Note: The old com.schoolcode.guestterminal.plist is no longer needed
# Terminal is now opened by the guest_login_setup script

echo ""
echo "✅ Guest shell initialization configured!"
echo ""
echo "Setup runs automatically when the Guest user opens Terminal."
echo "No permission dialogs required! 🎉" 