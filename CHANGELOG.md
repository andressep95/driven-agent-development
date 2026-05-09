# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/).

## [Unreleased]

### [3f9abe4] — 2026-05-09

**refactor(cli): modularize setup-agent into setup/ package**

> what: Splits SetupAgentCommand into 5 focused classes — Checklist,
> ScaffoldInstaller, SkillRegistry, RulesPatcher, SkillMeta —
> and fixes resource leaks, raw-mode CR/LF drift, stale skills
> on re-run, and rules.md table sync; adds Java 17 to pom.xml

#### Added

- `src/main/java/com/cloudcentinel/setup/Checklist.java`
- `src/main/java/com/cloudcentinel/setup/RulesPatcher.java`
- `src/main/java/com/cloudcentinel/setup/ScaffoldInstaller.java`
- `src/main/java/com/cloudcentinel/setup/SkillMeta.java`
- `src/main/java/com/cloudcentinel/setup/SkillRegistry.java`

#### Changed

- `pom.xml`
- `src/main/java/com/cloudcentinel/commands/SetupAgentCommand.java`

---

### [02c4d26] — 2026-05-08

**feat(cli): add interactive skill selection menu to setup-agent**

> what: Adds a two-step interactive checklist — first AI tools, then skills —
> so users control exactly which skills get installed locally; skills are
> discovered dynamically from the jar at runtime
> why:  Installing all skills unconditionally saturates the AI context window;

#### Changed

- `src/main/java/com/cloudcentinel/commands/SetupAgentCommand.java`

---

### [6513f86] — 2026-05-06

**feat(skills): add vercel-react-best-practices skill**

> what: add vercel-react-best-practices skill to .agents/skills and scaffold
> why: enable React/Next.js performance optimization guidelines in future projects
> breaking: none

#### Added

- `.agents/skills/vercel-react-best-practices/AGENTS.md`
- `.agents/skills/vercel-react-best-practices/README.md`
- `.agents/skills/vercel-react-best-practices/SKILL.md`
- `.agents/skills/vercel-react-best-practices/metadata.json`
- `.agents/skills/vercel-react-best-practices/rules/_sections.md`
- `.agents/skills/vercel-react-best-practices/rules/_template.md`
- `.agents/skills/vercel-react-best-practices/rules/advanced-effect-event-deps.md`
- `.agents/skills/vercel-react-best-practices/rules/advanced-event-handler-refs.md`
- `.agents/skills/vercel-react-best-practices/rules/advanced-init-once.md`
- `.agents/skills/vercel-react-best-practices/rules/advanced-use-latest.md`
- `.agents/skills/vercel-react-best-practices/rules/async-api-routes.md`
- `.agents/skills/vercel-react-best-practices/rules/async-cheap-condition-before-await.md`
- `.agents/skills/vercel-react-best-practices/rules/async-defer-await.md`
- `.agents/skills/vercel-react-best-practices/rules/async-dependencies.md`
- `.agents/skills/vercel-react-best-practices/rules/async-parallel.md`
- `.agents/skills/vercel-react-best-practices/rules/async-suspense-boundaries.md`
- `.agents/skills/vercel-react-best-practices/rules/bundle-analyzable-paths.md`
- `.agents/skills/vercel-react-best-practices/rules/bundle-barrel-imports.md`
- `.agents/skills/vercel-react-best-practices/rules/bundle-conditional.md`
- `.agents/skills/vercel-react-best-practices/rules/bundle-defer-third-party.md`
- _…and 132 more_

#### Changed

- `.agents/rules.md`
- `src/main/resources/scaffold/rules.md`

---

### [9e9340f] — 2026-05-02

**feat(skills): add Vue 3 and Vue PrimeVue skills**

> what: Adds SKILL.md definitions for Vue 3 core patterns and Vue 3 with
> PrimeVue UI components
> why:  Enables skill-driven agent support for Vue frontend development tasks
> breaking: false

#### Added

- `.agents/skills/vue-primevue/SKILL.md`
- `.agents/skills/vue-primevue/references/CHEATSHEET.md`
- `.agents/skills/vue-primevue/references/COMPONENTS.md`
- `.agents/skills/vue-primevue/references/THEMING.md`
- `.agents/skills/vue/SKILL.md`
- `.agents/skills/vue/references/CHEATSHEET.md`
- `.agents/skills/vue/references/PINIA.md`
- `.agents/skills/vue/references/REACTIVITY.md`
- `.agents/skills/vue/references/ROUTER.md`
- `src/main/resources/scaffold/skills/vue-primevue/SKILL.md`
- `src/main/resources/scaffold/skills/vue-primevue/references/CHEATSHEET.md`
- `src/main/resources/scaffold/skills/vue-primevue/references/COMPONENTS.md`
- `src/main/resources/scaffold/skills/vue-primevue/references/THEMING.md`
- `src/main/resources/scaffold/skills/vue/SKILL.md`
- `src/main/resources/scaffold/skills/vue/references/CHEATSHEET.md`
- `src/main/resources/scaffold/skills/vue/references/PINIA.md`
- `src/main/resources/scaffold/skills/vue/references/REACTIVITY.md`
- `src/main/resources/scaffold/skills/vue/references/ROUTER.md`

---

### [4d00152] — 2026-05-02

**perf(agent): consolidate Chroma queries into single Python process**

