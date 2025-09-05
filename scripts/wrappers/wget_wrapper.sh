#!/bin/bash
# Wget wrapper for Guest users with security restrictions
# AdminHub - Version 2.1.0

# Find the actual wget executable
find_actual_wget() {
    # First try the backed up original binaries
    if [ -x "/opt/admin-tools/actual-direct-backups/original-wget" ]; then
        echo "/opt/admin-tools/actual-direct-backups/original-wget"
        return
    fi
    
    # Then check if we have a direct symlink
    if [ -L "/opt/admin-tools/actual/bin/wget" ]; then
        local target=$(readlink "/opt/admin-tools/actual/bin/wget")
        if [ -x "$target" ]; then
            echo "$target"
            return
        fi
    fi
    
    # Otherwise search in common locations
    local wget_locations=(
        "/opt/homebrew/bin/wget"
        "/usr/local/bin/wget"
        "/usr/bin/wget"
        "/bin/wget"
    )
    
    for location in "${wget_locations[@]}"; do
        if [ -x "$location" ]; then
            echo "$location"
            return
        fi
    done
    
    # Fallback to which
    which wget 2>/dev/null || echo ""
}

ACTUAL_WGET=$(find_actual_wget)

if [ -z "$ACTUAL_WGET" ]; then
    echo "❌ Error: Wget not found"
    exit 1
fi

