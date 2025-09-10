#!/bin/bash
# Copyright (c) 2025 Luka Löhr
#
# SchoolCode Uninstallation Script
# Completely removes SchoolCode from the system
#
# Usage: sudo ./uninstall_schoolcode.sh [OPTIONS]
# Options:
#   -f, --force      Skip confirmation prompts
#   -k, --keep-logs  Keep log files after uninstallation
#   -b, --backup     Create backup before uninstalling
#   -v, --verbose    Enable verbose output
#   -h, --help       Show help message

set -euo pipefail

#############################################
# CONFIGURATION
#############################################

readonly SCRIPT_VERSION="1.0.0"
readonly SCRIPT_NAME=$(basename "$0")
readonly INSTALL_PREFIX="${SCHOOLCODE_PREFIX:-/opt/schoolcode}"
readonly LOG_DIR="/var/log/schoolcode"
readonly BACKUP_DIR="/var/backups/schoolcode"
readonly UNINSTALL_LOG="$LOG_DIR/uninstall_$(date +%Y%m%d_%H%M%S).log"

# Options
FORCE=false
KEEP_LOGS=false
CREATE_BACKUP=false
VERBOSE=false

# Statistics
FILES_REMOVED=0
DIRS_REMOVED=0
SERVICES_STOPPED=0
ERRORS_OCCURRED=0

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

# Logging
log() {
    local level="$1"
    shift
    local message="$*"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    
    # Ensure log directory exists
    mkdir -p "$LOG_DIR" 2>/dev/null || true
    
    # Write to log file
    echo "[$timestamp] [$level] $message" >> "$UNINSTALL_LOG" 2>/dev/null || true
    
    # Write to console
    case "$level" in
        ERROR)
            echo -e "${RED}❌ $message${NC}" >&2
            ERRORS_OCCURRED=$((ERRORS_OCCURRED + 1))
            ;;
        SUCCESS)
            echo -e "${GREEN}✅ $message${NC}"
            ;;
        INFO)
            echo -e "${BLUE}ℹ️  $message${NC}"
            ;;
        WARN)
            echo -e "${YELLOW}⚠️  $message${NC}"
            ;;
        DEBUG)
            if [[ "$VERBOSE" == "true" ]]; then
                echo -e "${YELLOW}🔍 $message${NC}"
            fi
            ;;
    esac
}

# Show help
show_help() {
    cat << EOF
${BLUE}SchoolCode Uninstallation Script v${SCRIPT_VERSION}${NC}

${GREEN}USAGE:${NC}
    sudo $SCRIPT_NAME [OPTIONS]

${GREEN}OPTIONS:${NC}
    -f, --force      Skip confirmation prompts
    -k, --keep-logs  Keep log files after uninstallation
    -b, --backup     Create backup before uninstalling
    -v, --verbose    Enable verbose output
    -h, --help       Show this help message

${GREEN}WHAT WILL BE REMOVED:${NC}
    • Installation directory: $INSTALL_PREFIX
    • LaunchAgents/LaunchDaemons for SchoolCode
    • Guest setup scripts
    • PATH configurations from shell files
    • Log files (unless --keep-logs is specified)
    • Temporary files and caches

${GREEN}WHAT WILL BE KEPT:${NC}
    • Backup files in $BACKUP_DIR
    • User-installed packages (pip packages, etc.)
    • Homebrew and Python installations

${YELLOW}WARNING:${NC}
    This will completely remove SchoolCode from your system.
    Consider using --backup to create a backup first.

EOF
}

# Parse arguments
parse_arguments() {
    while [[ $# -gt 0 ]]; do
        case "$1" in
            -f|--force)
                FORCE=true
                shift
                ;;
            -k|--keep-logs)
                KEEP_LOGS=true
                shift
                ;;
            -b|--backup)
                CREATE_BACKUP=true
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
    if [[ $EUID -ne 0 ]]; then
        log ERROR "This script must be run with sudo privileges"
        echo "Please run: sudo $SCRIPT_NAME"
        exit 1
    fi
}

