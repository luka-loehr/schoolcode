#!/bin/bash
# Copyright (c) 2025 Luka Löhr
#
# System Repair Utility - Fixes common issues on old Macs
# Handles Xcode CLT, certificates, Git configuration, and system prerequisites

set -euo pipefail

# Source utilities - handle both direct execution and sourcing
if [[ -n "${BASH_SOURCE[0]:-}" ]]; then
    REPAIR_SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
else
    REPAIR_SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
fi

# Only source if not already sourced
if ! type log_silent &>/dev/null; then
    source "${REPAIR_SCRIPT_DIR}/logging.sh"
fi
if ! type version_compare &>/dev/null; then
    source "${REPAIR_SCRIPT_DIR}/old_mac_compatibility.sh"
fi

# Global variables
CLT_PLACEHOLDER="/tmp/.com.apple.dt.CommandLineTools.installondemand.in-progress"
CERT_UPDATE_URL="https://curl.se/ca/cacert.pem"
REPAIR_STATUS="unknown"
REPAIRS_PERFORMED=0
REPAIR_MESSAGES=()  # Collect repair messages

# Check and repair Xcode Command Line Tools
check_and_repair_xcode_clt() {
    log_silent "INFO" "Checking Xcode Command Line Tools..."
    
    # Check if CLT is installed
    if ! xcode-select -p &>/dev/null; then
        install_xcode_clt
        return $?
    fi
    
    # Check CLT path
    local clt_path=$(xcode-select -p 2>/dev/null)
    
    # Verify CLT is actually functional
    if [[ ! -d "$clt_path" ]]; then
        reset_xcode_clt
        return $?
    fi
    
    # Check for common CLT issues
    local issues_found=0
    
    # Check if git works
    if ! command -v git &>/dev/null; then
        ((issues_found++))
    elif ! git --version &>/dev/null; then
        ((issues_found++))
    fi
    
    # Check for essential CLT components
    local essential_tools=("clang" "make" "gcc" "git")
    for tool in "${essential_tools[@]}"; do
        if ! command -v "$tool" &>/dev/null; then
            ((issues_found++))
        fi
    done
    
    # Check CLT version and receipts
    local clt_receipts=$(pkgutil --pkgs | grep -E 'com.apple.pkg.CLTools|com.apple.pkg.DeveloperToolsCLI' | wc -l)
    if [[ $clt_receipts -eq 0 ]]; then
        ((issues_found++))
    fi
    
    if [[ $issues_found -gt 0 ]]; then
        repair_xcode_clt
        return $?
    fi
    
    return 0
}

# Install Xcode CLT
install_xcode_clt() {
    log_silent "INFO" "Installing Xcode Command Line Tools..."
    
    # Try the automatic installation method first
    touch "$CLT_PLACEHOLDER"
    
    # Find the latest CLT package
    local clt_label=$(softwareupdate -l 2>/dev/null | grep -B 1 -E 'Command Line Tools' | awk -F'*' '/^ *\\*/ {print $2}' | sed 's/^ *//' | head -n1)
    
    if [[ -n "$clt_label" ]]; then
        if softwareupdate -i "$clt_label" --verbose 2>&1 >/dev/null; then
            rm -f "$CLT_PLACEHOLDER"
            ((REPAIRS_PERFORMED++))
            REPAIR_MESSAGES+=("Installed Xcode Command Line Tools")
            return 0
        fi
    fi
    
    rm -f "$CLT_PLACEHOLDER"
    
    # Fallback: trigger GUI installation
    xcode-select --install 2>/dev/null || true
    REPAIR_MESSAGES+=("Triggered Xcode CLT installation popup")
    
    return 1
}

# Reset Xcode CLT
reset_xcode_clt() {
    log_silent "INFO" "Resetting Xcode Command Line Tools..."
    
    # Reset xcode-select path
    if [[ $EUID -eq 0 ]]; then
        xcode-select --reset 2>/dev/null || true
    else
        sudo xcode-select --reset 2>/dev/null || true
    fi
    
    ((REPAIRS_PERFORMED++))
    REPAIR_MESSAGES+=("Reset Xcode CLT path")
    
    # Re-check after reset
    check_and_repair_xcode_clt
}

# Repair Xcode CLT
repair_xcode_clt() {
    log_silent "INFO" "Attempting to repair Xcode Command Line Tools..."
    
    # First try to switch to the correct path
    local possible_paths=(
        "/Applications/Xcode.app/Contents/Developer"
        "/Library/Developer/CommandLineTools"
    )
    
    for path in "${possible_paths[@]}"; do
        if [[ -d "$path" ]]; then
            if sudo xcode-select -s "$path" 2>/dev/null; then
                ((REPAIRS_PERFORMED++))
                REPAIR_MESSAGES+=("Switched Xcode CLT to $path")
                
                # Verify it works now
                if git --version &>/dev/null; then
                    return 0
                fi
            fi
        fi
    done
    
    # If repair didn't work, try reinstallation
    install_xcode_clt
}

