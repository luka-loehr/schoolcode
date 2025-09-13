#!/bin/bash
# Copyright (c) 2025 Luka Löhr

# SchoolCode Simple Test Suite
# Tests the essential functionality of SchoolCode

set -uo pipefail

# Test configuration
readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

# Colors
readonly GREEN='\033[0;32m'
readonly RED='\033[0;31m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly NC='\033[0m'

# Test counters
TESTS_RUN=0
TESTS_PASSED=0
TESTS_FAILED=0

# Utility functions
print_header() {
    echo -e "${BLUE}╔═══════════════════════════════════════╗"
    echo -e "║        SchoolCode Test Suite         ║"
    echo -e "╚═══════════════════════════════════════╝${NC}"
    echo ""
}

print_test() {
    echo -e "${BLUE}Testing:${NC} $1"
}

print_pass() {
    echo -e "  ${GREEN}✅ PASS${NC}"
    ((TESTS_PASSED++))
}

print_fail() {
    echo -e "  ${RED}❌ FAIL${NC}"
    ((TESTS_FAILED++))
}

print_summary() {
    echo ""
    echo -e "${BLUE}════════════════════════════════════════${NC}"
    echo -e "${BLUE}              TEST SUMMARY${NC}"
    echo -e "${BLUE}════════════════════════════════════════${NC}"
    echo -e "Tests Run:     $TESTS_RUN"
    echo -e "Tests Passed:  ${GREEN}$TESTS_PASSED${NC}"
    echo -e "Tests Failed:  ${RED}$TESTS_FAILED${NC}"
    
    if [[ $TESTS_FAILED -eq 0 ]]; then
        echo -e "${GREEN}🎉 All tests passed!${NC}"
        return 0
    else
        echo -e "${RED}❌ Some tests failed${NC}"
        return 1
    fi
}

# Test functions
test_script_exists() {
    print_test "Script files exist"
    ((TESTS_RUN++))
    
    local scripts=(
        "$PROJECT_ROOT/schoolcode.sh"
        "$PROJECT_ROOT/scripts/install.sh"
        "$PROJECT_ROOT/scripts/schoolcode-cli.sh"
        "$PROJECT_ROOT/system_repair.sh"
        "$PROJECT_ROOT/old_mac_compatibility.sh"
    )
    
    local missing=0
    for script in "${scripts[@]}"; do
        if [[ ! -f "$script" ]]; then
            echo "    Missing: $script"
            ((missing++))
        fi
    done
    
    if [[ $missing -eq 0 ]]; then
        print_pass
    else
        print_fail
    fi
}

test_script_executable() {
    print_test "Scripts are executable"
    ((TESTS_RUN++))
    
    local scripts=(
        "$PROJECT_ROOT/schoolcode.sh"
        "$PROJECT_ROOT/scripts/install.sh"
        "$PROJECT_ROOT/scripts/schoolcode-cli.sh"
        "$PROJECT_ROOT/system_repair.sh"
        "$PROJECT_ROOT/old_mac_compatibility.sh"
    )
    
    local not_executable=0
    for script in "${scripts[@]}"; do
        if [[ -f "$script" && ! -x "$script" ]]; then
            echo "    Not executable: $script"
            ((not_executable++))
        fi
    done
    
    if [[ $not_executable -eq 0 ]]; then
        print_pass
    else
        print_fail
    fi
}

test_script_syntax() {
    print_test "Script syntax validation"
    ((TESTS_RUN++))
    
    local scripts=(
        "$PROJECT_ROOT/schoolcode.sh"
        "$PROJECT_ROOT/scripts/install.sh"
        "$PROJECT_ROOT/scripts/schoolcode-cli.sh"
        "$PROJECT_ROOT/system_repair.sh"
        "$PROJECT_ROOT/old_mac_compatibility.sh"
    )
    
    local syntax_errors=0
    for script in "${scripts[@]}"; do
        if [[ -f "$script" ]]; then
            if ! bash -n "$script" 2>/dev/null; then
                echo "    Syntax error in: $script"
                ((syntax_errors++))
            fi
        fi
    done
    
    if [[ $syntax_errors -eq 0 ]]; then
        print_pass
    else
        print_fail
    fi
}

test_help_function() {
    print_test "Help function works"
    ((TESTS_RUN++))
    
    if [[ -f "$PROJECT_ROOT/schoolcode.sh" ]]; then
        if ./schoolcode.sh --help >/dev/null 2>&1; then
            print_pass
        else
            print_fail
        fi
    else
        print_fail
    fi
}

test_compatibility_check() {
    print_test "Compatibility check works"
    ((TESTS_RUN++))
    
    if [[ -f "$PROJECT_ROOT/old_mac_compatibility.sh" ]]; then
        if ./old_mac_compatibility.sh >/dev/null 2>&1; then
            print_pass
        else
            print_fail
        fi
    else
        print_fail
    fi
}

test_cli_status() {
    print_test "CLI status command works"
    ((TESTS_RUN++))
    
    if [[ -f "$PROJECT_ROOT/scripts/schoolcode-cli.sh" ]]; then
        # Test without sudo first (should show permission error, not syntax error)
        local output
        output=$(./scripts/schoolcode-cli.sh status 2>&1 || true)
        if echo "$output" | grep -q "root\|permission\|sudo"; then
            print_pass
        else
            print_fail
        fi
    else
        print_fail
    fi
}

test_tools_available() {
    print_test "Development tools are available"
    ((TESTS_RUN++))
    
    local tools=("python3" "git" "brew")
    local available=0
    
    for tool in "${tools[@]}"; do
        if command -v "$tool" >/dev/null 2>&1; then
            ((available++))
        fi
    done
    
    if [[ $available -ge 2 ]]; then  # At least 2 out of 3 tools should be available
        print_pass
    else
        print_fail
    fi
}

test_python_functionality() {
    print_test "Python functionality"
    ((TESTS_RUN++))
    
    if command -v python3 >/dev/null 2>&1; then
        if python3 -c "import sys; print('Python', sys.version_info.major, 'working')" >/dev/null 2>&1; then
            print_pass
        else
            print_fail
        fi
    else
        print_fail
    fi
}

test_git_functionality() {
    print_test "Git functionality"
    ((TESTS_RUN++))
    
    if command -v git >/dev/null 2>&1; then
        if git --version >/dev/null 2>&1; then
            print_pass
        else
            print_fail
        fi
    else
        print_fail
    fi
}

# Main test runner
main() {
    print_header
    
    # Run tests
    test_script_exists
    test_script_executable
    test_script_syntax
    test_help_function
    test_compatibility_check
    test_cli_status
    test_tools_available
    test_python_functionality
    test_git_functionality
    
    # Show summary
    print_summary
}

# Run tests
main "$@"