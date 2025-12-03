#!/bin/bash
# Copyright (c) 2025 Luka Löhr

# SchoolCode System Monitoring and Health Check Utility (Bash 3.2 Compatible)
# Provides comprehensive monitoring of SchoolCode components and tools

# Source dependencies
SCRIPT_DIR="$(dirname "${BASH_SOURCE[0]}")"
[[ -f "$SCRIPT_DIR/logging.sh" ]] && source "$SCRIPT_DIR/logging.sh"
[[ -f "$SCRIPT_DIR/config.sh" ]] && source "$SCRIPT_DIR/config.sh"

# Ensure Homebrew is in PATH for root users
if [[ $EUID -eq 0 ]]; then
    # Add common Homebrew paths for root detection
    if [[ -d "/opt/homebrew/bin" ]]; then
        export PATH="/opt/homebrew/bin:/opt/homebrew/sbin:$PATH"
    elif [[ -d "/usr/local/bin" ]]; then
        export PATH="/usr/local/bin:/usr/local/sbin:$PATH"
    fi
fi

# Monitoring configuration
HEALTH_CHECK_FILE="/var/log/schoolcode/health-status.json"
METRICS_FILE="/var/log/schoolcode/metrics.json"
ALERTS_FILE="/var/log/schoolcode/alerts.log"
AUTOUPDATE_PLIST="/Library/LaunchDaemons/com.schoolcode.autoupdate.plist"

# Health check status variables (bash 3.2 compatible)
HEALTH_OVERALL="unknown"
HEALTH_ADMIN_TOOLS="unknown"
HEALTH_GUEST_SETUP="unknown"
HEALTH_LAUNCHAGENT="unknown"
HEALTH_LAUNCHDAEMON="unknown"
HEALTH_HOMEBREW="unknown"
HEALTH_PERMISSIONS="unknown"
HEALTH_DISK_SPACE="unknown"

# Human-readable issue messages
HEALTH_ISSUES=""

# Performance metrics variables
METRICS_SETUP_TIME="0"
METRICS_TOOL_COUNT="0"
METRICS_ERROR_COUNT="0"
METRICS_GUEST_LOGINS="0"
METRICS_LAST_CHECK="never"
METRICS_MISSING_TOOLS=""  # Space-separated list of missing tools

# Function to convert to uppercase (bash 3.2 compatible)
to_upper() {
    echo "$1" | tr '[:lower:]' '[:upper:]'
}

# Track issues for status output (bash 3.2 compatible)
add_health_issue() {
    local message="$1"

    if [[ -z "$HEALTH_ISSUES" ]]; then
        HEALTH_ISSUES="• $message"
    else
        HEALTH_ISSUES="$HEALTH_ISSUES\n• $message"
    fi
}

# Function to set health status
set_health_status() {
    local component="$1"
    local status="$2"
    
    case "$component" in
        "overall") HEALTH_OVERALL="$status" ;;
        "schoolcode_tools") HEALTH_SCHOOLCODE_TOOLS="$status" ;;
        "guest_setup") HEALTH_GUEST_SETUP="$status" ;;
        "launchagent") HEALTH_LAUNCHAGENT="$status" ;;
        "launchdaemon") HEALTH_LAUNCHDAEMON="$status" ;;
        "homebrew") HEALTH_HOMEBREW="$status" ;;
        "permissions") HEALTH_PERMISSIONS="$status" ;;
        "disk_space") HEALTH_DISK_SPACE="$status" ;;
    esac
}

# Function to get health status
get_health_status() {
    local component="$1"
    
    case "$component" in
        "overall") echo "$HEALTH_OVERALL" ;;
        "schoolcode_tools") echo "$HEALTH_SCHOOLCODE_TOOLS" ;;
        "guest_setup") echo "$HEALTH_GUEST_SETUP" ;;
        "launchagent") echo "$HEALTH_LAUNCHAGENT" ;;
        "launchdaemon") echo "$HEALTH_LAUNCHDAEMON" ;;
        "homebrew") echo "$HEALTH_HOMEBREW" ;;
        "permissions") echo "$HEALTH_PERMISSIONS" ;;
        "disk_space") echo "$HEALTH_DISK_SPACE" ;;
        *) echo "unknown" ;;
    esac
}

