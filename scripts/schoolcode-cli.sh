#!/bin/bash
# Copyright (c) 2025 Luka Löhr

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
readonly SCRIPT_VERSION="3.0.0"

source "$SCRIPT_DIR/utils/logging.sh"
source "$SCRIPT_DIR/utils/config.sh"
source "$SCRIPT_DIR/utils/ui.sh"
CURRENT_LOG_LEVEL=999

COMMAND=""
SUBCOMMAND=""
OPTIONS=()
VERBOSE=false
DRY_RUN=false
FORCE=false
NO_REPAIR=false

show_help() {
    ui_header "SchoolCode CLI v$SCRIPT_VERSION" "Administrative command interface"
    ui_section "Commands"
    ui_list info \
        "install                 Install SchoolCode" \
        "install-auto            Alias for install" \
        "install-interactive     Alias for install" \
        "uninstall               Remove SchoolCode" \
        "status                  Show system status" \
        "health                  Run health checks" \
        "monitor                 Alias for health continuous" \
        "repair                  Repair prerequisites" \
        "compatibility           Check macOS compatibility" \
        "config                  Manage configuration" \
        "tools                   Manage tools" \
        "guest                   Guest account operations" \
        "logs                    View or clear logs" \
        "permissions             Check or fix permissions"
    ui_section "Examples"
    ui_list info \
        "$0 status detailed" \
        "$0 logs error 50" \
        "$0 repair" \
        "$0 guest setup"
}

show_version() {
    ui_header "SchoolCode CLI v$SCRIPT_VERSION" "Version"
    ui_key_value "macOS" "$(sw_vers -productVersion 2>/dev/null || echo unknown)"
    ui_key_value "Hostname" "$(hostname)"
    ui_key_value "User" "$(whoami)"
    ui_key_value "Location" "$SCRIPT_DIR"
}

parse_args() {
    while [[ $# -gt 0 ]]; do
        case "$1" in
            -v|--verbose)
                VERBOSE=true
                export SCHOOLCODE_LOG_LEVEL=0
                shift
                ;;
            -q|--quiet)
                export SCHOOLCODE_UI_MODE=plain
                export SCHOOLCODE_LOG_LEVEL=3
                shift
                ;;
            --dry-run)
                DRY_RUN=true
                shift
                ;;
            --force)
                FORCE=true
                shift
                ;;
            --no-repair)
                NO_REPAIR=true
                shift
                ;;
            -h|--help)
                show_help
                exit 0
                ;;
            --version)
                show_version
                exit 0
                ;;
            -*)
                ui_status fail "Unknown option: $1"
                exit 1
                ;;
            *)
                if [[ -z "$COMMAND" ]]; then
                    COMMAND="$1"
                elif [[ -z "$SUBCOMMAND" ]]; then
                    SUBCOMMAND="$1"
                else
                    OPTIONS+=("$1")
                fi
                shift
                ;;
        esac
    done

    case "$COMMAND" in
        install-auto|install-interactive)
            COMMAND="install"
            SUBCOMMAND="full"
            ;;
        monitor)
            COMMAND="health"
            SUBCOMMAND="continuous"
            ;;
    esac
}

require_root() {
    if [[ $EUID -ne 0 ]]; then
        ui_status fail "This operation requires administrator privileges."
        exit 1
    fi
}

confirm_operation() {
    local message="$1"

    if [[ "$FORCE" == "true" ]] || [[ "$DRY_RUN" == "true" ]]; then
        return 0
    fi

    ui_confirm "$message"
}

