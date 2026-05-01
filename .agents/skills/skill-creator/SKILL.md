---
name: skill-creator
description: >
  Creates new AI agent skills following the project skill spec.
  Trigger: When user asks to create a new skill, add agent instructions, or document
  patterns for AI reuse.
metadata:
  version: "1.0"
  scope: [root]
  auto_invoke:
    - "Creating a new skill"
    - "Adding agent instructions"
    - "Documenting a pattern for AI reuse"
    - "Crear un nuevo skill"
    - "Agregar instrucciones al agente"
    - "Documentar un patrón para reutilizar"
allowed-tools: Read, Edit, Write, Glob, Grep, Bash
---

## When to Create a Skill

Create a skill when:
- A pattern is used repeatedly and the agent needs explicit guidance
- Project conventions differ from generic best practices
- A workflow has enough steps that the agent needs a decision tree
- A new domain is added (new AWS service, new layer, new tool)

**Don't create a skill when:**
- The pattern is trivial or self-explanatory from the code
- It's a one-off task
- It's already covered by an existing skill — extend it instead

---

## Skill Structure

```
skills/{skill-name}/
├── SKILL.md          # Required — main skill file
└── references/       # Optional — pointers to local docs or ADRs
    └── notes.md
```

---

## SKILL.md Template

```markdown
---
name: {skill-name}
description: >
  {One-line description of what this skill does}.
  Trigger: {When the agent should load this skill}.
metadata:
  version: "1.0"
  scope: [root]
  auto_invoke:
    - "{Trigger phrase 1}"
    - "{Trigger phrase 2}"
allowed-tools: Read, Edit, Write, Glob, Grep, Bash
---

## When to Use

{Bullet points}

## Critical Rules

{The most important constraints}

## Patterns / Examples

{Minimal, focused code examples}

## Commands

```bash
{Copy-paste commands}
```
```

---

## Naming Conventions

| Type | Pattern | Example |
|------|---------|---------|
| Generic tech skill | `{technology}` | `go-aws`, `echo` |
| Project-specific | `{project}-{area}` | `discovery-api` |
| Workflow skill | `{action}` | `skill-creator`, `commit` |
| AWS-specific | `aws-{topic}` | `aws-mcp` |

---

## Scope Field

```yaml
scope: [root]                          # applies everywhere
scope: [root, internal/auth]           # auth-specific
scope: [root, src/main]               # source code
```

---

## Content Guidelines

### DO
- Lead with the most critical rules
- Use tables for decision trees and option comparisons
- Keep code examples minimal — one pattern per block
- Include a Commands section with copy-paste snippets
- Reference ADRs when a rule comes from an architectural decision

### DON'T
- Duplicate content from an existing skill — link to it
- Add web URLs in references — use local paths
- Write lengthy explanations — link to docs instead
- Create a skill for a pattern that only appears once

---

## After Creating a Skill

Run sync to update the skills tables:

```bash
bash .agents/scripts/sync.sh
```

---

## Checklist

- [ ] Skill doesn't already exist — checked `skills/`
- [ ] Pattern is reusable, not one-off
- [ ] Name follows conventions
- [ ] Frontmatter complete: `name`, `description` (with Trigger), `metadata`, `allowed-tools`
- [ ] `auto_invoke` phrases are defined
- [ ] Critical rules are explicit
- [ ] Code examples are minimal
