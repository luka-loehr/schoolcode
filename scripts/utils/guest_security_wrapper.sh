#!/bin/bash
# Copyright (c) 2025 Luka Löhr
#
# Guest Security Wrapper - Prevents system-wide installations
# This script creates secure wrapper scripts for all tools

set -euo pipefail

SCRIPT_DIR="$(dirname "$0")"
source "${SCRIPT_DIR}/logging.sh"

WRAPPERS_DIR="/opt/schoolcode/wrappers"
ACTUAL_TOOLS_DIR="/opt/schoolcode/actual"

# Create wrapper directories
create_wrapper_structure() {
    log_info "Creating security wrapper structure..."
    
    # Create directories
    mkdir -p "$WRAPPERS_DIR"
    mkdir -p "$ACTUAL_TOOLS_DIR/bin"
    
    # Set permissions
    chmod 755 "$WRAPPERS_DIR"
    chmod 755 "$ACTUAL_TOOLS_DIR"
}

# Create brew wrapper that blocks dangerous operations
create_brew_wrapper() {
    log_info "Creating Homebrew security wrapper..."
    
    cat > "$WRAPPERS_DIR/brew" << 'EOF'
#!/bin/bash
# Homebrew wrapper for Guest users - blocks system modifications

# Find the actual brew executable
find_actual_brew() {
    # First check if we have a direct symlink
    if [ -L "/opt/schoolcode/actual/bin/brew" ]; then
        local target=$(readlink "/opt/schoolcode/actual/bin/brew")
        if [ -x "$target" ]; then
            echo "$target"
            return
        fi
    fi
    
    # Otherwise search for brew in common locations
    local brew_locations=(
        "/opt/homebrew/bin/brew"
        "/usr/local/bin/brew"
        "/usr/local/Homebrew/bin/brew"
        "/home/linuxbrew/.linuxbrew/bin/brew"
    )
    
    for location in "${brew_locations[@]}"; do
        if [ -x "$location" ]; then
            echo "$location"
            return
        fi
    done
    
    # Fallback to which
    which brew 2>/dev/null || echo ""
}

ACTUAL_BREW=$(find_actual_brew)

if [ -z "$ACTUAL_BREW" ]; then
    echo "❌ Error: Homebrew not found"
    exit 1
fi

# Check if running as Guest
if [[ "$USER" == "Guest" ]]; then
    # Block dangerous commands
    case "$1" in
        install|uninstall|upgrade|update|tap|untap|link|unlink|pin|unpin)
            echo "❌ Error: System-wide modifications are not allowed for Guest users"
            echo "   Command '$1' has been blocked for security reasons"
            exit 1
            ;;
        reinstall|remove|rm|cleanup)
            echo "❌ Error: System-wide modifications are not allowed for Guest users"
            echo "   Command '$1' has been blocked for security reasons"
            exit 1
            ;;
        *)
            # Allow safe read-only commands
            exec "$ACTUAL_BREW" "$@"
            ;;
    esac
else
    # Non-guest users get full access
    exec "$ACTUAL_BREW" "$@"
fi
EOF
    
    chmod 755 "$WRAPPERS_DIR/brew"
}

