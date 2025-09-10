#!/bin/bash
# Copyright (c) 2025 Luka Löhr

# SchoolCode CLI Management Tool (Bash 3.2 Compatible)
# Comprehensive command-line interface for SchoolCode administration

set -euo pipefail  # Strict error handling

# Script metadata
SCRIPT_VERSION="2.1.0"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Source utility libraries
source "$SCRIPT_DIR/utils/logging.sh" 2>/dev/null || {
    echo "Error: Could not load logging utilities"
    exit 1
}
source "$SCRIPT_DIR/utils/config.sh" 2>/dev/null || {
    echo "Error: Could not load configuration utilities"
    exit 1
}

# CLI configuration
COMMAND=""
SUBCOMMAND=""
OPTIONS=()
VERBOSE=false
DRY_RUN=false
FORCE=false

# Color codes for CLI output (bash 3.2 compatible)
CLI_HEADER='\033[1;34m'
CLI_SUCCESS='\033[0;32m'
CLI_WARNING='\033[1;33m'
CLI_ERROR='\033[0;31m'
CLI_INFO='\033[0;36m'
CLI_BOLD='\033[1m'
CLI_NC='\033[0m'

# Function to print formatted messages
print_header() {
    echo -e "${CLI_HEADER}╔═══════════════════════════════════════╗"
    echo -e "║           SchoolCode CLI v$SCRIPT_VERSION           ║"
    echo -e "╚═══════════════════════════════════════╝${CLI_NC}"
    echo ""
}

print_success() {
    echo -e "${CLI_SUCCESS}✅ $1${CLI_NC}"
}

print_warning() {
    echo -e "${CLI_WARNING}⚠️  $1${CLI_NC}"
}

print_error() {
    echo -e "${CLI_ERROR}❌ $1${CLI_NC}"
}

print_info() {
    echo -e "${CLI_INFO}ℹ️  $1${CLI_NC}"
}

# Function to show help
show_help() {
    print_header
    echo "SchoolCode - Automated Development Tools for macOS Guest Accounts"
    echo ""
    echo -e "${CLI_BOLD}USAGE:${CLI_NC}"
    echo "  $0 <command> [subcommand] [options]"
    echo ""
    echo -e "${CLI_BOLD}COMMANDS:${CLI_NC}"
    echo ""
    echo -e "${CLI_INFO}Installation & Setup:${CLI_NC}"
    echo "  install         Install SchoolCode system"
    echo "  uninstall       Remove SchoolCode system"
    echo "  update          Update SchoolCode and all dependencies"
    echo ""
    echo -e "${CLI_INFO}System Management:${CLI_NC}"
    echo "  status          Show system status"
    echo "  health          Run health checks"
    echo "  logs            View system logs"
    echo ""
    echo -e "${CLI_INFO}Configuration:${CLI_NC}"
    echo "  config          Manage configuration"
    echo "  tools           Manage tools"
    echo "  permissions     Fix permissions"
    echo ""
    echo -e "${CLI_INFO}Guest Management:${CLI_NC}"
    echo "  guest           Guest account operations"
    echo ""
    echo ""
    echo -e "${CLI_BOLD}GLOBAL OPTIONS:${CLI_NC}"
    echo "  -v, --verbose   Enable verbose output"
    echo "  -q, --quiet     Suppress non-error output"
    echo "  --dry-run       Show what would be done without executing"
    echo "  --force         Force operations without confirmation"
    echo "  -h, --help      Show this help message"
    echo "  --version       Show version information"
    echo ""
    echo -e "${CLI_BOLD}EXAMPLES:${CLI_NC}"
    echo "  $0 install              # Install SchoolCode"
    echo "  $0 status --verbose     # Show detailed status"
    echo "  $0 update               # Update to latest version from GitHub"
    echo "  $0 health detailed      # Run detailed health check"
    echo "  $0 config show          # Show current configuration"
    echo "  $0 tools list           # List available tools"
    echo "  $0 guest setup          # Setup guest environment"
    echo "  $0 logs error           # Show error logs"
    echo ""
}

# Function to show version
show_version() {
    print_header
    echo "SchoolCode CLI Version: $SCRIPT_VERSION"
    echo "© 2025 Luka Löhr"
    echo ""
    echo "System Information:"
    echo "  macOS Version: $(sw_vers -productVersion 2>/dev/null || echo 'unknown')"
    echo "  Hostname: $(hostname)"
    echo "  Current User: $(whoami)"
    echo "  Script Location: $SCRIPT_DIR"
    echo ""
}

