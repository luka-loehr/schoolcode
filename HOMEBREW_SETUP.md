# Homebrew Tap Setup Guide

This guide explains how to set up the Homebrew tap for SchoolCode so users can install it via `brew install`.

## Prerequisites

- GitHub account with repository creation permissions
- Homebrew installed on your Mac (for testing)
- Git configured

## Step 1: Create the Tap Repository

1. Go to GitHub and create a new repository named `homebrew-schoolcode`
2. Initialize it with a README (optional)
3. Clone it locally:
   ```bash
   git clone https://github.com/luka-loehr/homebrew-schoolcode.git
   cd homebrew-schoolcode
   ```

## Step 2: Copy the Formula

1. Copy the formula file from this repository:
   ```bash
   cp /path/to/SchoolCode/Formula/schoolcode.rb Formula/schoolcode.rb
   ```
   Or manually create `Formula/schoolcode.rb` with the contents from `Formula/schoolcode.rb` in this repo.

2. Commit and push:
   ```bash
   git add Formula/schoolcode.rb
   git commit -m "Add SchoolCode formula"
   git push origin main
   ```

## Step 3: Create a GitHub Release

1. In the main SchoolCode repository, create a release tag:
   ```bash
   git tag v3.0.0
   git push origin v3.0.0
   ```

2. The GitHub Actions workflow (`.github/workflows/release.yml`) will automatically:
   - Create a release tarball
   - Calculate the SHA256 hash
   - Create a GitHub release

3. Get the SHA256 hash from the workflow output or release notes

## Step 4: Update Formula with SHA256

1. Edit `Formula/schoolcode.rb` in the tap repository
2. Update the `sha256` line with the hash from the release:
   ```ruby
   sha256 "abc123def456..." # Replace with actual hash
   ```

3. Commit and push:
   ```bash
   git add Formula/schoolcode.rb
   git commit -m "Update SHA256 for v3.0.0"
   git push origin main
   ```

## Step 5: Test Installation

1. Add the tap:
   ```bash
   brew tap luka-loehr/schoolcode
   ```

2. Install SchoolCode:
   ```bash
   brew install schoolcode
   ```
   This should automatically run `sudo schoolcode` and perform the full installation.

3. Verify installation:
   ```bash
   sudo schoolcode --status
   ```

4. Test uninstallation:
   ```bash
   brew uninstall schoolcode
   ```
   This should automatically run `sudo schoolcode --uninstall` before removing files.

## Step 6: Update Documentation

Update the main SchoolCode README.md to point users to the tap installation method.

## Future Updates

When releasing a new version:

1. Create a new release tag in the main repository
2. Get the new SHA256 hash from the release workflow
3. Update `Formula/schoolcode.rb` in the tap repository with:
   - New version number in `url`
   - New SHA256 hash
4. Commit and push the updated formula

## Troubleshooting

### Formula not found
- Ensure the tap repository is named exactly `homebrew-schoolcode`
- Verify the formula file is at `Formula/schoolcode.rb` (capital F)

### Installation fails
- Check that the SHA256 hash matches the release tarball
- Verify the URL points to the correct release tag
- Check Homebrew logs: `brew install --verbose schoolcode`

### Scripts not found
- Verify scripts are installed to `libexec/scripts/`
- Check that `schoolcode.sh` correctly detects Homebrew installation paths

## Notes

- The formula uses `post_install` to automatically run the installation script
- The formula uses `uninstall` to run cleanup before removing files
- Scripts are installed to `libexec/scripts/` to keep them separate from the main binary
- The main `schoolcode` command is symlinked to Homebrew's bin directory

