#!/bin/bash
# Copyright (c) 2025 Luka Löhr
#
# SchoolCode Auto-Update Script
# Provides automatic update checking and self-updating functionality
#
# Usage: ./update.sh [OPTIONS]
# Options:
#   -c, --check      Check for updates only (don't install)
#   -f, --force      Force update even if already up-to-date
#   -q, --quiet      Suppress non-error output
#   -v, --verbose    Enable verbose output
#   -h, --help       Show help message

set -euo pipefail

#############################################
# CONFIGURATION
#############################################

readonly SCRIPT_VERSION="1.0.0"
readonly SCRIPT_NAME=$(basename "$0")
readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly INSTALL_PREFIX="${SCHOOLCODE_PREFIX:-/opt/schoolcode}"

# GitHub repository details
readonly GITHUB_REPO="luka-loehr/SchoolCode"
readonly UPDATE_BRANCH="main"
readonly UPDATE_CHECK_URL="https://api.github.com/repos/$GITHUB_REPO/releases/latest"
readonly RAW_CONTENT_URL="https://raw.githubusercontent.com/$GITHUB_REPO/$UPDATE_BRANCH"

# Local version file
readonly VERSION_FILE="$INSTALL_PREFIX/version.txt"
readonly UPDATE_LOG="/var/log/schoolcode/update_$(date +%Y%m%d_%H%M%S).log"
readonly UPDATE_LOCK="/tmp/schoolcode_update.lock"

# Update settings
readonly MAX_RETRIES=3
readonly RETRY_DELAY=5
readonly UPDATE_TIMEOUT=300

# Options
CHECK_ONLY=false
FORCE_UPDATE=false
QUIET=false
VERBOSE=false

# Colors
if [[ -t 1 ]]; then
    readonly GREEN='\033[0;32m'
    readonly RED='\033[0;31m'
    readonly YELLOW='\033[1;33m'
    readonly BLUE='\033[0;34m'
    readonly NC='\033[0m'
else
    readonly GREEN=''
    readonly RED=''
    readonly YELLOW=''
    readonly BLUE=''
    readonly NC=''
fi

#############################################
# UTILITY FUNCTIONS
#############################################

# Source centralized logging
if [[ -f "$SCRIPT_DIR/utils/logging.sh" ]]; then
    source "$SCRIPT_DIR/utils/logging.sh"
fi

# Logging functions - use centralized if available
log() {
    local level="$1"
    shift
    local message="$*"
    
    # Use centralized logging if available
    if declare -f log_info >/dev/null 2>&1; then
        case "$level" in
            ERROR) log_error "[UPDATE] $message" ;;
            SUCCESS) log_info "[UPDATE] ✅ $message" ;;
            INFO) log_info "[UPDATE] $message" ;;
            DEBUG) log_debug "[UPDATE] $message" ;;
            *) log_info "[UPDATE] $message" ;;
        esac
    else
        # Fallback to local logging
        local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
        mkdir -p "$(dirname "$UPDATE_LOG")" 2>/dev/null || true
        echo "[$timestamp] [$level] $message" >> "$UPDATE_LOG" 2>/dev/null || true
        
        if [[ "$QUIET" != "true" ]]; then
            case "$level" in
                ERROR) echo -e "${RED}❌ $message${NC}" >&2 ;;
                SUCCESS) echo -e "${GREEN}✅ $message${NC}" ;;
                INFO) echo -e "${BLUE}ℹ️  $message${NC}" ;;
                DEBUG) [[ "$VERBOSE" == "true" ]] && echo -e "${YELLOW}🔍 $message${NC}" ;;
            esac
        fi
    fi
}

