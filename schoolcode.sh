#!/bin/bash
# Copyright (c) 2025 Luka Löhr

# SchoolCode Hub - Central Management Interface
# Unified script for all SchoolCode operations

set -euo pipefail

# Script metadata
SCRIPT_VERSION="3.0.1"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Detect if running from Homebrew installation
if [[ "$SCRIPT_DIR" == *"/Cellar/schoolcode"* ]] || [[ "$SCRIPT_DIR" == *"/Homebrew"* ]]; then
    # Running from Homebrew installation
    # Scripts are in libexec/scripts, main script is in bin
    
    # First, try to find the Cellar path directly
    if [[ "$SCRIPT_DIR" == *"/Cellar/schoolcode"* ]]; then
        # Extract version from path: /opt/homebrew/Cellar/schoolcode/3.0.0/bin -> /opt/homebrew/Cellar/schoolcode/3.0.0
        CELLAR_PATH="${SCRIPT_DIR%/bin}"
        PROJECT_ROOT="$CELLAR_PATH"
        SCRIPT_DIR="$CELLAR_PATH/libexec/scripts"
    else
        # Running from symlinked location (e.g., /opt/homebrew/bin/schoolcode)
        # Try to find actual Cellar path
        HOMEBREW_PREFIX="${HOMEBREW_PREFIX:-$(brew --prefix 2>/dev/null || echo "/opt/homebrew")}"
        CELLAR_PATH=$(brew --cellar schoolcode 2>/dev/null || echo "")
        
        if [[ -n "$CELLAR_PATH" ]] && [[ -d "$CELLAR_PATH" ]]; then
            # Find latest version directory
            LATEST_VERSION=$(ls -1 "$CELLAR_PATH" 2>/dev/null | sort -V | tail -1)
            if [[ -n "$LATEST_VERSION" ]] && [[ -d "$CELLAR_PATH/$LATEST_VERSION" ]]; then
                PROJECT_ROOT="$CELLAR_PATH/$LATEST_VERSION"
                SCRIPT_DIR="$PROJECT_ROOT/libexec/scripts"
            fi
        fi
    fi
else
    # Running from git clone or other installation
    PROJECT_ROOT="$SCRIPT_DIR"
    SCRIPT_DIR="$PROJECT_ROOT"
fi

# Status file location - use a writable directory
if [[ "$PROJECT_ROOT" == *"/Cellar/schoolcode"* ]]; then
    # Homebrew installation - use /usr/local/var or /opt/homebrew/var
    HOMEBREW_VAR="${HOMEBREW_PREFIX:-/opt/homebrew}/var"
    STATUS_FILE="$HOMEBREW_VAR/schoolcode/.schoolcode-status"
    mkdir -p "$HOMEBREW_VAR/schoolcode" 2>/dev/null || true
else
    # Git clone or other installation
    STATUS_FILE="$PROJECT_ROOT/.schoolcode-status"
fi

# Source utility libraries
# Logging is required for proper output
LOGGING_SH=""
if [[ -f "$SCRIPT_DIR/utils/logging.sh" ]]; then
    LOGGING_SH="$SCRIPT_DIR/utils/logging.sh"
elif [[ -f "$SCRIPT_DIR/scripts/utils/logging.sh" ]]; then
    LOGGING_SH="$SCRIPT_DIR/scripts/utils/logging.sh"
elif [[ -f "$PROJECT_ROOT/libexec/scripts/utils/logging.sh" ]]; then
    LOGGING_SH="$PROJECT_ROOT/libexec/scripts/utils/logging.sh"
    # Update SCRIPT_DIR to point to actual scripts location
    if [[ -d "$PROJECT_ROOT/libexec/scripts" ]]; then
        SCRIPT_DIR="$PROJECT_ROOT/libexec/scripts"
    fi
fi

if [[ -n "$LOGGING_SH" ]] && [[ -f "$LOGGING_SH" ]]; then
    source "$LOGGING_SH"
else
    # Fallback if logging.sh not found
    echo "Warning: Could not find logging.sh" >&2
fi

