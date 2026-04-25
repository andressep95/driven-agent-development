#!/usr/bin/env bash
# Git post-commit hook: syncs memory.jsonl for all tracked file types.
# Java files  → sync-memory.py  (line-level diff precision)
# Other files → sync-files.py   (.md, .sh, .py, .yaml, .yml, .sql, .json)
set -uo pipefail

AGENT_DIR=".agent"
JSONL="$AGENT_DIR/memory.jsonl"
CHROMA_URL="${CHROMA_URL:-http://localhost:8000}"

[ -f "$JSONL" ] || exit 0
! git rev-parse HEAD~1 >/dev/null 2>&1 && exit 0

# Java files
JAVA_ADDED=$(git diff --name-only --diff-filter=A HEAD~1 HEAD 2>/dev/null | grep '\.java$' || true)
JAVA_DELETED=$(git diff --name-only --diff-filter=D HEAD~1 HEAD 2>/dev/null | grep '\.java$' || true)
JAVA_MODIFIED=$(git diff --name-only --diff-filter=M HEAD~1 HEAD 2>/dev/null | grep '\.java$' || true)

# Non-Java tracked files
OTHER_ADDED=$(git diff --name-only --diff-filter=A HEAD~1 HEAD 2>/dev/null \
    | grep -E '\.(md|sh|py|yaml|yml|sql|json)$' \
    | grep -v 'memory\.jsonl\|memory\.db' || true)
OTHER_DELETED=$(git diff --name-only --diff-filter=D HEAD~1 HEAD 2>/dev/null \
    | grep -E '\.(md|sh|py|yaml|yml|sql|json)$' \
    | grep -v 'memory\.jsonl\|memory\.db' || true)
OTHER_MODIFIED=$(git diff --name-only --diff-filter=M HEAD~1 HEAD 2>/dev/null \
    | grep -E '\.(md|sh|py|yaml|yml|sql|json)$' \
    | grep -v 'memory\.jsonl\|memory\.db' || true)

HAS_JAVA=$([ -n "$JAVA_ADDED$JAVA_DELETED$JAVA_MODIFIED" ] && echo 1 || true)
HAS_OTHER=$([ -n "$OTHER_ADDED$OTHER_DELETED$OTHER_MODIFIED" ] && echo 1 || true)

[ -z "${HAS_JAVA}${HAS_OTHER}" ] && exit 0

echo "[memory] Files changed — syncing..."

if [ -n "${HAS_JAVA}" ]; then
    python3 "$AGENT_DIR/scripts/sync-memory.py" \
        --jsonl    "$JSONL" \
        --added    "$JAVA_ADDED" \
        --deleted  "$JAVA_DELETED" \
        --modified "$JAVA_MODIFIED"
fi

if [ -n "${HAS_OTHER}" ]; then
    python3 "$AGENT_DIR/scripts/sync-files.py" \
        --jsonl    "$JSONL" \
        --added    "$OTHER_ADDED" \
        --deleted  "$OTHER_DELETED" \
        --modified "$OTHER_MODIFIED"
fi

python3 "$AGENT_DIR/scripts/sync-to-chroma.py" --url "$CHROMA_URL" 2>&1 | tail -1
