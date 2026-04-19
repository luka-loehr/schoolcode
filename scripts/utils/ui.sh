#!/bin/bash
# Copyright (c) 2025 Luka Löhr

UI_SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$UI_SCRIPT_DIR/gum.sh"

ui_is_plain() {
    [[ "${SCHOOLCODE_UI_MODE:-auto}" == "plain" ]] && return 0
    [[ ! -t 1 ]] && return 0
    [[ "${TERM:-}" == "dumb" ]] && return 0
    return 1
}

ui_require_runtime() {
    if ui_is_plain; then
        return 0
    fi

    schoolcode_require_gum
}

ui_tone_label() {
    case "$1" in
        info) echo "INFO" ;;
        run) echo "RUN" ;;
        ok) echo "OK" ;;
        warn) echo "WARN" ;;
        fail) echo "FAIL" ;;
        *) echo "INFO" ;;
    esac
}

ui_tone_foreground() {
    case "$1" in
        info) echo "39" ;;
        run) echo "63" ;;
        ok) echo "42" ;;
        warn) echo "214" ;;
        fail) echo "196" ;;
        *) echo "252" ;;
    esac
}

ui_tone_muted() {
    case "$1" in
        info|run) echo "245" ;;
        ok) echo "78" ;;
        warn) echo "221" ;;
        fail) echo "203" ;;
        *) echo "245" ;;
    esac
}

ui_label_block() {
    local tone="${1:-info}"
    local label
    label="$(ui_tone_label "$tone")"

    if ui_is_plain; then
        printf '[%s]' "$label"
        return 0
    fi

    schoolcode_gum style \
        --bold \
        --foreground "255" \
        --background "$(ui_tone_foreground "$tone")" \
        --padding "0 1" \
        " $label "
}

ui_inline_text() {
    local tone="${1:-info}"
    shift
    local text="$*"

    if ui_is_plain; then
        printf '%s' "$text"
        return 0
    fi

    schoolcode_gum style --foreground "$(ui_tone_muted "$tone")" "$text"
}

ui_header() {
    local title="$1"
    local subtitle="${2:-}"

    if ui_is_plain; then
        printf '\n%s\n' "$title"
        if [[ -n "$subtitle" ]]; then
            printf '%s\n' "$subtitle"
        fi
        printf '\n'
        return 0
    fi

    local content="$title"
    if [[ -n "$subtitle" ]]; then
        local subtitle_line
        subtitle_line="$(schoolcode_gum style --foreground "245" "$subtitle")"
        content="$(printf '%s\n%s' "$title" "$subtitle_line")"
    fi

    schoolcode_gum style \
        --border rounded \
        --border-foreground "63" \
        --padding "1 2" \
        --margin "1 0" \
        --bold \
        "$content"
}

ui_section() {
    local title="$1"

    if ui_is_plain; then
        printf '\n%s\n' "$title"
        return 0
    fi

    schoolcode_gum style --bold --foreground "111" --margin "1 0 0 0" "$title"
}

ui_status() {
    local tone="$1"
    shift
    local message="$*"
    local label_block

    label_block="$(ui_label_block "$tone")"

    if ui_is_plain; then
        printf '  %s %s\n' "$label_block" "$message"
        return 0
    fi

    local text_block
    text_block="$(ui_inline_text "$tone" "$message")"
    schoolcode_gum join --horizontal "$label_block" "  $text_block"
}

ui_key_value() {
    local key="$1"
    local value="$2"

    if ui_is_plain; then
        printf '  %-18s %s\n' "$key" "$value"
        return 0
    fi

    local key_block
    local value_block
    key_block="$(schoolcode_gum style --foreground "245" --width 18 "$key")"
    value_block="$(schoolcode_gum style --foreground "252" "$value")"
    schoolcode_gum join --horizontal "$key_block" "  $value_block"
}

ui_list() {
    local tone="${1:-info}"
    shift || true

    local item
    for item in "$@"; do
        [[ -z "$item" ]] && continue
        if ui_is_plain; then
            printf '  - %s\n' "$item"
        else
            schoolcode_gum join --horizontal \
                "$(schoolcode_gum style --foreground "$(ui_tone_foreground "$tone")" "•")" \
                "  $(schoolcode_gum style --foreground "252" "$item")"
        fi
    done
}

ui_summary() {
    local title="$1"
    local body="${2:-}"
    local tone="${3:-info}"

    if ui_is_plain; then
        printf '\n%s\n' "$title"
        [[ -n "$body" ]] && printf '%s\n' "$body"
        printf '\n'
        return 0
    fi

    local content
    if [[ -n "$body" ]]; then
        content="$(printf '%s\n%s' "$title" "$body")"
    else
        content="$title"
    fi

    schoolcode_gum style \
        --border rounded \
        --border-foreground "$(ui_tone_foreground "$tone")" \
        --padding "1 2" \
        --margin "1 0" \
        "$content"
}

ui_error_summary() {
    local title="$1"
    local reason="${2:-}"
    local log_path="${3:-}"
    local body=""

    if [[ -n "$reason" ]]; then
        body="Reason: $reason"
    fi

    if [[ -n "$log_path" ]]; then
        if [[ -n "$body" ]]; then
            body="$(printf '%s\nLog: %s' "$body" "$log_path")"
        else
            body="Log: $log_path"
        fi
    fi

    ui_summary "$title" "$body" "fail"
}

ui_confirm() {
    local prompt="$1"

    if ui_is_plain; then
        printf '%s [y/N]: ' "$prompt"
        read -r response
        [[ "$response" =~ ^[Yy]$ ]]
        return $?
    fi

    schoolcode_gum confirm "$prompt"
}

ui_run_with_spinner() {
    local title="$1"
    shift

    if ui_is_plain; then
        "$@"
        return $?
    fi

    local output_file
    local runner_file
    output_file="$(mktemp /tmp/schoolcode-ui-output.XXXXXX)"
    runner_file="$(mktemp /tmp/schoolcode-ui-runner.XXXXXX)"

    local command_string=""
    printf -v command_string '%q ' "$@"

    cat >"$runner_file" <<EOF
#!/bin/bash
$command_string >"$output_file" 2>&1
EOF
    chmod 700 "$runner_file"

    local exit_code=0
    if ! schoolcode_gum spin \
        --spinner dot \
        --title "$title" \
        --title.foreground "245" \
        --spinner.foreground "63" \
        -- "$runner_file"; then
        exit_code=$?
    fi

    if [[ -s "$output_file" ]]; then
        cat "$output_file"
    fi

    rm -f "$output_file" "$runner_file"
    return "$exit_code"
}