# Function to get status color
get_status_color() {
    case "$1" in
        "healthy") echo '\033[0;32m' ;;
        "degraded") echo '\033[1;33m' ;;
        "unhealthy") echo '\033[0;31m' ;;
        "unknown") echo '\033[0;37m' ;;
        *) echo '\033[0m' ;;
    esac
}

# Function to get system uptime
get_uptime() {
    local uptime_seconds=$(sysctl -n kern.boottime 2>/dev/null | awk '{print $4}' | sed 's/,//')
    local current_time=$(date +%s)
    local uptime=$((current_time - uptime_seconds))
    
    local days=$((uptime / 86400))
    local hours=$(((uptime % 86400) / 3600))
    local minutes=$(((uptime % 3600) / 60))
    
    echo "${days}d ${hours}h ${minutes}m"
}

# Function to check disk space
check_disk_space() {
    local available_mb=$(df / | awk 'NR==2 {print int($4/1024)}')
    local used_percent=$(df / | awk 'NR==2 {print int($5)}' | sed 's/%//')
    local total_gb=$(df -H / | awk 'NR==2 {print $2}')
    
    # Enhanced thresholds for old systems
    local critical_mb=500    # 500MB critical threshold
    local warning_mb=2000    # 2GB warning threshold
    
    log_debug "Disk space: ${used_percent}% used, ${available_mb}MB free of $total_gb"
    
    if [[ $available_mb -lt $critical_mb ]]; then
        set_health_status "disk_space" "unhealthy"
        log_error "Critical: Low disk space - only ${available_mb}MB available (need ${critical_mb}MB minimum)"
        generate_alerts "error" "Critical disk space: ${available_mb}MB free"
        return 1
    elif [[ $available_mb -lt $warning_mb ]] || [[ $used_percent -gt 90 ]]; then
        set_health_status "disk_space" "degraded"
        log_warn "Low disk space: ${available_mb}MB available (${used_percent}% used)"
        generate_alerts "warn" "Low disk space warning: ${available_mb}MB free"
        return 2
    else
        set_health_status "disk_space" "healthy"
        return 0
    fi
}

# Function to check SchoolCode tools
check_schoolcode_tools() {
    local schoolcode_tools_dir=$(get_config "SCHOOLCODE_TOOLS_DIR")
    local tools_working=0
    local tools_total=0
    local missing_tools=""
    
    if [[ ! -d "$schoolcode_tools_dir/bin" ]]; then
        set_health_status "schoolcode_tools" "unhealthy"
        log_error "SchoolCode tools directory missing: $schoolcode_tools_dir/bin"
        return 1
    fi
    
    # Check each configured tool
    local tools_array=($(get_tools_array))
    for tool in "${tools_array[@]}"; do
        ((tools_total++))
        
        local tool_path="$schoolcode_tools_dir/bin/$tool"
        local tool_found=false
        
        # First, check if tool works from schoolcode bin
        if [[ -x "$tool_path" ]]; then
            local test_cmd=$(get_tool_info "$tool" "test_cmd")
            if [[ -n "$test_cmd" ]]; then
                if eval "$tool_path $test_cmd" &>/dev/null; then
                    tool_found=true
                    log_debug "Tool working (schoolcode): $tool"
                fi
            else
                tool_found=true
                log_debug "Tool present (schoolcode): $tool"
            fi
        fi
        
        # If not found in schoolcode bin, check system-wide
        if [[ "$tool_found" == "false" ]]; then
            if command -v "$tool" &>/dev/null; then
                local test_cmd=$(get_tool_info "$tool" "test_cmd")
                if [[ -n "$test_cmd" ]]; then
                    if eval "$tool $test_cmd" &>/dev/null; then
                        tool_found=true
                        log_debug "Tool working (system): $tool"
                    fi
                else
                    tool_found=true
                    log_debug "Tool present (system): $tool"
                fi
            fi
        fi
        
        if [[ "$tool_found" == "true" ]]; then
            ((tools_working++))
        else
            log_warn "Tool not available: $tool"
            missing_tools="$missing_tools $tool"
        fi
    done
    
    METRICS_TOOL_COUNT="$tools_working/$tools_total"
    METRICS_MISSING_TOOLS="${missing_tools# }"  # Trim leading space
    
    if [[ $tools_working -eq $tools_total ]]; then
        set_health_status "schoolcode_tools" "healthy"
        return 0
    elif [[ $tools_working -gt 0 ]]; then
        set_health_status "schoolcode_tools" "degraded"
        return 2
    else
        set_health_status "schoolcode_tools" "unhealthy"
        return 1
    fi
}

