#!/bin/bash
# Copyright (c) 2025 Luka Löhr

# SchoolCode Guest Auto Setup
# Runs automatically when the Guest user opens Terminal

# Only run for Guest user
if [[ "$(whoami)" != "Guest" ]]; then
    return 0 2>/dev/null || exit 0
fi

# Check if already initialized in this session
if [[ "$SCHOOLCODE_INITIALIZED" == "true" ]]; then
    return 0 2>/dev/null || exit 0
fi

# Mark as initialized
export SCHOOLCODE_INITIALIZED="true"

# Check if this is an interactive terminal
if [[ ! -t 0 ]]; then
    return 0 2>/dev/null || exit 0
fi

# SchoolCode installation and guest tools directories
SCHOOLCODE_DIR="/opt/schoolcode"
GUEST_TOOLS_DIR="/Users/Guest/tools"

# Always set up PATH to use SchoolCode tools directly (no copying)
clear
CURRENT_YEAR=$(date +%Y)
echo "╔══════════════════════════════════════╗"
echo "║       SchoolCode Guest Session       ║"
echo "║           © $CURRENT_YEAR Luka Löhr           ║"
echo "╚══════════════════════════════════════╝"
echo ""

# Configure PATH for Guest: SchoolCode bin, official Python, user pip bin
PYTHON_BIN_DIR="/Library/Frameworks/Python.framework/Versions/Current/bin"
if [[ -d "$PYTHON_BIN_DIR" ]]; then
    export PATH="$SCHOOLCODE_DIR/bin:$PYTHON_BIN_DIR:$HOME/.local/bin:$PATH"
else
    export PATH="$SCHOOLCODE_DIR/bin:$HOME/.local/bin:$PATH"
fi

# Configure pip to use user installs by default
export PIP_CONFIG_FILE="/opt/schoolcode/config/pip.conf"

