#!/bin/bash
# Copyright (c) 2025 Luka Löhr
#
# SchoolCode Installation Script v3.0
# Enhanced with comprehensive error handling, logging, and modularity
#
# Usage: ./install.sh [OPTIONS]
# Options:
#   -h, --help      Show help message
#   -v, --verbose   Enable verbose output
#   -q, --quiet     Suppress non-error output
#   -d, --dry-run   Perform dry run without making changes
#   -f, --force     Force installation without prompts
#   -l, --log PATH  Custom log file path
#   --no-backup     Skip backup creation
#   --prefix PATH   Custom installation prefix (default: /opt/schoolcode)

set -euo pipefail  # Exit on error, undefined variables, and pipe failures

#############################################
# CONFIGURATION SECTION
#############################################

readonly SCRIPT_VERSION="3.0.0"
readonly SCRIPT_NAME=$(basename "$0")
readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

# Installation paths
INSTALL_PREFIX="/opt/schoolcode"
readonly DEFAULT_PREFIX="/opt/schoolcode"
readonly CONFIG_DIR="${INSTALL_PREFIX}/config"
readonly LOG_DIR="/var/log/schoolcode"
readonly BACKUP_DIR="/var/backups/schoolcode"
readonly TEMP_DIR="/tmp/schoolcode_install_$$"

# System requirements
readonly MIN_DISK_SPACE_MB=2048
readonly MIN_MACOS_VERSION="10.14"
readonly REQUIRED_COMMANDS=("curl" "git" "make")

# Colors for output (disabled if not terminal or quiet mode)
if [[ -t 1 ]] && [[ "${NO_COLOR:-}" != "true" ]]; then
    readonly RED='\033[0;31m'
    readonly GREEN='\033[0;32m'
    readonly YELLOW='\033[1;33m'
    readonly BLUE='\033[0;34m'
    readonly MAGENTA='\033[0;35m'
    readonly CYAN='\033[0;36m'
    readonly WHITE='\033[1;37m'
    readonly NC='\033[0m' # No Color
else
    readonly RED=''
    readonly GREEN=''
    readonly YELLOW=''
    readonly BLUE=''
    readonly MAGENTA=''
    readonly CYAN=''
    readonly WHITE=''
    readonly NC=''
fi

#############################################
# GLOBAL VARIABLES
#############################################

# Command line options
VERBOSE=false
QUIET=false
DRY_RUN=false
FORCE=false
NO_BACKUP=false
CUSTOM_LOG_PATH=""
SHOW_HELP=false

# Runtime variables
LOG_FILE=""
BACKUP_CREATED=false
BACKUP_PATH=""
INSTALLATION_COMPLETE=false
ORIGINAL_USER=""
USER_HOME=""
ERRORS_OCCURRED=false

# Dependency versions
HOMEBREW_VERSION=""
PYTHON_VERSION=""
GIT_VERSION=""

#############################################
# LOGGING FUNCTIONS
#############################################

# Initialize logging
init_logging() {
    if [[ -n "$CUSTOM_LOG_PATH" ]]; then
        LOG_FILE="$CUSTOM_LOG_PATH"
    else
        mkdir -p "$LOG_DIR" 2>/dev/null || true
        LOG_FILE="${LOG_DIR}/install_$(date +%Y%m%d_%H%M%S).log"
    fi
    
    # Create log file with header
    {
        echo "=========================================="
        echo "SchoolCode Installation Log"
        echo "Version: $SCRIPT_VERSION"
        echo "Date: $(date)"
        echo "User: $(whoami)"
        echo "System: $(uname -a)"
        echo "=========================================="
    } > "$LOG_FILE" 2>/dev/null || {
        echo "Warning: Could not create log file at $LOG_FILE"
        LOG_FILE="/tmp/schoolcode_install_$$.log"
        echo "Using temporary log file: $LOG_FILE"
    }
}

# Logging function with levels
log() {
    local level="${1:-INFO}"
    shift
    local message="$*"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    
    # Write to log file
    echo "[$timestamp] [$level] $message" >> "$LOG_FILE" 2>/dev/null || true
    
    # Write to console based on verbosity settings
    if [[ "$QUIET" != "true" ]]; then
        case "$level" in
            ERROR)
                echo -e "${RED}❌ $message${NC}" >&2
                ;;
            WARN)
                echo -e "${YELLOW}⚠️  $message${NC}" >&2
                ;;
            SUCCESS)
                echo -e "${GREEN}✅ $message${NC}"
                ;;
            INFO)
                if [[ "$VERBOSE" == "true" ]] || [[ "$level" == "INFO" ]]; then
                    echo -e "${BLUE}ℹ️  $message${NC}"
                fi
                ;;
            DEBUG)
                if [[ "$VERBOSE" == "true" ]]; then
                    echo -e "${CYAN}🔍 $message${NC}"
                fi
                ;;
            *)
                echo "$message"
                ;;
        esac
    fi
}

# Progress indicator
show_progress() {
    local message="$1"
    if [[ "$QUIET" != "true" ]]; then
        echo -ne "${CYAN}⏳ $message...${NC}"
    fi
    log DEBUG "$message"
}