# Confirm uninstallation
confirm_uninstall() {
    if [[ "$FORCE" == "true" ]]; then
        return 0
    fi
    
    echo ""
    echo -e "${YELLOW}╔═══════════════════════════════════════╗${NC}"
    echo -e "${YELLOW}║           ⚠️  WARNING ⚠️               ║${NC}"
    echo -e "${YELLOW}╚═══════════════════════════════════════╝${NC}"
    echo ""
    echo "This will completely remove SchoolCode from your system."
    echo ""
    echo "The following will be removed:"
    echo "  • $INSTALL_PREFIX"
    echo "  • LaunchAgents and LaunchDaemons"
    echo "  • Guest setup scripts"
    echo "  • PATH configurations"
    if [[ "$KEEP_LOGS" != "true" ]]; then
        echo "  • Log files in $LOG_DIR"
    fi
    echo ""
    read -p "Are you sure you want to continue? (yes/NO): " response
    
    if [[ ! "$response" =~ ^[Yy][Ee][Ss]$ ]]; then
        log INFO "Uninstallation cancelled by user"
        exit 0
    fi
}

#############################################
# BACKUP FUNCTIONS
#############################################

# Create backup before uninstalling
create_backup() {
    if [[ "$CREATE_BACKUP" != "true" ]]; then
        return 0
    fi
    
    log INFO "Creating backup before uninstallation..."
    
    if [[ ! -d "$INSTALL_PREFIX" ]]; then
        log WARN "Installation directory not found, skipping backup"
        return 0
    fi
    
    mkdir -p "$BACKUP_DIR"
    local backup_file="$BACKUP_DIR/pre_uninstall_$(date +%Y%m%d_%H%M%S).tar.gz"
    
    if tar -czf "$backup_file" \
        -C "$(dirname "$INSTALL_PREFIX")" \
        "$(basename "$INSTALL_PREFIX")" 2>/dev/null; then
        log SUCCESS "Backup created: $backup_file"
        echo "  You can restore later with: tar -xzf $backup_file -C /"
    else
        log ERROR "Failed to create backup"
        if [[ "$FORCE" != "true" ]]; then
            read -p "Continue without backup? (y/N): " response
            if [[ ! "$response" =~ ^[Yy]$ ]]; then
                exit 1
            fi
        fi
    fi
}

#############################################
# UNINSTALLATION FUNCTIONS
#############################################

# Stop and remove LaunchAgents/LaunchDaemons
remove_launch_services() {
    log INFO "Removing LaunchAgents and LaunchDaemons..."
    
    local services=(
        "/Library/LaunchAgents/com.schoolcode.guestsetup.plist"
        "/Library/LaunchDaemons/com.schoolcode.autoupdate.plist"
    )
    
    for service in "${services[@]}"; do
        if [[ -f "$service" ]]; then
            log DEBUG "Unloading $service"
            launchctl unload "$service" 2>/dev/null || true
            rm -f "$service"
            SERVICES_STOPPED=$((SERVICES_STOPPED + 1))
            log SUCCESS "Removed $(basename "$service")"
        fi
    done
    
    # Remove any other SchoolCode launch services
    for plist in /Library/Launch*/com.schoolcode.*.plist; do
        if [[ -f "$plist" ]]; then
            launchctl unload "$plist" 2>/dev/null || true
            rm -f "$plist"
            SERVICES_STOPPED=$((SERVICES_STOPPED + 1))
        fi
    done
}

# Remove guest setup scripts
remove_guest_scripts() {
    log INFO "Removing guest setup scripts..."
    
    local scripts=(
        "/usr/local/bin/guest_setup_auto.sh"
        "/usr/local/bin/guest_login_setup"
    )
    
    for script in "${scripts[@]}"; do
        if [[ -f "$script" ]]; then
            rm -f "$script"
            FILES_REMOVED=$((FILES_REMOVED + 1))
            log SUCCESS "Removed $script"
        fi
    done
}

# Remove installation directory
remove_installation_directory() {
    log INFO "Removing installation directory..."
    
    if [[ -d "$INSTALL_PREFIX" ]]; then
        local file_count=$(find "$INSTALL_PREFIX" -type f | wc -l)
        local dir_count=$(find "$INSTALL_PREFIX" -type d | wc -l)
        
        rm -rf "$INSTALL_PREFIX"
        
        FILES_REMOVED=$((FILES_REMOVED + file_count))
        DIRS_REMOVED=$((DIRS_REMOVED + dir_count))
        
        log SUCCESS "Removed $INSTALL_PREFIX ($file_count files, $dir_count directories)"
    else
        log WARN "Installation directory not found: $INSTALL_PREFIX"
    fi
}

