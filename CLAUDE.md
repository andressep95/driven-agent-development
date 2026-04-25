# Kernel — Skill-Driven Protocol

## Executive Summary
You are a **Skill-Driven Agent**. Logic improvisation is a system failure. Every action must be preceded by a skill lookup.

## Non-Negotiable Rules
1. **Skill Supremacy:** Check `Available Skills` before ANY development action.
2. **Mandatory Reporting:** If no skill applies, you MUST state: "Skill gap detected. Proceeding via general knowledge."
3. **Execution Rigor:** Follow loaded skill instructions exactly. Do not blend with external patterns.
4. **Context Sync:** Run `scan-memory` after structural changes to maintain RAG/DB accuracy.

## Execution Flow
1. **Match:** Scan `Auto-Invoke` for task triggers.
2. **Lookup:** Find relevant skills in `Available Skills` table.
3. **Load:** Read the specific `SKILL.md` file before generating output.
4. **State:** Declare the active skill to the user.
## Stack

**TODO: describe your stack here**

## Available Skills

| Skill | Description | File |
|-------|-------------|------|
| `changelog` | Manages CHANGELOG.md entries following keepachangelog.com format. Trigger: After committing a feat, fix, sec, perf, or refactor — or before creating a PR. | [SKILL.md](skills/changelog/SKILL.md) |
| `commit` | Enforces professional git commits using the Conventional Commits specification. Trigger: Before any git commit or when requested to commit changes. | [SKILL.md](skills/commit/SKILL.md) |
| `endpoint-trace` | Generates code-level trace documents for each HTTP endpoint, mapping the full call chain from the controller inward through every component it touches (services, repositories, AWS clients, shared utilities). Output lives in docs/traces/ and is meant for developers navigating the codebase, not end users. Trigger: When documenting a new endpoint at the code level, auditing dependencies of an existing endpoint, or creating an endpoint-to-component map. | [SKILL.md](skills/endpoint-trace/SKILL.md) |
| `feature-docs` | When a feature is marked as complete in api/openapi.yaml, generates a Markdown usage-flow document in docs/features/ explaining how to use it end-to-end. Trigger: After updating api/openapi.yaml with a completed endpoint. | [SKILL.md](skills/feature-docs/SKILL.md) |
| `find-skills` | Helps users discover and install agent skills when they ask questions like "how do I do X", "find a skill for X", "is there a skill that can...", or express interest in extending capabilities. This skill should be used when the user is looking for functionality that might exist as an installable skill. | [SKILL.md](skills/find-skills/SKILL.md) |
| `openapi` | Keeps api/openapi.yaml in sync with the Spring controllers in src/main/java. Trigger: After adding, modifying, or deleting any HTTP endpoint or changing a request/response schema. | [SKILL.md](skills/openapi/SKILL.md) |
| `scan-memory` | Scans the Java project and populates .agent/memory.jsonl with symbol locations, intent summaries, and tags. Ends by running rebuild.sh to produce a queryable memory.db. Trigger: First-time setup, memory.db missing or empty, after major refactors. | [SKILL.md](skills/scan-memory/SKILL.md) |
| `skill-creator` | Creates new AI agent skills following the project skill spec. Trigger: When user asks to create a new skill, add agent instructions, or document patterns for AI reuse. | [SKILL.md](skills/skill-creator/SKILL.md) |
| `skill-sync` | Keeps the Available Skills and Auto-Invoke Skills tables in sync with skill metadata after any skill is created or modified. Detects CLAUDE.md and .kiro/steering/project-rules.md by file existence and updates both. Trigger: After creating or modifying any SKILL.md file. | [SKILL.md](skills/skill-sync/SKILL.md) |

## Auto-Invoke Skills

When performing these actions, ALWAYS load the corresponding skill FIRST:

| Action | Skill |
|--------|-------|
| Adding a new endpoint | `openapi` |
| Adding agent instructions | `skill-creator` |
| After a major refactor affecting multiple files | `scan-memory` |
| After committing a bug fix | `changelog` |
| After committing a new feature | `changelog` |
| After committing a security change | `changelog` |
| After creating or modifying a skill | `skill-sync` |
| After updating api/openapi.yaml with a completed endpoint | `feature-docs` |
| Auto-invoke table is out of sync | `skill-sync` |
| Before creating a pull request | `changelog` |
| Bootstrap agent memory | `scan-memory` |
| Changing API responses | `openapi` |
| Changing request or response schema | `openapi` |
| Creating a new skill | `skill-creator` |
| Deleting an endpoint | `openapi` |
| Documenting a completed feature | `feature-docs` |
| Documenting a pattern for AI reuse | `skill-creator` |
| Feature is ready and needs usage documentation | `feature-docs` |
| Find a skill for a task | `find-skills` |
| First-time project setup | `scan-memory` |
| Install a new skill | `find-skills` |
| Modifying a Spring controller | `openapi` |
| Search for available skills | `find-skills` |
| Updating CHANGELOG.md | `changelog` |
| create code-level endpoint doc | `endpoint-trace` |
| document endpoint code trace | `endpoint-trace` |
| map endpoint call chain | `endpoint-trace` |
| memory.db is empty or missing | `scan-memory` |
| trace endpoint dependencies | `endpoint-trace` |

## Architecture Decision Records

Significant decisions are documented in `docs/decisions/`.

| ADR | Decision |
|-----|----------|
| TODO | Add your ADRs here |
