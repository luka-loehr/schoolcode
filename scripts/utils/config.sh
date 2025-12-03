#!/bin/bash
# Copyright (c) 2025 Luka Löhr

# SchoolCode Configuration Management System (Bash 3.2 Compatible)
# Centralized configuration for all SchoolCode components

# Source logging if available
[[ -f "${BASH_SOURCE%/*}/logging.sh" ]] && source "${BASH_SOURCE%/*}/logging.sh"

# Configuration file location
CONFIG_DIR="/etc/schoolcode"
CONFIG_FILE="$CONFIG_DIR/schoolcode.conf"
USER_CONFIG_FILE="${HOME:-/var/root}/.schoolcode.conf"

# Default configuration values (bash 3.2 compatible)
DEFAULT_SCHOOLCODE_TOOLS_DIR="/opt/schoolcode"
DEFAULT_GUEST_TOOLS_DIR="/Users/Guest/tools"
DEFAULT_SCRIPTS_DIR="/usr/local/bin"
DEFAULT_LAUNCHAGENT_DIR="/Library/LaunchAgents"
DEFAULT_TOOLS_LIST="brew,python3,python,git,pip3,pip"
DEFAULT_HOMEBREW_TOOLS="git,python"
DEFAULT_SYSTEM_TOOLS="python3,pip3"
DEFAULT_AUTO_INSTALL_MISSING="true"
DEFAULT_OPEN_TERMINAL_ON_LOGIN="true"
DEFAULT_SHOW_WELCOME_MESSAGE="true"
DEFAULT_GUEST_SETUP_TIMEOUT="30"
DEFAULT_LOG_LEVEL="INFO"
DEFAULT_LOG_RETENTION_DAYS="30"
DEFAULT_ENABLE_DEBUG_LOGGING="false"
DEFAULT_ENABLE_TOOL_UPDATES="false"
DEFAULT_ENABLE_METRICS="false"
DEFAULT_ENABLE_REMOTE_CONFIG="false"
DEFAULT_BACKUP_EXISTING_CONFIG="true"
DEFAULT_CONFIRM_DESTRUCTIVE_ACTIONS="true"
DEFAULT_SKIP_HOMEBREW_CHECK="false"
DEFAULT_GUEST_USERNAME="Guest"
DEFAULT_GUEST_SHELL="zsh"
DEFAULT_PRESERVE_GUEST_SETTINGS="false"

# Tool metadata functions (bash 3.2 compatible)
get_tool_description() {
    case "$1" in
        "brew") echo "Homebrew package manager" ;;
        "python3") echo "Python 3 programming language" ;;
        "python") echo "Python programming language" ;;
        "git") echo "Git version control system" ;;
        "pip3") echo "Python 3 package installer" ;;
        "pip") echo "Python package installer" ;;
        *) echo "Development tool" ;;
    esac
}

get_tool_version_cmd() {
    case "$1" in
        "brew") echo "--version" ;;
        "python3") echo "--version" ;;
        "python") echo "--version" ;;
        "git") echo "--version" ;;
        "pip3") echo "--version" ;;
        "pip") echo "--version" ;;
        *) echo "--version" ;;
    esac
}

get_tool_test_cmd() {
    case "$1" in
        "brew") echo "--version" ;;
        "python3") echo "-c 'print(\"OK\")'" ;;
        "python") echo "-c 'print(\"OK\")'" ;;
        "git") echo "--version" ;;
        "pip3") echo "--version" ;;
        "pip") echo "--version" ;;
        *) echo "--version" ;;
    esac
}

# Configuration storage (using files instead of associative arrays)
CONFIG_CACHE_FILE="/tmp/schoolcode_config_cache.$"

# Function to create default config file
create_default_config() {
    local config_file="$1"
    local config_dir=$(dirname "$config_file")
    
    [[ $EUID -eq 0 ]] && mkdir -p "$config_dir" 2>/dev/null
    
    cat > "$config_file" << 'EOF'
# SchoolCode Configuration File
# This file contains settings for the SchoolCode system
# Lines starting with # are comments

# Paths Configuration
SCHOOLCODE_TOOLS_DIR=/opt/schoolcode
GUEST_TOOLS_DIR=/Users/Guest/tools
SCRIPTS_DIR=/usr/local/bin
LAUNCHAGENT_DIR=/Library/LaunchAgents

# Tool Configuration
# Comma-separated list of tools to manage
TOOLS_LIST=brew,python3,python,git,pip3,pip
HOMEBREW_TOOLS=git,python
SYSTEM_TOOLS=python3,pip3

# Behavior Settings
AUTO_INSTALL_MISSING=true
OPEN_TERMINAL_ON_LOGIN=true
SHOW_WELCOME_MESSAGE=true
GUEST_SETUP_TIMEOUT=30

# Logging Configuration
LOG_LEVEL=INFO
LOG_RETENTION_DAYS=30
ENABLE_DEBUG_LOGGING=false

# Feature Flags
ENABLE_TOOL_UPDATES=false
ENABLE_METRICS=false
ENABLE_REMOTE_CONFIG=false

# Installation Behavior
BACKUP_EXISTING_CONFIG=true
CONFIRM_DESTRUCTIVE_ACTIONS=true
SKIP_HOMEBREW_CHECK=false

# Guest User Settings
GUEST_USERNAME=Guest
GUEST_SHELL=zsh
PRESERVE_GUEST_SETTINGS=false
EOF
    
    [[ -f "$config_file" ]] && chmod 644 "$config_file" 2>/dev/null
}

