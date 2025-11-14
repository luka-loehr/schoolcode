# Homebrew Tap for SchoolCode

This directory contains the Homebrew formula for SchoolCode.

## Setting Up the Tap Repository

To make SchoolCode installable via Homebrew, you need to create a separate tap repository:

1. Create a new GitHub repository named `homebrew-schoolcode`
2. Copy `Formula/schoolcode.rb` to the new repository as `Formula/schoolcode.rb`
3. Update the SHA256 hash in the formula after creating a release
4. Users can then install via:
   ```bash
   brew tap luka-loehr/schoolcode
   brew install schoolcode
   ```

## Updating the Formula

When releasing a new version:

1. Create a GitHub release tag (e.g., `v3.0.1`)
2. The GitHub Actions workflow will create a release tarball
3. Get the SHA256 hash from the release workflow output
4. Update `Formula/schoolcode.rb` with:
   - New version number in `url`
   - SHA256 hash in `sha256`

## Formula Details

- **Installation**: Runs `sudo schoolcode --install` automatically via `post_install` hook
- **Uninstallation**: Runs `sudo schoolcode --uninstall` before removing files
- **Scripts Location**: Installed to `libexec/scripts/` (Homebrew standard)
- **Main Binary**: `schoolcode` in Homebrew's bin directory (symlinked from Cellar)
- **Version File**: `version.txt` copied to `libexec/` for version tracking
- **Status File**: Stored in `/opt/homebrew/var/schoolcode/.schoolcode-status` (writable location)

## File Structure After Installation

```
/opt/homebrew/
├── bin/schoolcode                           # Main executable (symlink)
├── Cellar/schoolcode/3.0.0/
│   ├── bin/schoolcode                       # Actual script
│   └── libexec/
│       ├── scripts/                         # All SchoolCode scripts
│       │   ├── install.sh
│       │   ├── uninstall.sh
│       │   ├── setup/
│       │   └── utils/
│       └── version.txt                      # Version information
└── var/schoolcode/
    └── .schoolcode-status                   # Installation status (writable)
```

## Testing Locally

To test the formula before publishing:

```bash
# Install from local formula
brew install --build-from-source ./Formula/schoolcode.rb

# Test installation
sudo schoolcode --status

# Test uninstallation
brew uninstall schoolcode
```

