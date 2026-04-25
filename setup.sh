#!/usr/bin/env bash
# Agent Skill Development — Project setup script.
# Lives at skills/setup.sh — one level above all skill folders.
#
# What it does:
#   1. Select target AI assistant(s): Claude Code, Kiro, or both
#   2. Create the global context file (CLAUDE.md / project-rules.md)
#      with the Agent Skill Development role and Skill-First Protocol
#   3. Bundle generic skills (changelog, commit, endpoint-trace, etc.)
#      into the target project's skills/ directory
#   4. Bundle .agent/ memory infrastructure (schema, scripts, hooks)
#   5. Run sync.sh to populate the Available Skills and Auto-Invoke tables
#
# Usage:
#   bash skills/setup.sh              # Interactive mode
#   bash skills/setup.sh --all        # Configure both Claude and Kiro
#   bash skills/setup.sh --claude     # Configure only Claude Code
#   bash skills/setup.sh --kiro       # Configure only Kiro
#   bash skills/setup.sh --help

set -e

REPO_ROOT="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
SKILLS_DIR="$REPO_ROOT/skills"

CLAUDE_MD="$REPO_ROOT/CLAUDE.md"
KIRO_RULES="$REPO_ROOT/.kiro/steering/project-rules.md"
SYNC_SH="$SKILLS_DIR/skill-sync/assets/sync.sh"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

SETUP_CLAUDE=false
SETUP_KIRO=false

# =============================================================================
# HELPERS
# =============================================================================

show_help() {
    echo "Usage: $0 [OPTIONS]"
    echo ""
    echo "Sets up Agent Skill Development context for AI assistants."
    echo ""
    echo "  --all      Configure both Claude Code and Kiro"
    echo "  --claude   Configure only Claude Code"
    echo "  --kiro     Configure only Kiro"
    echo "  --help     Show this help"
}

show_menu() {
    echo -e "${BOLD}Which AI assistant(s) do you want to configure?${NC}"
    echo -e "${CYAN}(Use numbers to toggle, Enter to confirm)${NC}"
    echo ""

    local options=("Claude Code  (CLAUDE.md)" "Kiro         (.kiro/steering/project-rules.md)")
    local selected=(true false)

    while true; do
        for i in "${!options[@]}"; do
            if [ "${selected[$i]}" = true ]; then
                echo -e "  ${GREEN}[x]${NC} $((i+1)). ${options[$i]}"
            else
                echo -e "  [ ] $((i+1)). ${options[$i]}"
            fi
        done
        echo ""
        echo -e "  ${YELLOW}a${NC}. Select all   ${YELLOW}n${NC}. Select none"
        echo ""
        echo -n "Toggle (1-2, a, n) or Enter to confirm: "
        read -r choice

        case $choice in
            1) selected[0]=$([ "${selected[0]}" = true ] && echo false || echo true) ;;
            2) selected[1]=$([ "${selected[1]}" = true ] && echo false || echo true) ;;
            a|A) selected=(true true) ;;
            n|N) selected=(false false) ;;
            "") break ;;
            *) echo -e "${RED}Invalid option${NC}" ;;
        esac
        echo -en "\033[9A\033[J"
    done

    SETUP_CLAUDE=${selected[0]}
    SETUP_KIRO=${selected[1]}
}

create_claude_md() {
    local file="$1"
    mkdir -p "$(dirname "$file")"
    cat > "$file" << 'TMPL'
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

## Auto-Invoke Skills

When performing these actions, ALWAYS load the corresponding skill FIRST:

| Action | Skill |
|--------|-------|

## Architecture Decision Records

Significant decisions are documented in `docs/decisions/`.

| ADR | Decision |
|-----|----------|
| TODO | Add your ADRs here |
TMPL
}

create_kiro_rules() {
    local file="$1"
    mkdir -p "$(dirname "$file")"
    cat > "$file" << 'TMPL'
---
inclusion: always
---

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

## Auto-Invoke Skills

When performing these actions, ALWAYS load the corresponding skill FIRST:

| Action | Skill |
|--------|-------|
TMPL
}

ensure_symlink() {
    local link="$1"   # e.g. .claude/skills
    local target="$2" # e.g. ../skills
    mkdir -p "$(dirname "$link")"
    if [ -L "$link" ]; then
        echo -e "  ${CYAN}–${NC} $(basename "$(dirname "$link")")/skills symlink already exists"
    else
        ln -sf "$target" "$link"
        echo -e "  ${GREEN}✓${NC} Created symlink: $(basename "$(dirname "$link")")/skills → $target"
    fi
}

# =============================================================================
# BUNDLED SKILLS — generic skills written into the target project
# =============================================================================