# Show help
show_help() {
    cat << EOF
${BLUE}SchoolCode Auto-Update Script v${SCRIPT_VERSION}${NC}

${GREEN}USAGE:${NC}
    $SCRIPT_NAME [OPTIONS]

${GREEN}OPTIONS:${NC}
    -c, --check      Check for updates only (don't install)
    -f, --force      Force update even if already up-to-date
    -q, --quiet      Suppress non-error output
    -v, --verbose    Enable verbose output
    -h, --help       Show this help message

${GREEN}EXAMPLES:${NC}
    # Check for updates
    $SCRIPT_NAME --check

    # Install updates if available
    sudo $SCRIPT_NAME

    # Force reinstall/update
    sudo $SCRIPT_NAME --force

    # Quiet mode for cron
    sudo $SCRIPT_NAME --quiet

${GREEN}AUTOMATIC UPDATES:${NC}
    To enable automatic updates, add to crontab:
    0 2 * * * /opt/schoolcode/scripts/update.sh --quiet

EOF
}

# Parse arguments
parse_arguments() {
    while [[ $# -gt 0 ]]; do
        case "$1" in
            -c|--check)
                CHECK_ONLY=true
                shift
                ;;
            -f|--force)
                FORCE_UPDATE=true
                shift
                ;;
            -q|--quiet)
                QUIET=true
                shift
                ;;
            -v|--verbose)
                VERBOSE=true
                shift
                ;;
            -h|--help)
                show_help
                exit 0
                ;;
            *)
                echo "Unknown option: $1"
                show_help
                exit 1
                ;;
        esac
    done
}

# Check if running as root
check_root() {
    if [[ "$CHECK_ONLY" == "true" ]]; then
        return 0  # Don't need root for checking
    fi
    
    if [[ $EUID -ne 0 ]]; then
        log ERROR "This script must be run with sudo privileges for updates"
        echo "Please run: sudo $SCRIPT_NAME"
        exit 1
    fi
}

# Acquire update lock
acquire_lock() {
    local timeout=30
    local elapsed=0
    
    while [[ -f "$UPDATE_LOCK" ]] && [[ $elapsed -lt $timeout ]]; do
        log DEBUG "Waiting for update lock..."
        sleep 1
        elapsed=$((elapsed + 1))
    done
    
    if [[ -f "$UPDATE_LOCK" ]]; then
        log ERROR "Could not acquire update lock after ${timeout}s"
        return 1
    fi
    
    echo $$ > "$UPDATE_LOCK"
    return 0
}

# Release update lock
release_lock() {
    rm -f "$UPDATE_LOCK"
}

# Cleanup on exit
cleanup() {
    release_lock
}

#############################################
# VERSION MANAGEMENT
#############################################

# Get current installed version
get_current_version() {
    if [[ -f "$VERSION_FILE" ]]; then
        cat "$VERSION_FILE"
    elif [[ -f "$INSTALL_PREFIX/scripts/install.sh" ]]; then
        # Try to extract version from script
        grep "SCRIPT_VERSION=" "$INSTALL_PREFIX/scripts/install.sh" | head -1 | cut -d'"' -f2
    else
        echo "unknown"
    fi
}

# Get latest version from GitHub
get_latest_version() {
    local version="unknown"
    
    # Try to get from GitHub API (releases)
    if command -v curl &>/dev/null; then
        version=$(curl -sSL "$UPDATE_CHECK_URL" 2>/dev/null | grep '"tag_name"' | cut -d'"' -f4 | sed 's/^v//')
    fi
    
    # Fallback: get from main branch version file
    if [[ "$version" == "unknown" ]] || [[ -z "$version" ]]; then
        version=$(curl -sSL "$RAW_CONTENT_URL/version.txt" 2>/dev/null || echo "unknown")
    fi
    
    echo "$version"
}

