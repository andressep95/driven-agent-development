#!/usr/bin/env bash
# Git post-commit hook: syncs memory.jsonl with changed Java files to Chroma.
set -uo pipefail

AGENT_DIR=".agent"
JSONL="$AGENT_DIR/memory.jsonl"
CHROMA_URL="${CHROMA_URL:-http://localhost:8000}"

[ -f "$JSONL" ] || exit 0
! git rev-parse HEAD~1 >/dev/null 2>&1 && exit 0

ADDED=$(git diff --name-only --diff-filter=A HEAD~1 HEAD 2>/dev/null | grep '\.java$' || true)
DELETED=$(git diff --name-only --diff-filter=D HEAD~1 HEAD 2>/dev/null | grep '\.java$' || true)
MODIFIED=$(git diff --name-only --diff-filter=M HEAD~1 HEAD 2>/dev/null | grep '\.java$' || true)

[ -z "$ADDED$DELETED$MODIFIED" ] && exit 0

echo "[memory] Java files changed — syncing to Chroma..."

python3 "$AGENT_DIR/scripts/sync-memory.py" \
    --jsonl  "$JSONL" \
    --added    "$ADDED" \
    --deleted  "$DELETED" \
    --modified "$MODIFIED"

python3 "$AGENT_DIR/scripts/sync-to-chroma.py" --url "$CHROMA_URL" 2>&1 | tail -1
