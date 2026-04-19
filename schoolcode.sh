#!/bin/bash
# Copyright (c) 2025 Luka Löhr

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly SCRIPT_VERSION="3.0.0"

source "$SCRIPT_DIR/scripts/utils/logging.sh"
source "$SCRIPT_DIR/scripts/utils/ui.sh"
CURRENT_LOG_LEVEL=999

if [[ "${1:-}" != "--help" ]] && [[ "${1:-}" != "-h" ]]; then
    source "$SCRIPT_DIR/scripts/utils/config.sh"
fi

write_status_log() {
    local status="$1"
    local message="${2:-}"
    log_silent "INFO" "[$status] $message"
}

check_root() {
    local command="${1:-}"
    case "$command" in
        --help|-h|--logs|-l)
            return 0
            ;;
    esac

    if [[ $EUID -ne 0 ]]; then
        ui_status fail "This command requires sudo."
        exit 1
    fi
}

extract_install_failure_reason() {
    local error_log="$1"
    local first_error=""

    if [[ ! -s "$error_log" ]]; then
        return 0
    fi

    first_error="$(grep -E '\[ERROR\]|Installation failed' "$error_log" | head -1 || true)"
    if [[ -z "$first_error" ]]; then
        first_error="$(grep -v '^[[:space:]]*$' "$error_log" | head -1 || true)"
    fi

    first_error="${first_error#\[ERROR\] }"
    printf '%s' "$first_error"
}

latest_install_log() {
    ls -t /var/log/schoolcode/install_*.log 2>/dev/null | head -1 || true
}

do_compatibility_check() {
    ui_status run "Checking system compatibility"
    export SCHOOLCODE_QUIET=true
    source "$SCRIPT_DIR/scripts/utils/old_mac_compatibility.sh"
    run_compatibility_check

    local errors warnings
    errors="$(get_compatibility_errors)"
    warnings="$(get_compatibility_warnings)"

    if [[ "$errors" -gt 0 ]]; then
        ui_status fail "System compatibility check failed"
        local issues=()
        while IFS= read -r issue; do
            [[ -n "$issue" ]] && issues+=("$issue")
        done < <(get_compatibility_issues)
        if [[ ${#issues[@]} -gt 0 ]]; then
            ui_section "Issues"
            ui_list fail "${issues[@]}"
        fi
        return 1
    fi

    if [[ "$warnings" -gt 0 ]]; then
        ui_status warn "System compatible with $warnings warning(s)"
    else
        ui_status ok "System compatible"
    fi
}

do_system_repair() {
    ui_status run "Preparing the system"
    export SCHOOLCODE_QUIET=true
    source "$SCRIPT_DIR/scripts/utils/system_repair.sh"
    run_system_repairs

    local repairs
    repairs="$(get_repairs_performed)"
    if [[ "$repairs" -gt 0 ]]; then
        ui_status ok "System prepared with $repairs fix(es)"
    else
        ui_status ok "System ready"
    fi
}

do_install_tools() {
    ui_status run "Installing development tools"

    local capture_file
    capture_file="/tmp/schoolcode_install_capture_$$.log"

    if SCHOOLCODE_QUIET=true "$SCRIPT_DIR/scripts/install.sh" -q >"$capture_file" 2>&1; then
        ui_status ok "Development tools installed"
        rm -f "$capture_file"
        return 0
    fi

    local exit_code=$?
    local reason log_path
    reason="$(extract_install_failure_reason "$capture_file")"
    log_path="$(latest_install_log)"

    ui_status fail "Installation stopped"
    ui_error_summary "Installation failed" "$reason" "$log_path"

    rm -f "$capture_file"
    return "$exit_code"
}

show_status() {
    ui_run_with_spinner \
        "Running system checks" \
        env SCHOOLCODE_QUIET=true "$SCRIPT_DIR/scripts/utils/monitoring.sh" detailed
}

print_log_contents() {
    local path="$1"
    local lines="$2"

    if [[ -f "$path" ]]; then
        tail -n "$lines" "$path"
    else
        printf 'No log file found at %s\n' "$path"
    fi
}

show_logs() {
    local subcommand="${1:-}"
    local lines="${2:-50}"

    case "$subcommand" in
        errors|error)
            ui_header "SchoolCode Logs" "Recent errors"
            print_log_contents "/var/log/schoolcode/schoolcode-error.log" "$lines"
            ;;
        warnings|warn)
            ui_header "SchoolCode Logs" "Recent warnings"
            if [[ -f "/var/log/schoolcode/schoolcode.log" ]]; then
                grep "\[WARN\]" /var/log/schoolcode/schoolcode.log | tail -n "$lines"
            else
                printf 'No SchoolCode log file found.\n'
            fi
            ;;
        install)
            ui_header "SchoolCode Logs" "Latest install log"
            local latest
            latest="$(latest_install_log)"
            if [[ -n "$latest" ]]; then
                printf 'File: %s\n\n' "$latest"
                tail -n "$lines" "$latest"
            else
                printf 'No install log found.\n'
            fi
            ;;
        guest)
            ui_header "SchoolCode Logs" "Guest setup log"
            print_log_contents "/var/log/schoolcode/guest-setup.log" "$lines"
            ;;
        today)
            ui_header "SchoolCode Logs" "Today"
            local today
            today="$(date '+%Y-%m-%d')"
            if [[ -f "/var/log/schoolcode/schoolcode.log" ]]; then
                grep "$today" /var/log/schoolcode/schoolcode.log | tail -n "$lines"
            else
                printf 'No SchoolCode log file found.\n'
            fi
            ;;
        events)
            cat /var/log/schoolcode/events.json 2>/dev/null || printf '[]\n'
            ;;
        metrics)
            cat /var/log/schoolcode/metrics.json 2>/dev/null || printf '[]\n'
            ;;
        tail)
            ui_header "SchoolCode Logs" "Recent activity"
            print_log_contents "/var/log/schoolcode/schoolcode.log" "$lines"
            ;;
        all|"")
            ui_header "SchoolCode v$SCRIPT_VERSION" "Log viewer"
            ui_section "Usage"
            ui_list info \
                "./schoolcode.sh --logs errors 100" \
                "./schoolcode.sh --logs install" \
                "./schoolcode.sh --logs tail 200"
            ui_section "Log types"
            ui_list info \
                "errors" \
                "warnings" \
                "install" \
                "guest" \
                "today" \
                "events" \
                "metrics" \
                "tail"
            ;;
        *)
            ui_status fail "Unknown log type: $subcommand"
            exit 1
            ;;
    esac
}

