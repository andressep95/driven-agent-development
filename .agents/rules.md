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
| `clean-ddd-hexagonal` | APIs, domain models, aggregates, use cases |
| `commit` | Before any git commit |
| `endpoint-trace` | Documenting or auditing an endpoint |
| `feature-docs` | After completing a feature |
| `find-skills` | User asks "how do I do X" |
| `openapi` | Adding, modifying, or deleting an endpoint |
| `query-memory` | Need deeper context beyond what the hook injected |
| `scan-memory` | Empty memory or major refactor |
| `skill-creator` | Adding agent instructions or patterns |
| `skill-sync` | After creating or modifying a skill |

## Auto-Invoke Skills

| Action | Skill |
|--------|-------|
| Before any git commit | `commit` |
| Designing APIs, domain models, use cases | `clean-ddd-hexagonal` |
| Adding or modifying an endpoint | `openapi` |
| Documenting a completed feature | `feature-docs` |
| Documenting an endpoint call chain | `endpoint-trace` |
| Creating or modifying a skill | `skill-creator` |
| After creating or modifying a skill | `skill-sync` |
| Finding or installing a skill | `find-skills` |

## Architecture Decision Records

| ADR | Decision |
|-----|----------|
| TODO | Add your ADRs here |