complete_progress() {
    if [[ "$QUIET" != "true" ]]; then
        echo -e " ${GREEN}Done!${NC}"
    fi
}

#############################################
# ERROR HANDLING FUNCTIONS
#############################################

# Error handler
handle_error() {
    local line_num="$1"
    local exit_code="$2"
    ERRORS_OCCURRED=true
    
    log ERROR "Script failed at line $line_num with exit code $exit_code"
    log ERROR "Last command: ${BASH_COMMAND:-unknown}"
    
    if [[ "$DRY_RUN" != "true" ]]; then
        cleanup_on_error
    fi
    
    echo ""
    echo -e "${RED}╔═══════════════════════════════════════╗${NC}"
    echo -e "${RED}║         Installation Failed           ║${NC}"
    echo -e "${RED}╚═══════════════════════════════════════╝${NC}"
    echo ""
    echo "Error occurred at line $line_num (exit code: $exit_code)"
    echo "Check the log file for details: $LOG_FILE"
    
    exit "$exit_code"
}

# Cleanup on error
cleanup_on_error() {
    log INFO "Starting cleanup after error..."
    
    # Remove temporary directory
    if [[ -d "$TEMP_DIR" ]]; then
        log DEBUG "Removing temporary directory: $TEMP_DIR"
        rm -rf "$TEMP_DIR" 2>/dev/null || true
    fi
    
    # Restore from backup if installation was partially complete
    if [[ "$BACKUP_CREATED" == "true" ]] && [[ -n "$BACKUP_PATH" ]]; then
        if prompt_user "Restore system from backup?"; then
            restore_from_backup
        fi
    fi
    
    # Remove partial installation if no backup
    if [[ "$INSTALLATION_COMPLETE" != "true" ]] && [[ -d "$INSTALL_PREFIX" ]]; then
        if prompt_user "Remove partial installation?"; then
            log INFO "Removing partial installation..."
            rm -rf "$INSTALL_PREFIX" 2>/dev/null || true
        fi
    fi
}

# Cleanup on exit
cleanup_on_exit() {
    if [[ "$ERRORS_OCCURRED" != "true" ]]; then
        # Normal cleanup
        if [[ -d "$TEMP_DIR" ]]; then
            rm -rf "$TEMP_DIR" 2>/dev/null || true
        fi
        
        if [[ "$INSTALLATION_COMPLETE" == "true" ]]; then
            log SUCCESS "Installation completed successfully"
        fi
    fi
}

# Set up error traps
trap 'handle_error ${LINENO} $?' ERR
trap cleanup_on_exit EXIT

#############################################
# UTILITY FUNCTIONS
#############################################

# Print usage information
show_help() {
    cat << EOF
${WHITE}SchoolCode Installation Script v${SCRIPT_VERSION}${NC}

${WHITE}USAGE:${NC}
    sudo $SCRIPT_NAME [OPTIONS]

${WHITE}OPTIONS:${NC}
    -h, --help          Show this help message
    -v, --verbose       Enable verbose output
    -q, --quiet         Suppress non-error output
    -d, --dry-run       Perform dry run without making changes
    -f, --force         Force installation without prompts
    -l, --log PATH      Specify custom log file path
    --no-backup         Skip creating backup before installation
    --prefix PATH       Custom installation prefix (default: $DEFAULT_PREFIX)
    --no-color          Disable colored output

${WHITE}EXAMPLES:${NC}
    # Standard installation
    sudo $SCRIPT_NAME

    # Verbose installation with custom prefix
    sudo $SCRIPT_NAME -v --prefix /usr/local/schoolcode

    # Dry run to see what would be installed
    sudo $SCRIPT_NAME -d -v

    # Force installation without prompts
    sudo $SCRIPT_NAME -f

${WHITE}REQUIREMENTS:${NC}
    - macOS $MIN_MACOS_VERSION or later
    - Administrator (sudo) privileges
    - At least ${MIN_DISK_SPACE_MB}MB free disk space
    - Internet connection for downloading components

${WHITE}SUPPORT:${NC}
    Documentation: https://github.com/luka-loehr/SchoolCode
    Issues: https://github.com/luka-loehr/SchoolCode/issues

EOF
}

# Parse command line arguments
parse_arguments() {
    while [[ $# -gt 0 ]]; do
        case "$1" in
            -h|--help)
                SHOW_HELP=true
                shift
                ;;
            -v|--verbose)
                VERBOSE=true
                shift
                ;;
            -q|--quiet)
                QUIET=true
                shift
                ;;
            -d|--dry-run)
                DRY_RUN=true
                shift
                ;;
            -f|--force)
                FORCE=true
                shift
                ;;
            -l|--log)
                CUSTOM_LOG_PATH="$2"
                shift 2
                ;;
            --no-backup)
                NO_BACKUP=true
                shift
                ;;
            --prefix)
                INSTALL_PREFIX="$2"
                shift 2
                ;;
            --no-color)
                NO_COLOR=true
                shift
                ;;
            *)
                echo "Unknown option: $1"
                echo "Use -h or --help for usage information"
                exit 1
                ;;
        esac
    done
}

