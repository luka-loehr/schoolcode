#!/bin/bash
# SchoolCode release-aware auto-update script

set -euo pipefail

readonly REPO_ROOT="/Library/SchoolCode/repo"
readonly SYSTEM_ROOT="/Library/SchoolCode"
readonly INSTALLED_VERSION_FILE="${SYSTEM_ROOT}/.installedversion"
readonly LOG_DIR="/var/log/schoolcode"
readonly LOG_FILE="${LOG_DIR}/daemon_update.log"
readonly GITHUB_REPO="luka-loehr/schoolcode"

log() {
    local level="$1"
    shift
    local message="$*"
    mkdir -p "$LOG_DIR"
    local log_line="[$(date '+%Y-%m-%d %H:%M:%S')] [$level] $message"
    
    # Write to log file
    echo "$log_line" >> "$LOG_FILE"
    
    # Also display to terminal
    echo "$message"
}

get_latest_release_version() {
    if ! command -v curl >/dev/null 2>&1; then
        log ERROR "curl is required to check GitHub releases"
        return 1
    fi

    local latest
    latest=$(curl -s --connect-timeout 5 "https://api.github.com/repos/${GITHUB_REPO}/releases/latest" 2>/dev/null \
        | grep '"tag_name":' | head -1 | sed -E 's/.*"([^"]+)".*/\1/' | sed 's/^v//')

    if [[ -z "$latest" ]]; then
        log ERROR "Unable to determine latest release version from GitHub"
        return 1
    fi

    echo "$latest"
}

get_installed_version() {
    if [[ -f "$INSTALLED_VERSION_FILE" ]]; then
        local recorded_version
        recorded_version=$(head -1 "$INSTALLED_VERSION_FILE" 2>/dev/null | tr -d '\r\n')
        if [[ -n "$recorded_version" ]]; then
            echo "$recorded_version"
            return
        fi
    fi

    echo "0.0.0"
}

record_installed_version() {
    local version="$1"
    mkdir -p "$SYSTEM_ROOT"
    echo "$version" > "$INSTALLED_VERSION_FILE"
    log INFO "Recorded installed version: $version"
}

is_newer_version() {
    local current="$1"
    local latest="$2"

    if [[ "$current" == "$latest" ]]; then
        return 1
    fi

    local highest
    highest=$(printf '%s\n%s\n' "$current" "$latest" | sort -V | tail -1)
    [[ "$highest" == "$latest" ]]
}

reset_to_release_tag() {
    local release_version="$1"
    local tag_ref="$release_version"

    if [[ ! "$tag_ref" =~ ^v ]]; then
        tag_ref="v${tag_ref}"
    fi

    git fetch --tags origin

    if git rev-parse --verify "refs/tags/${tag_ref}" >/dev/null 2>&1; then
        git reset --hard "${tag_ref}"
        log INFO "Reset repository to tag ${tag_ref}"
    else
        log ERROR "Release tag ${tag_ref} not found after fetch"
        return 1
    fi
}

reload_launchd_services() {
    local launchagent_plist="/Library/LaunchAgents/com.schoolcode.guestsetup.plist"
    local launchdaemon_plist="/Library/LaunchDaemons/com.schoolcode.autoupdate.plist"
    
    # LaunchAgent is per-user (loads on Guest login), we just verify the plist exists
    # It cannot be reloaded from root/admin context - this is expected behavior
    if [[ -f "$launchagent_plist" ]]; then
        echo "  ✓ LaunchAgent configured (loads on Guest login)"
    else
        echo "  ⚠ LaunchAgent plist missing"
    fi
    
    # LaunchDaemon is system-wide, unload and reload it
    if [[ -f "$launchdaemon_plist" ]]; then
        launchctl unload "$launchdaemon_plist" 2>/dev/null || true
        if launchctl load -w "$launchdaemon_plist" 2>/dev/null; then
            echo "  ✓ LaunchDaemon reloaded"
        else
            echo "  ⚠ LaunchDaemon reload failed"
        fi
    else
        echo "  ⚠ LaunchDaemon plist missing"
    fi
}

run_install() {
    log INFO "Starting installation from ${REPO_ROOT}"
    "$REPO_ROOT/schoolcode.sh" --install
}

main() {
    if [[ ! -d "$REPO_ROOT/.git" ]]; then
        log ERROR "Repository not found at ${REPO_ROOT}. Please install SchoolCode to /Library/SchoolCode/repo"
        exit 1
    fi

    cd "$REPO_ROOT"

    local installed_version latest_version
    installed_version=$(get_installed_version)
    
    echo "Checking for updates..."
    latest_version=$(get_latest_release_version)

    if [[ -z "$latest_version" ]]; then
        log ERROR "Latest release version could not be determined"
        exit 1
    fi

    log INFO "Installed version: ${installed_version}"
    log INFO "Latest release available: ${latest_version}"

    if ! is_newer_version "$installed_version" "$latest_version"; then
        log INFO "No update required; installed release is current"
        exit 0
    fi

    log INFO "New release found: ${latest_version}"
    log INFO "Fetching release ${latest_version}..."
    reset_to_release_tag "$latest_version"

    log INFO "Installing release ${latest_version}..."
    run_install
    record_installed_version "$latest_version"
    
    # Reload services to apply updates
    log INFO "Refreshing services..."
    reload_launchd_services

    echo ""
    log INFO "✓ Update completed successfully"
}

main "$@"