# Compare versions
version_compare() {
    local version1="$1"
    local version2="$2"
    
    # Handle special cases
    if [[ "$version1" == "unknown" ]] || [[ "$version2" == "unknown" ]]; then
        return 1  # Can't compare, assume update needed
    fi
    
    if [[ "$version1" == "$version2" ]]; then
        return 0  # Same version
    fi
    
    # Compare semantic versions
    local IFS='.'
    local i ver1=($version1) ver2=($version2)
    
    # Fill empty fields in ver1 with zeros
    for ((i=${#ver1[@]}; i<${#ver2[@]}; i++)); do
        ver1[i]=0
    done
    
    for ((i=0; i<${#ver1[@]}; i++)); do
        if [[ -z ${ver2[i]} ]]; then
            ver2[i]=0
        fi
        if ((10#${ver1[i]} > 10#${ver2[i]})); then
            return 1  # version1 is newer
        fi
        if ((10#${ver1[i]} < 10#${ver2[i]})); then
            return 2  # version2 is newer
        fi
    done
    
    return 0  # versions are equal
}

#############################################
# UPDATE FUNCTIONS
#############################################

# Check for updates
check_for_updates() {
    log INFO "Checking for updates..."
    
    local current_version=$(get_current_version)
    local latest_version=$(get_latest_version)
    
    log DEBUG "Current version: $current_version"
    log DEBUG "Latest version: $latest_version"
    
    if [[ "$latest_version" == "unknown" ]]; then
        log ERROR "Could not determine latest version"
        return 1
    fi
    
    version_compare "$current_version" "$latest_version"
    local result=$?
    
    if [[ $result -eq 2 ]] || [[ "$current_version" == "unknown" ]]; then
        log INFO "Update available: $current_version -> $latest_version"
        return 0  # Update available
    elif [[ $result -eq 0 ]]; then
        log INFO "Already up-to-date (version $current_version)"
        return 1  # No update needed
    else
        log INFO "Current version ($current_version) is newer than remote ($latest_version)"
        return 1  # No update needed
    fi
}

# Download file with retry
download_file() {
    local url="$1"
    local output="$2"
    local retries=0
    
    while [[ $retries -lt $MAX_RETRIES ]]; do
        log DEBUG "Downloading $url (attempt $((retries + 1))/$MAX_RETRIES)"
        
        if curl -fsSL "$url" -o "$output" 2>/dev/null; then
            return 0
        fi
        
        retries=$((retries + 1))
        if [[ $retries -lt $MAX_RETRIES ]]; then
            log DEBUG "Download failed, retrying in ${RETRY_DELAY}s..."
            sleep $RETRY_DELAY
        fi
    done
    
    log ERROR "Failed to download $url after $MAX_RETRIES attempts"
    return 1
}

# Backup current installation
backup_installation() {
    local backup_dir="/var/backups/schoolcode"
    local backup_file="$backup_dir/backup_$(date +%Y%m%d_%H%M%S).tar.gz"
    
    log INFO "Creating backup..."
    
    mkdir -p "$backup_dir"
    
    if tar -czf "$backup_file" -C "$(dirname "$INSTALL_PREFIX")" "$(basename "$INSTALL_PREFIX")" 2>/dev/null; then
        log SUCCESS "Backup created: $backup_file"
        echo "$backup_file"  # Return backup path
        return 0
    else
        log ERROR "Failed to create backup"
        return 1
    fi
}

# Restore from backup
restore_backup() {
    local backup_file="$1"
    
    if [[ ! -f "$backup_file" ]]; then
        log ERROR "Backup file not found: $backup_file"
        return 1
    fi
    
    log INFO "Restoring from backup..."
    
    rm -rf "$INSTALL_PREFIX"
    tar -xzf "$backup_file" -C "$(dirname "$INSTALL_PREFIX")"
    
    log SUCCESS "Restored from backup"
    return 0
}

# Perform update
perform_update() {
    log INFO "Starting update process..."
    
    # Create temporary directory
    local temp_dir="/tmp/schoolcode_update_$$"
    mkdir -p "$temp_dir"
    
    # Backup current installation
    local backup_file=$(backup_installation)
    if [[ -z "$backup_file" ]]; then
        log ERROR "Failed to create backup, aborting update"
        return 1
    fi
    
    # Download update files
    log INFO "Downloading update files..."
    
    local files_to_update=(
        "scripts/install.sh"
        "scripts/schoolcode-cli.sh"
        "scripts/update.sh"
        "scripts/uninstall.sh"
        "scripts/utils/logging.sh"
        "scripts/utils/config.sh"
        "scripts/setup/guest_tools_setup.sh"
        "version.txt"
    )
    
    local download_failed=false
    for file in "${files_to_update[@]}"; do
        local url="$RAW_CONTENT_URL/$file"
        local temp_file="$temp_dir/$(basename "$file")"
        
        if ! download_file "$url" "$temp_file"; then
            log ERROR "Failed to download $file"
            download_failed=true
            break
        fi
    done
    
    if [[ "$download_failed" == "true" ]]; then
        log ERROR "Update download failed, restoring backup"
        restore_backup "$backup_file"
        rm -rf "$temp_dir"
        return 1
    fi
    
    # Apply updates
    log INFO "Applying updates..."
    
    for file in "${files_to_update[@]}"; do
        local temp_file="$temp_dir/$(basename "$file")"
        local target_file="$INSTALL_PREFIX/$file"
        
        if [[ -f "$temp_file" ]]; then
            mkdir -p "$(dirname "$target_file")"
            cp "$temp_file" "$target_file"
            
            # Make scripts executable
            if [[ "$file" == *.sh ]]; then
                chmod +x "$target_file"
            fi
        fi
    done
    
    # Update version file
    local latest_version=$(get_latest_version)
    echo "$latest_version" > "$VERSION_FILE"
    
    # Verify update
    log INFO "Verifying update..."
    
    if [[ -f "$INSTALL_PREFIX/scripts/install.sh" ]]; then
        log SUCCESS "Update completed successfully to version $latest_version"
        
        # Clean up
        rm -rf "$temp_dir"
        
        # Run post-update tasks
        post_update_tasks
        
        return 0
    else
        log ERROR "Update verification failed, restoring backup"
        restore_backup "$backup_file"
        rm -rf "$temp_dir"
        return 1
    fi
}

# Post-update tasks
post_update_tasks() {
    log INFO "Running post-update tasks..."
    
    # Fix permissions
    if [[ -d "$INSTALL_PREFIX" ]]; then
        chmod -R 755 "$INSTALL_PREFIX"
    fi
    
    # Restart services if needed
    if launchctl list | grep -q "com.schoolcode"; then
        log DEBUG "Reloading LaunchAgents..."
        launchctl unload /Library/LaunchAgents/com.schoolcode.*.plist 2>/dev/null || true
        launchctl load /Library/LaunchAgents/com.schoolcode.*.plist 2>/dev/null || true
    fi
    
    log SUCCESS "Post-update tasks completed"
}

#############################################
# SCHEDULED UPDATE FUNCTIONS
#############################################

# Install update schedule
install_update_schedule() {
    log INFO "Installing automatic update schedule..."
    
    # Create LaunchDaemon for automatic updates
    local plist_file="/Library/LaunchDaemons/com.schoolcode.autoupdate.plist"
    
    cat > "$plist_file" << EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>com.schoolcode.autoupdate</string>
    <key>ProgramArguments</key>
    <array>
        <string>$INSTALL_PREFIX/scripts/update.sh</string>
        <string>--quiet</string>
    </array>
    <key>StartCalendarInterval</key>
    <dict>
        <key>Hour</key>
        <integer>2</integer>
        <key>Minute</key>
        <integer>0</integer>
    </dict>
    <key>StandardOutPath</key>
    <string>/var/log/schoolcode/autoupdate.log</string>
    <key>StandardErrorPath</key>
    <string>/var/log/schoolcode/autoupdate.err</string>
</dict>
</plist>
EOF
    
    # Load the daemon
    launchctl load "$plist_file" 2>/dev/null || true
    
    log SUCCESS "Automatic updates scheduled for 2:00 AM daily"
}

# Remove update schedule
remove_update_schedule() {
    log INFO "Removing automatic update schedule..."
    
    local plist_file="/Library/LaunchDaemons/com.schoolcode.autoupdate.plist"
    
    if [[ -f "$plist_file" ]]; then
        launchctl unload "$plist_file" 2>/dev/null || true
        rm -f "$plist_file"
        log SUCCESS "Automatic update schedule removed"
    fi
}

#############################################
# MAIN EXECUTION
#############################################

main() {
    # Parse arguments
    parse_arguments "$@"
    
    # Set up cleanup trap
    trap cleanup EXIT
    
    # Check root if needed
    check_root
    
    # Acquire lock
    if ! acquire_lock; then
        log ERROR "Another update process is running"
        exit 1
    fi
    
    # Check for updates
    if check_for_updates || [[ "$FORCE_UPDATE" == "true" ]]; then
        if [[ "$CHECK_ONLY" == "true" ]]; then
            log INFO "Update available but not installing (check-only mode)"
            exit 0
        fi
        
        # Perform update
        if perform_update; then
            log SUCCESS "SchoolCode has been updated successfully"
            exit 0
        else
            log ERROR "Update failed"
            exit 1
        fi
    else
        if [[ "$CHECK_ONLY" == "true" ]]; then
            log INFO "No updates available"
        else
            log INFO "SchoolCode is up-to-date"
        fi
        exit 0
    fi
}

# Run main
main "$@"
