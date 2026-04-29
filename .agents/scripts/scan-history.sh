#!/usr/bin/env bash
# Replays full git history into memory.jsonl using extract_changes.py.
# Each commit is processed with the same extractor used by the post-commit hook.
# Idempotent: duplicate (commit, file, hunk) entries are skipped.
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
cd "$ROOT"

PYTHON=""
for cmd in python3 python py; do
    if command -v "$cmd" &>/dev/null && "$cmd" -c "import sys; sys.exit(0)" 2>/dev/null; then
        PYTHON="$cmd"
        break
    fi
done
if [ -z "$PYTHON" ]; then
    echo "ERROR: Python not found. Install Python and ensure it's on your PATH."
    exit 1
fi

JSONL=".agents/memory/memory.jsonl"
mkdir -p "$(dirname "$JSONL")"

total=$(git log --oneline | wc -l | tr -d ' ')
echo "Replaying $total commits into $JSONL..."

count=0
while IFS=' ' read -r full_hash _; do
    count=$((count + 1))
    printf "  [%d/%d] %s\r" "$count" "$total" "${full_hash:0:7}"

    "$PYTHON" "$SCRIPT_DIR/extract_changes.py" --ref "$full_hash" 2>/dev/null || true
done < <(git log --reverse --format="%H %h")

echo ""
echo "Done. $count commits processed."
