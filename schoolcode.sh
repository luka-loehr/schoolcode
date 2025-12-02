#!/bin/bash
# Copyright (c) 2025 Luka Löhr

# SchoolCode Hub - Central Management Interface
# Unified script for all SchoolCode operations

set -euo pipefail

# Script metadata
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$SCRIPT_DIR"

# Fetch version from GitHub releases (with fallback)
get_version() {
    local version="0.0.0"  # Fallback version
    
    # Try to fetch latest release from GitHub
    if command -v curl &>/dev/null; then
        local github_version=$(curl -s --connect-timeout 2 "https://api.github.com/repos/luka-loehr/schoolcode/releases/latest" 2>/dev/null | grep '"tag_name":' | sed -E 's/.*"([^"]+)".*/\1/' | sed 's/^v//')
        if [[ -n "$github_version" ]] && [[ "$github_version" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
            version="$github_version"
        fi
    fi
    
    echo "$version"
}

SCRIPT_VERSION=$(get_version)

# Source utility libraries
source "$SCRIPT_DIR/scripts/utils/logging.sh"

# Only source config.sh if not showing help (to avoid permission issues)
if [ "${1:-}" != "--help" ] && [ "${1:-}" != "-h" ]; then
    source "$SCRIPT_DIR/scripts/utils/config.sh"
fi

# Create convenience aliases for logging functions - consolidate approach
print_error() {
    if declare -f log_error >/dev/null 2>&1; then
        log_error "$@"
    else
        echo -e "${ERROR}[ERROR]${NC} $@" >&2
    fi
}

print_info() {
    if declare -f log_info >/dev/null 2>&1; then
        log_info "$@"
    else
        echo -e "${INFO}[INFO]${NC} $@"
    fi
}

print_warning() {
    if declare -f log_warn >/dev/null 2>&1; then
        log_warn "$@"
    else
        echo -e "${WARNING}[WARN]${NC} $@" >&2
    fi
}

# Color codes for output
HEADER='\033[1;34m'
SUCCESS='\033[0;32m'
WARNING='\033[1;33m'
ERROR='\033[0;31m'
INFO='\033[0;36m'
DIM='\033[2m'
BOLD='\033[1m'
NC='\033[0m'

# Premium header
print_header() {
    local width=50
    echo ""
    printf "${HEADER}"
    printf "╭"
    printf '─%.0s' $(seq 1 $((width-2)))
    printf "╮\n"
    
    local title="SchoolCode v$SCRIPT_VERSION"
    local padding=$(( (width - 2 - ${#title}) / 2 ))
    printf "│"
    printf ' %.0s' $(seq 1 $padding)
    printf "%s" "$title"
    printf ' %.0s' $(seq 1 $((width - 2 - padding - ${#title})))
    printf "│\n"
    
    printf "╰"
    printf '─%.0s' $(seq 1 $((width-2)))
    printf "╯${NC}\n"
}

# Status reporting functions
get_schoolcode_version() {
    local version="latest"
    if [[ -f "$PROJECT_ROOT/version.txt" ]]; then
        local file_version=$(cat "$PROJECT_ROOT/version.txt" 2>/dev/null | head -1 | tr -d '\n\r')
        if [[ -n "$file_version" ]]; then
            version="$file_version"
        fi
    fi
    echo "$version"
}

get_installer_ip() {
    local ip=""
    if command -v ifconfig &>/dev/null; then
        ip=$(ifconfig | grep -E "inet [0-9]" | grep -v "127.0.0.1" | head -1 | awk '{print $2}' 2>/dev/null || echo "")
    elif command -v ip &>/dev/null; then
        ip=$(ip route get 1 2>/dev/null | awk '{print $7; exit}' 2>/dev/null || echo "")
    fi
    if [[ -z "$ip" ]]; then
        ip="127.0.0.1"
    fi
    echo "$ip"
}

update_status() {
    local status="$1"
    local message="${2:-}"
    # Status updates are logged but no longer write to marker file
    log_info "Status: $status - $message"
}

# Check if running as root (skip for help and logs)
check_root() {
    local cmd="${1:-}"
    # These commands don't require root
    if [ "$EUID" -ne 0 ] && [ "$cmd" != "--help" ] && [ "$cmd" != "-h" ] && [ "$cmd" != "--logs" ] && [ "$cmd" != "-l" ]; then
        print_error "This script must be run as root (use sudo)"
        exit 1
    fi
}

# Simple progress display (no background processes)
show_progress() {
    printf "  ${INFO}•${NC} %s..." "$1"
}

show_result() {
    local result="$1"
    local msg="${2:-}"
    # Clear line and show result
    printf "\r\033[K"  # Move to start and clear line
    case "$result" in
        success) printf "  ${SUCCESS}✓${NC} %s\n" "$msg" ;;
        error)   printf "  ${ERROR}✗${NC} %s\n" "$msg" ;;
        warning) printf "  ${WARNING}!${NC} %s\n" "$msg" ;;
    esac
}

# Run compatibility check
do_compatibility_check() {
    show_progress "Checking system compatibility"
    
    # Source compatibility script to get access to its functions (in quiet mode)
    export SCHOOLCODE_QUIET=true
    source "$SCRIPT_DIR/scripts/utils/old_mac_compatibility.sh"
    run_compatibility_check  # This calls the function from old_mac_compatibility.sh
    
    local errors=$(get_compatibility_errors)
    local warnings=$(get_compatibility_warnings)
    
    if [[ $errors -gt 0 ]]; then
        show_result "error" "System compatibility check failed"
        printf "\n  ${ERROR}Issues found:${NC}\n"
        while IFS= read -r issue; do
            [[ -n "$issue" ]] && printf "    ${DIM}• %s${NC}\n" "$issue"
        done < <(get_compatibility_issues)
        return 1
    elif [[ $warnings -gt 0 ]]; then
        show_result "warning" "System compatible ($warnings warnings)"
        return 0
    else
        show_result "success" "System compatible"
        return 0
    fi
}

# Run system repair
do_system_repair() {
    show_progress "Preparing system"
    
    # Source repair script to get access to its functions (in quiet mode)
    export SCHOOLCODE_QUIET=true
    source "$SCRIPT_DIR/scripts/utils/system_repair.sh"
    run_system_repairs  # This calls the function from system_repair.sh
    
    local repairs=$(get_repairs_performed)
    
    if [[ $repairs -gt 0 ]]; then
        show_result "success" "System prepared ($repairs fixes applied)"
    else
        show_result "success" "System ready"
    fi
    return 0
}

# Install tools
do_install_tools() {
    show_progress "Installing development tools"
    
    # Create temporary file for error capture
    local error_log="/tmp/schoolcode_install_error_$$.log"
    
    # Run install script with quiet mode, capture stderr
    if SCHOOLCODE_QUIET=true "$SCRIPT_DIR/scripts/install.sh" -q 2>"$error_log"; then
        show_result "success" "Development tools installed"
        rm -f "$error_log"
        return 0
    else
        local exit_code=$?
        show_result "error" "Tool installation failed"
        
        # Show error details if available
        if [[ -s "$error_log" ]]; then
            printf "\n  ${DIM}Error details:${NC}\n"
            while IFS= read -r line; do
                [[ -n "$line" ]] && printf "    ${DIM}• %s${NC}\n" "$line"
            done < "$error_log"
        fi
        
        # Show latest install log file
        local latest_log=$(ls -t /var/log/schoolcode/install_*.log 2>/dev/null | head -1)
        if [[ -n "$latest_log" ]]; then
            printf "\n  ${DIM}See full log: %s${NC}\n" "$latest_log"
        fi
        
        rm -f "$error_log"
        return "$exit_code"
    fi
}

# Setup guest account
do_setup_guest() {
    show_progress "Configuring Guest account"
    
    if SCHOOLCODE_QUIET=true "$SCRIPT_DIR/scripts/setup/setup_guest_shell_init.sh" 2>/dev/null; then
        show_result "success" "Guest account configured"
        return 0
    else
        show_result "error" "Guest setup failed"
        return 1
    fi
}

# Show system status
show_status() {
    log_operation_start "STATUS" "Health check"
    print_info "Checking system status..."
    "$SCRIPT_DIR/scripts/schoolcode-cli.sh" status detailed
    log_operation_end "STATUS" "SUCCESS"
}

# Update SchoolCode
update_schoolcode() {
    print_info "Updating SchoolCode..."
    "$SCRIPT_DIR/scripts/schoolcode-cli.sh" update
}

# Uninstall SchoolCode (interactive)
uninstall_schoolcode() {
    print_warning "This will remove SchoolCode and all installed tools from Guest accounts."
    read -p "Are you sure you want to continue? (y/N): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        print_info "Uninstalling SchoolCode..."
        "$SCRIPT_DIR/scripts/schoolcode-cli.sh" uninstall
    else
        print_info "Uninstall cancelled."
    fi
}

# Uninstall SchoolCode (non-interactive)
uninstall_schoolcode_noninteractive() {
    echo "Removing SchoolCode..."
    if "$SCRIPT_DIR/scripts/schoolcode-cli.sh" --force uninstall; then
        return 0
    else
        echo "Uninstallation failed."
        return 1
    fi
}

# Show logs - comprehensive log viewing utility
show_logs() {
    local subcommand="${1:-}"
    local lines="${2:-50}"
    
    case "$subcommand" in
        errors|error)
            echo "${BOLD}=== Error Logs (last $lines) ===${NC}"
            if [[ -f "/var/log/schoolcode/schoolcode-error.log" ]]; then
                tail -n "$lines" /var/log/schoolcode/schoolcode-error.log
            else
                echo "No error logs found"
            fi
            ;;
        warnings|warn)
            echo "${BOLD}=== Warning Logs (last $lines) ===${NC}"
            if [[ -f "/var/log/schoolcode/schoolcode.log" ]]; then
                grep "\[WARN\]" /var/log/schoolcode/schoolcode.log | tail -n "$lines"
            else
                echo "No logs found"
            fi
            ;;
        install)
            echo "${BOLD}=== Latest Install Log ===${NC}"
            local latest_install=$(ls -t /var/log/schoolcode/install_*.log 2>/dev/null | head -1)
            if [[ -n "$latest_install" ]]; then
                echo "File: $latest_install"
                echo ""
                tail -n "$lines" "$latest_install"
            else
                echo "No install logs found"
            fi
            ;;
        guest)
            echo "${BOLD}=== Guest Setup Logs (last $lines) ===${NC}"
            if [[ -f "/var/log/schoolcode/guest-setup.log" ]]; then
                tail -n "$lines" /var/log/schoolcode/guest-setup.log
            else
                echo "No guest logs found"
            fi
            ;;
        today)
            echo "${BOLD}=== Today's Logs ===${NC}"
            local today=$(date '+%Y-%m-%d')
            if [[ -f "/var/log/schoolcode/schoolcode.log" ]]; then
                grep "$today" /var/log/schoolcode/schoolcode.log | tail -n "$lines"
            else
                echo "No logs found"
            fi
            ;;
        events)
            echo "${BOLD}=== Structured Events (JSON) ===${NC}"
            if [[ -f "/var/log/schoolcode/events.json" ]]; then
                cat /var/log/schoolcode/events.json
            else
                echo "No events logged"
            fi
            ;;
        metrics)
            echo "${BOLD}=== Performance Metrics (JSON) ===${NC}"
            if [[ -f "/var/log/schoolcode/metrics.json" ]]; then
                cat /var/log/schoolcode/metrics.json
            else
                echo "No metrics logged"
            fi
            ;;
        tail)
            echo "${BOLD}=== Tail Main Log (last $lines) ===${NC}"
            if [[ -f "/var/log/schoolcode/schoolcode.log" ]]; then
                tail -n "$lines" /var/log/schoolcode/schoolcode.log
            else
                echo "No logs found"
            fi
            ;;
        all|"")
            echo "${BOLD}SchoolCode Log Viewer${NC}"
            echo ""
            echo "${BOLD}Usage:${NC} ./schoolcode.sh --logs [TYPE] [LINES]"
            echo ""
            echo "${BOLD}Log Types:${NC}"
            echo "  errors    - Show only error logs"
            echo "  warnings  - Show only warning logs"
            echo "  install   - Show latest installation log"
            echo "  guest     - Show guest setup logs"
            echo "  today     - Show today's logs"
            echo "  events    - Show structured events (JSON)"
            echo "  metrics   - Show performance metrics (JSON)"
            echo "  tail      - Show recent main log entries"
            echo ""
            echo "${BOLD}Examples:${NC}"
            echo "  ./schoolcode.sh --logs errors 100"
            echo "  ./schoolcode.sh --logs install"
            echo "  ./schoolcode.sh --logs tail 200"
            ;;
        *)
            print_error "Unknown log type: $subcommand"
            echo "Run './schoolcode.sh --logs' for usage"
            exit 1
            ;;
    esac
}