# Function to check LaunchAgent
check_launchagent() {
    local plist_file="/Library/LaunchAgents/com.schoolcode.guestsetup.plist"

    if [[ ! -f "$plist_file" ]]; then
        set_health_status "launchagent" "unhealthy"
        log_error "LaunchAgent plist missing: $plist_file"
        add_health_issue "Guest LaunchAgent missing at $plist_file"
        return 1
    fi
    
    # Check if the guest setup script exists and is executable
    if [[ ! -x "/usr/local/bin/guest_setup_auto.sh" ]]; then
        set_health_status "launchagent" "degraded"
        log_warn "Guest setup script missing or not executable"
        add_health_issue "Guest setup script missing at /usr/local/bin/guest_setup_auto.sh"
        return 2
    fi

    # The Guest LaunchAgent is per-user and only loads when a user logs in.
    # It's expected to NOT be loaded when checking from an admin session.
    # We consider it healthy if:
    #   1. The plist file exists
    #   2. The guest setup script exists and is executable
    # It will automatically load when Guest user logs in.
    
    # If running as Guest and it's loaded, report that
    if [[ "$USER" == "Guest" ]]; then
        if launchctl list 2>/dev/null | grep -q "com.schoolcode.guestsetup"; then
            set_health_status "launchagent" "healthy"
            log_debug "LaunchAgent is loaded for Guest user"
            return 0
        fi
    fi
    
    # Otherwise, plist exists + script exists = healthy (will load on Guest login)
    set_health_status "launchagent" "healthy"
    log_debug "LaunchAgent configured correctly (loads on Guest login)"
    return 0
}

# Function to check auto-update LaunchDaemon
check_launchdaemon() {
    local plist_file="$AUTOUPDATE_PLIST"
    local label="com.schoolcode.autoupdate"

    if [[ ! -f "$plist_file" ]]; then
        set_health_status "launchdaemon" "unhealthy"
        log_error "Auto-update LaunchDaemon plist missing: $plist_file"
        add_health_issue "Auto-update LaunchDaemon missing at $plist_file"
        return 1
    fi

    if launchctl list 2>/dev/null | grep -q "$label"; then
        set_health_status "launchdaemon" "healthy"
        log_debug "Auto-update LaunchDaemon is loaded"
        return 0
    else
        set_health_status "launchdaemon" "degraded"
        log_warn "Auto-update LaunchDaemon plist exists but not loaded"
        add_health_issue "Auto-update LaunchDaemon exists but is not loaded ($label)"
        return 2
    fi
}

