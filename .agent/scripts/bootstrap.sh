#!/usr/bin/env bash
# Full memory bootstrap: scan Java symbols → push everything to Chroma.
# Run once after cloning or after a major refactor.
set -uo pipefail
CHROMA_URL="${CHROMA_URL:-http://localhost:8000}"
echo "=== Memory Bootstrap ==="
echo "[1/2] Scanning Java symbols..."
bash .agent/scripts/scan.sh > /dev/null 2>&1
echo "[2/2] Syncing to Chroma..."
python3 .agent/scripts/sync-to-chroma.py --url "$CHROMA_URL"
echo "=== Done ==="
