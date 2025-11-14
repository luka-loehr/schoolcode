# Instructions to Update Homebrew Tap for v3.0.1

## Current Status
- ✅ Main repository updated to v3.0.1
- ✅ Release tag v3.0.1 created and pushed
- ⏳ Waiting for GitHub Actions to create release and calculate SHA256
- ⏳ Need to update `homebrew-schoolcode` tap repository

## Step 1: Check GitHub Actions Workflow

1. Go to: https://github.com/luka-loehr/schoolcode/actions
2. Find the "Create Release" workflow run for tag `v3.0.1`
3. Wait for it to complete (should take 1-2 minutes)
4. Click on the completed workflow run
5. Look for the "Output SHA256 for formula" step
6. **Copy the SHA256 value** (it will look like: `abc123def456...`)

**Alternative:** Check the release page:
- Go to: https://github.com/luka-loehr/schoolcode/releases
- Find `v3.0.1` release
- The SHA256 will be in the release notes

## Step 2: Update the Tap Repository

### Option A: If you have the tap repository cloned locally

```bash
# Navigate to your tap repository
cd /path/to/homebrew-schoolcode

# Make sure you're up to date
git pull origin main

# Copy the updated formula
cp /Users/Luka/Documents/SchoolCode/Formula/schoolcode.rb Formula/schoolcode.rb

# Edit the formula to add the SHA256
# Open Formula/schoolcode.rb and update line 11:
# sha256 "PASTE_SHA256_HERE"

# Or use sed (replace YOUR_SHA256_HERE with actual value):
# sed -i '' 's/sha256 ""/sha256 "YOUR_SHA256_HERE"/' Formula/schoolcode.rb

# Verify the changes
cat Formula/schoolcode.rb | grep -A1 "url\|sha256"

# Commit and push
git add Formula/schoolcode.rb
git commit -m "Update to v3.0.1 - Homebrew installation fix"
git push origin main
```

### Option B: If you need to create/update the tap repository

```bash
# Check if repository exists on GitHub
# Go to: https://github.com/luka-loehr/homebrew-schoolcode

# If it doesn't exist, create it:
# 1. Go to https://github.com/new
# 2. Repository name: homebrew-schoolcode
# 3. Make it public
# 4. Initialize with README

# Clone it
cd /Users/Luka/Documents
git clone https://github.com/luka-loehr/homebrew-schoolcode.git
cd homebrew-schoolcode

# Create Formula directory
mkdir -p Formula

# Copy the formula
cp /Users/Luka/Documents/SchoolCode/Formula/schoolcode.rb Formula/schoolcode.rb

# Edit Formula/schoolcode.rb:
# Update line 11: sha256 "PASTE_SHA256_HERE"

# Commit and push
git add Formula/schoolcode.rb
git commit -m "Add SchoolCode formula v3.0.1"
git push origin main
```

## Step 3: Test the Installation

Once the tap is updated:

```bash
# Clean slate
brew uninstall schoolcode 2>/dev/null || true
brew untap luka-loehr/schoolcode 2>/dev/null || true

# Add the updated tap
brew tap luka-loehr/schoolcode

# Install
brew install schoolcode

# Verify version
schoolcode --help  # Should show v3.0.1

# Test status
sudo schoolcode --status

# Check file structure
ls -la $(brew --cellar schoolcode)/*/libexec/scripts/
cat $(brew --prefix)/var/schoolcode/.schoolcode-status
```

## Quick Reference: Formula Updates Needed

The formula at `Formula/schoolcode.rb` needs these updates:

```ruby
# Line 10: URL (already updated)
url "https://github.com/luka-loehr/SchoolCode/archive/refs/tags/v3.0.1.tar.gz"

# Line 11: SHA256 (NEEDS TO BE UPDATED)
sha256 "PASTE_SHA256_FROM_GITHUB_ACTIONS_HERE"
```

## Troubleshooting

### If installation fails with "SHA256 mismatch"
- Double-check the SHA256 value from GitHub Actions
- Make sure there are no extra spaces or characters
- The SHA256 should be 64 hexadecimal characters

### If "formula not found"
- Verify the tap repository name is exactly `homebrew-schoolcode`
- Check that the formula is at `Formula/schoolcode.rb` (capital F)
- Ensure the repository is public

### If scripts are not found
- Check that scripts are in `libexec/scripts/`
- Verify the path detection in `schoolcode.sh` is working
- Run: `ls -la $(brew --cellar schoolcode)/*/libexec/scripts/`

## Current Formula Status

✅ URL updated to v3.0.1  
⏳ SHA256 needs to be added (waiting for GitHub Actions)  
✅ All other fixes are in place

---

**Next Action:** Wait for GitHub Actions to complete, then update the tap repository with the SHA256.

