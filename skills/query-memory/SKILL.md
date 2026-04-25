---
name: query-memory
description: >
  Searches agent memory by semantic similarity (ChromaDB) with automatic
  fallback to keyword search over memory.jsonl when Chroma is unavailable.
  Trigger: Search codebase symbols by intent or behavior rather than exact name.
metadata:
  version: "1.0"
  scope: [root]
  auto_invoke:
    - "Search codebase by intent or behavior"
    - "Semantic search over agent memory"
    - "Find symbols by description"
    - "Query ChromaDB for code symbols"
allowed-tools: Bash
---

## When to Use

Prefer `query-memory` over SQLite FTS when:
- Searching by **behavior or intent** ("find the class that handles retries")
- The symbol name is unknown but its purpose is known
- Keyword search returns no results or too many irrelevant ones

Use SQLite FTS directly when you need exact keyword or file path matching.

---

## Commands

```bash
# Semantic query — uses Chroma if available, falls back to JSONL automatically
python3 .agent/scripts/query-memory.py "handles cross-account role assumption"

# Filter by kind: controller, service, repository, config, dto, domain
python3 .agent/scripts/query-memory.py "account onboarding" --kind service

# Limit results
python3 .agent/scripts/query-memory.py "pagination helpers" --limit 5

# Force JSONL-only (skip Chroma entirely)
python3 .agent/scripts/query-memory.py "credential caching" --no-chroma

# Custom Chroma URL
python3 .agent/scripts/query-memory.py "error handling" --url http://localhost:8000
```

---

## Fallback Behavior

The script auto-detects Chroma availability at query time:

| Chroma status | Behavior |
|---------------|----------|
| Running | Semantic vector search (ranked by embedding similarity) |
| Down / not installed | Keyword search over `.agent/memory.jsonl` |

No configuration needed — the fallback is transparent.

---

## Output Format

```
## ClassName (kind)
   File: src/main/java/...
   Lines: 14-120
   Intent: One-sentence description of what it does
   Score: 87.42%       ← similarity score (Chroma) or keyword matches (JSONL)
```

---

## Memory Must Be Populated

Before querying, ensure memory exists:

```bash
# Full bootstrap: scan Java files + push to Chroma
bash .agent/scripts/bootstrap.sh

# Or push existing memory.jsonl to Chroma only
python3 .agent/scripts/sync-to-chroma.py
```

Run `scan-memory` if `memory.jsonl` is empty or missing.
