---
name: scan-memory
description: >
  Scans the full git history and indexes change records directly into
  ChromaDB for semantic search. Trigger: First-time setup, empty Chroma,
  after major refactors.
metadata:
  version: "3.0"
  scope: [root]
  auto_invoke:
    - "First-time project setup"
    - "After a major refactor affecting multiple files"
    - "Bootstrap agent memory"
    - "Chroma collection is empty"
    - "Inicializar memoria del agente"
    - "Escanear historial de git"
    - "La memoria está vacía o falta"
allowed-tools: Read, Bash, Write
---

## Purpose

Bootstraps ChromaDB by replaying the full git history. Each diff hunk
becomes a record with intent, what/why, semantic description, tags, and
author metadata. Uses `extract_changes.py` — the same extractor invoked
by the post-commit hook — so the schema is always consistent.

Git is the source of truth. Chroma is the search layer.

## When to Run

- First time any dev (or agent) clones the project
- Chroma collection is empty or returns no results
- After a large refactor that moves or renames multiple files

---

## Commands

```bash
# Full bootstrap: replay git history + index skills
bash .agents/scripts/init.sh

# Replay history only
bash .agents/scripts/scan-history.sh

# Re-index skills only
python3 .agents/scripts/sync-skills-to-chroma.py
```

Idempotent — duplicate records (matched by commit + file + lines_start) are skipped.

---

## Verify

```bash
python3 .agents/scripts/query-memory.py "KEYWORDS"
```

---

## Record Schema

Every record indexed into Chroma includes:

| Metadata field | Purpose |
|----------------|---------|
| `what` / `why` | Parsed from commit body — feeds semantic search |
| `intent` | Commit subject line |
| `author` / `ts` | Who made the change and when |
| `file` / `lines_start` / `lines_end` | Exact location |
| `language` / `file_kind` | Auto-detected from extension |
| `commit` / `branch` | Git reference for `git show` |
| `tags` | Composite of commit_type, change_type, kind, scope |
