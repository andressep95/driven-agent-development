#!/usr/bin/env bash
# Replays full git history into memory.jsonl for ALL tracked file types.
# Each commit is diffed and its hunks appended as change records.
# Idempotent: duplicate (commit, file, hunk) entries are skipped.
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
cd "$ROOT"

JSONL=".agent/memory.jsonl"
EMPTY_TREE="4b825dc642cb6eb9a060e54bf8d69288fbee4904"

total=$(git log --oneline | wc -l | tr -d ' ')
echo "Replaying $total commits into $JSONL..."

count=0
while IFS=' ' read -r full_hash short_hash; do
    count=$((count + 1))
    printf "  [%d/%d] %s\r" "$count" "$total" "$short_hash"

    # Use empty tree for the initial commit (no parent)
    parent=$(git rev-parse --verify "${full_hash}~1" 2>/dev/null || echo "$EMPTY_TREE")

    added=$(git diff --diff-filter=A --name-only "$parent" "$full_hash" 2>/dev/null || true)
    deleted=$(git diff --diff-filter=D --name-only "$parent" "$full_hash" 2>/dev/null || true)
    modified=$(git diff --diff-filter=M --name-only "$parent" "$full_hash" 2>/dev/null || true)

    python3 "$SCRIPT_DIR/sync-hunks.py" \
        --jsonl "$JSONL" \
        --from-commit "$parent" \
        --to-commit "$full_hash" \
        --added "$added" \
        --deleted "$deleted" \
        --modified "$modified" \
        --all-files \
        2>/dev/null || true
done < <(git log --reverse --format="%H %h")

echo ""
echo "Done. $count commits processed."