bundle_skills() {
    local dir="$1"
    local wrote=0

    echo -e "${CYAN}── Bundled Skills ──────────────────────────────────────────────────${NC}"

    # ── changelog ─────────────────────────────────────────────────────────
    if [ ! -f "$dir/changelog/SKILL.md" ]; then
        mkdir -p "$dir/changelog"
        cat > "$dir/changelog/SKILL.md" << 'SKILL_EOF'
---
name: changelog
description: >
  Manages CHANGELOG.md entries following keepachangelog.com format.
  Trigger: After committing a feat, fix, sec, perf, or refactor — or before creating a PR.
metadata:
  version: "1.0"
  scope: [root]
  auto_invoke:
    - "After committing a new feature"
    - "After committing a bug fix"
    - "After committing a security change"
    - "Before creating a pull request"
    - "Updating CHANGELOG.md"
allowed-tools: Read, Edit, Write, Bash
---

## Changelog Location

Single file at the project root: `CHANGELOG.md`

---

## Section Order — always this order

```markdown
## [Unreleased]

### Added
### Changed
### Fixed
### Security
### Performance
### Removed
### Deprecated
```

Only include sections that have entries. Do not add empty section headers.

---

## Entry Format

```markdown
### Added

- Existing entry [(#12)](https://github.com/org/discovery-service/pull/12)
- New entry goes at the BOTTOM of its section [(#15)](https://github.com/org/discovery-service/pull/15)
```

**Rules:**
- New entries always go at the **bottom** of their section
- One entry per commit/PR
- Be specific about what changed — not why (the ADR or commit body covers why)
- No period at the end of the entry
- No redundant verbs — the section header already implies the action
- PR link is optional locally, required before merging

---

## Commit Type → Changelog Section Mapping

| Commit type | Changelog section |
|-------------|-------------------|
| `feat` | `### Added` |
| `fix` | `### Fixed` |
| `sec` | `### Security` |
| `perf` | `### Performance` |
| `refactor` | `### Changed` |
| `chore` / `ci` / `test` / `docs` | No entry needed |

---

## Versioning — semver

| Change | Bump |
|--------|------|
| `fix`, `perf` only | PATCH — `0.1.0` → `0.1.1` |
| `feat`, `refactor`, `sec` | MINOR — `0.1.1` → `0.2.0` |
| Breaking change or `Removed` | MAJOR — `0.2.0` → `1.0.0` |

A breaking change is signaled by adding `BREAKING CHANGE:` in the commit footer.

---

## Releasing a Version

When releasing, move `[Unreleased]` entries to a dated version block:

```markdown
## [Unreleased]

---

## [0.2.0] - 2026-04-17

### Added

- Cross-account STS AssumeRole with ExternalId per tenant [(#3)](...)
- AWS Config Advanced Queries as primary discovery source [(#5)](...)

### Fixed

- Empty recorder status on fresh accounts not handled [(#7)](...)
```

Released versions are **immutable** — never modify a block that already has a version tag.

---

## Good vs Bad Entries

```markdown
# GOOD
- Cross-account discovery via STS AssumeRole with ExternalId [(#3)](...)
- Credential caching with 2-minute expiry buffer to avoid STS rate limits [(#8)](...)
- Empty recorder status on fresh AWS accounts [(#11)](...)

# BAD
- Added a new feature for discovery.     # redundant verb, has period
- fix bug                                # vague, no PR link
- This commit adds STS support (#3)      # conversational, wrong link format
- Updated the code to work better        # meaningless
```

---

## Workflow

```bash
# 1. Check what was just committed
git log -1 --oneline

# 2. Determine commit type → section mapping (see table above)

# 3. Open CHANGELOG.md and add entry at bottom of correct section

# 4. Verify format
head -40 CHANGELOG.md

# 5. Commit the changelog update
git add CHANGELOG.md
git commit -m "chore: update changelog for <brief description>"
```

---

## Checklist Before PR

- [ ] `CHANGELOG.md` has an entry for every `feat`, `fix`, `sec`, or `perf` commit
- [ ] Entries are at the bottom of their section
- [ ] No empty section headers
- [ ] No periods at the end of entries
- [ ] Released version blocks were not modified
- [ ] Version bump in `go.mod` matches the change type (PATCH / MINOR / MAJOR)
SKILL_EOF
        wrote=$((wrote + 1))
        echo -e "  ${GREEN}✓${NC} changelog"
    fi

    # ── commit ────────────────────────────────────────────────────────────
    if [ ! -f "$dir/commit/SKILL.md" ]; then
        mkdir -p "$dir/commit"
        cat > "$dir/commit/SKILL.md" << 'SKILL_EOF'
---
name: commit
description: >
  Enforces professional git commits using the Conventional Commits specification.
  Trigger: Before any git commit or when requested to commit changes.
metadata:
  version: "2.0"
  type: "Skill-Driven Constraint"
  auto_invoke:
    - "Before any git commit"
    - "Creating a git commit"
    - "Stage and commit changes"
    - "Write a commit message"
allowed-tools: Bash
---

## Critical Rules

- **Standard:** ALWAYS use `type(scope): description`.
- **Anonymity:** NEVER add AI signatures, co-authors, or "Generated by" lines.
- **Tone:** English, imperative mood (e.g., "Add feature" not "Added feature"), no trailing period.
- **Length:** First line < 72 characters. Body wrapped at 72 characters.
- **Confirmation:** ALWAYS show the message to the user and ask for confirmation before executing `git commit`.
- **Isolation:** NEVER use `git push --force`.
- **Complete History:** Stage ALL modified and untracked files by default (`git add -A`). Every change must be committed to maintain a faithful project history. Never silently leave files unstaged.
- **Sensitive File Guard:** Before staging, scan for files that should NOT be committed (`.env`, `*.key`, `*.pem`, credentials, secrets). Warn the user if any are found and exclude them explicitly.
- **Granularity:** If the diff spans clearly unrelated concerns (e.g., a feature change + a skill update), propose splitting into two commits. If the user confirms one commit, proceed with all changes in a single commit.

## Commitment Format

```text
type(scope): concise description in imperative mood

- Detailed change 1
- Detailed change 2 (if applicable)
```

## Mandatory Types

| Type       | Intent                                                          |
| :--------- | :-------------------------------------------------------------- |
| `feat`     | New capability, feature, or public API.                         |
| `fix`      | Bug fix or error handling correction.                           |
| `refactor` | Code change that neither fixes a bug nor adds a feature.        |
| `perf`     | Code change that improves performance.                          |
| `sec`      | Security hardening, vulnerability fixes, or permission changes. |
| `test`     | Adding missing tests or correcting existing tests.              |
| `docs`     | Documentation only (Markdown, Javadoc, comments).               |
| `chore`    | Build process, auxiliary tools, dependencies, or config.        |
| `ci`       | Changes to CI/CD pipelines and scripts.                         |

## Dynamic Scope Resolution (Agnostic)

Do NOT use hardcoded scopes. Instead, resolve the `(scope)` using these priority rules:

1. **Project Module:** The top-level directory or module name (e.g., `account`, `shared`, `ui`, `billing`).
2. **Architecture Layer:** If the change is layer-specific (e.g., `domain`, `infra`, `api`, `repo`).
3. **Skill/Tooling:** If changing the agent's brain (e.g., `skills`, `agent`, `memory`).
4. **Dependency:** Use `deps` for package manager changes (e.g., `pom.xml`, `go.mod`).
5. **Cross-Cutting:** Use `global` or `core` if the change affects the entire system.

_Rule: If the change spans multiple scopes, use the most significant one or omit it if it becomes too broad._

## Workflow

1. **Analysis:**
   ```bash
   git status
   git diff --stat HEAD
   ```
2. **Sensitive file check:** Scan the unstaged list for `.env`, `*.key`, `*.pem`, `*secret*`, `*credential*`. Warn the user if any appear — exclude them before staging.

3. **Granularity check:** If the diff spans clearly unrelated concerns, propose separate commits. If the user wants a single commit, proceed.

4. **Drafting:** Look at the 3 most recent commits to maintain project-specific style:
   ```bash
   git log -3 --oneline
   ```
5. **Interactive Commit:**
   - Present the draft to the user.
   - Upon confirmation, stage all changes and commit:
   ```bash
   git add -A
   git commit -m "type(scope): description"
   ```

## Examples

| Quality     | Message                                             | Reason                                      |
| :---------- | :-------------------------------------------------- | :------------------------------------------ |
| ✅ **Good** | `feat(api): add account verification endpoint`      | Correct type/scope, imperative.             |
| ✅ **Good** | `refactor(domain): move validation logic to entity` | Follows DDD boundaries.                     |
| ✅ **Good** | `sec(auth): redact account IDs in logs`             | Clear security intent.                      |
| ❌ **Bad**  | `fix: fixed the bug.`                               | Missing scope, past tense, trailing period. |
| ❌ **Bad**  | `feat(deps): update aws sdk`                        | Wrong type (should be `chore` or `deps`).   |

## Assets

- **Hook:** `.git/hooks/post-commit` → Triggers memory sync after success.
SKILL_EOF
        wrote=$((wrote + 1))
        echo -e "  ${GREEN}✓${NC} commit"

        # ── commit/assets/post-commit.sh ──────────────────────────────
        mkdir -p "$dir/commit/assets"
        if [ ! -f "$dir/commit/assets/post-commit.sh" ]; then
            cat > "$dir/commit/assets/post-commit.sh" << 'AGENT_EOF'
#!/usr/bin/env bash
# Git post-commit hook: syncs memory.jsonl for all tracked file types.
# Java files  → sync-memory.py  (line-level diff precision)
# Other files → sync-files.py   (.md, .sh, .py, .yaml, .yml, .sql, .json)
set -uo pipefail

AGENT_DIR=".agent"
JSONL="$AGENT_DIR/memory.jsonl"
CHROMA_URL="${CHROMA_URL:-http://localhost:8000}"

[ -f "$JSONL" ] || exit 0
! git rev-parse HEAD~1 >/dev/null 2>&1 && exit 0

# Java files
JAVA_ADDED=$(git diff --name-only --diff-filter=A HEAD~1 HEAD 2>/dev/null | grep '\.java$' || true)
JAVA_DELETED=$(git diff --name-only --diff-filter=D HEAD~1 HEAD 2>/dev/null | grep '\.java$' || true)
JAVA_MODIFIED=$(git diff --name-only --diff-filter=M HEAD~1 HEAD 2>/dev/null | grep '\.java$' || true)

# Non-Java tracked files
OTHER_ADDED=$(git diff --name-only --diff-filter=A HEAD~1 HEAD 2>/dev/null \
    | grep -E '\.(md|sh|py|yaml|yml|sql|json)$' \
    | grep -v 'memory\.jsonl\|memory\.db' || true)
OTHER_DELETED=$(git diff --name-only --diff-filter=D HEAD~1 HEAD 2>/dev/null \
    | grep -E '\.(md|sh|py|yaml|yml|sql|json)$' \
    | grep -v 'memory\.jsonl\|memory\.db' || true)
OTHER_MODIFIED=$(git diff --name-only --diff-filter=M HEAD~1 HEAD 2>/dev/null \
    | grep -E '\.(md|sh|py|yaml|yml|sql|json)$' \
    | grep -v 'memory\.jsonl\|memory\.db' || true)

HAS_JAVA=$([ -n "$JAVA_ADDED$JAVA_DELETED$JAVA_MODIFIED" ] && echo 1 || true)
HAS_OTHER=$([ -n "$OTHER_ADDED$OTHER_DELETED$OTHER_MODIFIED" ] && echo 1 || true)

[ -z "${HAS_JAVA}${HAS_OTHER}" ] && exit 0

echo "[memory] Files changed — syncing..."

if [ -n "${HAS_JAVA}" ]; then
    python3 "$AGENT_DIR/scripts/sync-memory.py" \
        --jsonl    "$JSONL" \
        --added    "$JAVA_ADDED" \
        --deleted  "$JAVA_DELETED" \
        --modified "$JAVA_MODIFIED"
fi

if [ -n "${HAS_OTHER}" ]; then
    python3 "$AGENT_DIR/scripts/sync-files.py" \
        --jsonl    "$JSONL" \
        --added    "$OTHER_ADDED" \
        --deleted  "$OTHER_DELETED" \
        --modified "$OTHER_MODIFIED"
fi

python3 "$AGENT_DIR/scripts/sync-to-chroma.py" --url "$CHROMA_URL" 2>&1 | tail -1
AGENT_EOF
            chmod +x "$dir/commit/assets/post-commit.sh"
            wrote=$((wrote + 1))
            echo -e "  ${GREEN}✓${NC} commit/assets/post-commit.sh"
        fi
    fi

    # ── endpoint-trace ────────────────────────────────────────────────
    if [ ! -f "$dir/endpoint-trace/SKILL.md" ]; then
        mkdir -p "$dir/endpoint-trace"
        cat > "$dir/endpoint-trace/SKILL.md" << 'SKILL_EOF'
---
name: endpoint-trace
description: >
  Generates code-level trace documents for each HTTP endpoint, mapping the full
  call chain from the controller inward through every component it touches
  (services, repositories, AWS clients, shared utilities). Output lives in
  docs/traces/ and is meant for developers navigating the codebase, not end users.
  Trigger: When documenting a new endpoint at the code level, auditing dependencies
  of an existing endpoint, or creating an endpoint-to-component map.
metadata:
  version: "1.0"
  scope: [root]
  auto_invoke:
    - "document endpoint code trace"
    - "trace endpoint dependencies"
    - "map endpoint call chain"
    - "create code-level endpoint doc"
allowed-tools: Read, Edit, Write, Glob, Grep, Bash
---

## When to Use

- After implementing a new endpoint and its full service chain
- When a developer needs to understand which components an endpoint touches
- When auditing which AWS SDK calls are made per endpoint
- When planning a refactor and needing to know the blast radius

---

## Critical Rules

- **Read the actual source** — never infer the call chain; always read the controller, service, and every class it calls
- **One document per endpoint** — each HTTP method+path gets its own file
- **Output location**: `docs/traces/{NN}-{method}-{slug}.md` (e.g., `01-post-accounts-connect.md`)
- **Never duplicate** — check `docs/traces/` for existing files before creating
- **Only document what the code actually does** — no speculation about future behavior

---

## Output Location

```
docs/traces/{NN}-{http-method}-{path-slug}.md
```

- `NN` — two-digit sequence (01, 02…). Check existing files for the next number.
- `http-method` — lowercase (`get`, `post`, `put`, `delete`)
- `path-slug` — path kebab-cased, drop `{id}` brackets (e.g., `accounts-id-config-activate`)

Examples:
```
01-post-accounts.md
02-post-accounts-id-verify.md
03-get-accounts-id.md
04-delete-accounts-id.md
05-put-accounts-id-discovery-source.md
06-get-accounts-id-config-status.md
07-post-accounts-id-config-activate.md
```

---

## How to Generate a Trace Document

### Step 1 — Find the controller method

Grep for the path in the controllers:
```bash
grep -r "config/activate\|configActivat" src/main/java --include="*.java" -l
```
Read the controller class, find the handler method, note:
- Exact method signature
- Which service(s) it calls
- What it returns

### Step 2 — Trace each service call

Read each service class the controller calls. For each service method, note:
- What it calls next (repositories, AWS clients, other services)
- What domain objects it touches
- What exceptions it can throw

### Step 3 — Trace repositories and AWS clients

Read repository interfaces + adapters. Read AWS client usage — note the exact SDK method called (`s3Client.createBucket`, `stsClient.assumeRole`, etc.) and the AWS service it maps to.

### Step 4 — Write the document

Use the template below.

---

## Document Template

````markdown
# {HTTP METHOD} {/path}

> `{ControllerClass}.{methodName}()` — {one-line summary of what this endpoint does}

## Call Chain

```
{ControllerClass}.{method}(params)
  └── {ServiceClass}.{method}(params)
        ├── {RepositoryInterface}.{method}()          [domain port]
        │     └── {JpaAdapterClass}.{method}()        [JPA]
        ├── {SharedService}.{method}()
        │     └── [{AWS_SERVICE}] SdkClient.sdkMethod()
        ├── {AnotherService}.{method}()
        │     ├── [{AWS_SERVICE}] SdkClient.sdkMethod()
        │     └── [{AWS_SERVICE}] SdkClient.sdkMethod()
        └── {HelperMethod}()
```

## Components

| Component | Layer | File |
|-----------|-------|------|
| `{ControllerClass}` | `api` | `{bounded-context}/api/{ControllerClass}.java` |
| `{ServiceClass}` | `application` | `{bounded-context}/application/{ServiceClass}.java` |

## AWS Calls

| Step | SDK Client | Method | AWS Service | Purpose |
|------|-----------|--------|-------------|---------|
| 1 | `{ClientType}` | `.{sdkMethod}()` | {AWS Service name} | {what it does} |

> Omit this section if the endpoint makes no AWS calls.

## Error Paths

| Exception | Thrown by | Maps to |
|-----------|-----------|---------|
| `{ExceptionClass}` | `{ComponentClass}` | `{HTTP_STATUS} {ERROR_CODE}` |
````

---

## Call Chain Notation

Use ASCII tree with these prefixes:

```
└──   last child
├──   non-last child
│     continuation line (vertical bar for indentation)
```

Labels: `[JPA]`, `[STS]`, `[S3]`, `[IAM]`, `[Config]`, `[CFN]`, `[Explorer]`, `[Cache]`, `[HTTP]`

---

## After Writing the Document

1. Create `docs/traces/README.md` if it doesn't exist.
2. Add a one-line entry linking to the new trace document.

---

## Checklist

- [ ] Read every class in the chain — no inferred steps
- [ ] All AWS SDK calls listed in the AWS Calls table
- [ ] All exception paths documented in Error Paths
- [ ] File named correctly: `{NN}-{method}-{slug}.md`
- [ ] `docs/traces/README.md` updated
SKILL_EOF
        wrote=$((wrote + 1))
        echo -e "  ${GREEN}✓${NC} endpoint-trace"
    fi

    # ── feature-docs ──────────────────────────────────────────────────────
    if [ ! -f "$dir/feature-docs/SKILL.md" ]; then
        mkdir -p "$dir/feature-docs"
        cat > "$dir/feature-docs/SKILL.md" << 'SKILL_EOF'
---
name: feature-docs
description: >
  When a feature is marked as complete in api/openapi.yaml, generates a Markdown
  usage-flow document in docs/features/ explaining how to use it end-to-end.
  Trigger: After updating api/openapi.yaml with a completed endpoint.
metadata:
  version: "1.0"
  scope: [root]
  auto_invoke:
    - "After updating api/openapi.yaml with a completed endpoint"
    - "Documenting a completed feature"
    - "Feature is ready and needs usage documentation"
allowed-tools: Read, Write, Glob, Grep
---

## When to Run This Skill

Run after:
1. The handler is implemented and working
2. `api/openapi.yaml` has been updated with the endpoint
3. The user confirms the feature is complete

Do NOT run for stubs, partial implementations, or endpoints that are still changing.

---

## Output Location

```
docs/features/{NN}-{feature-slug}.md
```

- `NN` — two-digit sequence number (01, 02, 03…)
- `feature-slug` — kebab-case name of the feature

Check existing files in `docs/features/` to pick the next sequence number.

---

## How to Generate the Document

### Step 1 — Read the endpoint from openapi.yaml

Find the relevant `operationId` in `api/openapi.yaml` and extract:
- HTTP method and path
- Summary and description
- Parameters (path, query)
- Request body schema (if any)
- All response schemas (success + errors)

### Step 2 — Read the handler implementation

Find the corresponding handler and extract:
- Actual validation logic
- What it calls internally
- Any edge cases or caveats not in the OpenAPI spec

### Step 3 — Write the document using the template below

---

## Document Template

````markdown
# {Feature Title}

> `{METHOD} {path}` — {one-line summary from OpenAPI}

## Overview

{2–4 sentences explaining what this feature does.}

## Prerequisites

{Bulleted list of what must be in place before using this endpoint.}

## Request

### Endpoint

```
{METHOD} /api/v1/{path}
```

### Request Body (only if applicable)

```json
{
  "field": "value"
}
```

## Response

### Success — `{status code}`

```json
{
  "data": { ... }
}
```

## Error Cases

| Code | HTTP | When |
|------|------|------|
| `{DOMAIN_ERROR_CODE}` | `{status}` | {condition} |

## Example

### Request

```bash
curl -X {METHOD} http://localhost:8080/api/v1/{path} \
  -H "Content-Type: application/json" \
  -d '{...}'
```

### Response

```json
{
  "data": { ... }
}
```
````

---

## Content Rules

- Write for a developer integrating this API for the first time
- Use real example values (fake ARNs, fake account IDs, real UUID format)
- Keep code blocks copy-pasteable
- No implementation details (no internal types or package names)

---

## After Writing the Document

Update `docs/features/README.md` (create it if it doesn't exist) with a one-line
entry for the new document.
SKILL_EOF
        wrote=$((wrote + 1))
        echo -e "  ${GREEN}✓${NC} feature-docs"
    fi

    # ── find-skills ──────────────────────────────────────────────────
    if [ ! -f "$dir/find-skills/SKILL.md" ]; then
        mkdir -p "$dir/find-skills"
        cat > "$dir/find-skills/SKILL.md" << 'SKILL_EOF'
---
name: find-skills
description: Helps users discover and install agent skills when they ask questions like "how do I do X", "find a skill for X", "is there a skill that can...", or express interest in extending capabilities. This skill should be used when the user is looking for functionality that might exist as an installable skill.
metadata:
  version: "1.0"
  scope: [root]
  auto_invoke:
    - "Find a skill for a task"
    - "Search for available skills"
    - "Install a new skill"
---

# Find Skills

This skill helps you discover and install skills from the open agent skills ecosystem.

## When to Use This Skill

Use this skill when the user:

- Asks "how do I do X" where X might be a common task with an existing skill
- Says "find a skill for X" or "is there a skill for X"
- Asks "can you do X" where X is a specialized capability
- Expresses interest in extending agent capabilities
- Wants to search for tools, templates, or workflows
- Mentions they wish they had help with a specific domain (design, testing, deployment, etc.)

## What is the Skills CLI?

The Skills CLI (`npx skills`) is the package manager for the open agent skills ecosystem. Skills are modular packages that extend agent capabilities with specialized knowledge, workflows, and tools.

**Key commands:**

- `npx skills find [query]` - Search for skills interactively or by keyword
- `npx skills add <package>` - Install a skill from GitHub or other sources
- `npx skills check` - Check for skill updates
- `npx skills update` - Update all installed skills

**Browse skills at:** https://skills.sh/

## How to Help Users Find Skills

### Step 1: Understand What They Need

When a user asks for help with something, identify:

1. The domain (e.g., React, testing, design, deployment)
2. The specific task (e.g., writing tests, creating animations, reviewing PRs)
3. Whether this is a common enough task that a skill likely exists

### Step 2: Check the Leaderboard First

Before running a CLI search, check the [skills.sh leaderboard](https://skills.sh/) to see if a well-known skill already exists for the domain.

### Step 3: Search for Skills

If the leaderboard doesn't cover the user's need, run the find command:

```bash
npx skills find [query]
```

### Step 4: Verify Quality Before Recommending

**Do not recommend a skill based solely on search results.** Always verify:

1. **Install count** — Prefer skills with 1K+ installs.
2. **Source reputation** — Official sources are more trustworthy than unknown authors.
3. **GitHub stars** — Check the source repository.

### Step 5: Present Options to the User

When you find relevant skills, present them with:

1. The skill name and what it does
2. The install count and source
3. The install command they can run
4. A link to learn more at skills.sh

### Step 6: Offer to Install

If the user wants to proceed:

```bash
npx skills add <owner/repo@skill> -g -y
```

The `-g` flag installs globally (user-level) and `-y` skips confirmation prompts.

## When No Skills Are Found

If no relevant skills exist:

1. Acknowledge that no existing skill was found
2. Offer to help with the task directly using your general capabilities
3. Suggest the user could create their own skill with `npx skills init`
SKILL_EOF
        wrote=$((wrote + 1))
        echo -e "  ${GREEN}✓${NC} find-skills"
    fi

    # ── openapi ───────────────────────────────────────────────────────────
    if [ ! -f "$dir/openapi/SKILL.md" ]; then
        mkdir -p "$dir/openapi"
        cat > "$dir/openapi/SKILL.md" << 'SKILL_EOF'
---
name: openapi
description: >
  Keeps api/openapi.yaml in sync with the Spring controllers in src/main/java.
  Trigger: After adding, modifying, or deleting any HTTP endpoint or changing a
  request/response schema.
metadata:
  version: "3.0"
  scope: [root, src/main]
  auto_invoke:
    - "Adding a new endpoint"
    - "Modifying a Spring controller"
    - "Changing API responses"
    - "Changing request or response schema"
    - "Deleting an endpoint"
allowed-tools: Read, Edit, Write, Glob, Grep
---

## File Location

```
api/openapi.yaml   ← single source of truth for the API contract
```

Always edit this file after any handler change. Never let it drift from the code.

---

## Critical Rules

- ALWAYS update `api/openapi.yaml` after any endpoint change
- NEVER document a field in OpenAPI that doesn't exist in the Java DTO/record
- ALWAYS use `$ref` for schemas used in more than one place
- Response envelope MUST match the `ApiResponse<T>` record in `shared/api/`
- `operationId` MUST be unique and match the Spring controller method name exactly
- ALWAYS read `api/openapi.yaml` before adding a new endpoint (check for naming conflicts)

---

## Controller → OpenAPI Mapping

For every Spring controller method, add or update a path entry:

```yaml
paths:
  /api/v1/accounts/{id}/resources:
    get:
      operationId: listResources
      summary: List discovered resources for an account
      tags: [discovery]
      parameters:
        - $ref: '#/components/parameters/AccountId'
      responses:
        '200':
          description: Resources listed successfully
          content:
            application/json:
              schema:
                $ref: '#/components/schemas/ResourceListResponse'
        '404':
          $ref: '#/components/responses/NotFound'
        '500':
          $ref: '#/components/responses/InternalError'
```

---

## HTTP Method → OpenAPI Verb

| Spring annotation | OpenAPI verb | Typical status |
|-------------------|--------------|----------------|
| `@PostMapping` | `post` | 201 (created) / 202 (async accepted) |
| `@GetMapping` | `get` | 200 |
| `@PutMapping` | `put` | 200 |
| `@PatchMapping` | `patch` | 200 |
| `@DeleteMapping` | `delete` | 204 |

---

## Tags

| Tag | Endpoints |
|-----|-----------|
| `accounts` | connect, status, delete |
| `discovery` | discover, resources, graph |
| `activation` | activate |
| `projects` | project-scoped resources |

---

## Workflow

1. Add or modify the controller in `src/main/java/.../api/`
2. Read `api/openapi.yaml` to check for naming conflicts and existing patterns
3. Add or update the path entry — reuse `$ref` components where possible
4. If a new schema is needed, add it to `components/schemas/`
5. Verify `operationId` matches the Spring controller method name exactly

---

## Checklist

- [ ] Path entry exists for every `@RequestMapping` method in the controller
- [ ] `operationId` matches the Spring controller method name
- [ ] Request body schema matches the Java DTO / record class
- [ ] Response schema matches the `ApiResponse<T>` envelope
- [ ] All error responses use `$ref` to standard error responses
- [ ] New schemas are in `components/schemas/`, not inlined
- [ ] Tags are consistent with the tags table above
SKILL_EOF
        wrote=$((wrote + 1))
        echo -e "  ${GREEN}✓${NC} openapi"
    fi

    # ── query-memory ─────────────────────────────────────────────────
    if [ ! -f "$dir/query-memory/SKILL.md" ]; then
        mkdir -p "$dir/query-memory"
        cat > "$dir/query-memory/SKILL.md" << 'SKILL_EOF'
---
name: query-memory
description: >
  Searches agent memory by semantic similarity (ChromaDB) with automatic
  fallback to keyword search over memory.jsonl when Chroma is unavailable.
  Trigger: Search codebase symbols by intent or behavior rather than exact name.
metadata:
  version: "1.0"
  scope: [root]
  auto_invoke:
    - "Search codebase by intent or behavior"
    - "Semantic search over agent memory"
    - "Find symbols by description"
    - "Query ChromaDB for code symbols"
allowed-tools: Bash
---

## When to Use

Prefer `query-memory` over SQLite FTS when:
- Searching by **behavior or intent** ("find the class that handles retries")
- The symbol name is unknown but its purpose is known
- Keyword search returns no results or too many irrelevant ones

Use SQLite FTS directly when you need exact keyword or file path matching.

---

## Commands

```bash
# Semantic query — uses Chroma if available, falls back to JSONL automatically
python3 .agent/scripts/query-memory.py "handles cross-account role assumption"

# Filter by kind: controller, service, repository, config, dto, domain
python3 .agent/scripts/query-memory.py "account onboarding" --kind service

# Limit results
python3 .agent/scripts/query-memory.py "pagination helpers" --limit 5

# Force JSONL-only (skip Chroma entirely)
python3 .agent/scripts/query-memory.py "credential caching" --no-chroma

# Custom Chroma URL
python3 .agent/scripts/query-memory.py "error handling" --url http://localhost:8000
```

---

## Fallback Behavior

The script auto-detects Chroma availability at query time:

| Chroma status | Behavior |
|---------------|----------|
| Running | Semantic vector search (ranked by embedding similarity) |
| Down / not installed | Keyword search over `.agent/memory.jsonl` |

No configuration needed — the fallback is transparent.

---

## Output Format

```
## ClassName (kind)
   File: src/main/java/...
   Lines: 14-120
   Intent: One-sentence description of what it does
   Score: 87.42%       ← similarity score (Chroma) or keyword matches (JSONL)
```

---

## Memory Must Be Populated

Before querying, ensure memory exists:

```bash
# Full bootstrap: scan Java files + push to Chroma
bash .agent/scripts/bootstrap.sh

# Or push existing memory.jsonl to Chroma only
python3 .agent/scripts/sync-to-chroma.py
```

Run `scan-memory` if `memory.jsonl` is empty or missing.
SKILL_EOF
        wrote=$((wrote + 1))
        echo -e "  ${GREEN}✓${NC} query-memory"
    fi

    # ── skill-creator ────────────────────────────────────────────────
    if [ ! -f "$dir/skill-creator/SKILL.md" ]; then
        mkdir -p "$dir/skill-creator"
        cat > "$dir/skill-creator/SKILL.md" << 'SKILL_EOF'
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
bash skills/skill-sync/assets/sync.sh
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
SKILL_EOF
        wrote=$((wrote + 1))
        echo -e "  ${GREEN}✓${NC} skill-creator"
    fi

    # ── scan-memory ──────────────────────────────────────────────────
    if [ ! -f "$dir/scan-memory/SKILL.md" ]; then
        mkdir -p "$dir/scan-memory"
        cat > "$dir/scan-memory/SKILL.md" << 'SKILL_EOF'
---
name: scan-memory
description: >
  Scans the Java project and populates .agent/memory.jsonl with symbol locations,
  intent summaries, and tags. Ends by running rebuild.sh to produce a queryable memory.db.
  Trigger: First-time setup, memory.db missing or empty, after major refactors.
metadata:
  version: "1.0"
  scope: [root]
  auto_invoke:
    - "memory.db is empty or missing"
    - "First-time project setup"
    - "After a major refactor affecting multiple files"
    - "Bootstrap agent memory"
allowed-tools: Read, Bash, Write
---

## Purpose

Bootstraps `.agent/memory.jsonl` by scanning every Java file in `src/main/java`,
reading each symbol's code, generating a one-sentence `intent`, assigning `tags`,
and writing structured JSONL entries. Ends by running `rebuild.sh` to produce
a queryable `memory.db`.

## When to Run

- First time any dev (or agent) clones the project
- `memory.db` is missing or returns no results
- After a large refactor that moves or renames multiple files
- Manually triggered: `bash .agent/scripts/scan.sh`

---

## Step-by-Step Procedure

### Step 1 — Run the mechanical scan

```bash
bash .agent/scripts/scan.sh
```

### Step 2 — For each symbol, read and summarize

Generate:
- `intent` — one sentence: what does it do?
- `tags` — JSON array from: controller, service, repository, domain, config, dto,
  util, aws, sts, s3, account, discovery, resource, shared, auth, validation,
  error-handling, pagination, caching, credentials

### Step 3 — Write JSONL entries to `.agent/memory.jsonl`

```jsonl
{"type":"symbol","file":"path/to/File.java","symbol":"ClassName","kind":"controller","lines":[14,120],"intent":"one sentence","tags":["controller","account"],"commit":"GIT_HASH","ts":"YYYY-MM-DD"}
```

### Step 4 — Rebuild the DB

```bash
bash .agent/scripts/rebuild.sh
```

### Step 5 — Sync to Chroma (optional)

If ChromaDB is running, push memory to the vector search index:

```bash
bash .agent/scripts/bootstrap.sh
# or directly:
python3 .agent/scripts/sync-to-chroma.py --url "\${CHROMA_URL:-http://localhost:8000}"
```

Skip this step if ChromaDB is not available — SQLite FTS remains fully functional.

### Step 6 — Verify

```bash
sqlite3 .agent/memory.db \
  "SELECT c.file_path, c.line_start, c.line_end, c.intent
   FROM code_search s JOIN codebase_index c ON s.rowid = c.id
   WHERE code_search MATCH 'account' ORDER BY rank LIMIT 5;"
```

---

## How the Agent Uses Memory

```bash
sqlite3 .agent/memory.db \
  "SELECT c.file_path, c.line_start, c.line_end, c.intent
   FROM code_search s JOIN codebase_index c ON s.rowid = c.id
   WHERE code_search MATCH 'KEYWORDS' ORDER BY rank LIMIT 10;"
```

Then: `sed -n 'LINE_START,LINE_ENDp' FILE_PATH`

---

## Git Rules

- `memory.db` → `.gitignore` (rebuilt locally)
- `memory.jsonl` → committed (portable source of truth)
SKILL_EOF
        wrote=$((wrote + 1))
        echo -e "  ${GREEN}✓${NC} scan-memory"
    fi

    # ── skill-sync ────────────────────────────────────────────────────
    if [ ! -f "$dir/skill-sync/SKILL.md" ]; then
        mkdir -p "$dir/skill-sync"
        cat > "$dir/skill-sync/SKILL.md" << 'SKILL_EOF'
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
SKILL_EOF
        wrote=$((wrote + 1))
        echo -e "  ${GREEN}✓${NC} skill-sync/SKILL.md"
    fi

    # ── skill-sync/assets/sync.sh ────────────────────────────────────
    if [ ! -f "$dir/skill-sync/assets/sync.sh" ]; then
        mkdir -p "$dir/skill-sync/assets"
        cat > "$dir/skill-sync/assets/sync.sh" << 'SYNCSH_EOF'
#!/usr/bin/env bash
# Skill Sync — Updates Auto-Invoke Skills table in all detected context files.
#
# Detection (file existence, no config needed):
#   CLAUDE.md                          → Claude Code context
#   .kiro/steering/project-rules.md    → Kiro context
#
# Usage:
#   ./sync.sh             # Auto-detect and sync all existing context files
#   ./sync.sh --dry-run   # Preview without writing
#   ./sync.sh --help

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(dirname "$(dirname "$(dirname "$SCRIPT_DIR")")")"
SKILLS_DIR="$REPO_ROOT/skills"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

DRY_RUN=false

while [[ $# -gt 0 ]]; do
    case $1 in
        --dry-run) DRY_RUN=true; shift ;;
        --help|-h)
            echo "Usage: $0 [--dry-run]"
            echo ""
            echo "Syncs the Auto-Invoke Skills table into all detected context files."
            echo "Detection is file-based — no configuration required."
            echo ""
            echo "  CLAUDE.md                        → Claude Code"
            echo "  .kiro/steering/project-rules.md  → Kiro"
            exit 0 ;;
        *) echo -e "${RED}Unknown option: $1${NC}"; exit 1 ;;
    esac
done

# ── detect targets ────────────────────────────────────────────────────────────

TARGETS=()
[ -f "$REPO_ROOT/CLAUDE.md" ]                              && TARGETS+=("Claude Code|$REPO_ROOT/CLAUDE.md")
[ -f "$REPO_ROOT/.kiro/steering/project-rules.md" ]       && TARGETS+=("Kiro|$REPO_ROOT/.kiro/steering/project-rules.md")

echo -e "${BLUE}Skill Sync — syncing Auto-Invoke tables${NC}"
echo "======================================="
echo ""

if [ ${#TARGETS[@]} -eq 0 ]; then
    echo -e "${YELLOW}No context files found. Run setup first:${NC}"
    echo "  bash skills/mcp-sync/assets/setup.sh"
    exit 0
fi

echo -e "Detected context files:"
for t in "${TARGETS[@]}"; do
    label="${t%%|*}"; path="${t##*|}"
    echo -e "  ${GREEN}✓${NC} $label  →  ${path#$REPO_ROOT/}"
done
echo ""

# ── helpers ───────────────────────────────────────────────────────────────────

extract_field() {
    local file="$1" field="$2"
    awk -v field="$field" '
        /^---$/ { in_frontmatter = !in_frontmatter; next }
        in_frontmatter && $1 == field":" {
            sub(/^[^:]+:[[:space:]]*/, "")
            if ($0 != "" && $0 != ">") { gsub(/^["'"'"']|["'"'"']$/, ""); print; exit }
            getline
            while (/^[[:space:]]/ && !/^---$/) { sub(/^[[:space:]]+/, ""); printf "%s ", $0; if (!getline) break }
            print ""; exit
        }
    ' "$file" | sed 's/[[:space:]]*$//'
}

extract_auto_invoke() {
    local file="$1"
    awk '
        function trim(s) { sub(/^[[:space:]]+/, "", s); sub(/[[:space:]]+$/, "", s); return s }
        /^---$/ { in_fm = !in_fm; next }
        in_fm && /^metadata:/ { in_meta = 1; next }
        in_fm && in_meta && /^[a-z]/ && !/^[[:space:]]/ { in_meta = 0 }
        in_fm && in_meta && $1 == "auto_invoke:" {
            sub(/^[^:]+:[[:space:]]*/, "")
            if ($0 != "") { v = $0; gsub(/^["'"'"']|["'"'"']$/, "", v); print trim(v); exit }
            out = ""
            while (getline) {
                if (!in_fm || !in_meta) break
                if ($0 ~ /^[a-z]/ && $0 !~ /^[[:space:]]/) break
                if ($0 ~ /^---$/) break
                line = $0
                if (line ~ /^[[:space:]]*-[[:space:]]*/) {
                    sub(/^[[:space:]]*-[[:space:]]*/, "", line); line = trim(line)
                    gsub(/^["'"'"']|["'"'"']$/, "", line)
                    if (line != "") out = (out == "") ? line : out "|" line
                } else break
            }
            if (out != "") print out
            exit
        }
    ' "$file"
}

# ── collect all skill rows ────────────────────────────────────────────────────

ROWS_FILE=$(mktemp)
SKILLS_TABLE_FILE=$(mktemp)
trap 'rm -f "$ROWS_FILE" "$SKILLS_TABLE_FILE"' EXIT

while IFS= read -r skill_file; do
    [ -f "$skill_file" ] || continue
    name=$(extract_field "$skill_file" "name")
    desc=$(extract_field "$skill_file" "description")
    [ -z "$name" ] && continue

    # Skills table row
    rel_path="${skill_file#$REPO_ROOT/}"
    printf "%s\t%s\t%s\n" "$name" "$desc" "$rel_path" >> "$SKILLS_TABLE_FILE"

    # Auto-invoke rows
    auto_raw=$(extract_auto_invoke "$skill_file")
    [ -z "$auto_raw" ] && continue
    echo "$auto_raw" | tr '|' '\n' | while read -r action; do
        action="$(echo "$action" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')"
        [ -z "$action" ] && continue
        printf "%s\t%s\n" "$action" "$name" >> "$ROWS_FILE"
    done
done < <(find "$SKILLS_DIR" -mindepth 2 -maxdepth 2 -name SKILL.md -print | sort)

# Build skills table markdown
SKILLS_TABLE="## Available Skills

| Skill | Description | File |
|-------|-------------|------|"
while IFS=$'\t' read -r name desc path; do
    SKILLS_TABLE="$SKILLS_TABLE
| \`$name\` | $desc | [SKILL.md]($path) |"
done < <(LC_ALL=C sort "$SKILLS_TABLE_FILE")

# Build auto-invoke table markdown
AUTO_INVOKE="## Auto-Invoke Skills

When performing these actions, ALWAYS load the corresponding skill FIRST:

| Action | Skill |
|--------|-------|"
while IFS=$'\t' read -r action name; do
    [ -z "$action" ] && continue
    AUTO_INVOKE="$AUTO_INVOKE
| $action | \`$name\` |"
done < <(LC_ALL=C sort -t $'\t' -k1,1 -k2,2 "$ROWS_FILE")

# ── update each detected context file ────────────────────────────────────────

update_section() {
    local file="$1" section_header="$2" new_content="$3"
    local section_file
    section_file=$(mktemp)
    echo "$new_content" > "$section_file"

    if grep -q "^$section_header" "$file"; then
        awk -v hdr="$section_header" -v sec="$section_file" '
            $0 ~ "^" hdr {
                while ((getline line < sec) > 0) print line
                close(sec); skip = 1; next
            }
            skip && /^## / { skip = 0; print ""; print; next }
            !skip { print }
        ' "$file" > "$file.tmp" && mv "$file.tmp" "$file"
    else
        echo "" >> "$file"
        cat "$section_file" >> "$file"
    fi
    rm -f "$section_file"
}

for t in "${TARGETS[@]}"; do
    label="${t%%|*}"; file="${t##*|}"
    rel="${file#$REPO_ROOT/}"

    echo -e "${CYAN}── $label  ($rel) ──────────────────────────────────────────${NC}"

    if $DRY_RUN; then
        echo -e "${YELLOW}[DRY RUN] Would update Available Skills and Auto-Invoke Skills sections${NC}"
        echo ""
        continue
    fi

    update_section "$file" "## Available Skills"    "$SKILLS_TABLE"
    echo -e "  ${GREEN}✓${NC} Available Skills updated"

    update_section "$file" "## Auto-Invoke Skills"  "$AUTO_INVOKE"
    echo -e "  ${GREEN}✓${NC} Auto-Invoke Skills updated"
    echo ""
done

# ── report skills missing metadata ───────────────────────────────────────────

echo -e "${BLUE}Skills missing sync metadata:${NC}"
missing=0
while IFS= read -r skill_file; do
    [ -f "$skill_file" ] || continue
    name=$(extract_field "$skill_file" "name")
    auto=$(extract_auto_invoke "$skill_file")
    if [ -z "$auto" ]; then
        echo -e "  ${YELLOW}$name${NC} — missing auto_invoke in metadata"
        missing=$((missing + 1))
    fi
done < <(find "$SKILLS_DIR" -mindepth 2 -maxdepth 2 -name SKILL.md -print | sort)
[ $missing -eq 0 ] && echo -e "  ${GREEN}All skills have sync metadata${NC}"
echo ""
echo -e "${GREEN}Done.${NC}"
SYNCSH_EOF
        chmod +x "$dir/skill-sync/assets/sync.sh"
        wrote=$((wrote + 1))
        echo -e "  ${GREEN}✓${NC} skill-sync/assets/sync.sh"
    fi

    if [ $wrote -eq 0 ]; then
        echo -e "  ${CYAN}–${NC} All bundled skills already exist"
    else
        echo -e "  ${GREEN}Wrote $wrote bundled skill(s)${NC}"
    fi
    echo ""
}

# =============================================================================
# BUNDLED .agent/ — memory infrastructure written into the target project
# =============================================================================

bundle_agent_dir() {
    local root="$1"
    local dir="$root/.agent"
    local wrote=0

    echo -e "${CYAN}── Agent Memory Infrastructure ─────────────────────────────────────${NC}"

    # ── schema.sql ────────────────────────────────────────────────────
    if [ ! -f "$dir/schema.sql" ]; then
        mkdir -p "$dir/scripts"
        cat > "$dir/schema.sql" << 'AGENT_EOF'
CREATE TABLE IF NOT EXISTS codebase_index (
    id          INTEGER PRIMARY KEY AUTOINCREMENT,
    file_path   TEXT NOT NULL,
    symbol_name TEXT,
    symbol_type TEXT,
    line_start  INTEGER,
    line_end    INTEGER,
    intent      TEXT,
    tags        TEXT,
    author      TEXT,
    email       TEXT,
    git_hash    TEXT,
    updated_at  TEXT
);

-- Full-text search over file_path, symbol_name, intent, tags
CREATE VIRTUAL TABLE IF NOT EXISTS code_search USING fts5(
    file_path,
    symbol_name,
    intent,
    tags,
    content='codebase_index',
    content_rowid='id'
);

-- Architectural decisions that don't live in code or git messages
CREATE TABLE IF NOT EXISTS decisions (
    id        INTEGER PRIMARY KEY AUTOINCREMENT,
    context   TEXT,
    decision  TEXT,
    reason    TEXT,
    tags      TEXT,
    author    TEXT,
    email     TEXT,
    git_hash  TEXT,
    timestamp TEXT
);

-- Search effectiveness log: lets the agent learn which queries return useful results
CREATE TABLE IF NOT EXISTS search_log (
    id          INTEGER PRIMARY KEY AUTOINCREMENT,
    query       TEXT,
    result_file TEXT,
    result_sym  TEXT,
    was_used    INTEGER DEFAULT 0,  -- 1 = agent actually read this result
    timestamp   TEXT
);
AGENT_EOF
        wrote=$((wrote + 1))
        echo -e "  ${GREEN}✓${NC} schema.sql"
    fi

    # ── rebuild.sh ────────────────────────────────────────────────────
    if [ ! -f "$dir/scripts/rebuild.sh" ]; then
        mkdir -p "$dir/scripts"
        cat > "$dir/scripts/rebuild.sh" << 'AGENT_EOF'
#!/usr/bin/env bash
# Rebuilds memory.db from memory.jsonl. Run after any write to memory.jsonl.
# Usage: bash .agent/scripts/rebuild.sh
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
DB="$ROOT/.agent/memory.db"
JSONL="$ROOT/.agent/memory.jsonl"
SCHEMA="$ROOT/.agent/schema.sql"

echo "Rebuilding $DB..."
rm -f "$DB"
sqlite3 "$DB" < "$SCHEMA"

if [ ! -s "$JSONL" ]; then
    echo "memory.jsonl is empty — blank DB created."
    exit 0
fi

python3 - "$DB" "$JSONL" << 'PYEOF'
import json, sqlite3, sys

db = sqlite3.connect(sys.argv[1])
symbols = 0
decisions = 0

with open(sys.argv[2]) as f:
    for raw in f:
        raw = raw.strip()
        if not raw:
            continue
        try:
            r = json.loads(raw)
        except json.JSONDecodeError as e:
            print(f"  skipping malformed line: {e}", file=sys.stderr)
            continue

        if r.get("type") == "symbol":
            lines = r.get("lines", [None, None])
            db.execute(
                "INSERT INTO codebase_index "
                "(file_path,symbol_name,symbol_type,line_start,line_end,intent,tags,git_hash,updated_at) "
                "VALUES (?,?,?,?,?,?,?,?,?)",
                (r.get("file"), r.get("symbol"), r.get("kind"),
                 lines[0] if lines else None,
                 lines[1] if len(lines) > 1 else None,
                 r.get("intent"),
                 json.dumps(r.get("tags", [])),
                 r.get("commit"), r.get("ts"))
            )
            symbols += 1

        elif r.get("type") == "decision":
            db.execute(
                "INSERT INTO decisions (context,decision,reason,tags,git_hash,timestamp) "
                "VALUES (?,?,?,?,?,?)",
                (r.get("context"), r.get("decision"), r.get("reason"),
                 json.dumps(r.get("tags", [])),
                 r.get("commit"), r.get("ts"))
            )
            decisions += 1

db.execute("INSERT INTO code_search(code_search) VALUES('rebuild')")
db.commit()
db.close()
print(f"Done: {symbols} symbols, {decisions} decisions.")
PYEOF
AGENT_EOF
        chmod +x "$dir/scripts/rebuild.sh"
        wrote=$((wrote + 1))
        echo -e "  ${GREEN}✓${NC} scripts/rebuild.sh"
    fi

    # ── scan.sh ─────────────────────────────────────────────────────
    if [ ! -f "$dir/scripts/scan.sh" ]; then
        mkdir -p "$dir/scripts"
        cat > "$dir/scripts/scan.sh" << 'AGENT_EOF'
#!/usr/bin/env bash
# Scans the Java source tree and emits raw symbol locations for agent processing.
# Usage: bash .agent/scripts/scan.sh
set -uo pipefail

JAVA_ROOT="src/main/java"

if [ ! -d "$JAVA_ROOT" ]; then
    echo "ERROR: $JAVA_ROOT not found. Run from project root." >&2
    exit 1
fi

echo "# SCAN — $(date +%Y-%m-%d)"
echo ""

echo "## FILES"
find "$JAVA_ROOT" -name "*.java" | sort | while read -r f; do
    hash=$(git log --follow -1 --format="%h" -- "$f" 2>/dev/null || echo "unknown")
    date=$(git log --follow -1 --format="%ad" --date=format:"%Y-%m-%d" -- "$f" 2>/dev/null || echo "unknown")
    echo "  $f COMMIT=$hash DATE=$date"
done
echo ""

echo "## CLASSES"
find "$JAVA_ROOT" -name "*.java" | sort | while read -r f; do
    total=$(wc -l < "$f")
    hash=$(git log --follow -1 --format="%h" -- "$f" 2>/dev/null || echo "unknown")
    grep -n "^public class \|^public interface \|^public enum \|^public record \|^  public class \|^  public record " "$f" 2>/dev/null \
    | while IFS=: read -r lineno rest; do
        ann=$(awk "NR>=$((lineno-3)) && NR<$lineno && /^@/" "$f" | tr '\n' ',' | sed 's/,$//')
        echo "  FILE=$f COMMIT=$hash LINE=$lineno TOTAL=$total ANN='$ann' DEF='$(echo "$rest" | sed "s/^ //")'"
    done
done
echo ""

echo "## ENDPOINTS"
find "$JAVA_ROOT" -name "*.java" | sort | while read -r f; do
    hash=$(git log --follow -1 --format="%h" -- "$f" 2>/dev/null || echo "unknown")
    grep -n "@GetMapping\|@PostMapping\|@PutMapping\|@DeleteMapping\|@PatchMapping\|@RequestMapping" "$f" 2>/dev/null \
    | while IFS=: read -r lineno rest; do
        method=$(awk "NR>$lineno && NR<=$((lineno+3)) && /public/" "$f" | grep -o '[a-zA-Z][a-zA-Z0-9]*(' | head -1 | tr -d '(')
        echo "  FILE=$f COMMIT=$hash LINE=$lineno METHOD='$method' MAPPING='$(echo "$rest" | sed "s/^ //")'"
    done
done
echo ""

echo "## METHODS"
find "$JAVA_ROOT" -name "*.java" | sort | while read -r f; do
    hash=$(git log --follow -1 --format="%h" -- "$f" 2>/dev/null || echo "unknown")
    grep -n "    public [a-zA-Z<@]" "$f" 2>/dev/null \
    | grep -v "class \|interface \|enum \|record \|get[A-Z]\|set[A-Z]\|is[A-Z]\|equals\|hashCode\|toString\|Builder" \
    | while IFS=: read -r lineno rest; do
        echo "  FILE=$f COMMIT=$hash LINE=$lineno SIG='$(echo "$rest" | sed "s/^ //")'"
    done
done
echo ""

echo "## CONFIG"
find "$JAVA_ROOT" -name "*.java" | sort | while read -r f; do
    hash=$(git log --follow -1 --format="%h" -- "$f" 2>/dev/null || echo "unknown")
    grep -n "@ConfigurationProperties" "$f" 2>/dev/null \
    | while IFS=: read -r lineno rest; do
        total=$(wc -l < "$f")
        echo "  FILE=$f COMMIT=$hash LINE=$lineno TOTAL=$total DEF='$(echo "$rest" | sed "s/^ //")'"
    done
done
AGENT_EOF
        chmod +x "$dir/scripts/scan.sh"
        wrote=$((wrote + 1))
        echo -e "  ${GREEN}✓${NC} scripts/scan.sh"
    fi

    # ── sync-files.py ────────────────────────────────────────────
    if [ ! -f "$dir/scripts/sync-files.py" ]; then
        mkdir -p "$dir/scripts"
        cat > "$dir/scripts/sync-files.py" << 'AGENT_EOF'
#!/usr/bin/env python3
"""
Tracks non-Java file changes in memory.jsonl.
Called by post-commit hook for .md, .sh, .py, .yaml, .yml, .sql, .json files.
For SKILL.md files: extracts name/description from frontmatter.
For other files: records file-level change with path and kind.
"""
import json, sys, os, re, subprocess, argparse
from datetime import date

TRACKED_EXTENSIONS = {'.md', '.sh', '.py', '.yaml', '.yml', '.sql', '.json'}
FILE_TYPES_TO_KIND = {
    '.sh':   'script',
    '.py':   'script',
    '.yaml': 'config',
    '.yml':  'config',
    '.sql':  'config',
    '.json': 'config',
    '.md':   'doc',
}

def git_hash(path):
    r = subprocess.run(
        ['git', 'log', '--follow', '-1', '--format=%h', '--', path],
        capture_output=True, text=True
    )
    return r.stdout.strip() or 'unknown'

def git_date(path):
    r = subprocess.run(
        ['git', 'log', '--follow', '-1', '--format=%ad', '--date=format:%Y-%m-%d', '--', path],
        capture_output=True, text=True
    )
    return r.stdout.strip() or str(date.today())

def extract_skill_meta(path):
    try:
        with open(path) as f:
            content = f.read()
        name_m = re.search(r'^name:\s*(.+)$', content, re.MULTILINE)
        name = name_m.group(1).strip() if name_m else None
        desc_block = re.search(r'^description:\s*>\s*\n((?:[ \t]+.+\n)+)', content, re.MULTILINE)
        if desc_block:
            desc = ' '.join(line.strip() for line in desc_block.group(1).strip().splitlines())
        else:
            desc_line = re.search(r'^description:\s*(.+)$', content, re.MULTILINE)
            desc = desc_line.group(1).strip() if desc_line else None
        return name, desc
    except Exception:
        return None, None

def extract_intent(path):
    ext = os.path.splitext(path)[1].lower()
    basename = os.path.basename(path)
    try:
        with open(path) as f:
            lines = [l.rstrip() for l in f.readlines()]
        if ext == '.sh':
            for line in lines:
                if line.startswith('#') and not line.startswith('#!'):
                    intent = line.lstrip('#').strip()
                    if intent:
                        return intent
            fns = [re.match(r'^(\w+)\s*\(\)', l) for l in lines]
            names = [m.group(1) for m in fns if m]
            if names:
                return f"Shell script — functions: {', '.join(names[:5])}"
        elif ext == '.py':
            joined = '\n'.join(lines)
            doc = re.search(r'"""(.+?)"""', joined, re.DOTALL)
            if doc:
                return doc.group(1).strip().splitlines()[0]
            for line in lines:
                if line.startswith('#') and not line.startswith('#!'):
                    intent = line.lstrip('#').strip()
                    if intent:
                        return intent
        elif ext == '.md':
            for line in lines:
                if line.startswith('#'):
                    return line.lstrip('#').strip()
        elif ext in ('.yaml', '.yml'):
            for line in lines:
                if line.startswith('#'):
                    intent = line.lstrip('#').strip()
                    if intent:
                        return intent
            for line in lines:
                if line and not line.startswith(' '):
                    return f"Config key: {line.split(':')[0].strip()}"
        elif ext == '.sql':
            for line in lines:
                if line.startswith('--'):
                    intent = line.lstrip('-').strip()
                    if intent:
                        return intent
    except Exception:
        pass
    return basename

def classify_file(path):
    basename = os.path.basename(path)
    ext = os.path.splitext(basename)[1].lower()
    if basename == 'SKILL.md':
        name, desc = extract_skill_meta(path)
        return 'skill', name or basename, desc or 'Agent skill definition'
    if basename == 'CLAUDE.md':
        return 'config', 'CLAUDE.md', 'Agent context and skill-driven protocol'
    kind = FILE_TYPES_TO_KIND.get(ext, 'file')
    intent = extract_intent(path)
    return kind, basename, intent

def should_track(path):
    ext = os.path.splitext(path)[1].lower()
    if ext not in TRACKED_EXTENSIONS:
        return False
    if os.path.basename(path) in ('memory.jsonl', 'memory.db'):
        return False
    return True

def split_files(raw):
    return [f.strip() for f in (raw or '').split('\n') if f.strip()]

def load_jsonl(path):
    entries = []
    if not os.path.exists(path):
        return entries
    with open(path) as f:
        for raw in f:
            raw = raw.strip()
            if raw:
                try:
                    entries.append(json.loads(raw))
                except json.JSONDecodeError:
                    pass
    return entries

NON_JAVA_TYPES = {'skill', 'file', 'doc', 'script', 'config'}

def main():
    p = argparse.ArgumentParser()
    p.add_argument('--jsonl', required=True)
    p.add_argument('--added',    default='')
    p.add_argument('--deleted',  default='')
    p.add_argument('--modified', default='')
    args = p.parse_args()

    added    = [f for f in split_files(args.added)    if should_track(f)]
    deleted  = [f for f in split_files(args.deleted)  if should_track(f)]
    modified = [f for f in split_files(args.modified) if should_track(f)]

    if not (added or deleted or modified):
        return

    entries = load_jsonl(args.jsonl)
    dirty   = set(deleted + modified)
    kept = [e for e in entries if not (e.get('type') in NON_JAVA_TYPES and e.get('file') in dirty)]

    stats = {'deleted': len(deleted), 'added': 0, 'updated': 0}

    for filepath in added + modified:
        if not os.path.exists(filepath):
            continue
        kind, symbol, intent = classify_file(filepath)
        commit = git_hash(filepath)
        ts     = git_date(filepath)
        kept.append({
            'type': kind, 'file': filepath, 'symbol': symbol,
            'kind': kind, 'intent': intent,
            'tags': [], 'commit': commit, 'ts': ts,
        })
        if filepath in added:
            stats['added'] += 1
        else:
            stats['updated'] += 1

    with open(args.jsonl, 'w') as f:
        for entry in kept:
            f.write(json.dumps(entry, ensure_ascii=False) + '\n')

    print(f"  [files] deleted={stats['deleted']} added={stats['added']} updated={stats['updated']}")

if __name__ == '__main__':
    main()
AGENT_EOF
        chmod +x "$dir/scripts/sync-files.py"
        wrote=$((wrote + 1))
        echo -e "  ${GREEN}✓${NC} scripts/sync-files.py"
    fi

    # ── sync-to-chroma.py ────────────────────────────────────────
    if [ ! -f "$dir/scripts/sync-to-chroma.py" ]; then
        mkdir -p "$dir/scripts"
        cat > "$dir/scripts/sync-to-chroma.py" << 'AGENT_EOF'
#!/usr/bin/env python3
import json, sys, os, argparse
try:
    import chromadb
except ImportError:
    print("ERROR: chromadb not installed. Run: pip install chromadb")
    sys.exit(1)

def load_jsonl(path):
    entries = []
    if not os.path.exists(path):
        return entries
    with open(path) as f:
        for raw in f:
            raw = raw.strip()
            if raw:
                try:
                    entries.append(json.loads(raw))
                except json.JSONDecodeError:
                    pass
    return entries

def get_author_from_git():
    import subprocess
    try:
        r = subprocess.run(["git", "config", "user.name"], capture_output=True, text=True)
        author = r.stdout.strip() or "unknown"
        r = subprocess.run(["git", "config", "user.email"], capture_output=True, text=True)
        email = r.stdout.strip() or "unknown"
        return author, email
    except Exception:
        return "unknown", "unknown"

def main():
    p = argparse.ArgumentParser()
    p.add_argument("--jsonl", default=".agent/memory.jsonl")
    p.add_argument("--url", default="http://localhost:8000")
    p.add_argument("--collection", default="codebase")
    args = p.parse_args()

    author, email = get_author_from_git()
    entries = load_jsonl(args.jsonl)

    if not entries:
        print("No entries in memory.jsonl")
        sys.exit(1)

    client = chromadb.HttpClient(host=args.url.replace("http://", "").split(":")[0],
                             port=args.url.split(":")[-1] if ":" in args.url else "8000")
    collection = client.get_or_create_collection(args.collection)

    ids, documents, metadatas = [], [], []
    for e in entries:
        entry_id = f"{e.get('file', '')}:{e.get('symbol', '')}"
        intent = e.get('intent', '')
        tags = e.get('tags', [])
        kind = e.get('kind', '')
        lines = e.get('lines', [0, 0])

        combined_doc = f"{e.get('symbol', '')} ({kind}): {intent}"
        if tags:
            combined_doc += f" Tags: {', '.join(tags)}"

        ids.append(entry_id)
        documents.append(combined_doc)
        metadatas.append({
            "symbol": e.get('symbol', ''),
            "kind": kind,
            "file": e.get('file', ''),
            "lines_start": lines[0],
            "lines_end": lines[1],
            "intent": intent,
            "tags": json.dumps(tags),
            "author": author,
            "email": email,
            "commit": e.get('commit', ''),
            "ts": e.get('ts', '')
        })

    if ids:
        collection.upsert(ids=ids, documents=documents, metadatas=metadatas)

    print(f"Synced {len(ids)} entries to Chroma")
    print(f"  Author: {author}")
    print(f"  Email: {email}")

if __name__ == "__main__":
    main()
AGENT_EOF
        chmod +x "$dir/scripts/sync-to-chroma.py"
        wrote=$((wrote + 1))
        echo -e "  ${GREEN}✓${NC} scripts/sync-to-chroma.py"
    fi

    # ── query-memory.py ────────────────────────────────────────────
    if [ ! -f "$dir/scripts/query-memory.py" ]; then
        mkdir -p "$dir/scripts"
        cat > "$dir/scripts/query-memory.py" << 'AGENT_EOF'
#!/usr/bin/env python3
import json, sys, argparse, os

def search_jsonl(jsonl_path, query, kind_filter, limit):
    if not os.path.exists(jsonl_path):
        print(f"ERROR: {jsonl_path} not found. Run scan-memory first.")
        sys.exit(1)

    terms = [t.lower() for t in query.split()]
    results = []

    with open(jsonl_path) as f:
        for raw in f:
            raw = raw.strip()
            if not raw:
                continue
            try:
                e = json.loads(raw)
            except json.JSONDecodeError:
                continue

            if e.get("type") != "symbol":
                continue
            if kind_filter and e.get("kind") != kind_filter:
                continue

            haystack = " ".join([
                e.get("symbol", ""),
                e.get("kind", ""),
                e.get("intent", ""),
                e.get("file", ""),
                " ".join(e.get("tags", [])),
            ]).lower()

            score = sum(1 for t in terms if t in haystack)
            if score > 0:
                results.append((score, e))

    results.sort(key=lambda x: x[0], reverse=True)
    return results[:limit]

def print_result(m, score_label):
    lines = m.get("lines", [0, 0])
    print(f"## {m.get('symbol')} ({m.get('kind')})")
    print(f"   File: {m.get('file')}")
    print(f"   Lines: {lines[0]}-{lines[1]}")
    print(f"   Intent: {m.get('intent')}")
    print(f"   Score: {score_label}")
    print()

def main():
    p = argparse.ArgumentParser()
    p.add_argument("query", nargs="?", default="")
    p.add_argument("--url", default="http://localhost:8000")
    p.add_argument("--collection", default="codebase")
    p.add_argument("--jsonl", default=".agent/memory.jsonl")
    p.add_argument("--kind", default="")
    p.add_argument("--limit", type=int, default=10)
    p.add_argument("--json", action="store_true")
    p.add_argument("--no-chroma", action="store_true", help="Skip Chroma, query JSONL directly")
    args = p.parse_args()

    if not args.query:
        print("Usage: query-memory.py <query> [--kind controller] [--limit 5] [--no-chroma]")
        sys.exit(1)

    if not args.no_chroma:
        try:
            import chromadb
            host = args.url.replace("http://", "").replace("https://", "").split(":")[0]
            port = int(args.url.split(":")[-1]) if ":" in args.url else 8000
            client = chromadb.HttpClient(host=host, port=port)
            client.heartbeat()
            collection = client.get_collection(args.collection)

            where_clause = {"kind": args.kind} if args.kind else None
            results = collection.query(
                query_texts=[args.query],
                n_results=args.limit,
                where=where_clause,
            )

            for i in range(len(results["ids"][0])):
                m = results["metadatas"][0][i]
                dist = results["distances"][0][i] if results.get("distances") else 0
                score = max(0, 1 - dist)
                print_result(m, f"{score:.2%}")
            return

        except Exception as e:
            print(f"[query-memory] Chroma unavailable ({e}) — falling back to JSONL", file=sys.stderr)

    hits = search_jsonl(args.jsonl, args.query, args.kind, args.limit)
    if not hits:
        print("No results found.")
        return

    for score, e in hits:
        print_result(e, f"{score} keyword match(es)")

if __name__ == "__main__":
    main()
AGENT_EOF
        chmod +x "$dir/scripts/query-memory.py"
        wrote=$((wrote + 1))
        echo -e "  ${GREEN}✓${NC} scripts/query-memory.py"
    fi

    # ── bootstrap.sh ────────────────────────────────────────────────
    if [ ! -f "$dir/scripts/bootstrap.sh" ]; then
        mkdir -p "$dir/scripts"
        cat > "$dir/scripts/bootstrap.sh" << 'AGENT_EOF'
#!/usr/bin/env bash
# Full memory bootstrap: scan.sh → sync-to-chroma.py
set -uo pipefail
CHROMA_URL="${CHROMA_URL:-http://localhost:8000}"
echo "=== Memory Bootstrap ==="
echo "[1/2] Scanning..."
bash .agent/scripts/scan.sh > /dev/null 2>&1
echo "[2/2] Syncing to Chroma..."
python3 .agent/scripts/sync-to-chroma.py --url "$CHROMA_URL"
echo "=== Done ==="
AGENT_EOF
        chmod +x "$dir/scripts/bootstrap.sh"
        wrote=$((wrote + 1))
        echo -e "  ${GREEN}✓${NC} scripts/bootstrap.sh"
    fi

    # ── sync-memory.py ───────────────────────────────────────────────
    if [ ! -f "$dir/scripts/sync-memory.py" ]; then
        mkdir -p "$dir/scripts"
        cat > "$dir/scripts/sync-memory.py" << 'AGENT_EOF'
#!/usr/bin/env python3
"""
Syncs memory.jsonl after a git commit using line-level diff precision.

For each modified file:
  - Parses git diff --unified=0 to get changed hunks (new_start, new_end, delta)
  - For each symbol in memory.jsonl:
      overlap with hunk  -> code changed: find new location, update commit/ts
      below a hunk       -> line numbers shifted: apply cumulative delta silently
      above all hunks    -> untouched: no change
"""
import json, sys, os, re, subprocess, argparse
from datetime import date


# -- git helpers ---------------------------------------------------------------

def git_file_hash(path):
    r = subprocess.run(
        ["git", "log", "--follow", "-1", "--format=%h", "--", path],
        capture_output=True, text=True
    )
    return r.stdout.strip() or "unknown"


def git_file_date(path):
    r = subprocess.run(
        ["git", "log", "--follow", "-1", "--format=%ad", "--date=format:%Y-%m-%d", "--", path],
        capture_output=True, text=True
    )
    return r.stdout.strip() or str(date.today())


def parse_hunks(filepath):
    r = subprocess.run(
        ["git", "diff", "--unified=0", "HEAD~1", "HEAD", "--", filepath],
        capture_output=True, text=True
    )
    hunks = []
    for line in r.stdout.splitlines():
        m = re.match(r'^@@ -(\d+)(?:,(\d+))? \+(\d+)(?:,(\d+))? @@', line)
        if not m:
            continue
        old_count = int(m.group(2)) if m.group(2) is not None else 1
        new_start = int(m.group(3))
        new_count = int(m.group(4)) if m.group(4) is not None else 1
        delta     = new_count - old_count
        new_end   = new_start + max(new_count - 1, 0)
        hunks.append({"start": new_start, "end": new_end, "delta": delta})
    return hunks


# -- line arithmetic -----------------------------------------------------------

def classify_symbol(sym_start, sym_end, hunks):
    for hunk in hunks:
        if sym_start <= hunk["end"] and sym_end >= hunk["start"]:
            return sym_start, sym_end, True
    delta = sum(h["delta"] for h in hunks if h["start"] < sym_start)
    return sym_start + delta, sym_end + delta, False


def find_symbol_line(filepath, symbol_name):
    if not os.path.exists(filepath):
        return None
    pattern = re.compile(
        r'(?:public\s+)?(?:class|interface|enum|record)\s+' + re.escape(symbol_name) + r'\b'
        r'|(?:public\s+[\w<>\[\]]+\s+)' + re.escape(symbol_name) + r'\s*\('
    )
    with open(filepath) as f:
        for i, line in enumerate(f, 1):
            if pattern.search(line):
                return i
    return None


# -- new-file scanner ----------------------------------------------------------

def scan_classes(path):
    if not os.path.exists(path):
        return []
    with open(path) as f:
        lines = f.readlines()
    total = len(lines)
    results = []
    for i, line in enumerate(lines):
        m = re.match(r'\s*public (?:class|interface|enum|record) (\w+)', line)
        if not m:
            continue
        name = m.group(1)
        anns = [lines[j].strip() for j in range(max(0, i - 3), i) if lines[j].strip().startswith("@")]
        ann  = " ".join(anns)
        if   "@RestController" in ann:                   kind = "controller"
        elif "@Service" in ann:                          kind = "service"
        elif "@Repository" in ann:                       kind = "repository"
        elif "@Configuration" in ann or "@ConfigurationProperties" in ann: kind = "config"
        elif "/dto/" in path:                            kind = "dto"
        elif "/domain/" in path:                         kind = "domain"
        else:                                            kind = "class"
        results.append({"name": name, "kind": kind, "line_start": i + 1, "line_end": total})
    return results


# -- helpers -------------------------------------------------------------------

def split_files(raw):
    return [f.strip() for f in (raw or "").split("\n") if f.strip()]


def load_jsonl(path):
    entries = []
    if not os.path.exists(path):
        return entries
    with open(path) as f:
        for raw in f:
            raw = raw.strip()
            if raw:
                try:
                    entries.append(json.loads(raw))
                except json.JSONDecodeError:
                    pass
    return entries


# -- main ----------------------------------------------------------------------

def main():
    p = argparse.ArgumentParser()
    p.add_argument("--jsonl",     required=True)
    p.add_argument("--added",     default="")
    p.add_argument("--deleted",   default="")
    p.add_argument("--modified",  default="")
    args = p.parse_args()

    added    = split_files(args.added)
    deleted  = split_files(args.deleted)
    modified = split_files(args.modified)
    dirty    = set(deleted + modified)

    entries = load_jsonl(args.jsonl)
    kept      = [e for e in entries if e.get("file") not in dirty]
    to_update = [e for e in entries if e.get("file") in dirty]

    stats = {"deleted": 0, "shifted": 0, "touched": 0, "added": 0, "pending": 0}

    stats["deleted"] = sum(1 for e in to_update if e.get("file") in set(deleted))

    for filepath in modified:
        file_entries = [e for e in to_update if e.get("file") == filepath and e.get("type") == "symbol"]
        if not file_entries:
            continue

        commit = git_file_hash(filepath)
        ts     = git_file_date(filepath)
        hunks  = parse_hunks(filepath)

        if not hunks:
            for e in file_entries:
                e["commit"] = commit
                e["ts"]     = ts
                kept.append(e)
            continue

        for entry in file_entries:
            s, e_end = entry["lines"][0], entry["lines"][1]
            new_s, new_e, touched = classify_symbol(s, e_end, hunks)

            if not touched:
                entry["lines"]  = [new_s, new_e]
                entry["commit"] = commit
                entry["ts"]     = ts
                kept.append(entry)
                stats["shifted"] += 1
            else:
                new_line = find_symbol_line(filepath, entry["symbol"])
                if new_line:
                    total = sum(1 for _ in open(filepath))
                    entry["lines"]  = [new_line, min(new_line + (e_end - s), total)]
                    entry["commit"] = commit
                    entry["ts"]     = ts
                else:
                    entry["intent"] = "PENDING_INTENT -- symbol may have been renamed or deleted"
                    entry["commit"] = commit
                    entry["ts"]     = ts
                    stats["pending"] += 1
                kept.append(entry)
                stats["touched"] += 1

    for filepath in added:
        if not os.path.exists(filepath):
            continue
        commit = git_file_hash(filepath)
        ts     = git_file_date(filepath)
        for sym in scan_classes(filepath):
            kept.append({
                "type": "symbol", "file": filepath,
                "symbol": sym["name"], "kind": sym["kind"],
                "lines": [sym["line_start"], sym["line_end"]],
                "intent": "PENDING_INTENT -- run /scan-memory to generate",
                "tags": [], "commit": commit, "ts": ts
            })
            stats["added"]   += 1
            stats["pending"] += 1

    with open(args.jsonl, "w") as f:
        for entry in kept:
            f.write(json.dumps(entry, ensure_ascii=False) + "\n")

    print(f"  deleted={stats['deleted']} shifted={stats['shifted']} "
          f"touched={stats['touched']} added={stats['added']} pending={stats['pending']}")
    if stats["pending"]:
        print("  hint: run /scan-memory to fill PENDING_INTENT entries")


if __name__ == "__main__":
    main()
AGENT_EOF
        chmod +x "$dir/scripts/sync-memory.py"
        wrote=$((wrote + 1))
        echo -e "  ${GREEN}✓${NC} scripts/sync-memory.py"
    fi

    # ── chroma docker-compose ────────────────────────────────────────
    if [ ! -f "$dir/chroma/docker-compose.yml" ]; then
        mkdir -p "$dir/chroma"
        cat > "$dir/chroma/docker-compose.yml" << 'AGENT_EOF'
version: "3.8"
services:
  chroma:
    image: chromadb/chroma:1.5.3
    container_name: chroma
    restart: unless-stopped
    ports:
      - "8000:8000"
    environment:
      ANONYMIZED_TELEMETRY: "FALSE"
      IS_PERSISTENT: "TRUE"
    volumes:
      - chroma_data:/chroma/chroma
volumes:
  chroma_data:
    driver: local
AGENT_EOF
        wrote=$((wrote + 1))
        echo -e "  ${GREEN}✓${NC} chroma/docker-compose.yml"
    fi

    # ── empty memory.jsonl seed ──────────────────────────────────────
    if [ ! -f "$dir/memory.jsonl" ]; then
        touch "$dir/memory.jsonl"
        wrote=$((wrote + 1))
        echo -e "  ${GREEN}✓${NC} memory.jsonl (empty seed)"
    fi

    if [ $wrote -eq 0 ]; then
        echo -e "  ${CYAN}–${NC} .agent/ infrastructure already exists"
    else
        echo -e "  ${GREEN}Wrote $wrote .agent file(s)${NC}"
    fi
    echo ""
}

# =============================================================================
# PARSE ARGUMENTS
# =============================================================================

while [[ $# -gt 0 ]]; do
    case $1 in
        --all)    SETUP_CLAUDE=true; SETUP_KIRO=true; shift ;;
        --claude) SETUP_CLAUDE=true; shift ;;
        --kiro)   SETUP_KIRO=true;   shift ;;
        --help|-h) show_help; exit 0 ;;
        *) echo -e "${RED}Unknown option: $1${NC}"; echo "Run $0 --help for usage."; exit 1 ;;
    esac
done

# =============================================================================
# MAIN
# =============================================================================

echo -e "${BLUE}Agent Skill Development — Setup${NC}"
echo "================================="
echo ""

# ── Step 1: Select targets ───────────────────────────────────────────────────
if [ "$SETUP_CLAUDE" = false ] && [ "$SETUP_KIRO" = false ]; then
    show_menu
    echo ""
fi

if [ "$SETUP_CLAUDE" = false ] && [ "$SETUP_KIRO" = false ]; then
    echo -e "${YELLOW}No target selected. Nothing to do.${NC}"
    exit 0
fi

SKILL_COUNT=$(find "$SKILLS_DIR" -mindepth 2 -maxdepth 2 -name "SKILL.md" | wc -l | tr -d ' ')
echo -e "  Skills found in skills/: ${BOLD}$SKILL_COUNT${NC}"
echo ""

# ── Step 2: Create context files + symlinks ──────────────────────────────────
if [ "$SETUP_CLAUDE" = true ]; then
    echo -e "${CYAN}── Claude Code ─────────────────────────────────────────────────────${NC}"
    if [ ! -f "$CLAUDE_MD" ]; then
        create_claude_md "$CLAUDE_MD"
        echo -e "  ${GREEN}✓${NC} Created CLAUDE.md"
    else
        echo -e "  ${CYAN}–${NC} CLAUDE.md already exists"
    fi
    ensure_symlink "$REPO_ROOT/.claude/skills" "../skills"
    echo ""
fi

if [ "$SETUP_KIRO" = true ]; then
    echo -e "${CYAN}── Kiro ────────────────────────────────────────────────────────────${NC}"
    if [ ! -f "$KIRO_RULES" ]; then
        create_kiro_rules "$KIRO_RULES"
        echo -e "  ${GREEN}✓${NC} Created .kiro/steering/project-rules.md"
    else
        echo -e "  ${CYAN}–${NC} .kiro/steering/project-rules.md already exists"
    fi
    ensure_symlink "$REPO_ROOT/.kiro/skills" "../skills"
    echo ""
fi

# ── Step 3: Bundle generic skills ─────────────────────────────────────────
bundle_skills "$SKILLS_DIR"

# ── Step 4: Bundle .agent/ memory infrastructure ─────────────────────────────
bundle_agent_dir "$REPO_ROOT"

# ── Step 5: Sync skills tables into context files ────────────────────────────
if [ -f "$SYNC_SH" ]; then
    bash "$SYNC_SH"
else
    echo -e "${YELLOW}skill-sync not found at $SYNC_SH — skipping table sync${NC}"
    echo "  Run: bash skills/skill-sync/assets/sync.sh"
fi

# ── Step 6: Install git hooks ────────────────────────────────────────────────
echo -e "${CYAN}── Installing Git Hooks ────────────────────────────────────────────${NC}"

# Install post-commit hook from skills/commit/assets/
HOOK_SRC="skills/commit/assets/post-commit.sh"
HOOK_DST=".git/hooks/post-commit"

if [ -f "$HOOK_SRC" ]; then
    if [ -f "$HOOK_DST" ] && [ ! -L "$HOOK_DST" ]; then
        echo "BACKUP existing $HOOK_DST → $HOOK_DST.bak"
        mv "$HOOK_DST" "$HOOK_DST.bak"
    fi
    ln -sf "../../$HOOK_SRC" "$HOOK_DST"
    chmod +x "$HOOK_SRC"
    echo "OK   $HOOK_DST → $HOOK_SRC"
else
    echo -e "${YELLOW}Hook not found at $HOOK_SRC — skipping${NC}"
fi
