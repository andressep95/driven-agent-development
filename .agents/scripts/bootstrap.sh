#!/usr/bin/env bash
# Full memory bootstrap: scan all git history + Java symbols → push to Chroma.
# Run from anywhere — script resolves the project root automatically.
set -uo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
cd "$ROOT"
CHROMA_URL="${CHROMA_URL:-http://localhost:8000}"
echo "=== Memory Bootstrap ==="
echo "[1/3] Replaying git history for all tracked file types..."
bash "$SCRIPT_DIR/scan-history.sh"
echo "[2/3] Scanning Java symbols..."
if [ -d "src/main/java" ]; then
    bash "$SCRIPT_DIR/scan.sh" > /dev/null 2>&1
else
    echo "  (no src/main/java — skipping Java symbol scan)"
fi
echo "[3/3] Syncing to Chroma..."
python3 "$SCRIPT_DIR/sync-to-chroma.py" --url "$CHROMA_URL"
echo "=== Done ==="
