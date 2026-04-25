---
name: scan-memory
description: >
  Scans the Java project and populates .agent/memory.jsonl with symbol locations,
  intent summaries, and tags. Ends by running rebuild.sh to produce a queryable memory.db.
  Trigger: First-time setup, memory.db missing or empty, after major refactors.
metadata:
  version: "1.0"
  scope: [root]
  auto_invoke:
    - "memory.db is empty or missing"
    - "First-time project setup"
    - "After a major refactor affecting multiple files"
    - "Bootstrap agent memory"
allowed-tools: Read, Bash, Write
---

## Purpose

Bootstraps `.agent/memory.jsonl` by scanning every Java file in `src/main/java`,
reading each symbol's code, generating a one-sentence `intent`, assigning `tags`,
and writing structured JSONL entries. Ends by running `rebuild.sh` to produce
a queryable `memory.db`.

## When to Run

- First time any dev (or agent) clones the project
- `memory.db` is missing or returns no results
- After a large refactor that moves or renames multiple files
- Manually triggered: `bash .agent/scripts/scan.sh`

---

## Step-by-Step Procedure

### Step 1 — Run the mechanical scan

```bash
bash .agent/scripts/scan.sh
```

### Step 2 — For each symbol, read and summarize

Generate:
- `intent` — one sentence: what does it do?
- `tags` — JSON array from: controller, service, repository, domain, config, dto,
  util, aws, sts, s3, account, discovery, resource, shared, auth, validation,
  error-handling, pagination, caching, credentials

### Step 3 — Write JSONL entries to `.agent/memory.jsonl`

```jsonl
{"type":"symbol","file":"path/to/File.java","symbol":"ClassName","kind":"controller","lines":[14,120],"intent":"one sentence","tags":["controller","account"],"commit":"GIT_HASH","ts":"YYYY-MM-DD"}
```

### Step 4 — Sync to Chroma (optional)

If ChromaDB is running, push memory to the vector search index:

```bash
bash .agent/scripts/bootstrap.sh
# or directly:
python3 .agent/scripts/sync-to-chroma.py --url "${CHROMA_URL:-http://localhost:8000}"
```

Skip this step if ChromaDB is not available — SQLite FTS remains fully functional.

### Step 5 — Verify

```bash
python3 .agent/scripts/query-memory.py "account" --type symbol --no-chroma
```

---

## How the Agent Uses Memory

```bash
# Semantic search (requires Chroma)
python3 .agent/scripts/query-memory.py "KEYWORDS"

# Keyword fallback (always available)
python3 .agent/scripts/query-memory.py "KEYWORDS" --no-chroma

# Filter by type
python3 .agent/scripts/query-memory.py "KEYWORDS" --type symbol   # Java code
python3 .agent/scripts/query-memory.py "KEYWORDS" --type change   # git history
```

---

## Git Rules

- `memory.jsonl` → committed (portable source of truth, append-only history)
- No SQLite DB — persistence is JSONL + Chroma only
