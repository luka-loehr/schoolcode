#!/bin/bash
# Copyright (c) 2025 Luka Löhr

# SchoolCode Hub - Central Management Interface
# Unified script for all SchoolCode operations

set -euo pipefail

# Script metadata
SCRIPT_VERSION="3.0.0"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

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
    if "$SCRIPT_DIR/old_mac_compatibility.sh"; then
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
    if "$SCRIPT_DIR/system_repair.sh"; then
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
    if "$SCRIPT_DIR/scripts/guest_setup_auto.sh"; then
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

# Uninstall SchoolCode
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

# Interactive mode menu
interactive_mode() {
    while true; do
        print_header
        echo "Select an operation:"
        echo ""
        echo "📋 System Management:"
        echo "  1) Check Compatibility"
        echo "  2) System Repair"
        echo "  3) Show Status"
        echo ""
        echo "🔧 Installation & Setup:"
        echo "  4) Install Tools Only"
        echo "  5) Setup Guest Account Only"
        echo "  6) Install Everything (Full Setup)"
        echo ""
        echo "🔄 Maintenance:"
        echo "  7) Update SchoolCode"
        echo "  8) Uninstall SchoolCode"
        echo ""
        echo "📊 Monitoring & Debugging:"
        echo "  9) View Logs"
        echo "  10) Run Tests"
        echo ""
        echo "  0) Exit"
        echo ""
        read -p "Enter your choice (0-10): " choice
        
        case $choice in
            1)
                echo ""
                run_compatibility_check
                echo ""
                read -p "Press Enter to continue..."
                ;;
            2)
                echo ""
                run_system_repair
                echo ""
                read -p "Press Enter to continue..."
                ;;
            3)
                echo ""
                show_status
                echo ""
                read -p "Press Enter to continue..."
                ;;
            4)
                echo ""
                install_tools
                echo ""
                read -p "Press Enter to continue..."
                ;;
            5)
                echo ""
                setup_guest_account
                echo ""
                read -p "Press Enter to continue..."
                ;;
            6)
                echo ""
                print_info "Starting full installation..."
                if run_compatibility_check && run_system_repair && install_tools && setup_guest_account; then
                    print_success "Full installation completed successfully!"
                else
                    print_error "Installation failed at some step. Check logs for details."
                fi
                echo ""
                read -p "Press Enter to continue..."
                ;;
            7)
                echo ""
                update_schoolcode
                echo ""
                read -p "Press Enter to continue..."
                ;;
            8)
                echo ""
                uninstall_schoolcode
                echo ""
                read -p "Press Enter to continue..."
                ;;
            9)
                echo ""
                show_logs
                echo ""
                read -p "Press Enter to continue..."
                ;;
            10)
                echo ""
                run_tests
                echo ""
                read -p "Press Enter to continue..."
                ;;
            0)
                print_info "Goodbye!"
                exit 0
                ;;
            *)
                print_error "Invalid choice. Please enter a number between 0-10."
                echo ""
                read -p "Press Enter to continue..."
                ;;
        esac
    done
}

# Automatic mode (no flags) - runs full installation
automatic_mode() {
    print_header
    print_info "Running automatic installation mode..."
    echo ""
    
    # Run full installation sequence
    if run_compatibility_check && run_system_repair && install_tools && setup_guest_account; then
        print_success "SchoolCode installation completed successfully!"
        echo ""
        print_info "You can now:"
        echo "  • Switch to Guest account to test the installation"
        echo "  • Run './schoolcode.sh' for interactive management"
        echo "  • Run './schoolcode.sh --status' to check system status"
    else
        print_error "Installation failed at some step. Check logs for details."
        echo ""
        print_info "You can run './schoolcode.sh' for interactive troubleshooting."
        exit 1
    fi
}

# Help function
show_help() {
    print_header
    echo "SchoolCode Hub - Central Management Interface"
    echo ""
    echo "Usage:"
    echo "  sudo ./schoolcode.sh                    # Automatic installation (full setup)"
    echo "  sudo ./schoolcode.sh --interactive      # Interactive mode (menu-driven)"
    echo "  sudo ./schoolcode.sh --status           # Show system status"
    echo "  sudo ./schoolcode.sh --help             # Show this help"
    echo ""
    echo "Automatic Mode (no flags):"
    echo "  Runs compatibility check, system repair, tool installation, and guest setup"
    echo ""
    echo "Interactive Mode:"
    echo "  Provides menu-driven access to all SchoolCode operations"
    echo ""
    echo "Examples:"
    echo "  sudo ./schoolcode.sh                    # Full automatic setup"
    echo "  sudo ./schoolcode.sh --interactive      # Interactive management"
    echo "  sudo ./schoolcode.sh --status           # Check system health"
}

# Main script logic
main() {
    # Check if running as root (skip for help)
    check_root "${1:-}"
    
    # Parse command line arguments
    case "${1:-}" in
        --interactive|-i)
            interactive_mode
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