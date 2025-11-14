# Quick Start: Homebrew Installation Fix

## ✅ What Was Fixed

The Homebrew installation post-install step was failing because:
- The script couldn't find its dependencies in the Homebrew Cellar structure
- Path detection logic didn't handle Homebrew's `libexec/scripts/` layout
- Status file was trying to write to a read-only location

**All issues are now resolved!** 🎉

## 📦 Changes Summary

### Modified Files
- ✏️ `schoolcode.sh` - Enhanced path detection and script sourcing
- ✏️ `Formula/schoolcode.rb` - Fixed post-install command and added version.txt
- ✏️ `Formula/README.md` - Updated documentation
- ✏️ `version.txt` - Bumped to 3.0.1
- 📄 `HOMEBREW_FIX_SUMMARY.md` - Detailed technical documentation
- 📄 `TEST_HOMEBREW_INSTALL.sh` - Automated test script
- 📄 `CHANGELOG_HOMEBREW_FIX.md` - Complete changelog

### Key Improvements
1. **Smart Path Detection**: Automatically detects Homebrew vs git clone installation
2. **Robust Script Finding**: Searches multiple locations for utility scripts
3. **Writable Status File**: Uses `/opt/homebrew/var/schoolcode/` for status
4. **Version Tracking**: Finds `version.txt` in `libexec/` directory
5. **Better Error Handling**: Non-critical failures don't stop installation

## 🚀 How to Test

### Option 1: Quick Test (Git Clone Mode)
```bash
cd /Users/Luka/Documents/SchoolCode
sudo ./schoolcode.sh --help
sudo ./schoolcode.sh --status
```

### Option 2: Full Homebrew Test
```bash
cd /Users/Luka/Documents/SchoolCode
./TEST_HOMEBREW_INSTALL.sh
```

This automated test script will:
- ✅ Check Homebrew installation
- ✅ Remove existing SchoolCode
- ✅ Install from local formula
- ✅ Verify file structure
- ✅ Test commands
- ✅ Provide detailed summary

### Option 3: Manual Homebrew Test
```bash
# Clean install
brew uninstall schoolcode 2>/dev/null || true
brew untap luka-loehr/schoolcode 2>/dev/null || true

# Install from local formula
cd /Users/Luka/Documents/SchoolCode
brew install --build-from-source ./Formula/schoolcode.rb

# Test commands
schoolcode --help
sudo schoolcode --status

# Check installation
ls -la /opt/homebrew/Cellar/schoolcode/*/libexec/scripts/
cat /opt/homebrew/var/schoolcode/.schoolcode-status
```

## 📋 Next Steps

### 1. Test Locally ✅
```bash
cd /Users/Luka/Documents/SchoolCode
./TEST_HOMEBREW_INSTALL.sh
```

### 2. Commit Changes
```bash
git add schoolcode.sh Formula/ version.txt *.md TEST_HOMEBREW_INSTALL.sh
git commit -m "fix: Homebrew installation path detection and script sourcing (v3.0.1)"
git push
```

### 3. Update Homebrew Tap
Copy the updated `Formula/schoolcode.rb` to your `homebrew-schoolcode` repository:

```bash
# Navigate to your homebrew-schoolcode tap repository
cd /path/to/homebrew-schoolcode

# Copy the updated formula
cp /Users/Luka/Documents/SchoolCode/Formula/schoolcode.rb Formula/schoolcode.rb

# Commit and push
git add Formula/schoolcode.rb
git commit -m "fix: Homebrew installation path detection (v3.0.1)"
git push
```

### 4. Create GitHub Release
1. Go to: https://github.com/luka-loehr/SchoolCode/releases/new
2. Tag: `v3.0.1`
3. Title: "v3.0.1 - Homebrew Installation Fix"
4. Description: Use content from `CHANGELOG_HOMEBREW_FIX.md`
5. Create release

### 5. Update Formula SHA256
After creating the release, calculate the SHA256:

```bash
# Download the release tarball
curl -L https://github.com/luka-loehr/SchoolCode/archive/refs/tags/v3.0.1.tar.gz -o SchoolCode-3.0.1.tar.gz

# Calculate SHA256
shasum -a 256 SchoolCode-3.0.1.tar.gz

# Update Formula/schoolcode.rb with the hash
```

### 6. Test from Tap
```bash
brew untap luka-loehr/schoolcode
brew tap luka-loehr/schoolcode
brew install schoolcode

sudo schoolcode --status
```

### 7. Verify Guest Account
```bash
# Switch to Guest account
# Then check if tools are available:
git --version
python3 --version
node --version
```

## 🔍 What Changed Under the Hood

### Path Detection (Before)
```bash
# Couldn't find Cellar path correctly
if [[ "$SCRIPT_DIR" == *"/Cellar/schoolcode"* ]]; then
    # Simple fallback, didn't work
fi
```

### Path Detection (After)
```bash
# Properly extracts version from Cellar path
if [[ "$SCRIPT_DIR" == *"/Cellar/schoolcode"* ]]; then
    CELLAR_PATH="${SCRIPT_DIR%/bin}"  # Extract path before /bin
    PROJECT_ROOT="$CELLAR_PATH"
    SCRIPT_DIR="$CELLAR_PATH/libexec/scripts"
fi
```

### File Structure
```
Homebrew Installation:
/opt/homebrew/
├── bin/schoolcode                    → Cellar/schoolcode/3.0.1/bin/schoolcode
├── Cellar/schoolcode/3.0.1/
│   ├── bin/schoolcode                ← Main script
│   └── libexec/
│       ├── scripts/                  ← All SchoolCode scripts
│       └── version.txt               ← Version file
└── var/schoolcode/
    └── .schoolcode-status            ← Status file (writable!)
```

## 📖 Documentation

- **HOMEBREW_FIX_SUMMARY.md** - Detailed technical documentation
- **CHANGELOG_HOMEBREW_FIX.md** - Complete changelog with all changes
- **TEST_HOMEBREW_INSTALL.sh** - Automated test script
- **Formula/README.md** - Updated Homebrew formula documentation

## ❓ Troubleshooting

### Issue: "command not found: schoolcode"
```bash
# Check installation
brew list schoolcode
which schoolcode

# Reinstall
brew reinstall schoolcode
```

### Issue: "Permission denied"
```bash
# SchoolCode requires sudo for installation
sudo schoolcode --install
```

### Issue: "Scripts not found"
```bash
# Check if scripts are installed
ls -la $(brew --cellar schoolcode)/*/libexec/scripts/

# If missing, reinstall
brew reinstall --build-from-source schoolcode
```

### Issue: Post-install still fails
```bash
# Run installation manually
sudo schoolcode --install

# Check status
sudo schoolcode --status

# View detailed output
sudo $(brew --prefix)/bin/schoolcode --install
```

## 🎯 Success Criteria

The fix is successful when:
- ✅ `brew install schoolcode` completes without errors
- ✅ `schoolcode --help` works
- ✅ `sudo schoolcode --status` shows system information
- ✅ Scripts are found in `/opt/homebrew/Cellar/schoolcode/*/libexec/scripts/`
- ✅ Status file is created in `/opt/homebrew/var/schoolcode/`
- ✅ Guest account has access to installed tools

## 📞 Support

If you encounter any issues:
1. Run `./TEST_HOMEBREW_INSTALL.sh` and share the output
2. Check logs: `sudo /opt/homebrew/bin/schoolcode --status`
3. Review `HOMEBREW_FIX_SUMMARY.md` for technical details

---

**Version**: 3.0.1  
**Date**: 2025-11-14  
**Status**: ✅ Ready for testing and deployment