> what: Replaces two separate Python invocations (skill + memory) with one
> unified query-all.py script that loads the embedding model once
> why:  Eliminates duplicate model loading on every prompt submit, cutting
> hook latency roughly in half

#### Added

- `.agents/scripts/query-all.py`
- `src/main/resources/scaffold/scripts/query-all.py`

#### Changed

- `.agents/scripts/user-prompt-submit.sh`
- `src/main/resources/scaffold/scripts/user-prompt-submit.sh`

---

### [61852dd] — 2026-05-02

**fix(memory): use local timezone for JSONL timestamps**

> what: Replaces UTC timestamps with local-timezone-aware ones using
> datetime.now().astimezone().isoformat() in token-tracker.py
> and query-memory.py
> why:  UTC offsets made timestamps unreadable when inspecting logs

#### Changed

- `.agents/scripts/query-memory.py`
- `.agents/scripts/token-tracker.py`
- `src/main/resources/scaffold/scripts/query-memory.py`
- `src/main/resources/scaffold/scripts/token-tracker.py`

---

### [6837c3f] — 2026-05-02

**feat(skills): add jpa-query-optimizer skill and refactor skill-creator**

> what: Adds a full JPA/Hibernate query optimization skill with 6 reference
> docs covering N+1, fetch strategies, projections, entity graphs,
> pagination, and caching; refactors skill-creator to follow the same
> English-only, table-and-decision-tree convention

#### Added

- `.agents/skills/jpa-query-optimizer/SKILL.md`
- `.agents/skills/jpa-query-optimizer/references/CACHING.md`
- `.agents/skills/jpa-query-optimizer/references/CHEATSHEET.md`
- `.agents/skills/jpa-query-optimizer/references/ENTITY-GRAPHS.md`
- `.agents/skills/jpa-query-optimizer/references/FETCH-STRATEGIES.md`
- `.agents/skills/jpa-query-optimizer/references/N+1-PROBLEM.md`
- `.agents/skills/jpa-query-optimizer/references/PAGINATION.md`
- `.agents/skills/jpa-query-optimizer/references/PROJECTIONS.md`
- `src/main/resources/scaffold/skills/jpa-query-optimizer/SKILL.md`
- `src/main/resources/scaffold/skills/jpa-query-optimizer/references/CACHING.md`
- `src/main/resources/scaffold/skills/jpa-query-optimizer/references/CHEATSHEET.md`
- `src/main/resources/scaffold/skills/jpa-query-optimizer/references/ENTITY-GRAPHS.md`
- `src/main/resources/scaffold/skills/jpa-query-optimizer/references/FETCH-STRATEGIES.md`
- `src/main/resources/scaffold/skills/jpa-query-optimizer/references/N+1-PROBLEM.md`
- `src/main/resources/scaffold/skills/jpa-query-optimizer/references/PAGINATION.md`
- `src/main/resources/scaffold/skills/jpa-query-optimizer/references/PROJECTIONS.md`

#### Changed

- `.agents/skills/skill-creator/SKILL.md`
- `.kiro/steering/project-rules.md`
- `CLAUDE.md`
- `src/main/resources/scaffold/skills/skill-creator/SKILL.md`

---

### [ca89b9a] — 2026-05-02

**feat(agent): add token consumption tracking and query relevance filtering**

> what: Adds Claude Code token tracker (Stop hook), query relevance threshold with audit logging, and token-report.py for system health analysis
> why: Needed visibility into whether the skill-driven protocol reduces context waste and whether Chroma injections are relevant
> breaking: false

#### Added

- `.agents/scripts/token-report.py`
- `.agents/scripts/token-tracker.py`
- `src/main/resources/scaffold/scripts/token-report.py`
- `src/main/resources/scaffold/scripts/token-tracker.py`

#### Changed

- `.agents/scripts/query-memory.py`
- `.claude/settings.json`
- `.gitignore`
- `src/main/resources/scaffold/.claude/settings.json`
- `src/main/resources/scaffold/scripts/query-memory.py`

---

### [b1fa501] — 2026-04-30

**refactor(agent): remove JSONL support from changelog and drop sync-to-chroma scaffold**

> what: Strips --from-jsonl flag from generate-changelog.py and deletes the
> scaffold sync-to-chroma.py that synced memory.jsonl to Chroma
> why: The JSONL layer was replaced by direct Chroma writes in a prior refactor;
> these files were dead code

#### Changed

- `.agents/scripts/generate-changelog.py`
- `src/main/resources/scaffold/scripts/generate-changelog.py`

#### Removed

- `src/main/resources/scaffold/scripts/sync-to-chroma.py`

---

### [20aefe3] — 2026-04-30

**feat(agent): switch to multilingual-e5-small embedding model**

> what: Replaces DefaultEmbeddingFunction with SentenceTransformerEmbeddingFunction
> (intfloat/multilingual-e5-small) across all Chroma scripts, and refactors
> scan-history.sh to load the model once for the full history replay
> why: Better cross-language semantic embeddings improve code search quality,

#### Changed

