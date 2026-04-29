# Driven Agent Development

A skill-driven protocol for AI coding agents (Claude Code, Kiro, OpenCode).
Instead of improvising, the agent consults a library of skills before acting.
Every commit is tracked at the diff-hunk level and stored in a searchable memory.

## CLI

The project ships a Java CLI (`agent.jar`) built with Maven and Picocli.

### Build

```bash
mvn package
# produces target/agent.jar
```

### Docker

```bash
docker pull ghcr.io/andressep95/driven-agent-development:main
docker run --rm -it -v "$PWD:/project" -w /project ghcr.io/andressep95/driven-agent-development:main setup-agent
```

On Windows, replace `$PWD`:

```powershell
# PowerShell
docker run --rm -it -v "${PWD}:/project" -w /project ghcr.io/andressep95/driven-agent-development:main setup-agent
```

```cmd
# CMD
docker run --rm -it -v "%cd%:/project" -w /project ghcr.io/andressep95/driven-agent-development:main setup-agent
```

This mounts your current directory into the container and runs the CLI. Use `-it` for interactive commands (tool selection TUI). Replace `setup-agent` with any command.

### Commands

#### `setup-agent`

Bootstraps the full agent scaffold in the current directory and initializes both memory databases.

```bash
java -jar target/agent.jar setup-agent
```

1. Detects whether a git repository exists — offers to run `git init` if not.
2. Presents an interactive TUI checklist to select which AI tools to configure:

```
[setup-agent] Select AI tools to configure:
  ↑↓ navigate  ·  Space toggle  ·  Enter confirm

  > [x] Claude Code
    [x] Kiro
    [x] OpenCode
```

3. Extracts the scaffold from the JAR and creates the following structure based on the selected tools:

| What is created | Tool |
|-----------------|------|
| `.agents/rules.md`, `.agents/skills/`, `.agents/scripts/`, `.agents/memory/` | Always |
| `.git/hooks/post-commit` | Always |
| `.claude/settings.json`, `CLAUDE.md → .agents/rules.md`, `.claude/skills → .agents/skills/` | Claude Code |
| `.kiro/hooks/post-commit-clear.yaml`, `.kiro/skills → .agents/skills/`, `.kiro/steering/project-rules.md` | Kiro |
| `AGENTS.md → .agents/rules.md` | OpenCode |

4. Prints the command to initialize memory databases: `bash .agents/scripts/init.sh`

#### `scan-git`

Prints a diagnostic snapshot of the current git repository.

```bash
java -jar target/agent.jar scan-git
```

Outputs: identity, remotes, branches, active hooks, full config, status, and last 10 commits.

---

## Memory & Search Strategy

The memory system stores every commit as diff-hunk records and exposes them through two complementary layers.

### Dual-layer storage

```
git commit
    │
    ├── Pass 1: extract_changes.py ──→ .agents/memory/memory.jsonl   (flat JSONL)
    ├── Pass 2: sync-to-chroma.py  ──→ .agents/memory/chroma/        (vector DB)
    └── Pass 3: generate-changelog.py → CHANGELOG.md
```

Both layers are populated on every commit via `.git/hooks/post-commit`. No Docker, no external server — ChromaDB runs as a local `PersistentClient` embedded in Python.

### Search priority

```
query-memory.py "<query>"
        │
        ├── 1. ChromaDB (semantic)   ← default, ranks by meaning
        │       model: all-MiniLM-L6-v2 (local, no API calls, no tokens)
        │       returns: top-N results ordered by cosine similarity
        │
        └── 2. JSONL keyword fallback  ← activates if Chroma is unavailable
                searches: symbol, file, intent, hunk_content, tags
                returns: all matches sorted by keyword hit count
```

Chroma is always preferred because it understands intent — a query for `"inicializar memoria"` finds `init.sh` even if the word "inicializar" never appears in the file. The keyword fallback is exact-match only and returns raw volume.

### Usage

```bash
# Semantic search (uses Chroma)
python3 .agents/scripts/query-memory.py "setup agent bootstrap"

# Force keyword fallback (bypass Chroma)
python3 .agents/scripts/query-memory.py "setup agent bootstrap" --no-chroma

# Filter by record type
python3 .agents/scripts/query-memory.py "chroma sync" --type change
python3 .agents/scripts/query-memory.py "PersistentClient" --type symbol

# Full rebuild of both databases from git history
bash .agents/scripts/init.sh
```

### No tokens consumed

The entire memory pipeline — extraction, indexing, and querying — runs locally:

| Operation | Tool | AI / Tokens |
|-----------|------|-------------|
| Extract hunks | `extract_changes.py` (git + Python) | None |
| Index to Chroma | `sync-to-chroma.py` + `all-MiniLM-L6-v2` | None (local model) |
| Semantic query | `query-memory.py` + Chroma | None (local model) |
| Keyword fallback | `query-memory.py` + JSONL scan | None |

OpenAI embeddings are available via `--openai` flag if higher accuracy is needed, but not required.

---

## Multi-Agent Architecture

```
repo/
│
├── .agents/                        ← central core, source of truth
│   ├── rules.md                    ← project rules (canonical)
│   ├── memory/                     ← context shared between agents
│   │   ├── memory.jsonl            ← diff-hunk records (JSONL index)
│   │   └── chroma/                 ← vector DB (local, gitignored)
│   ├── scripts/                    ← environment utilities
│   └── skills/                     ← canonical skills
│       └── <skill-name>/
│           └── SKILL.md
│
├── .claude/                        ← Claude Code config
│   ├── settings.json               ← PostToolUse hook → post-commit-clear.sh
│   ├── hooks/
│   └── skills/ → ../.agents/skills/
│
├── .kiro/                          ← Kiro config
│   ├── hooks/
│   ├── steering/project-rules.md → ../../.agents/rules.md
│   └── skills/ → ../.agents/skills/
│
├── .git/hooks/post-commit          ← populates memory.jsonl + Chroma on every commit
├── AGENTS.md → .agents/rules.md   ← OpenCode entry point
└── CLAUDE.md → .agents/rules.md   ← Claude Code entry point
```

**Guiding principle:** if something is needed by more than one agent, it lives in `.agents/`.
Agent-specific config lives in the agent's own folder. Root files are always symlinks, never content.

## Skill Protocol

Every task the agent executes follows this flow:

```
task → query memory → load SKILL.md → execute → commit → /clear
```

Skills live in `.agents/skills/<name>/SKILL.md`. See `CLAUDE.md` for the full skill table and auto-invoke rules.

## Dependencies

| Library | Version | Purpose |
|---------|---------|---------|
| Picocli | 4.7.7 | CLI parsing |
| JLine | 3.27.1 | Interactive TUI (terminal raw mode) |
