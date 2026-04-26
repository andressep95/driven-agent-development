# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/).

## [Unreleased]

### [0edf290] — 2026-04-25

**refactor(agent): remove memory.db references and harden memory bootstrap**

> - Replace memory.db auto-invoke triggers with memory.jsonl in setup.sh,
> SKILL.md, CLAUDE.md, and project-rules.md
> - Remove memory.db from git diff filters and SKIP_FILES in sync-hunks.py
> - bootstrap.sh now runs scan-history.sh before Java scan (3-step flow)

#### Added

- `.agent/scripts/scan-history.sh` — Replays full git history into memory.jsonl for ALL tracked file types.
- `.agent/scripts/sync-hunks.py` — Dedup: skip records already tracked for this (commit, file, hunk_header)
- `README.md`
- `setup.sh`
- `skills/scan-memory/SKILL.md` — scan-memory

#### Changed

- `.agent/scripts/bootstrap.sh` — Full memory bootstrap: scan all git history + Java symbols → push to Chr
- `.agent/scripts/sync-hunks.py` — git_commit_info
- `.kiro/steering/project-rules.md`
- `CLAUDE.md`
- `README.md`
- `setup.sh`
- `skills/scan-memory/SKILL.md` — scan-memory

#### Removed

- `.agent/scripts/sync-hunks.py` — Try to find a meaningful identifier in the changed lines
- `README.md` — `symbol` — Java code locations (from `scan-memory`)
- `setup.sh` — or directly:
- `skills/scan-memory/SKILL.md` — scan-memory

---

### [2c9053d] — 2026-04-25

**fix(agent): fix query-memory filter bug and update memory terminology**

> - Remove broken where-filter condition in query-memory.py
> - Mark sync-hunks.py as executable
> - Strip dead comments from bootstrap.sh and sync-to-chroma.py
> - Update scan-memory and query-memory SKILL.md: replace SQLite/memory.db

#### Changed

- `skills/query-memory/SKILL.md` — query-memory
- `skills/scan-memory/SKILL.md` — scan-memory

#### Removed

- `.agent/scripts/bootstrap.sh`
- `.agent/scripts/query-memory.py`
- `.agent/scripts/sync-to-chroma.py` — Unique ID: commit + file + hunk start line

---

### [1630906] — 2026-04-25

**feat(skills): add clean-ddd-hexagonal skill with auto-invoke triggers**

> - Add SKILL.md and references/ directory for clean-ddd-hexagonal
> - Embed skill template in setup.sh for bootstrapped projects
> - Register skill in CLAUDE.md and .kiro/steering/project-rules.md
> with full auto-invoke trigger list

#### Added

- `skills/clean-ddd-hexagonal/SKILL.md` — clean-ddd-hexagonal
- `skills/clean-ddd-hexagonal/references/CHEATSHEET.md` — Quick Reference Cheatsheet
- `skills/clean-ddd-hexagonal/references/CQRS-EVENTS.md` — CQRS & Domain Events
- `skills/clean-ddd-hexagonal/references/DDD-STRATEGIC.md` — DDD Strategic Patterns
- `skills/clean-ddd-hexagonal/references/DDD-TACTICAL.md` — DDD Tactical Patterns
- `skills/clean-ddd-hexagonal/references/HEXAGONAL.md` — Hexagonal Architecture (Ports & Adapters)
- `skills/clean-ddd-hexagonal/references/LAYERS.md` — Layer Structure - Complete Reference
- `skills/clean-ddd-hexagonal/references/TESTING.md` — Testing Patterns
- `.kiro/steering/project-rules.md`
- `CLAUDE.md`
- `setup.sh` — ── clean-ddd-hexagonal ───────────────────────────────────────────────

#### Changed

- `.kiro/steering/project-rules.md`
- `CLAUDE.md`

---

### [60dc5e3] — 2026-04-25

**feat(agent): add post-commit compact reminder for Claude Code and Kiro**

#### Added

- `setup.sh`
- `skills/commit/assets/post-commit.sh`

---

### [dccd076] — 2026-04-25

**refactor(setup): sync setup.sh templates with hunk-based memory system**

> - Replace post-commit.sh template with two-pass sync-hunks.py version
> - Replace sync-files.py template with sync-hunks.py (hunk-level tracker)
> - Update sync-to-chroma.py template to handle both symbol and change types
> - Update query-memory.py template with --type filter and change record display

