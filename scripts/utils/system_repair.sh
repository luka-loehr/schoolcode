#!/bin/bash
# Copyright (c) 2025 Luka Löhr
#
# System Repair Utility - Fixes common issues on old Macs
# Handles Xcode CLT, certificates, Git configuration, and system prerequisites

set -euo pipefail

# Source utilities
SCRIPT_DIR="$(dirname "$0")"
source "${SCRIPT_DIR}/logging.sh"
source "${SCRIPT_DIR}/old_mac_compatibility.sh"

# Global variables
CLT_PLACEHOLDER="/tmp/.com.apple.dt.CommandLineTools.installondemand.in-progress"
CERT_UPDATE_URL="https://curl.se/ca/cacert.pem"
REPAIR_STATUS="unknown"
REPAIRS_PERFORMED=0

# Check and repair Xcode Command Line Tools
check_and_repair_xcode_clt() {
    log_info "Checking Xcode Command Line Tools..."
    
    # Check if CLT is installed
    if ! xcode-select -p &>/dev/null; then
        log_warn "Xcode Command Line Tools not installed"
        install_xcode_clt
        return $?
    fi
    
    # Check CLT path
    local clt_path=$(xcode-select -p 2>/dev/null)
    log_debug "CLT path: $clt_path"
    
    # Verify CLT is actually functional
    if [[ ! -d "$clt_path" ]]; then
        log_error "CLT path does not exist: $clt_path"
        reset_xcode_clt
        return $?
    fi
    
    # Check for common CLT issues
    local issues_found=0
    
    # Check if git works
    if ! command -v git &>/dev/null; then
        log_warn "Git not found despite CLT being installed"
        ((issues_found++))
    elif ! git --version &>/dev/null; then
        log_warn "Git is present but not functional"
        ((issues_found++))
    fi
    
    # Check for essential CLT components
    local essential_tools=("clang" "make" "gcc" "git")
    for tool in "${essential_tools[@]}"; do
        if ! command -v "$tool" &>/dev/null; then
            log_warn "Essential CLT tool missing: $tool"
            ((issues_found++))
        fi
    done
    
    # Check CLT version and receipts
    local clt_receipts=$(pkgutil --pkgs | grep -E 'com.apple.pkg.CLTools|com.apple.pkg.DeveloperToolsCLI' | wc -l)
    if [[ $clt_receipts -eq 0 ]]; then
        log_warn "No CLT receipts found - installation may be corrupted"
        ((issues_found++))
    fi
    
    if [[ $issues_found -gt 0 ]]; then
        log_warn "Found $issues_found issues with CLT installation"
        repair_xcode_clt
        return $?
    fi
    
    log_info "Xcode Command Line Tools are properly installed"
    return 0
}

# Install Xcode CLT
install_xcode_clt() {
    log_info "Installing Xcode Command Line Tools..."
    
    # Try the automatic installation method first
    touch "$CLT_PLACEHOLDER"
    
    # Find the latest CLT package
    local clt_label=$(softwareupdate -l 2>/dev/null | grep -B 1 -E 'Command Line Tools' | awk -F'*' '/^ *\\*/ {print $2}' | sed 's/^ *//' | head -n1)
    
    if [[ -n "$clt_label" ]]; then
        log_info "Found CLT package: $clt_label"
        if softwareupdate -i "$clt_label" --verbose 2>&1; then
            rm -f "$CLT_PLACEHOLDER"
            ((REPAIRS_PERFORMED++))
            log_info "CLT installed successfully"
            return 0
        else
            log_error "Failed to install CLT via softwareupdate"
        fi
    else
        log_warn "No CLT package found in softwareupdate"
    fi
    
    rm -f "$CLT_PLACEHOLDER"
    
    # Fallback: trigger GUI installation
    log_info "Triggering interactive CLT installation..."
    xcode-select --install 2>/dev/null || true
    
    log_warn "Please complete the CLT installation in the popup window"
    log_warn "After installation, run this script again"
    
    return 1
}

