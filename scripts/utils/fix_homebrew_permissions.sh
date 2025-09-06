#!/bin/bash
# Copyright (c) 2025 Luka Löhr

# Fix Homebrew permissions so Guest can use the tools


# Make Homebrew directories readable for all
sudo chmod -R o+rX /opt/homebrew 2>/dev/null || true
sudo chmod -R o+rX /usr/local/Homebrew 2>/dev/null || true

# Fix permissions for installed tools (only if they exist)
for tool in git python@3.12 python@3.13; do
    if [ -d "/opt/homebrew/Cellar/$tool" ]; then
        sudo chmod -R o+rX "/opt/homebrew/Cellar/$tool"
    fi
done

# Fix permissions for brew command itself
if [ -f "/opt/homebrew/bin/brew" ]; then
    sudo chmod o+rx "/opt/homebrew/bin/brew"
fi
if [ -f "/usr/local/bin/brew" ]; then
    sudo chmod o+rx "/usr/local/bin/brew"
fi

# Fix permissions for admin tools directory
sudo chmod -R o+rX /opt/admin-tools 2>/dev/null || true

# Fix LaunchAgent permissions
if [ -f "/Library/LaunchAgents/com.schoolcode.guestsetup.plist" ]; then
    sudo chmod 644 /Library/LaunchAgents/com.schoolcode.guestsetup.plist
    sudo chown root:wheel /Library/LaunchAgents/com.schoolcode.guestsetup.plist
fi

 