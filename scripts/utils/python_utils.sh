#!/bin/bash
# Copyright (c) 2025 Luka Löhr

# Python utilities for SchoolCode
# Functions to detect and work with official Python installations

# Function to find the newest installed official Python version from python.org.
find_official_python_version() {
    local framework_base="/Library/Frameworks/Python.framework/Versions"

    if [[ ! -d "$framework_base" ]]; then
        return 1
    fi

    find "$framework_base" -mindepth 1 -maxdepth 1 -type d 2>/dev/null | \
        xargs -n1 basename 2>/dev/null | \
        grep -E '^[0-9]+\.[0-9]+(\.[0-9]+)?$' | \
        sort -t. -k1,1n -k2,2n -k3,3n | \
        tail -1
}

# Function to get the bin directory for the newest installed official Python.
get_python_bin_dir() {
    local version
    version="$(find_official_python_version)" || return 1
    echo "/Library/Frameworks/Python.framework/Versions/$version/bin"
}

# Function to emit the concrete python/pip paths for the detected installation.
get_python_paths() {
    local actual_bin
    actual_bin="$(get_python_bin_dir)" || return 1

    local version
    version="$(find_official_python_version)" || return 1

    echo "PYTHON_PATH=${actual_bin}/python"
    echo "PYTHON3_PATH=${actual_bin}/python3"
    echo "PIP_PATH=${actual_bin}/pip"
    echo "PIP3_PATH=${actual_bin}/pip3"
    echo "PYTHON_VERSION=${version}"
}

# Export functions for use in other scripts
export -f find_official_python_version
export -f get_python_bin_dir
export -f get_python_paths