# Parse command line arguments
parse_args() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            -v|--verbose)
                VERBOSE=true
                export SCHOOLCODE_LOG_LEVEL=0  # Debug level
                shift
                ;;
            -q|--quiet)
                export SCHOOLCODE_LOG_LEVEL=3  # Error level only
                shift
                ;;
            --dry-run)
                DRY_RUN=true
                print_info "Dry run mode enabled - no changes will be made"
                shift
                ;;
            --force)
                FORCE=true
                shift
                ;;
            -h|--help)
                show_help
                exit 0
                ;;
            --version)
                show_version
                exit 0
                ;;
            -*)
                print_error "Unknown option: $1"
                echo "Use '$0 --help' for usage information."
                exit 1
                ;;
            *)
                if [[ -z "$COMMAND" ]]; then
                    COMMAND="$1"
                elif [[ -z "$SUBCOMMAND" ]]; then
                    SUBCOMMAND="$1"
                else
                    OPTIONS+=("$1")
                fi
                shift
                ;;
        esac
    done
}

# Function to require root privileges
require_root() {
    if [[ $EUID -ne 0 ]]; then
        print_error "This operation requires administrator privileges"
        echo "Please run: sudo $0 $COMMAND $SUBCOMMAND"
        exit 1
    fi
}

# Function to confirm destructive operations
confirm_operation() {
    local message="$1"
    
    if [[ "$FORCE" == "true" ]]; then
        return 0
    fi
    
    print_warning "$message"
    echo -n "Continue? (y/N): "
    read -r response
    
    if [[ ! "$response" =~ ^[yY]$ ]]; then
        print_info "Operation cancelled"
        exit 0
    fi
}

# Installation commands
cmd_install() {
    require_root
    
    case "$SUBCOMMAND" in
        ""|"full")
            print_header
            log_info "Starting SchoolCode installation..."
            
            if [[ "$DRY_RUN" == "true" ]]; then
                print_info "Would run: setup.sh"
                return
            fi
            
            if SCHOOLCODE_CLI_INSTALL=true bash "$SCRIPT_DIR/setup.sh"; then
                print_success "SchoolCode installation completed successfully"
                echo ""
                # Show health status (no clear to preserve installation logs)
                print_header
                print_success "Installation Complete!"
                echo ""
                # Run health check to show system status
                bash "$SCRIPT_DIR/utils/monitoring.sh" status
            else
                print_error "Installation failed"
                exit 1
            fi
            ;;
        "tools")
            print_info "Installing tools only..."
            if [[ "$DRY_RUN" == "false" ]]; then
                SCHOOLCODE_CLI_INSTALL=true bash "$SCRIPT_DIR/install.sh"
            fi
            ;;
        "agent")
            print_info "Installing LaunchAgent only..."
            if [[ "$DRY_RUN" == "false" ]]; then
                bash "$SCRIPT_DIR/setup/setup_guest_shell_init.sh"
            fi
            ;;
        *)
            print_error "Unknown install subcommand: $SUBCOMMAND"
            echo "Available: full, tools, agent"
            exit 1
            ;;
    esac
}

# Uninstall commands
cmd_uninstall() {
    require_root
    
    confirm_operation "This will remove all SchoolCode components from the system."
    
    print_info "Removing SchoolCode..."
    if [[ "$DRY_RUN" == "false" ]]; then
        SCHOOLCODE_CLI_UNINSTALL=true bash "$SCRIPT_DIR/uninstall.sh"
    fi
    print_success "SchoolCode uninstallation completed"
    echo ""
    echo "Note: Homebrew and packages (git, python) were NOT removed."
}

# Status commands
cmd_status() {
    case "$SUBCOMMAND" in
        ""|"brief")
            bash "$SCRIPT_DIR/utils/monitoring.sh" status
            ;;
        "detailed")
            bash "$SCRIPT_DIR/utils/monitoring.sh" detailed
            ;;
        "json")
            bash "$SCRIPT_DIR/utils/monitoring.sh" json
            ;;
        *)
            print_error "Unknown status subcommand: $SUBCOMMAND"
            echo "Available: brief, detailed, json"
            exit 1
            ;;
    esac
}

