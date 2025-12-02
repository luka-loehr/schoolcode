#!/bin/bash
# Copyright (c) 2025 Luka Löhr

# SchoolCode Centralized Logging System (Bash 3.2 Compatible)
# Provides structured logging functions for all SchoolCode scripts

# Guard against multiple sourcing
[[ -n "${_SCHOOLCODE_LOGGING_SOURCED:-}" ]] && return 0
_SCHOOLCODE_LOGGING_SOURCED=1

# Log configuration (only set if not already defined)
: "${LOG_DIR:=/var/log/schoolcode}"
: "${LOG_FILE:=$LOG_DIR/schoolcode.log}"
: "${ERROR_LOG:=$LOG_DIR/schoolcode-error.log}"
: "${SETUP_LOG:=$LOG_DIR/guest-setup.log}"
: "${EVENTS_LOG:=$LOG_DIR/events.json}"
: "${METRICS_LOG:=$LOG_DIR/metrics.json}"

# Ensure log directory exists and check integrity
if [[ $EUID -eq 0 ]]; then
    mkdir -p "$LOG_DIR" 2>/dev/null || true
    chmod 755 "$LOG_DIR" 2>/dev/null || true
    touch "$LOG_FILE" "$ERROR_LOG" "$SETUP_LOG" "$EVENTS_LOG" "$METRICS_LOG" 2>/dev/null || true
    chmod 644 "$LOG_FILE" "$ERROR_LOG" "$SETUP_LOG" "$EVENTS_LOG" "$METRICS_LOG" 2>/dev/null || true
    
    # Initialize JSON files if empty
    [[ ! -s "$EVENTS_LOG" ]] && echo "[]" > "$EVENTS_LOG" 2>/dev/null || true
    [[ ! -s "$METRICS_LOG" ]] && echo "[]" > "$METRICS_LOG" 2>/dev/null || true
    
    # Clean up old install logs on initialization
    cleanup_install_logs 2>/dev/null || true
fi

# Run integrity check (defined later, will run after functions are loaded)
# This is called automatically when the file is sourced

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
    # Use BASH_SOURCE[2] if available, fallback to [1] or [0]
    local src="${BASH_SOURCE[2]:-${BASH_SOURCE[1]:-${BASH_SOURCE[0]:-unknown}}}"
    basename "$src" .sh 2>/dev/null || echo "unknown"
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
    
    # Write to log file - create parent directory and file if needed
    if [[ -n "$log_file" ]]; then
        local log_dir=$(dirname "$log_file")
        if [[ ! -d "$log_dir" ]] && [[ $EUID -eq 0 ]]; then
            mkdir -p "$log_dir" 2>/dev/null || true
        fi
        
        # Try to write, silently skip if no permission (for non-root log viewing)
        { echo "$log_entry" >> "$log_file"; } 2>/dev/null || true
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
    local show_console="true"
    is_quiet && show_console="false"
    write_log "$level" "[GUEST] $message" "$SETUP_LOG" "$color" "$show_console"
    # Also write to main log for visibility
    write_log "$level" "[GUEST] $message" "$LOG_FILE" "" "false"
}

# Operation-specific logging helpers with performance tracking
log_operation_start() {
    local operation="$1"
    local details="${2:-}"
    local msg="[$operation] ===== START ====="
    [[ -n "$details" ]] && msg="$msg $details"
    log_info "$msg"
    
    # Store start time for this operation
    export OPERATION_START_TIME_${operation}=$(date +%s)
    
    # Log structured event
    local event_data='{"operation":"'"$operation"'","status":"started","details":"'"${details:-}"'"}'
    log_event "operation_start" "$event_data" "INFO"
}

