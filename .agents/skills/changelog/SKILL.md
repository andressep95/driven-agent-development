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