# Reset Xcode CLT
reset_xcode_clt() {
    log_info "Resetting Xcode Command Line Tools..."
    
    # Reset xcode-select path
    if [[ $EUID -eq 0 ]]; then
        xcode-select --reset
        log_info "Reset xcode-select to default path"
    else
        log_warn "Need sudo to reset xcode-select path"
        sudo xcode-select --reset
    fi
    
    ((REPAIRS_PERFORMED++))
    
    # Re-check after reset
    check_and_repair_xcode_clt
}

# Repair Xcode CLT
repair_xcode_clt() {
    log_info "Attempting to repair Xcode Command Line Tools..."
    
    # First try to switch to the correct path
    local possible_paths=(
        "/Applications/Xcode.app/Contents/Developer"
        "/Library/Developer/CommandLineTools"
    )
    
    for path in "${possible_paths[@]}"; do
        if [[ -d "$path" ]]; then
            log_debug "Trying to switch to: $path"
            if sudo xcode-select -s "$path" 2>/dev/null; then
                log_info "Switched to $path"
                ((REPAIRS_PERFORMED++))
                
                # Verify it works now
                if git --version &>/dev/null; then
                    log_info "CLT repair successful"
                    return 0
                fi
            fi
        fi
    done
    
    # If repair didn't work, try reinstallation
    log_warn "Could not repair CLT, attempting reinstallation..."
    install_xcode_clt
}

# Update system certificates
update_system_certificates() {
    log_info "Updating system certificates..."
    
    # Update curl/wget certificates
    local cert_locations=(
        "/usr/local/etc/openssl/cert.pem"
        "/etc/ssl/cert.pem"
        "/usr/local/etc/ca-certificates/cert.pem"
    )
    
    local updated=0
    
    for cert_path in "${cert_locations[@]}"; do
        if [[ -f "$cert_path" ]] || [[ -L "$cert_path" ]]; then
            log_debug "Found certificate bundle at: $cert_path"
            
            # Backup existing certificates
            if [[ -f "$cert_path" ]] && [[ ! -L "$cert_path" ]]; then
                cp "$cert_path" "${cert_path}.backup.$(date +%Y%m%d)" 2>/dev/null || true
            fi
            
            # Download new certificates
            if curl -fsSL "$CERT_UPDATE_URL" -o "/tmp/cacert.pem" 2>/dev/null; then
                if [[ -w "$cert_path" ]] || [[ $EUID -eq 0 ]]; then
                    cp "/tmp/cacert.pem" "$cert_path" 2>/dev/null && ((updated++))
                else
                    sudo cp "/tmp/cacert.pem" "$cert_path" 2>/dev/null && ((updated++))
                fi
            fi
        fi
    done
    
    # Clean up
    rm -f "/tmp/cacert.pem"
    
    # Handle expired DST Root CA X3 (Let's Encrypt issue)
    if security find-certificate -a -c "DST Root CA X3" /System/Library/Keychains/SystemRootCertificates.keychain &>/dev/null; then
        log_info "Removing expired DST Root CA X3 certificate..."
        if [[ $EUID -eq 0 ]]; then
            security delete-certificate -c "DST Root CA X3" /System/Library/Keychains/SystemRootCertificates.keychain 2>/dev/null || true
        else
            sudo security delete-certificate -c "DST Root CA X3" /System/Library/Keychains/SystemRootCertificates.keychain 2>/dev/null || true
        fi
        ((updated++))
    fi
    
    # Update Homebrew's ca-certificates if installed
    if command -v brew &>/dev/null && brew list ca-certificates &>/dev/null; then
        log_info "Updating Homebrew ca-certificates..."
        brew upgrade ca-certificates 2>/dev/null || brew install ca-certificates 2>/dev/null || true
        ((updated++))
    fi
    
    if [[ $updated -gt 0 ]]; then
        log_info "Updated $updated certificate bundle(s)"
        ((REPAIRS_PERFORMED++))
    else
        log_info "No certificate updates needed"
    fi
    
    return 0
}

