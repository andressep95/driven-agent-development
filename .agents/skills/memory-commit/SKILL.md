---
name: memory-commit
description: "ALWAYS ACTIVE — Before every commit, analyze the diff and write a structured message with what/why to feed the RAG memory system."
---

# Memory Commit — Protocol

Follow this protocol before every commit. Do not skip it even for small changes.

## STEP 1 — Analyze the staged diff

Run `git diff --staged` and for each file identify:
- Which function or section was modified (`symbol`)
- What the code does now that it didn't before (`what`)
- Why the change was necessary (`why`)

## STEP 2 — Write the commit with structured body

Required format:

```
<type>(<scope>): <subject>

what: <one sentence — what the code does now>
why: <one sentence — why it was necessary>
breaking: <true|false>
```

### Valid types
`feat` · `fix` · `refactor` · `perf` · `style` · `test` · `docs` · `chore` · `sec`

### Rules for `what`
- One sentence describing the new behavior
- Do not mention file names or line numbers — the hook captures those
- ❌ BAD:  `fix bug in auth`
- ✅ GOOD: `Replaces individual queries with batch query in getUserList`

### Rules for `why`
- One sentence explaining the motivation
- This is the most important field for future semantic search
- Must answer: what problem does it solve? what constraint does it meet?
- ❌ BAD:  `because it was broken`
- ✅ GOOD: `Previous version made N DB roundtrips, one per user — O(n) instead of O(1)`

### `breaking: true` only when
- A public function signature changes
- An endpoint or API field is removed
- Observable behavior of an existing feature changes

## STEP 3 — Execute the commit

```bash
git commit -m "$(cat <<'EOF'
feat(auth): implement JWT RS256 token generation

what: Generates JWT tokens signed with RS256 using a rotatable private key
why: RS256 allows client services to verify tokens without knowing the private key
breaking: false
EOF
)"
```

The post-commit hook handles the rest automatically.

## WELL-FORMED COMMIT EXAMPLES

```
fix(db): replace N+1 queries with batch fetch in getUserList

what: Replaces individual query loop with a single IN-clause query
why: Previous version made one DB roundtrip per user, O(n) instead of O(1)
breaking: false
```

```
refactor(cache): extract Redis client into singleton with connection pooling

what: Centralizes Redis connection in a configurable pool singleton
why: Each handler was creating its own connection, exhausting the pool under load
breaking: false
```