# Prompt user for confirmation
prompt_user() {
    local message="$1"
    local default="${2:-n}"
    
    if [[ "$FORCE" == "true" ]] || [[ "$DRY_RUN" == "true" ]]; then
        return 0
    fi
    
    local prompt
    if [[ "$default" == "y" ]]; then
        prompt="$message [Y/n]: "
    else
        prompt="$message [y/N]: "
    fi
    
    read -p "$prompt" -n 1 -r response
    echo
    
    if [[ -z "$response" ]]; then
        response="$default"
    fi
    
    [[ "$response" =~ ^[Yy]$ ]]
}

# Check if running as root
check_root() {
    if [[ $EUID -ne 0 ]]; then
        log ERROR "This script must be run with sudo privileges"
        echo "Please run: sudo $SCRIPT_NAME"
        exit 1
    fi
    
    # Get original user who ran sudo
    ORIGINAL_USER="${SUDO_USER:-$(whoami)}"
    if [[ "$ORIGINAL_USER" == "root" ]]; then
        ORIGINAL_USER=$(stat -f "%Su" /dev/console 2>/dev/null || echo "root")
    fi
    
    # Get user home directory securely (macOS compatible)
    if [[ "$(uname)" == "Darwin" ]]; then
        # macOS doesn't have getent, use dscl instead
        USER_HOME=$(dscl . -read /Users/"$ORIGINAL_USER" NFSHomeDirectory 2>/dev/null | awk '{print $2}')
    else
        # Linux/Unix systems
        USER_HOME=$(getent passwd "$ORIGINAL_USER" 2>/dev/null | cut -d: -f6)
    fi
    
    if [[ -z "$USER_HOME" ]]; then
        USER_HOME="/Users/$ORIGINAL_USER"
    fi
    
    log DEBUG "Running as root, original user: $ORIGINAL_USER"
    log DEBUG "User home directory: $USER_HOME"
}

# Verify system requirements
verify_system_requirements() {
    log INFO "Verifying system requirements..."
    
    # Check macOS version
    local macos_version=$(sw_vers -productVersion 2>/dev/null || echo "0.0")
    local major_version=$(echo "$macos_version" | cut -d. -f1)
    local minor_version=$(echo "$macos_version" | cut -d. -f2)
    
    log DEBUG "Detected macOS version: $macos_version"
    
    if [[ $major_version -lt 10 ]] || ([[ $major_version -eq 10 ]] && [[ $minor_version -lt 14 ]]); then
        log ERROR "macOS $MIN_MACOS_VERSION or later is required (found: $macos_version)"
        return 1
    fi
    
    # Check available disk space
    local available_space=$(df /opt 2>/dev/null | awk 'NR==2 {print int($4/1024)}')
    log DEBUG "Available disk space: ${available_space}MB"
    
    if [[ $available_space -lt $MIN_DISK_SPACE_MB ]]; then
        log ERROR "Insufficient disk space. Need ${MIN_DISK_SPACE_MB}MB, have ${available_space}MB"
        return 1
    fi
    
    # Check for required commands
    local missing_commands=()
    for cmd in "${REQUIRED_COMMANDS[@]}"; do
        if ! command -v "$cmd" &>/dev/null; then
            missing_commands+=("$cmd")
        fi
    done
    
    if [[ ${#missing_commands[@]} -gt 0 ]]; then
        log WARN "Missing required commands: ${missing_commands[*]}"
        log INFO "Attempting to install missing dependencies..."
        install_missing_dependencies "${missing_commands[@]}"
    fi
    
    log SUCCESS "System requirements verified"
    return 0
}

# Install missing dependencies
install_missing_dependencies() {
    local deps=("$@")
    
    for dep in "${deps[@]}"; do
        case "$dep" in
            git)
                log INFO "Installing git via xcode-select..."
                if [[ "$DRY_RUN" != "true" ]]; then
                    xcode-select --install 2>/dev/null || true
                fi
                ;;
            curl)
                log ERROR "curl is required but not installed. Please install Xcode Command Line Tools"
                return 1
                ;;
            *)
                log WARN "Don't know how to install $dep"
                ;;
        esac
    done
}

#############################################
# BACKUP AND RESTORE FUNCTIONS
#############################################

# Create backup
create_backup() {
    if [[ "$NO_BACKUP" == "true" ]] || [[ "$DRY_RUN" == "true" ]]; then
        log DEBUG "Skipping backup creation"
        return 0
    fi
    
    log INFO "Creating backup..."
    
    mkdir -p "$BACKUP_DIR" 2>/dev/null || {
        log WARN "Could not create backup directory, skipping backup"
        return 0
    }
    
    BACKUP_PATH="${BACKUP_DIR}/backup_$(date +%Y%m%d_%H%M%S).tar.gz"
    
    # Backup existing installation if it exists
    if [[ -d "$INSTALL_PREFIX" ]]; then
        show_progress "Backing up existing installation"
        tar -czf "$BACKUP_PATH" -C "$(dirname "$INSTALL_PREFIX")" "$(basename "$INSTALL_PREFIX")" 2>/dev/null || {
            log WARN "Could not create backup"
            return 1
        }
        complete_progress
        BACKUP_CREATED=true
        log SUCCESS "Backup created at: $BACKUP_PATH"
    else
        log DEBUG "No existing installation to backup"
    fi
    
    return 0
}

