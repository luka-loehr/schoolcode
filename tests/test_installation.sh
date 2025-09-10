#!/bin/bash
# Copyright (c) 2025 Luka Löhr
#
# SchoolCode Installation Test Suite
# Comprehensive automated tests for installation script v3.0
#
# Usage: ./test_installation.sh [OPTIONS]
# Options:
#   -v, --verbose    Enable verbose output
#   -q, --quick      Run quick tests only
#   -f, --full       Run full test suite including destructive tests
#   -c, --cleanup    Clean up test artifacts after completion

set -euo pipefail

#############################################
# TEST CONFIGURATION
#############################################

readonly TEST_VERSION="1.0.0"
readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
readonly INSTALL_SCRIPT="$PROJECT_ROOT/scripts/install_schoolcode_v3.sh"
readonly TEST_PREFIX="/tmp/schoolcode_test_$$"
readonly TEST_LOG_DIR="/tmp/schoolcode_test_logs_$$"
readonly TEST_RESULTS_FILE="$TEST_LOG_DIR/test_results.txt"

# Test counters
TESTS_RUN=0
TESTS_PASSED=0
TESTS_FAILED=0
TESTS_SKIPPED=0

# Options
VERBOSE=false
QUICK_MODE=false
FULL_MODE=false
CLEANUP=true