# Run tests
run_tests() {
    print_info "Running SchoolCode tests..."
    echo "1) Python tests"
    echo "2) Shell script tests"
    echo "3) Both"
    read -p "Select test type (1-3): " test_choice
    
    local test_py=""
    local test_sh=""
    
    # Find test files
    if [[ -f "$PROJECT_ROOT/test_schoolcode.py" ]]; then
        test_py="$PROJECT_ROOT/test_schoolcode.py"
    elif [[ -f "$SCRIPT_DIR/test_schoolcode.py" ]]; then
        test_py="$SCRIPT_DIR/test_schoolcode.py"
    fi
    
    if [[ -f "$PROJECT_ROOT/tests/test_installation.sh" ]]; then
        test_sh="$PROJECT_ROOT/tests/test_installation.sh"
    elif [[ -f "$SCRIPT_DIR/tests/test_installation.sh" ]]; then
        test_sh="$SCRIPT_DIR/tests/test_installation.sh"
    fi
    
    case $test_choice in
        1) 
            if [[ -n "$test_py" ]]; then
                python3 "$test_py"
            else
                print_error "Could not find test_schoolcode.py"
            fi
            ;;
        2) 
            if [[ -n "$test_sh" ]]; then
                "$test_sh"
            else
                print_error "Could not find test_installation.sh"
            fi
            ;;
        3) 
            if [[ -n "$test_py" ]]; then
                python3 "$test_py"
            fi
            if [[ -n "$test_sh" ]]; then
                "$test_sh"
            fi
            ;;
        *) print_error "Invalid selection" ;;
    esac
}