# Restore from backup
restore_from_backup() {
    if [[ ! -f "$BACKUP_PATH" ]]; then
        log ERROR "Backup file not found: $BACKUP_PATH"
        return 1
    fi
    
    log INFO "Restoring from backup..."
    
    # Remove current installation
    if [[ -d "$INSTALL_PREFIX" ]]; then
        rm -rf "$INSTALL_PREFIX" 2>/dev/null || {
            log ERROR "Could not remove current installation"
            return 1
        }
    fi
    
    # Restore backup
    tar -xzf "$BACKUP_PATH" -C "$(dirname "$INSTALL_PREFIX")" 2>/dev/null || {
        log ERROR "Could not restore backup"
        return 1
    }
    
    log SUCCESS "System restored from backup"
    return 0
}

#############################################
# INSTALLATION FUNCTIONS
#############################################

# Check and install Homebrew
check_homebrew() {
    log INFO "Checking Homebrew installation..."
    
    if ! command -v brew &>/dev/null; then
        log ERROR "Homebrew is not installed"
        
        if prompt_user "Install Homebrew now?"; then
            install_homebrew
        else
            log ERROR "Homebrew is required for SchoolCode installation"
            return 1
        fi
    else
        HOMEBREW_VERSION=$(brew --version 2>/dev/null | head -1 | awk '{print $2}')
        log SUCCESS "Homebrew ${HOMEBREW_VERSION} found"
        
        # Run brew doctor to check for issues
        show_progress "Checking Homebrew health"
        local brew_health=$(brew doctor 2>&1 || true)
        complete_progress
        
        # Check for critical issues that require repair
        local needs_repair=false
        if echo "$brew_health" | grep -q "Your system is ready to brew"; then
            log SUCCESS "Homebrew is healthy"
        elif echo "$brew_health" | grep -q "Error\|Broken\|Permission denied\|No such file"; then
            log WARN "Homebrew has critical issues, attempting repair..."
            needs_repair=true
        else
            log INFO "Homebrew has minor warnings but should be functional"
            # Only show warnings in verbose mode
            if [[ "$VERBOSE" == "true" ]]; then
                log DEBUG "Brew doctor output: $brew_health"
            fi
        fi
        
        if [[ "$needs_repair" == "true" ]]; then
            repair_homebrew
        fi
    fi
    
    return 0
}

# Install Homebrew
install_homebrew() {
    log INFO "Installing Homebrew..."
    
    if [[ "$DRY_RUN" == "true" ]]; then
        log DEBUG "Would install Homebrew"
        return 0
    fi
    
    # Download and run Homebrew installer
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)" || {
        log ERROR "Failed to install Homebrew"
        return 1
    }
    
    # Add Homebrew to PATH for Apple Silicon Macs
    if [[ -f "/opt/homebrew/bin/brew" ]]; then
        eval "$(/opt/homebrew/bin/brew shellenv)"
    fi
    
    log SUCCESS "Homebrew installed successfully"
    return 0
}

# Repair Homebrew
repair_homebrew() {
    log INFO "Repairing Homebrew..."
    
    if [[ "$DRY_RUN" == "true" ]]; then
        log DEBUG "Would repair Homebrew"
        return 0
    fi
    
    # Fix permissions
    local brew_prefix=$(brew --prefix 2>/dev/null || echo "/usr/local")
    
    # Run Homebrew's own repair commands
    brew update-reset 2>/dev/null || true
    brew cleanup 2>/dev/null || true
    
    log SUCCESS "Homebrew repair completed"
    return 0
}

# Install Python
install_python() {
    log INFO "Installing Python..."
    
    # First, try to install official Python from python.org
    log INFO "Attempting to install official Python from python.org..."
    if install_python_official; then
        log SUCCESS "Official Python installed successfully"
    else
        log WARN "Could not install official Python, falling back to Homebrew"
        
        # Fall back to Homebrew if official installation fails
        if command -v brew &>/dev/null; then
            show_progress "Installing Python via Homebrew"
            brew install python3 2>/dev/null || {
                log ERROR "Failed to install Python via Homebrew"
                return 1
            }
            complete_progress
        else
            log ERROR "No method available to install Python"
            return 1
        fi
    fi
    
    if [[ "$DRY_RUN" == "true" ]]; then
        log DEBUG "Would install Python"
        return 0
    fi
    
    # Verify Python installation
    if command -v python3 &>/dev/null; then
        PYTHON_VERSION=$(python3 --version 2>/dev/null | awk '{print $2}')
        log SUCCESS "Python ${PYTHON_VERSION} is available"
    else
        log ERROR "Python installation verification failed"
        return 1
    fi
    
    return 0
}

