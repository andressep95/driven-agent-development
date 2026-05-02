# Driven Agent Development

A skill-driven protocol for AI coding agents (Claude Code, Kiro, OpenCode).
Instead of improvising, the agent consults a library of skills before acting.
Hooks enforce behavior by code — not by text rules the agent can ignore.

## Quick Start

```bash
# Build
mvn package

# Bootstrap scaffold
java -jar target/agent.jar setup-agent

# Initialize memory (git history + skills → Chroma)
bash .agents/scripts/init.sh
```

## CLI

### Docker

```bash
docker pull ghcr.io/andressep95/driven-agent-development:main
docker run --rm -it -v "$PWD:/project" -w /project ghcr.io/andressep95/driven-agent-development:main setup-agent
```

### Commands

#### `setup-agent`

Bootstraps the full agent scaffold. Interactive TUI lets you select which AI tools to configure.

| What is created | Tool |
|-----------------|------|
| `.agents/rules.md`, `.agents/skills/`, `.agents/scripts/`, `.agents/memory/` | Always |
| `.git/hooks/post-commit` | Always |
| `.claude/settings.json`, `CLAUDE.md`, `.claude/skills/` | Claude Code |
| `.kiro/hooks/*.yaml`, `.kiro/skills/`, `.kiro/steering/project-rules.md` | Kiro |
| `AGENTS.md` | OpenCode |

#### `scan-git`

Prints a diagnostic snapshot of the current git repository.

---

## Hooks — Behavior Enforced by Code

Hooks intercept agent lifecycle events and inject context or block actions automatically. The agent cannot ignore them.

| Hook | Event | What it does |
|------|-------|-------------|
| `session-start.sh` | SessionStart | Auto-detects project stack (Java/Node/Rust/Go/Python + Docker/Terraform) and injects it |
| `user-prompt-submit.sh` | UserPromptSubmit | Finds relevant skill via Chroma semantic search + injects prior context from memory |
| `validate-commit.sh` | PreToolUse | Blocks `git commit` if body is missing `what:`, `why:`, `breaking:` fields |
| `post-commit-clear.sh` | PostToolUse | Reminds agent to request `/clear` after each commit |
| `token-tracker.py` | Stop | Reads token usage from the session transcript and appends a record to `.agents/memory/token-usage.jsonl` |

### How UserPromptSubmit works

```
User writes: "crear endpoint de autenticación JWT"
  │
  ├─ Queries Chroma 'skills' collection (semantic, cross-language)
  │    → openapi (86%), endpoint-trace (85%)
  │
  ├─ Queries Chroma 'changes' collection
  │    → 5 most relevant prior changes in the project
  │    → drops results below relevance threshold (default: 0.72)
  │
  └─ Injects as additionalContext:
       "## Relevant Skill: openapi
        Load and follow: .agents/skills/openapi/SKILL.md
        
        ## Prior Context from Memory (Chroma)
        [relevant prior changes]"
```

The agent receives precise context before responding — no need to read the entire project.

### Adding new hooks

See [docs/extending-hooks.md](docs/extending-hooks.md) for a complete guide with recipes.

---

## Token Tracking

The `Stop` hook runs `token-tracker.py` at the end of every session and logs token consumption to `.agents/memory/token-usage.jsonl`.

Each record includes:

| Field | Description |
|-------|-------------|
| `input` / `output` | Raw token counts for the session |
| `cache_creation` / `cache_read` | Prompt cache breakdown |
| `quality` | `alta` (≥80% cache hit), `media` (≥40%), `baja` (<40%) |
| `session_id` | Claude session identifier |

### Analyzing system health

```bash
python3 .agents/scripts/token-report.py
```

Prints a report that crosses `token-usage.jsonl` with `query-log.jsonl` to show:

- Token usage per turn and per agent (with cache hit rate)
- Chroma injection quality: how many results were injected vs dropped per query
- Warning if any injection scored below the relevance threshold

---

## Memory — Git → Chroma Direct

Git is the source of truth. Chroma is the search layer. No intermediaries.

```
git commit
    │
    ├── extract_changes.py ──→ .agents/memory/chroma/  (vector DB, direct)
    └── generate-changelog.py → CHANGELOG.md
```

### How it works

- **On every commit:** `post-commit` hook runs `extract_changes.py` which parses the diff and indexes each hunk directly into ChromaDB
- **On init:** `scan-history.sh` replays the full git history into Chroma in a single Python process (model loads once)
- **On skill changes:** `sync.sh` updates rules.md tables + re-indexes skills in Chroma