#### Added

- `setup.sh` — Java-only for symbol location tracking

#### Changed

- `setup.sh` — Git post-commit hook — two passes:

#### Removed

- `setup.sh`

---

### [c94b63a] — 2026-04-25

**fix(agent): resolve project root in scan.sh for standalone execution**

#### Added

- `.agent/scripts/scan.sh`

#### Changed

- `.agent/scripts/scan.sh` — Run from anywhere — script resolves the project root automatically.

---

### [b625647] — 2026-04-25

**fix(agent): resolve bootstrap path and remove obsolete docker-compose version**

> - bootstrap.sh resolves project root via SCRIPT_DIR to fix relative path error
> - Remove obsolete version field from docker-compose.yml
> - Sync setup.sh templates

#### Added

- `.agent/scripts/bootstrap.sh`
- `setup.sh`

#### Changed

- `.agent/scripts/bootstrap.sh` — Run from anywhere — script resolves the project root automatically.
- `setup.sh` — Full memory bootstrap: scan Java symbols → push everything to Chroma.

#### Removed

- `.agent/chroma/docker-compose.yml`
- `setup.sh`

---

### [86811de] — 2026-04-25

**refactor(agent): replace SQLite with hunk-level JSONL+Chroma memory**

> - Add sync-hunks.py: each git diff hunk becomes one change record
> - Remove schema.sql, rebuild.sh, sync-files.py (SQLite eliminated)
> - Update post-commit.sh: sync-hunks.py for all types + sync-memory.py for Java symbols
> - Update sync-to-chroma.py: handle both symbol and change record types

#### Added

- `.agent/scripts/sync-hunks.py` — ── git helpers ─────────────────────────────────────────────────────────
- `.agent/scripts/query-memory.py`
- `.agent/scripts/sync-to-chroma.py`
- `skills/commit/assets/post-commit.sh` — Java-only for symbol location tracking

#### Changed

- `.agent/scripts/bootstrap.sh` — Full memory bootstrap: scan Java symbols → push everything to Chroma.
- `.agent/scripts/query-memory.py` — search_jsonl
- `.agent/scripts/sync-to-chroma.py` — entry_to_chroma
- `skills/commit/assets/post-commit.sh` — Git post-commit hook — two passes:
- `skills/scan-memory/SKILL.md` — scan-memory

#### Removed

- `.agent/scripts/query-memory.py` — Try Chroma first unless --no-chroma
- `.agent/scripts/sync-to-chroma.py`
- `skills/commit/assets/post-commit.sh`
- `.agent/schema.sql`
- `.agent/scripts/rebuild.sh`
- `.agent/scripts/sync-files.py`

---

### [9de9d34] — 2026-04-25

**fix(agent): extract meaningful intent for non-Java files in sync-files**

> - Add extract_intent() to pull first comment from .sh, module docstring
> from .py, first heading from .md, first comment from .yaml/.sql
> - Remove fake line ranges from non-Java file entries
> - Fix docstring regex to match past shebang line

#### Added

- `.agent/scripts/sync-files.py` — extract_intent
- `setup.sh` — extract_intent

#### Changed

- `.agent/scripts/sync-files.py`
- `setup.sh`

#### Removed

- `.agent/scripts/sync-files.py` — file_line_count
- `setup.sh` — file_line_count

---

### [5ed979e] — 2026-04-25

**feat(agent): track all file types in post-commit memory sync**

> - Add sync-files.py to index .md, .sh, .py, .yaml, .yml, .sql, .json
> - Extract name/description from SKILL.md frontmatter as intent
> - Update post-commit.sh to call both sync-memory.py and sync-files.py
> - Bundle sync-files.py and updated hook template in setup.sh

#### Added

- `.agent/scripts/sync-files.py` — git_hash
- `setup.sh` — ── sync-files.py ────────────────────────────────────────────

#### Changed

- `setup.sh` — Git post-commit hook: syncs memory.jsonl for all tracked file types.
- `skills/commit/assets/post-commit.sh` — Git post-commit hook: syncs memory.jsonl for all tracked file types.

---

### [914c495] — 2026-04-25

**feat(skills): add query-memory skill and harden commit workflow**

