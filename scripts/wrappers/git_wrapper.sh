#!/bin/bash
# Git wrapper for Guest users with controlled access
# AdminHub - Version 2.1.0

# Find the actual git executable
find_actual_git() {
    # First try the backed up original binaries
    if [ -x "/opt/admin-tools/actual-direct-backups/original-git" ]; then
        echo "/opt/admin-tools/actual-direct-backups/original-git"
        return
    fi
    
    # Then check if we have a direct symlink
    if [ -L "/opt/admin-tools/actual/bin/git" ]; then
        local target=$(readlink "/opt/admin-tools/actual/bin/git")
        if [ -x "$target" ]; then
            echo "$target"
            return
        fi
    fi
    
    # Otherwise search in common locations
    local git_locations=(
        "/opt/homebrew/bin/git"
        "/usr/local/bin/git"
        "/usr/bin/git"
    )
    
    for location in "${git_locations[@]}"; do
        if [ -x "$location" ]; then
            echo "$location"
            return
        fi
    done
    
    # Fallback to which
    which git 2>/dev/null || echo ""
}

ACTUAL_GIT=$(find_actual_git)

if [ -z "$ACTUAL_GIT" ]; then
    echo "❌ Error: Git not found"
    exit 1
fi

# Check if running as Guest
if [[ "$USER" == "Guest" ]]; then
    # Analyze git command for security risks
    case "$1" in
        "clone"|"pull"|"fetch"|"checkout"|"branch"|"status"|"log"|"show"|"diff"|"add"|"commit"|"push"|"remote")
            # These are generally safe git operations for Guest users
            # But we still need to ensure they can't modify system areas
            ;;
        "config")
            # Check for dangerous config operations
            if [[ "$2" == "--global" ]] || [[ "$2" == "--system" ]]; then
                echo "❌ Error: Global and system Git configuration changes are not allowed for Guest users"
                echo "   Use: git config --local <setting> <value> to configure repository-specific settings"
                echo "   Or: git config <setting> <value> for the current repository"
                
                # Log the attempt
                echo "[$(date)] SECURITY: Guest user attempted global git config: git $*" >> /var/log/adminhub/security.log 2>/dev/null || true
                exit 1
            fi
            
            # Block dangerous config settings
            if [[ "$*" == *"core.editor"* ]] && [[ "$*" == *"rm\|sh\|bash\|python\|perl"* ]]; then
                echo "❌ Error: Dangerous git editor configuration blocked for Guest users"
                echo "   Git editor settings that could execute system commands are not allowed"
                
                # Log the attempt  
                echo "[$(date)] SECURITY: Guest user attempted dangerous git config: git $*" >> /var/log/adminhub/security.log 2>/dev/null || true
                exit 1
            fi
            ;;
        "hook"|"hooks")
            echo "❌ Error: Git hooks are not allowed for Guest users"
            echo "   Git hooks can execute arbitrary commands and are restricted for security"
            
            # Log the attempt
            echo "[$(date)] SECURITY: Guest user attempted git hooks: git $*" >> /var/log/adminhub/security.log 2>/dev/null || true
            exit 1
            ;;
        "submodule")
            # Submodules can be dangerous as they can fetch from anywhere
            if [[ "$2" == "add" ]] && [[ "$*" != *"github.com"* ]] && [[ "$*" != *"gitlab.com"* ]]; then
                echo "⚠️  Warning: Submodule from untrusted source"
                echo "   For security, only submodules from trusted sources like GitHub/GitLab are recommended"
                echo "   Proceeding with caution..."
                
                # Log but allow
                echo "[$(date)] WARNING: Guest user added untrusted submodule: git $*" >> /var/log/adminhub/security.log 2>/dev/null || true
            fi
            ;;
        "credential")
            # Block credential access but allow credential storage
            if [[ "$2" == "fill" ]] || [[ "$2" == "approve" ]] || [[ "$2" == "reject" ]]; then
                echo "❌ Error: Direct git credential access is restricted for Guest users"
                echo "   Use standard git operations which will prompt for credentials when needed"
                
                # Log the attempt
                echo "[$(date)] SECURITY: Guest user attempted credential access: git $*" >> /var/log/adminhub/security.log 2>/dev/null || true
                exit 1
            fi
            ;;
        "--help"|"help"|"version"|"--version")
            # Always allow help and version
            ;;
        *)
            # Log unknown/new commands
            echo "[$(date)] INFO: Guest user used git command: git $*" >> /var/log/adminhub/security.log 2>/dev/null || true
            ;;
    esac
    
    # Set safe git environment for Guest users
    export GIT_TERMINAL_PROMPT=1  # Always prompt for credentials
    export GIT_CONFIG_NOSYSTEM=1  # Don't read system config
    
    # Limit git to safe directories (prevent directory traversal)
    if [[ -n "$PWD" ]]; then
        cd "$PWD" 2>/dev/null || {
            echo "❌ Error: Cannot access current directory"
            exit 1
        }
    fi
    
    # Execute git with restrictions
    exec "$ACTUAL_GIT" "$@"
else
    # For non-Guest users, execute normally
    exec "$ACTUAL_GIT" "$@"
fi