# Update system certificates (only on old macOS or if certs are missing/outdated)
update_system_certificates() {
    log_silent "INFO" "Checking system certificates..."
    
    # Only update certificates on older macOS versions (pre-Catalina) or if SSL fails
    local macos_version=$(sw_vers -productVersion 2>/dev/null | cut -d. -f1)
    local needs_update=false
    
    # Check if SSL/TLS works properly
    if ! curl -fsS --connect-timeout 5 "https://github.com" -o /dev/null 2>/dev/null; then
        needs_update=true
    fi
    
    # On older macOS (< 10.15 Catalina), certificates may need updating
    if [[ "$macos_version" =~ ^10$ ]] || [[ "$macos_version" -lt 10 ]]; then
        local minor_version=$(sw_vers -productVersion 2>/dev/null | cut -d. -f2)
        if [[ "$minor_version" -lt 15 ]]; then
            needs_update=true
        fi
    fi
    
    if [[ "$needs_update" != "true" ]]; then
        return 0
    fi
    
    local cert_locations=(
        "/usr/local/etc/openssl/cert.pem"
        "/etc/ssl/cert.pem"
        "/usr/local/etc/ca-certificates/cert.pem"
    )
    
    local updated=0
    
    # Download new certificates once
    if curl -fsSL "$CERT_UPDATE_URL" -o "/tmp/cacert.pem" 2>/dev/null; then
        for cert_path in "${cert_locations[@]}"; do
            if [[ -f "$cert_path" ]] || [[ -L "$cert_path" ]]; then
                # Only update if different
                if ! cmp -s "/tmp/cacert.pem" "$cert_path" 2>/dev/null; then
                    # Backup existing certificates
                    if [[ -f "$cert_path" ]] && [[ ! -L "$cert_path" ]]; then
                        cp "$cert_path" "${cert_path}.backup.$(date +%Y%m%d)" 2>/dev/null || true
                    fi
                    
                    if [[ -w "$cert_path" ]] || [[ $EUID -eq 0 ]]; then
                        cp "/tmp/cacert.pem" "$cert_path" 2>/dev/null && ((updated++))
                    else
                        sudo cp "/tmp/cacert.pem" "$cert_path" 2>/dev/null && ((updated++))
                    fi
                fi
            fi
        done
    fi
    
    rm -f "/tmp/cacert.pem"
    
    # Handle expired DST Root CA X3 (only an issue on older systems)
    if security find-certificate -a -c "DST Root CA X3" /System/Library/Keychains/SystemRootCertificates.keychain &>/dev/null 2>&1; then
        if [[ $EUID -eq 0 ]]; then
            security delete-certificate -c "DST Root CA X3" /System/Library/Keychains/SystemRootCertificates.keychain 2>/dev/null && ((updated++))
        else
            sudo security delete-certificate -c "DST Root CA X3" /System/Library/Keychains/SystemRootCertificates.keychain 2>/dev/null && ((updated++))
        fi
    fi
    
    # Update Homebrew's ca-certificates if installed and outdated
    if command -v brew &>/dev/null && brew list ca-certificates &>/dev/null 2>&1; then
        if brew outdated ca-certificates 2>/dev/null | grep -q ca-certificates; then
            brew upgrade ca-certificates 2>/dev/null && ((updated++))
        fi
    fi
    
    if [[ $updated -gt 0 ]]; then
        ((REPAIRS_PERFORMED++))
        REPAIR_MESSAGES+=("Updated $updated certificate bundle(s)")
    fi
    
    return 0
}

# Fix Git configuration for old versions
fix_git_configuration() {
    log_silent "INFO" "Fixing Git configuration for old systems..."
    
    if ! command -v git &>/dev/null; then
        return 0
    fi
    
    local git_version=$(git --version 2>/dev/null | grep -oE '[0-9]+\.[0-9]+' | head -1)
    local changes_made=0
    
    # Helper to set config only if not already set to the expected value
    set_git_config_if_different() {
        local key="$1"
        local value="$2"
        local current=$(git config --global --get "$key" 2>/dev/null || echo "")
        if [[ "$current" != "$value" ]]; then
            git config --global "$key" "$value" 2>/dev/null && ((changes_made++))
        fi
    }
    
    # Force HTTPS instead of git:// protocol
    set_git_config_if_different "url.https://github.com/.insteadOf" "git://github.com/"
    set_git_config_if_different "url.https://.insteadOf" "git://"
    
    # For very old Git versions, set compatibility options
    if [[ $(version_compare "$git_version" "2.0") -eq -1 ]]; then
        set_git_config_if_different "http.sslVerify" "false"
        set_git_config_if_different "http.postBuffer" "524288000"
        set_git_config_if_different "core.compression" "0"
    fi
    
    # Set reasonable defaults
    set_git_config_if_different "init.defaultBranch" "main"
    set_git_config_if_different "core.autocrlf" "input"
    
    # Fix credentials for old systems
    if [[ $(version_compare "$git_version" "2.0") -ge 0 ]]; then
        set_git_config_if_different "credential.helper" "osxkeychain"
    fi
    
    if [[ $changes_made -gt 0 ]]; then
        ((REPAIRS_PERFORMED++))
        REPAIR_MESSAGES+=("Configured Git ($changes_made settings)")
    fi
    
    return 0
}