> - Add query-memory skill with Chroma semantic search and JSONL fallback
> - Rewrite query-memory.py with auto-detect + fallback to memory.jsonl
> - Delete deprecated .agent/scripts/post-commit.sh
> - Add Chroma sync step (Step 5) to scan-memory skill

#### Added

- `skills/query-memory/SKILL.md` — query-memory
- `.agent/scripts/query-memory.py`
- `.kiro/steering/project-rules.md`
- `CLAUDE.md`
- `setup.sh`
- `skills/commit/SKILL.md` — commit

#### Changed

- `.agent/scripts/query-memory.py` — search_jsonl
- `setup.sh`
- `skills/commit/SKILL.md` — commit
- `skills/scan-memory/SKILL.md` — scan-memory

#### Removed

- `setup.sh` — ── post-commit.sh (deprecated - kept for reference) ───────────────────
- `.agent/scripts/post-commit.sh`

---

### [b36bb02] — 2026-04-25

**refactor(skills): remove install-hooks.sh and link hook directly from setup**

> - Remove .agent/scripts/install-hooks.sh (no longer needed)
> - Setup now creates post-commit symlink directly to skills/commit/assets/
> - Hook logic simplified in setup.sh Step 6

#### Changed

- `setup.sh` — ── post-commit.sh (deprecated - kept for reference) ───────────────────

---

### [b482338] — 2026-04-25

**feat(skills): add skill-driven protocol with Chroma memory**

> - Add setup.sh with full skill infrastructure
> - Add 10 bundled skills (changelog, commit, scan-memory, etc.)
> - Add Chroma vector DB for semantic search
> - Add post-commit hook that syncs to Chroma after each commit

#### Added

- `.agent/chroma/docker-compose.yml`
- `.agent/schema.sql`
- `.agent/scripts/bootstrap.sh` — Full memory bootstrap: scan.sh → sync-to-chroma.py
- `.agent/scripts/install-hooks.sh` — Installs git hooks from skills/ into .git/hooks/ via symlink.
- `.agent/scripts/post-commit.sh` — DEPRECATED: Use skills/commit/assets/post-commit.sh instead
- `.agent/scripts/query-memory.py` — main
- `.agent/scripts/rebuild.sh` — Rebuilds memory.db from memory.jsonl. Run after any write to memory.json
- `.agent/scripts/scan.sh` — Scans the Java source tree and emits raw symbol locations for agent proc
- `.agent/scripts/sync-memory.py` — -- git helpers ---------------------------------------------------------
- `.agent/scripts/sync-to-chroma.py` — load_jsonl
- `.claude/skills`
- `.kiro/skills`
- `.kiro/steering/project-rules.md` — Kernel — Skill-Driven Protocol
- `CLAUDE.md` — Kernel — Skill-Driven Protocol
- `skills/changelog/SKILL.md` — changelog
- `skills/commit/SKILL.md` — commit
- `skills/commit/assets/post-commit.sh` — Git post-commit hook: syncs memory.jsonl with changed Java files to Chro
- `skills/endpoint-trace/SKILL.md` — endpoint-trace
- `skills/feature-docs/SKILL.md` — feature-docs
- `skills/find-skills/SKILL.md` — find-skills
- _…and 6 more_

#### Changed

- `setup.sh`

---

### [93ebc38] — 2026-04-25

**post-commit trigger hook**

#### Added

- `setup.sh` — Git Hook

#### Changed

- `setup.sh` — Installs git hooks from skills/ into .git/hooks/ via symlink.

#### Removed

- `setup.sh` — Skip if memory not initialised yet

---

### [37e11aa] — 2026-04-24

**feat(skills): add ChromaDB sync and author tracking to agent memory**

> - Add sync-to-chroma.py script for memory.jsonl → ChromaDB sync
> - Add bootstrap.sh for combined scan + Chroma sync workflow
> - Add docker-compose.yml for ChromaDB container (v1.5.3)
> - Update post-commit hook to sync to Chroma instead of SQLite rebuild

#### Added

- `setup.sh` — ── sync-to-chroma.py ────────────────────────────────────────

#### Changed

- `setup.sh`

---

### [2eeb48f] — 2026-04-24

**base scrips development**

#### Added

- `setup.sh` — Agent Skill Development — Project setup script.

---