uninstall_schoolcode_noninteractive() {
    ui_header "SchoolCode v$SCRIPT_VERSION" "Uninstall"
    ui_status run "Removing SchoolCode"
    if "$SCRIPT_DIR/scripts/schoolcode-cli.sh" --force uninstall; then
        ui_status ok "SchoolCode removed"
        return 0
    fi

    ui_status fail "Uninstall failed"
    return 1
}

automatic_mode() {
    ui_header "SchoolCode v$SCRIPT_VERSION" "Shared Mac development environment"

    local failed=false

    if ! do_compatibility_check; then
        failed=true
    fi

    if [[ "$failed" == "false" ]] && ! do_system_repair; then
        failed=true
    fi

    if [[ "$failed" == "false" ]] && ! do_install_tools; then
        failed=true
    fi

    if [[ "$failed" == "true" ]]; then
        write_status_log "error" "SchoolCode installation failed"
        exit 1
    fi

    write_status_log "ready" "SchoolCode installation completed successfully"
    ui_summary "Installation complete" "SchoolCode is ready to test on the Guest account." "ok"
    ui_section "Next steps"
    ui_list info \
        "Log into the Guest account and open Terminal." \
        "Run sudo ./schoolcode.sh --status to verify the install."
}

show_help() {
    ui_header "SchoolCode v$SCRIPT_VERSION" "Admin interface"
    ui_section "Commands"
    ui_list info \
        "sudo ./schoolcode.sh               Install everything" \
        "sudo ./schoolcode.sh --install     Install everything explicitly" \
        "sudo ./schoolcode.sh --uninstall   Remove SchoolCode" \
        "sudo ./schoolcode.sh --status      Show system status" \
        "./schoolcode.sh --logs             View logs" \
        "./schoolcode.sh --help             Show help"
    ui_section "Log viewer"
    ui_list info \
        "./schoolcode.sh --logs errors 100" \
        "./schoolcode.sh --logs install" \
        "./schoolcode.sh --logs tail 200"
}

main() {
    ui_require_runtime
    check_root "${1:-}"

    case "${1:-}" in
        --install|--interactive|"")
            automatic_mode
            ;;
        --uninstall)
            uninstall_schoolcode_noninteractive
            ;;
        --status|-s)
            show_status
            ;;
        --logs|-l)
            show_logs "${2:-}" "${3:-50}"
            ;;
        --help|-h)
            show_help
            ;;
        *)
            ui_status fail "Unknown option: $1"
            printf '\n'
            show_help
            exit 1
            ;;
    esac
}

main "$@"