cmd_install() {
    require_root

    case "$SUBCOMMAND" in
        ""|"full")
            if [[ "$DRY_RUN" == "true" ]]; then
                ui_status info "Would run: $PROJECT_ROOT/schoolcode.sh --install"
                return 0
            fi

            exec "$PROJECT_ROOT/schoolcode.sh" --install
            ;;
        "tools")
            ui_header "SchoolCode CLI" "Tool installation"
            ui_status run "Installing tools only"
            if [[ "$DRY_RUN" == "false" ]]; then
                SCHOOLCODE_CLI_INSTALL=true SCHOOLCODE_QUIET=true bash "$SCRIPT_DIR/install.sh"
            fi
            ui_status ok "Tool installation finished"
            ;;
        "agent")
            ui_header "SchoolCode CLI" "Guest LaunchAgent"
            ui_status run "Installing Guest shell agent"
            if [[ "$DRY_RUN" == "false" ]]; then
                SCHOOLCODE_QUIET=true bash "$SCRIPT_DIR/setup/setup_guest_shell_init.sh"
            fi
            ui_status ok "Guest shell agent installed"
            ;;
        *)
            ui_status fail "Unknown install subcommand: $SUBCOMMAND"
            exit 1
            ;;
    esac
}

cmd_uninstall() {
    require_root
    confirm_operation "Remove all SchoolCode components from this Mac?" || exit 0

    ui_header "SchoolCode CLI" "Uninstall"
    ui_status run "Removing SchoolCode"
    if [[ "$DRY_RUN" == "false" ]]; then
        SCHOOLCODE_CLI_UNINSTALL=true SCHOOLCODE_QUIET=true bash "$SCRIPT_DIR/uninstall.sh"
    fi
    ui_status ok "SchoolCode removed"
    ui_summary "Uninstall complete" "Homebrew and its packages were left intact." "info"
}

cmd_status() {
    case "$SUBCOMMAND" in
        ""|"brief")
            ui_run_with_spinner \
                "Running system checks" \
                bash "$SCRIPT_DIR/utils/monitoring.sh" status
            ;;
        "detailed")
            ui_run_with_spinner \
                "Running system checks" \
                bash "$SCRIPT_DIR/utils/monitoring.sh" detailed
            ;;
        "json")
            SCHOOLCODE_UI_MODE=plain bash "$SCRIPT_DIR/utils/monitoring.sh" json
            ;;
        *)
            ui_status fail "Unknown status subcommand: $SUBCOMMAND"
            exit 1
            ;;
    esac
}

cmd_health() {
    case "$SUBCOMMAND" in
        ""|"basic")
            ui_run_with_spinner \
                "Running health checks" \
                bash "$SCRIPT_DIR/utils/monitoring.sh" status
            ;;
        "detailed")
            ui_run_with_spinner \
                "Running health checks" \
                bash "$SCRIPT_DIR/utils/monitoring.sh" detailed
            ;;
        "continuous")
            local interval="${OPTIONS[0]:-300}"
            ui_header "SchoolCode CLI" "Continuous health monitoring"
            ui_status info "Polling every ${interval}s"
            bash "$SCRIPT_DIR/utils/monitoring.sh" monitor "$interval"
            ;;
        *)
            ui_status fail "Unknown health subcommand: $SUBCOMMAND"
            exit 1
            ;;
    esac
}

cmd_repair() {
    require_root
    local repair_script="$PROJECT_ROOT/scripts/utils/system_repair.sh"

    case "$SUBCOMMAND" in
        ""|"system")
            ui_header "SchoolCode CLI" "System repair"
            ui_status run "Repairing prerequisites"
            if [[ "$DRY_RUN" == "false" ]]; then
                [[ -f "$repair_script" ]] || { ui_status fail "System repair script not found"; exit 1; }
                SCHOOLCODE_QUIET=true bash "$repair_script"
            fi
            ui_status ok "System repair completed"
            ;;
        "xcode")
            ui_header "SchoolCode CLI" "Xcode command line tools"
            ui_status run "Repairing Xcode command line tools"
            if [[ "$DRY_RUN" == "false" ]]; then
                [[ -f "$repair_script" ]] || { ui_status fail "System repair script not found"; exit 1; }
                bash -c "source '$repair_script'; check_and_repair_xcode_clt"
            fi
            ui_status ok "Xcode command line tools repair completed"
            ;;
        *)
            ui_status fail "Unknown repair subcommand: $SUBCOMMAND"
            exit 1
            ;;
    esac
}

