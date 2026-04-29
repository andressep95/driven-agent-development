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
if command -v python3 &>/dev/null; then
    python3 "$SCRIPT_DIR/sync-to-chroma.py"
else
    echo "  [skip] python3 not found — memory.jsonl is populated."
    echo "  Run this manually on your machine to index Chroma:"
    echo "    python3 .agents/scripts/sync-to-chroma.py"
fi
echo "=== Done ==="