# Remove PATH configurations from shell files
remove_path_configurations() {
    log INFO "Removing PATH configurations..."
    
    # Get all user home directories
    local users=$(dscl . -list /Users | grep -v '^_')
    
    for user in $users; do
        local user_home=$(dscl . -read /Users/"$user" NFSHomeDirectory 2>/dev/null | awk '{print $2}')
        
        if [[ -z "$user_home" ]] || [[ ! -d "$user_home" ]]; then
            continue
        fi
        
        log DEBUG "Checking user: $user"
        
        # Shell configuration files to check
        local shell_configs=(
            "$user_home/.zshrc"
            "$user_home/.bashrc"
            "$user_home/.bash_profile"
            "$user_home/.profile"
        )
        
        for config in "${shell_configs[@]}"; do
            if [[ -f "$config" ]]; then
                # Create backup of original file
                cp "$config" "$config.schoolcode_backup_$(date +%Y%m%d)" 2>/dev/null || true
                
                # Remove SchoolCode PATH entries
                if grep -q "schoolcode" "$config" 2>/dev/null; then
                    # Remove lines containing schoolcode
                    sed -i '' '/schoolcode/d' "$config" 2>/dev/null || true
                    
                    # Remove empty lines that might be left
                    sed -i '' '/^[[:space:]]*$/d' "$config" 2>/dev/null || true
                    
                    log SUCCESS "Cleaned $config for user $user"
                fi
            fi
        done
    done
}

# Remove log files
remove_log_files() {
    if [[ "$KEEP_LOGS" == "true" ]]; then
        log INFO "Keeping log files as requested"
        return 0
    fi
    
    log INFO "Removing log files..."
    
    if [[ -d "$LOG_DIR" ]]; then
        # Count files before removal
        local log_count=$(find "$LOG_DIR" -type f | wc -l)
        
        # Keep the current uninstall log until the end
        local current_log=$(basename "$UNINSTALL_LOG")
        find "$LOG_DIR" -type f ! -name "$current_log" -delete 2>/dev/null || true
        
        FILES_REMOVED=$((FILES_REMOVED + log_count - 1))
        log SUCCESS "Removed $((log_count - 1)) log files"
    fi
}

# Remove temporary files
remove_temp_files() {
    log INFO "Removing temporary files..."
    
    # Remove any SchoolCode temp files
    rm -rf /tmp/schoolcode_* 2>/dev/null || true
    rm -f /tmp/.schoolcode_* 2>/dev/null || true
    
    # Remove update locks
    rm -f /tmp/schoolcode_update.lock 2>/dev/null || true
    
    log SUCCESS "Removed temporary files"
}

# Remove cron jobs
remove_cron_jobs() {
    log INFO "Checking for cron jobs..."
    
    # Check root crontab
    if crontab -l 2>/dev/null | grep -q "schoolcode"; then
        log DEBUG "Removing SchoolCode cron jobs"
        crontab -l | grep -v "schoolcode" | crontab - 2>/dev/null || true
        log SUCCESS "Removed cron jobs"
    fi
}

# Final cleanup
final_cleanup() {
    log INFO "Performing final cleanup..."
    
    # Remove any remaining SchoolCode references
    find /usr/local/bin -name "*schoolcode*" -delete 2>/dev/null || true
    find /opt -name "*schoolcode*" -type d -empty -delete 2>/dev/null || true
    
    # Remove backup directory if empty
    if [[ -d "$BACKUP_DIR" ]] && [[ -z "$(ls -A "$BACKUP_DIR")" ]]; then
        rmdir "$BACKUP_DIR" 2>/dev/null || true
    fi
    
    log SUCCESS "Final cleanup completed"
}

# Verify uninstallation
verify_uninstallation() {
    log INFO "Verifying uninstallation..."
    
    local issues=0
    
    # Check if installation directory still exists
    if [[ -d "$INSTALL_PREFIX" ]]; then
        log WARN "Installation directory still exists: $INSTALL_PREFIX"
        issues=$((issues + 1))
    fi
    
    # Check for LaunchAgents/LaunchDaemons
    if ls /Library/Launch*/com.schoolcode.* 2>/dev/null | grep -q .; then
        log WARN "Some LaunchAgents/LaunchDaemons still exist"
        issues=$((issues + 1))
    fi
    
    # Check for guest scripts
    if [[ -f "/usr/local/bin/guest_setup_auto.sh" ]]; then
        log WARN "Guest setup script still exists"
        issues=$((issues + 1))
    fi
    
    if [[ $issues -eq 0 ]]; then
        log SUCCESS "Uninstallation verified - SchoolCode has been completely removed"
        return 0
    else
        log WARN "Uninstallation completed with $issues issues"
        return 1
    fi
}

