#!/usr/bin/env bash
# Full memory bootstrap: replay git history → push to Chroma.
# Run from anywhere — script resolves the project root automatically.
set -uo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
cd "$ROOT"
echo "=== Memory Bootstrap ==="
echo "[1/2] Replaying git history..."
bash "$SCRIPT_DIR/scan-history.sh"
echo "[2/2] Syncing to Chroma..."
python3 "$SCRIPT_DIR/sync-to-chroma.py"
echo "=== Done ==="
