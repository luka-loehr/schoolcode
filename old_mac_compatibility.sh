#!/bin/bash
# Copyright (c) 2025 Luka Löhr

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
exec "$SCRIPT_DIR/scripts/utils/old_mac_compatibility.sh" "$@"
