#!/usr/bin/env bash
# Git post-commit hook — two passes:
#   1. sync-hunks.py  : hunk-level change records for ALL tracked file types
#   2. sync-memory.py : Java symbol location updates (line shifts after edits)
# Both write to memory.jsonl; sync-to-chroma.py pushes everything to Chroma.
set -uo pipefail

AGENT_DIR=".agent"
JSONL="$AGENT_DIR/memory.jsonl"
CHROMA_URL="${CHROMA_URL:-http://localhost:8000}"

[ -f "$JSONL" ] || exit 0
! git rev-parse HEAD~1 >/dev/null 2>&1 && exit 0

# All tracked file types for hunk tracking
ALL_ADDED=$(git diff --name-only --diff-filter=A HEAD~1 HEAD 2>/dev/null \
    | grep -E '\.(java|md|sh|py|yaml|yml|sql|json)$' \
    | grep -v 'memory\.jsonl\|memory\.db' || true)
ALL_DELETED=$(git diff --name-only --diff-filter=D HEAD~1 HEAD 2>/dev/null \
    | grep -E '\.(java|md|sh|py|yaml|yml|sql|json)$' \
    | grep -v 'memory\.jsonl\|memory\.db' || true)
ALL_MODIFIED=$(git diff --name-only --diff-filter=M HEAD~1 HEAD 2>/dev/null \
    | grep -E '\.(java|md|sh|py|yaml|yml|sql|json)$' \
    | grep -v 'memory\.jsonl\|memory\.db' || true)

# Java-only for symbol location tracking
JAVA_ADDED=$(echo "$ALL_ADDED"    | grep '\.java$' || true)
JAVA_DELETED=$(echo "$ALL_DELETED"  | grep '\.java$' || true)
JAVA_MODIFIED=$(echo "$ALL_MODIFIED" | grep '\.java$' || true)

HAS_ANY=$([ -n "$ALL_ADDED$ALL_DELETED$ALL_MODIFIED" ] && echo 1 || true)
HAS_JAVA=$([ -n "$JAVA_ADDED$JAVA_DELETED$JAVA_MODIFIED" ] && echo 1 || true)

[ -z "${HAS_ANY}" ] && exit 0

echo "[memory] Syncing changes..."

# Pass 1 — hunk records for all file types
python3 "$AGENT_DIR/scripts/sync-hunks.py" \
    --jsonl    "$JSONL" \
    --added    "$ALL_ADDED" \
    --deleted  "$ALL_DELETED" \
    --modified "$ALL_MODIFIED"

# Pass 2 — Java symbol location updates only
if [ -n "${HAS_JAVA}" ]; then
    python3 "$AGENT_DIR/scripts/sync-memory.py" \
        --jsonl    "$JSONL" \
        --added    "$JAVA_ADDED" \
        --deleted  "$JAVA_DELETED" \
        --modified "$JAVA_MODIFIED"
fi

python3 "$AGENT_DIR/scripts/sync-to-chroma.py" --url "$CHROMA_URL" 2>&1 | tail -1
echo "[memory] Changes persisted in git + JSONL + Chroma — safe to compact context."
echo "         Claude Code → /compact  |  Kiro → /compact"