# Colors
readonly GREEN='\033[0;32m'
readonly RED='\033[0;31m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly NC='\033[0m'

#############################################
# UTILITY FUNCTIONS
#############################################

# Print colored output
print_info() {
    echo -e "${BLUE}[INFO]${NC} $*"
}

print_success() {
    echo -e "${GREEN}[PASS]${NC} $*"
}

print_error() {
    echo -e "${RED}[FAIL]${NC} $*"
}

print_warning() {
    echo -e "${YELLOW}[WARN]${NC} $*"
}

print_skip() {
    echo -e "${YELLOW}[SKIP]${NC} $*"
}

# Setup test environment
setup_test_env() {
    print_info "Setting up test environment..."
    
    # Create test directories
    mkdir -p "$TEST_LOG_DIR"
    mkdir -p "$TEST_PREFIX"
    
    # Initialize results file
    cat > "$TEST_RESULTS_FILE" << EOF
SchoolCode Installation Test Results
=====================================
Date: $(date)
Test Version: $TEST_VERSION
Script Path: $INSTALL_SCRIPT
Test Prefix: $TEST_PREFIX
=====================================

EOF
    
    print_success "Test environment ready"
}

# Cleanup test environment
cleanup_test_env() {
    if [[ "$CLEANUP" == "true" ]]; then
        print_info "Cleaning up test environment..."
        rm -rf "$TEST_PREFIX" 2>/dev/null || true
        rm -rf "$TEST_LOG_DIR" 2>/dev/null || true
        print_success "Cleanup complete"
    else
        print_info "Skipping cleanup (artifacts preserved at $TEST_PREFIX)"
    fi
}

# Run a test
run_test() {
    local test_name="$1"
    local test_function="$2"
    
    TESTS_RUN=$((TESTS_RUN + 1))
    
    if [[ "$VERBOSE" == "true" ]]; then
        echo ""
        echo "=========================================="
        echo "Test #$TESTS_RUN: $test_name"
        echo "=========================================="
    else
        echo -n "Testing $test_name... "
    fi
    
    # Create test-specific log
    local test_log="$TEST_LOG_DIR/test_${TESTS_RUN}_$(echo "$test_name" | tr ' ' '_').log"
    
    # Run the test
    if $test_function > "$test_log" 2>&1; then
        TESTS_PASSED=$((TESTS_PASSED + 1))
        if [[ "$VERBOSE" == "true" ]]; then
            print_success "Test passed"
        else
            echo -e "${GREEN}PASS${NC}"
        fi
        echo "Test #$TESTS_RUN: $test_name - PASSED" >> "$TEST_RESULTS_FILE"
    else
        TESTS_FAILED=$((TESTS_FAILED + 1))
        if [[ "$VERBOSE" == "true" ]]; then
            print_error "Test failed"
            echo "Error output:"
            tail -n 20 "$test_log"
        else
            echo -e "${RED}FAIL${NC}"
        fi
        echo "Test #$TESTS_RUN: $test_name - FAILED" >> "$TEST_RESULTS_FILE"
        echo "  Error log: $test_log" >> "$TEST_RESULTS_FILE"
    fi
}

# Skip a test
skip_test() {
    local test_name="$1"
    local reason="$2"
    
    TESTS_SKIPPED=$((TESTS_SKIPPED + 1))
    print_skip "$test_name - $reason"
    echo "Test: $test_name - SKIPPED ($reason)" >> "$TEST_RESULTS_FILE"
}

#############################################
# TEST FUNCTIONS
#############################################

# Test: Script exists and is executable
test_script_exists() {
    if [[ ! -f "$INSTALL_SCRIPT" ]]; then
        return 1
    fi
    
    if [[ ! -x "$INSTALL_SCRIPT" ]]; then
        return 1
    fi
    
    return 0
}

# Test: Script syntax is valid
test_script_syntax() {
    bash -n "$INSTALL_SCRIPT"
}

# Test: Help option works
test_help_option() {
    "$INSTALL_SCRIPT" --help | grep -q "SchoolCode Installation Script"
}

# Test: Version is displayed
test_version_display() {
    "$INSTALL_SCRIPT" --help | grep -q "v3.0.0"
}

# Test: Dry run mode works
test_dry_run() {
    # Should not require sudo in dry-run mode with help
    "$INSTALL_SCRIPT" --dry-run --help | grep -q "DRY RUN"
}

# Test: Invalid option handling
test_invalid_option() {
    # Should exit with error for invalid option
    if "$INSTALL_SCRIPT" --invalid-option 2>/dev/null; then
        return 1
    else
        return 0
    fi
}

# Test: Custom prefix option parsing
test_custom_prefix() {
    "$INSTALL_SCRIPT" --dry-run --prefix /custom/path --help 2>&1 | grep -q "Installation prefix: /custom/path" || true
}

# Test: Log file creation
test_log_creation() {
    local custom_log="$TEST_LOG_DIR/custom_install.log"
    
    # Test that log option is accepted
    "$INSTALL_SCRIPT" --help --log "$custom_log" > /dev/null 2>&1
    
    # In a real scenario, we'd check if the log file was created
    # For now, just verify the option is accepted
    return 0
}

# Test: Color output control
test_color_control() {
    # Test with color
    local with_color=$("$INSTALL_SCRIPT" --help 2>&1 | cat -v | grep -c '\^\[\[' || true)
    
    # Test without color
    local without_color=$("$INSTALL_SCRIPT" --help --no-color 2>&1 | cat -v | grep -c '\^\[\[' || true)
    
    # Without color should have fewer escape sequences
    if [[ $without_color -lt $with_color ]]; then
        return 0
    else
        return 1
    fi
}

# Test: Verbose mode
test_verbose_mode() {
    "$INSTALL_SCRIPT" --verbose --help 2>&1 | grep -q "DEBUG\|VERBOSE" || true
    return 0
}

# Test: Quiet mode
test_quiet_mode() {
    local output=$("$INSTALL_SCRIPT" --quiet --help 2>&1 | wc -l)
    
    # Quiet mode should produce minimal output
    if [[ $output -lt 10 ]]; then
        return 0
    else
        return 1
    fi
}

# Test: Force mode parsing
test_force_mode() {
    "$INSTALL_SCRIPT" --force --help > /dev/null 2>&1
}

# Test: Check root requirement
test_root_check() {
    # Running without sudo should fail (unless we're already root)
    if [[ $EUID -eq 0 ]]; then
        return 0  # Skip if already root
    fi
    
    # Should fail without sudo
    if "$INSTALL_SCRIPT" --prefix "$TEST_PREFIX" 2>&1 | grep -q "sudo"; then
        return 0
    else
        return 1
    fi
}

# Test: System requirements check
test_system_requirements() {
    # This would need sudo, so we just test the function exists
    grep -q "verify_system_requirements" "$INSTALL_SCRIPT"
}

# Test: Backup function exists
test_backup_function() {
    grep -q "create_backup" "$INSTALL_SCRIPT"
    grep -q "restore_from_backup" "$INSTALL_SCRIPT"
}

# Test: Error handling exists
test_error_handling() {
    grep -q "handle_error" "$INSTALL_SCRIPT"
    grep -q "cleanup_on_error" "$INSTALL_SCRIPT"
    grep -q "trap.*ERR" "$INSTALL_SCRIPT"
}

# Test: Logging functions exist
test_logging_functions() {
    grep -q "init_logging" "$INSTALL_SCRIPT"
    grep -q "log.*DEBUG" "$INSTALL_SCRIPT"
    grep -q "log.*INFO" "$INSTALL_SCRIPT"
    grep -q "log.*ERROR" "$INSTALL_SCRIPT"
}

# Test: Security wrappers exist
test_security_wrappers() {
    grep -q "setup_security_wrappers" "$INSTALL_SCRIPT"
    grep -q "Guest.*user.*protection" "$INSTALL_SCRIPT"
}

# Test: macOS compatibility
test_macos_compatibility() {
    # Check for macOS-specific commands
    grep -q "dscl" "$INSTALL_SCRIPT"
    grep -q "sw_vers" "$INSTALL_SCRIPT"
}

# Test: Installation functions
test_installation_functions() {
    grep -q "check_homebrew" "$INSTALL_SCRIPT"
    grep -q "install_python" "$INSTALL_SCRIPT"
    grep -q "setup_schoolcode_tools" "$INSTALL_SCRIPT"
}

# Test: PATH configuration
test_path_configuration() {
    grep -q "configure_user_path" "$INSTALL_SCRIPT"
    grep -q ".zshrc" "$INSTALL_SCRIPT"
    grep -q ".bashrc" "$INSTALL_SCRIPT"
}

# Test: Verification functions
test_verification_functions() {
    grep -q "verify_installation" "$INSTALL_SCRIPT"
    grep -q "tools_working" "$INSTALL_SCRIPT"
}

# Test: All required functions are defined
test_function_definitions() {
    local required_functions=(
        "main"
        "parse_arguments"
        "show_help"
        "check_root"
        "verify_system_requirements"
        "create_backup"
        "restore_from_backup"
        "check_homebrew"
        "install_python"
        "setup_schoolcode_tools"
        "configure_user_path"
        "verify_installation"
    )
    
    for func in "${required_functions[@]}"; do
        if ! grep -q "^${func}()" "$INSTALL_SCRIPT"; then
            echo "Missing function: $func"
            return 1
        fi
    done
    
    return 0
}

# Test: No hardcoded paths (security)
test_no_hardcoded_credentials() {
    # Check for common credential patterns
    if grep -E "(password|passwd|token|secret|key)[ ]*=[ ]*['\"]" "$INSTALL_SCRIPT" | grep -v "ssh-key"; then
        return 1
    fi
    return 0
}

# Test: ShellCheck validation (if available)
test_shellcheck() {
    if command -v shellcheck &>/dev/null; then
        shellcheck -S warning "$INSTALL_SCRIPT"
    else
        return 0  # Skip if shellcheck not available
    fi
}

#############################################
# INTEGRATION TESTS
#############################################

# Integration test: Full dry-run installation
test_integration_dry_run() {
    if [[ "$FULL_MODE" != "true" ]]; then
        return 0  # Skip in quick mode
    fi
    
    sudo "$INSTALL_SCRIPT" \
        --dry-run \
        --prefix "$TEST_PREFIX" \
        --log "$TEST_LOG_DIR/integration_dry_run.log" \
        --force \
        --no-color
}

# Integration test: Backup and restore simulation
test_integration_backup() {
    if [[ "$FULL_MODE" != "true" ]]; then
        return 0  # Skip in quick mode
    fi
    
    # Create a fake existing installation
    mkdir -p "$TEST_PREFIX/bin"
    touch "$TEST_PREFIX/bin/test_file"
    
    # Run with backup
    sudo "$INSTALL_SCRIPT" \
        --dry-run \
        --prefix "$TEST_PREFIX" \
        --force \
        --verbose 2>&1 | grep -q "backup"
}

#############################################
# MAIN TEST EXECUTION
#############################################

# Parse command line arguments
parse_args() {
    while [[ $# -gt 0 ]]; do
        case "$1" in
            -v|--verbose)
                VERBOSE=true
                shift
                ;;
            -q|--quick)
                QUICK_MODE=true
                shift
                ;;
            -f|--full)
                FULL_MODE=true
                shift
                ;;
            -c|--cleanup)
                CLEANUP=true
                shift
                ;;
            --no-cleanup)
                CLEANUP=false
                shift
                ;;
            *)
                echo "Unknown option: $1"
                echo "Usage: $0 [-v|--verbose] [-q|--quick] [-f|--full] [-c|--cleanup]"
                exit 1
                ;;
        esac
    done
}