# Fix Git configuration for old versions
fix_git_configuration() {
    log_info "Fixing Git configuration for old systems..."
    
    if ! command -v git &>/dev/null; then
        log_warn "Git not installed, skipping Git configuration"
        return 0
    fi
    
    local git_version=$(git --version 2>/dev/null | grep -oE '[0-9]+\.[0-9]+' | head -1)
    log_debug "Git version: $git_version"
    
    # Force HTTPS instead of git:// protocol (more reliable on old systems)
    log_info "Configuring Git to use HTTPS instead of git:// protocol..."
    git config --global url."https://github.com/".insteadOf git://github.com/ 2>/dev/null || true
    git config --global url."https://".insteadOf git:// 2>/dev/null || true
    
    # For very old Git versions, set compatibility options
    if [[ $(version_compare "$git_version" "2.0") -eq -1 ]]; then
        log_warn "Very old Git version detected, applying compatibility settings..."
        
        # Disable SSL verification temporarily (only for old Git)
        # This is insecure but may be necessary for very old systems
        git config --global http.sslVerify false 2>/dev/null || true
        log_warn "SSL verification disabled for Git (old version compatibility)"
        
        # Use older protocols
        git config --global http.postBuffer 524288000 2>/dev/null || true
        git config --global core.compression 0 2>/dev/null || true
    fi
    
    # Set reasonable defaults
    git config --global init.defaultBranch main 2>/dev/null || true
    git config --global core.autocrlf input 2>/dev/null || true
    
    # Fix credentials for old systems
    if [[ $(version_compare "$git_version" "2.0") -ge 0 ]]; then
        git config --global credential.helper osxkeychain 2>/dev/null || true
    fi
    
    ((REPAIRS_PERFORMED++))
    log_info "Git configuration updated for compatibility"
    
    return 0
}

# Fix PATH issues
fix_path_issues() {
    log_info "Checking and fixing PATH issues..."
    
    local path_fixed=false
    local new_paths=()
    
    # Essential paths that should be in PATH
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
    
    # Check current PATH
    local current_path="$PATH"
    
    for path in "${essential_paths[@]}"; do
        if [[ -d "$path" ]] && [[ ":$current_path:" != *":$path:"* ]]; then
            log_warn "Missing essential PATH: $path"
            new_paths+=("$path")
            path_fixed=true
        fi
    done
    
    if [[ "$path_fixed" == "true" ]]; then
        # Update PATH for current session
        export PATH="${new_paths[*]}:$PATH"
        log_info "Updated PATH for current session"
        
        # Provide instructions for permanent fix
        log_info "To make PATH changes permanent, add to your shell profile:"
        log_info "export PATH=\"${new_paths[*]}:\$PATH\""
        
        ((REPAIRS_PERFORMED++))
    else
        log_info "PATH contains all essential directories"
    fi
    
    return 0
}

# Clean up legacy system files
cleanup_legacy_files() {
    log_info "Cleaning up legacy system files..."
    
    local cleaned=0
    
    # Remove old Homebrew locks
    local lock_files=(
        "/usr/local/.git/index.lock"
        "/usr/local/Homebrew/.git/index.lock"
        "/opt/homebrew/.git/index.lock"
    )
    
    for lock_file in "${lock_files[@]}"; do
        if [[ -f "$lock_file" ]]; then
            log_debug "Removing stale lock file: $lock_file"
            rm -f "$lock_file" 2>/dev/null && ((cleaned++))
        fi
    done
    
    # Clean up broken symlinks in /usr/local/bin
    if [[ -d "/usr/local/bin" ]]; then
        local broken_links=$(find /usr/local/bin -type l ! -exec test -e {} \; -print 2>/dev/null | wc -l)
        if [[ $broken_links -gt 0 ]]; then
            log_info "Found $broken_links broken symlinks in /usr/local/bin"
            find /usr/local/bin -type l ! -exec test -e {} \; -delete 2>/dev/null
            ((cleaned += broken_links))
        fi
    fi
    
    # Remove old Python 2.7 user packages that might conflict
    local old_python_dirs=(
        "$HOME/Library/Python/2.7"
        "$HOME/.local/lib/python2.7"
    )
    
    for dir in "${old_python_dirs[@]}"; do
        if [[ -d "$dir" ]]; then
            log_warn "Found old Python 2.7 directory: $dir"
            # Don't auto-remove, just warn
        fi
    done
    
    if [[ $cleaned -gt 0 ]]; then
        log_info "Cleaned up $cleaned legacy files"
        ((REPAIRS_PERFORMED++))
    else
        log_info "No legacy files to clean up"
    fi
    
    return 0
}

