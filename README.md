# Driven Agent Development

A skill-driven protocol for AI coding agents (Claude Code, Kiro, etc.).
Instead of improvising, the agent consults a library of skills before acting.
Every commit is tracked at the diff-hunk level and stored in a searchable memory.

---

## Quick Start

Run the installer once in any project:

```bash
bash setup.sh
```

This generates:
- `skills/` — all base skills with their `SKILL.md` definitions
- `.agent/` — memory infrastructure (scripts, Chroma config, `memory.jsonl`)
- `.git/hooks/post-commit` — symlink to `skills/commit/assets/post-commit.sh`
- `CLAUDE.md` — agent context file wiring everything together

---

## How the Agent Works

The agent follows a **skill-first protocol** defined in `CLAUDE.md`:

1. **Match** — scan the Auto-Invoke table for the current task trigger
2. **Lookup** — find the relevant skill in the Available Skills table
3. **Load** — read the skill's `SKILL.md` before generating any output
4. **Execute** — follow the skill instructions exactly

If no skill applies, the agent declares: _"Skill gap detected. Proceeding via general knowledge."_

---

## Base Skills

| Skill | Trigger | Purpose |
|-------|---------|---------|
| `commit` | Before any git commit | Enforces Conventional Commits format with sensitive file guard |
| `changelog` | After committing a feat/fix/sec/refactor | Maintains `CHANGELOG.md` following keepachangelog.com |
| `scan-memory` | First-time setup, after major refactors | Scans Java source tree and populates `memory.jsonl` with symbol locations |
| `query-memory` | Search codebase by intent or behavior | Semantic search via ChromaDB with automatic JSONL fallback |
| `openapi` | After adding/modifying/deleting any endpoint | Keeps `api/openapi.yaml` in sync with Spring controllers |
| `endpoint-trace` | Documenting a new endpoint | Generates code-level call chain docs in `docs/traces/` |
| `feature-docs` | After completing an endpoint in openapi.yaml | Generates usage-flow docs in `docs/features/` |
| `skill-creator` | Creating a new agent skill | Scaffolds a new `SKILL.md` following the project spec |
| `skill-sync` | After creating or modifying any skill | Rebuilds the Available Skills and Auto-Invoke tables in `CLAUDE.md` |
| `find-skills` | Looking for a skill that does X | Discovers and installs skills from the registry |

---

## Memory System

Every commit is recorded in `.agent/memory.jsonl` and synced to ChromaDB.
There are two record types:

### `symbol` — Java code locations (from `scan-memory`)

Written manually by the agent when scanning `src/main/java`. Contains:
- Class/method name, file path, line range
- One-sentence intent, tags, git hash, date

### `change` — Git diff hunks (from post-commit hook)

Written automatically after every commit. One record per diff hunk:
- `change_type`: `addition` | `deletion` | `modification`
- `hunk_header`: the `@@ -X,Y +A,B @@` line from the diff
- `hunk_content`: exact added/removed lines
- `lines_start`, `lines_end`, `lines_delta`
- `intent`: the commit message subject
- `author`, `email`, `commit`, `ts`

Records are **append-only** — history is never rewritten.

---

## Sync Architecture

```
git commit
    │
    └─► post-commit hook
            │
            ├─ Pass 1: sync-hunks.py
            │   Parses git diff --unified=0 HEAD~1 HEAD
            │   One record per hunk → appended to .agent/memory.jsonl
            │
            ├─ Pass 2: sync-memory.py  (Java files only)
            │   Updates symbol line ranges when lines shift
            │
            └─ sync-to-chroma.py
                Pushes all entries to ChromaDB via HTTP
                ID scheme:
                  change  → change:{commit}:{file}:{lines_start}
                  symbol  → symbol:{file}:{symbol}
```

### Local fallback

If ChromaDB is not running, `query-memory.py` falls back automatically to
keyword search over `memory.jsonl` — no configuration needed.

---

## Querying Memory

```bash
# Semantic search (Chroma required)
python3 .agent/scripts/query-memory.py "handles cross-account role assumption"

# Keyword fallback (always available)
python3 .agent/scripts/query-memory.py "account onboarding" --no-chroma

# Filter by record type
python3 .agent/scripts/query-memory.py "auth refactor" --type change
python3 .agent/scripts/query-memory.py "StsClient" --type symbol

# Filter by file kind
python3 .agent/scripts/query-memory.py "docker" --kind config

# Limit results
python3 .agent/scripts/query-memory.py "pagination" --limit 5
```

---

## ChromaDB Setup

ChromaDB runs locally via Docker:

```bash
cd .agent/chroma
docker compose up -d
```

Default URL: `http://localhost:8000`. Override with `CHROMA_URL` env var:

```bash
CHROMA_URL=http://myhost:8000 bash .agent/scripts/bootstrap.sh
```

Bootstrap (re-sync all JSONL entries to Chroma from scratch):

```bash
bash .agent/scripts/bootstrap.sh
```

---

## Adding a New Skill

```bash
# Let the agent scaffold it
# Trigger: "Creating a new skill" → loads skill-creator
```

Or manually: create `skills/<name>/SKILL.md` following the spec in
`skills/skill-creator/SKILL.md`, then run:

```bash
bash skills/skill-sync/assets/sync.sh
```

This rebuilds the Available Skills and Auto-Invoke tables in `CLAUDE.md`.

---

## File Layout

```
.
├── setup.sh                    # Installer — run once per project
├── CLAUDE.md                   # Agent context (auto-updated by skill-sync)
├── skills/
│   ├── commit/
│   │   ├── SKILL.md
│   │   └── assets/
│   │       └── post-commit.sh  # Git hook (symlinked from .git/hooks/)
│   ├── scan-memory/SKILL.md
│   ├── query-memory/SKILL.md
│   └── ...
└── .agent/
    ├── memory.jsonl             # Append-only change history (committed)
    ├── chroma/
    │   └── docker-compose.yml
    └── scripts/
        ├── scan.sh              # Java symbol scanner
        ├── sync-hunks.py        # Hunk-level change recorder
        ├── sync-memory.py       # Java symbol line updater
        ├── sync-to-chroma.py    # JSONL → ChromaDB pusher
        ├── query-memory.py      # Search CLI
        └── bootstrap.sh         # Full re-sync to Chroma
```