- `.agents/scripts/extract_changes.py`
- `.agents/scripts/query-memory.py`
- `.agents/scripts/requirements.txt`
- `.agents/scripts/scan-history.sh`
- `.agents/scripts/sync-skills-to-chroma.py`
- `.agents/scripts/sync-to-chroma.py`
- `.agents/scripts/user-prompt-submit.sh`
- `src/main/resources/scaffold/scripts/extract_changes.py`
- `src/main/resources/scaffold/scripts/query-memory.py`
- `src/main/resources/scaffold/scripts/requirements.txt`
- `src/main/resources/scaffold/scripts/scan-history.sh`
- `src/main/resources/scaffold/scripts/sync-skills-to-chroma.py`
- `src/main/resources/scaffold/scripts/sync-to-chroma.py`
- `src/main/resources/scaffold/scripts/user-prompt-submit.sh`

---

### [95de1c3] — 2026-04-30

**refactor(agent): write hunks directly to Chroma, drop JSONL layer**

> what: extract_changes.py, scan-history.sh, and post-commit now index
> hunks straight into ChromaDB in a single pass; init.sh exits on
> missing deps instead of soft-falling back to JSONL-only mode;
> sync.sh gains a Chroma skill re-index step

#### Changed

- `.agents/scripts/extract_changes.py`
- `.agents/scripts/init.sh`
- `.agents/scripts/post-commit`
- `.agents/scripts/scan-history.sh`
- `.agents/scripts/sync.sh`
- `.agents/skills/commit/SKILL.md`
- `.agents/skills/query-memory/SKILL.md`
- `.agents/skills/scan-memory/SKILL.md`
- `.agents/skills/skill-sync/SKILL.md`
- `.kiro/steering/project-rules.md`
- `CLAUDE.md`
- `src/main/resources/scaffold/scripts/extract_changes.py`
- `src/main/resources/scaffold/scripts/init.sh`
- `src/main/resources/scaffold/scripts/post-commit`
- `src/main/resources/scaffold/scripts/scan-history.sh`
- `src/main/resources/scaffold/scripts/sync.sh`
- `src/main/resources/scaffold/skills/commit/SKILL.md`
- `src/main/resources/scaffold/skills/query-memory/SKILL.md`
- `src/main/resources/scaffold/skills/scan-memory/SKILL.md`
- `src/main/resources/scaffold/skills/skill-sync/SKILL.md`

---

### [7903560] — 2026-04-30

**refactor(agent): replace keyword scoring with Chroma semantic skill search**

> what: user-prompt-submit.sh queries the 'skills' Chroma collection; sync-skills-to-chroma.py indexes all SKILL.md files; init.sh adds a [3/3] skills-indexing step
> why: Keyword overlap produced false matches on complex prompts — semantic embeddings route to the correct skill regardless of vocabulary mismatch
> breaking: false

#### Added

- `.agents/scripts/sync-skills-to-chroma.py`
- `src/main/resources/scaffold/scripts/sync-skills-to-chroma.py`

#### Changed

- `.agents/scripts/init.sh`
- `.agents/scripts/user-prompt-submit.sh`
- `src/main/resources/scaffold/scripts/init.sh`
- `src/main/resources/scaffold/scripts/user-prompt-submit.sh`

---

### [9f8b05c] — 2026-04-30

**feat(agent): add session-start and validate-commit hooks**

> what: SessionStart detects project stack and injects it as context; PreToolUse blocks git commit when what:/why:/breaking: fields are missing
> why: Eliminates manual stack context at session open and enforces RAG-critical commit fields at the git layer before they can be lost
> breaking: false

#### Added

- `.agents/scripts/session-start.sh`
- `.agents/scripts/validate-commit.sh`
- `.kiro/hooks/session-start.yaml`
- `.kiro/hooks/validate-commit.yaml`
- `src/main/resources/scaffold/.kiro/hooks/session-start.yaml`
- `src/main/resources/scaffold/.kiro/hooks/validate-commit.yaml`
- `src/main/resources/scaffold/scripts/session-start.sh`
- `src/main/resources/scaffold/scripts/validate-commit.sh`

#### Changed

- `.claude/settings.json`
- `src/main/java/com/cloudcentinel/commands/SetupAgentCommand.java`
- `src/main/resources/scaffold/.claude/settings.json`

---

### [c3bcb17] — 2026-04-30

**feat(agent): add UserPromptSubmit hook for per-task context injection**

> what: Injects matching skill name and Chroma memory results as
> additionalContext before each user prompt is processed.
> why:  Agents previously started every task cold; this hook surfaces
> the relevant skill and prior change history automatically.

#### Added

- `.agents/scripts/user-prompt-submit.sh`
- `.kiro/hooks/user-prompt-submit.yaml`
- `src/main/resources/scaffold/.kiro/hooks/user-prompt-submit.yaml`
- `src/main/resources/scaffold/scripts/user-prompt-submit.sh`

#### Changed

- `.agents/scripts/query-memory.py`
- `.agents/skills/query-memory/SKILL.md`
- `.claude/settings.json`
- `src/main/java/com/cloudcentinel/commands/SetupAgentCommand.java`
- `src/main/resources/scaffold/.claude/settings.json`
- `src/main/resources/scaffold/scripts/query-memory.py`
- `src/main/resources/scaffold/skills/query-memory/SKILL.md`

---

### [26c3784] — 2026-04-29

**refactor(agent): rename bootstrap.sh to init.sh and remove Python from Docker**

