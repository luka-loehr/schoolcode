#!/bin/bash
# Simple installation script for SchoolCode via Homebrew
# This makes it easy to install with just one command

set -euo pipefail

echo "🍺 Installing SchoolCode via Homebrew..."
echo ""

# Add tap and install
brew tap luka-loehr/schoolcode
brew install schoolcode

echo ""
echo "✅ Installation complete!"
echo ""
echo "Next steps:"
echo "  • Check status: sudo schoolcode --status"
echo "  • Switch to Guest account to test tools"
echo ""

