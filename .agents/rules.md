# Kernel — Skill-Driven Protocol

## Rules

1. **Every task is executed through a skill.** No skill → no action. State `"Skill gap detected."` if none applies.
2. **Load the SKILL.md before generating output.** The name is not the protocol. The file is.
3. **Memory and stack are injected automatically.** Hooks handle Chroma queries, commit validation, and /clear reminders. Do not duplicate that work.

## Execution Flow

```
task → [hook injects memory + skill hint] → load skill → execute → commit → /clear
```

## Available Skills

| Skill | Trigger |
|-------|---------|
| `commit` | Before any git commit |
| `endpoint-trace` | document endpoint code trace |
| `feature-docs` | After updating api/openapi.yaml with a completed endpoint |
| `find-skills` | Find a skill for a task |
| `openapi` | Adding a new endpoint |
| `query-memory` | Search codebase by intent or behavior |
| `scan-memory` | First-time project setup |
| `skill-creator` | Create a new skill |
| `skill-sync` | After creating or modifying a skill |

## Auto-Invoke Skills

| Action | Skill |
|--------|-------|
| Before any git commit | `commit` |
| document endpoint code trace | `endpoint-trace` |
| After updating api/openapi.yaml with a completed endpoint | `feature-docs` |
| Find a skill for a task | `find-skills` |
| Adding a new endpoint | `openapi` |
| Search codebase by intent or behavior | `query-memory` |
| First-time project setup | `scan-memory` |
| Create a new skill | `skill-creator` |
| After creating or modifying a skill | `skill-sync` |

## Architecture Decision Records

| ADR | Decision |
|-----|----------|
| TODO | Add your ADRs here |