> what: Renames bootstrap.sh to init.sh across all scripts, skills, scaffold,
> and docs; setup-agent now prints the init command instead of running it;
> removes python3, pip, and chromadb from the Docker image.
> why:  bootstrap.sh name was generic and confusing; auto-running memory init

#### Added

- `.agents/scripts/init.sh`
- `src/main/resources/scaffold/scripts/init.sh`

#### Changed

- `.agents/skills/query-memory/SKILL.md`
- `.agents/skills/scan-memory/SKILL.md`
- `Dockerfile`
- `README.md`
- `src/main/java/com/cloudcentinel/commands/SetupAgentCommand.java`
- `src/main/resources/scaffold/skills/query-memory/SKILL.md`
- `src/main/resources/scaffold/skills/scan-memory/SKILL.md`

#### Removed

- `.agents/scripts/bootstrap.sh`
- `src/main/resources/scaffold/scripts/bootstrap.sh`

---

### [fcd1b00] — 2026-04-29

**Merge pull request #3 from andressep95/restructure/cli-java**

> Restructure/cli java

_No file changes detected._

---

### [d5efd04] — 2026-04-29

**fix(docker): add python3 and chromadb to container image**

> what: Installs python3, pip, and chromadb in the runtime image so
> bootstrap.sh can fully populate both memory.jsonl and Chroma
> during setup-agent without manual intervention
> why:  The container lacked python3, causing sync-to-chroma.py to fail

#### Changed

- `.agents/memory/memory.jsonl`
- `.agents/scripts/bootstrap.sh`
- `Dockerfile`
- `src/main/resources/scaffold/scripts/bootstrap.sh`

---

### [d32bddb] — 2026-04-29

**Merge pull request #2 from andressep95/restructure/cli-java**

> Restructure/cli java

_No file changes detected._

---

### [e6d3063] — 2026-04-29

**refactor(memory): migrate Chroma to local PersistentClient and auto-sync on commit**

> what: Removes Docker-based Chroma setup and replaces it with a local
> PersistentClient; post-commit hook now syncs memory.jsonl to
> Chroma on every commit; setup-agent runs bootstrap automatically
> why:  Eliminates Docker as a runtime dependency for the memory system,

#### Added

- `chroma-local-setup.md`

#### Changed

- `.agents/memory/memory.jsonl`
- `.agents/rules.md`
- `.agents/scripts/post-commit`
- `README.md`
- `src/main/java/com/cloudcentinel/commands/SetupAgentCommand.java`
- `src/main/resources/scaffold/manifest.json`
- `src/main/resources/scaffold/scripts/post-commit`

#### Removed

- `docker-compose.yml`
- `setup.sh`
- `src/main/resources/scaffold/agents-compose.yml`

---

### [601cc3c] — 2026-04-28

**Merge pull request #1 from andressep95/restructure/cli-java**

> Restructure/cli java

_No file changes detected._

---

### [36319eb] — 2026-04-28

**feat(cli): add ChromaDB compose file to scaffold**

> what: Adds agents-compose.yml to scaffold and updates setup-agent to extract it to client machines
> why: Enables clients to run local ChromaDB instance for vector search memory queries
> breaking: false

#### Added

- `src/main/resources/scaffold/agents-compose.yml`

#### Changed

- `.agents/memory/memory.jsonl`
- `README.md`
- `src/main/java/com/cloudcentinel/commands/SetupAgentCommand.java`

---

### [64f7ee6] — 2026-04-28

**fix(docker): install git in runtime image**

> what: Adds git to the JRE runtime stage so the CLI can detect existing repositories in mounted volumes
> why: Without git the container could not run git rev-parse, causing setup-agent to falsely report no repo found
> breaking: false

#### Changed

- `Dockerfile`

---

### [84b9827] — 2026-04-28

**fix(cli): handle non-interactive TTY and add multi-platform Docker build**

> what: SetupAgentCommand detects missing TTY and defaults to auto-init + all tools; CI now builds linux/amd64 and linux/arm64 images
> why: Running via docker run without -it caused a NoSuchElementException crash, and ARM Macs received an amd64 image requiring emulation
> breaking: false

#### Changed

- `.agents/memory/memory.jsonl`
- `.github/workflows/docker.yml`
- `README.md`
- `src/main/java/com/cloudcentinel/commands/SetupAgentCommand.java`

---

### [05b9e1e] — 2026-04-28

**refactor(scripts): consolidate memory pipeline and remove deprecated utilities**

> what: Removes redundant scripts (sync-hunks, sync-memory, migrate_to_chroma, scan.sh, rebuild-chroma) and consolidates memory sync into a single extract→sync-to-chroma pipeline
> why: Multiple overlapping scripts caused confusion and maintenance burden; the new pipeline is simpler and matches the post-commit hook flow
> breaking: false

#### Changed

- `.agents/rules.md`
- `.agents/scripts/bootstrap.sh`
- `.agents/scripts/extract_changes.py`
- `.agents/scripts/generate-changelog.py`
- `.agents/scripts/post-commit`
- `.agents/scripts/query-memory.py`
- `.agents/scripts/scan-history.sh`
- `.agents/scripts/sync-to-chroma.py`
- `.agents/scripts/sync.sh`
- `.agents/skills/query-memory/SKILL.md`
- `.agents/skills/scan-memory/SKILL.md`
- `.agents/skills/skill-creator/SKILL.md`
- `.agents/skills/skill-sync/SKILL.md`
- `src/main/resources/scaffold/rules.md`
- `src/main/resources/scaffold/scripts/bootstrap.sh`
- `src/main/resources/scaffold/scripts/extract_changes.py`
- `src/main/resources/scaffold/scripts/generate-changelog.py`
- `src/main/resources/scaffold/scripts/post-commit`
- `src/main/resources/scaffold/scripts/query-memory.py`
- `src/main/resources/scaffold/scripts/scan-history.sh`
- _…and 6 more_

