#!/bin/bash
# Make wrapper - blocks dangerous make commands for Guest users
# AdminHub - Version 2.1.0

# Check if running as Guest
if [[ "$USER" == "Guest" ]]; then
    # Check for dangerous make targets
    case "$1" in
        "install"|"uninstall"|"clean"|"distclean"|"maintainer-clean")
            echo "❌ Error: Make '$1' is not allowed for Guest users"
            echo ""
            echo "   Guest users cannot use make install/uninstall for security reasons."
            echo "   This prevents system-wide modifications and ensures"
            echo "   a clean environment for all users."
            echo ""
            echo "   Use the appropriate package manager instead:"
            echo "   • pip install --user <package>     (for Python packages)"
            echo "   • npm install <package>            (for Node.js packages)"
            echo "   • Contact administrator for system packages"
            
            # Log the attempt
            echo "[$(date)] SECURITY: Guest user attempted make $1: make $*" >> /var/log/adminhub/security.log 2>/dev/null || true
            exit 1
            ;;
        "all"|"build"|"compile"|"test"|"check"|"help"|"--help"|"--version"|"-v")
            # Allow safe make targets
            ;;
        *)
            # Check if any argument contains dangerous patterns
            for arg in "$@"; do
                if [[ "$arg" == *"install"* ]] || [[ "$arg" == *"uninstall"* ]]; then
                    echo "❌ Error: Make targets containing 'install' or 'uninstall' are not allowed for Guest users"
                    echo ""
                    echo "   Guest users cannot use make install/uninstall for security reasons."
                    echo "   This prevents system-wide modifications and ensures"
                    echo "   a clean environment for all users."
                    
                    # Log the attempt
                    echo "[$(date)] SECURITY: Guest user attempted dangerous make target: make $*" >> /var/log/adminhub/security.log 2>/dev/null || true
                    exit 1
                fi
            done
            ;;
    esac
    
    # Execute make with restrictions
    exec /usr/bin/make "$@"
else
    # For non-Guest users, execute normally
    exec /usr/bin/make "$@"
fi