# Install Python from official source
install_python_official() {
    log INFO "Installing Python from python.org..."
    
    # Use Python 3.12.7 (latest stable as of writing)
    local python_version="3.12.7"
    local python_pkg_url="https://www.python.org/ftp/python/${python_version}/python-${python_version}-macos11.pkg"
    local python_pkg="/tmp/python-installer.pkg"
    
    # Check if official Python is already installed
    if [[ -f "/Library/Frameworks/Python.framework/Versions/3.12/bin/python3" ]]; then
        log SUCCESS "Official Python already installed"
        return 0
    fi
    
    # Download Python installer
    show_progress "Downloading Python installer"
    curl -fsSL "$python_pkg_url" -o "$python_pkg" || {
        log ERROR "Failed to download Python installer"
        return 1
    }
    complete_progress
    
    # Install Python
    show_progress "Installing Python"
    installer -pkg "$python_pkg" -target / || {
        log ERROR "Failed to install Python"
        rm -f "$python_pkg"
        return 1
    }
    complete_progress
    
    rm -f "$python_pkg"
    
    # Update PATH for official Python
    export PATH="/Library/Frameworks/Python.framework/Versions/3.12/bin:$PATH"
    
    log SUCCESS "Official Python ${python_version} installed"
    return 0
}

# Set up SchoolCode tools
setup_schoolcode_tools() {
    log INFO "Setting up SchoolCode tools..."
    
    if [[ "$DRY_RUN" == "true" ]]; then
        log DEBUG "Would set up SchoolCode tools"
        return 0
    fi
    
    # Create directory structure
    show_progress "Creating directory structure"
    mkdir -p "$INSTALL_PREFIX"/{bin,lib,config,wrappers,actual/bin,scripts}
    mkdir -p "$CONFIG_DIR"
    complete_progress
    
    # Copy scripts and utilities
    show_progress "Copying scripts and utilities"
    if [[ -d "$SCRIPT_DIR/utils" ]]; then
        cp -r "$SCRIPT_DIR/utils" "$INSTALL_PREFIX/" 2>/dev/null || true
    fi
    if [[ -d "$SCRIPT_DIR/setup" ]]; then
        cp -r "$SCRIPT_DIR/setup" "$INSTALL_PREFIX/" 2>/dev/null || true
    fi
    
    # Copy update and uninstall scripts
    if [[ -f "$SCRIPT_DIR/update.sh" ]]; then
        cp "$SCRIPT_DIR/update.sh" "$INSTALL_PREFIX/scripts/" 2>/dev/null || true
        chmod +x "$INSTALL_PREFIX/scripts/update.sh" 2>/dev/null || true
    fi
    if [[ -f "$SCRIPT_DIR/uninstall.sh" ]]; then
        cp "$SCRIPT_DIR/uninstall.sh" "$INSTALL_PREFIX/scripts/" 2>/dev/null || true
        chmod +x "$INSTALL_PREFIX/scripts/uninstall.sh" 2>/dev/null || true
    fi
    
    # Copy version file
    if [[ -f "$PROJECT_ROOT/version.txt" ]]; then
        cp "$PROJECT_ROOT/version.txt" "$INSTALL_PREFIX/" 2>/dev/null || true
    fi
    
    complete_progress
    
    # Create symlinks for tools
    create_tool_symlinks
    
    # Set up security wrappers
    setup_security_wrappers
    
    # Configure pip
    configure_pip
    
    log SUCCESS "SchoolCode tools set up successfully"
    return 0
}

