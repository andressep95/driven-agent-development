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
| `scan-memory` | First-time setup, after major refactors | Scans all tracked file types and populates `memory.jsonl` with change hunks |
| `query-memory` | Search codebase by intent or behavior | Semantic search via ChromaDB with automatic JSONL fallback |
| `openapi` | After adding/modifying/deleting any endpoint | Keeps `api/openapi.yaml` in sync with Spring controllers |
| `endpoint-trace` | Documenting a new endpoint | Generates code-level call chain docs in `docs/traces/` |
| `feature-docs` | After completing an endpoint in openapi.yaml | Generates usage-flow docs in `docs/features/` |
| `skill-creator` | Creating a new agent skill | Scaffolds a new `SKILL.md` following the project spec |
| `skill-sync` | After creating or modifying any skill | Rebuilds the Available Skills and Auto-Invoke tables in `CLAUDE.md` |
| `find-skills` | Looking for a skill that does X | Discovers and installs skills from the registry |
| `clean-ddd-hexagonal` | Designing APIs, DDD, Clean Architecture | Applies hexagonal architecture patterns with ports and adapters |

---

## Memory System

Every commit is recorded in `.agent/memory.jsonl` at the diff-hunk level and optionally synced to ChromaDB.
There are two record types:

### `change` — Git diff hunks (from post-commit hook)

Written automatically after every commit. One record per diff hunk for **all tracked file types** (`.java`, `.md`, `.sh`, `.py`, `.yaml`, `.yml`, `.sql`, `.json`):
- `change_type`: `addition` | `deletion` | `modification`
- `hunk_header`: the `@@ -X,Y +A,B @@` line from the diff
- `hunk_content`: exact added/removed lines
- `lines_start`, `lines_end`, `lines_delta`
- `intent`: the commit message subject
- `author`, `email`, `commit`, `ts`
- `tags`: file kind and change type

### `symbol` — Java code locations (from scan-memory)

Written by the agent when scanning `src/main/java`. Contains:
- Class/method name, file path, line range
- One-sentence intent, tags, git hash, date

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

### Bootstrap (re-sync all JSONL entries to Chroma from scratch)

```bash
bash .agent/scripts/bootstrap.sh
```

This runs:
1. `scan-history.sh` — replay all git history for all tracked file types
2. `scan.sh` — scan Java symbols (if `src/main/java` exists)
3. `sync-to-chroma.py` — push memory to ChromaDB

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

## Changelog

All notable changes to this project are documented in [CHANGELOG.md](CHANGELOG.md).

---

## Commit History

```
2c9053d fix(agent): fix query-memory filter bug and update memory terminology
1630906 feat(skills): add clean-ddd-hexagonal skill with auto-invoke triggers
60dc5e3 feat(agent): add post-commit compact reminder for Claude Code and Kiro
ffc9ad8 docs(root): add README with skills, memory system, and sync architecture
dccd076 refactor(setup): sync setup.sh templates with hunk-based memory system
c94b63a fix(agent): resolve project root in scan.sh for standalone execution
b625647 fix(agent): resolve bootstrap path and remove obsolete docker-compose version
86811de refactor(agent): replace SQLite with hunk-level JSONL+Chroma memory
9de9d34 fix(agent): extract meaningful intent for non-Java files in sync-files
5ed979e feat(agent): track all file types in post-commit memory sync
914c495 feat(skills): add query-memory skill and harden commit workflow
06186d0 chore(skills): remove install-hooks.sh artifact
b36bb02 refactor(skills): remove install-hooks.sh and link hook directly from setup
b482338 feat(skills): add skill-driven protocol with Chroma memory
93ebc38 post-commit trigger hook
37e11aa feat(skills): add ChromaDB sync and author tracking to agent memory
2eeb48f base scrips development
```

---

## File Layout

```
.
├── setup.sh                    # Installer — run once per project
├── CLAUDE.md                   # Agent context (auto-updated by skill-sync)
├── CHANGELOG.md                # Keepachangelog-formatted changelog
├── skills/
│   ├── commit/
│   │   ├── SKILL.md
│   │   └── assets/
│   │       └── post-commit.sh  # Git hook (symlinked from .git/hooks/)
│   ├── scan-memory/SKILL.md
│   ├── query-memory/SKILL.md
│   ├── openapi/SKILL.md
│   ├── endpoint-trace/SKILL.md
│   ├── feature-docs/SKILL.md
│   ├── skill-creator/SKILL.md
│   ├── skill-sync/SKILL.md
│   ├── find-skills/SKILL.md
│   ├── changelog/SKILL.md
│   ├── clean-ddd-hexagonal/SKILL.md
│   └── ui-design-review/SKILL.md
└── .agent/
    ├── memory.jsonl             # Append-only change history (committed)
    ├── chroma/
    │   └── docker-compose.yml
    └── scripts/
        ├── scan.sh              # Java symbol scanner
        ├── scan-history.sh      # Git history replay for all file types
        ├── bootstrap.sh         # Full re-sync (history + symbols + Chroma)
        ├── sync-hunks.py        # Hunk-level change recorder
        ├── sync-memory.py       # Java symbol line updater
        ├── sync-to-chroma.py    # JSONL → ChromaDB pusher
        └── query-memory.py      # Search CLI (Chroma + JSONL fallback)
```
