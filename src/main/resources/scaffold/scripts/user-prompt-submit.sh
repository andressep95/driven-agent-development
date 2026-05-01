#!/usr/bin/env bash
# Hook UserPromptSubmit — Driven Agent Development
#
# Reads the user prompt, finds the relevant skill, queries Chroma for
# prior context, and returns both as additionalContext so the agent
# starts every task with precise, project-specific information.
#
# Input:  JSON on stdin  { "session_id": "…", "prompt": "…", … }
# Output: JSON on stdout { "hookSpecificOutput": { "hookEventName": "UserPromptSubmit", "additionalContext": "…" } }

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
SKILLS_DIR="$ROOT/.agents/skills"
QUERY_SCRIPT="$SCRIPT_DIR/query-memory.py"

INPUT=$(cat)
PROMPT=$(echo "$INPUT" | python3 -c "import sys,json; print(json.load(sys.stdin).get('prompt',''))" 2>/dev/null)

if [ -z "$PROMPT" ]; then
  echo '{}'
  exit 0
fi

# ── 1. Find matching skill ────────────────────────────────────────────────
SKILL_MATCH=""
SKILL_FILE=""

if [ -d "$SKILLS_DIR" ]; then
  PROMPT_LOWER=$(echo "$PROMPT" | tr '[:upper:]' '[:lower:]')
  BEST_SCORE=0

  for skill_dir in "$SKILLS_DIR"/*/; do
    [ -f "${skill_dir}SKILL.md" ] || continue
    skill_name=$(basename "$skill_dir")

    # skip meta-skills that the hook itself would trigger
    case "$skill_name" in query-memory|scan-memory|skill-sync|find-skills) continue;; esac

    # build searchable text from the SKILL.md header (first 30 lines)
    header=$(head -30 "${skill_dir}SKILL.md" | tr '[:upper:]' '[:lower:]')

    score=0
    for word in $PROMPT_LOWER; do
      [ ${#word} -lt 4 ] && continue
      echo "$header" | grep -qF "$word" && score=$((score + 1))
    done

    if [ "$score" -gt "$BEST_SCORE" ]; then
      BEST_SCORE=$score
      SKILL_MATCH=$skill_name
      SKILL_FILE="${skill_dir}SKILL.md"
    fi
  done
fi

# ── 2. Query Chroma for prior context ─────────────────────────────────────
MEMORY=""
if [ -f "$QUERY_SCRIPT" ] && python3 -c "import chromadb" &>/dev/null; then
  MEMORY=$(python3 "$QUERY_SCRIPT" "$PROMPT" --limit 5 2>/dev/null || true)
fi

# ── 3. Build additionalContext ────────────────────────────────────────────
CTX=""

if [ -n "$SKILL_MATCH" ] && [ "$BEST_SCORE" -ge 2 ]; then
  CTX="## Relevant Skill: $SKILL_MATCH
Load and follow: .agents/skills/$SKILL_MATCH/SKILL.md
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
