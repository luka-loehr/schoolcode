#!/bin/bash
# Copyright (c) 2025 Luka Löhr

set -euo pipefail

readonly SCHOOLCODE_GUM_VERSION="0.17.0"

schoolcode_repo_root() {
    local source_path="${BASH_SOURCE[0]}"
    local source_dir
    source_dir="$(cd "$(dirname "$source_path")" && pwd)"
    cd "$source_dir/../.." && pwd
}

schoolcode_gum_platform_dir() {
    case "$(uname -m)" in
        arm64)
            echo "darwin-arm64"
            ;;
        x86_64)
            echo "darwin-x86_64"
            ;;
        *)
            echo ""
            return 1
            ;;
    esac
}

schoolcode_gum_path() {
    local repo_root
    repo_root="$(schoolcode_repo_root)"

    local platform_dir
    platform_dir="$(schoolcode_gum_platform_dir)"

    echo "$repo_root/vendor/gum/$platform_dir/gum"
}

schoolcode_has_gum() {
    local gum_path
    gum_path="$(schoolcode_gum_path)"
    [[ -x "$gum_path" ]]
}

schoolcode_require_gum() {
    local gum_path
    gum_path="$(schoolcode_gum_path)"

    if [[ -x "$gum_path" ]]; then
        return 0
    fi

    echo "SchoolCode could not find its vendored Gum runtime." >&2
    echo "Expected executable: $gum_path" >&2
    echo "Pinned version: v$SCHOOLCODE_GUM_VERSION" >&2
    return 1
}

schoolcode_gum() {
    local gum_path
    gum_path="$(schoolcode_gum_path)"
    schoolcode_require_gum
    "$gum_path" "$@"
}
