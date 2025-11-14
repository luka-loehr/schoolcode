#!/bin/bash
# Copyright (c) 2025 Luka Löhr

# SchoolCode Hub - Central Management Interface
# Unified script for all SchoolCode operations

set -euo pipefail

# Script metadata
SCRIPT_VERSION="3.0.0"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$SCRIPT_DIR"
STATUS_FILE="$PROJECT_ROOT/.schoolcode-status"

# Source utility libraries
source "$SCRIPT_DIR/scripts/utils/logging.sh"

# Only source config.sh if not showing help (to avoid permission issues)
if [ "${1:-}" != "--help" ] && [ "${1:-}" != "-h" ]; then
    source "$SCRIPT_DIR/scripts/utils/config.sh"
fi

# Color codes for output
HEADER='\033[1;34m'
SUCCESS='\033[0;32m'
WARNING='\033[1;33m'
ERROR='\033[0;31m'
INFO='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

# Function to print formatted messages
print_header() {
    echo -e "${HEADER}╔═══════════════════════════════════════╗"
    echo -e "║           SchoolCode Hub v$SCRIPT_VERSION           ║"
    echo -e "╚═══════════════════════════════════════╝${NC}"
    echo ""
}

print_success() {
    echo -e "${SUCCESS}✅ $1${NC}"
}

print_error() {
    echo -e "${ERROR}❌ $1${NC}"
}

print_warning() {
    echo -e "${WARNING}⚠️  $1${NC}"
}

print_info() {
    echo -e "${INFO}ℹ️  $1${NC}"
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
    
    # Check if marker file exists (created by installer)
    if [[ ! -f "$STATUS_FILE" ]]; then
        echo "Warning: Marker file not found at $STATUS_FILE (should be created by installer)" >&2
        return 1
    fi
    
    # Validate status value
    case "$status" in
        "ready"|"error")
            ;;
        *)
            echo "Error: Invalid status value: $status" >&2
            return 1
            ;;
    esac
    
    # Get current values
    local schoolcode_version=$(get_schoolcode_version)
    local install_path="$PROJECT_ROOT"
    local installer_ip=$(get_installer_ip)
    local timestamp=$(date -u +%Y-%m-%dT%H:%M:%S.%3NZ)
    
    # Create status data structure
    local status_data
    if [[ "$status" == "ready" ]]; then
        status_data=$(cat << EOF
{
  "status": "$status",
  "cloned": true,
  "installed": true,
  "timestamp": "$timestamp",
  "install_path": "$install_path",
  "schoolcode_version": "$schoolcode_version",
  "message": "$message"
}
EOF
)
    else
        status_data=$(cat << EOF
{
  "status": "$status",
  "cloned": true,
  "timestamp": "$timestamp",
  "install_path": "$install_path",
  "schoolcode_version": "$schoolcode_version",
  "message": "$message"
}
EOF
)
    fi
    
    # Write status file with error handling
    if echo "$status_data" > "$STATUS_FILE" 2>/dev/null; then
        echo "Status updated: $status"
        return 0
    else
        echo "Error: Failed to update status file: $STATUS_FILE" >&2
        return 1
    fi
}

# Check if running as root (skip for help)
check_root() {
    if [ "$EUID" -ne 0 ] && [ "${1:-}" != "--help" ] && [ "${1:-}" != "-h" ]; then
        print_error "This script must be run as root (use sudo)"
        exit 1
    fi
}

# Run compatibility check
run_compatibility_check() {
    print_info "Running compatibility check..."
    if "$SCRIPT_DIR/scripts/utils/old_mac_compatibility.sh"; then
        print_success "Compatibility check passed!"
        return 0
    else
        print_error "Compatibility check failed!"
        return 1
    fi
}

# Run system repair
run_system_repair() {
    print_info "Running system repair..."
    if "$SCRIPT_DIR/scripts/utils/system_repair.sh"; then
        print_success "System repair completed!"
        return 0
    else
        print_error "System repair failed!"
        return 1
    fi
}

