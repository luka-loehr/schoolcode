#!/bin/bash
# Mv wrapper for Guest users with security restrictions
# AdminHub - Version 2.1.0

# Find the actual mv executable
find_actual_mv() {
    # First try the backed up original binaries
    if [ -x "/opt/admin-tools/actual-direct-backups/original-mv" ]; then
        echo "/opt/admin-tools/actual-direct-backups/original-mv"
        return
    fi
    
    # Otherwise search in common locations
    local mv_locations=(
        "/bin/mv"
        "/usr/bin/mv"
    )
    
    for location in "${mv_locations[@]}"; do
        if [ -x "$location" ]; then
            echo "$location"
            return
        fi
    done
    
    # Fallback to which
    which mv 2>/dev/null || echo ""
}

ACTUAL_MV=$(find_actual_mv)

if [ -z "$ACTUAL_MV" ]; then
    echo "❌ Error: mv not found"
    exit 1
fi

# Check if running as Guest
if [[ "$USER" == "Guest" ]]; then
    # Analyze mv command for security risks
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
            echo "❌ Error: Moving system files is not allowed for Guest users"
            echo "   System files are protected for security reasons"
            echo "   You can only move files in your home directory"
            
            # Log the attempt
            echo "[$(date)] SECURITY: Guest user attempted system file move: mv $*" >> /var/log/adminhub/security.log 2>/dev/null || true
            exit 1
        fi
    fi
    
    # Check destination path
    if [[ -n "$dest_path" ]]; then
        if [[ "$dest_path" == /* ]] && [[ "$dest_path" == /usr* ]] || [[ "$dest_path" == /opt* ]] || [[ "$dest_path" == /Library* ]] || [[ "$dest_path" == /System* ]] || [[ "$dest_path" == /bin* ]] || [[ "$dest_path" == /sbin* ]]; then
            echo "❌ Error: Moving files to system directories is not allowed for Guest users"
            echo "   System directories are protected for security reasons"
            echo "   You can only move files within your home directory"
            
            # Log the attempt
            echo "[$(date)] SECURITY: Guest user attempted system directory move: mv $*" >> /var/log/adminhub/security.log 2>/dev/null || true
            exit 1
        fi
        
        # Check for path traversal
        if [[ "$dest_path" == *".."* ]] && [[ "$dest_path" == *"/"* ]]; then
            echo "❌ Error: Path traversal patterns are not allowed for Guest users"
            echo "   Patterns like .. can be used to access system directories"
            
            # Log the attempt
            echo "[$(date)] SECURITY: Guest user attempted path traversal: mv $*" >> /var/log/adminhub/security.log 2>/dev/null || true
            exit 1
        fi
    fi
    
    # Check for dangerous flags
    for arg in "$@"; do
        case "$arg" in
            -f|--force)
                # Allow force flag
                ;;
            -v|--verbose)
                # Allow verbose flag
                ;;
            -i|--interactive)
                # Allow interactive flag
                ;;
            *)
                # Check for other dangerous flags
                if [[ "$arg" == -* ]] && [[ "$arg" != "-f" ]] && [[ "$arg" != "-v" ]] && [[ "$arg" != "-i" ]]; then
                    echo "❌ Error: Unknown or potentially dangerous mv flag: $arg"
                    echo "   Only basic mv flags are allowed for Guest users"
                    
                    # Log the attempt
                    echo "[$(date)] SECURITY: Guest user attempted unknown mv flag: mv $*" >> /var/log/adminhub/security.log 2>/dev/null || true
                    exit 1
                fi
                ;;
        esac
    done
    
    # Execute mv with restrictions
    exec "$ACTUAL_MV" "$@"
else
    # For non-Guest users, execute normally
    exec "$ACTUAL_MV" "$@"
fi
