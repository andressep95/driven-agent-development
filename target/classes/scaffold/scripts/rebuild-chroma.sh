#!/usr/bin/env bash
# Drops and rebuilds the ChromaDB collection from .agent/memory.jsonl.
# Use after importing a project or restoring from backup.
#
# Usage:
#   bash .agent/scripts/rebuild-chroma.sh
#   CHROMA_URL=http://myhost:8000 bash .agent/scripts/rebuild-chroma.sh
set -uo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
cd "$ROOT"
CHROMA_URL="${CHROMA_URL:-http://localhost:8000}"
echo "=== Rebuilding Chroma from memory.jsonl ==="
echo "URL     : $CHROMA_URL"
echo "Source  : .agents/memory/memory.jsonl"
echo ""
python3 "$SCRIPT_DIR/sync-to-chroma.py" \
    --jsonl ".agents/memory/memory.jsonl" \
    --url   "$CHROMA_URL" \
    --rebuild
echo "=== Done ==="