### Embedding model

Uses `intfloat/multilingual-e5-small` — a multilingual sentence transformer that runs 100% locally. No API keys, no server, no cost.

- Downloads once (~500MB) to `~/.cache/huggingface/`
- Cross-language: Spanish prompts match English skill descriptions at 85-89% accuracy
- Cosine similarity search via ChromaDB `PersistentClient`

### What Chroma stores per record

| Metadata field | Purpose |
|----------------|---------|
| `file` / `lines_start` / `lines_end` | Exact location |
| `intent` | Commit subject line |
| `what` / `why` | From commit body — feeds semantic search |
| `author` / `ts` | Who made the change and when |
| `commit` / `branch` | Git reference for `git show` |
| `language` / `file_kind` | Auto-detected from extension |
| `tags` | Composite of commit_type, change_type, kind, scope |

### Usage

```bash
# Semantic search
python3 .agents/scripts/query-memory.py "autenticación JWT"

# Filter by kind
python3 .agents/scripts/query-memory.py "pagination" --kind service

# Full rebuild from git history
bash .agents/scripts/init.sh
```

### No tokens consumed

| Operation | Tool | AI / Tokens |
|-----------|------|-------------|
| Extract hunks | `extract_changes.py` (git + Python) | None |
| Index to Chroma | `multilingual-e5-small` (local) | None |
| Semantic query | `query-memory.py` + Chroma | None |
| Skill matching | `user-prompt-submit.sh` + Chroma | None |

---

## Skill Protocol

```
task → [hook injects memory + skill hint] → load skill → execute → commit → /clear
```

Skills live in `.agents/skills/<name>/SKILL.md`. The `UserPromptSubmit` hook finds the right skill automatically via semantic search. The agent loads the SKILL.md and follows its protocol.

### Available skills

| Skill | Purpose |
|-------|---------|
| `clean-ddd-hexagonal` | APIs, domain models, aggregates, use cases |
| `commit` | Conventional Commits enforcement |
| `endpoint-trace` | Full call-chain trace for an HTTP endpoint |
| `feature-docs` | Usage-flow docs for completed features |
| `jpa-query-optimizer` | Detect and fix N+1, fetch strategy, projection, pagination, and caching issues in Spring Boot JPA/Hibernate |
| `openapi` | Keep `api/openapi.yaml` in sync with Spring controllers |
| `query-memory` | Semantic search over project history |
| `scan-memory` | Replay full git history into Chroma |
| `skill-creator` | Author new skills consistently |
| `skill-sync` | Sync skill tables in `rules.md` and re-index in Chroma |

### Syncing skills

```bash
# Sync skill tables in rules.md + re-index in Chroma
bash .agents/scripts/sync.sh
```

This updates Available Skills and Auto-Invoke tables in `rules.md` (which `CLAUDE.md` and `.kiro/steering/project-rules.md` symlink to) and re-indexes all skills in Chroma's `skills` collection.

---

## Architecture

```
repo/
├── .agents/                        ← central core, source of truth
│   ├── rules.md                    ← project rules (canonical)
│   ├── memory/
│   │   └── chroma/                 ← vector DB (local, gitignored)
│   ├── scripts/                    ← hooks, extractors, sync
│   └── skills/                     ← canonical skills
│       └── <skill-name>/SKILL.md
│
├── .claude/                        ← Claude Code config
│   ├── settings.json               ← hooks: SessionStart, UserPromptSubmit, PreToolUse, PostToolUse, Stop
│   └── skills/ → ../.agents/skills/
│
├── .kiro/                          ← Kiro config
│   ├── hooks/*.yaml                ← same hooks as Claude, yaml format
│   ├── steering/project-rules.md → ../../.agents/rules.md
│   └── skills/ → ../.agents/skills/
│
├── .git/hooks/post-commit          ← indexes each commit into Chroma
├── .mcp.json                       ← MCP server configuration (Claude Code)
├── AGENTS.md → .agents/rules.md    ← OpenCode entry point
└── CLAUDE.md → .agents/rules.md    ← Claude Code entry point
```

**Principle:** shared content lives in `.agents/`. Agent-specific config lives in the agent's folder. Root files are symlinks, never content.

## Dependencies

| Library | Version | Purpose |
|---------|---------|---------|
| Picocli | 4.7.7 | CLI parsing |
| JLine | 3.27.1 | Interactive TUI |
| ChromaDB | 1.5.8 | Vector search (Python, local) |
| sentence-transformers | ≥2.2.0 | Multilingual embeddings (local) |