# Function to load configuration into cache
load_config() {
    if declare -f log_function >/dev/null 2>&1; then
        log_function "load_config" "enter" 2>/dev/null || true
    fi
    
    # Start with default values
    cat > "$CONFIG_CACHE_FILE" << EOF
SCHOOLCODE_TOOLS_DIR=$DEFAULT_SCHOOLCODE_TOOLS_DIR
GUEST_TOOLS_DIR=$DEFAULT_GUEST_TOOLS_DIR
SCRIPTS_DIR=$DEFAULT_SCRIPTS_DIR
LAUNCHAGENT_DIR=$DEFAULT_LAUNCHAGENT_DIR
TOOLS_LIST=$DEFAULT_TOOLS_LIST
HOMEBREW_TOOLS=$DEFAULT_HOMEBREW_TOOLS
SYSTEM_TOOLS=$DEFAULT_SYSTEM_TOOLS
AUTO_INSTALL_MISSING=$DEFAULT_AUTO_INSTALL_MISSING
OPEN_TERMINAL_ON_LOGIN=$DEFAULT_OPEN_TERMINAL_ON_LOGIN
SHOW_WELCOME_MESSAGE=$DEFAULT_SHOW_WELCOME_MESSAGE
GUEST_SETUP_TIMEOUT=$DEFAULT_GUEST_SETUP_TIMEOUT
LOG_LEVEL=$DEFAULT_LOG_LEVEL
LOG_RETENTION_DAYS=$DEFAULT_LOG_RETENTION_DAYS
ENABLE_DEBUG_LOGGING=$DEFAULT_ENABLE_DEBUG_LOGGING
ENABLE_TOOL_UPDATES=$DEFAULT_ENABLE_TOOL_UPDATES
ENABLE_METRICS=$DEFAULT_ENABLE_METRICS
ENABLE_REMOTE_CONFIG=$DEFAULT_ENABLE_REMOTE_CONFIG
BACKUP_EXISTING_CONFIG=$DEFAULT_BACKUP_EXISTING_CONFIG
CONFIRM_DESTRUCTIVE_ACTIONS=$DEFAULT_CONFIRM_DESTRUCTIVE_ACTIONS
SKIP_HOMEBREW_CHECK=$DEFAULT_SKIP_HOMEBREW_CHECK
GUEST_USERNAME=$DEFAULT_GUEST_USERNAME
GUEST_SHELL=$DEFAULT_GUEST_SHELL
PRESERVE_GUEST_SETTINGS=$DEFAULT_PRESERVE_GUEST_SETTINGS
EOF
    
    # Load system config if it exists
    if [[ -f "$CONFIG_FILE" ]]; then
        while IFS='=' read -r key value; do
            # Skip comments and empty lines
            [[ "$key" =~ ^[[:space:]]*# ]] && continue
            [[ -z "$key" ]] && continue
            
            # Remove whitespace and quotes
            key=$(echo "$key" | tr -d '[:space:]')
            value=$(echo "$value" | sed 's/^[[:space:]]*//' | sed 's/[[:space:]]*$//' | sed 's/^"//' | sed 's/"$//')
            
            # Update cache
            if [[ -n "$key" ]]; then
                sed -i.bak "s/^$key=.*/$key=$value/" "$CONFIG_CACHE_FILE" 2>/dev/null || true
            fi
        done < "$CONFIG_FILE"
        
        if declare -f log_debug >/dev/null 2>&1; then
            log_debug "Loaded system config from $CONFIG_FILE" 2>/dev/null || true
        fi
    fi
    
    # Load user config if it exists (overrides system config)
    if [[ -f "$USER_CONFIG_FILE" ]]; then
        while IFS='=' read -r key value; do
            [[ "$key" =~ ^[[:space:]]*# ]] && continue
            [[ -z "$key" ]] && continue
            
            key=$(echo "$key" | tr -d '[:space:]')
            value=$(echo "$value" | sed 's/^[[:space:]]*//' | sed 's/[[:space:]]*$//' | sed 's/^"//' | sed 's/"$//')
            
            if [[ -n "$key" ]]; then
                sed -i.bak "s/^$key=.*/$key=$value/" "$CONFIG_CACHE_FILE" 2>/dev/null || true
            fi
        done < "$USER_CONFIG_FILE"
        
        if declare -f log_debug >/dev/null 2>&1; then
            log_debug "Loaded user config from $USER_CONFIG_FILE" 2>/dev/null || true
        fi
    fi
    
    if declare -f log_function >/dev/null 2>&1; then
        log_function "load_config" "exit" 2>/dev/null || true
    fi
}

# Function to get configuration value
get_config() {
    local key="$1"
    local default_value="${2:-}"
    
    # Load config if cache doesn't exist
    [[ ! -f "$CONFIG_CACHE_FILE" ]] && load_config
    
    # Get value from cache
    local value=$(grep "^$key=" "$CONFIG_CACHE_FILE" 2>/dev/null | cut -d'=' -f2-)
    
    if [[ -n "$value" ]]; then
        echo "$value"
    elif [[ -n "$default_value" ]]; then
        echo "$default_value"
    else
        # Fallback to default values
        case "$key" in
            "SCHOOLCODE_TOOLS_DIR") echo "$DEFAULT_SCHOOLCODE_TOOLS_DIR" ;;
            "GUEST_TOOLS_DIR") echo "$DEFAULT_GUEST_TOOLS_DIR" ;;
            "SCRIPTS_DIR") echo "$DEFAULT_SCRIPTS_DIR" ;;
            "TOOLS_LIST") echo "$DEFAULT_TOOLS_LIST" ;;
            *) echo "" ;;
        esac
    fi
}