#### Removed

- `.agents/scripts/migrate_to_chroma.py`
- `.agents/scripts/rebuild-chroma.sh`
- `.agents/scripts/scan.sh`
- `.agents/scripts/sync-hunks.py`
- `.agents/scripts/sync-memory.py`
- `.agents/skills/changelog/SKILL.md`
- `.agents/skills/commit/assets/post-commit.sh`
- `.agents/skills/skill-sync/assets/sync.sh`
- `src/main/resources/scaffold/scripts/migrate_to_chroma.py`
- `src/main/resources/scaffold/scripts/rebuild-chroma.sh`
- `src/main/resources/scaffold/scripts/scan.sh`
- `src/main/resources/scaffold/scripts/sync-hunks.py`
- `src/main/resources/scaffold/scripts/sync-memory.py`
- `src/main/resources/scaffold/skills/changelog/SKILL.md`
- `src/main/resources/scaffold/skills/commit/assets/post-commit.sh`
- `src/main/resources/scaffold/skills/skill-sync/assets/sync.sh`

---

### [b5ab996] — 2026-04-28

**feat(cli): add interactive tool-selector TUI to setup-agent**

> what: SetupAgentCommand now shows a jline checklist so users pick
> which AI tools to scaffold, and auto-detects or initializes
> git before running; InitRepoCommand is absorbed and removed.
> why:  The command installed all tool configs unconditionally; scoping

#### Changed

- `.vscode/settings.json`
- `pom.xml`
- `src/main/java/com/cloudcentinel/App.java`
- `src/main/java/com/cloudcentinel/commands/SetupAgentCommand.java`

#### Removed

- `.agents/memory/memory.jsonl`
- `src/main/java/com/cloudcentinel/commands/InitRepoCommand.java`

---

### [fdc0a94] — 2026-04-28

**fix(agent): correct .agent/ paths to .agents/memory/ in all scripts**

> what: Updates hardcoded .agent/memory.jsonl references to
> .agents/memory/memory.jsonl across scripts and adds the full
> script set to src/main/resources/scaffold/scripts/ so setup-agent
> deploys them correctly on every new repo.

#### Added

- `.agents/memory/memory.jsonl`
- `src/main/resources/scaffold/scripts/bootstrap.sh`
- `src/main/resources/scaffold/scripts/generate-changelog.py`
- `src/main/resources/scaffold/scripts/post-commit.sh`
- `src/main/resources/scaffold/scripts/query-memory.py`
- `src/main/resources/scaffold/scripts/rebuild-chroma.sh`
- `src/main/resources/scaffold/scripts/scan-history.sh`
- `src/main/resources/scaffold/scripts/scan.sh`
- `src/main/resources/scaffold/scripts/sync-hunks.py`
- `src/main/resources/scaffold/scripts/sync-memory.py`
- `src/main/resources/scaffold/scripts/sync-to-chroma.py`
- `src/main/resources/scaffold/scripts/sync.sh`
- `target/classes/scaffold/scripts/bootstrap.sh`
- `target/classes/scaffold/scripts/generate-changelog.py`
- `target/classes/scaffold/scripts/post-commit.sh`
- `target/classes/scaffold/scripts/query-memory.py`
- `target/classes/scaffold/scripts/rebuild-chroma.sh`
- `target/classes/scaffold/scripts/scan-history.sh`
- `target/classes/scaffold/scripts/scan.sh`
- `target/classes/scaffold/scripts/sync-hunks.py`
- _…and 3 more_

#### Changed

- `.agents/scripts/query-memory.py`
- `.agents/scripts/rebuild-chroma.sh`
- `.agents/scripts/scan-history.sh`
- `.agents/scripts/sync-to-chroma.py`
- `target/agent.jar`
- `target/original-agent.jar`

---

### [440f449] — 2026-04-28