cmd_compatibility() {
    local checker="$PROJECT_ROOT/scripts/utils/old_mac_compatibility.sh"

    case "$SUBCOMMAND" in
        ""|"check")
            [[ -f "$checker" ]] || { ui_status fail "Compatibility checker not found"; exit 1; }
            exec bash "$checker"
            ;;
        "report")
            [[ -f "$checker" ]] || { ui_status fail "Compatibility checker not found"; exit 1; }
            bash "$checker"
            ui_status info "Compatibility report completed"
            ;;
        *)
            ui_status fail "Unknown compatibility subcommand: $SUBCOMMAND"
            exit 1
            ;;
    esac
}

cmd_config() {
    case "$SUBCOMMAND" in
        "show")
            ui_header "SchoolCode CLI" "Configuration"
            show_config
            ;;
        "edit")
            local config_file
            config_file="$(get_config "USER_CONFIG_FILE" "$HOME/.schoolcode.conf")"
            ${EDITOR:-nano} "$config_file"
            ui_status ok "Configuration opened"
            ;;
        "reset")
            local scope="${OPTIONS[0]:-user}"
            confirm_operation "Reset configuration to defaults for scope '$scope'?" || exit 0
            if [[ "$DRY_RUN" == "false" ]]; then
                reset_config "$scope"
            fi
            ui_status ok "Configuration reset"
            ;;
        "validate")
            if validate_config; then
                ui_status ok "Configuration is valid"
            else
                ui_status fail "Configuration validation failed"
                exit 1
            fi
            ;;
        "set")
            if [[ ${#OPTIONS[@]} -lt 2 ]]; then
                ui_status fail "Usage: $0 config set <key> <value> [scope]"
                exit 1
            fi
            local key="${OPTIONS[0]}"
            local value="${OPTIONS[1]}"
            local scope="${OPTIONS[2]:-user}"
            if [[ "$DRY_RUN" == "false" ]]; then
                set_config "$key" "$value" "$scope"
            fi
            ui_status ok "Set $key for scope $scope"
            ;;
        *)
            ui_status fail "Unknown config subcommand: $SUBCOMMAND"
            exit 1
            ;;
    esac
}

cmd_tools() {
    case "$SUBCOMMAND" in
        "list")
            ui_header "SchoolCode CLI" "Configured tools"
            local tools_array=()
            read -r -a tools_array <<<"$(get_tools_array)"
            if [[ ${#tools_array[@]} -eq 0 ]]; then
                ui_status warn "No tools configured"
                return 0
            fi
            local tool
            for tool in "${tools_array[@]}"; do
                ui_key_value "$tool" "$(get_tool_info "$tool" description)"
            done
            ;;
        "versions")
            ui_header "SchoolCode CLI" "Tool versions"
            local tools_array=()
            read -r -a tools_array <<<"$(get_tools_array)"
            local tool
            for tool in "${tools_array[@]}"; do
                local version_cmd
                version_cmd="$(get_tool_info "$tool" version_cmd)"
                local version="unknown"
                if command -v "$tool" >/dev/null 2>&1; then
                    version="$(eval "$tool $version_cmd" 2>/dev/null | head -1 || echo unknown)"
                fi
                ui_key_value "$tool" "$version"
            done
            ;;
        "install")
            require_root
            local tool="${OPTIONS[0]:-}"
            [[ -n "$tool" ]] || { ui_status fail "Usage: $0 tools install <tool>"; exit 1; }
            ui_header "SchoolCode CLI" "Tool installation"
            if is_homebrew_tool "$tool"; then
                ui_status run "Installing $tool"
                [[ "$DRY_RUN" == "true" ]] || brew install "$tool"
                ui_status ok "$tool installed"
            else
                ui_status warn "$tool is not managed by Homebrew"
            fi
            ;;
        *)
            ui_status fail "Unknown tools subcommand: $SUBCOMMAND"
            exit 1
            ;;
    esac
}