# Enable Rosetta 2 on Apple Silicon if needed
check_and_enable_rosetta() {
    log_info "Checking Rosetta 2 status..."
    
    # Only relevant for Apple Silicon
    if [[ $(uname -m) != "arm64" ]]; then
        log_debug "Intel Mac detected, Rosetta 2 not needed"
        return 0
    fi
    
    # Check if Rosetta 2 is installed
    if ! pkgutil --pkgs | grep -q "com.apple.pkg.RosettaUpdateAuto" 2>/dev/null; then
        log_warn "Rosetta 2 not installed on Apple Silicon Mac"
        log_info "Installing Rosetta 2 for x86_64 compatibility..."
        
        if /usr/sbin/softwareupdate --install-rosetta --agree-to-license 2>&1; then
            log_info "Rosetta 2 installed successfully"
            ((REPAIRS_PERFORMED++))
        else
            log_error "Failed to install Rosetta 2"
            log_error "Some Intel-only tools may not work"
        fi
    else
        log_info "Rosetta 2 is already installed"
    fi
    
    return 0
}

# Fix DNS issues (common on old systems)
fix_dns_issues() {
    log_info "Checking DNS resolution..."
    
    # Test DNS resolution
    local test_failed=false
    local test_domains=("github.com" "brew.sh" "apple.com")
    
    for domain in "${test_domains[@]}"; do
        if ! nslookup "$domain" &>/dev/null; then
            log_warn "DNS resolution failed for: $domain"
            test_failed=true
        fi
    done
    
    if [[ "$test_failed" == "true" ]]; then
        log_info "Attempting to fix DNS issues..."
        
        # Flush DNS cache
        if dscacheutil -flushcache 2>/dev/null; then
            log_info "Flushed DNS cache"
        fi
        
        # Restart mDNSResponder
        if [[ $EUID -eq 0 ]]; then
            killall -HUP mDNSResponder 2>/dev/null || true
        else
            sudo killall -HUP mDNSResponder 2>/dev/null || true
        fi
        
        # Add public DNS servers if needed
        log_info "Consider adding public DNS servers (8.8.8.8, 1.1.1.1) in Network Preferences"
        
        ((REPAIRS_PERFORMED++))
    else
        log_info "DNS resolution working properly"
    fi
    
    return 0
}

# Main repair function
run_system_repairs() {
    log_info "Starting comprehensive system repairs for old Mac..."
    
    # Check if running with sufficient privileges
    if [[ $EUID -ne 0 ]]; then
        log_warn "Running without root privileges. Some repairs may prompt for password."
    fi
    
    # Run all repair functions
    check_and_repair_xcode_clt
    update_system_certificates
    fix_git_configuration
    fix_path_issues
    cleanup_legacy_files
    check_and_enable_rosetta
    fix_dns_issues
    
    # Summary
    if [[ $REPAIRS_PERFORMED -gt 0 ]]; then
        REPAIR_STATUS="repairs_completed"
        log_info "System repairs completed. Made $REPAIRS_PERFORMED repairs."
    else
        REPAIR_STATUS="no_repairs_needed"
        log_info "No system repairs were needed."
    fi
    
    return 0
}

# Run if executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    run_system_repairs
    exit $?
fi