#!/bin/bash
# Copyright (c) 2025 Luka Löhr
#
# SchoolCode Update Script
# Pulls latest changes from GitHub and reruns installation

set -euo pipefail

# Source utilities
SCRIPT_DIR="$(dirname "$0")"
source "${SCRIPT_DIR}/utils/logging.sh"
source "${SCRIPT_DIR}/utils/config.sh"

# GitHub repository
REPO_URL="https://github.com/luka-loehr/SchoolCode"
REPO_NAME="SchoolCode"

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m'

# Check if we're in a git repository
check_git_repo() {
    if ! git rev-parse --git-dir >/dev/null 2>&1; then
        log_error "Not in a git repository. Cannot update."
        return 1
    fi
    
    # Check if this is the SchoolCode repository
    local remote_url=$(git config --get remote.origin.url 2>/dev/null || echo "")
    if [[ ! "$remote_url" =~ "SchoolCode" ]]; then
        log_warn "This doesn't appear to be the SchoolCode repository"
        log_warn "Remote URL: $remote_url"
        echo -n "Continue anyway? (y/N): "
        read -r response
        if [[ ! "$response" =~ ^[yY]$ ]]; then
            return 1
        fi
            return 1
        fi
    fi
    
    return 0
}

# Check for uncommitted changes
check_uncommitted_changes() {
    if ! git diff-index --quiet HEAD -- 2>/dev/null; then
        log_warn "You have uncommitted changes:"
        git status --short
        echo ""
        echo -n "Stash changes and continue? (y/N): "
        read -r response
        if [[ "$response" =~ ^[yY]$ ]]; then
            log_info "Stashing local changes..."
            git stash push -m "SchoolCode update stash $(date +%Y%m%d_%H%M%S)"
            return 0
        else
            log_error "Update cancelled. Please commit or stash your changes first."
            return 1
        fi
    fi
    return 0
}

# Get current version/commit
get_current_version() {
    local current_commit=$(git rev-parse --short HEAD 2>/dev/null || echo "unknown")
    local current_branch=$(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo "unknown")
    echo "Branch: $current_branch, Commit: $current_commit"
}

# Backup current installation
backup_current_installation() {
    local backup_dir="/tmp/schoolcode_backup_$(date +%Y%m%d_%H%M%S)"
    log_info "Creating backup at: $backup_dir"
    
    # Backup configuration
    mkdir -p "$backup_dir/config"
    if [[ -f "/etc/schoolcode/schoolcode.conf" ]]; then
        cp -p "/etc/schoolcode/schoolcode.conf" "$backup_dir/config/" 2>/dev/null || true
    fi
    
    # Backup logs
    if [[ -d "/var/log/schoolcode" ]]; then
        cp -rp "/var/log/schoolcode" "$backup_dir/logs" 2>/dev/null || true
    fi
    
    # Save current version info
    get_current_version > "$backup_dir/version.txt"
    
    log_info "Backup completed: $backup_dir"
    echo "$backup_dir"
}

# Pull latest changes from GitHub
pull_latest_changes() {
    log_info "Fetching latest changes from GitHub..."
    
    # Fetch all branches and tags
    if ! git fetch --all --tags 2>&1; then
        log_error "Failed to fetch from remote repository"
        return 1
    fi
    
    # Get current branch
    local current_branch=$(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo "main")
    
    # Check if we're on main/master branch
    if [[ "$current_branch" != "main" ]] && [[ "$current_branch" != "master" ]]; then
        log_warn "Not on main branch (current: $current_branch)"
        echo -n "Switch to main branch? (Y/n): "
        read -r response
        if [[ ! "$response" =~ ^[nN]$ ]]; then
            if git show-ref --verify --quiet refs/heads/main; then
                git checkout main
                current_branch="main"
            elif git show-ref --verify --quiet refs/heads/master; then
                git checkout master
                current_branch="master"
            else
                log_error "No main or master branch found"
                return 1
            fi
        fi
    fi
    
    # Show what will be updated
    local behind_count=$(git rev-list --count HEAD..origin/$current_branch 2>/dev/null || echo "0")
    if [[ $behind_count -eq 0 ]]; then
        log_info "Already up to date!"
        return 2  # Special return code for "already up to date"
    fi
    
    log_info "Found $behind_count new commits"
    echo ""
    echo "Recent changes:"
    git log --oneline -10 HEAD..origin/$current_branch 2>/dev/null || true
    echo ""
    
    # Pull the changes
    log_info "Pulling latest changes..."
    if ! git pull origin "$current_branch" 2>&1; then
        log_error "Failed to pull changes"
        return 1
    fi
    
    log_info "Successfully updated to latest version"
    return 0
}

