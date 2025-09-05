#!/bin/bash
# Chmod wrapper for Guest users with security restrictions
# AdminHub - Version 2.1.0

# Find the actual chmod executable
find_actual_chmod() {
    # First try the backed up original binaries
    if [ -x "/opt/admin-tools/actual-direct-backups/original-chmod" ]; then
        echo "/opt/admin-tools/actual-direct-backups/original-chmod"
        return
    fi
    
    # Otherwise search in common locations
    local chmod_locations=(
        "/bin/chmod"
        "/usr/bin/chmod"
    )
    
    for location in "${chmod_locations[@]}"; do
        if [ -x "$location" ]; then
            echo "$location"
            return
        fi
    done
    
    # Fallback to which
    which chmod 2>/dev/null || echo ""
}

ACTUAL_CHMOD=$(find_actual_chmod)

if [ -z "$ACTUAL_CHMOD" ]; then
    echo "❌ Error: chmod not found"
    exit 1
fi

# Check if running as Guest
if [[ "$USER" == "Guest" ]]; then
    # Analyze chmod command for security risks
    for arg in "$@"; do
        # Check if trying to modify system files
        if [[ "$arg" == /* ]] && [[ "$arg" == /usr* ]] || [[ "$arg" == /opt* ]] || [[ "$arg" == /Library* ]] || [[ "$arg" == /System* ]] || [[ "$arg" == /bin* ]] || [[ "$arg" == /sbin* ]]; then
            echo "❌ Error: Modifying permissions of system files is not allowed for Guest users"
            echo "   System files are protected for security reasons"
            echo "   You can only modify permissions of files in your home directory"
            
            # Log the attempt
            echo "[$(date)] SECURITY: Guest user attempted system file chmod: chmod $*" >> /var/log/adminhub/security.log 2>/dev/null || true
            exit 1
        fi
        
        # Check for dangerous permission combinations
        if [[ "$arg" == *"777"* ]] || [[ "$arg" == *"666"* ]]; then
            echo "❌ Error: Dangerous permission settings (777, 666) are not allowed for Guest users"
            echo "   These permissions can create security vulnerabilities"
            echo "   Use more restrictive permissions like 755 or 644"
            
            # Log the attempt
            echo "[$(date)] SECURITY: Guest user attempted dangerous chmod: chmod $*" >> /var/log/adminhub/security.log 2>/dev/null || true
            exit 1
        fi
        
        # Check for setuid/setgid attempts
        if [[ "$arg" == *"4"* ]] || [[ "$arg" == *"2"* ]] || [[ "$arg" == *"s"* ]]; then
            echo "❌ Error: Setuid/setgid permissions are not allowed for Guest users"
            echo "   These permissions can be used for privilege escalation"
            
            # Log the attempt
            echo "[$(date)] SECURITY: Guest user attempted setuid/setgid chmod: chmod $*" >> /var/log/adminhub/security.log 2>/dev/null || true
            exit 1
        fi
    done
    
    # Execute chmod with restrictions
    exec "$ACTUAL_CHMOD" "$@"
else
    # For non-Guest users, execute normally
    exec "$ACTUAL_CHMOD" "$@"
fi