# Create tool symlinks
create_tool_symlinks() {
    log DEBUG "Creating tool symlinks..."
    
    # First, try to find official Python if installed
    local official_python3=""
    local official_python=""
    local official_pip3=""
    local official_pip=""
    
    # Check for official Python from python.org (usually in /Library/Frameworks)
    if [[ -f "/Library/Frameworks/Python.framework/Versions/Current/bin/python3" ]]; then
        official_python3="/Library/Frameworks/Python.framework/Versions/Current/bin/python3"
        official_python="/Library/Frameworks/Python.framework/Versions/Current/bin/python"
        official_pip3="/Library/Frameworks/Python.framework/Versions/Current/bin/pip3"
        official_pip="/Library/Frameworks/Python.framework/Versions/Current/bin/pip"
        log DEBUG "Found official Python from python.org"
    fi
    
    local tools=("brew" "python" "python3" "pip" "pip3" "git")
    
    # Robust detection for brew and git even when not in PATH under sudo
    local detected_brew=""
    local detected_git=""
    for candidate in /opt/homebrew/bin/brew /usr/local/bin/brew; do
        if [[ -x "$candidate" ]]; then detected_brew="$candidate"; break; fi
    done
    if [[ -z "$detected_brew" ]]; then detected_brew="$(command -v brew 2>/dev/null || true)"; fi
    for candidate in /opt/homebrew/bin/git /usr/local/bin/git; do
        if [[ -x "$candidate" ]]; then detected_git="$candidate"; break; fi
    done
    if [[ -z "$detected_git" ]]; then detected_git="$(command -v git 2>/dev/null || true)"; fi
    
    for tool in "${tools[@]}"; do
        local tool_path=""
        
        # Use official Python if available
        case "$tool" in
            python3)
                if [[ -n "$official_python3" ]] && [[ -f "$official_python3" ]]; then
                    tool_path="$official_python3"
                else
                    tool_path=$(which python3 2>/dev/null || true)
                fi
                ;;
            python)
                # For 'python' command, prefer the unversioned python if it exists,
                # otherwise fall back to python3 (which is the modern standard)
                if [[ -n "$official_python" ]] && [[ -f "$official_python" ]]; then
                    tool_path="$official_python"
                elif [[ -n "$official_python3" ]] && [[ -f "$official_python3" ]]; then
                    # Use python3 as python (modern Python 3 is the standard)
                    tool_path="$official_python3"
                else
                    tool_path=$(which python 2>/dev/null || which python3 2>/dev/null || true)
                fi
                ;;
            pip3)
                if [[ -n "$official_pip3" ]] && [[ -f "$official_pip3" ]]; then
                    tool_path="$official_pip3"
                else
                    tool_path=$(which pip3 2>/dev/null || true)
                fi
                ;;
            pip)
                if [[ -n "$official_pip" ]] && [[ -f "$official_pip" ]]; then
                    tool_path="$official_pip"
                elif [[ -n "$official_pip3" ]] && [[ -f "$official_pip3" ]]; then
                    # Fallback to pip3 if pip doesn't exist
                    tool_path="$official_pip3"
                else
                    tool_path=$(which pip 2>/dev/null || which pip3 2>/dev/null || true)
                fi
                ;;
            brew)
                tool_path="$detected_brew"
                ;;
            git)
                tool_path="$detected_git"
                ;;
            *)
                tool_path=$(command -v "$tool" 2>/dev/null || true)
                ;;
        esac
        
        if [[ -n "$tool_path" ]]; then
            # Create actual symlink (always points to the real executable)
            ln -sf "$tool_path" "$INSTALL_PREFIX/actual/bin/$tool" 2>/dev/null || true
            
            # Create wrapper or direct symlink
            if [[ "$tool" == "brew" ]] || [[ "$tool" == "pip" ]] || [[ "$tool" == "pip3" ]]; then
                # These tools get security wrappers
                ln -sf "$INSTALL_PREFIX/wrappers/$tool" "$INSTALL_PREFIX/bin/$tool" 2>/dev/null || true
            else
                # Direct symlink for other tools
                ln -sf "$tool_path" "$INSTALL_PREFIX/bin/$tool" 2>/dev/null || true
            fi
            
            log DEBUG "Created symlink for $tool -> $tool_path"
        else
            # Create fallback symlinks for missing tools
            case "$tool" in
                python)
                    # If python doesn't exist, link it to python3
                    if [[ -L "$INSTALL_PREFIX/bin/python3" ]] || [[ -f "$INSTALL_PREFIX/bin/python3" ]]; then
                        ln -sf "$INSTALL_PREFIX/bin/python3" "$INSTALL_PREFIX/bin/python" 2>/dev/null || true
                        log DEBUG "Created fallback symlink: python -> python3"
                    else
                        log WARN "Tool not found: $tool"
                    fi
                    ;;
                pip)
                    # If pip doesn't exist, create wrapper that redirects to pip3
                    if [[ -f "$INSTALL_PREFIX/wrappers/pip3" ]]; then
                        ln -sf "$INSTALL_PREFIX/wrappers/pip3" "$INSTALL_PREFIX/bin/pip" 2>/dev/null || true
                        log DEBUG "Created fallback symlink: pip -> pip3 wrapper"
                    else
                        log WARN "Tool not found: $tool"
                    fi
                    ;;
                *)
                    log WARN "Tool not found: $tool"
                    ;;
            esac
        fi
    done
}

# Set up security wrappers
setup_security_wrappers() {
    log DEBUG "Setting up security wrappers..."
    
    # Create brew wrapper
    cat > "$INSTALL_PREFIX/wrappers/brew" << 'EOF'
#!/bin/bash
# Homebrew wrapper for Guest users - blocks system modifications

# Find the actual brew executable dynamically
find_actual_brew() {
    # Check symlink first
    if [[ -L "/opt/schoolcode/actual/bin/brew" ]]; then
        local target=$(readlink "/opt/schoolcode/actual/bin/brew")
        if [[ -x "$target" ]]; then
            echo "$target"
            return
        fi
    fi
    
    # Search common locations
    local brew_locations=(
        "/opt/homebrew/bin/brew"
        "/usr/local/bin/brew"
        "/usr/local/Homebrew/bin/brew"
    )
    
    for location in "${brew_locations[@]}"; do
        if [[ -x "$location" ]]; then
            echo "$location"
            return
        fi
    done
    
    # Fallback to which
    which brew 2>/dev/null || echo ""
}

ACTUAL_BREW=$(find_actual_brew)

if [[ -z "$ACTUAL_BREW" ]]; then
    echo "❌ Error: Homebrew not found" >&2
    exit 1
fi

# Check if running as Guest
if [[ "$USER" == "Guest" ]]; then
    # Block dangerous commands
    case "$1" in
        install|uninstall|upgrade|update|tap|untap|link|unlink|pin|unpin|reinstall|remove|rm|cleanup)
            echo "❌ Error: System-wide modifications are not allowed for Guest users" >&2
            echo "   Command '$1' has been blocked for security reasons" >&2
            exit 1
            ;;
        *)
            # Allow safe read-only commands
            exec "$ACTUAL_BREW" "$@"
            ;;
    esac