# Run post-update tasks
run_post_update_tasks() {
    log_info "Running post-update tasks..."
    
    # Make all scripts executable
    find "$SCRIPT_DIR" -name "*.sh" -type f -exec chmod +x {} \; 2>/dev/null
    
    # Update CLI symlink if needed
    if [[ -L "/usr/local/bin/schoolcode" ]]; then
        local current_target=$(readlink "/usr/local/bin/schoolcode" 2>/dev/null || echo "")
        local expected_target="$SCRIPT_DIR/SchoolCode-cli.sh"
        
        if [[ "$current_target" != "$expected_target" ]]; then
            log_info "Updating CLI symlink..."
            sudo ln -sf "$expected_target" "/usr/local/bin/schoolcode"
        fi
    fi
    
    return 0
}

# Update dependencies
update_dependencies() {
    echo ""
    echo -n "Update all dependencies (Python, Git, Homebrew)? (Y/n): "
    read -r response
    
    if [[ ! "$response" =~ ^[nN]$ ]]; then
        log_info "Updating dependencies..."
        
        if [[ -f "$SCRIPT_DIR/utils/update_dependencies.sh" ]]; then
            sudo "$SCRIPT_DIR/utils/update_dependencies.sh"
        else
            log_warn "Dependency update script not found"
        fi
    fi
}

# Main update function
run_update() {
    echo -e "${BLUE}╔═══════════════════════════════════════╗${NC}"
    echo -e "${BLUE}║       SchoolCode Update Utility         ║${NC}"
    echo -e "${BLUE}╚═══════════════════════════════════════╝${NC}"
    echo ""
    
    # Show current version
    echo "Current version: $(get_current_version)"
    echo ""
    
    # Check prerequisites
    if ! check_git_repo; then
        return 1
    fi
    
    if ! check_uncommitted_changes; then
        return 1
    fi
    
    # Create backup
    local backup_path=$(backup_current_installation)
    
    # Pull latest changes
    local pull_result
    pull_latest_changes
    pull_result=$?
    
    if [[ $pull_result -eq 1 ]]; then
        log_error "Update failed"
        echo ""
        echo "Backup is available at: $backup_path"
        return 1
    elif [[ $pull_result -eq 2 ]]; then
        # Already up to date
        echo ""
        echo -n "Already up to date. Re-run installation anyway? (y/N): "
        read -r response
        if [[ ! "$response" =~ ^[yY]$ ]]; then
            log_info "No update needed"
            return 2  # Return 2 to indicate "already up to date"
        fi
    fi
    
    # Run post-update tasks
    run_post_update_tasks
    
    # Show new version
    echo ""
    echo "New version: $(get_current_version)"
    echo ""
    
    # Update dependencies
    update_dependencies
    
    # Ask to run installation
    echo ""
    echo -e "${YELLOW}The update has been downloaded successfully.${NC}"
    echo "To complete the update, the installation script needs to run."
    echo ""
    echo -n "Run installation now? (Y/n): "
    read -r response
    
    if [[ ! "$response" =~ ^[nN]$ ]]; then
        echo ""
        log_info "Running installation script..."
        
        # Change to repository root
        cd "$(git rev-parse --show-toplevel)"
        
        # Run installation
        if [[ -f "./scripts/install_SchoolCode.sh" ]]; then
            sudo ./scripts/install_SchoolCode.sh
        else
            log_error "Installation script not found"
            return 1
        fi
    else
        echo ""
        echo -e "${YELLOW}Update downloaded but not installed.${NC}"
        echo "To complete the installation later, run:"
        echo "  sudo ./scripts/install_SchoolCode.sh"
    fi
    
    echo ""
    log_info "Update process completed"
    echo "Backup available at: $backup_path"
    
    return 0
}

# Run if executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    # Check if running with sudo for the installation part
    if [[ $EUID -ne 0 ]] && [[ "${1:-}" != "--no-install" ]]; then
        log_warn "Note: Installation will require sudo privileges"
    fi
    
    run_update
    exit $?
fi