#!/bin/bash
# Copyright (c) 2025 Luka Löhr

if [[ "$(whoami)" != "Guest" ]]; then
    return 0 2>/dev/null || exit 0
fi

if [[ "${SCHOOLCODE_INITIALIZED:-false}" == "true" ]]; then
    return 0 2>/dev/null || exit 0
fi
export SCHOOLCODE_INITIALIZED="true"

if [[ ! -t 0 ]]; then
    return 0 2>/dev/null || exit 0
fi

SCHOOLCODE_DIR="/opt/schoolcode"
WORKSPACE_DIR="$HOME/SchoolCode"
VERSION="3.0.0"

if [[ -f "$SCHOOLCODE_DIR/utils/ui.sh" ]]; then
    source "$SCHOOLCODE_DIR/utils/ui.sh"
else
    SCHOOLCODE_UI_MODE=plain
    ui_header() { printf '\n%s\n%s\n\n' "$1" "${2:-}"; }
    ui_section() { printf '%s\n' "$1"; }
    ui_key_value() { printf '  %-12s %s\n' "$1" "$2"; }
    ui_list() {
        shift || true
        local item
        for item in "$@"; do
            printf '  - %s\n' "$item"
        done
    }
fi

tool_version() {
    local tool_name="$1"
    shift

    if command -v "$tool_name" >/dev/null 2>&1; then
        "$tool_name" "$@" 2>/dev/null | head -1
    else
        echo "not available"
    fi
}

PYTHON_BIN_DIR="/Library/Frameworks/Python.framework/Versions/Current/bin"
if [[ -d "$PYTHON_BIN_DIR" ]]; then
    export PATH="$SCHOOLCODE_DIR/bin:$PYTHON_BIN_DIR:$HOME/.local/bin:$PATH"
else
    export PATH="$SCHOOLCODE_DIR/bin:$HOME/.local/bin:$PATH"
fi

export PIP_CONFIG_FILE="/opt/schoolcode/config/pip.conf"
mkdir -p "$WORKSPACE_DIR" 2>/dev/null || true

clear

PYTHON_INFO="$(tool_version python3 --version)"
GIT_INFO="$(tool_version git --version)"
BREW_INFO="$(tool_version brew --version)"

ui_header "SchoolCode v$VERSION" "Guest coding environment"
ui_section "Workspace"
ui_key_value "Path" "$WORKSPACE_DIR"

ui_section "Available tools"
ui_key_value "Python" "$PYTHON_INFO"
ui_key_value "Git" "$GIT_INFO"
ui_key_value "Homebrew" "$BREW_INFO"

ui_section "Session rules"
ui_list info \
    "Files in the Guest account reset when you log out." \
    "Python packages install to your user space by default." \
    "Homebrew tools are available from the shared install on this Mac."

ui_section "Quick start"
ui_list info \
    "cd \"$WORKSPACE_DIR\"" \
    "python3 --version" \
    "python3" \
    "git --version"
