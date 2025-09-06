#!/bin/bash
# Copyright (c) 2025 Luka Löhr

# SchoolCode Guest Login Setup
# Runs automatically when the Guest user logs in (via LaunchAgent)

# Only run for Guest user
if [[ "$(whoami)" != "Guest" ]]; then
    exit 0
fi

# Log startup
echo "[$(date)] Guest Login Setup started" >> /tmp/schoolcode-setup.log

# Guest home directory (recreated on every login)
GUEST_HOME="/Users/Guest"

# Wait briefly until the home directory is fully created
sleep 1

# Create pip configuration for Guest user
echo "[$(date)] Creating pip configuration" >> /tmp/schoolcode-setup.log
mkdir -p "$GUEST_HOME/.config/pip"
cat > "$GUEST_HOME/.config/pip/pip.conf" << 'EOF'
[global]
break-system-packages = true
user = true
EOF
chmod 644 "$GUEST_HOME/.config/pip/pip.conf" 2>/dev/null || true

# Create .zshrc with our auto-setup
echo "[$(date)] Creating .zshrc" >> /tmp/schoolcode-setup.log
cat > "$GUEST_HOME/.zshrc" << 'EOF'
# SchoolCode Guest Setup
# Automatically generated at login

# Load the auto-setup script
if [ -f /usr/local/bin/guest_setup_auto.sh ]; then
    source /usr/local/bin/guest_setup_auto.sh
fi
EOF

# Create .bash_profile for Bash compatibility
echo "[$(date)] Creating .bash_profile" >> /tmp/schoolcode-setup.log
cat > "$GUEST_HOME/.bash_profile" << 'EOF'
# SchoolCode Guest Setup
# Automatically generated at login

# Load the auto-setup script
if [ -f /usr/local/bin/guest_setup_auto.sh ]; then
    source /usr/local/bin/guest_setup_auto.sh
fi
EOF

# Set permissions
chmod 644 "$GUEST_HOME/.zshrc" "$GUEST_HOME/.bash_profile" 2>/dev/null || true

# Automatically open Terminal
echo "[$(date)] Opening Terminal" >> /tmp/schoolcode-setup.log
/usr/bin/open -a Terminal

echo "[$(date)] Guest Login Setup completed" >> /tmp/schoolcode-setup.log 