#!/bin/bash
# Copyright (c) 2025 Luka Löhr
#
# Old Mac Compatibility Checker - Validates system requirements for SchoolCode
# Handles macOS versions back to 10.14 (Mojave) and identifies potential issues

set -euo pipefail

# Source logging utility - handle both direct execution and sourcing
if [[ -n "${BASH_SOURCE[0]:-}" ]]; then
    COMPAT_SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
else
    COMPAT_SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
fi

# Only source logging if not already available
if ! type log_silent &>/dev/null; then
    if [ -f "${COMPAT_SCRIPT_DIR}/logging.sh" ]; then
        source "${COMPAT_SCRIPT_DIR}/logging.sh"
    else
        # Basic logging functions if logging.sh is not found
        log_info() { :; }  # Silent by default
        log_error() { echo "[ERROR] $*" >&2; }
        log_warn() { echo "[WARN] $*" >&2; }
        log_silent() { :; }
        start_spinner() { :; }
        stop_spinner() { :; }
    fi
fi

# Compatibility thresholds
MIN_MACOS_MAJOR=10
MIN_MACOS_MINOR=14  # macOS 10.14 Mojave
RECOMMENDED_MACOS_MINOR=15  # macOS 10.15 Catalina
MIN_DISK_SPACE_MB=5000  # 5GB minimum
MIN_RAM_GB=4  # 4GB minimum
MIN_RUBY_VERSION="2.6.0"
MIN_GIT_VERSION="2.0.0"

# Global status variables
COMPAT_STATUS="unknown"
COMPAT_ERRORS=0
COMPAT_WARNINGS=0
COMPAT_ISSUES=()  # Collect issues to show at the end

# Quiet mode - only show spinner and final result
QUIET_MODE="${SCHOOLCODE_QUIET:-true}"

# Function to compare version strings
version_compare() {
    local version1="$1"
    local version2="$2"
    
    # Convert to comparable format (e.g., 2.6.0 -> 002006000)
    local v1_formatted=$(echo "$version1" | awk -F. '{printf "%03d%03d%03d", $1, $2, $3}')
    local v2_formatted=$(echo "$version2" | awk -F. '{printf "%03d%03d%03d", $1, $2, $3}')
    
    if [[ "10#$v1_formatted" -lt "10#$v2_formatted" ]]; then
        echo "-1"
    elif [[ "10#$v1_formatted" -gt "10#$v2_formatted" ]]; then
        echo "1"
    else
        echo "0"
    fi
}

# Check macOS version
check_macos_version() {
    log_silent "INFO" "Checking macOS version compatibility..."
    
    local macos_version=$(sw_vers -productVersion 2>/dev/null || echo "0.0")
    local macos_build=$(sw_vers -buildVersion 2>/dev/null || echo "unknown")
    local major_version=$(echo "$macos_version" | cut -d. -f1)
    local minor_version=$(echo "$macos_version" | cut -d. -f2)
    
    log_silent "INFO" "Detected macOS $macos_version (Build $macos_build)"
    
    # Check if version is too old
    if [[ $major_version -lt $MIN_MACOS_MAJOR ]] || 
       [[ $major_version -eq $MIN_MACOS_MAJOR && $minor_version -lt $MIN_MACOS_MINOR ]]; then
        COMPAT_ISSUES+=("macOS $macos_version is not supported (minimum: 10.14 Mojave)")
        ((COMPAT_ERRORS++))
        return 1
    fi
    
    # Check if version is outdated but supported
    if [[ $major_version -eq $MIN_MACOS_MAJOR && $minor_version -lt $RECOMMENDED_MACOS_MINOR ]]; then
        COMPAT_ISSUES+=("macOS $macos_version is outdated (recommended: 10.15+)")
        ((COMPAT_WARNINGS++))
        
        # Set environment variables for older systems
        export HOMEBREW_NO_AUTO_UPDATE=1
        export HOMEBREW_NO_INSTALL_CLEANUP=1
    fi
    
    # Special handling for very old systems
    if [[ $major_version -eq 10 && $minor_version -eq 14 ]]; then
        COMPAT_ISSUES+=("macOS Mojave requires compatibility mode")
        export HOMEBREW_FORCE_VENDOR_RUBY=1
        export HOMEBREW_NO_ANALYTICS=1
        ((COMPAT_WARNINGS++))
    fi
    
    return 0
}

