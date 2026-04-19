#!/bin/bash
# Copyright (c) 2025 Luka Löhr

set -euo pipefail

if [[ $EUID -ne 0 ]]; then
    echo "This script must be run as root." >&2
    exit 1
fi

chmod -R o+rX /opt/homebrew 2>/dev/null || true
chmod -R o+rX /usr/local/Homebrew 2>/dev/null || true

for tool in git python@3.12 python@3.13; do
    if [[ -d "/opt/homebrew/Cellar/$tool" ]]; then
        chmod -R o+rX "/opt/homebrew/Cellar/$tool"
    fi
done

if [[ -f "/opt/homebrew/bin/brew" ]]; then
    chmod o+rx "/opt/homebrew/bin/brew"
fi

if [[ -f "/usr/local/bin/brew" ]]; then
    chmod o+rx "/usr/local/bin/brew"
fi

chmod -R o+rX /opt/admin-tools 2>/dev/null || true

if [[ -f "/Library/LaunchAgents/com.schoolcode.guestsetup.plist" ]]; then
    chmod 644 /Library/LaunchAgents/com.schoolcode.guestsetup.plist
    chown root:wheel /Library/LaunchAgents/com.schoolcode.guestsetup.plist
fi
