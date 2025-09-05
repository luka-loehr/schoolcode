#!/bin/bash
# NPM wrapper for Guest users with security restrictions
# AdminHub - Version 2.1.0

# Find the actual npm executable
find_actual_npm() {
    # First try the backed up original binaries
    if [ -x "/opt/admin-tools/actual-direct-backups/original-npm" ]; then
        echo "/opt/admin-tools/actual-direct-backups/original-npm"
        return
    fi
    
    # Then check if we have a direct symlink
    if [ -L "/opt/admin-tools/actual/bin/npm" ]; then
        local target=$(readlink "/opt/admin-tools/actual/bin/npm")
        if [ -x "$target" ]; then
            echo "$target"
            return
        fi
    fi
    
    # Otherwise search in common locations
    local npm_locations=(
        "/opt/homebrew/bin/npm"
        "/usr/local/bin/npm"
        "/usr/bin/npm"
    )
    
    for location in "${npm_locations[@]}"; do
        if [ -x "$location" ]; then
            echo "$location"
            return
        fi
    done
    
    # Fallback to which
    which npm 2>/dev/null || echo ""
}

ACTUAL_NPM=$(find_actual_npm)

if [ -z "$ACTUAL_NPM" ]; then
    echo "❌ Error: NPM not found"
    exit 1
fi

# Check if running as Guest
if [[ "$USER" == "Guest" ]]; then
    # Analyze npm command for security risks
    case "$1" in
        "install"|"i")
            # Check for global installation attempts
            if [[ "$*" == *"-g"* ]] || [[ "$*" == *"--global"* ]]; then
                echo "❌ Error: Global NPM installations are not allowed for Guest users"
                echo "   Use: npm install <package> (installs locally to current project)"
                echo "   Global packages would affect all users and are restricted for security"
                
                # Log the attempt
                echo "[$(date)] SECURITY: Guest user attempted global npm install: npm $*" >> /var/log/adminhub/security.log 2>/dev/null || true
                exit 1
            fi
            
            # Check for dangerous install flags
            for arg in "$@"; do
                case "$arg" in
                    --prefix|--global|--global-style)
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
            
            # Set safe npm environment
            export NPM_CONFIG_PREFIX="$HOME/.npm-global"
            export NPM_CONFIG_USERCONFIG="$HOME/.npmrc"
            ;;
        "uninstall"|"remove"|"rm")
            # Check for global uninstall attempts
            if [[ "$*" == *"-g"* ]] || [[ "$*" == *"--global"* ]]; then
                echo "❌ Error: Global NPM uninstalls are not allowed for Guest users"
                echo "   Use: npm uninstall <package> (removes from current project only)"
                
                # Log the attempt
                echo "[$(date)] SECURITY: Guest user attempted global npm uninstall: npm $*" >> /var/log/adminhub/security.log 2>/dev/null || true
                exit 1
            fi
            ;;
        "link"|"unlink")
            echo "❌ Error: NPM link operations are not allowed for Guest users"
            echo "   Linking can create system-wide packages and is restricted for security"
            
            # Log the attempt
            echo "[$(date)] SECURITY: Guest user attempted npm link: npm $*" >> /var/log/adminhub/security.log 2>/dev/null || true
            exit 1
            ;;
        "audit"|"audit-fix"|"fix")
            # Allow audit but warn about global fixes
            if [[ "$*" == *"-g"* ]] || [[ "$*" == *"--global"* ]]; then
                echo "⚠️  Warning: Global audit fixes are restricted for Guest users"
                echo "   Use: npm audit (to check for vulnerabilities)"
                echo "   Use: npm audit fix (to fix local project vulnerabilities)"
                exit 1
            fi
            ;;
        "config")
            # Check for dangerous config operations
            if [[ "$2" == "set" ]] && [[ "$*" == *"prefix"* ]]; then
                echo "❌ Error: NPM prefix configuration is not allowed for Guest users"
                echo "   This could redirect global installations to system directories"
                
                # Log the attempt
                echo "[$(date)] SECURITY: Guest user attempted npm prefix config: npm $*" >> /var/log/adminhub/security.log 2>/dev/null || true
                exit 1
            fi
            ;;
        "run"|"start"|"test"|"build"|"dev"|"serve")
            # Allow common development commands
            ;;
        "list"|"ls"|"outdated"|"view"|"info"|"show"|"search"|"help"|"--help"|"--version"|"-v")
            # Allow read-only operations
            ;;
        *)
            # Log unknown commands for monitoring
            echo "[$(date)] INFO: Guest user used npm command: npm $*" >> /var/log/adminhub/security.log 2>/dev/null || true
            ;;
    esac
    
    # Set safe npm environment for Guest users
    export NPM_CONFIG_PREFIX="$HOME/.npm-global"
    export NPM_CONFIG_USERCONFIG="$HOME/.npmrc"
    export NPM_CONFIG_CACHE="$HOME/.npm"
    
    # Ensure no global installations
    export NPM_CONFIG_GLOBAL=false
    
    # Execute npm with restrictions
    exec "$ACTUAL_NPM" "$@"
else
    # For non-Guest users, execute normally
    exec "$ACTUAL_NPM" "$@"
fi
