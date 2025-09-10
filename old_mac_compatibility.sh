#!/bin/bash
# Copyright (c) 2025 Luka Löhr
#
# Old Mac Compatibility Checker - Validates system requirements for SchoolCode
# Handles macOS versions back to 10.14 (Mojave) and identifies potential issues

set -euo pipefail

# Source logging utility
SCRIPT_DIR="$(dirname "$0")"
source "${SCRIPT_DIR}/logging.sh"

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

# Function to compare version strings
version_compare() {
    local version1="$1"
    local version2="$2"
    
    # Convert to comparable format (e.g., 2.6.0 -> 002006000)
    local v1_formatted=$(echo "$version1" | awk -F. '{printf "%03d%03d%03d", $1, $2, $3}')
    local v2_formatted=$(echo "$version2" | awk -F. '{printf "%03d%03d%03d", $1, $2, $3}')
    
    if [[ "$v1_formatted" -lt "$v2_formatted" ]]; then
        echo "-1"
    elif [[ "$v1_formatted" -gt "$v2_formatted" ]]; then
        echo "1"
    else
        echo "0"
    fi
}

# Check macOS version
check_macos_version() {
    log_info "Checking macOS version compatibility..."
    
    local macos_version=$(sw_vers -productVersion 2>/dev/null || echo "0.0")
    local macos_build=$(sw_vers -buildVersion 2>/dev/null || echo "unknown")
    local major_version=$(echo "$macos_version" | cut -d. -f1)
    local minor_version=$(echo "$macos_version" | cut -d. -f2)
    
    log_info "Detected macOS $macos_version (Build $macos_build)"
    
    # Check if version is too old
    if [[ $major_version -lt $MIN_MACOS_MAJOR ]] || 
       [[ $major_version -eq $MIN_MACOS_MAJOR && $minor_version -lt $MIN_MACOS_MINOR ]]; then
        log_error "macOS $macos_version is not supported. Minimum required: 10.14 (Mojave)"
        log_error "Homebrew and many tools no longer support this version."
        ((COMPAT_ERRORS++))
        return 1
    fi
    
    # Check if version is outdated but supported
    if [[ $major_version -eq $MIN_MACOS_MAJOR && $minor_version -lt $RECOMMENDED_MACOS_MINOR ]]; then
        log_warn "macOS $macos_version is outdated. Recommended: 10.15 (Catalina) or newer"
        log_warn "Some features may not work properly. Consider updating macOS."
        ((COMPAT_WARNINGS++))
        
        # Set environment variables for older systems
        export HOMEBREW_NO_AUTO_UPDATE=1
        export HOMEBREW_NO_INSTALL_CLEANUP=1
        log_debug "Disabled Homebrew auto-update for old macOS"
    fi
    
    # Special handling for very old systems
    if [[ $major_version -eq 10 && $minor_version -eq 14 ]]; then
        log_warn "macOS Mojave detected - additional compatibility measures will be applied"
        export HOMEBREW_FORCE_VENDOR_RUBY=1
        export HOMEBREW_NO_ANALYTICS=1
        ((COMPAT_WARNINGS++))
    fi
    
    return 0
}

# Check disk space
check_disk_space() {
    log_info "Checking available disk space..."
    
    local available_mb=$(df / | awk 'NR==2 {print int($4/1024)}')
    local used_percent=$(df / | awk 'NR==2 {print int($5)}' | sed 's/%//')
    local total_gb=$(df -H / | awk 'NR==2 {print $2}')
    
    log_info "Disk usage: ${used_percent}% of $total_gb, ${available_mb}MB free"
    
    if [[ $available_mb -lt $MIN_DISK_SPACE_MB ]]; then
        log_error "Insufficient disk space: ${available_mb}MB available, ${MIN_DISK_SPACE_MB}MB required"
        log_error "Please free up disk space before proceeding."
        ((COMPAT_ERRORS++))
        return 1
    elif [[ $available_mb -lt $((MIN_DISK_SPACE_MB * 2)) ]]; then
        log_warn "Low disk space: ${available_mb}MB available. Recommended: $((MIN_DISK_SPACE_MB * 2))MB"
        ((COMPAT_WARNINGS++))
    fi
    
    return 0
}

# Check system RAM
check_system_ram() {
    log_info "Checking system memory..."
    
    local total_ram_bytes=$(sysctl -n hw.memsize 2>/dev/null || echo "0")
    local total_ram_gb=$((total_ram_bytes / 1024 / 1024 / 1024))
    
    log_info "Total RAM: ${total_ram_gb}GB"
    
    if [[ $total_ram_gb -lt $MIN_RAM_GB ]]; then
        log_warn "Low system memory: ${total_ram_gb}GB. Recommended: ${MIN_RAM_GB}GB or more"
        log_warn "Installation may be slow on systems with limited RAM"
        ((COMPAT_WARNINGS++))
    fi
    
    return 0
}