# Install tools
install_tools() {
    print_info "Installing development tools..."
    if "$SCRIPT_DIR/scripts/install.sh"; then
        print_success "Tools installation completed!"
        return 0
    else
        print_error "Tools installation failed!"
        return 1
    fi
}

# Setup guest account
setup_guest_account() {
    print_info "Setting up Guest account..."
    if "$SCRIPT_DIR/scripts/setup/setup_guest_shell_init.sh"; then
        print_success "Guest account setup completed!"
        return 0
    else
        print_error "Guest account setup failed!"
        return 1
    fi
}

# Show system status
show_status() {
    print_info "Checking system status..."
    "$SCRIPT_DIR/scripts/schoolcode-cli.sh" status detailed
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
        echo "Uninstallation completed."
        return 0
    else
        echo "Uninstallation failed."
        return 1
    fi
}

# Show logs
show_logs() {
    print_info "Available log types:"
    echo "1) All logs"
    echo "2) Error logs only"
    echo "3) Guest setup logs"
    echo "4) Installation logs"
    read -p "Select log type (1-4): " log_choice
    
    case $log_choice in
        1) "$SCRIPT_DIR/scripts/schoolcode-cli.sh" logs ;;
        2) "$SCRIPT_DIR/scripts/schoolcode-cli.sh" logs error ;;
        3) "$SCRIPT_DIR/scripts/schoolcode-cli.sh" logs guest ;;
        4) "$SCRIPT_DIR/scripts/schoolcode-cli.sh" logs install ;;
        *) print_error "Invalid selection" ;;
    esac
}

# Run tests
run_tests() {
    print_info "Running SchoolCode tests..."
    echo "1) Python tests"
    echo "2) Shell script tests"
    echo "3) Both"
    read -p "Select test type (1-3): " test_choice
    
    case $test_choice in
        1) python3 "$SCRIPT_DIR/test_schoolcode.py" ;;
        2) "$SCRIPT_DIR/tests/test_installation.sh" ;;
        3) 
            python3 "$SCRIPT_DIR/test_schoolcode.py"
            "$SCRIPT_DIR/tests/test_installation.sh"
            ;;
        *) print_error "Invalid selection" ;;
    esac
}


# Automatic mode (no flags) - runs full installation
automatic_mode() {
    print_header
    print_info "Running automatic installation mode..."
    echo ""
    
    # Run full installation sequence
    if run_compatibility_check && run_system_repair && install_tools && setup_guest_account; then
        print_success "SchoolCode installation completed successfully!"
        update_status "ready" "SchoolCode installation completed successfully"
        echo ""
        print_info "You can now:"
        echo "  • Switch to Guest account to test the installation"
        echo "  • Run './schoolcode.sh --status' to check system status"
        echo "  • Use './scripts/schoolcode-cli.sh' for advanced management"
    else
        print_error "Installation failed at some step. Check logs for details."
        update_status "error" "SchoolCode installation failed"
        echo ""
        print_info "You can run './schoolcode.sh --status' to check system status."
        exit 1
    fi
}

# Help function
show_help() {
    print_header
    echo "SchoolCode Hub - Central Management Interface"
    echo ""
    echo "Usage:"
    echo "  sudo ./schoolcode.sh                    # Install everything (automatic setup)"
    echo "  sudo ./schoolcode.sh --uninstall        # Remove SchoolCode (non-interactive)"
    echo "  sudo ./schoolcode.sh --status           # Show system status"
    echo "  sudo ./schoolcode.sh --help             # Show this help"
    echo ""
    echo "Installation Mode (no flags):"
    echo "  Runs compatibility check, system repair, tool installation, and guest setup"
    echo ""
    echo "Uninstall Mode (--uninstall):"
    echo "  Removes SchoolCode and all installed tools from Guest accounts (no prompts)"
    echo ""
    echo "Status Mode (--status):"
    echo "  Shows comprehensive system health and installation status"
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