# Function to check Homebrew
check_homebrew() {
    if ! command -v brew &> /dev/null; then
        set_health_status "homebrew" "unhealthy"
        log_error "Homebrew not installed"
        return 1
    fi
    
    # Run brew doctor to check for issues (it returns 1 even for warnings)
    # If running as root, switch to the regular user to avoid Homebrew warnings
    local doctor_output
    local doctor_exit_code
    
    if [[ $EUID -eq 0 ]]; then
        # Running as root, determine the actual user
        local actual_user
        if [[ -n "$SUDO_USER" ]]; then
            actual_user="$SUDO_USER"
        else
            actual_user=$(stat -f "%Su" /dev/console 2>/dev/null || echo "")
        fi
        
        if [[ -n "$actual_user" && "$actual_user" != "root" ]]; then
            # Run brew doctor as the actual user with proper PATH
            # First, find brew location
            local brew_path=$(which brew 2>/dev/null || echo "/usr/local/bin/brew")
            if [[ ! -x "$brew_path" ]]; then
                brew_path="/opt/homebrew/bin/brew"
            fi
            
            # Run with full path to avoid PATH issues
            doctor_output=$(su - "$actual_user" -c "$brew_path doctor 2>&1")
            doctor_exit_code=$?
        else
            # Fallback to running directly (will show warning)
            doctor_output=$(brew doctor 2>&1)
            doctor_exit_code=$?
        fi
    else
        # Not root, run normally
        doctor_output=$(brew doctor 2>&1)
        doctor_exit_code=$?
    fi
    
    # Check for "ready to brew" (perfect health)
    if echo "$doctor_output" | grep -q "ready to brew"; then
        set_health_status "homebrew" "healthy"
        return 0
    fi
    
    # Define error keywords that indicate actual problems
    local error_keywords="Error:|Failed|broken|corrupted|permission denied|cannot be found|missing|fatal|critical"
    
    # Check if output contains actual errors
    if echo "$doctor_output" | grep -qE "$error_keywords"; then
        set_health_status "homebrew" "unhealthy"
        log_error "Homebrew has critical errors"
        log_debug "Brew doctor output: $doctor_output"
        return 1
    fi
    
    # If brew doctor returned non-zero but no critical errors found
    if [[ $doctor_exit_code -ne 0 ]]; then
        # Common benign warnings to ignore
        local benign_warnings="Unbrewed header files|Unbrewed .pc files|Unbrewed static libraries|Warning: Some installed formulae|Warning: You have unlinked kegs|Warning: Homebrew's \"sbin\" was not found|Warning: A newer Command Line Tools|Warning: Your Command Line Tools|Tier 2 configuration"
        
        # Count warnings vs errors
        local warning_count=$(echo "$doctor_output" | grep -c "Warning:" || true)
        local error_count=$(echo "$doctor_output" | grep -cE "$error_keywords" || true)
        
        # If only warnings and they're known benign ones
        if [[ $error_count -eq 0 ]] && echo "$doctor_output" | grep -qE "$benign_warnings"; then
            set_health_status "homebrew" "healthy"
            log_debug "Homebrew has only benign warnings"
            return 0
        fi
        
        # Otherwise treat as degraded
        set_health_status "homebrew" "degraded"
        log_warn "Homebrew has warnings (exit code: $doctor_exit_code)"
        log_debug "Warning count: $warning_count, Error count: $error_count"
        return 2
    fi
    
    # If we get here, brew doctor succeeded with no output
    set_health_status "homebrew" "healthy"
    return 0
}

# Function to check permissions
check_permissions() {
    local schoolcode_tools_dir=$(get_config "SCHOOLCODE_TOOLS_DIR")
    local permission_issues=0
    
    # Check SchoolCode tools directory permissions
    if [[ -d "$schoolcode_tools_dir" ]]; then
        local perms=$(stat -f "%p" "$schoolcode_tools_dir" 2>/dev/null | tail -c 4)
        if [[ "$perms" != "755" ]]; then
            log_warn "Incorrect permissions on SchoolCode tools directory: $perms"
            ((permission_issues++))
        fi
        
        # Check individual tool permissions
        if [[ -d "$schoolcode_tools_dir/bin" ]]; then
            while IFS= read -r -d '' tool_file; do
                local tool_perms=$(stat -f "%p" "$tool_file" 2>/dev/null | tail -c 4)
                if [[ "$tool_perms" != "755" ]]; then
                    log_warn "Incorrect permissions on tool: $(basename "$tool_file") ($tool_perms)"
                    ((permission_issues++))
                fi
            done < <(find "$schoolcode_tools_dir/bin" -type f -print0 2>/dev/null)
        fi
    fi
    
    # Check Homebrew permissions
    if [[ -d "/opt/homebrew" ]]; then
        local homebrew_readable=true
        find /opt/homebrew/bin -type f -executable 2>/dev/null | head -5 | while read -r file; do
            if [[ ! -r "$file" ]]; then
                homebrew_readable=false
                break
            fi
        done
        
        if [[ "$homebrew_readable" == "false" ]]; then
            log_warn "Homebrew files not readable by all users"
            ((permission_issues++))
        fi
    fi
    
    if [[ $permission_issues -eq 0 ]]; then
        set_health_status "permissions" "healthy"
        return 0
    elif [[ $permission_issues -lt 3 ]]; then
        set_health_status "permissions" "degraded"
        return 2
    else
        set_health_status "permissions" "unhealthy"
        return 1
    fi
}

