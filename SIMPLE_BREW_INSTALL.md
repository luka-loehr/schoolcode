# Simple Homebrew Installation

## ✅ Goal: `brew install schoolcode`

To use just `brew install schoolcode`, you need to tap first. Here are the easiest ways:

### Option 1: One-Liner (Recommended)

```bash
brew tap luka-loehr/schoolcode && brew install schoolcode
```

### Option 2: Auto-Tap Format

```bash
brew install luka-loehr/schoolcode/schoolcode
```

This automatically taps the repository, so you don't need to run `brew tap` separately.

### Option 3: Use the Install Script

```bash
curl -fsSL https://raw.githubusercontent.com/luka-loehr/schoolcode/main/install-via-brew.sh | bash
```

Or download and run:
```bash
./install-via-brew.sh
```

## Current Status

✅ Tap repository updated with v3.0.1 formula  
⏳ Waiting for GitHub Actions to calculate SHA256  
⏳ Need to update SHA256 in tap repository  
⏳ Then push tap repository  

## After SHA256 is Added

Once the SHA256 is added to the tap repository, users can install with:

```bash
# Method 1: Tap then install
brew tap luka-loehr/schoolcode
brew install schoolcode

# Method 2: Auto-tap (one command)
brew install luka-loehr/schoolcode/schoolcode

# Method 3: One-liner
brew tap luka-loehr/schoolcode && brew install schoolcode
```

## Why Not Just `brew install schoolcode`?

To use just `brew install schoolcode` without tapping, the formula would need to be in the official Homebrew core tap (`homebrew-core`), which requires:
- Submitting a PR to https://github.com/Homebrew/homebrew-core
- Meeting Homebrew's requirements (popularity, maintenance, etc.)
- Approval from Homebrew maintainers

For now, the tap approach is the standard way for third-party formulas.

## Next Steps

1. ✅ Tap repository updated locally
2. ⏳ Get SHA256 from GitHub Actions workflow
3. ⏳ Update `Formula/schoolcode.rb` with SHA256
4. ⏳ Push tap repository
5. ✅ Users can then install!

---

**Quick Install Command (once tap is updated):**
```bash
brew install luka-loehr/schoolcode/schoolcode
```

