# Homebrew Installation Fix Summary

## Problem
The Homebrew installation was failing during the `post_install` step. The error log showed that the script was outputting Homebrew diagnostic information instead of running the actual installation.

## Root Causes

1. **Path Detection Issues**: The `schoolcode.sh` script wasn't correctly detecting the Homebrew installation structure
2. **Script Sourcing Failures**: Utility scripts (`logging.sh`, `config.sh`) weren't being found in the `libexec/scripts/` directory
3. **Status File Location**: The script tried to write to the Cellar directory, which is read-only
4. **Version File Location**: The script couldn't find `version.txt` in the Homebrew installation
5. **Post-Install Command**: The formula was running `sudo schoolcode` without the `--install` flag

## Changes Made

### 1. `schoolcode.sh` - Path Detection Fix

**Before**: Simple path detection that didn't handle Homebrew's structure properly

**After**: Enhanced path detection with proper Cellar path extraction:
```bash
# Detect if running from Homebrew installation
if [[ "$SCRIPT_DIR" == *"/Cellar/schoolcode"* ]] || [[ "$SCRIPT_DIR" == *"/Homebrew"* ]]; then
    # First, try to find the Cellar path directly
    if [[ "$SCRIPT_DIR" == *"/Cellar/schoolcode"* ]]; then
        # Extract version from path: /opt/homebrew/Cellar/schoolcode/3.0.0/bin -> /opt/homebrew/Cellar/schoolcode/3.0.0
        CELLAR_PATH="${SCRIPT_DIR%/bin}"
        PROJECT_ROOT="$CELLAR_PATH"
        SCRIPT_DIR="$CELLAR_PATH/libexec/scripts"
    else
        # Running from symlinked location (e.g., /opt/homebrew/bin/schoolcode)
        # Find actual Cellar path using brew commands
        ...
    fi
fi
```

### 2. `schoolcode.sh` - Script Sourcing Fix

**Before**: Limited fallback paths for finding utility scripts

**After**: Comprehensive search with Homebrew-aware logic:
```bash
LOGGING_SH=""
if [[ -f "$SCRIPT_DIR/utils/logging.sh" ]]; then
    LOGGING_SH="$SCRIPT_DIR/utils/logging.sh"
elif [[ -f "$SCRIPT_DIR/scripts/utils/logging.sh" ]]; then
    LOGGING_SH="$SCRIPT_DIR/scripts/utils/logging.sh"
elif [[ -f "$PROJECT_ROOT/libexec/scripts/utils/logging.sh" ]]; then
    LOGGING_SH="$PROJECT_ROOT/libexec/scripts/utils/logging.sh"
    # Update SCRIPT_DIR to point to actual scripts location
    if [[ -d "$PROJECT_ROOT/libexec/scripts" ]]; then
        SCRIPT_DIR="$PROJECT_ROOT/libexec/scripts"
    fi
fi
```

### 3. `schoolcode.sh` - Status File Fix

**Before**: Tried to write to `$PROJECT_ROOT/.schoolcode-status` (inside Cellar - read-only)

**After**: Uses writable directory for Homebrew installations:
```bash
# Status file location - use a writable directory
if [[ "$PROJECT_ROOT" == *"/Cellar/schoolcode"* ]]; then
    # Homebrew installation - use /opt/homebrew/var
    HOMEBREW_VAR="${HOMEBREW_PREFIX:-/opt/homebrew}/var"
    STATUS_FILE="$HOMEBREW_VAR/schoolcode/.schoolcode-status"
    mkdir -p "$HOMEBREW_VAR/schoolcode" 2>/dev/null || true
else
    # Git clone or other installation
    STATUS_FILE="$PROJECT_ROOT/.schoolcode-status"
fi
```

### 4. `schoolcode.sh` - Version Detection Fix

**Before**: Only looked for `version.txt` in `PROJECT_ROOT`

**After**: Checks multiple locations including `libexec/`:
```bash
get_schoolcode_version() {
    local version="$SCRIPT_VERSION"
    
    # Try to read from version.txt in various locations
    local version_file=""
    if [[ -f "$PROJECT_ROOT/version.txt" ]]; then
        version_file="$PROJECT_ROOT/version.txt"
    elif [[ -f "$PROJECT_ROOT/libexec/version.txt" ]]; then
        version_file="$PROJECT_ROOT/libexec/version.txt"
    elif [[ -f "$SCRIPT_DIR/../version.txt" ]]; then
        version_file="$SCRIPT_DIR/../version.txt"
    fi
    ...
}
```

### 5. `schoolcode.sh` - Find Script Function Fix

**Before**: Limited search paths

**After**: Prioritizes Homebrew structure:
```bash
find_script() {
    local script_name="$1"
    
    # Homebrew installation: scripts are in libexec/scripts/
    if [[ -f "$PROJECT_ROOT/libexec/scripts/$script_name" ]]; then
        echo "$PROJECT_ROOT/libexec/scripts/$script_name"
        return 0
    fi
    
    # Direct SCRIPT_DIR location
    if [[ -f "$SCRIPT_DIR/$script_name" ]]; then
        echo "$SCRIPT_DIR/$script_name"
        return 0
    fi
    ...
}
```

### 6. `schoolcode.sh` - Status Update Robustness

**Before**: Failed installation if status file couldn't be created

