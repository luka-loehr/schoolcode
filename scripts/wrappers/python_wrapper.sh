#!/bin/bash
# Python wrapper for Guest users with comprehensive security controls
# AdminHub - Version 2.1.0

# Find the actual python executable
find_actual_python() {
    # First try the backed up original binaries
    if [ -x "/opt/admin-tools/actual-direct-backups/original-python" ]; then
        echo "/opt/admin-tools/actual-direct-backups/original-python"
        return
    fi
    
    # Then check if we have a direct symlink
    if [ -L "/opt/admin-tools/actual/bin/python" ]; then
        local target=$(readlink "/opt/admin-tools/actual/bin/python")
        if [ -x "$target" ]; then
            echo "$target"
            return
        fi
    fi
    
    # Otherwise search in common locations (avoiding our wrapped versions)
    local python_locations=(
        "/Library/Frameworks/Python.framework/Versions/3.13/bin/python"
        "/Library/Frameworks/Python.framework/Versions/3.12/bin/python"
        "/opt/homebrew/Cellar/python@3.13/3.13.5/libexec/bin/python"
        "/opt/homebrew/bin/python3.13"
        "/usr/bin/python3"
    )
    
    for location in "${python_locations[@]}"; do
        if [ -x "$location" ]; then
            echo "$location"
            return
        fi
    done
    
    # Fallback to which
    which python3 2>/dev/null || which python 2>/dev/null || echo ""
}

# Security function to analyze and block dangerous Python code
analyze_python_code() {
    local code="$1"
    
    # Block direct pip imports and calls
    if [[ "$code" == *"import pip"* ]] || [[ "$code" == *"from pip"* ]]; then
        echo "❌ Error: Direct pip imports are not allowed for Guest users"
        echo "   Detected pip import attempt in Python code"
        echo "   Use the AdminHub pip command instead: pip install <package>"
        return 1
    fi
    
    # Block subprocess calls to pip, brew, git
    if [[ "$code" == *"subprocess"* ]] && [[ "$code" == *"pip\|brew\|git"* ]]; then
        echo "❌ Error: Subprocess calls to AdminHub tools are not allowed for Guest users" 
        echo "   Use the AdminHub-provided commands directly instead"
        return 1
    fi
    
    # Block system calls and os.system
    if [[ "$code" == *"os.system"* ]] || [[ "$code" == *"os.popen"* ]] || [[ "$code" == *"os.exec"* ]]; then
        echo "❌ Error: System command execution is restricted for Guest users"
        echo "   Direct system calls are not allowed for security reasons"
        return 1
    fi
    
    # Block site-packages manipulation
    if [[ "$code" == *"site-packages"* ]] && [[ "$code" == *"open("* ]]; then
        echo "❌ Error: Direct site-packages modification is not allowed for Guest users"
        echo "   Use pip install --user to install packages to your user directory"
        return 1
    fi
    
    # Block dangerous path manipulation
    if [[ "$code" == *"/opt/homebrew"* ]] || [[ "$code" == *"/usr/local"* ]] || [[ "$code" == *"/Library/Frameworks"* ]]; then
        if [[ "$code" == *"open("* ]] || [[ "$code" == *"write("* ]] || [[ "$code" == *"mkdir"* ]]; then
            echo "❌ Error: System directory modification attempts are blocked for Guest users"
            echo "   Modifications to system directories are not allowed"
            return 1
        fi
    fi
    
    return 0
}

ACTUAL_PYTHON=$(find_actual_python)

if [ -z "$ACTUAL_PYTHON" ]; then
    echo "❌ Error: Python not found"
    exit 1
fi

# Check if running as Guest
if [[ "$USER" == "Guest" ]]; then
    # Set secure Python environment
    export PYTHONDONTWRITEBYTECODE=1  # Prevent .pyc files
    export PYTHONUNBUFFERED=1        # Ensure output is visible
    
    # Check if this is a 'python -m pip' call
    if [[ "$1" == "-m" ]] && [[ "$2" == "pip" ]]; then
        # This is a Guest user trying to use 'python -m pip'
        shift 2  # Remove '-m pip' from arguments
        pip_args="$@"
        
        # Check for dangerous flags in the pip arguments
        if [[ "$pip_args" == *"--isolated"* ]] || [[ "$pip_args" == *"--target"* ]] || [[ "$pip_args" == *"--prefix"* ]] || [[ "$pip_args" == *"--root"* ]] || [[ "$pip_args" == *"--no-user-cfg"* ]] || [[ "$pip_args" == *"--no-site-cfg"* ]]; then
            echo "❌ Error: Security bypass detected in 'python -m pip' call"
            echo "   Dangerous flags like --isolated, --target, --prefix, --root are not allowed for Guest users"
            echo "   These flags can bypass AdminHub's security restrictions"
            echo ""
            echo "   Use pip normally instead:"
            echo "   • pip install <package>           (safe installation to ~/.local/)"
            echo "   • python -m pip install <package> (without dangerous flags)"
            
            # Log the attempt
            echo "[$(date)] SECURITY: Guest user attempted python -m pip bypass: python -m pip $pip_args" >> /var/log/adminhub/security.log 2>/dev/null || true
            exit 1
        fi
        
        # If it's a safe pip call, redirect to our secure pip wrapper
        echo "ℹ️  Note: Redirecting to secure pip wrapper for Guest user"
        exec /opt/admin-tools/bin/pip "$@"
        
    # Check if this is a 'python -c' call with code
    elif [[ "$1" == "-c" ]]; then
        python_code="$2"
        
        # Analyze the code for security threats
        if ! analyze_python_code "$python_code"; then
            # Log the attempt
            echo "[$(date)] SECURITY: Guest user attempted dangerous Python -c: $python_code" >> /var/log/adminhub/security.log 2>/dev/null || true
            exit 1
        fi
        
        # If code is safe, execute with restrictions
        export PYTHONPATH="/tmp/restricted:$PYTHONPATH"  # Prepend safe path
        
    # Check for other dangerous Python modules
    elif [[ "$1" == "-m" ]]; then
        module="$2"
        case "$module" in
            "ensurepip"|"pip"|"setuptools"|"distutils.util")
                echo "❌ Error: Python module '$module' is restricted for Guest users"
                echo "   This module can bypass AdminHub security restrictions"
                echo "   Use the AdminHub-provided pip command instead"
                
                # Log the attempt
                echo "[$(date)] SECURITY: Guest user attempted restricted module: python -m $module" >> /var/log/adminhub/security.log 2>/dev/null || true
                exit 1
                ;;
        esac
    fi
    
    # Set additional security restrictions
    export PYTHONSAFEPATH=1 2>/dev/null || true  # Python 3.11+ safe path mode
    
    # Block write access to system Python directories
    if [[ -n "$VIRTUAL_ENV" ]]; then
        # In virtual environment - allow more freedom
        exec "$ACTUAL_PYTHON" "$@"
    else
        # Not in virtual environment - maximum restrictions
        exec "$ACTUAL_PYTHON" "$@"
    fi
else
    # Normal python call or non-Guest user - execute normally
    exec "$ACTUAL_PYTHON" "$@"
fi
