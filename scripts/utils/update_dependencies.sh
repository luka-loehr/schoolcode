#!/bin/bash
# Copyright (c) 2025 Luka Löhr

# SchoolCode Dependency Update Utility
# Updates all dependencies that SchoolCode relies on

set -euo pipefail

# Source logging utilities
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/logging.sh"
source "$SCRIPT_DIR/python_utils.sh" 2>/dev/null || true

# Function to run command as original user (not root)
run_as_user() {
    if [[ "$EUID" -eq 0 ]] && [[ -n "${SUDO_USER:-}" ]]; then
        # Running as root via sudo, execute as original user
        sudo -u "$SUDO_USER" "$@"
    else
        # Not root or no sudo user, run normally
        "$@"
    fi
}

# Function to update Python to latest version
update_python() {
    log_info "Checking for Python updates..."
    
    # Run the official Python installer with update mode
    if [[ -f "$SCRIPT_DIR/install_official_python.sh" ]]; then
        "$SCRIPT_DIR/install_official_python.sh"
    else
        log_error "Python installer script not found"
        return 1
    fi
    
    return 0
}

# Function to update Git
update_git() {
    log_info "Checking for Git updates..."
    
    # Check if Git is installed via Homebrew
    if command -v brew &>/dev/null && run_as_user brew list git &>/dev/null 2>&1; then
        log_info "Updating Git via Homebrew..."
        run_as_user brew upgrade git 2>&1 || {
            log_warn "Git is already at the latest version"
        }
    else
        log_info "Git is not managed by Homebrew, skipping update"
    fi
    
    # Show current Git version
    if command -v git &>/dev/null; then
        local git_version=$(git --version | cut -d' ' -f3)
        log_info "Current Git version: $git_version"
    fi
    
    return 0
}

# Function to update Homebrew itself
update_homebrew() {
    log_info "Updating Homebrew..."
    
    if ! command -v brew &>/dev/null; then
        log_error "Homebrew not found"
        return 1
    fi
    
    # Update Homebrew (must run as regular user)
    log_info "Running brew update..."
    run_as_user brew update 2>&1 || {
        log_error "Failed to update Homebrew"
        return 1
    }
    
    # Show Homebrew version
    local brew_version=$(run_as_user brew --version | head -1)
    log_info "Current Homebrew version: $brew_version"
    
    return 0
}

# Function to update pip packages
update_pip_packages() {
    log_info "Updating pip and setuptools..."
    
    # Find Python installation
    local python_bin_dir=""
    if declare -f get_python_bin_dir >/dev/null 2>&1; then
        python_bin_dir=$(get_python_bin_dir 2>/dev/null || echo "")
    fi
    
    if [[ -z "$python_bin_dir" ]] || [[ ! -x "$python_bin_dir/python3" ]]; then
        # Try to find any python3
        if command -v python3 &>/dev/null; then
            log_info "Using system Python for pip update"
            python3 -m pip install --upgrade pip 2>&1 || {
                log_error "Failed to update pip"
                return 1
            }
            python3 -m pip install --upgrade setuptools 2>&1 || {
                log_warn "Failed to update setuptools"
            }
            local pip_version=$(pip3 --version | cut -d' ' -f2)
            log_info "Current pip version: $pip_version"
        else
            log_error "Python not found"
            return 1
        fi
    else
        # Update pip itself
        log_info "Upgrading pip..."
        "$python_bin_dir/python3" -m pip install --upgrade pip 2>&1 || {
            log_error "Failed to update pip"
            return 1
        }
        
        # Update setuptools
        log_info "Upgrading setuptools..."
        "$python_bin_dir/python3" -m pip install --upgrade setuptools 2>&1 || {
            log_warn "Failed to update setuptools"
        }
        
        # Show pip version
        local pip_version=$("$python_bin_dir/pip" --version | cut -d' ' -f2)
        log_info "Current pip version: $pip_version"
    fi
    
    return 0
}

