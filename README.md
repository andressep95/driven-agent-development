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

Bootstraps the full agent scaffold in the current directory.

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
| `.agents/rules.md`, `.agents/skills/`, `.agents/scripts/`, `.agents/memory/`, `.agents/agents-compose.yml` | Always |
| `.git/hooks/post-commit` | Always |
| `.claude/settings.json`, `CLAUDE.md → .agents/rules.md`, `.claude/skills → .agents/skills/` | Claude Code |
| `.kiro/hooks/post-commit-clear.yaml`, `.kiro/skills → .agents/skills/`, `.kiro/steering/project-rules.md` | Kiro |
| `AGENTS.md → .agents/rules.md` | OpenCode |

#### ChromaDB (optional)

The scaffold includes a Compose file for ChromaDB, the vector search backend used by the memory system:

```bash
docker compose -f .agents/agents-compose.yml up -d
```

This starts ChromaDB on port 8765. Without it, memory queries fall back to keyword search over `memory.jsonl`.

#### `scan-git`

Prints a diagnostic snapshot of the current git repository.

```bash
java -jar target/agent.jar scan-git
```

Outputs: identity, remotes, branches, active hooks, full config, status, and last 10 commits.

---

## Multi-Agent Architecture

```
repo/
│
├── .agents/                        ← central core, source of truth
│   ├── rules.md                    ← project rules (canonical)
│   ├── memory/                     ← context shared between agents
│   │   └── memory.jsonl            ← diff-hunk records (RAG index)
│   ├── scripts/                    ← environment utilities
│   └── skills/                     ← canonical skills
│       └── <skill-name>/
│           └── SKILL.md
│
├── .claude/                        ← Claude Code config
│   ├── settings.json
│   ├── hooks/
│   └── skills/ → ../.agents/skills/
│
├── .kiro/                          ← Kiro config
│   ├── hooks/
│   ├── steering/project-rules.md → ../../.agents/rules.md
│   └── skills/ → ../.agents/skills/
│
├── .git/hooks/post-commit          ← records diff hunks to memory.jsonl
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
