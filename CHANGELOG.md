# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/).

## [Unreleased]

### [26c3784] — 2026-04-29

**refactor(agent): rename bootstrap.sh to init.sh and remove Python from Docker**

> what: Renames bootstrap.sh to init.sh across all scripts, skills, scaffold,
> and docs; setup-agent now prints the init command instead of running it;
> removes python3, pip, and chromadb from the Docker image.
> why:  bootstrap.sh name was generic and confusing; auto-running memory init

_Run with jsonl enrichment for file-level detail._

---

### [fcd1b00] — 2026-04-29

**Merge pull request #3 from andressep95/restructure/cli-java**

> Restructure/cli java

_Run with jsonl enrichment for file-level detail._

---

### [d5efd04] — 2026-04-29

**fix(docker): add python3 and chromadb to container image**

> what: Installs python3, pip, and chromadb in the runtime image so
> bootstrap.sh can fully populate both memory.jsonl and Chroma
> during setup-agent without manual intervention
> why:  The container lacked python3, causing sync-to-chroma.py to fail

_Run with jsonl enrichment for file-level detail._

---

### [d32bddb] — 2026-04-29

**Merge pull request #2 from andressep95/restructure/cli-java**

> Restructure/cli java

_Run with jsonl enrichment for file-level detail._

---

### [e6d3063] — 2026-04-29

**refactor(memory): migrate Chroma to local PersistentClient and auto-sync on commit**

> what: Removes Docker-based Chroma setup and replaces it with a local
> PersistentClient; post-commit hook now syncs memory.jsonl to
> Chroma on every commit; setup-agent runs bootstrap automatically
> why:  Eliminates Docker as a runtime dependency for the memory system,

_Run with jsonl enrichment for file-level detail._

---

### [601cc3c] — 2026-04-28

**Merge pull request #1 from andressep95/restructure/cli-java**

> Restructure/cli java

_Run with jsonl enrichment for file-level detail._

---

### [36319eb] — 2026-04-28

**feat(cli): add ChromaDB compose file to scaffold**

> what: Adds agents-compose.yml to scaffold and updates setup-agent to extract it to client machines
> why: Enables clients to run local ChromaDB instance for vector search memory queries
> breaking: false

_Run with jsonl enrichment for file-level detail._

---

### [64f7ee6] — 2026-04-28

**fix(docker): install git in runtime image**

> what: Adds git to the JRE runtime stage so the CLI can detect existing repositories in mounted volumes
> why: Without git the container could not run git rev-parse, causing setup-agent to falsely report no repo found
> breaking: false

_Run with jsonl enrichment for file-level detail._

---

### [84b9827] — 2026-04-28

**fix(cli): handle non-interactive TTY and add multi-platform Docker build**

> what: SetupAgentCommand detects missing TTY and defaults to auto-init + all tools; CI now builds linux/amd64 and linux/arm64 images
> why: Running via docker run without -it caused a NoSuchElementException crash, and ARM Macs received an amd64 image requiring emulation
> breaking: false

_Run with jsonl enrichment for file-level detail._

---

### [05b9e1e] — 2026-04-28

**refactor(scripts): consolidate memory pipeline and remove deprecated utilities**

> what: Removes redundant scripts (sync-hunks, sync-memory, migrate_to_chroma, scan.sh, rebuild-chroma) and consolidates memory sync into a single extract→sync-to-chroma pipeline
> why: Multiple overlapping scripts caused confusion and maintenance burden; the new pipeline is simpler and matches the post-commit hook flow
> breaking: false

_Run with jsonl enrichment for file-level detail._

---

### [b5ab996] — 2026-04-28

**feat(cli): add interactive tool-selector TUI to setup-agent**

> what: SetupAgentCommand now shows a jline checklist so users pick
> which AI tools to scaffold, and auto-detects or initializes
> git before running; InitRepoCommand is absorbed and removed.
> why:  The command installed all tool configs unconditionally; scoping