# Check disk space
check_disk_space() {
    log_silent "INFO" "Checking available disk space..."
    
    local available_mb=$(df / | awk 'NR==2 {print int($4/1024)}')
    local used_percent=$(df / | awk 'NR==2 {print int($5)}' | sed 's/%//')
    local total_gb=$(df -H / | awk 'NR==2 {print $2}')
    
    log_silent "INFO" "Disk usage: ${used_percent}% of $total_gb, ${available_mb}MB free"
    
    if [[ $available_mb -lt $MIN_DISK_SPACE_MB ]]; then
        COMPAT_ISSUES+=("Insufficient disk space: ${available_mb}MB (need ${MIN_DISK_SPACE_MB}MB)")
        ((COMPAT_ERRORS++))
        return 1
    elif [[ $available_mb -lt $((MIN_DISK_SPACE_MB * 2)) ]]; then
        COMPAT_ISSUES+=("Low disk space: ${available_mb}MB available")
        ((COMPAT_WARNINGS++))
    fi
    
    return 0
}

# Check system RAM
check_system_ram() {
    log_silent "INFO" "Checking system memory..."
    
    local total_ram_bytes=$(sysctl -n hw.memsize 2>/dev/null || echo "0")
    local total_ram_gb=$((total_ram_bytes / 1024 / 1024 / 1024))
    
    log_silent "INFO" "Total RAM: ${total_ram_gb}GB"
    
    if [[ $total_ram_gb -lt $MIN_RAM_GB ]]; then
        COMPAT_ISSUES+=("Low memory: ${total_ram_gb}GB (recommended: ${MIN_RAM_GB}GB)")
        ((COMPAT_WARNINGS++))
    fi
    
    return 0
}

# Check Ruby version
check_ruby_version() {
    log_silent "INFO" "Checking Ruby version..."
    
    if ! command -v ruby &>/dev/null; then
        COMPAT_ISSUES+=("Ruby not found (required for Homebrew)")
        ((COMPAT_ERRORS++))
        return 1
    fi
    
    local ruby_version=$(ruby -e 'puts RUBY_VERSION' 2>/dev/null || echo "0.0.0")
    log_silent "INFO" "Ruby version: $ruby_version"
    
    if [[ $(version_compare "$ruby_version" "$MIN_RUBY_VERSION") -eq -1 ]]; then
        COMPAT_ISSUES+=("Ruby $ruby_version is outdated")
        export HOMEBREW_FORCE_VENDOR_RUBY=1
        ((COMPAT_WARNINGS++))
    fi
    
    return 0
}

# Check Git version
check_git_version() {
    log_silent "INFO" "Checking Git version..."
    
    if ! command -v git &>/dev/null; then
        COMPAT_ISSUES+=("Git not found (will be installed)")
        ((COMPAT_WARNINGS++))
        return 0
    fi
    
    local git_version=$(git --version 2>/dev/null | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | head -1 || echo "0.0.0")
    log_silent "INFO" "Git version: $git_version"
    
    if [[ $(version_compare "$git_version" "$MIN_GIT_VERSION") -eq -1 ]]; then
        COMPAT_ISSUES+=("Git $git_version is outdated")
        ((COMPAT_WARNINGS++))
    fi
    
    return 0
}

# Check internet connectivity
check_internet_connection() {
    log_silent "INFO" "Checking internet connection..."
    
    local test_hosts=("github.com" "cdn.jsdelivr.net" "formulae.brew.sh")
    local connected=false
    
    for host in "${test_hosts[@]}"; do
        if ping -c 1 -t 5 "$host" &>/dev/null; then
            connected=true
            break
        fi
    done
    
    if [[ "$connected" == "false" ]]; then
        COMPAT_ISSUES+=("No internet connection detected")
        ((COMPAT_ERRORS++))
        return 1
    fi
    
    # Check for proxy settings
    if [[ -n "${HTTP_PROXY:-}" ]] || [[ -n "${HTTPS_PROXY:-}" ]]; then
        COMPAT_ISSUES+=("Proxy detected - ensure access to github.com, brew.sh")
        ((COMPAT_WARNINGS++))
    fi
    
    return 0
}

# Check SIP (System Integrity Protection) status
check_sip_status() {
    log_silent "INFO" "Checking System Integrity Protection status..."
    
    if command -v csrutil &>/dev/null; then
        local sip_status=$(csrutil status 2>/dev/null | grep -o 'enabled\|disabled' || echo "unknown")
        log_silent "INFO" "SIP status: $sip_status"
        
        if [[ "$sip_status" == "disabled" ]]; then
            COMPAT_ISSUES+=("System Integrity Protection is disabled")
            ((COMPAT_WARNINGS++))
        fi
    fi
    
    return 0
}