# Health check commands
cmd_health() {
    case "$SUBCOMMAND" in
        ""|"basic")
            bash "$SCRIPT_DIR/utils/monitoring.sh" status
            ;;
        "detailed")
            bash "$SCRIPT_DIR/utils/monitoring.sh" detailed
            ;;
        "continuous")
            local interval="${OPTIONS[0]:-300}"
            print_info "Starting continuous health monitoring (interval: ${interval}s)"
            bash "$SCRIPT_DIR/utils/monitoring.sh" monitor "$interval"
            ;;
        *)
            print_error "Unknown health subcommand: $SUBCOMMAND"
            echo "Available: basic, detailed, continuous [interval]"
            exit 1
            ;;
    esac
}

# Configuration commands
cmd_config() {
    case "$SUBCOMMAND" in
        "show")
            show_config
            ;;
        "edit")
            local config_file=$(get_config "USER_CONFIG_FILE" "$HOME/.schoolcode.conf")
            ${EDITOR:-nano} "$config_file"
            print_success "Configuration file opened for editing"
            ;;
        "reset")
            local scope="${OPTIONS[0]:-user}"
            confirm_operation "This will reset configuration to defaults (scope: $scope)"
            
            if [[ "$DRY_RUN" == "false" ]]; then
                reset_config "$scope"
            fi
            print_success "Configuration reset to defaults"
            ;;
        "validate")
            if validate_config; then
                print_success "Configuration is valid"
            else
                print_error "Configuration validation failed"
                exit 1
            fi
            ;;
        "set")
            if [[ ${#OPTIONS[@]} -lt 2 ]]; then
                print_error "Usage: $0 config set <key> <value> [scope]"
                exit 1
            fi
            
            local key="${OPTIONS[0]}"
            local value="${OPTIONS[1]}"
            local scope="${OPTIONS[2]:-user}"
            
            if [[ "$DRY_RUN" == "false" ]]; then
                set_config "$key" "$value" "$scope"
            fi
            print_success "Set $key=$value (scope: $scope)"
            ;;
        *)
            print_error "Unknown config subcommand: $SUBCOMMAND"
            echo "Available: show, edit, reset [scope], validate, set <key> <value> [scope]"
            exit 1
            ;;
    esac
}

# Tools management commands
cmd_tools() {
    case "$SUBCOMMAND" in
        "list")
            print_info "Configured tools:"
            local tools_array=($(get_tools_array))
            if [[ ${#tools_array[@]} -gt 0 ]]; then
                for tool in "${tools_array[@]}"; do
                    local description=$(get_tool_info "$tool" "description")
                    printf "  %-10s - %s\n" "$tool" "$description"
                done
            else
                echo "  No tools configured"
            fi
            ;;
        "versions")
            print_info "Tool versions:"
            local tools_array=($(get_tools_array))
            if [[ ${#tools_array[@]} -gt 0 ]]; then
                for tool in "${tools_array[@]}"; do
                    local version_cmd=$(get_tool_info "$tool" "version_cmd")
                    if [[ -n "$version_cmd" ]]; then
                        local version=$(eval "$tool $version_cmd" 2>/dev/null || echo "unknown")
                        printf "  %-10s - %s\n" "$tool" "$version"
                    fi
                done
            else
                echo "  No tools configured"
            fi
            ;;
        "install")
            require_root
            local tool="${OPTIONS[0]:-}"
            if [[ -z "$tool" ]]; then
                print_error "Usage: $0 tools install <tool>"
                exit 1
            fi
            
            print_info "Installing tool: $tool"
            if is_homebrew_tool "$tool"; then
                if [[ "$DRY_RUN" == "false" ]]; then
                    brew install "$tool"
                fi
            else
                print_warning "Tool $tool is not managed by Homebrew"
            fi
            ;;
        *)
            print_error "Unknown tools subcommand: $SUBCOMMAND"
            echo "Available: list, versions, install <tool>"
            exit 1
            ;;
    esac
}

# Guest management commands
cmd_guest() {
    case "$SUBCOMMAND" in
        "setup")
            if [[ "$USER" != "Guest" ]]; then
                print_warning "This command should be run as the Guest user"
            fi
            
            if [[ "$DRY_RUN" == "false" ]]; then
                bash "$SCRIPT_DIR/guest_setup_auto.sh"
            fi
            print_success "Guest setup completed"
            ;;
        "test")
            bash "$SCRIPT_DIR/utils/monitoring.sh" guest
            ;;
        "cleanup")
            if [[ "$USER" == "Guest" ]]; then
                local guest_tools_dir=$(get_config "GUEST_TOOLS_DIR")
                confirm_operation "This will remove guest tools directory: $guest_tools_dir"
                
                if [[ "$DRY_RUN" == "false" ]]; then
                    rm -rf "$guest_tools_dir"
                fi
                print_success "Guest tools cleaned up"
            else
                print_warning "This command should be run as the Guest user"
            fi
            ;;
        *)
            print_error "Unknown guest subcommand: $SUBCOMMAND"
            echo "Available: setup, test, cleanup"
            exit 1
            ;;
    esac
}

