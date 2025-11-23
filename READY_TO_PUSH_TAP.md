# Ready to Push Tap Repository

## ✅ What's Done

1. ✅ Tap repository cloned and updated locally
2. ✅ Formula updated to v3.0.1 with all fixes
3. ✅ README updated with installation instructions
4. ✅ Changes committed locally
5. ⏳ **Waiting for SHA256 from GitHub Actions**

## 📋 Next Steps

### Step 1: Get SHA256 from GitHub Actions

**Option A: Check Workflow Output**
1. Go to: https://github.com/luka-loehr/schoolcode/actions
2. Find the "Create Release" workflow for tag `v3.0.1`
3. Click on the completed workflow run
4. Find the "Output SHA256 for formula" step
5. **Copy the SHA256 value**

**Option B: Check Release Page**
1. Go to: https://github.com/luka-loehr/schoolcode/releases
2. Find the `v3.0.1` release
3. The SHA256 will be in the release notes

### Step 2: Update Formula with SHA256

```bash
cd /Users/Luka/Documents/homebrew-schoolcode

# Edit Formula/schoolcode.rb
# Update line 11: sha256 "PASTE_SHA256_HERE"

# Or use sed (replace YOUR_SHA256 with actual value):
sed -i '' 's/sha256 ""/sha256 "YOUR_SHA256_HERE"/' Formula/schoolcode.rb

# Verify
cat Formula/schoolcode.rb | grep sha256
```

### Step 3: Commit and Push

```bash
cd /Users/Luka/Documents/homebrew-schoolcode

git add Formula/schoolcode.rb
git commit -m "Add SHA256 for v3.0.1"
git push origin main
```

### Step 4: Test Installation

```bash
# Clean install
brew uninstall schoolcode 2>/dev/null || true
brew untap luka-loehr/schoolcode 2>/dev/null || true

# Install (auto-taps)
brew install luka-loehr/schoolcode/schoolcode

# Or tap then install
brew tap luka-loehr/schoolcode
brew install schoolcode

# Verify
schoolcode --help  # Should show v3.0.1
sudo schoolcode --status
```

## 🎯 Installation Commands for Users

Once the tap is pushed, users can install with:

### Simplest (Auto-Tap):
```bash
brew install luka-loehr/schoolcode/schoolcode
```

### Two-Step:
```bash
brew tap luka-loehr/schoolcode
brew install schoolcode
```

### One-Liner:
```bash
brew tap luka-loehr/schoolcode && brew install schoolcode
```

## 📝 Current Formula Status

**Location:** `/Users/Luka/Documents/homebrew-schoolcode/Formula/schoolcode.rb`

**Current state:**
- ✅ URL: `v3.0.1` 
- ⏳ SHA256: Empty (needs to be filled)
- ✅ All other fixes: Applied

## 🔍 Verify Before Pushing

```bash
cd /Users/Luka/Documents/homebrew-schoolcode

# Check formula
cat Formula/schoolcode.rb | grep -E "url|sha256"

# Should show:
# url "https://github.com/luka-loehr/SchoolCode/archive/refs/tags/v3.0.1.tar.gz"
# sha256 "64-character-hex-string-here"
```

## ⚠️ Important Notes

- **Don't push without SHA256** - Homebrew will reject the formula
- The SHA256 must match the release tarball exactly
- Test locally after updating SHA256 before pushing

---

**Status:** ✅ Ready to update SHA256 and push  
**Location:** `/Users/Luka/Documents/homebrew-schoolcode`  
**Next:** Get SHA256 from GitHub Actions, update formula, push