# Create Python/pip wrapper that forces user installations
create_python_wrapper() {
    log_info "Creating Python security wrappers..."
    
    # Python wrapper
    cat > "$WRAPPERS_DIR/python" << 'EOF'
#!/bin/bash
# Python wrapper for Guest users

# Find the actual python executable
find_actual_python() {
    # First check if we have a direct symlink
    if [ -L "/opt/schoolcode/actual/bin/python" ]; then
        local target=$(readlink "/opt/schoolcode/actual/bin/python")
        if [ -x "$target" ]; then
            echo "$target"
            return
        fi
    fi
    
    # Fallback to python3 if python doesn't exist
    if [ -L "/opt/schoolcode/actual/bin/python3" ]; then
        local target=$(readlink "/opt/schoolcode/actual/bin/python3")
        if [ -x "$target" ]; then
            echo "$target"
            return
        fi
    fi
    
    # Otherwise search in common locations
    local python_locations=(
        "/opt/homebrew/opt/python@3.13/libexec/bin/python"
        "/opt/homebrew/opt/python@3.12/libexec/bin/python"
        "/opt/homebrew/opt/python@3.11/libexec/bin/python"
        "/usr/local/opt/python@3.13/libexec/bin/python"
        "/usr/local/opt/python@3.12/libexec/bin/python"
        "/usr/local/opt/python@3.11/libexec/bin/python"
        "/opt/homebrew/bin/python3"
        "/usr/local/bin/python3"
    )
    
    for location in "${python_locations[@]}"; do
        if [ -x "$location" ]; then
            echo "$location"
            return
        fi
    done
    
    # Fallback to which
    which python3 2>/dev/null || which python 2>/dev/null || echo ""
}

ACTUAL_PYTHON=$(find_actual_python)

if [ -z "$ACTUAL_PYTHON" ]; then
    echo "❌ Error: Python not found"
    exit 1
fi

# Set secure environment for Guest
if [[ "$USER" == "Guest" ]]; then
    # Force user installations
    export PIP_USER=1
    export PYTHONUSERBASE="$HOME/.local"
    export PIP_NO_WARN_SCRIPT_LOCATION=1
    
    # Disable system-wide operations
    export PIP_REQUIRE_VIRTUALENV=false
    export PIP_DISABLE_PIP_VERSION_CHECK=1
fi

exec "$ACTUAL_PYTHON" "$@"
EOF
    
    # Python3 wrapper (same as python)
    cp "$WRAPPERS_DIR/python" "$WRAPPERS_DIR/python3"
    
    # Pip wrapper with extra protection
    cat > "$WRAPPERS_DIR/pip" << 'EOF'
#!/bin/bash
# Pip wrapper for Guest users - forces user installations

# Find the actual pip executable
find_actual_pip() {
    # First check if we have a direct symlink
    if [ -L "/opt/schoolcode/actual/bin/pip" ]; then
        local target=$(readlink "/opt/schoolcode/actual/bin/pip")
        if [ -x "$target" ]; then
            echo "$target"
            return
        fi
    fi
    
    # Fallback to pip3 if pip doesn't exist
    if [ -L "/opt/schoolcode/actual/bin/pip3" ]; then
        local target=$(readlink "/opt/schoolcode/actual/bin/pip3")
        if [ -x "$target" ]; then
            echo "$target"
            return
        fi
    fi
    
    # Otherwise search in common locations
    local pip_locations=(
        "/opt/homebrew/opt/python@3.13/libexec/bin/pip"
        "/opt/homebrew/opt/python@3.12/libexec/bin/pip"
        "/opt/homebrew/opt/python@3.11/libexec/bin/pip"
        "/usr/local/opt/python@3.13/libexec/bin/pip"
        "/usr/local/opt/python@3.12/libexec/bin/pip"
        "/usr/local/opt/python@3.11/libexec/bin/pip"
        "/opt/homebrew/bin/pip3"
        "/usr/local/bin/pip3"
    )
    
    for location in "${pip_locations[@]}"; do
        if [ -x "$location" ]; then
            echo "$location"
            return
        fi
    done
    
    # Fallback to which
    which pip3 2>/dev/null || which pip 2>/dev/null || echo ""
}

ACTUAL_PIP=$(find_actual_pip)

if [ -z "$ACTUAL_PIP" ]; then
    echo "❌ Error: pip not found"
    exit 1
fi

# Check if running as Guest
if [[ "$USER" == "Guest" ]]; then
    # Force user installation
    export PIP_USER=1
    export PYTHONUSERBASE="$HOME/.local"
    
    # Check for dangerous flags
    for arg in "$@"; do
        case "$arg" in
            --target|--prefix|--root|-t)
                echo "❌ Error: System installation flags are not allowed for Guest users"
                echo "   All packages will be installed to your user directory"
                exit 1
                ;;
            --upgrade-strategy)
                # Allow but ignore
                ;;
        esac
    done
    
    # Check if trying to use sudo
    if [[ -n "${SUDO_USER:-}" ]]; then
        echo "❌ Error: sudo pip is not allowed for Guest users"
        exit 1
    fi
    
    # Add --user flag if installing
    if [[ "$1" == "install" ]] && [[ "$*" != *"--user"* ]]; then
        echo "ℹ️  Note: Installing to user directory (~/.local/)"
        set -- "$1" --user "${@:2}"
    fi