# Function to check guest setup
check_guest_setup() {
    local setup_script="/usr/local/bin/guest_setup_auto.sh"
    local login_script="/usr/local/bin/guest_login_setup"
    
    if [[ ! -f "$setup_script" ]]; then
        set_health_status "guest_setup" "unhealthy"
        log_error "Guest setup script missing: $setup_script"
        return 1
    fi
    
    if [[ ! -f "$login_script" ]]; then
        set_health_status "guest_setup" "degraded"
        log_warn "Guest login script missing: $login_script"
        return 2
    fi
    
    # Check if scripts are executable
    if [[ -x "$setup_script" && -x "$login_script" ]]; then
        set_health_status "guest_setup" "healthy"
        return 0
    else
        set_health_status "guest_setup" "degraded"
        log_warn "Guest setup scripts not executable"
        return 2
    fi
}

# Function to check system age and update status
check_system_age() {
    log_info "Checking system age and update status..."
    
    local macos_version=$(sw_vers -productVersion 2>/dev/null || echo "0.0")
    local macos_build=$(sw_vers -buildVersion 2>/dev/null || echo "unknown")
    local major_version=$(echo "$macos_version" | cut -d. -f1)
    local minor_version=$(echo "$macos_version" | cut -d. -f2)
    
    # Current macOS is 14.x (Sonoma), so anything below 12.x is old
    if [[ $major_version -lt 11 ]] || [[ $major_version -eq 10 && $minor_version -lt 15 ]]; then
        log_warn "Very old macOS detected: $macos_version"
        log_warn "This system is 4+ years out of date"
        return 2
    elif [[ $major_version -lt 12 ]]; then
        log_info "Older macOS detected: $macos_version"
        return 1
    else
        log_info "macOS $macos_version is reasonably current"
        return 0
    fi
}

# Function to validate system resources
validate_system_resources() {
    log_info "Validating system resources..."
    
    local issues=0
    
    # Check RAM
    local total_ram_bytes=$(sysctl -n hw.memsize 2>/dev/null || echo "0")
    local total_ram_gb=$((total_ram_bytes / 1024 / 1024 / 1024))
    if [[ $total_ram_gb -lt 4 ]]; then
        log_warn "Low RAM: ${total_ram_gb}GB (recommended: 4GB+)"
        ((issues++))
    fi
    
    # Check CPU cores
    local cpu_cores=$(sysctl -n hw.ncpu 2>/dev/null || echo "1")
    if [[ $cpu_cores -lt 2 ]]; then
        log_warn "Limited CPU cores: $cpu_cores"
        ((issues++))
    fi
    
    # Check swap usage (indicates memory pressure)
    local swap_used=$(sysctl -n vm.swapusage 2>/dev/null | grep -oE 'used = [0-9.]+[MG]' | grep -oE '[0-9.]+')
    if [[ -n "$swap_used" ]] && (( $(echo "$swap_used > 1000" | bc -l) )); then
        log_warn "High swap usage detected: ${swap_used}M"
        ((issues++))
    fi
    
    return $issues
}

# Function to run all health checks
run_health_checks() {
    # Suppress verbose logging during checks
    local old_quiet="${SCHOOLCODE_QUIET:-false}"
    export SCHOOLCODE_QUIET=true

    HEALTH_ISSUES=""

    local overall_score=0
    local check_count=0

    # Run individual checks
    check_disk_space; local disk_result=$?
    check_schoolcode_tools; local tools_result=$?
    check_launchagent; local agent_result=$?
    check_launchdaemon; local daemon_result=$?
    check_homebrew; local brew_result=$?
    check_permissions; local perms_result=$?
    check_guest_setup; local guest_result=$?

    # Additional checks for old systems
    check_system_age; local age_result=$?
    validate_system_resources; local resource_result=$?
    
    # Restore logging
    export SCHOOLCODE_QUIET="$old_quiet"

    # Calculate overall health score (including new checks)
    for result in $disk_result $tools_result $agent_result $daemon_result $brew_result $perms_result $guest_result $age_result; do
        case $result in
            0) overall_score=$((overall_score + 100)) ;;  # healthy
            2) overall_score=$((overall_score + 50)) ;;   # degraded
            *) overall_score=$((overall_score + 0)) ;;    # unhealthy
        esac
        ((check_count++))
    done
    
    # Resource validation doesn't affect score but adds warnings
    if [[ $resource_result -gt 0 ]]; then
        log_info "System has $resource_result resource limitations"
    fi
    
    local avg_score=$((overall_score / check_count))
    
    if [[ $avg_score -ge 90 ]]; then
        set_health_status "overall" "healthy"
    elif [[ $avg_score -ge 50 ]]; then
        set_health_status "overall" "degraded"
    else
        set_health_status "overall" "unhealthy"
    fi
    
    METRICS_LAST_CHECK=$(date '+%Y-%m-%d %H:%M:%S')
}

