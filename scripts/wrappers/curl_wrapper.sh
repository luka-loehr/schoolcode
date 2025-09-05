#!/bin/bash
# Curl wrapper for Guest users with security restrictions
# AdminHub - Version 2.1.0

# Find the actual curl executable
find_actual_curl() {
    # First try the backed up original binaries
    if [ -x "/opt/admin-tools/actual-direct-backups/original-curl" ]; then
        echo "/opt/admin-tools/actual-direct-backups/original-curl"
        return
    fi
    
    # Then check if we have a direct symlink
    if [ -L "/opt/admin-tools/actual/bin/curl" ]; then
        local target=$(readlink "/opt/admin-tools/actual/bin/curl")
        if [ -x "$target" ]; then
            echo "$target"
            return
        fi
    fi
    
    # Otherwise search in common locations
    local curl_locations=(
        "/opt/homebrew/bin/curl"
        "/usr/local/bin/curl"
        "/usr/bin/curl"
        "/bin/curl"
    )
    
    for location in "${curl_locations[@]}"; do
        if [ -x "$location" ]; then
            echo "$location"
            return
        fi
    done
    
    # Fallback to which
    which curl 2>/dev/null || echo ""
}

ACTUAL_CURL=$(find_actual_curl)

if [ -z "$ACTUAL_CURL" ]; then
    echo "❌ Error: Curl not found"
    exit 1
fi

# Check if running as Guest
if [[ "$USER" == "Guest" ]]; then
    # Analyze curl command for security risks
    
    # Check for dangerous flags
    for arg in "$@"; do
        case "$arg" in
            -o|--output)
                # Check if output is to system directory
                shift
                if [[ "$1" == /* ]] && [[ "$1" == /usr* ]] || [[ "$1" == /opt* ]] || [[ "$1" == /Library* ]] || [[ "$1" == /System* ]]; then
                    echo "❌ Error: Writing to system directories is not allowed for Guest users"
                    echo "   Use: curl -o ~/filename <url> (writes to your home directory)"
                    echo "   Or: curl -o ./filename <url> (writes to current directory)"
                    
                    # Log the attempt
                    echo "[$(date)] SECURITY: Guest user attempted system directory write: curl $*" >> /var/log/adminhub/security.log 2>/dev/null || true
                    exit 1
                fi
                ;;
            --output=*)
                local output_path="${arg#*=}"
                if [[ "$output_path" == /* ]] && [[ "$output_path" == /usr* ]] || [[ "$output_path" == /opt* ]] || [[ "$output_path" == /Library* ]] || [[ "$output_path" == /System* ]]; then
                    echo "❌ Error: Writing to system directories is not allowed for Guest users"
                    echo "   Use: curl -o ~/filename <url> (writes to your home directory)"
                    echo "   Or: curl -o ./filename <url> (writes to current directory)"
                    
                    # Log the attempt
                    echo "[$(date)] SECURITY: Guest user attempted system directory write: curl $*" >> /var/log/adminhub/security.log 2>/dev/null || true
                    exit 1
                fi
                ;;
            -T|--upload-file)
                echo "❌ Error: File upload operations are not allowed for Guest users"
                echo "   Upload operations can be used to modify system files"
                
                # Log the attempt
                echo "[$(date)] SECURITY: Guest user attempted file upload: curl $*" >> /var/log/adminhub/security.log 2>/dev/null || true
                exit 1
                ;;
            --data-raw|--data-ascii|--data-binary|--data-urlencode)
                echo "❌ Error: Data posting operations are not allowed for Guest users"
                echo "   Data posting can be used for malicious purposes"
                
                # Log the attempt
                echo "[$(date)] SECURITY: Guest user attempted data posting: curl $*" >> /var/log/adminhub/security.log 2>/dev/null || true
                exit 1
                ;;
            -X|--request)
                # Check for dangerous HTTP methods
                shift
                if [[ "$1" == "POST" ]] || [[ "$1" == "PUT" ]] || [[ "$1" == "DELETE" ]] || [[ "$1" == "PATCH" ]]; then
                    echo "❌ Error: HTTP $1 requests are not allowed for Guest users"
                    echo "   Only GET and HEAD requests are permitted for security"
                    
                    # Log the attempt
                    echo "[$(date)] SECURITY: Guest user attempted $1 request: curl $*" >> /var/log/adminhub/security.log 2>/dev/null || true
                    exit 1
                fi
                ;;
            --request=*)
                local method="${arg#*=}"
                if [[ "$method" == "POST" ]] || [[ "$method" == "PUT" ]] || [[ "$method" == "DELETE" ]] || [[ "$method" == "PATCH" ]]; then
                    echo "❌ Error: HTTP $method requests are not allowed for Guest users"
                    echo "   Only GET and HEAD requests are permitted for security"
                    
                    # Log the attempt
                    echo "[$(date)] SECURITY: Guest user attempted $method request: curl $*" >> /var/log/adminhub/security.log 2>/dev/null || true
                    exit 1
                fi
                ;;
            -k|--insecure)
                echo "❌ Error: Insecure SSL connections are not allowed for Guest users"
                echo "   This flag bypasses SSL certificate verification and is restricted for security"
                
                # Log the attempt
                echo "[$(date)] SECURITY: Guest user attempted insecure SSL: curl $*" >> /var/log/adminhub/security.log 2>/dev/null || true
                exit 1
                ;;
            --resolve|--connect-to)
                echo "❌ Error: DNS resolution manipulation is not allowed for Guest users"
                echo "   These flags can redirect requests to malicious servers"
                
                # Log the attempt
                echo "[$(date)] SECURITY: Guest user attempted DNS manipulation: curl $*" >> /var/log/adminhub/security.log 2>/dev/null || true
                exit 1
                ;;
            --proxy|--proxy-user|--proxy-pass)
                echo "❌ Error: Proxy configuration is not allowed for Guest users"
                echo "   Proxy settings can be used to intercept and modify requests"
                
                # Log the attempt
                echo "[$(date)] SECURITY: Guest user attempted proxy configuration: curl $*" >> /var/log/adminhub/security.log 2>/dev/null || true
                exit 1
                ;;
            --config)
                echo "❌ Error: Custom configuration files are not allowed for Guest users"
                echo "   Configuration files can contain dangerous settings"
                
                # Log the attempt
                echo "[$(date)] SECURITY: Guest user attempted config file: curl $*" >> /var/log/adminhub/security.log 2>/dev/null || true
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
                    echo "[$(date)] SECURITY: Guest user attempted system port access: curl $*" >> /var/log/adminhub/security.log 2>/dev/null || true
                    exit 1
                fi
            fi
            
            # Check for file:// URLs
            if [[ "$arg" == file://* ]]; then
                echo "❌ Error: File:// URLs are not allowed for Guest users"
                echo "   File access can be used to read system files"
                
                # Log the attempt
                echo "[$(date)] SECURITY: Guest user attempted file URL: curl $*" >> /var/log/adminhub/security.log 2>/dev/null || true
                exit 1
            fi
        fi
    done
    
    # Set safe curl environment for Guest users
    export CURL_HOME="$HOME/.curl"
    export CURL_CA_BUNDLE=""
    
    # Execute curl with restrictions
    exec "$ACTUAL_CURL" "$@"
else
    # For non-Guest users, execute normally
    exec "$ACTUAL_CURL" "$@"
fi