log_operation_end() {
    local operation="$1"
    local status="${2:-SUCCESS}"
    local details="${3:-}"
    
    # Calculate duration
    local start_var="OPERATION_START_TIME_${operation}"
    local start_time=${!start_var:-0}
    local end_time=$(date +%s)
    local duration=$((end_time - start_time))
    
    local msg="[$operation] ===== END ($status) ====="
    [[ -n "$details" ]] && msg="$msg $details"
    [[ $duration -gt 0 ]] && msg="$msg (${duration}s)"
    
    if [[ "$status" == "SUCCESS" ]]; then
        log_info "$msg"
    elif [[ "$status" == "FAILED" ]]; then
        log_error "$msg"
    else
        log_warn "$msg"
    fi
    
    # Log metrics
    if [[ $duration -gt 0 ]]; then
        log_metric "${operation}_duration" "$duration" "seconds"
    fi
    
    # Log structured event
    local event_data='{"operation":"'"$operation"'","status":"'"$(echo $status | tr '[:upper:]' '[:lower:]')"'","duration":'"$duration"',"details":"'"${details:-}"'"}'
    log_event "operation_end" "$event_data" "INFO"
    
    # Clean up start time variable
    unset "$start_var"
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

# Function to clean up old install logs
cleanup_install_logs() {
    local log_dir="${LOG_DIR:-/var/log/schoolcode}"
    local max_logs=5
    local max_age_days=7
    
    if [[ ! -d "$log_dir" ]]; then
        return 0
    fi
    
    # Remove logs older than max_age_days
    find "$log_dir" -name "install_*.log" -type f -mtime +"$max_age_days" -delete 2>/dev/null || true
    
    # Keep only the most recent max_logs install logs
    local install_logs=$(ls -t "$log_dir"/install_*.log 2>/dev/null | tail -n +$((max_logs + 1)))
    if [[ -n "$install_logs" ]]; then
        echo "$install_logs" | xargs rm -f 2>/dev/null || true
        log_debug "Cleaned up old install logs"
    fi
}

# Structured logging - log critical events in JSON format
log_event() {
    local event_type="$1"
    local event_data="$2"
    local severity="${3:-INFO}"
    
    local timestamp=$(date -u '+%Y-%m-%dT%H:%M:%SZ')
    local hostname=$(hostname)
    local user=$(whoami)
    
    # Create JSON event
    local json_event=$(cat <<EOF
{
  "timestamp": "$timestamp",
  "type": "$event_type",
  "severity": "$severity",
  "user": "$user",
  "hostname": "$hostname",
  "data": $event_data
}
EOF
)
    
    # Append to events log (with proper JSON array handling)
    if [[ -w "$EVENTS_LOG" ]] 2>/dev/null; then
        local temp_file="${EVENTS_LOG}.tmp"
        if [[ -f "$EVENTS_LOG" ]] && [[ -s "$EVENTS_LOG" ]]; then
            local content=$(cat "$EVENTS_LOG")
            # Check if array is empty []
            if [[ "$content" == "[]" ]]; then
                printf '[\n%s\n]\n' "$json_event" > "$EVENTS_LOG"
            else
                # Remove closing bracket ], add comma, new event, closing bracket
                # Use sed to remove last line (the ]) for macOS compatibility  
                sed '$ d' "$EVENTS_LOG" > "$temp_file"
                printf ',\n%s\n]\n' "$json_event" >> "$temp_file"
                mv "$temp_file" "$EVENTS_LOG"
            fi
        else
            printf '[\n%s\n]\n' "$json_event" > "$EVENTS_LOG"
        fi
    fi
}

# Log metrics for performance tracking
log_metric() {
    local metric_name="$1"
    local metric_value="$2"
    local unit="${3:-}"
    
    local timestamp=$(date -u '+%Y-%m-%dT%H:%M:%SZ')
    
    local json_metric=$(cat <<EOF
{
  "timestamp": "$timestamp",
  "metric": "$metric_name",
  "value": $metric_value,
  "unit": "$unit"
}
EOF
)
    
    if [[ -w "$METRICS_LOG" ]] 2>/dev/null; then
        local temp_file="${METRICS_LOG}.tmp"
        if [[ -f "$METRICS_LOG" ]] && [[ -s "$METRICS_LOG" ]]; then
            local content=$(cat "$METRICS_LOG")
            # Check if array is empty []
            if [[ "$content" == "[]" ]]; then
                printf '[\n%s\n]\n' "$json_metric" > "$METRICS_LOG"
            else
                # Use sed to remove last line (the ]) for macOS compatibility
                sed '$ d' "$METRICS_LOG" > "$temp_file"
                printf ',\n%s\n]\n' "$json_metric" >> "$temp_file"
                mv "$temp_file" "$METRICS_LOG"
            fi
        else
            printf '[\n%s\n]\n' "$json_metric" > "$METRICS_LOG"
        fi
    fi
}

# Filter logs by severity
filter_logs_by_severity() {
    local severity="$1"
    local log_file="${2:-$LOG_FILE}"
    local lines="${3:-100}"
    
    if [[ ! -f "$log_file" ]]; then
        echo "Log file not found: $log_file"
        return 1
    fi
    
    case "$(echo "$severity" | tr '[:lower:]' '[:upper:]')" in
        ERROR|FATAL)
            grep -E "\[(ERROR|FATAL)\]" "$log_file" | tail -n "$lines"
            ;;
        WARN|WARNING)
            grep "\[WARN\]" "$log_file" | tail -n "$lines"
            ;;
        INFO)
            grep "\[INFO\]" "$log_file" | tail -n "$lines"
            ;;
        DEBUG)
            grep "\[DEBUG\]" "$log_file" | tail -n "$lines"
            ;;
        *)
            echo "Unknown severity: $severity"
            echo "Valid options: ERROR, WARN, INFO, DEBUG"
            return 1
            ;;
    esac
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