# Check Ruby version
check_ruby_version() {
    log_info "Checking Ruby version..."
    
    if ! command -v ruby &>/dev/null; then
        log_error "Ruby not found. This should not happen on macOS."
        ((COMPAT_ERRORS++))
        return 1
    fi
    
    local ruby_version=$(ruby -e 'puts RUBY_VERSION' 2>/dev/null || echo "0.0.0")
    log_info "Ruby version: $ruby_version"
    
    if [[ $(version_compare "$ruby_version" "$MIN_RUBY_VERSION") -eq -1 ]]; then
        log_warn "Ruby $ruby_version is old. Homebrew requires Ruby $MIN_RUBY_VERSION or newer"
        log_warn "Will use Homebrew's portable Ruby if available"
        export HOMEBREW_FORCE_VENDOR_RUBY=1
        ((COMPAT_WARNINGS++))
    fi
    
    return 0
}

# Check Git version
check_git_version() {
    log_info "Checking Git version..."
    
    if ! command -v git &>/dev/null; then
        log_warn "Git not found. It will be installed with Xcode Command Line Tools"
        ((COMPAT_WARNINGS++))
        return 0
    fi
    
    local git_version=$(git --version 2>/dev/null | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | head -1 || echo "0.0.0")
    log_info "Git version: $git_version"
    
    if [[ $(version_compare "$git_version" "$MIN_GIT_VERSION") -eq -1 ]]; then
        log_warn "Git $git_version is very old. Minimum recommended: $MIN_GIT_VERSION"
        log_warn "Some Git operations may fail. Consider updating Xcode CLT."
        ((COMPAT_WARNINGS++))
    fi
    
    return 0
}

# Check internet connectivity
check_internet_connection() {
    log_info "Checking internet connection..."
    
    local test_hosts=("github.com" "cdn.jsdelivr.net" "formulae.brew.sh")
    local connected=false
    
    for host in "${test_hosts[@]}"; do
        if ping -c 1 -t 5 "$host" &>/dev/null; then
            connected=true
            log_debug "Successfully reached $host"
            break
        else
            log_debug "Failed to reach $host"
        fi
    done
    
    if [[ "$connected" == "false" ]]; then
        log_error "No internet connection detected"
        log_error "SchoolCode requires internet access to download tools"
        ((COMPAT_ERRORS++))
        return 1
    fi
    
    # Check for proxy settings
    if [[ -n "${HTTP_PROXY:-}" ]] || [[ -n "${HTTPS_PROXY:-}" ]]; then
        log_warn "Proxy detected. Ensure proxy allows access to:"
        log_warn "  - github.com"
        log_warn "  - brew.sh"
        log_warn "  - apple.com (for Xcode CLT)"
        ((COMPAT_WARNINGS++))
    fi
    
    return 0
}

# Check SIP (System Integrity Protection) status
check_sip_status() {
    log_info "Checking System Integrity Protection status..."
    
    if command -v csrutil &>/dev/null; then
        local sip_status=$(csrutil status 2>/dev/null | grep -o 'enabled\|disabled' || echo "unknown")
        log_info "SIP status: $sip_status"
        
        if [[ "$sip_status" == "disabled" ]]; then
            log_warn "System Integrity Protection is disabled"
            log_warn "This may cause unexpected behavior with system tools"
            ((COMPAT_WARNINGS++))
        fi
    fi
    
    return 0
}

# Check for conflicting software
check_conflicting_software() {
    log_info "Checking for conflicting software..."
    
    # Check for MacPorts
    if [[ -d "/opt/local" ]] && command -v port &>/dev/null; then
        log_warn "MacPorts detected at /opt/local"
        log_warn "This may conflict with Homebrew. Consider removing MacPorts."
        ((COMPAT_WARNINGS++))
    fi
    
    # Check for Fink
    if [[ -d "/sw" ]]; then
        log_warn "Fink detected at /sw"
        log_warn "This may conflict with Homebrew. Consider removing Fink."
        ((COMPAT_WARNINGS++))
    fi
    
    # Check for other Python installations
    local python_locations=("/Library/Frameworks/Python.framework" "/Applications/Python*")
    for location in "${python_locations[@]}"; do
        if ls $location &>/dev/null; then
            log_warn "Additional Python installation found at $location"
            log_warn "This may cause PATH conflicts"
            ((COMPAT_WARNINGS++))
        fi
    done
    
    return 0
}

# Generate compatibility report
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
    
    log_info "Compatibility report generated: $report_file"
}

# Main compatibility check
run_compatibility_check() {
    log_info "Starting comprehensive compatibility check for old Mac support..."
    
    # Run all checks
    check_macos_version
    check_disk_space
    check_system_ram
    check_ruby_version
    check_git_version
    check_internet_connection
    check_sip_status
    check_conflicting_software
    
    # Determine overall status
    if [[ $COMPAT_ERRORS -gt 0 ]]; then
        COMPAT_STATUS="incompatible"
        log_error "System is not compatible. Found $COMPAT_ERRORS critical errors."
    elif [[ $COMPAT_WARNINGS -gt 0 ]]; then
        COMPAT_STATUS="compatible_with_warnings"
        log_warn "System is compatible but has $COMPAT_WARNINGS warnings."
    else
        COMPAT_STATUS="compatible"
        log_info "System is fully compatible!"
    fi
    
    # Generate report
    generate_compatibility_report
    
    # Return appropriate exit code
    if [[ $COMPAT_ERRORS -gt 0 ]]; then
        return 1
    else
        return 0
    fi
}

# Export functions for use in other scripts
export -f version_compare check_macos_version check_disk_space

# Run if executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    run_compatibility_check
    exit $?
fi