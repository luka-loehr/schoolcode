#!/bin/bash
# Cp wrapper for Guest users with security restrictions
# AdminHub - Version 2.1.0

# Find the actual cp executable
find_actual_cp() {
    # First try the backed up original binaries
    if [ -x "/opt/admin-tools/actual-direct-backups/original-cp" ]; then
        echo "/opt/admin-tools/actual-direct-backups/original-cp"
        return
    fi
    
    # Otherwise search in common locations
    local cp_locations=(
        "/bin/cp"
        "/usr/bin/cp"
    )
    
    for location in "${cp_locations[@]}"; do
        if [ -x "$location" ]; then
            echo "$location"
            return
        fi
    done
    
    # Fallback to which
    which cp 2>/dev/null || echo ""
}

ACTUAL_CP=$(find_actual_cp)

if [ -z "$ACTUAL_CP" ]; then
    echo "❌ Error: cp not found"
    exit 1
fi

# Check if running as Guest
if [[ "$USER" == "Guest" ]]; then
    # Analyze cp command for security risks
    local source_path=""
    local dest_path=""
    local arg_count=0
    
    for arg in "$@"; do
        # Skip flags
        if [[ "$arg" == -* ]]; then
            continue
        fi
        
        arg_count=$((arg_count + 1))
        
        if [[ $arg_count -eq 1 ]]; then
            source_path="$arg"
        elif [[ $arg_count -eq 2 ]]; then
            dest_path="$arg"
        fi
    done
    
    # Check source path
    if [[ -n "$source_path" ]]; then
        if [[ "$source_path" == /* ]] && [[ "$source_path" == /usr* ]] || [[ "$source_path" == /opt* ]] || [[ "$source_path" == /Library* ]] || [[ "$source_path" == /System* ]] || [[ "$source_path" == /bin* ]] || [[ "$source_path" == /sbin* ]]; then
            echo "❌ Error: Copying system files is not allowed for Guest users"
            echo "   System files are protected for security reasons"
            echo "   You can only copy files in your home directory"
            
            # Log the attempt
            echo "[$(date)] SECURITY: Guest user attempted system file copy: cp $*" >> /var/log/adminhub/security.log 2>/dev/null || true
            exit 1
        fi
    fi
    
    # Check destination path
    if [[ -n "$dest_path" ]]; then
        if [[ "$dest_path" == /* ]] && [[ "$dest_path" == /usr* ]] || [[ "$dest_path" == /opt* ]] || [[ "$dest_path" == /Library* ]] || [[ "$dest_path" == /System* ]] || [[ "$dest_path" == /bin* ]] || [[ "$dest_path" == /sbin* ]]; then
            echo "❌ Error: Copying files to system directories is not allowed for Guest users"
            echo "   System directories are protected for security reasons"
            echo "   You can only copy files within your home directory"
            
            # Log the attempt
            echo "[$(date)] SECURITY: Guest user attempted system directory copy: cp $*" >> /var/log/adminhub/security.log 2>/dev/null || true
            exit 1
        fi
        
        # Check for path traversal
        if [[ "$dest_path" == *".."* ]] && [[ "$dest_path" == *"/"* ]]; then
            echo "❌ Error: Path traversal patterns are not allowed for Guest users"
            echo "   Patterns like .. can be used to access system directories"
            
            # Log the attempt
            echo "[$(date)] SECURITY: Guest user attempted path traversal: cp $*" >> /var/log/adminhub/security.log 2>/dev/null || true
            exit 1
        fi
    fi
    
    # Check for dangerous flags
    for arg in "$@"; do
        case "$arg" in
            -r|--recursive)
                # Allow recursive flag
                ;;
            -f|--force)
                # Allow force flag
                ;;
            -v|--verbose)
                # Allow verbose flag
                ;;
            -i|--interactive)
                # Allow interactive flag
                ;;
            -p|--preserve)
                # Allow preserve flag
                ;;
            *)
                # Check for other dangerous flags
                if [[ "$arg" == -* ]] && [[ "$arg" != "-r" ]] && [[ "$arg" != "-f" ]] && [[ "$arg" != "-v" ]] && [[ "$arg" != "-i" ]] && [[ "$arg" != "-p" ]]; then
                    echo "❌ Error: Unknown or potentially dangerous cp flag: $arg"
                    echo "   Only basic cp flags are allowed for Guest users"
                    
                    # Log the attempt
                    echo "[$(date)] SECURITY: Guest user attempted unknown cp flag: cp $*" >> /var/log/adminhub/security.log 2>/dev/null || true
                    exit 1
                fi
                ;;
        esac
    done
    
    # Execute cp with restrictions
    exec "$ACTUAL_CP" "$@"
else
    # For non-Guest users, execute normally
    exec "$ACTUAL_CP" "$@"
fi
