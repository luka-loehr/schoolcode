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
WORKSPACE_DIR="$HOME/SchoolCode"

# Script version
VERSION="3.0.0"

tool_version() {
    local tool_name="$1"
    shift

    if command -v "$tool_name" >/dev/null 2>&1; then
        "$tool_name" "$@" 2>/dev/null | head -1
    else
        echo "not available"
    fi
}

print_line() {
    printf '%s\n' "------------------------------------------------------------"
}

# Configure PATH for Guest: SchoolCode bin, official Python, user pip bin
PYTHON_BIN_DIR="/Library/Frameworks/Python.framework/Versions/Current/bin"
if [[ -d "$PYTHON_BIN_DIR" ]]; then
    export PATH="$SCHOOLCODE_DIR/bin:$PYTHON_BIN_DIR:$HOME/.local/bin:$PATH"
else
    export PATH="$SCHOOLCODE_DIR/bin:$HOME/.local/bin:$PATH"
fi

# Configure pip to use user installs by default
export PIP_CONFIG_FILE="/opt/schoolcode/config/pip.conf"

mkdir -p "$WORKSPACE_DIR" 2>/dev/null || true

# Display welcome banner after PATH is configured so version checks resolve
clear
YEAR=$(date +%Y)
PYTHON_INFO="$(tool_version python3 --version)"
GIT_INFO="$(tool_version git --version)"
BREW_INFO="$(tool_version brew --version)"

cat <<EOF
============================================================
SchoolCode v$VERSION
Shared coding environment for this Mac
© $YEAR Luka Löhr
============================================================

Welcome. This Guest session is ready for coding.

Workspace
  $WORKSPACE_DIR

Available tools
  $PYTHON_INFO
  $GIT_INFO
  $BREW_INFO

Session rules
  Files in the Guest account are temporary and reset on logout.
  Python packages install to your user space by default.
  Homebrew tools are available from the shared install on this Mac.

Quick start
  cd "$WORKSPACE_DIR"
  python3 --version
  python3
  git --version

Tip
  Start by creating a file in "$WORKSPACE_DIR" so your work stays easy to find
  during this session.

EOF

print_line