# Function to set configuration value
set_config() {
    local key="$1"
    local value="$2"
    local scope="${3:-user}"  # "user" or "system"
    
    # Load config if cache doesn't exist
    [[ ! -f "$CONFIG_CACHE_FILE" ]] && load_config
    
    # Update cache
    sed -i.bak "s/^$key=.*/$key=$value/" "$CONFIG_CACHE_FILE" 2>/dev/null || echo "$key=$value" >> "$CONFIG_CACHE_FILE"
    
    # Determine which file to update
    local target_file
    if [[ "$scope" == "system" && $EUID -eq 0 ]]; then
        target_file="$CONFIG_FILE"
    else
        target_file="$USER_CONFIG_FILE"
    fi
    
    # Create config file if it doesn't exist
    if [[ ! -f "$target_file" ]]; then
        create_default_config "$target_file"
    fi
    
    # Update or add the configuration value
    if grep -q "^$key=" "$target_file" 2>/dev/null; then
        # Update existing value
        sed -i.bak "s/^$key=.*/$key=$value/" "$target_file"
    else
        # Add new value
        echo "$key=$value" >> "$target_file"
    fi
    
    if declare -f log_info >/dev/null 2>&1; then
        log_info "Updated configuration: $key=$value (scope: $scope)" 2>/dev/null || true
    fi
}

# Function to get tool list as array
get_tools_array() {
    local tools_string=$(get_config "TOOLS_LIST")
    echo "$tools_string" | tr ',' ' '
}

# Function to get tool metadata
get_tool_info() {
    local tool="$1"
    local info_type="$2"  # description, version_cmd, test_cmd
    
    case "$info_type" in
        "description") get_tool_description "$tool" ;;
        "version_cmd") get_tool_version_cmd "$tool" ;;
        "test_cmd") get_tool_test_cmd "$tool" ;;
        *) echo "" ;;
    esac
}

# Function to check if tool is homebrew-managed
is_homebrew_tool() {
    local tool="$1"
    local homebrew_tools=$(get_config "HOMEBREW_TOOLS")
    
    case ",$homebrew_tools," in
        *",$tool,"*) return 0 ;;
        *) return 1 ;;
    esac
}