# Function to save health status to file
save_health_status() {
    local status_file="$1"
    
    mkdir -p "$(dirname "$status_file")" 2>/dev/null
    
    cat > "$status_file" << EOF
{
  "timestamp": "$(date -u '+%Y-%m-%dT%H:%M:%SZ')",
  "overall_status": "$(get_health_status overall)",
  "components": {
    "schoolcode_tools": "$(get_health_status schoolcode_tools)",
    "guest_setup": "$(get_health_status guest_setup)",
    "launchagent": "$(get_health_status launchagent)",
    "launchdaemon": "$(get_health_status launchdaemon)",
    "homebrew": "$(get_health_status homebrew)",
    "permissions": "$(get_health_status permissions)",
    "disk_space": "$(get_health_status disk_space)"
  },
  "metrics": {
    "setup_time": "$METRICS_SETUP_TIME",
    "tool_count": "$METRICS_TOOL_COUNT",
    "error_count": "$METRICS_ERROR_COUNT",
    "guest_logins": "$METRICS_GUEST_LOGINS",
    "last_check": "$METRICS_LAST_CHECK"
  },
  "system_info": {
    "hostname": "$(hostname)",
    "macos_version": "$(sw_vers -productVersion 2>/dev/null || echo "unknown")",
    "uptime": "$(get_uptime)",
    "current_user": "$(whoami)"
  }
}
EOF
    
    chmod 644 "$status_file" 2>/dev/null
}

# Function to display health status
show_health_status() {
    local show_details="${1:-false}"
    
    # Compact header
    echo ""
    echo "╭────────────────────────────────────────╮"
    echo "│       SchoolCode System Status         │"
    echo "╰────────────────────────────────────────╯"
    echo ""
    
    # Overall status with icon
    local overall_status=$(get_health_status "overall")
    local overall_icon="✅"
    case "$overall_status" in
        "degraded") overall_icon="⚠️ " ;;
        "unhealthy") overall_icon="❌" ;;
    esac
    local overall_upper=$(to_upper "$overall_status")
    echo -e "  Status: $overall_icon $overall_upper"
    echo ""
    
    # Component status - only show if degraded or unhealthy
    local has_issues=false
    local components="schoolcode_tools guest_setup launchagent launchdaemon homebrew permissions disk_space"
    for component in $components; do
        local status=$(get_health_status "$component")
        if [[ "$status" != "healthy" ]]; then
            has_issues=true
            break
        fi
    done
    
    if [[ "$has_issues" == "true" ]] || [[ "$show_details" == "true" ]]; then
        echo "  Components:"
        for component in $components; do
            local status=$(get_health_status "$component")
            local icon="✅"
            
            case "$status" in
                "degraded") icon="⚠️ " ;;
                "unhealthy") icon="❌" ;;
            esac
            
            # Only show non-healthy components in brief mode
            if [[ "$show_details" == "true" ]] || [[ "$status" != "healthy" ]]; then
                local display_name=$(echo "$component" | sed 's/_/ /g')
                printf "    • %-18s %s\n" "$display_name" "$icon"
            fi
        done
        echo ""
    fi

    if [[ -n "$HEALTH_ISSUES" ]]; then
        echo "  Issues:"
        printf "    %b\n" "$HEALTH_ISSUES"
        echo ""
    fi

    # Metrics - compact
    echo "  Tools: $METRICS_TOOL_COUNT available"
    
    # Show missing tools if any
    if [[ -n "$METRICS_MISSING_TOOLS" ]]; then
        echo "  Missing: $METRICS_MISSING_TOOLS"
    fi
    
    if [[ "$show_details" == "true" ]]; then
        echo "  Uptime: $(get_uptime)"
        echo "  macOS: $(sw_vers -productVersion 2>/dev/null || echo "unknown")"
    fi
    
    echo ""
}

