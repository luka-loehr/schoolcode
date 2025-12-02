#!/bin/bash
# Copyright (c) 2025 Luka Löhr

# SchoolCode Centralized Logging System (Bash 3.2 Compatible)
# Provides structured logging functions for all SchoolCode scripts

# Log configuration
LOG_DIR="/var/log/schoolcode"
LOG_FILE="$LOG_DIR/schoolcode.log"
ERROR_LOG="$LOG_DIR/schoolcode-error.log"
SETUP_LOG="$LOG_DIR/guest-setup.log"

# Ensure log directory exists
if [[ $EUID -eq 0 ]]; then
    mkdir -p "$LOG_DIR"
    chmod 755 "$LOG_DIR"
    touch "$LOG_FILE" "$ERROR_LOG" "$SETUP_LOG"
    chmod 644 "$LOG_FILE" "$ERROR_LOG" "$SETUP_LOG"
fi

# Color codes for console output
COLOR_RED='\033[0;31m'
COLOR_GREEN='\033[0;32m'
COLOR_YELLOW='\033[1;33m'
COLOR_BLUE='\033[0;34m'
COLOR_PURPLE='\033[0;35m'
COLOR_CYAN='\033[0;36m'
COLOR_NC='\033[0m'

# Log levels
LOG_LEVEL_DEBUG=0
LOG_LEVEL_INFO=1
LOG_LEVEL_WARN=2
LOG_LEVEL_ERROR=3
LOG_LEVEL_FATAL=4

# Current log level (default INFO)
CURRENT_LOG_LEVEL=${SCHOOLCODE_LOG_LEVEL:-1}

# Function to get timestamp
get_timestamp() {
    date '+%Y-%m-%d %H:%M:%S'
}

# Function to get script name
get_script_name() {
    basename "${BASH_SOURCE[2]}" .sh 2>/dev/null || echo "unknown"
}

# Function to get color for level
get_level_color() {
    case "$1" in
        "DEBUG") echo "$COLOR_CYAN" ;;
        "INFO") echo "$COLOR_GREEN" ;;
        "WARN") echo "$COLOR_YELLOW" ;;
        "ERROR") echo "$COLOR_RED" ;;
        "FATAL") echo "$COLOR_RED" ;;
        *) echo "$COLOR_NC" ;;
    esac
}

# Function to get numeric level
get_level_number() {
    case "$1" in
        "DEBUG") echo $LOG_LEVEL_DEBUG ;;
        "INFO") echo $LOG_LEVEL_INFO ;;
        "WARN") echo $LOG_LEVEL_WARN ;;
        "ERROR") echo $LOG_LEVEL_ERROR ;;
        "FATAL") echo $LOG_LEVEL_FATAL ;;
        *) echo $LOG_LEVEL_INFO ;;
    esac
}

# Generic logging function
write_log() {
    local level="$1"
    local message="$2"
    local log_file="$3"
    local color="$4"
    local show_console="${5:-true}"
    
    local timestamp=$(get_timestamp)
    local script_name=$(get_script_name)
    local user=$(whoami)
    
    # Format: [TIMESTAMP] [LEVEL] [SCRIPT] [USER] MESSAGE
    local log_entry="[$timestamp] [$level] [$script_name] [$user] $message"
    
    # Write to log file if writable
    if [[ -w "$log_file" ]] 2>/dev/null; then
        echo "$log_entry" >> "$log_file"
    fi
    
    # Show on console based on log level
    local level_num=$(get_level_number "$level")
    if [[ $level_num -ge $CURRENT_LOG_LEVEL ]] && [[ "$show_console" == "true" ]]; then
        if [[ -n "$color" ]]; then
            echo -e "${color}[$level]${COLOR_NC} $message"
        else
            echo "[$level] $message"
        fi
    fi
}

# Check if quiet mode is enabled
is_quiet() {
    [[ "${SCHOOLCODE_QUIET:-false}" == "true" ]]
}

# Specific logging functions
log_debug() {
    local color=$(get_level_color "DEBUG")
    write_log "DEBUG" "$1" "$LOG_FILE" "$color" "${SCHOOLCODE_DEBUG:-false}"
}