# Only source config.sh if not showing help (to avoid permission issues)
if [ "${1:-}" != "--help" ] && [ "${1:-}" != "-h" ]; then
    CONFIG_SH=""
    if [[ -f "$SCRIPT_DIR/utils/config.sh" ]]; then
        CONFIG_SH="$SCRIPT_DIR/utils/config.sh"
    elif [[ -f "$PROJECT_ROOT/libexec/scripts/utils/config.sh" ]]; then
        CONFIG_SH="$PROJECT_ROOT/libexec/scripts/utils/config.sh"
    fi
    
    if [[ -n "$CONFIG_SH" ]] && [[ -f "$CONFIG_SH" ]]; then
        source "$CONFIG_SH" || true  # Don't fail if config sourcing has issues
    fi
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
    local version="$SCRIPT_VERSION"
    
    # Try to read from version.txt in various locations
    local version_file=""
    if [[ -f "$PROJECT_ROOT/version.txt" ]]; then
        version_file="$PROJECT_ROOT/version.txt"
    elif [[ -f "$PROJECT_ROOT/libexec/version.txt" ]]; then
        version_file="$PROJECT_ROOT/libexec/version.txt"
    elif [[ -f "$SCRIPT_DIR/../version.txt" ]]; then
        version_file="$SCRIPT_DIR/../version.txt"
    fi
    
    if [[ -n "$version_file" ]] && [[ -f "$version_file" ]]; then
        local file_version=$(cat "$version_file" 2>/dev/null | head -1 | tr -d '\n\r')
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
    
    # Ensure directory exists
    local status_dir=$(dirname "$STATUS_FILE")
    if [[ ! -d "$status_dir" ]]; then
        mkdir -p "$status_dir" 2>/dev/null || {
            echo "Warning: Failed to create status directory: $status_dir" >&2
            return 1
        }
    fi
    
    # Write status file with error handling
    if echo "$status_data" > "$STATUS_FILE" 2>/dev/null; then
        echo "Status updated: $status"
        return 0
    else
        echo "Warning: Failed to update status file: $STATUS_FILE (this is non-critical)" >&2
        return 0  # Don't fail the installation just because we can't write status
    fi
}

# Check if running as root (skip for help)
check_root() {
    if [ "$EUID" -ne 0 ] && [ "${1:-}" != "--help" ] && [ "${1:-}" != "-h" ]; then
        print_error "This script must be run as root (use sudo)"
        exit 1
    fi
}

# Helper function to find script path
find_script() {
    local script_name="$1"
    # Try multiple possible locations in order of preference
    
    # Homebrew installation: scripts are in libexec/scripts/
    if [[ -f "$PROJECT_ROOT/libexec/scripts/$script_name" ]]; then
        echo "$PROJECT_ROOT/libexec/scripts/$script_name"
        return 0
    fi
    
    # Direct SCRIPT_DIR location
    if [[ -f "$SCRIPT_DIR/$script_name" ]]; then
        echo "$SCRIPT_DIR/$script_name"
        return 0
    fi
    
    # Git clone: scripts are in scripts/
    if [[ -f "$SCRIPT_DIR/scripts/$script_name" ]]; then
        echo "$SCRIPT_DIR/scripts/$script_name"
        return 0
    fi
    
    # Root directory fallback
    if [[ -f "$PROJECT_ROOT/$script_name" ]]; then
        echo "$PROJECT_ROOT/$script_name"
        return 0
    fi
    
    return 1
}

# Run compatibility check
run_compatibility_check() {
    print_info "Running compatibility check..."
    local script_path=$(find_script "utils/old_mac_compatibility.sh" || find_script "old_mac_compatibility.sh")
    if [[ -n "$script_path" ]] && "$script_path"; then
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
    local script_path=$(find_script "utils/system_repair.sh" || find_script "system_repair.sh")
    if [[ -n "$script_path" ]] && "$script_path"; then
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
    local script_path=$(find_script "install.sh")
    if [[ -n "$script_path" ]] && "$script_path"; then
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
    local script_path=$(find_script "setup/setup_guest_shell_init.sh")
    if [[ -n "$script_path" ]] && "$script_path"; then
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
    local script_path=$(find_script "schoolcode-cli.sh")
    if [[ -n "$script_path" ]]; then
        "$script_path" status detailed
    else
        print_error "Could not find schoolcode-cli.sh"
    fi
}

# Update SchoolCode
update_schoolcode() {
    print_info "Updating SchoolCode..."
    local script_path=$(find_script "schoolcode-cli.sh")
    if [[ -n "$script_path" ]]; then
        "$script_path" update
    else
        print_error "Could not find schoolcode-cli.sh"
    fi
}

# Uninstall SchoolCode (interactive)
uninstall_schoolcode() {
    print_warning "This will remove SchoolCode and all installed tools from Guest accounts."
    read -p "Are you sure you want to continue? (y/N): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        print_info "Uninstalling SchoolCode..."
        local script_path=$(find_script "schoolcode-cli.sh")
        if [[ -n "$script_path" ]]; then
            "$script_path" uninstall
        else
            print_error "Could not find schoolcode-cli.sh"
        fi
    else
        print_info "Uninstall cancelled."
    fi
}

# Uninstall SchoolCode (non-interactive)
uninstall_schoolcode_noninteractive() {
    echo "Removing SchoolCode..."
    local script_path=$(find_script "schoolcode-cli.sh")
    if [[ -n "$script_path" ]] && "$script_path" --force uninstall; then
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
    
    local script_path=$(find_script "schoolcode-cli.sh")
    if [[ -z "$script_path" ]]; then
        print_error "Could not find schoolcode-cli.sh"
        return 1
    fi
    
    case $log_choice in
        1) "$script_path" logs ;;
        2) "$script_path" logs error ;;
        3) "$script_path" logs guest ;;
        4) "$script_path" logs install ;;
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