_Run with jsonl enrichment for file-level detail._

---

### [fdc0a94] — 2026-04-28

**fix(agent): correct .agent/ paths to .agents/memory/ in all scripts**

> what: Updates hardcoded .agent/memory.jsonl references to
> .agents/memory/memory.jsonl across scripts and adds the full
> script set to src/main/resources/scaffold/scripts/ so setup-agent
> deploys them correctly on every new repo.

_Run with jsonl enrichment for file-level detail._

---

### [440f449] — 2026-04-28

**feat(cli): add setup-agent command and migrate scaffold to .agents/**

> what: Adds setup-agent subcommand that extracts the full agent scaffold
> (.agents/, skills, scripts, hooks, symlinks) from embedded JAR
> resources, replacing the manually maintained .agent/ directory.
> why: Automates project bootstrap so any user can run setup-agent once

_Run with jsonl enrichment for file-level detail._

---

### [d102cb6] — 2026-04-28

**feat(cli): add init-repo command and restructure agent skills layout**

> - Add InitRepoCommand with interactive git initialization prompt
> - Register init-repo subcommand in App.java
> - Migrate all SKILL.md files from skills/ to .agent/skills/
> - Remove legacy skills/ directory and CHANGELOG.md

_Run with jsonl enrichment for file-level detail._

---

### [fb0be98] — 2026-04-25

**feat(commit): auto-regenerate CHANGELOG.md on feat/fix/refactor/perf/sec commits**

> - Add Pass 3 to post-commit hook: runs generate-changelog.py after
> any notable commit type and auto-commits the updated CHANGELOG.md
> - Guard against infinite loop via chore(changelog): prefix detection
> - Uses --no-verify on the changelog commit to skip hook re-entry

_Run with jsonl enrichment for file-level detail._

---

### [61f65d6] — 2026-04-25

**feat(changelog): add full-history regeneration from git and jsonl**

> - Add generate-changelog.py: per-commit sections [hash] with
> Added/Changed/Removed file grouping, enriched from memory.jsonl
> hunk data and git commit body
> - Add rebuild-chroma.sh: drops and rebuilds ChromaDB collection

_Run with jsonl enrichment for file-level detail._

---

### [0edf290] — 2026-04-25

**refactor(agent): remove memory.db references and harden memory bootstrap**

> - Replace memory.db auto-invoke triggers with memory.jsonl in setup.sh,
> SKILL.md, CLAUDE.md, and project-rules.md
> - Remove memory.db from git diff filters and SKIP_FILES in sync-hunks.py
> - bootstrap.sh now runs scan-history.sh before Java scan (3-step flow)

_Run with jsonl enrichment for file-level detail._

---

### [2c9053d] — 2026-04-25

**fix(agent): fix query-memory filter bug and update memory terminology**

> - Remove broken where-filter condition in query-memory.py
> - Mark sync-hunks.py as executable
> - Strip dead comments from bootstrap.sh and sync-to-chroma.py
> - Update scan-memory and query-memory SKILL.md: replace SQLite/memory.db

_Run with jsonl enrichment for file-level detail._

---

### [1630906] — 2026-04-25

**feat(skills): add clean-ddd-hexagonal skill with auto-invoke triggers**

> - Add SKILL.md and references/ directory for clean-ddd-hexagonal
> - Embed skill template in setup.sh for bootstrapped projects
> - Register skill in CLAUDE.md and .kiro/steering/project-rules.md
> with full auto-invoke trigger list

_Run with jsonl enrichment for file-level detail._

---

### [60dc5e3] — 2026-04-25

**feat(agent): add post-commit compact reminder for Claude Code and Kiro**

_Run with jsonl enrichment for file-level detail._

---

### [dccd076] — 2026-04-25

**refactor(setup): sync setup.sh templates with hunk-based memory system**

> - Replace post-commit.sh template with two-pass sync-hunks.py version
> - Replace sync-files.py template with sync-hunks.py (hunk-level tracker)
> - Update sync-to-chroma.py template to handle both symbol and change types
> - Update query-memory.py template with --type filter and change record display

_Run with jsonl enrichment for file-level detail._

---

### [c94b63a] — 2026-04-25

**fix(agent): resolve project root in scan.sh for standalone execution**

_Run with jsonl enrichment for file-level detail._

---

### [b625647] — 2026-04-25

**fix(agent): resolve bootstrap path and remove obsolete docker-compose version**

> - bootstrap.sh resolves project root via SCRIPT_DIR to fix relative path error
> - Remove obsolete version field from docker-compose.yml
> - Sync setup.sh templates

_Run with jsonl enrichment for file-level detail._

---

### [86811de] — 2026-04-25

**refactor(agent): replace SQLite with hunk-level JSONL+Chroma memory**

> - Add sync-hunks.py: each git diff hunk becomes one change record
> - Remove schema.sql, rebuild.sh, sync-files.py (SQLite eliminated)
> - Update post-commit.sh: sync-hunks.py for all types + sync-memory.py for Java symbols
> - Update sync-to-chroma.py: handle both symbol and change record types

_Run with jsonl enrichment for file-level detail._

---

### [9de9d34] — 2026-04-25

**fix(agent): extract meaningful intent for non-Java files in sync-files**

> - Add extract_intent() to pull first comment from .sh, module docstring
> from .py, first heading from .md, first comment from .yaml/.sql
> - Remove fake line ranges from non-Java file entries
> - Fix docstring regex to match past shebang line

_Run with jsonl enrichment for file-level detail._

---

### [5ed979e] — 2026-04-25

**feat(agent): track all file types in post-commit memory sync**

> - Add sync-files.py to index .md, .sh, .py, .yaml, .yml, .sql, .json
> - Extract name/description from SKILL.md frontmatter as intent
> - Update post-commit.sh to call both sync-memory.py and sync-files.py
> - Bundle sync-files.py and updated hook template in setup.sh

_Run with jsonl enrichment for file-level detail._

---

### [914c495] — 2026-04-25

**feat(skills): add query-memory skill and harden commit workflow**

> - Add query-memory skill with Chroma semantic search and JSONL fallback
> - Rewrite query-memory.py with auto-detect + fallback to memory.jsonl
> - Delete deprecated .agent/scripts/post-commit.sh
> - Add Chroma sync step (Step 5) to scan-memory skill

_Run with jsonl enrichment for file-level detail._

---

### [b36bb02] — 2026-04-25

**refactor(skills): remove install-hooks.sh and link hook directly from setup**

> - Remove .agent/scripts/install-hooks.sh (no longer needed)
> - Setup now creates post-commit symlink directly to skills/commit/assets/
> - Hook logic simplified in setup.sh Step 6

_Run with jsonl enrichment for file-level detail._

---

### [b482338] — 2026-04-25

**feat(skills): add skill-driven protocol with Chroma memory**

> - Add setup.sh with full skill infrastructure
> - Add 10 bundled skills (changelog, commit, scan-memory, etc.)
> - Add Chroma vector DB for semantic search
> - Add post-commit hook that syncs to Chroma after each commit

_Run with jsonl enrichment for file-level detail._

---

### [93ebc38] — 2026-04-25

**post-commit trigger hook**

_Run with jsonl enrichment for file-level detail._

---

### [37e11aa] — 2026-04-24

**feat(skills): add ChromaDB sync and author tracking to agent memory**

> - Add sync-to-chroma.py script for memory.jsonl → ChromaDB sync
> - Add bootstrap.sh for combined scan + Chroma sync workflow
> - Add docker-compose.yml for ChromaDB container (v1.5.3)
> - Update post-commit hook to sync to Chroma instead of SQLite rebuild

_Run with jsonl enrichment for file-level detail._

---

### [2eeb48f] — 2026-04-24

**base scrips development**

_Run with jsonl enrichment for file-level detail._

---
