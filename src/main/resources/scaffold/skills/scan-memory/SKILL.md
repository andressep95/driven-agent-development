---
name: scan-memory
description: >
  Scans the full git history and optionally Java symbols to populate
  .agents/memory/memory.jsonl with change records for every tracked file type
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

Bootstraps `.agents/memory/memory.jsonl` by replaying the full git history.
Each diff hunk becomes a `change` record with intent, what/why, semantic
description, tags, and author metadata. Uses `extract_changes.py` — the same
extractor invoked by the post-commit hook — so the schema is always consistent.

## When to Run

- First time any dev (or agent) clones the project
- `memory.jsonl` is empty or returns no results
- After a large refactor that moves or renames multiple files
- Manually triggered: `bash .agents/scripts/init.sh`

---

## Step-by-Step Procedure

### Step 1 — Replay full git history

```bash
bash .agents/scripts/scan-history.sh
```

This iterates every commit from the beginning of the repo and runs
`extract_changes.py --ref <commit>` for each one. It is idempotent —
records already in `memory.jsonl` (matched by commit + file + hunk
header) are skipped.

### Step 2 — (Shortcut) Bootstrap + Chroma sync

```bash
bash .agents/scripts/init.sh
```

`init.sh` runs `scan-history.sh` → `sync-to-chroma.py` in sequence.

### Step 3 — Sync to Chroma (optional)

If ChromaDB is running, push memory to the vector search index:

```bash
python3 .agents/scripts/sync-to-chroma.py
```

Skip this step if ChromaDB is not available — JSONL keyword search remains fully functional.

### Step 4 — Verify

```bash
python3 .agents/scripts/query-memory.py "KEYWORDS" --type change --no-chroma
```

---

## Record Schema

Every record is produced by `extract_changes.py` and includes:

| Field | Purpose |
|-------|---------|
| `what` / `why` | Parsed from commit body — feeds semantic search |
| `semantic_description` | Composite of what + why + intent for embeddings |
| `language` | Auto-detected from file extension |
| `related_files` | Other files changed in the same commit |
| `breaking` | Parsed from commit body |

---

## How the Agent Uses Memory

```bash
# Semantic search (requires Chroma)
python3 .agents/scripts/query-memory.py "KEYWORDS"

# Keyword fallback (always available)
python3 .agents/scripts/query-memory.py "KEYWORDS" --no-chroma

# Filter by type
python3 .agents/scripts/query-memory.py "KEYWORDS" --type change
```

---

## Git Rules

- `memory.jsonl` → committed (portable source of truth, append-only history)
- No SQLite DB — persistence is JSONL + Chroma only