#############################################
# SUMMARY FUNCTIONS
#############################################

# Print uninstallation summary
print_summary() {
    echo ""
    echo -e "${BLUE}╔═══════════════════════════════════════╗${NC}"
    echo -e "${BLUE}║     Uninstallation Summary            ║${NC}"
    echo -e "${BLUE}╚═══════════════════════════════════════╝${NC}"
    echo ""
    echo "Statistics:"
    echo "  Files removed:    $FILES_REMOVED"
    echo "  Directories removed: $DIRS_REMOVED"
    echo "  Services stopped: $SERVICES_STOPPED"
    
    if [[ $ERRORS_OCCURRED -gt 0 ]]; then
        echo -e "  ${RED}Errors occurred: $ERRORS_OCCURRED${NC}"
    fi
    
    echo ""
    
    if [[ "$KEEP_LOGS" == "true" ]]; then
        echo "Log files kept in: $LOG_DIR"
    fi
    
    if [[ "$CREATE_BACKUP" == "true" ]]; then
        echo "Backup saved in: $BACKUP_DIR"
    fi
    
    echo ""
    echo "Uninstall log: $UNINSTALL_LOG"
}

# Show post-uninstall instructions
show_post_uninstall() {
    echo ""
    echo -e "${GREEN}╔═══════════════════════════════════════╗${NC}"
    echo -e "${GREEN}║   Uninstallation Complete! 🗑️         ║${NC}"
    echo -e "${GREEN}╚═══════════════════════════════════════╝${NC}"
    echo ""
    echo "SchoolCode has been removed from your system."
    echo ""
    echo "Note: The following were NOT removed:"
    echo "  • Homebrew installation"
    echo "  • Python installation"
    echo "  • User-installed packages"
    echo "  • Backup files (if any)"
    echo ""
    
    if [[ "$CREATE_BACKUP" == "true" ]]; then
        echo "To restore SchoolCode from backup:"
        echo "  1. Find your backup in $BACKUP_DIR"
        echo "  2. Run: tar -xzf [backup_file] -C /"
        echo "  3. Reinstall with: sudo /opt/schoolcode/scripts/install_schoolcode_v3.sh"
        echo ""
    fi
    
    echo "To reinstall SchoolCode:"
    echo "  git clone https://github.com/luka-loehr/SchoolCode.git"
    echo "  cd SchoolCode"
    echo "  sudo ./scripts/install_schoolcode_v3.sh"
    echo ""
    echo "Thank you for using SchoolCode! 👋"
}

#############################################
# MAIN EXECUTION
#############################################

main() {
    # Parse arguments
    parse_arguments "$@"
    
    # Print header
    echo ""
    echo -e "${RED}╔═══════════════════════════════════════╗${NC}"
    echo -e "${RED}║   SchoolCode Uninstaller v${SCRIPT_VERSION}      ║${NC}"
    echo -e "${RED}╚═══════════════════════════════════════╝${NC}"
    echo ""
    
    # Check root privileges
    check_root
    
    # Confirm uninstallation
    confirm_uninstall
    
    # Start uninstallation
    log INFO "Starting SchoolCode uninstallation..."
    
    # Create backup if requested
    create_backup
    
    # Perform uninstallation steps
    remove_launch_services
    remove_guest_scripts
    remove_path_configurations
    remove_installation_directory
    remove_temp_files
    remove_cron_jobs
    
    # Clean up logs (keep current uninstall log)
    remove_log_files
    
    # Final cleanup
    final_cleanup
    
    # Verify uninstallation
    verify_uninstallation
    
    # Print summary
    print_summary
    
    # Show post-uninstall instructions
    show_post_uninstall
    
    # Final log message
    log SUCCESS "SchoolCode uninstallation completed"
    
    # Remove log directory if empty and not keeping logs
    if [[ "$KEEP_LOGS" != "true" ]] && [[ -d "$LOG_DIR" ]]; then
        # Move final log to temp
        cp "$UNINSTALL_LOG" "/tmp/schoolcode_final_uninstall.log" 2>/dev/null || true
        rm -rf "$LOG_DIR" 2>/dev/null || true
        echo ""
        echo "Final uninstall log saved to: /tmp/schoolcode_final_uninstall.log"
    fi
    
    exit 0
}

# Run main
main "$@"