**After**: Treats status file write failure as non-critical:
```bash
# Write status file with error handling
if echo "$status_data" > "$STATUS_FILE" 2>/dev/null; then
    echo "Status updated: $status"
    return 0
else
    echo "Warning: Failed to update status file: $STATUS_FILE (this is non-critical)" >&2
    return 0  # Don't fail the installation just because we can't write status
fi
```

### 7. `Formula/schoolcode.rb` - Post-Install Fix

**Before**:
```ruby
def post_install
    system "sudo", "#{bin}/schoolcode"
end
```

**After**:
```ruby
def post_install
    ohai "Running SchoolCode installation..."
    ohai "This requires sudo privileges and will set up Guest account tools."
    
    # Run with explicit error handling
    unless system "sudo", "#{bin}/schoolcode", "--install"
      opoo "SchoolCode installation encountered an issue."
      opoo "You can manually complete installation by running:"
      opoo "  sudo schoolcode --install"
    end
end
```

### 8. `Formula/schoolcode.rb` - Version File Installation

**Before**: Didn't install `version.txt`

**After**:
```ruby
def install
    ...
    # Install version.txt to libexec
    libexec.install "version.txt" if File.exist?("version.txt")
    ...
end
```

## Testing Instructions

### 1. Test Locally Before Publishing

```bash
# Navigate to SchoolCode directory
cd /Users/Luka/Documents/SchoolCode

# Test the script directly to ensure path detection works
sudo ./schoolcode.sh --help

# Test installation in git clone mode
sudo ./schoolcode.sh --install

# Check status
sudo ./schoolcode.sh --status
```

### 2. Test Homebrew Installation (Local Formula)

```bash
# Remove old installation if present
brew uninstall schoolcode 2>/dev/null || true
brew untap luka-loehr/schoolcode 2>/dev/null || true

# Install from local formula (for testing)
cd /Users/Luka/Documents/SchoolCode
brew install --build-from-source ./Formula/schoolcode.rb

# Check if binary is available
which schoolcode

# Check if scripts are in the right place
ls -la /opt/homebrew/Cellar/schoolcode/3.0.0/libexec/scripts/

# Test the command
sudo schoolcode --help
sudo schoolcode --status

# Test installation
sudo schoolcode --install

# Check status file
cat /opt/homebrew/var/schoolcode/.schoolcode-status
```

### 3. Publish to Homebrew Tap

After local testing succeeds:

```bash
# 1. Commit changes
cd /Users/Luka/Documents/SchoolCode
git add schoolcode.sh Formula/schoolcode.rb Formula/README.md
git commit -m "fix: Homebrew installation path detection and script sourcing"

# 2. Update the homebrew-schoolcode tap repository
# Copy Formula/schoolcode.rb to your homebrew-schoolcode repository
# Commit and push

# 3. Test installation from tap
brew untap luka-loehr/schoolcode
brew tap luka-loehr/schoolcode
brew install schoolcode

# 4. Verify installation
sudo schoolcode --status
```

### 4. Verify Guest Account Setup

```bash
# After installation, switch to Guest account
# Then check if tools are available:
git --version
python3 --version
node --version
code --version  # if VS Code is installed
```

## What Was Fixed

✅ **Path Detection**: Script now correctly detects Homebrew Cellar structure
✅ **Script Sourcing**: Utility scripts are found in `libexec/scripts/`
✅ **Status File**: Uses writable location (`/opt/homebrew/var/schoolcode/`)
✅ **Version Detection**: Finds `version.txt` in `libexec/`
✅ **Post-Install**: Runs with explicit `--install` flag and better error handling
✅ **Version File**: `version.txt` is now installed to `libexec/`
✅ **Find Script**: Enhanced script finding logic for Homebrew structure
✅ **Error Handling**: Non-critical failures don't stop installation

## File Structure

After successful Homebrew installation:

```
/opt/homebrew/
├── bin/
│   └── schoolcode                           # Symlink to Cellar
├── Cellar/schoolcode/3.0.0/
│   ├── bin/
│   │   └── schoolcode                       # Main script
│   └── libexec/
│       ├── scripts/                         # All SchoolCode scripts
│       │   ├── install.sh
│       │   ├── uninstall.sh
│       │   ├── update.sh
│       │   ├── guest_setup_auto.sh
│       │   ├── schoolcode-cli.sh
│       │   ├── setup/
│       │   │   ├── guest_login_setup.sh
│       │   │   ├── guest_tools_setup.sh
│       │   │   └── setup_guest_shell_init.sh
│       │   └── utils/
│       │       ├── config.sh
│       │       ├── logging.sh
│       │       ├── monitoring.sh
│       │       └── ... (all utility scripts)
│       └── version.txt                      # Version information
└── var/schoolcode/
    └── .schoolcode-status                   # Installation status
```

## Next Steps

1. **Test locally** using the instructions above
2. **Verify** all functionality works (install, status, uninstall)
3. **Commit** the changes to the main repository
4. **Update** the homebrew-schoolcode tap repository with the new formula
5. **Create release** (v3.0.1) with proper SHA256 hash
6. **Test** installation from the tap
7. **Document** the fix in the changelog

## Notes

- The changes maintain backward compatibility with git clone installations
- The script now gracefully handles both Homebrew and non-Homebrew installations
- Status file write failures are non-critical and won't stop installation
- All utility scripts are properly located using enhanced path detection