# Check for conflicting software
check_conflicting_software() {
    log_silent "INFO" "Checking for conflicting software..."
    
    # Check for MacPorts
    if [[ -d "/opt/local" ]] && command -v port &>/dev/null; then
        COMPAT_ISSUES+=("MacPorts detected (may conflict with Homebrew)")
        ((COMPAT_WARNINGS++))
    fi
    
    # Check for Fink
    if [[ -d "/sw" ]]; then
        COMPAT_ISSUES+=("Fink detected (may conflict with Homebrew)")
        ((COMPAT_WARNINGS++))
    fi
    
    # Check for other Python installations - this is usually fine
    local python_locations=("/Library/Frameworks/Python.framework" "/Applications/Python*")
    for location in "${python_locations[@]}"; do
        if ls $location &>/dev/null 2>&1; then
            # Don't warn about this - it's expected with official Python
            log_silent "INFO" "Python installation found at $location"
        fi
    done
    
    return 0
}

# Generate compatibility report (silent)
generate_compatibility_report() {
    local report_file="/tmp/schoolcode_compatibility_report.txt"
    
    cat > "$report_file" << EOF
SchoolCode Compatibility Report
Generated: $(date)
========================================

System Information:
  macOS Version: $(sw_vers -productVersion 2>/dev/null || echo "unknown")
  Build: $(sw_vers -buildVersion 2>/dev/null || echo "unknown")
  Hardware: $(sysctl -n hw.model 2>/dev/null || echo "unknown")
  Architecture: $(uname -m)
  Hostname: $(hostname)

Compatibility Status:
  Errors: $COMPAT_ERRORS
  Warnings: $COMPAT_WARNINGS
  Overall Status: $COMPAT_STATUS

Resource Availability:
  Disk Space: $(df -H / | awk 'NR==2 {print $4}') free of $(df -H / | awk 'NR==2 {print $2}')
  Memory: $(sysctl -n hw.memsize | awk '{print int($1/1024/1024/1024)}')GB total
  CPU Cores: $(sysctl -n hw.ncpu)

Software Versions:
  Ruby: $(ruby -v 2>/dev/null | head -1 || echo "not found")
  Git: $(git --version 2>/dev/null || echo "not found")
  Python: $(python3 --version 2>/dev/null || echo "not found")
  Bash: $BASH_VERSION

Environment Variables Set:
$(env | grep HOMEBREW_ | sort || echo "  None")

Recommendations:
EOF
    
    if [[ $COMPAT_ERRORS -gt 0 ]]; then
        echo "  - Fix critical errors before proceeding with installation" >> "$report_file"
    fi
    
    if [[ $COMPAT_WARNINGS -gt 0 ]]; then
        echo "  - Address warnings for optimal performance" >> "$report_file"
    fi
    
    if [[ $COMPAT_STATUS == "compatible" ]]; then
        echo "  - System is ready for SchoolCode installation" >> "$report_file"
    fi
    
    echo "" >> "$report_file"
    echo "Full report saved to: $report_file" >> "$report_file"
    
    log_silent "INFO" "Compatibility report generated: $report_file"
}

# Main compatibility check
run_compatibility_check() {
    # Run all checks silently
    check_macos_version || true
    check_disk_space || true
    check_system_ram || true
    check_ruby_version || true
    check_git_version || true
    check_internet_connection || true
    check_sip_status || true
    check_conflicting_software || true
    
    # Determine overall status
    if [[ $COMPAT_ERRORS -gt 0 ]]; then
        COMPAT_STATUS="incompatible"
    elif [[ $COMPAT_WARNINGS -gt 0 ]]; then
        COMPAT_STATUS="compatible_with_warnings"
    else
        COMPAT_STATUS="compatible"
    fi
    
    # Generate report (silently)
    generate_compatibility_report
    
    # Return appropriate exit code
    if [[ $COMPAT_ERRORS -gt 0 ]]; then
        return 1
    else
        return 0
    fi
}

# Get issues array for external scripts
get_compatibility_issues() {
    printf '%s\n' "${COMPAT_ISSUES[@]}"
}

# Get status for external scripts
get_compatibility_status() {
    echo "$COMPAT_STATUS"
}

get_compatibility_errors() {
    echo "$COMPAT_ERRORS"
}

get_compatibility_warnings() {
    echo "$COMPAT_WARNINGS"
}

# Export functions for use in other scripts
export -f version_compare check_macos_version check_disk_space

# Run if executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    run_compatibility_check
    exit $?
fi