else
    # Non-guest users get full access
    exec "$ACTUAL_BREW" "$@"
fi
EOF
    
    chmod 755 "$INSTALL_PREFIX/wrappers/brew"
    
    # Create pip wrapper for both pip and pip3
    for pip_cmd in pip pip3; do
        cat > "$INSTALL_PREFIX/wrappers/$pip_cmd" << EOF
#!/bin/bash
# Pip wrapper for Guest users - forces user installations

# Find actual pip - check multiple locations
find_actual_pip() {
    # Check for official Python pip first
    if [[ -x "/Library/Frameworks/Python.framework/Versions/Current/bin/$pip_cmd" ]]; then
        echo "/Library/Frameworks/Python.framework/Versions/Current/bin/$pip_cmd"
        return
    fi
    
    # Check symlink in actual/bin
    if [[ -L "/opt/schoolcode/actual/bin/$pip_cmd" ]]; then
        local target=\$(readlink "/opt/schoolcode/actual/bin/$pip_cmd")
        if [[ -x "\$target" ]]; then
            echo "\$target"
            return
        fi
    fi
    
    # Fallback to which
    which $pip_cmd 2>/dev/null || which ${pip_cmd%3}3 2>/dev/null || echo ""
}

ACTUAL_PIP=\$(find_actual_pip)

if [[ -z "\$ACTUAL_PIP" ]] || [[ ! -x "\$ACTUAL_PIP" ]]; then
    # Try the alternate version (pip vs pip3)
    if [[ "$pip_cmd" == "pip" ]]; then
        ACTUAL_PIP=\$(which pip3 2>/dev/null || echo "")
    else
        ACTUAL_PIP=\$(which pip 2>/dev/null || echo "")
    fi
    
    if [[ -z "\$ACTUAL_PIP" ]] || [[ ! -x "\$ACTUAL_PIP" ]]; then
        echo "❌ Error: $pip_cmd not found" >&2
        exit 1
    fi
fi

# Force user installation for Guest users
if [[ "\$USER" == "Guest" ]]; then
    exec "\$ACTUAL_PIP" --user "\$@"
else
    exec "\$ACTUAL_PIP" "\$@"
fi
EOF
        chmod 755 "$INSTALL_PREFIX/wrappers/$pip_cmd"
    done
    
    log DEBUG "Security wrappers created"
}

# Configure pip
configure_pip() {
    log DEBUG "Configuring pip..."
    
    # Create pip configuration for Guest users
    local pip_config="/opt/schoolcode/config/pip.conf"
    
    cat > "$pip_config" << 'EOF'
[global]
user = true
no-warn-script-location = true
disable-pip-version-check = true

[install]
user = true
EOF
    
    log DEBUG "Pip configuration created"
}

# Configure PATH for users
configure_user_path() {
    log INFO "Configuring PATH for users..."
    
    if [[ "$DRY_RUN" == "true" ]]; then
        log DEBUG "Would configure user PATH"
        return 0
    fi
    
    local path_export="export PATH=\"$INSTALL_PREFIX/bin:\$PATH\""
    
    # Update shell configuration files for the original user
    for shell_config in ".zshrc" ".bashrc" ".bash_profile"; do
        local config_file="$USER_HOME/$shell_config"
        
        if [[ -f "$config_file" ]]; then
            # Check if PATH is already configured
            if ! grep -q "$INSTALL_PREFIX/bin" "$config_file"; then
                {
                    echo ""
                    echo "# SchoolCode Tools (added by installer)"
                    echo "$path_export"
                } >> "$config_file"
                log DEBUG "Updated $shell_config"
            else
                log DEBUG "$shell_config already configured"
            fi
        fi
    done
    
    # Create system-wide configuration for Guest users
    create_guest_configuration
    
    log SUCCESS "PATH configuration completed"
    return 0
}

# Create Guest user configuration
create_guest_configuration() {
    log DEBUG "Creating Guest user configuration..."
    
    # Create LaunchAgent for Guest setup
    local plist_file="/Library/LaunchAgents/com.schoolcode.guestsetup.plist"
    
    cat > "$plist_file" << EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>com.schoolcode.guestsetup</string>
    <key>ProgramArguments</key>
    <array>
        <string>/usr/local/bin/guest_setup_auto.sh</string>
    </array>
    <key>RunAtLoad</key>
    <true/>
    <key>StandardOutPath</key>
    <string>/tmp/schoolcode_guest_setup.log</string>
    <key>StandardErrorPath</key>
    <string>/tmp/schoolcode_guest_setup.err</string>
</dict>
</plist>
EOF
    
    # Create guest setup script
    cat > /usr/local/bin/guest_setup_auto.sh << 'EOF'
#!/bin/bash
# Guest user setup script for SchoolCode

if [[ "$USER" == "Guest" ]]; then
    # Add SchoolCode to PATH
    export PATH="/opt/schoolcode/bin:$PATH"
    
    # Set up pip configuration
    export PIP_CONFIG_FILE="/opt/schoolcode/config/pip.conf"
    
    # Create temporary workspace
    mkdir -p "$HOME/SchoolCode"
    cd "$HOME/SchoolCode"
    
    # Display welcome message
    echo "========================================="
    echo "     🚀 SchoolCode Guest Setup 🚀"
    echo "========================================="
    echo ""
    echo "Development tools are ready to use!"
    echo "Available commands:"
    echo "  • python3 - Python programming"
    echo "  • pip3    - Python package manager"
    echo "  • git     - Version control"
    echo "  • brew    - Package manager (read-only)"
    echo ""
    echo "Happy coding! 🎉"
fi
EOF
    
    chmod 755 /usr/local/bin/guest_setup_auto.sh
    
    # Load LaunchAgent
    launchctl load "$plist_file" 2>/dev/null || true
    
    log DEBUG "Guest configuration created"
}

