---
name: skill-sync
description: >
  Keeps the Available Skills and Auto-Invoke Skills tables in sync with skill
  metadata after any skill is created or modified. Detects CLAUDE.md and
  .kiro/steering/project-rules.md by file existence and updates both.
  Trigger: After creating or modifying any SKILL.md file.
metadata:
  version: "2.0"
  scope: [root]
  auto_invoke:
    - "After creating or modifying a skill"
    - "Auto-invoke table is out of sync"
allowed-tools: Read, Glob, Edit, Bash
---

## Commands

```bash
# Sync all skills into all detected context files
./skills/skill-sync/assets/sync.sh

# Preview without writing
./skills/skill-sync/assets/sync.sh --dry-run
```

---

## What the Script Does

After any skill is created or modified, perform these steps:

### 1. Detect context files

The script detects which context files exist and syncs only those:

| File | AI Assistant |
|------|-------------|
| `CLAUDE.md` | Claude Code |
| `.kiro/steering/project-rules.md` | Kiro |

No configuration needed — detection is purely file-based. If neither exists,
the script reports that and exits cleanly.

### 2. Read all skills

Read every `skills/*/SKILL.md` and extract:
- `name` — the skill identifier
- `description` — one-line description for the Available Skills table
- `metadata.auto_invoke` — list of trigger phrases for the Auto-Invoke table

### 3. Rebuild both tables in each detected file

Replaces the `## Available Skills` and `## Auto-Invoke Skills` sections with
freshly generated tables.

Rules:
- One row per `auto_invoke` phrase per skill
- Sort rows alphabetically by Action column
- Replace the full existing table — do not append

### 4. Report missing metadata

After syncing, lists any skills that are missing `auto_invoke` in their
frontmatter so they can be fixed.

---

## Required Metadata in Every SKILL.md

```yaml
metadata:
  version: "1.0"
  scope: [root]
  auto_invoke:
    - "Trigger phrase 1"
    - "Trigger phrase 2"
```

Skills missing `auto_invoke` appear in the "missing sync metadata" report but
are still listed in the Available Skills table.