# Logs commands
cmd_logs() {
    case "$SUBCOMMAND" in
        ""|"all")
            show_logs "${OPTIONS[0]:-50}" "all"
            ;;
        "error")
            show_logs "${OPTIONS[0]:-20}" "error"
            ;;
        "guest")
            show_logs "${OPTIONS[0]:-30}" "guest"
            ;;
        "alerts")
            bash "$SCRIPT_DIR/utils/monitoring.sh" alerts "${OPTIONS[0]:-20}"
            ;;
        "clear")
            confirm_operation "This will clear all SchoolCode logs"
            if [[ "$DRY_RUN" == "false" ]]; then
                clear_logs
            fi
            print_success "Logs cleared"
            ;;
        "tail")
            print_info "Tailing SchoolCode logs (Ctrl+C to stop)..."
            tail -f /var/log/schoolcode/schoolcode.log 2>/dev/null || {
                print_error "Log file not accessible"
                exit 1
            }
            ;;
        *)
            print_error "Unknown logs subcommand: $SUBCOMMAND"
            echo "Available: all [lines], error [lines], guest [lines], alerts [lines], clear, tail"
            exit 1
            ;;
    esac
}

# Permissions commands
cmd_permissions() {
    require_root
    
    case "$SUBCOMMAND" in
        ""|"fix")
            print_info "Fixing permissions..."
            if [[ "$DRY_RUN" == "false" ]]; then
                bash "$SCRIPT_DIR/utils/fix_homebrew_permissions.sh"
            fi
            print_success "Permissions fixed"
            ;;
        "check")
            print_info "Checking permissions..."
            # This would be part of the monitoring health check
            bash "$SCRIPT_DIR/utils/monitoring.sh" status | grep -A 20 "Component Status"
            ;;
        *)
            print_error "Unknown permissions subcommand: $SUBCOMMAND"
            echo "Available: fix, check"
            exit 1
            ;;
    esac
}

# Update command
cmd_update() {
    require_root
    
    print_info "Updating SchoolCode and all dependencies..."
    
    if [[ "$DRY_RUN" == "true" ]]; then
        print_info "Would update SchoolCode, Python, Git, Homebrew, and pip"
        return
    fi
    
    # Update SchoolCode first
    print_info "Pulling latest SchoolCode from GitHub..."
    
    # Change to repo directory
    cd "$(dirname "$SCRIPT_DIR")"
    
    # Stash any local changes
    if ! git diff-index --quiet HEAD -- 2>/dev/null; then
        git stash push -m "SchoolCode update stash $(date +%Y%m%d_%H%M%S)" >/dev/null 2>&1
    fi
    
    # Pull latest changes
    git fetch --all --tags >/dev/null 2>&1
    git pull origin main >/dev/null 2>&1 || git pull origin master >/dev/null 2>&1
    
    # Make scripts executable
    find "$SCRIPT_DIR" -name "*.sh" -type f -exec chmod +x {} \; 2>/dev/null
    
    print_success "SchoolCode code updated"
    
    # Update all dependencies
    print_info "Updating Python, Git, Homebrew, and pip..."
    bash "$SCRIPT_DIR/utils/update_dependencies.sh"
    
    # Run installation to apply updates
    print_info "Applying updates..."
    bash "$SCRIPT_DIR/install.sh"
    
    print_success "Update completed successfully!"
}



# Main command dispatcher
main() {
    # Parse arguments
    parse_args "$@"
    
    # If no command provided, show help
    if [[ -z "$COMMAND" ]]; then
        show_help
        exit 0
    fi
    
    # Dispatch to command function
    case "$COMMAND" in
        install)     cmd_install ;;
        uninstall)   cmd_uninstall ;;
        status)      cmd_status ;;
        health)      cmd_health ;;
        config)      cmd_config ;;
        tools)       cmd_tools ;;
        guest)       cmd_guest ;;
        logs)        cmd_logs ;;
        permissions) cmd_permissions ;;
        update)      cmd_update ;;
        *)
            print_error "Unknown command: $COMMAND"
            echo "Use '$0 --help' for usage information."
            exit 1
            ;;
    esac
}

# Run main function
main "$@" 