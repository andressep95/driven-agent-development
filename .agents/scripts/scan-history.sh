#!/usr/bin/env bash
# Replays full git history into Chroma using extract_changes.py.
# Idempotent: duplicate (commit, file, lines_start) entries are skipped.
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
cd "$ROOT"

total=$(git log --oneline | wc -l | tr -d ' ')
echo "Replaying $total commits into Chroma..."

count=0
while IFS=' ' read -r full_hash _; do
    count=$((count + 1))
    printf "  [%d/%d] %s\r" "$count" "$total" "${full_hash:0:7}"
    python3 "$SCRIPT_DIR/extract_changes.py" --ref "$full_hash" 2>/dev/null || true
done < <(git log --reverse --format="%H %h")

echo ""
echo "Done. $count commits processed."
