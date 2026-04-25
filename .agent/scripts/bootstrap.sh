#!/usr/bin/env bash
# Full memory bootstrap: scan.sh → sync-to-chroma.py
set -uo pipefail
CHROMA_URL="${CHROMA_URL:-http://localhost:8000}"
echo "=== Memory Bootstrap ==="
echo "[1/2] Scanning..."
bash .agent/scripts/scan.sh > /dev/null 2>&1
echo "[2/2] Syncing to Chroma..."
python3 .agent/scripts/sync-to-chroma.py --url "$CHROMA_URL"
echo "=== Done ==="