#############################################
# VERIFICATION FUNCTIONS
#############################################

# Verify installation
verify_installation() {
    log INFO "Verifying installation..."
    
    local verification_failed=false
    local tools_checked=0
    local tools_working=0
    
    # Check directory structure
    for dir in "$INSTALL_PREFIX" "$INSTALL_PREFIX/bin" "$INSTALL_PREFIX/wrappers"; do
        if [[ -d "$dir" ]]; then
            log DEBUG "Directory exists: $dir"
        else
            log ERROR "Directory missing: $dir"
            verification_failed=true
        fi
    done
    
    # Check tools
    local tools=("python3" "pip3" "git" "brew")
    
    echo ""
    echo "Tool Status:"
    echo "────────────────────"
    
    for tool in "${tools[@]}"; do
        tools_checked=$((tools_checked + 1))
        local tool_path="$INSTALL_PREFIX/bin/$tool"
        
        if [[ -e "$tool_path" ]]; then
            # Test if tool works
            if "$tool_path" --version &>/dev/null 2>&1; then
                echo "  ✅ $tool: Working"
                tools_working=$((tools_working + 1))
                log DEBUG "$tool is working"
            else
                echo "  ⚠️  $tool: Installed but not working"
                log WARN "$tool is not working properly"
            fi
        else
            echo "  ❌ $tool: Not found"
            log ERROR "$tool not found at $tool_path"
            verification_failed=true
        fi
    done
    
    echo ""
    echo "Installation Summary:"
    echo "────────────────────"
    echo "  Tools checked: $tools_checked"
    echo "  Tools working: $tools_working"
    echo "  Installation directory: $INSTALL_PREFIX"
    echo "  Log file: $LOG_FILE"
    
    if [[ "$verification_failed" == "true" ]]; then
        log WARN "Installation completed with warnings"
        return 1
    else
        log SUCCESS "Installation verified successfully"
        return 0
    fi
}

#############################################
# MAIN EXECUTION
#############################################

main() {
    # Parse command line arguments
    parse_arguments "$@"
    
    # Show help if requested
    if [[ "$SHOW_HELP" == "true" ]]; then
        show_help
        exit 0
    fi
    
    # Initialize logging
    init_logging
    
    # Print header
    echo ""
    echo -e "${BLUE}╔═══════════════════════════════════════╗${NC}"
    echo -e "${BLUE}║   SchoolCode Installation v${SCRIPT_VERSION}    ║${NC}"
    echo -e "${BLUE}╚═══════════════════════════════════════╝${NC}"
    echo ""
    
    if [[ "$DRY_RUN" == "true" ]]; then
        echo -e "${YELLOW}Running in DRY RUN mode - no changes will be made${NC}"
        echo ""
    fi
    
    # Start installation process
    log INFO "Starting SchoolCode installation..."
    log INFO "Installation prefix: $INSTALL_PREFIX"
    
    # Verify we're running as root
    check_root
    
    # Verify system requirements
    verify_system_requirements || {
        log ERROR "System requirements not met"
        exit 1
    }
    
    # Create backup if needed
    create_backup
    
    # Check and install Homebrew
    check_homebrew || {
        log ERROR "Homebrew setup failed"
        exit 1
    }
    
    # Install Python
    install_python || {
        log ERROR "Python installation failed"
        exit 1
    }
    
    # Set up SchoolCode tools
    setup_schoolcode_tools || {
        log ERROR "SchoolCode setup failed"
        exit 1
    }
    
    # Configure PATH for users
    configure_user_path
    
    # Mark installation as complete
    INSTALLATION_COMPLETE=true
    
    # Verify installation
    verify_installation
    
    # Print completion message
    echo ""
    echo -e "${GREEN}╔═══════════════════════════════════════╗${NC}"
    echo -e "${GREEN}║    Installation Complete! 🎉          ║${NC}"
    echo -e "${GREEN}╚═══════════════════════════════════════╝${NC}"
    echo ""
    echo "Next steps:"
    echo "  1. Restart your terminal or run: source ~/.zshrc"
    echo "  2. Verify installation: $INSTALL_PREFIX/bin/python3 --version"
    echo "  3. Check system status: sudo $SCRIPT_DIR/schoolcode-cli.sh status"
    echo ""
    echo "Log file: $LOG_FILE"
    
    if [[ "$BACKUP_CREATED" == "true" ]]; then
        echo "Backup saved: $BACKUP_PATH"
    fi
}

# Run main function with all arguments
main "$@"
