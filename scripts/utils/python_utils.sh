#!/bin/bash
# Copyright (c) 2025 Luka Löhr

# Python utilities for SchoolCode
# Functions to detect and work with official Python installations

# Function to find the installed official Python version
# HARDCODED to Python 3.13 - automatic detection disabled
find_official_python_version() {
    echo "3.13"
    return 0
}

# Function to get Python bin directory
# HARDCODED to Python 3.13 - automatic detection disabled
get_python_bin_dir() {
    echo "/Library/Frameworks/Python.framework/Versions/3.13/bin"
    return 0
}

# Export functions for use in other scripts
export -f find_official_python_version
export -f get_python_bin_dir