**feat(cli): add setup-agent command and migrate scaffold to .agents/**

> what: Adds setup-agent subcommand that extracts the full agent scaffold
> (.agents/, skills, scripts, hooks, symlinks) from embedded JAR
> resources, replacing the manually maintained .agent/ directory.
> why: Automates project bootstrap so any user can run setup-agent once

#### Added

- `.agents/rules.md`
- `.agents/scripts/bootstrap.sh`
- `.agents/scripts/extract_changes.py`
- `.agents/scripts/generate-changelog.py`
- `.agents/scripts/migrate_to_chroma.py`
- `.agents/scripts/post-commit`
- `.agents/scripts/post-commit.sh`
- `.agents/scripts/query-memory.py`
- `.agents/scripts/rebuild-chroma.sh`
- `.agents/scripts/scan-history.sh`
- `.agents/scripts/scan.sh`
- `.agents/scripts/sync-hunks.py`
- `.agents/scripts/sync-memory.py`
- `.agents/scripts/sync-to-chroma.py`
- `.agents/scripts/sync.sh`
- `.agents/skills/changelog/SKILL.md`
- `.agents/skills/clean-ddd-hexagonal/SKILL.md`
- `.agents/skills/clean-ddd-hexagonal/references/CHEATSHEET.md`
- `.agents/skills/clean-ddd-hexagonal/references/CQRS-EVENTS.md`
- `.agents/skills/clean-ddd-hexagonal/references/DDD-STRATEGIC.md`
- _…and 79 more_

#### Changed

- `.claude/skills`
- `.kiro/skills`
- `.kiro/steering/project-rules.md`
- `CLAUDE.md`
- `src/main/java/com/cloudcentinel/App.java`
- `target/agent.jar`
- `target/classes/com/cloudcentinel/App.class`
- `target/maven-status/maven-compiler-plugin/compile/default-compile/createdFiles.lst`
- `target/maven-status/maven-compiler-plugin/compile/default-compile/inputFiles.lst`
- `target/original-agent.jar`

#### Removed

- `.agent/chroma/docker-compose.yml`
- `.agent/memory.jsonl`
- `.agent/scripts/bootstrap.sh`
- `.agent/scripts/generate-changelog.py`
- `.agent/scripts/query-memory.py`
- `.agent/scripts/rebuild-chroma.sh`
- `.agent/scripts/scan-history.sh`
- `.agent/scripts/scan.sh`
- `.agent/scripts/sync-hunks.py`
- `.agent/scripts/sync-memory.py`
- `.agent/scripts/sync-to-chroma.py`
- `.agent/skills/changelog/SKILL.md`
- `.agent/skills/clean-ddd-hexagonal/SKILL.md`
- `.agent/skills/clean-ddd-hexagonal/references/CHEATSHEET.md`
- `.agent/skills/clean-ddd-hexagonal/references/CQRS-EVENTS.md`
- `.agent/skills/clean-ddd-hexagonal/references/DDD-STRATEGIC.md`
- `.agent/skills/clean-ddd-hexagonal/references/DDD-TACTICAL.md`
- `.agent/skills/clean-ddd-hexagonal/references/HEXAGONAL.md`
- `.agent/skills/clean-ddd-hexagonal/references/LAYERS.md`
- `.agent/skills/clean-ddd-hexagonal/references/TESTING.md`
- _…and 12 more_

---

### [d102cb6] — 2026-04-28

**feat(cli): add init-repo command and restructure agent skills layout**

> - Add InitRepoCommand with interactive git initialization prompt
> - Register init-repo subcommand in App.java
> - Migrate all SKILL.md files from skills/ to .agent/skills/
> - Remove legacy skills/ directory and CHANGELOG.md

#### Added

- `.agent/skills/changelog/SKILL.md`
- `.agent/skills/clean-ddd-hexagonal/SKILL.md`
- `.agent/skills/clean-ddd-hexagonal/references/CHEATSHEET.md`
- `.agent/skills/clean-ddd-hexagonal/references/CQRS-EVENTS.md`
- `.agent/skills/clean-ddd-hexagonal/references/DDD-STRATEGIC.md`
- `.agent/skills/clean-ddd-hexagonal/references/DDD-TACTICAL.md`
- `.agent/skills/clean-ddd-hexagonal/references/HEXAGONAL.md`
- `.agent/skills/clean-ddd-hexagonal/references/LAYERS.md`
- `.agent/skills/clean-ddd-hexagonal/references/TESTING.md`
- `.agent/skills/commit/SKILL.md`
- `.agent/skills/commit/assets/post-commit.sh`
- `.agent/skills/endpoint-trace/SKILL.md`
- `.agent/skills/feature-docs/SKILL.md`
- `.agent/skills/find-skills/SKILL.md`
- `.agent/skills/openapi/SKILL.md`
- `.agent/skills/query-memory/SKILL.md`
- `.agent/skills/scan-memory/SKILL.md`
- `.agent/skills/skill-creator/SKILL.md`
- `.agent/skills/skill-sync/SKILL.md`
- `.agent/skills/skill-sync/assets/sync.sh`
- _…and 20 more_

#### Changed

- `.agent/memory.jsonl`
- `.agent/scripts/generate-changelog.py`
- `.agent/scripts/rebuild-chroma.sh`
- `.agent/scripts/sync-hunks.py`
- `.claude/skills`
- `.kiro/skills`
- `.kiro/steering/project-rules.md`
- `CLAUDE.md`
- `README.md`

#### Removed

- `CHANGELOG.md`
- `skills/changelog/SKILL.md`
- `skills/clean-ddd-hexagonal/SKILL.md`
- `skills/clean-ddd-hexagonal/references/CHEATSHEET.md`
- `skills/clean-ddd-hexagonal/references/CQRS-EVENTS.md`
- `skills/clean-ddd-hexagonal/references/DDD-STRATEGIC.md`
- `skills/clean-ddd-hexagonal/references/DDD-TACTICAL.md`
- `skills/clean-ddd-hexagonal/references/HEXAGONAL.md`
- `skills/clean-ddd-hexagonal/references/LAYERS.md`
- `skills/clean-ddd-hexagonal/references/TESTING.md`
- `skills/commit/SKILL.md`
- `skills/commit/assets/post-commit.sh`
- `skills/endpoint-trace/SKILL.md`
- `skills/feature-docs/SKILL.md`
- `skills/find-skills/SKILL.md`
- `skills/openapi/SKILL.md`
- `skills/query-memory/SKILL.md`
- `skills/scan-memory/SKILL.md`
- `skills/skill-creator/SKILL.md`
- `skills/skill-sync/SKILL.md`
- _…and 1 more_

---

### [fb0be98] — 2026-04-25

**feat(commit): auto-regenerate CHANGELOG.md on feat/fix/refactor/perf/sec commits**

> - Add Pass 3 to post-commit hook: runs generate-changelog.py after
> any notable commit type and auto-commits the updated CHANGELOG.md
> - Guard against infinite loop via chore(changelog): prefix detection
> - Uses --no-verify on the changelog commit to skip hook re-entry

#### Changed

- `setup.sh`
- `skills/commit/assets/post-commit.sh`

---

### [61f65d6] — 2026-04-25

**feat(changelog): add full-history regeneration from git and jsonl**

> - Add generate-changelog.py: per-commit sections [hash] with
> Added/Changed/Removed file grouping, enriched from memory.jsonl
> hunk data and git commit body
> - Add rebuild-chroma.sh: drops and rebuilds ChromaDB collection

#### Added

- `.agent/scripts/generate-changelog.py`
- `.agent/scripts/rebuild-chroma.sh`

#### Changed

- `.agent/memory.jsonl`
- `.agent/scripts/sync-to-chroma.py`
- `setup.sh`
- `skills/changelog/SKILL.md`

---

### [0edf290] — 2026-04-25

**refactor(agent): remove memory.db references and harden memory bootstrap**

> - Replace memory.db auto-invoke triggers with memory.jsonl in setup.sh,
> SKILL.md, CLAUDE.md, and project-rules.md
> - Remove memory.db from git diff filters and SKIP_FILES in sync-hunks.py
> - bootstrap.sh now runs scan-history.sh before Java scan (3-step flow)

#### Added

- `.agent/scripts/scan-history.sh`

#### Changed

- `.agent/memory.jsonl`
- `.agent/scripts/bootstrap.sh`
- `.agent/scripts/sync-hunks.py`
- `.kiro/steering/project-rules.md`
- `CLAUDE.md`
- `README.md`
- `setup.sh`
- `skills/scan-memory/SKILL.md`

---

### [2c9053d] — 2026-04-25

**fix(agent): fix query-memory filter bug and update memory terminology**

> - Remove broken where-filter condition in query-memory.py
> - Mark sync-hunks.py as executable
> - Strip dead comments from bootstrap.sh and sync-to-chroma.py
> - Update scan-memory and query-memory SKILL.md: replace SQLite/memory.db

#### Changed

- `.agent/memory.jsonl`
- `.agent/scripts/bootstrap.sh`
- `.agent/scripts/query-memory.py`
- `.agent/scripts/sync-hunks.py`
- `.agent/scripts/sync-to-chroma.py`
- `skills/query-memory/SKILL.md`
- `skills/scan-memory/SKILL.md`

---

### [1630906] — 2026-04-25

**feat(skills): add clean-ddd-hexagonal skill with auto-invoke triggers**

> - Add SKILL.md and references/ directory for clean-ddd-hexagonal
> - Embed skill template in setup.sh for bootstrapped projects
> - Register skill in CLAUDE.md and .kiro/steering/project-rules.md
> with full auto-invoke trigger list

#### Added

- `skills/clean-ddd-hexagonal/SKILL.md`
- `skills/clean-ddd-hexagonal/references/CHEATSHEET.md`
- `skills/clean-ddd-hexagonal/references/CQRS-EVENTS.md`
- `skills/clean-ddd-hexagonal/references/DDD-STRATEGIC.md`
- `skills/clean-ddd-hexagonal/references/DDD-TACTICAL.md`
- `skills/clean-ddd-hexagonal/references/HEXAGONAL.md`
- `skills/clean-ddd-hexagonal/references/LAYERS.md`
- `skills/clean-ddd-hexagonal/references/TESTING.md`

#### Changed

- `.kiro/steering/project-rules.md`
- `CLAUDE.md`
- `setup.sh`

---

### [60dc5e3] — 2026-04-25

**feat(agent): add post-commit compact reminder for Claude Code and Kiro**

#### Changed

- `.agent/memory.jsonl`
- `setup.sh`
- `skills/commit/assets/post-commit.sh`

---

### [dccd076] — 2026-04-25

**refactor(setup): sync setup.sh templates with hunk-based memory system**

> - Replace post-commit.sh template with two-pass sync-hunks.py version
> - Replace sync-files.py template with sync-hunks.py (hunk-level tracker)
> - Update sync-to-chroma.py template to handle both symbol and change types
> - Update query-memory.py template with --type filter and change record display

#### Changed

- `.agent/memory.jsonl`
- `setup.sh`

---

### [c94b63a] — 2026-04-25

**fix(agent): resolve project root in scan.sh for standalone execution**

#### Changed

- `.agent/memory.jsonl`
- `.agent/scripts/scan.sh`

---

### [b625647] — 2026-04-25

**fix(agent): resolve bootstrap path and remove obsolete docker-compose version**

> - bootstrap.sh resolves project root via SCRIPT_DIR to fix relative path error
> - Remove obsolete version field from docker-compose.yml
> - Sync setup.sh templates

#### Changed

- `.agent/chroma/docker-compose.yml`
- `.agent/memory.jsonl`
- `.agent/scripts/bootstrap.sh`
- `setup.sh`

---

### [86811de] — 2026-04-25

**refactor(agent): replace SQLite with hunk-level JSONL+Chroma memory**

> - Add sync-hunks.py: each git diff hunk becomes one change record
> - Remove schema.sql, rebuild.sh, sync-files.py (SQLite eliminated)
> - Update post-commit.sh: sync-hunks.py for all types + sync-memory.py for Java symbols
> - Update sync-to-chroma.py: handle both symbol and change record types

#### Added

- `.agent/scripts/sync-hunks.py`

#### Changed

- `.agent/memory.jsonl`
- `.agent/scripts/bootstrap.sh`
- `.agent/scripts/query-memory.py`
- `.agent/scripts/sync-to-chroma.py`
- `skills/commit/assets/post-commit.sh`
- `skills/scan-memory/SKILL.md`

#### Removed

- `.agent/schema.sql`
- `.agent/scripts/rebuild.sh`
- `.agent/scripts/sync-files.py`

---

### [9de9d34] — 2026-04-25

**fix(agent): extract meaningful intent for non-Java files in sync-files**

> - Add extract_intent() to pull first comment from .sh, module docstring
> from .py, first heading from .md, first comment from .yaml/.sql
> - Remove fake line ranges from non-Java file entries
> - Fix docstring regex to match past shebang line

#### Changed

- `.agent/memory.jsonl`
- `.agent/scripts/sync-files.py`
- `setup.sh`

---

### [5ed979e] — 2026-04-25

**feat(agent): track all file types in post-commit memory sync**

> - Add sync-files.py to index .md, .sh, .py, .yaml, .yml, .sql, .json
> - Extract name/description from SKILL.md frontmatter as intent
> - Update post-commit.sh to call both sync-memory.py and sync-files.py
> - Bundle sync-files.py and updated hook template in setup.sh

#### Added

- `.agent/scripts/sync-files.py`

#### Changed

- `setup.sh`
- `skills/commit/assets/post-commit.sh`

---

### [914c495] — 2026-04-25

**feat(skills): add query-memory skill and harden commit workflow**

> - Add query-memory skill with Chroma semantic search and JSONL fallback
> - Rewrite query-memory.py with auto-detect + fallback to memory.jsonl
> - Delete deprecated .agent/scripts/post-commit.sh
> - Add Chroma sync step (Step 5) to scan-memory skill

#### Added

- `skills/query-memory/SKILL.md`

#### Changed

- `.agent/scripts/query-memory.py`
- `.kiro/steering/project-rules.md`
- `CLAUDE.md`
- `setup.sh`
- `skills/commit/SKILL.md`
- `skills/scan-memory/SKILL.md`

#### Removed

- `.agent/scripts/post-commit.sh`

---

### [b36bb02] — 2026-04-25

**refactor(skills): remove install-hooks.sh and link hook directly from setup**

> - Remove .agent/scripts/install-hooks.sh (no longer needed)
> - Setup now creates post-commit symlink directly to skills/commit/assets/
> - Hook logic simplified in setup.sh Step 6

#### Changed

- `setup.sh`

---

### [b482338] — 2026-04-25

**feat(skills): add skill-driven protocol with Chroma memory**

> - Add setup.sh with full skill infrastructure
> - Add 10 bundled skills (changelog, commit, scan-memory, etc.)
> - Add Chroma vector DB for semantic search
> - Add post-commit hook that syncs to Chroma after each commit

#### Added

- `.agent/chroma/docker-compose.yml`
- `.agent/memory.jsonl`
- `.agent/schema.sql`
- `.agent/scripts/bootstrap.sh`
- `.agent/scripts/install-hooks.sh`
- `.agent/scripts/post-commit.sh`
- `.agent/scripts/query-memory.py`
- `.agent/scripts/rebuild.sh`
- `.agent/scripts/scan.sh`
- `.agent/scripts/sync-memory.py`
- `.agent/scripts/sync-to-chroma.py`
- `.claude/skills`
- `.kiro/skills`
- `.kiro/steering/project-rules.md`
- `CLAUDE.md`
- `skills/changelog/SKILL.md`
- `skills/commit/SKILL.md`
- `skills/commit/assets/post-commit.sh`
- `skills/endpoint-trace/SKILL.md`
- `skills/feature-docs/SKILL.md`
- _…and 6 more_

#### Changed

- `setup.sh`

---

### [93ebc38] — 2026-04-25

**post-commit trigger hook**

#### Changed

- `setup.sh`

---

### [37e11aa] — 2026-04-24

**feat(skills): add ChromaDB sync and author tracking to agent memory**

> - Add sync-to-chroma.py script for memory.jsonl → ChromaDB sync
> - Add bootstrap.sh for combined scan + Chroma sync workflow
> - Add docker-compose.yml for ChromaDB container (v1.5.3)
> - Update post-commit hook to sync to Chroma instead of SQLite rebuild

#### Changed

- `setup.sh`

---

### [2eeb48f] — 2026-04-24

**base scrips development**

_No file changes detected._

---