# Function to monitor guest setup performance
monitor_guest_setup() {
    local start_time=$(date +%s)
    
    log_info "Monitoring guest setup performance..."
    
    # Simulate or monitor actual guest setup
    if [[ "$USER" == "Guest" ]]; then
        local setup_script="/usr/local/bin/guest_setup_auto.sh"
        if [[ -f "$setup_script" ]]; then
            bash "$setup_script"
        fi
    fi
    
    local end_time=$(date +%s)
    local setup_duration=$((end_time - start_time))
    
    METRICS_SETUP_TIME="${setup_duration}s"
    log_info "Guest setup completed in ${setup_duration}s"
    
    return 0
}

# Function to generate alerts
generate_alerts() {
    local alert_level="$1"  # info, warn, error
    local message="$2"
    
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo "[$timestamp] [$alert_level] $message" >> "$ALERTS_FILE"
    
    case "$alert_level" in
        "error")
            log_error "ALERT: $message"
            ;;
        "warn")
            log_warn "ALERT: $message"
            ;;
        *)
            log_info "ALERT: $message"
            ;;
    esac
}

# Function to check for issues and generate alerts
check_and_alert() {
    run_health_checks
    
    # Generate alerts based on health status
    local overall_status=$(get_health_status "overall")
    case "$overall_status" in
        "unhealthy")
            generate_alerts "error" "SchoolCode system is unhealthy - immediate attention required"
            ;;
        "degraded")
            generate_alerts "warn" "SchoolCode system is degraded - some components need attention"
            ;;
        "healthy")
            generate_alerts "info" "SchoolCode system is healthy"
            ;;
    esac
    
    # Specific component alerts
    local components="schoolcode_tools guest_setup launchagent launchdaemon homebrew permissions disk_space"
    for component in $components; do
        local status=$(get_health_status "$component")
        case "$status" in
            "unhealthy")
                generate_alerts "error" "Component '$component' is unhealthy"
                ;;
            "degraded")
                generate_alerts "warn" "Component '$component' is degraded"
                ;;
        esac
    done
}

# Function to run continuous monitoring
continuous_monitoring() {
    local interval="${1:-300}"  # 5 minutes default
    
    log_info "Starting continuous monitoring (interval: ${interval}s)"
    
    while true; do
        check_and_alert
        save_health_status "$HEALTH_CHECK_FILE"
        
        log_debug "Health check completed, sleeping for ${interval}s"
        sleep "$interval"
    done
}

# Main monitoring command
case "${1:-status}" in
    "status")
        run_health_checks
        show_health_status "${2:-false}"
        ;;
    "detailed")
        run_health_checks
        show_health_status "true"
        ;;
    "json")
        run_health_checks
        save_health_status "$HEALTH_CHECK_FILE"
        cat "$HEALTH_CHECK_FILE"
        ;;
    "monitor")
        continuous_monitoring "${2:-300}"
        ;;
    "alerts")
        [[ -f "$ALERTS_FILE" ]] && tail -n "${2:-20}" "$ALERTS_FILE" || echo "No alerts found"
        ;;
    "guest")
        monitor_guest_setup
        ;;
    *)
        echo "Usage: $0 {status|detailed|json|monitor [interval]|alerts [lines]|guest}"
        echo ""
        echo "Commands:"
        echo "  status    - Show basic health status"
        echo "  detailed  - Show detailed health status"
        echo "  json      - Output status as JSON"
        echo "  monitor   - Run continuous monitoring"
        echo "  alerts    - Show recent alerts"
        echo "  guest     - Monitor guest setup performance"
        exit 1
        ;;
esac 