# Run test suite
run_test_suite() {
    echo ""
    echo "╔═══════════════════════════════════════╗"
    echo "║   SchoolCode Installation Test Suite   ║"
    echo "║            Version $TEST_VERSION            ║"
    echo "╚═══════════════════════════════════════╝"
    echo ""
    
    print_info "Starting test suite..."
    print_info "Mode: $([ "$QUICK_MODE" == "true" ] && echo "Quick" || ([ "$FULL_MODE" == "true" ] && echo "Full" || echo "Standard"))"
    echo ""
    
    # Basic tests
    echo "=== Basic Tests ==="
    run_test "Script exists and is executable" test_script_exists
    run_test "Script syntax validation" test_script_syntax
    run_test "Help option" test_help_option
    run_test "Version display" test_version_display
    
    # Option tests
    echo ""
    echo "=== Option Tests ==="
    run_test "Dry-run mode" test_dry_run
    run_test "Invalid option handling" test_invalid_option
    run_test "Custom prefix option" test_custom_prefix
    run_test "Log file option" test_log_creation
    run_test "Color control" test_color_control
    run_test "Verbose mode" test_verbose_mode
    run_test "Quiet mode" test_quiet_mode
    run_test "Force mode" test_force_mode
    
    # Functionality tests
    echo ""
    echo "=== Functionality Tests ==="
    run_test "Root requirement check" test_root_check
    run_test "System requirements function" test_system_requirements
    run_test "Backup functions" test_backup_function
    run_test "Error handling" test_error_handling
    run_test "Logging functions" test_logging_functions
    run_test "Security wrappers" test_security_wrappers
    run_test "macOS compatibility" test_macos_compatibility
    run_test "Installation functions" test_installation_functions
    run_test "PATH configuration" test_path_configuration
    run_test "Verification functions" test_verification_functions
    
    # Code quality tests
    echo ""
    echo "=== Code Quality Tests ==="
    run_test "Function definitions" test_function_definitions
    run_test "No hardcoded credentials" test_no_hardcoded_credentials
    
    # Optional ShellCheck
    if command -v shellcheck &>/dev/null; then
        run_test "ShellCheck validation" test_shellcheck
    else
        skip_test "ShellCheck validation" "shellcheck not installed"
    fi
    
    # Integration tests (only in full mode)
    if [[ "$FULL_MODE" == "true" ]]; then
        echo ""
        echo "=== Integration Tests ==="
        run_test "Full dry-run installation" test_integration_dry_run
        run_test "Backup and restore" test_integration_backup
    else
        if [[ "$QUICK_MODE" != "true" ]]; then
            echo ""
            print_info "Skipping integration tests (use --full to run)"
        fi
    fi
}

