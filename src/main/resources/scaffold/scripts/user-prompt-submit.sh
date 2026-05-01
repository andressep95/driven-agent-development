#!/usr/bin/env bash
# Hook UserPromptSubmit — Driven Agent Development
#
# 1. Queries Chroma 'skills' collection to find the best skill for the task
# 2. Queries Chroma 'changes' collection for prior project context
# 3. Injects both as additionalContext — the agent starts informed
#
# Input:  JSON on stdin  { "session_id": "…", "prompt": "…", … }
# Output: JSON on stdout { "hookSpecificOutput": { ... "additionalContext": "…" } }

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
CHROMA_PATH="$ROOT/.agents/memory/chroma"
QUERY_SCRIPT="$SCRIPT_DIR/query-memory.py"

INPUT=$(cat)
PROMPT=$(echo "$INPUT" | python3 -c "import sys,json; print(json.load(sys.stdin).get('prompt',''))" 2>/dev/null)

if [ -z "$PROMPT" ]; then
  echo '{}'
  exit 0
fi

HAS_CHROMA=false
python3 -c "import chromadb" &>/dev/null && HAS_CHROMA=true

# ── 1. Find matching skill via Chroma semantic search ─────────────────────
SKILL_CTX=""
if [ "$HAS_CHROMA" = true ]; then
  SKILL_CTX=$(python3 -c "
import chromadb
from chromadb.utils import embedding_functions
import sys

try:
    client = chromadb.PersistentClient(path='$CHROMA_PATH')
    ef = embedding_functions.DefaultEmbeddingFunction()
    col = client.get_collection('skills', embedding_function=ef)
    r = col.query(query_texts=[sys.argv[1]], n_results=1)
    if r['ids'][0]:
        dist = r['distances'][0][0] if r.get('distances') else 1
        score = max(0, 1 - dist)
        if score >= 0.25:
            name = r['metadatas'][0][0]['name']
            print(f'## Relevant Skill: {name}')
            print(f'Load and follow: .agents/skills/{name}/SKILL.md')
            print(f'Match confidence: {score:.0%}')
except Exception:
    pass
" "$PROMPT" 2>/dev/null || true)
fi

# ── 2. Query Chroma for prior context ─────────────────────────────────────
MEMORY=""
if [ "$HAS_CHROMA" = true ] && [ -f "$QUERY_SCRIPT" ]; then
  MEMORY=$(python3 "$QUERY_SCRIPT" "$PROMPT" --limit 5 2>/dev/null || true)
fi

# ── 3. Build additionalContext ────────────────────────────────────────────
CTX=""

if [ -n "$SKILL_CTX" ]; then
  CTX="$SKILL_CTX
"
fi

if [ -n "$MEMORY" ]; then
  CTX="${CTX}
## Prior Context from Memory (Chroma)
The following changes were previously made in this project and are relevant to the current task:

$MEMORY"
fi

if [ -z "$CTX" ]; then
  echo '{}'
  exit 0
fi

# ── 4. Return JSON ───────────────────────────────────────────────────────
python3 -c "
import json, sys
ctx = sys.stdin.read()
print(json.dumps({
    'hookSpecificOutput': {
        'hookEventName': 'UserPromptSubmit',
        'additionalContext': ctx
    }
}))
" <<< "$CTX"
