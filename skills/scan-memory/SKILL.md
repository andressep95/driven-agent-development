---
name: scan-memory
description: >
  Scans the full git history and optionally Java symbols to populate
  .agent/memory.jsonl with change records for every tracked file type
  (.java, .md, .sh, .py, .yaml, .yml, .sql, .json). Syncs to ChromaDB
  for semantic search. Trigger: First-time setup, memory.jsonl missing
  or empty, after major refactors.
metadata:
  version: "2.0"
  scope: [root]
  auto_invoke:
    - "memory.jsonl is empty or missing"
    - "First-time project setup"
    - "After a major refactor affecting multiple files"
    - "Bootstrap agent memory"
allowed-tools: Read, Bash, Write
---

## Purpose

Bootstraps `.agent/memory.jsonl` by replaying the full git history for
**all tracked file types** — not just Java. Each diff hunk becomes a
`change` record with intent, tags, and author metadata. Optionally also
scans Java symbol definitions for `symbol` records.

**Tracked extensions:** `.java` `.md` `.sh` `.py` `.yaml` `.yml` `.sql` `.json`

## When to Run

- First time any dev (or agent) clones the project
- `memory.jsonl` is empty or returns no results
- After a large refactor that moves or renames multiple files
- When onboarding a non-Java project (Python, TypeScript, Go, etc.)
- Manually triggered: `bash .agent/scripts/bootstrap.sh`

---

## Step-by-Step Procedure

### Step 1 — Replay full git history (all file types)

```bash
bash .agent/scripts/scan-history.sh
```

This iterates every commit from the beginning of the repo and writes
one `change` record per hunk for each tracked file. It is idempotent —
records already in `memory.jsonl` (matched by commit + file + hunk
header) are skipped.

### Step 2 — (Optional) Scan Java symbols

Only needed when the project has a `src/main/java` tree:

```bash
bash .agent/scripts/scan.sh
```

### Step 3 — (Shortcut) Run both steps at once

```bash
bash .agent/scripts/bootstrap.sh
```

`bootstrap.sh` runs `scan-history.sh` → `scan.sh` (if Java exists) →
`sync-to-chroma.py` in sequence.

### Step 4 — Sync to Chroma (optional)

If ChromaDB is running, push memory to the vector search index:

```bash
python3 .agent/scripts/sync-to-chroma.py --url "\${CHROMA_URL:-http://localhost:8000}"
```

Skip this step if ChromaDB is not available — JSONL keyword search remains fully functional.

### Step 5 — Verify

```bash
python3 .agent/scripts/query-memory.py "KEYWORDS" --type change --no-chroma
python3 .agent/scripts/query-memory.py "account" --type symbol --no-chroma
```

---

## Record Types

| type | Produced by | Contains |
|------|-------------|----------|
| \`change\` | \`scan-history.sh\` / post-commit hook | git diff hunks for any file type |
| \`symbol\` | \`scan.sh\` (Java only) | class/method definitions with line ranges |

---

## How the Agent Uses Memory

```bash
# Semantic search (requires Chroma)
python3 .agent/scripts/query-memory.py "KEYWORDS"

# Keyword fallback (always available)
python3 .agent/scripts/query-memory.py "KEYWORDS" --no-chroma

# Filter by type
python3 .agent/scripts/query-memory.py "KEYWORDS" --type symbol   # Java symbols
python3 .agent/scripts/query-memory.py "KEYWORDS" --type change   # git history
```

---

## Git Rules

- `memory.jsonl` → committed (portable source of truth, append-only history)
- No SQLite DB — persistence is JSONL + Chroma only
