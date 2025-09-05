#!/bin/bash
# Rm wrapper for Guest users with security restrictions
# AdminHub - Version 2.1.0

# Find the actual rm executable
find_actual_rm() {
    # First try the backed up original binaries
    if [ -x "/opt/admin-tools/actual-direct-backups/original-rm" ]; then
        echo "/opt/admin-tools/actual-direct-backups/original-rm"
        return
    fi
    
    # Otherwise search in common locations
    local rm_locations=(
        "/bin/rm"
        "/usr/bin/rm"
    )
    
    for location in "${rm_locations[@]}"; do
        if [ -x "$location" ]; then
            echo "$location"
            return
        fi
    done
    
    # Fallback to which
    which rm 2>/dev/null || echo ""
}

ACTUAL_RM=$(find_actual_rm)

if [ -z "$ACTUAL_RM" ]; then
    echo "❌ Error: rm not found"
    exit 1
fi

# Check if running as Guest
if [[ "$USER" == "Guest" ]]; then
    # Analyze rm command for security risks
    for arg in "$@"; do
        # Skip flags, check file paths
        if [[ "$arg" == -* ]]; then
            continue
        fi
        
        # Check if trying to delete system files
        if [[ "$arg" == /* ]] && [[ "$arg" == /usr* ]] || [[ "$arg" == /opt* ]] || [[ "$arg" == /Library* ]] || [[ "$arg" == /System* ]] || [[ "$arg" == /bin* ]] || [[ "$arg" == /sbin* ]]; then
            echo "❌ Error: Deleting system files is not allowed for Guest users"
            echo "   System files are protected for security reasons"
            echo "   You can only delete files in your home directory"
            
            # Log the attempt
            echo "[$(date)] SECURITY: Guest user attempted system file deletion: rm $*" >> /var/log/adminhub/security.log 2>/dev/null || true
            exit 1
        fi
        
        # Check for dangerous patterns
        if [[ "$arg" == *"/*"* ]] || [[ "$arg" == *".."* ]]; then
            echo "❌ Error: Path traversal patterns are not allowed for Guest users"
            echo "   Patterns like /* or .. can be used to access system directories"
            
            # Log the attempt
            echo "[$(date)] SECURITY: Guest user attempted path traversal: rm $*" >> /var/log/adminhub/security.log 2>/dev/null || true
            exit 1
        fi
    done
    
    # Check for dangerous flags
    for arg in "$@"; do
        case "$arg" in
            -rf|--recursive|--force)
                # Allow but warn
                echo "⚠️  Warning: Using -rf can delete many files at once"
                echo "   Make sure you're only deleting files in your home directory"
                ;;
            -I|--interactive)
                # Allow interactive mode
                ;;
            -v|--verbose)
                # Allow verbose mode
                ;;
            *)
                # Check for other dangerous flags
                if [[ "$arg" == -* ]] && [[ "$arg" != "-r" ]] && [[ "$arg" != "-f" ]] && [[ "$arg" != "-v" ]] && [[ "$arg" != "-i" ]]; then
                    echo "❌ Error: Unknown or potentially dangerous rm flag: $arg"
                    echo "   Only basic rm flags are allowed for Guest users"
                    
                    # Log the attempt
                    echo "[$(date)] SECURITY: Guest user attempted unknown rm flag: rm $*" >> /var/log/adminhub/security.log 2>/dev/null || true
                    exit 1
                fi
                ;;
        esac
    done
    
    # Execute rm with restrictions
    exec "$ACTUAL_RM" "$@"
else
    # For non-Guest users, execute normally
    exec "$ACTUAL_RM" "$@"
fi
