---
name: query-memory
description: >
  Searches agent memory by semantic similarity via ChromaDB.
  Trigger: Search codebase symbols by intent or behavior rather than exact name.
metadata:
  version: "2.0"
  scope: [root]
  auto_invoke:
    - "Search codebase by intent or behavior"
    - "Semantic search over agent memory"
    - "Find symbols by description"
    - "Query ChromaDB for code symbols"
allowed-tools: Bash
---

## When to Use

Prefer `query-memory` for semantic searches when:
- Searching by **behavior or intent** ("find the class that handles retries")
- The symbol name is unknown but its purpose is known

> **Note:** This skill is auto-invoked by the `UserPromptSubmit` hook before
> every task. You rarely need to call it manually — the context is already
> injected. Use it explicitly only for follow-up or narrower queries.

---

## Commands

```bash
# Semantic query via Chroma
python3 .agents/scripts/query-memory.py "handles cross-account role assumption"

# Filter by kind: controller, service, repository, config, dto, domain
python3 .agents/scripts/query-memory.py "account onboarding" --kind service

# Limit results
python3 .agents/scripts/query-memory.py "pagination helpers" --limit 5
```

---

## Output Format

```
## ClassName (kind)
   File: src/main/java/...
   Lines: 14-120
   Intent: One-sentence description of what it does
   Score: 87.42%       ← cosine similarity score
```

---

## Memory Must Be Populated

Before querying, ensure memory exists:

```bash
# Full init: scan git history into Chroma
bash .agents/scripts/init.sh
```

Run `scan-memory` if the Chroma collection is empty.