# Check log file integrity and setup
check_log_integrity() {
    local issues=0
    
    # Check if log directory exists
    if [[ ! -d "$LOG_DIR" ]]; then
        if [[ $EUID -eq 0 ]]; then
            mkdir -p "$LOG_DIR" 2>/dev/null || {
                echo "[WARNING] Cannot create log directory: $LOG_DIR" >&2
                echo "[INFO] Falling back to /tmp for logging" >&2
                export LOG_DIR="/tmp/schoolcode_logs"
                mkdir -p "$LOG_DIR" 2>/dev/null
                ((issues++))
            }
        else
            echo "[WARNING] Log directory does not exist and no root access: $LOG_DIR" >&2
            export LOG_DIR="/tmp/schoolcode_logs"
            mkdir -p "$LOG_DIR" 2>/dev/null
            ((issues++))
        fi
    fi
    
    # Check if log files are writable
    for log_file in "$LOG_FILE" "$ERROR_LOG" "$SETUP_LOG"; do
        if [[ -f "$log_file" ]] && [[ ! -w "$log_file" ]]; then
            echo "[WARNING] Log file not writable: $log_file" >&2
            ((issues++))
        fi
    done
    
    # Check disk space
    if command -v df >/dev/null 2>&1; then
        local available_mb=$(df "$LOG_DIR" 2>/dev/null | awk 'NR==2 {print int($4/1024)}')
        if [[ -n "$available_mb" ]] && [[ $available_mb -lt 10 ]]; then
            echo "[WARNING] Low disk space in log directory: ${available_mb}MB available" >&2
            ((issues++))
        fi
    fi
    
    return $issues
}

# Export functions for use in other scripts
export -f log_debug log_info log_warn log_error log_fatal log_guest
export -f log_operation_start log_operation_end
export -f log_command log_function show_logs clear_logs rotate_logs cleanup_install_logs
export -f log_event log_metric filter_logs_by_severity check_log_integrity
export -f log_silent is_quiet
export -f start_spinner stop_spinner show_step set_total_steps