fi

exec "$ACTUAL_PIP" "$@"
EOF
    
    # Pip3 wrapper (same as pip)
    cp "$WRAPPERS_DIR/pip" "$WRAPPERS_DIR/pip3"
    
    chmod 755 "$WRAPPERS_DIR/python" "$WRAPPERS_DIR/python3"
    chmod 755 "$WRAPPERS_DIR/pip" "$WRAPPERS_DIR/pip3"
}

# Create git wrapper that prevents system config changes
create_git_wrapper() {
    log_info "Creating Git security wrapper..."
    
    cat > "$WRAPPERS_DIR/git" << 'EOF'
#!/bin/bash
# Git wrapper for Guest users - prevents system config changes

# Find the actual git executable
find_actual_git() {
    # First check if we have a direct symlink
    if [ -L "/opt/schoolcode/actual/bin/git" ]; then
        local target=$(readlink "/opt/schoolcode/actual/bin/git")
        if [ -x "$target" ]; then
            echo "$target"
            return
        fi
    fi
    
    # Otherwise use which to find git
    which git 2>/dev/null || echo ""
}

ACTUAL_GIT=$(find_actual_git)

if [ -z "$ACTUAL_GIT" ]; then
    echo "❌ Error: Git not found"
    exit 1
fi

# Check if running as Guest
if [[ "$USER" == "Guest" ]]; then
    # Block system-wide config changes
    if [[ "$1" == "config" ]]; then
        for arg in "$@"; do
            if [[ "$arg" == "--system" ]]; then
                echo "❌ Error: System-wide git config is not allowed for Guest users"
                echo "   Use --global for your personal settings"
                exit 1
            fi
        done
    fi
fi

exec "$ACTUAL_GIT" "$@"
EOF
    
    chmod 755 "$WRAPPERS_DIR/git"
}

# Create npm wrapper (if npm is available)
create_npm_wrapper() {
    if [[ -f "/opt/schoolcode/actual/bin/npm" ]]; then
        log_info "Creating npm security wrapper..."
        
        cat > "$WRAPPERS_DIR/npm" << 'EOF'
#!/bin/bash
# NPM wrapper for Guest users - prevents global installations

ACTUAL_NPM="/opt/schoolcode/actual/bin/npm"

# Check if running as Guest
if [[ "$USER" == "Guest" ]]; then
    # Block global installations
    for arg in "$@"; do
        if [[ "$arg" == "-g" ]] || [[ "$arg" == "--global" ]]; then
            echo "❌ Error: Global npm installations are not allowed for Guest users"
            echo "   Remove -g flag to install locally"
            exit 1
        fi
    done
    
    # Set npm prefix to user directory
    export NPM_CONFIG_PREFIX="$HOME/.npm-global"
fi

exec "$ACTUAL_NPM" "$@"
EOF
        
        chmod 755 "$WRAPPERS_DIR/npm"
    fi
}