# Function to validate configuration
validate_config() {
    local errors=0
    
    # Check required paths exist or can be created
    local schoolcode_tools_dir=$(get_config "SCHOOLCODE_TOOLS_DIR")
    if [[ ! -d "$schoolcode_tools_dir" && $EUID -eq 0 ]]; then
        mkdir -p "$schoolcode_tools_dir" 2>/dev/null || {
            if declare -f log_error >/dev/null 2>&1; then
                log_error "Cannot create SchoolCode tools directory: $schoolcode_tools_dir"
            fi
            ((errors++))
        }
    fi
    
    # Validate boolean values
    local bool_configs="AUTO_INSTALL_MISSING OPEN_TERMINAL_ON_LOGIN SHOW_WELCOME_MESSAGE ENABLE_DEBUG_LOGGING ENABLE_TOOL_UPDATES ENABLE_METRICS BACKUP_EXISTING_CONFIG CONFIRM_DESTRUCTIVE_ACTIONS"
    
    for config_key in $bool_configs; do
        local value=$(get_config "$config_key")
        if [[ "$value" != "true" && "$value" != "false" ]]; then
            if declare -f log_warn >/dev/null 2>&1; then
                log_warn "Invalid boolean value for $config_key: $value (using default)"
            fi
            case "$config_key" in
                "AUTO_INSTALL_MISSING") set_config "$config_key" "$DEFAULT_AUTO_INSTALL_MISSING" ;;
                "OPEN_TERMINAL_ON_LOGIN") set_config "$config_key" "$DEFAULT_OPEN_TERMINAL_ON_LOGIN" ;;
                "SHOW_WELCOME_MESSAGE") set_config "$config_key" "$DEFAULT_SHOW_WELCOME_MESSAGE" ;;
                "ENABLE_DEBUG_LOGGING") set_config "$config_key" "$DEFAULT_ENABLE_DEBUG_LOGGING" ;;
                "ENABLE_TOOL_UPDATES") set_config "$config_key" "$DEFAULT_ENABLE_TOOL_UPDATES" ;;
                "ENABLE_METRICS") set_config "$config_key" "$DEFAULT_ENABLE_METRICS" ;;
                "BACKUP_EXISTING_CONFIG") set_config "$config_key" "$DEFAULT_BACKUP_EXISTING_CONFIG" ;;
                "CONFIRM_DESTRUCTIVE_ACTIONS") set_config "$config_key" "$DEFAULT_CONFIRM_DESTRUCTIVE_ACTIONS" ;;
            esac
        fi
    done
    
    # Validate numeric values
    local timeout=$(get_config "GUEST_SETUP_TIMEOUT")
    if ! [[ "$timeout" =~ ^[0-9]+$ ]]; then
        if declare -f log_warn >/dev/null 2>&1; then
            log_warn "Invalid timeout value: $timeout (using default)"
        fi
        set_config "GUEST_SETUP_TIMEOUT" "$DEFAULT_GUEST_SETUP_TIMEOUT"
    fi
    
    return $errors
}

# Function to show current configuration
show_config() {
    echo "╔═══════════════════════════════════════╗"
    echo "║        SchoolCode Configuration         ║"
    echo "╚═══════════════════════════════════════╝"
    echo ""
    
    echo "📁 Paths:"
    echo "  SchoolCode Tools: $(get_config 'SCHOOLCODE_TOOLS_DIR')"
    echo "  Guest Tools: $(get_config 'GUEST_TOOLS_DIR')"
    echo "  Scripts:     $(get_config 'SCRIPTS_DIR')"
    echo ""
    
    echo "🔧 Tools:"
    echo "  Managed:   $(get_config 'TOOLS_LIST')"
    echo "  Homebrew:  $(get_config 'HOMEBREW_TOOLS')"
    echo "  System:    $(get_config 'SYSTEM_TOOLS')"
    echo ""
    
    echo "⚙️  Behavior:"
    echo "  Auto Install:    $(get_config 'AUTO_INSTALL_MISSING')"
    echo "  Open Terminal:   $(get_config 'OPEN_TERMINAL_ON_LOGIN')"
    echo "  Welcome Msg:     $(get_config 'SHOW_WELCOME_MESSAGE')"
    echo "  Setup Timeout:   $(get_config 'GUEST_SETUP_TIMEOUT')s"
    echo ""
    
    echo "📝 Logging:"
    echo "  Level:     $(get_config 'LOG_LEVEL')"
    echo "  Debug:     $(get_config 'ENABLE_DEBUG_LOGGING')"
    echo "  Retention: $(get_config 'LOG_RETENTION_DAYS') days"
    echo ""
}

# Function to reset configuration to defaults
reset_config() {
    local scope="${1:-user}"
    
    if [[ "$scope" == "system" ]]; then
        [[ $EUID -eq 0 ]] && create_default_config "$CONFIG_FILE"
    else
        create_default_config "$USER_CONFIG_FILE"
    fi
    
    # Clear cache to force reload
    rm -f "$CONFIG_CACHE_FILE"
    load_config
    
    if declare -f log_info >/dev/null 2>&1; then
        log_info "Configuration reset to defaults (scope: $scope)"
    fi
}

# Cleanup function
cleanup_config() {
    rm -f "$CONFIG_CACHE_FILE" "$CONFIG_CACHE_FILE.bak" 2>/dev/null
}

# Set trap to cleanup cache file
trap cleanup_config EXIT

# Initialize configuration on source
load_config

# Export configuration functions
export -f get_config set_config get_tools_array get_tool_info is_homebrew_tool
export -f validate_config show_config reset_config 