# Fix PATH issues
fix_path_issues() {
    log_silent "INFO" "Checking and fixing PATH issues..."
    
    local path_fixed=false
    local new_paths=()
    
    local essential_paths=(
        "/usr/local/bin"
        "/usr/bin"
        "/bin"
        "/usr/sbin"
        "/sbin"
    )
    
    # Add Homebrew paths based on architecture
    if [[ -d "/opt/homebrew/bin" ]]; then
        essential_paths=("/opt/homebrew/bin" "/opt/homebrew/sbin" "${essential_paths[@]}")
    elif [[ -d "/usr/local/bin/brew" ]]; then
        essential_paths=("/usr/local/bin" "/usr/local/sbin" "${essential_paths[@]}")
    fi
    
    local current_path="$PATH"
    
    for path in "${essential_paths[@]}"; do
        if [[ -d "$path" ]] && [[ ":$current_path:" != *":$path:"* ]]; then
            new_paths+=("$path")
            path_fixed=true
        fi
    done
    
    if [[ "$path_fixed" == "true" ]]; then
        export PATH="${new_paths[*]}:$PATH"
        ((REPAIRS_PERFORMED++))
        REPAIR_MESSAGES+=("Fixed PATH (added ${#new_paths[@]} directories)")
    fi
    
    return 0
}

# Clean up legacy system files
cleanup_legacy_files() {
    log_silent "INFO" "Cleaning up legacy system files..."
    
    local cleaned=0
    
    local lock_files=(
        "/usr/local/.git/index.lock"
        "/usr/local/Homebrew/.git/index.lock"
        "/opt/homebrew/.git/index.lock"
    )
    
    for lock_file in "${lock_files[@]}"; do
        if [[ -f "$lock_file" ]]; then
            rm -f "$lock_file" 2>/dev/null && ((cleaned++))
        fi
    done
    
    # Clean up broken symlinks in /usr/local/bin
    if [[ -d "/usr/local/bin" ]]; then
        local broken_links=$(find /usr/local/bin -type l ! -exec test -e {} \; -print 2>/dev/null | wc -l | tr -d ' ')
        if [[ $broken_links -gt 0 ]]; then
            find /usr/local/bin -type l ! -exec test -e {} \; -delete 2>/dev/null
            ((cleaned += broken_links))
        fi
    fi
    
    if [[ $cleaned -gt 0 ]]; then
        ((REPAIRS_PERFORMED++))
        REPAIR_MESSAGES+=("Cleaned up $cleaned legacy files")
    fi
    
    return 0
}

# Enable Rosetta 2 on Apple Silicon if needed
check_and_enable_rosetta() {
    log_silent "INFO" "Checking Rosetta 2 status..."
    
    # Only relevant for Apple Silicon
    if [[ $(uname -m) != "arm64" ]]; then
        return 0
    fi
    
    # Check if Rosetta 2 is installed
    if ! pkgutil --pkgs | grep -q "com.apple.pkg.RosettaUpdateAuto" 2>/dev/null; then
        if /usr/sbin/softwareupdate --install-rosetta --agree-to-license 2>&1 >/dev/null; then
            ((REPAIRS_PERFORMED++))
            REPAIR_MESSAGES+=("Installed Rosetta 2")
        fi
    fi
    
    return 0
}

# Fix DNS issues (common on old systems)
fix_dns_issues() {
    log_silent "INFO" "Checking DNS resolution..."
    
    local test_failed=false
    local test_domains=("github.com" "brew.sh" "apple.com")
    
    for domain in "${test_domains[@]}"; do
        if ! nslookup "$domain" &>/dev/null; then
            test_failed=true
        fi
    done
    
    if [[ "$test_failed" == "true" ]]; then
        # Flush DNS cache
        dscacheutil -flushcache 2>/dev/null || true
        
        # Restart mDNSResponder
        if [[ $EUID -eq 0 ]]; then
            killall -HUP mDNSResponder 2>/dev/null || true
        else
            sudo killall -HUP mDNSResponder 2>/dev/null || true
        fi
        
        ((REPAIRS_PERFORMED++))
        REPAIR_MESSAGES+=("Flushed DNS cache")
    fi
    
    return 0
}

# Main repair function
run_system_repairs() {
    # Run all repair functions silently
    check_and_repair_xcode_clt || true
    update_system_certificates || true
    fix_git_configuration || true
    fix_path_issues || true
    cleanup_legacy_files || true
    check_and_enable_rosetta || true
    fix_dns_issues || true
    
    # Set status
    if [[ $REPAIRS_PERFORMED -gt 0 ]]; then
        REPAIR_STATUS="repairs_completed"
    else
        REPAIR_STATUS="no_repairs_needed"
    fi
    
    return 0
}

# Get repair messages for external scripts
get_repair_messages() {
    printf '%s\n' "${REPAIR_MESSAGES[@]}"
}

get_repairs_performed() {
    echo "$REPAIRS_PERFORMED"
}

get_repair_status() {
    echo "$REPAIR_STATUS"
}

# Run if executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    run_system_repairs
    exit $?
fi