# Function to recreate symlinks with updated paths
update_symlinks() {
    log_info "Updating tool symlinks..."
    
    # Run guest tools setup to recreate symlinks
    local setup_script="$(dirname "$SCRIPT_DIR")/setup/guest_tools_setup.sh"
    if [[ -f "$setup_script" ]]; then
        # Just update the symlinks, don't reinstall tools
        log_info "Recreating symlinks with updated paths..."
        (
            cd "$(dirname "$setup_script")"
            # Source the script and run only the symlink creation part
            source "$setup_script"
            
            # Create symlinks section
            if declare -f create_symlink >/dev/null 2>&1; then
                ADMIN_TOOLS_DIR="/opt/admin-tools"
                
                # Get updated Python paths
                source "$SCRIPT_DIR/python_utils.sh" 2>/dev/null || true
                OFFICIAL_PYTHON_PATH=""
                if declare -f get_python_bin_dir >/dev/null 2>&1; then
                    OFFICIAL_PYTHON_PATH=$(get_python_bin_dir 2>/dev/null || echo "")
                fi
                
                # Recreate Python symlinks
                if [[ -n "$OFFICIAL_PYTHON_PATH" ]] && [[ -d "$OFFICIAL_PYTHON_PATH" ]]; then
                    create_symlink "$OFFICIAL_PYTHON_PATH/python3" "$ADMIN_TOOLS_DIR/bin/python3"
                    create_symlink "$OFFICIAL_PYTHON_PATH/python" "$ADMIN_TOOLS_DIR/bin/python"
                    create_symlink "$OFFICIAL_PYTHON_PATH/pip3" "$ADMIN_TOOLS_DIR/bin/pip3"
                    create_symlink "$OFFICIAL_PYTHON_PATH/pip" "$ADMIN_TOOLS_DIR/bin/pip"
                fi
                
                # Update other tool symlinks if needed
                if command -v git &>/dev/null; then
                    create_symlink "$(run_as_user which git)" "$ADMIN_TOOLS_DIR/bin/git"
                fi
                
                if command -v brew &>/dev/null; then
                    create_symlink "$(run_as_user which brew)" "$ADMIN_TOOLS_DIR/bin/brew"
                fi
            fi
        )
    else
        log_warn "Guest tools setup script not found"
    fi
    
    return 0
}

# Function to check system dependencies
check_system_dependencies() {
    log_info "Checking system dependencies..."
    
    # Check Command Line Tools
    if command -v xcode-select &>/dev/null; then
        if xcode-select -p &>/dev/null; then
            local clt_version=$(pkgutil --pkg-info=com.apple.pkg.CLTools_Executables 2>/dev/null | grep version | cut -d: -f2 | xargs)
            if [[ -n "$clt_version" ]]; then
                log_info "Command Line Tools version: $clt_version"
            else
                log_info "Command Line Tools installed (version unknown)"
            fi
        else
            log_warn "Command Line Tools not installed"
            log_info "Install with: xcode-select --install"
        fi
    fi
    
    return 0
}

# Main update function
update_all_dependencies() {
    log_info "Starting dependency update process..."
    
    # Check if running as root
    if [[ "$EUID" -ne 0 ]]; then
        log_error "This script must be run with sudo"
        return 1
    fi
    
    local failed_updates=0
    
    # Update Homebrew first
    if ! update_homebrew; then
        ((failed_updates++))
    fi
    
    echo ""
    
    # Update Python
    if ! update_python; then
        ((failed_updates++))
    fi
    
    echo ""
    
    # Update Git
    if ! update_git; then
        ((failed_updates++))
    fi
    
    echo ""
    
    # Update pip packages
    if ! update_pip_packages; then
        ((failed_updates++))
    fi
    
    echo ""
    
    # Update symlinks with new paths
    if ! update_symlinks; then
        ((failed_updates++))
    fi
    
    echo ""
    
    # Check system dependencies
    check_system_dependencies
    
    echo ""
    
    if [[ $failed_updates -eq 0 ]]; then
        log_info "All dependencies updated successfully!"
        return 0
    else
        log_warn "Completed with $failed_updates failed updates"
        return 2
    fi
}

# Run if executed directly
if [[ "${BASH_SOURCE[0]}" = "${0}" ]]; then
    update_all_dependencies
fi