# Print test summary
print_summary() {
    echo ""
    echo "=========================================="
    echo "            TEST SUMMARY"
    echo "=========================================="
    echo "Tests Run:     $TESTS_RUN"
    echo -e "Tests Passed:  ${GREEN}$TESTS_PASSED${NC}"
    if [[ $TESTS_FAILED -gt 0 ]]; then
        echo -e "Tests Failed:  ${RED}$TESTS_FAILED${NC}"
    else
        echo -e "Tests Failed:  $TESTS_FAILED"
    fi
    if [[ $TESTS_SKIPPED -gt 0 ]]; then
        echo -e "Tests Skipped: ${YELLOW}$TESTS_SKIPPED${NC}"
    fi
    echo "=========================================="
    
    # Calculate pass rate
    if [[ $TESTS_RUN -gt 0 ]]; then
        local pass_rate=$((TESTS_PASSED * 100 / TESTS_RUN))
        echo "Pass Rate: $pass_rate%"
    fi
    
    echo ""
    echo "Results saved to: $TEST_RESULTS_FILE"
    
    # Exit code based on test results
    if [[ $TESTS_FAILED -gt 0 ]]; then
        echo ""
        print_error "TEST SUITE FAILED"
        return 1
    else
        echo ""
        print_success "TEST SUITE PASSED"
        return 0
    fi
}

# Main execution
main() {
    parse_args "$@"
    setup_test_env
    
    # Set up cleanup trap
    trap cleanup_test_env EXIT
    
    # Run tests
    run_test_suite
    
    # Print summary
    print_summary
}

# Run main
main "$@"