cmd_guest() {
    case "$SUBCOMMAND" in
        "status"|"test")
            ui_run_with_spinner \
                "Inspecting Guest environment" \
                bash "$SCRIPT_DIR/utils/monitoring.sh" guest
            ;;
        "setup")
            ui_header "SchoolCode CLI" "Guest setup"
            ui_status run "Configuring the Guest environment"
            if [[ "$DRY_RUN" == "false" ]]; then
                if [[ $EUID -eq 0 ]]; then
                    SCHOOLCODE_QUIET=true bash "$SCRIPT_DIR/setup/setup_guest_shell_init.sh"
                else
                    bash "$SCRIPT_DIR/guest_setup_auto.sh"
                fi
            fi
            ui_status ok "Guest setup completed"
            ;;
        "cleanup")
            if [[ "$USER" != "Guest" ]]; then
                ui_status warn "Run guest cleanup from the Guest account."
                return 0
            fi
            local guest_tools_dir
            guest_tools_dir="$(get_config "GUEST_TOOLS_DIR")"
            confirm_operation "Remove Guest tools at $guest_tools_dir?" || exit 0
            [[ "$DRY_RUN" == "true" ]] || rm -rf "$guest_tools_dir"
            ui_status ok "Guest tools cleaned up"
            ;;
        *)
            ui_status fail "Unknown guest subcommand: $SUBCOMMAND"
            exit 1
            ;;
    esac
}

cmd_logs() {
    case "$SUBCOMMAND" in
        ""|"all")
            exec "$PROJECT_ROOT/schoolcode.sh" --logs "${SUBCOMMAND:-all}" "${OPTIONS[0]:-50}"
            ;;
        "error"|"guest"|"install"|"today"|"warnings"|"warn"|"metrics"|"events")
            exec "$PROJECT_ROOT/schoolcode.sh" --logs "$SUBCOMMAND" "${OPTIONS[0]:-50}"
            ;;
        "alerts")
            SCHOOLCODE_UI_MODE=plain bash "$SCRIPT_DIR/utils/monitoring.sh" alerts "${OPTIONS[0]:-20}"
            ;;
        "clear")
            confirm_operation "Clear all SchoolCode logs?" || exit 0
            [[ "$DRY_RUN" == "true" ]] || clear_logs
            ui_status ok "Logs cleared"
            ;;
        "tail")
            ui_header "SchoolCode CLI" "Live log tail"
            tail -f /var/log/schoolcode/schoolcode.log 2>/dev/null || {
                ui_status fail "Log file is not accessible"
                exit 1
            }
            ;;
        *)
            ui_status fail "Unknown logs subcommand: $SUBCOMMAND"
            exit 1
            ;;
    esac
}

cmd_permissions() {
    require_root
    case "$SUBCOMMAND" in
        ""|"fix")
            ui_header "SchoolCode CLI" "Permissions"
            ui_status run "Fixing permissions"
            [[ "$DRY_RUN" == "true" ]] || bash "$SCRIPT_DIR/utils/fix_homebrew_permissions.sh"
            ui_status ok "Permissions fixed"
            ;;
        "check")
            bash "$SCRIPT_DIR/utils/monitoring.sh" detailed
            ;;
        *)
            ui_status fail "Unknown permissions subcommand: $SUBCOMMAND"
            exit 1
            ;;
    esac
}

main() {
    ui_require_runtime
    parse_args "$@"

    if [[ -z "$COMMAND" ]]; then
        show_help
        exit 0
    fi

    case "$COMMAND" in
        install) cmd_install ;;
        uninstall) cmd_uninstall ;;
        status) cmd_status ;;
        health) cmd_health ;;
        repair) cmd_repair ;;
        compatibility) cmd_compatibility ;;
        config) cmd_config ;;
        tools) cmd_tools ;;
        guest) cmd_guest ;;
        logs) cmd_logs ;;
        permissions) cmd_permissions ;;
        *)
            ui_status fail "Unknown command: $COMMAND"
            exit 1
            ;;
    esac
}

main "$@"
