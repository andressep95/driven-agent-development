# Kernel — Skill-Driven Protocol

## Rules

1. **You know nothing about this project until you query memory.** Your training data has never seen this codebase.
2. **Before acting on existing code, query memory first.** Use `query-memory` to find what exists and why.
3. **Every task is executed through a skill.** No skill → no action. State `"Skill gap detected."` if none applies.
4. **Load the SKILL.md file before generating any output.** The name is not the protocol. The file is.
5. **Every commit body must include `what:`, `why:`, `breaking:`.** Empty fields break the RAG system.
6. **After every commit, wait for `/clear`.** Do not start the next task until context is reset. Chroma holds the memory — you do not need to.

## Execution Flow

```
task → query memory (if existing code) → load skill → execute → commit → wait for /clear
```

## Stack

**TODO: describe your stack here**

## Available Skills

| Skill | Description | File |
|-------|-------------|------|
| `changelog` | Manages CHANGELOG.md entries following keepachangelog.com format. Trigger: After committing a feat, fix, sec, perf, or refactor — or before creating a PR. | [SKILL.md](.agents/skills/changelog/SKILL.md) |
| `clean-ddd-hexagonal` | Clean Architecture + DDD + Hexagonal patterns for backend services. Trigger: APIs, microservices, domain models, aggregates, repositories, use cases, bounded contexts. | [SKILL.md](.agents/skills/clean-ddd-hexagonal/SKILL.md) |
| `commit` | Conventional Commits with structured what/why/breaking body for RAG memory. Trigger: Before any git commit. | [SKILL.md](.agents/skills/commit/SKILL.md) |
| `endpoint-trace` | Maps full call chain from controller inward. Output in docs/traces/. Trigger: Documenting or auditing an endpoint. | [SKILL.md](.agents/skills/endpoint-trace/SKILL.md) |
| `feature-docs` | Generates usage-flow docs in docs/features/. Trigger: After marking a feature complete in openapi.yaml. | [SKILL.md](.agents/skills/feature-docs/SKILL.md) |
| `find-skills` | Discovers and installs agent skills. Trigger: User asks "how do I do X" or "find a skill for X". | [SKILL.md](.agents/skills/find-skills/SKILL.md) |
| `memory-commit` | Protocol for writing what/why/breaking commit bodies. Reference for the full RAG memory model. | [SKILL.md](.agents/skills/memory-commit/SKILL.md) |
| `openapi` | Keeps api/openapi.yaml in sync with Spring controllers. Trigger: Adding, modifying, or deleting any endpoint or schema. | [SKILL.md](.agents/skills/openapi/SKILL.md) |
| `query-memory` | Semantic search over Chroma with JSONL fallback. Trigger: Need context about existing code before acting. | [SKILL.md](.agents/skills/query-memory/SKILL.md) |
| `scan-memory` | Scans git history into .agents/memory/memory.jsonl and syncs to Chroma. Trigger: First setup, empty memory, or major refactor. | [SKILL.md](.agents/skills/scan-memory/SKILL.md) |
| `skill-creator` | Creates new skills following the project spec. Trigger: Adding agent instructions or documenting a pattern. | [SKILL.md](.agents/skills/skill-creator/SKILL.md) |
| `skill-sync` | Syncs Available Skills and Auto-Invoke tables after skill changes. Trigger: After creating or modifying any SKILL.md. | [SKILL.md](.agents/skills/skill-sync/SKILL.md) |

## Auto-Invoke Skills

| Action | Skill |
|--------|-------|
| Before any git commit | `commit` |
| After committing feat / fix / refactor / perf / sec | `changelog` |
| Before creating a pull request | `changelog` |
| Need context about existing code before acting | `query-memory` |
| memory.jsonl is empty, missing, or after major refactor | `scan-memory` |
| Adding, modifying, or deleting an endpoint or schema | `openapi` |
| Designing APIs, domain models, aggregates, use cases | `clean-ddd-hexagonal` |
| Documenting a completed feature | `feature-docs` |
| Documenting or auditing an endpoint call chain | `endpoint-trace` |
| Creating or modifying a skill | `skill-creator` |
| After creating or modifying a skill | `skill-sync` |
| Finding or installing a skill | `find-skills` |

## Architecture Decision Records

| ADR | Decision |
|-----|----------|
| TODO | Add your ADRs here |