log_info() {
    local color=$(get_level_color "INFO")
    local show_console="true"
    is_quiet && show_console="false"
    write_log "INFO" "$1" "$LOG_FILE" "$color" "$show_console"
}

log_warn() {
    local color=$(get_level_color "WARN")
    local show_console="true"
    is_quiet && show_console="false"
    write_log "WARN" "$1" "$LOG_FILE" "$color" "$show_console"
}

log_error() {
    local color=$(get_level_color "ERROR")
    # Errors always show on console even in quiet mode
    write_log "ERROR" "$1" "$ERROR_LOG" "$color" "true"
    # Also write to main log
    write_log "ERROR" "$1" "$LOG_FILE" "" "false"
}

log_fatal() {
    local color=$(get_level_color "FATAL")
    write_log "FATAL" "$1" "$ERROR_LOG" "$color" "true"
    write_log "FATAL" "$1" "$LOG_FILE" "" "false"
}

# Guest-specific logging (for guest setup operations)
log_guest() {
    local level="$1"
    local message="$2"
    local color=$(get_level_color "$level")
    write_log "$level" "$message" "$SETUP_LOG" "$color"
}

# Function to log command execution
log_command() {
    local cmd="$1"
    local description="$2"
    
    log_debug "Executing: $cmd"
    
    if eval "$cmd" 2>/dev/null; then
        log_info "$description: SUCCESS"
        return 0
    else
        local exit_code=$?
        log_error "$description: FAILED (exit code: $exit_code)"
        return $exit_code
    fi
}

# Function to log function entry/exit
log_function() {
    local func_name="$1"
    local action="$2"  # "enter" or "exit"
    
    if [[ "$action" == "enter" ]]; then
        log_debug "→ Entering function: $func_name"
    else
        log_debug "← Exiting function: $func_name"
    fi
}

# Function to rotate logs
rotate_logs() {
    local max_size=10485760  # 10MB
    
    for log_file in "$LOG_FILE" "$ERROR_LOG" "$SETUP_LOG"; do
        if [[ -f "$log_file" ]] && [[ $(stat -f%z "$log_file" 2>/dev/null || echo 0) -gt $max_size ]]; then
            mv "$log_file" "${log_file}.old"
            touch "$log_file"
            chmod 644 "$log_file"
            log_info "Rotated log file: $log_file"
        fi
    done
}

# Function to show recent logs
show_logs() {
    local lines="${1:-50}"
    local log_type="${2:-all}"
    
    case "$log_type" in
        "error")
            echo "=== Recent Error Logs ==="
            [[ -f "$ERROR_LOG" ]] && tail -n "$lines" "$ERROR_LOG"
            ;;
        "guest")
            echo "=== Recent Guest Setup Logs ==="
            [[ -f "$SETUP_LOG" ]] && tail -n "$lines" "$SETUP_LOG"
            ;;
        "all"|*)
            echo "=== Recent SchoolCode Logs ==="
            [[ -f "$LOG_FILE" ]] && tail -n "$lines" "$LOG_FILE"
            ;;
    esac
}

# Function to clear logs
clear_logs() {
    log_info "Clearing SchoolCode logs"
    > "$LOG_FILE" 2>/dev/null || true
    > "$ERROR_LOG" 2>/dev/null || true
    > "$SETUP_LOG" 2>/dev/null || true
}

# Spinner stubs (not used - schoolcode.sh uses simpler progress)
start_spinner() { :; }
stop_spinner() { :; }
show_step() { :; }
set_total_steps() { :; }

# Silent logging - logs to file only, no console output
log_silent() {
    local level="$1"
    local message="$2"
    local timestamp=$(get_timestamp)
    local script_name=$(get_script_name)
    local user=$(whoami)
    local log_entry="[$timestamp] [$level] [$script_name] [$user] $message"
    
    if [[ -w "$LOG_FILE" ]] 2>/dev/null; then
        echo "$log_entry" >> "$LOG_FILE"
    fi
}

# Export functions for use in other scripts
export -f log_debug log_info log_warn log_error log_fatal log_guest
export -f log_command log_function show_logs clear_logs rotate_logs
export -f log_silent is_quiet
export -f start_spinner stop_spinner show_step set_total_steps 