# Automatic mode (no flags) - runs full installation
automatic_mode() {
    print_header
    echo ""
    
    log_operation_start "INSTALL" "SchoolCode v$SCRIPT_VERSION"
    
    # Run full installation sequence
    local failed=false
    
    do_compatibility_check || failed=true
    
    if [[ "$failed" != "true" ]]; then
        do_system_repair || failed=true
    fi
    
    if [[ "$failed" != "true" ]]; then
        do_install_tools || failed=true
    fi
    
    if [[ "$failed" != "true" ]]; then
        do_setup_guest || failed=true
    fi
    
    echo ""
    
    if [[ "$failed" != "true" ]]; then
        # Success box
        local width=50
        printf "${SUCCESS}"
        printf "╭"
        printf '─%.0s' $(seq 1 $((width-2)))
        printf "╮\n"
        
        local msg="Installation Complete!"
        local padding=$(( (width - 2 - ${#msg}) / 2 ))
        printf "│"
        printf ' %.0s' $(seq 1 $padding)
        printf "%s" "$msg"
        printf ' %.0s' $(seq 1 $((width - 2 - padding - ${#msg})))
        printf "│\n"
        
        printf "╰"
        printf '─%.0s' $(seq 1 $((width-2)))
        printf "╯${NC}\n"
        
        update_status "ready" "SchoolCode installation completed successfully"
        log_operation_end "INSTALL" "SUCCESS"
        echo ""
        printf "  ${DIM}Next steps:${NC}\n"
        printf "    • Switch to Guest account to test\n"
        printf "    • Run ${BOLD}./schoolcode.sh --status${NC} to verify\n"
    else
        # Error box
        local width=50
        printf "${ERROR}"
        printf "╭"
        printf '─%.0s' $(seq 1 $((width-2)))
        printf "╮\n"
        
        local msg="Installation Failed"
        local padding=$(( (width - 2 - ${#msg}) / 2 ))
        printf "│"
        printf ' %.0s' $(seq 1 $padding)
        printf "%s" "$msg"
        printf ' %.0s' $(seq 1 $((width - 2 - padding - ${#msg})))
        printf "│\n"
        
        printf "╰"
        printf '─%.0s' $(seq 1 $((width-2)))
        printf "╯${NC}\n"
        
        update_status "error" "SchoolCode installation failed"
        log_operation_end "INSTALL" "FAILED"
        echo ""
        printf "  ${DIM}Check logs: /var/log/schoolcode/${NC}\n"
        exit 1
    fi
}

# Help function
show_help() {
    print_header
    echo ""
    printf "  ${BOLD}Usage:${NC}\n"
    printf "    sudo ./schoolcode.sh              ${DIM}Install everything${NC}\n"
    printf "    sudo ./schoolcode.sh --uninstall  ${DIM}Remove SchoolCode${NC}\n"
    printf "    sudo ./schoolcode.sh --status     ${DIM}Show system status${NC}\n"
    printf "    sudo ./schoolcode.sh --logs       ${DIM}View logs${NC}\n"
    printf "    sudo ./schoolcode.sh --help       ${DIM}Show this help${NC}\n"
    echo ""
    printf "  ${BOLD}Log Viewer:${NC}\n"
    printf "    ./schoolcode.sh --logs [type] [lines]\n"
    printf "    ${DIM}Types: errors, warnings, install, guest, today, events, metrics, tail${NC}\n"
    echo ""
}

# Main script logic
main() {
    # Check if running as root (skip for help)
    check_root "${1:-}"
    
    # Parse command line arguments
    case "${1:-}" in
        --install)
            # Explicit installation mode (same as no flags)
            automatic_mode
            ;;
        --uninstall)
            # Non-interactive uninstall mode
            uninstall_schoolcode_noninteractive
            ;;
        --status|-s)
            show_status
            ;;
        --logs|-l)
            show_logs "${2:-}" "${3:-50}"
            ;;
        --help|-h)
            show_help
            ;;
        "")
            # No arguments - run automatic mode
            automatic_mode
            ;;
        *)
            print_error "Unknown option: $1"
            echo ""
            show_help
            exit 1
            ;;
    esac
}

# Run main function
main "$@"