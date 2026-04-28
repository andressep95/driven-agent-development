# Driven Agent Development

A skill-driven protocol for AI coding agents (Claude Code, Kiro, etc.).
Instead of improvising, the agent consults a library of skills before acting.
Every commit is tracked at the diff-hunk level and stored in a searchable memory.

# Multi-Agent Architecture

```
repo/
│
├── .agents/                        ← central core, source of truth
│   ├── rules.md                    ← project rules (canonical)
│   ├── architecture.md             ← this file
│   ├── memory/                     ← context shared between agents
│   │   ├── context.md              ← current project state
│   │   └── decisions.md            ← architecture/design decisions
│   ├── hooks/                      ← shared hook scripts
│   │   ├── pre-commit.sh
│   │   └── post-task.sh
│   ├── scripts/                    ← multi-agent environment utilities
│   │   └── sync-rules.sh           ← regenerates symlinks if needed
│   └── skills/                     ← canonical skills (source of truth)
│       └── skill-name/
│           └── SKILL.md
│
├── .kiro/                          ← Kiro-specific
│   ├── project_rules.md            ← symlink → ../.agents/rules.md
│   └── skills/                     ← symlinks → .agents/skills/...
│
├── .opencode/                      ← OpenCode-specific
│   ├── skills/                     ← symlinks → .agents/skills/...
│   └── memory/                     ← symlink → ../.agents/memory/
│
├── AGENTS.md                       ← symlink → .agents/rules.md  (OpenCode)
├── CLAUDE.md                       ← symlink → .agents/rules.md  (Claude Code)
└── skills-lock.json                ← registry of installed skills
```

## Guiding Principle

If something is needed by more than one agent, it lives in `.agents/`.
If it's exclusive to a single agent (config format, steering), it lives in the agent's own folder.
Root files and agent folders are **always symlinks**, never actual content.

## Responsibility Table

| Layer                 | Where it lives              | What it contains                        |
| --------------------- | --------------------------- | --------------------------------------- |
| Project rules        | .agents/rules.md            | What all agents must know              |
| --------------------- | --------------------------- | --------------------------------------- |
| Shared memory        | .agents/memory/             | Context that persists between sessions |
| --------------------- | --------------------------- | --------------------------------------- |
| Canonical skills    | .agents/skills/             | Code review, prompts, etc.               |
| --------------------- | --------------------------- | --------------------------------------- |
| Agent config        | .[agent]/                  | Steering, preferences, etc.             |
| --------------------- | --------------------------- | --------------------------------------- |
| Public docs         | AGENTS.md, CLAUDE.md, etc.  | Symlinks, never actual content         |