# Check if running as Guest
if [[ "$USER" == "Guest" ]]; then
    # Analyze wget command for security risks
    local dangerous_flags=()
    local system_paths=()
    
    # Check for dangerous flags
    for arg in "$@"; do
        case "$arg" in
            -O|--output-document)
                # Check if output is to system directory
                shift
                if [[ "$1" == /* ]] && [[ "$1" == /usr* ]] || [[ "$1" == /opt* ]] || [[ "$1" == /Library* ]] || [[ "$1" == /System* ]]; then
                    echo "❌ Error: Writing to system directories is not allowed for Guest users"
                    echo "   Use: wget -O ~/filename <url> (writes to your home directory)"
                    echo "   Or: wget -O ./filename <url> (writes to current directory)"
                    
                    # Log the attempt
                    echo "[$(date)] SECURITY: Guest user attempted system directory write: wget $*" >> /var/log/adminhub/security.log 2>/dev/null || true
                    exit 1
                fi
                ;;
            --output-document=*)
                local output_path="${arg#*=}"
                if [[ "$output_path" == /* ]] && [[ "$output_path" == /usr* ]] || [[ "$output_path" == /opt* ]] || [[ "$output_path" == /Library* ]] || [[ "$output_path" == /System* ]]; then
                    echo "❌ Error: Writing to system directories is not allowed for Guest users"
                    echo "   Use: wget -O ~/filename <url> (writes to your home directory)"
                    echo "   Or: wget -O ./filename <url> (writes to current directory)"
                    
                    # Log the attempt
                    echo "[$(date)] SECURITY: Guest user attempted system directory write: wget $*" >> /var/log/adminhub/security.log 2>/dev/null || true
                    exit 1
                fi
                ;;
            -P|--directory-prefix)
                # Check if directory prefix is system directory
                shift
                if [[ "$1" == /* ]] && [[ "$1" == /usr* ]] || [[ "$1" == /opt* ]] || [[ "$1" == /Library* ]] || [[ "$1" == /System* ]]; then
                    echo "❌ Error: Using system directories as prefix is not allowed for Guest users"
                    echo "   Use: wget -P ~/downloads <url> (downloads to your home directory)"
                    echo "   Or: wget -P ./downloads <url> (downloads to current directory)"
                    
                    # Log the attempt
                    echo "[$(date)] SECURITY: Guest user attempted system directory prefix: wget $*" >> /var/log/adminhub/security.log 2>/dev/null || true
                    exit 1
                fi
                ;;
            --directory-prefix=*)
                local prefix_path="${arg#*=}"
                if [[ "$prefix_path" == /* ]] && [[ "$prefix_path" == /usr* ]] || [[ "$prefix_path" == /opt* ]] || [[ "$prefix_path" == /Library* ]] || [[ "$prefix_path" == /System* ]]; then
                    echo "❌ Error: Using system directories as prefix is not allowed for Guest users"
                    echo "   Use: wget -P ~/downloads <url> (downloads to your home directory)"
                    echo "   Or: wget -P ./downloads <url> (downloads to current directory)"
                    
                    # Log the attempt
                    echo "[$(date)] SECURITY: Guest user attempted system directory prefix: wget $*" >> /var/log/adminhub/security.log 2>/dev/null || true
                    exit 1
                fi
                ;;
            --post-data|--post-file)
                echo "❌ Error: Data posting operations are not allowed for Guest users"
                echo "   Data posting can be used for malicious purposes"
                
                # Log the attempt
                echo "[$(date)] SECURITY: Guest user attempted data posting: wget $*" >> /var/log/adminhub/security.log 2>/dev/null || true
                exit 1
                ;;
            --method)
                # Check for dangerous HTTP methods
                shift
                if [[ "$1" == "POST" ]] || [[ "$1" == "PUT" ]] || [[ "$1" == "DELETE" ]] || [[ "$1" == "PATCH" ]]; then
                    echo "❌ Error: HTTP $1 requests are not allowed for Guest users"
                    echo "   Only GET and HEAD requests are permitted for security"
                    
                    # Log the attempt
                    echo "[$(date)] SECURITY: Guest user attempted $1 request: wget $*" >> /var/log/adminhub/security.log 2>/dev/null || true
                    exit 1
                fi
                ;;
            -k|--no-check-certificate)
                echo "❌ Error: Insecure SSL connections are not allowed for Guest users"
                echo "   This flag bypasses SSL certificate verification and is restricted for security"
                
                # Log the attempt
                echo "[$(date)] SECURITY: Guest user attempted insecure SSL: wget $*" >> /var/log/adminhub/security.log 2>/dev/null || true
                exit 1
                ;;
            --resolve|--dns-servers)
                echo "❌ Error: DNS resolution manipulation is not allowed for Guest users"
                echo "   These flags can redirect requests to malicious servers"
                
                # Log the attempt
                echo "[$(date)] SECURITY: Guest user attempted DNS manipulation: wget $*" >> /var/log/adminhub/security.log 2>/dev/null || true
                exit 1
                ;;
            --proxy|--proxy-user|--proxy-password)
                echo "❌ Error: Proxy configuration is not allowed for Guest users"
                echo "   Proxy settings can be used to intercept and modify requests"
                
                # Log the attempt
                echo "[$(date)] SECURITY: Guest user attempted proxy configuration: wget $*" >> /var/log/adminhub/security.log 2>/dev/null || true
                exit 1
                ;;
            --config)
                echo "❌ Error: Custom configuration files are not allowed for Guest users"
                echo "   Configuration files can contain dangerous settings"
                
                # Log the attempt
                echo "[$(date)] SECURITY: Guest user attempted config file: wget $*" >> /var/log/adminhub/security.log 2>/dev/null || true
                exit 1
                ;;
            --execute)
                echo "❌ Error: Command execution is not allowed for Guest users"
                echo "   This flag can execute arbitrary commands and is restricted for security"
                
                # Log the attempt
                echo "[$(date)] SECURITY: Guest user attempted command execution: wget $*" >> /var/log/adminhub/security.log 2>/dev/null || true
                exit 1
                ;;
        esac
    done
    
    # Check URLs for suspicious patterns
    for arg in "$@"; do
        if [[ "$arg" == http* ]]; then
            # Check for localhost/127.0.0.1 access to system ports
            if [[ "$arg" == *"localhost"* ]] || [[ "$arg" == *"127.0.0.1"* ]]; then
                if [[ "$arg" == *":22"* ]] || [[ "$arg" == *":21"* ]] || [[ "$arg" == *":23"* ]] || [[ "$arg" == *":25"* ]] || [[ "$arg" == *":53"* ]] || [[ "$arg" == *":80"* ]] || [[ "$arg" == *":443"* ]] || [[ "$arg" == *":993"* ]] || [[ "$arg" == *":995"* ]]; then
                    echo "❌ Error: Access to system ports is not allowed for Guest users"
                    echo "   System ports are restricted for security"
                    
                    # Log the attempt
                    echo "[$(date)] SECURITY: Guest user attempted system port access: wget $*" >> /var/log/adminhub/security.log 2>/dev/null || true
                    exit 1
                fi
            fi
            
            # Check for file:// URLs
            if [[ "$arg" == file://* ]]; then
                echo "❌ Error: File:// URLs are not allowed for Guest users"
                echo "   File access can be used to read system files"
                
                # Log the attempt
                echo "[$(date)] SECURITY: Guest user attempted file URL: wget $*" >> /var/log/adminhub/security.log 2>/dev/null || true
                exit 1
            fi
        fi
    done
    
    # Set safe wget environment for Guest users
    export WGETRC="$HOME/.wgetrc"
    export WGET_HOME="$HOME/.wget"
    
    # Execute wget with restrictions
    exec "$ACTUAL_WGET" "$@"
else
    # For non-Guest users, execute normally
    exec "$ACTUAL_WGET" "$@"
fi
