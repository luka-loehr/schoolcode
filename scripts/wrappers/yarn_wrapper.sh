#!/bin/bash
# Yarn wrapper for Guest users with security restrictions
# AdminHub - Version 2.1.0

# Find the actual yarn executable
find_actual_yarn() {
    # First try the backed up original binaries
    if [ -x "/opt/admin-tools/actual-direct-backups/original-yarn" ]; then
        echo "/opt/admin-tools/actual-direct-backups/original-yarn"
        return
    fi
    
    # Then check if we have a direct symlink
    if [ -L "/opt/admin-tools/actual/bin/yarn" ]; then
        local target=$(readlink "/opt/admin-tools/actual/bin/yarn")
        if [ -x "$target" ]; then
            echo "$target"
            return
        fi
    fi
    
    # Otherwise search in common locations
    local yarn_locations=(
        "/opt/homebrew/bin/yarn"
        "/usr/local/bin/yarn"
        "/usr/bin/yarn"
    )
    
    for location in "${yarn_locations[@]}"; do
        if [ -x "$location" ]; then
            echo "$location"
            return
        fi
    done
    
    # Fallback to which
    which yarn 2>/dev/null || echo ""
}

ACTUAL_YARN=$(find_actual_yarn)

if [ -z "$ACTUAL_YARN" ]; then
    echo "❌ Error: Yarn not found"
    exit 1
fi

# Check if running as Guest
if [[ "$USER" == "Guest" ]]; then
    # Analyze yarn command for security risks
    case "$1" in
        "add"|"install")
            # Check for global installation attempts
            if [[ "$*" == *"-g"* ]] || [[ "$*" == *"--global"* ]]; then
                echo "❌ Error: Global Yarn installations are not allowed for Guest users"
                echo "   Use: yarn add <package> (installs locally to current project)"
                echo "   Global packages would affect all users and are restricted for security"
                
                # Log the attempt
                echo "[$(date)] SECURITY: Guest user attempted global yarn add: yarn $*" >> /var/log/adminhub/security.log 2>/dev/null || true
                exit 1
            fi
            
            # Check for dangerous install flags
            for arg in "$@"; do
                case "$arg" in
                    --prefix|--global-folder)
                        echo "❌ Error: System installation flags are not allowed for Guest users"
                        echo "   All packages will be installed locally to your project directory"
                        exit 1
                        ;;
                    --unsafe-perm|--allow-root)
                        echo "❌ Error: Unsafe permission flags are not allowed for Guest users"
                        echo "   These flags can bypass security restrictions"
                        exit 1
                        ;;
                esac
            done
            
            # Set safe yarn environment
            export YARN_CACHE_FOLDER="$HOME/.yarn/cache"
            export YARN_GLOBAL_FOLDER="$HOME/.yarn/global"
            ;;
        "remove"|"rm")
            # Check for global removal attempts
            if [[ "$*" == *"-g"* ]] || [[ "$*" == *"--global"* ]]; then
                echo "❌ Error: Global Yarn removals are not allowed for Guest users"
                echo "   Use: yarn remove <package> (removes from current project only)"
                
                # Log the attempt
                echo "[$(date)] SECURITY: Guest user attempted global yarn remove: yarn $*" >> /var/log/adminhub/security.log 2>/dev/null || true
                exit 1
            fi
            ;;
        "link"|"unlink")
            echo "❌ Error: Yarn link operations are not allowed for Guest users"
            echo "   Linking can create system-wide packages and is restricted for security"
            
            # Log the attempt
            echo "[$(date)] SECURITY: Guest user attempted yarn link: yarn $*" >> /var/log/adminhub/security.log 2>/dev/null || true
            exit 1
            ;;
        "global")
            echo "❌ Error: Yarn global commands are not allowed for Guest users"
            echo "   Global operations affect all users and are restricted for security"
            echo "   Use local project commands instead"
            
            # Log the attempt
            echo "[$(date)] SECURITY: Guest user attempted yarn global: yarn $*" >> /var/log/adminhub/security.log 2>/dev/null || true
            exit 1
            ;;
        "run"|"start"|"test"|"build"|"dev"|"serve")
            # Allow common development commands
            ;;
        "list"|"ls"|"outdated"|"info"|"why"|"help"|"--help"|"--version"|"-v")
            # Allow read-only operations
            ;;
        "config")
            # Check for dangerous config operations
            if [[ "$2" == "set" ]] && [[ "$*" == *"global-folder"* ]]; then
                echo "❌ Error: Yarn global folder configuration is not allowed for Guest users"
                echo "   This could redirect global installations to system directories"
                
                # Log the attempt
                echo "[$(date)] SECURITY: Guest user attempted yarn global config: yarn $*" >> /var/log/adminhub/security.log 2>/dev/null || true
                exit 1
            fi
            ;;
        *)
            # Log unknown commands for monitoring
            echo "[$(date)] INFO: Guest user used yarn command: yarn $*" >> /var/log/adminhub/security.log 2>/dev/null || true
            ;;
    esac
    
    # Set safe yarn environment for Guest users
    export YARN_CACHE_FOLDER="$HOME/.yarn/cache"
    export YARN_GLOBAL_FOLDER="$HOME/.yarn/global"
    export YARN_CONFIG_FOLDER="$HOME/.yarn"
    
    # Ensure no global installations
    export YARN_GLOBAL_FOLDER="$HOME/.yarn/global"
    
    # Execute yarn with restrictions
    exec "$ACTUAL_YARN" "$@"
else
    # For non-Guest users, execute normally
    exec "$ACTUAL_YARN" "$@"
fi