# Create gem wrapper (if Ruby gems are available)
create_gem_wrapper() {
    if [[ -f "/opt/schoolcode/actual/bin/gem" ]]; then
        log_info "Creating gem security wrapper..."
        
        cat > "$WRAPPERS_DIR/gem" << 'EOF'
#!/bin/bash
# Gem wrapper for Guest users - forces user installations

ACTUAL_GEM="/opt/schoolcode/actual/bin/gem"

# Check if running as Guest
if [[ "$USER" == "Guest" ]]; then
    # Force user installation
    if [[ "$1" == "install" ]] && [[ "$*" != *"--user-install"* ]]; then
        set -- "$1" --user-install "${@:2}"
    fi
fi

exec "$ACTUAL_GEM" "$@"
EOF
        
        chmod 755 "$WRAPPERS_DIR/gem"
    fi
}

# Update symlinks to point to wrappers instead of actual tools
update_symlinks_to_wrappers() {
    log_info "Updating symlinks to use security wrappers..."
    
    local admin_bin="/opt/schoolcode/bin"
    
    # For each wrapper we created, update the symlink
    for wrapper in "$WRAPPERS_DIR"/*; do
        if [[ -f "$wrapper" ]]; then
            local tool_name=$(basename "$wrapper")
            log_debug "Updating symlink for $tool_name"
            
            # Remove old symlink
            rm -f "$admin_bin/$tool_name"
            
            # Create new symlink to wrapper
            ln -sf "$wrapper" "$admin_bin/$tool_name"
        fi
    done
}

# Move actual tools to secure location
move_actual_tools() {
    log_info "Moving actual tools to secure location..."
    
    local admin_bin="/opt/schoolcode/bin"
    
    # Move real tool symlinks to actual directory
    for tool in brew python python3 pip pip3 git npm gem; do
        if [[ -L "$admin_bin/$tool" ]] && [[ ! -f "$WRAPPERS_DIR/$tool" ]]; then
            # Get the target of the symlink
            local target=$(readlink "$admin_bin/$tool" 2>/dev/null || true)
            if [[ -n "$target" ]]; then
                log_debug "Moving $tool -> $target"
                ln -sf "$target" "$ACTUAL_TOOLS_DIR/bin/$tool"
            fi
        fi
    done
}

# Create comprehensive security environment script
create_security_environment() {
    log_info "Creating security environment script..."
    
    cat > "$WRAPPERS_DIR/guest_security_env.sh" << 'EOF'
#!/bin/bash
# Security environment for Guest users

if [[ "$USER" == "Guest" ]]; then
    # Python security
    export PIP_USER=1
    export PYTHONUSERBASE="$HOME/.local"
    export PIP_NO_WARN_SCRIPT_LOCATION=1
    export PIP_DISABLE_PIP_VERSION_CHECK=1
    
    # NPM security
    export NPM_CONFIG_PREFIX="$HOME/.npm-global"
    
    # Ruby security
    export GEM_USER_INSTALL=1
    
    # Homebrew security
    export HOMEBREW_NO_INSTALL_UPGRADE=1
    export HOMEBREW_NO_AUTO_UPDATE=1
    
    # Path modifications - prioritize user installations
    export PATH="$HOME/.local/bin:$HOME/.npm-global/bin:$PATH"
    
    # Aliases for extra safety
    alias sudo='echo "❌ sudo is not available for Guest users"; false'
    alias su='echo "❌ su is not available for Guest users"; false'
fi
EOF
    
    chmod 755 "$WRAPPERS_DIR/guest_security_env.sh"
}

# Main setup function
setup_security_wrappers() {
    log_info "Setting up Guest security wrappers..."
    
    # Create structure
    create_wrapper_structure
    
    # Move actual tools first
    move_actual_tools
    
    # Create all wrappers
    create_brew_wrapper
    create_python_wrapper
    create_git_wrapper
    create_npm_wrapper
    create_gem_wrapper
    
    # Create security environment
    create_security_environment
    
    # Update symlinks
    update_symlinks_to_wrappers
    
    log_info "Security wrappers installed successfully"
}

# Run if executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    setup_security_wrappers
fi