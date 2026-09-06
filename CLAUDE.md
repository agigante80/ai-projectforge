# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What This Repo Is

**The superpowers boundary (issue #69, decided 2026-08-27):** where the obra/superpowers
plugin is present, superpowers owns the INNER loop (how work happens: brainstorm, plan, TDD,
per-round review, verify) and forge-kit owns the OUTER loop (what must be true before and
after: tickets and the gate, hooks and CI guards, versioning, host awareness, overnight
governance). Deliberately kept and not to be "fixed" by contributions: governed unattended
work (approval happens at gate time) and mechanical enforcement over prose persuasion, which
are forge-kit's differentiators. forge-adapt's coexistence mode (#72) applies the boundary at
install time.

A root `AGENTS.md` exists as a thin pointer to this file for non-Claude agents (the open
cross-agent instruction format); keep it a pointer, never duplicate content into it.

**forge-kit** is an AI-assisted project governance scaffold: AI-agnostic at the governance layer (issue templates, labels, GWT scenarios), Claude Code-native at the automation layer (agents, skills, slash commands). It is a template repository, not a buildable application. Its purpose is to be bootstrapped into other projects or used as an upgrade reference via the `forge-adapt` skill. There are no build steps or package managers. The only CI is a governance `Validate` workflow (`.github/workflows/validate.yml`): it runs the structural check, the template lockstep, thirteen contract test suites, the component-index freshness check, the component size budget, and (on `pull_request` only) the two range guards, plus one advisory `claude plugin validate` step marked `continue-on-error` that can report issues without failing the build. There is no application build/test pipeline. Eight of those thirteen suites cover shipped executables (hooks, the catalogue script, `forge-lib.sh`, the component-index generator); the other five cover the repo's own guards (`test-template-lockstep.sh`, `test-check-plugin-version-bump.sh`, `test-component-size.sh`, `test-pre-push-hook.sh`, `test-component-paths.sh`), and all of those run unconditionally even though one of the guards they cover is PR-only.

**Validation approach:** There is no application test runner. Two kinds of validation exist:

1. **Structural / discipline checks** (the same gates CI runs; run these before committing):

   ```bash
   bash scripts/validate-plugins.sh            # plugin.json + marketplace.json + version markers (whole tree)
   bash scripts/check-template-lockstep.sh     # fail if the work templates + canonical ticket-standards doc drift out of version lockstep
   python3 scripts/test-hooks.py               # behavioural contract tests for the hooks
   bash scripts/test-template-lockstep.sh      # contract test for the lockstep guard above
   bash scripts/test-forge-adapt-catalogue.sh  # contract test for the forge-adapt catalogue script
   bash scripts/test-forge-lib.sh              # contract test for the forge-host adapter (stubbed transport)
   bash scripts/test-update-component-index.sh # contract test for the component-index generator
   python3 scripts/update-component-index.py --check  # fail if the generated inventory regions are stale
   bash scripts/test-component-size.sh          # contract test for the size budget guard
   bash scripts/check-component-size.sh        # warn above the word budget, fail above the ceiling
   bash scripts/test-pre-push-hook.sh          # contract test for the local pre-push range guard
   bash scripts/test-component-paths.sh        # fail if the four path-set consumers disagree
   bash scripts/test-version-lib.sh            # contract test for the release version<->tag primitive
   bash scripts/test-release-run.sh            # contract test for the release lane policy (DRY_RUN)
   bash scripts/test-sync-labels.sh            # contract test for the host-aware label sync
   python3 scripts/test-closing-sessions-memory.py  # contract test for the closing-sessions memory.py helper (NOT yet wired into CI)
   git fetch origin main                       # required: the next script fails closed on a missing base ref
   bash scripts/check-version-bump.sh origin/main   # fail if a changed component didn't bump its <name>-version marker
   bash scripts/test-check-plugin-version-bump.sh   # contract test for the plugin-semver guard below
   bash scripts/check-plugin-version-bump.sh origin/main  # fail if a changed plugin GROUP didn't bump its plugin.json semver
   git config core.hooksPath .githooks         # one-time: enable the local pre-commit version-bump guard
   ```

   `validate-plugins.sh` requires `jq` and `grep -P` (GNU grep). `check-version-bump.sh` diffs `<base>...HEAD` (CI passes `origin/$BASE_REF`) and **exits 1 if the base ref does not exist locally**, rather than passing vacuously, so fetch first. It reads committed blobs via `git show`, not the worktree: an uncommitted marker bump will not satisfy it. The local `.githooks/pre-commit` covers markers with `--diff-filter=AM` on the staged set (CI additionally catches renames, `AMR`) and runs the plugin-semver rule via `check-plugin-version-bump.sh --staged` (`ADM`, `--no-renames` so a cross-group rename charges the source group too). The semver half needs `jq`: a jq-less machine skips it with a loud warning and CI still enforces it. Both range guards run at PR time only; a direct push to main bypasses them, so the local hook is the only gate on that path.

   No test script takes a filter argument, so one script is the smallest unit you can run; there is no per-case selector to reach for. The only finer entry point is `python3 plugins/forge-kit-devops/hooks/block-legacy-host-push.py --self-test`, that hook's own verdict matrix, which `test-hooks.py` also drives.

2. **Behavioural validation:** agents, skills, and commands are prose, cannot be run in isolation here, and must be installed into a test project via `forge-adapt` and exercised there. **The exception is anything the kit ships as an executable**, which has a real contract and therefore a real test. Six exist today, and all six run in CI, each exercised as a subprocess (throwaway directories, this repo itself, or a stubbed transport, per bullet):

   - **Hooks** (`scripts/test-hooks.py`): JSON payload on stdin, a `permissionDecision` on stdout, always exit 0. The test covers every matched tool, fail-open on unparseable input, deny-signalled-on-stdout-not-exit-code, and a regression guard for the foreign-cwd wiring bugs. It runs in CI. When you change a hook, extend it: three consecutive PRs shipped hook defects before this existed.
   - **`closing-sessions/scripts/memory.py`** (`scripts/test-closing-sessions-memory.py`, 12 tests): the one skill that ships an executable rather than only prose, so the `forge-kit-governance` plugin has a second testable surface. Its own history is the argument for the test (`anchor index matching and escape memory fields`, `treat index-line replacement as literal, not regex`). Wired into CI as of #76; it previously existed but ran only by hand. It still carries **no** `<name>-version: N` marker, because `memory.py` lives in a `scripts/` subdirectory and no marker guard globs that (see the enforced path set below), so a change to it is caught by the test but produces no drift signal for `forge-adapt`.
   - **`scripts/forge-adapt-catalogue.sh`** (`scripts/test-forge-adapt-catalogue.sh`, in CI): the S3 component catalogue the `forge-adapt` skill runs verbatim instead of paraphrasing an inline block (an LLM executor kept reintroducing fixed bugs). Contract: prints `<type>: <name> | v<N>` rows where a skill's name is its *directory* name (every skill file is `SKILL.md`), resolves each version by marker name and then by the first-marker-wins fallback (see the marker-parsing note under Key Conventions), never prints `vnone`, and always exits 0 so a group with no hooks or agents never reads as a failure. Also lists versioned shell assets as `asset:` rows. A `--tsv` mode adds the file path for machine consumers (`update-component-index.py`); the default output is a contract forge-adapt reads, so it is byte-stable and must stay that way.
   - **`scripts/update-component-index.py`** (`scripts/test-update-component-index.sh`, in CI): renders the component inventory into marker-delimited regions in `README.md` (`component-index`) and `CLAUDE.md` (`plugin-groups`) from the catalogue's `--tsv` output, and `--check` fails a build whose regions have gone stale. **Do not hand-edit inside those markers**; run the script. It is Python rather than bash because it is marker rewriting and diffing rather than globbing, and it shells out to the catalogue rather than re-walking the tree, so "what counts as a component" keeps one definition.
   - **`forge-host/assets/forge-lib.sh`** (`scripts/test-forge-lib.sh`, in CI): the host adapter, driven with a stubbed `forge_api` standing in for the network layer. Covers Forgejo pagination (termination on an EMPTY page, deliberately not `length < limit`, because the server clamps `limit` to `MAX_RESPONSE_ITEMS`), multi-page label resolution, atomic refusal of unresolvable label names, the zero-label message, and dry-run sending nothing.

   - **`release-automation/assets/version-lib.sh`** (`scripts/test-version-lib.sh`, 19 tests, in CI): the version-versus-tag primitive every release lane sources and acts on. Side-effect-free and returns a one-word verdict, so it tests like a pure function against throwaway repos where the tags ARE the input. Covers the four verdicts, the fail-closed paths, `TAG_GLOB` deriving from `TAG_PREFIX`, and two traps the source calls out: comparing release CORES (because `sort -V` ranks `1.2.0-rc1` above `1.2.0`, so a naive compare would ship a prerelease as production) and git-mode being HEAD-relative on purpose (so a higher tag on an unmerged sibling branch cannot make HEAD look `behind`).
   - **`release-automation/assets/release-run.sh`** (`scripts/test-release-run.sh`, 19 tests, in CI): the side-effecting release driver, run entirely with `DRY_RUN=1` so no forge, push or tag is touched. Covers the LANE POLICY rather than the mechanics: the recursion guard, the dependency scope gate (including the vacuous case, where a bot commit changing no files must not release), the version decision for each verdict, and tag-derived git mode's bootstrap and phantom-tag guards.

   - **`forge-host/assets/sync-labels.sh`** (`scripts/test-sync-labels.sh`, 22 tests, in CI): makes the host's labels match `.github/labels.yml`, or `--check` reports that they do not. Host-aware through `forge-lib.sh` (GitHub updates a label by NAME, Forgejo by ID) and **never deletes**: an undeclared label is reported and left alone, because GitHub ships stock defaults and a sync that deletes what it does not recognise is a footgun aimed at other people's data. A malformed `labels.yml` line REFUSES the whole run rather than skipping the entry, since a silent partial sync is the drift it exists to end. Driven in tests by a stub `forge-lib.sh` placed beside a copy of the script, so the script sources the stub instead of the transport.

   **Every shipped executable now has a contract test, and all of them run in CI** (issue #76 closed the last gap). All four shell assets carry hook-style `# <name>-version: N` markers, enforced by the same enforcement points as every other component.

## Architecture

The kit is organized into plugin groups under `plugins/<group>/`. This table is generated from the
tree by `scripts/update-component-index.py`; CI fails if it goes stale, so do not hand-edit it. The
Version column is the group's `plugin.json` semver (the unit of install), not a component marker.

<!-- plugin-groups:start -->
<!-- Generated by scripts/update-component-index.py from the plugins/ tree. Do not hand-edit: run the script. CI fails on a stale region. -->

| Plugin group | Version | Contents |
|---|---|---|
| `forge-kit-adapt` | 0.3.5 | skill: adapt |
| `forge-kit-backend` | 0.1.0 | skills: api-design-principles, architecture-patterns, cqrs-implementation, microservices-patterns, saga-orchestration |
| `forge-kit-devops` | 0.7.1 | agents: dep-auditor, health-check; command: ci-health; skills: find-dead-code, forge-host, github-to-forgejo, release, release-automation; hook: block-legacy-host-push; shell assets: forge-lib, release-run, sync-labels, version-lib |
| `forge-kit-governance` | 0.7.17 | agent: ticket-gate; command: gate-ticket; skills: closing-sessions, working-overnight; hooks: block-dashes, overnight-continue, overnight-guard |
| `forge-kit-review` | 0.3.3 | agents: architect-review, backend-architect, code-reviewer, code-simplifier, coding-standards-auditor; commands: full-review, pr-enhance |
| `forge-kit-security` | 0.3.0 | agents: api-security-tester, backend-security-coder, security-auditor; skills: owasp-api-security, privacy-regime |
| `forge-kit-testing` | 0.2.1 | agents: performance-engineer, tdd-orchestrator, test-automator; skill: mutation-sweep |
<!-- plugin-groups:end -->

Users install via the plugin marketplace (`/plugin marketplace add agigante80/forge-kit`) or by cloning the repo and running `forge-adapt` from within the target project.

## Component Types

**Agents** (`plugins/<group>/agents/*.md`): isolated specialist subagents that run in a separate context window, invoked via the Claude Code `Agent` tool with `subagent_type`. Required YAML frontmatter:

```yaml
---
name: <agent-name>
description: <when to invoke this agent (include trigger phrases)>
model: opus          # or omit for default
tools: ["Agent", "Bash", "Read", "Grep", "Glob"]
color: red           # optional; used in Claude Code UI
---
```

Key agents:
- `ticket-gate`: deterministic mechanical checks plus ONE critic agent (verdict, pushback, GWT review, pros and cons, researched best practices, suggested approach), with a security lens on `security`/`critical` labels; posts the review to the forge and returns PASS, NEEDS-WORK, or BLOCKED (labels/thin-ticket). The former 5-agent 10/10 scoring committee was retired by issue #70.
- `dep-auditor`: scans workspace packages for unused deps, unmaintained libraries, and vulnerabilities; caches results in `docs/audit/dep-audit-cache.json` (30-day window); creates GitHub tickets for every finding.
- `health-check`: verifies the dev environment (runtime, package manager, Docker, TypeScript, env files, GitHub CLI).
- `coding-standards-auditor`: consolidates coding standards from wherever they live (inline CLAUDE.md, CONTRIBUTING.md, STYLE_GUIDE.md, docs/) into a canonical `docs/coding-standards.md`, then replaces the inline standards with a reference line.
- `code-simplifier`: runs proactively after a code change to simplify recently modified code while preserving functionality.
- Specialist agents: `security-auditor`, `architect-review`, `backend-architect`, `code-reviewer`, `api-security-tester`, `tdd-orchestrator`, `test-automator`, `performance-engineer`, `backend-security-coder`.

Note: the 5-phase `full-review` orchestrator is a **command** (`/full-review`), not an agent (see Commands below). There is no `full-review` agent type.

**Commands** (`plugins/<group>/commands/*.md`): thin slash-command wrappers that delegate to agents. The command name comes from the filename (`full-review.md` → `/full-review`), so YAML frontmatter is optional and inconsistent across the kit: `gate-ticket`, `pr-enhance`, and `ci-health` have no frontmatter at all (markdown body only); `full-review` uses `description` + `argument-hint`. Don't assume a `name:` field exists. Users invoke these directly:
- `/gate-ticket <N>`: run the ticket readiness gate on GitHub issue N.
- `/full-review [path] [--since <ref>] [--security-focus] [--performance-critical] [--strict-mode] [--framework name]`: 5-phase code review; `--since` runs a delta-only verify-fixes round under the iteration contract. Positioned as a pre-merge/periodic audit, not the per-task reviewer (that is `code-reviewer` alone under the same contract).
- `/pr-enhance`: pull request enhancement (description, scope review, checklist generation).
- `/ci-health`: check all GitHub Actions workflows, create P0 tickets for failures, auto-fix safe failures.

Note: `dep-auditor` and `health-check` are agent types, not slash commands. Trigger them by mentioning "health check" or "audit dependencies" in conversation.

**Skills** (`plugins/<group>/skills/*/SKILL.md`): domain knowledge injected into the main conversation (not isolated). Frontmatter requires only `name` and `description`. Skills can have `assets/` (checklists, templates, shipped executables), `references/` (supporting docs), and `scripts/` (helper executables) subdirectories alongside `SKILL.md`. For example, `api-design-principles` (`forge-kit-backend`) uses `assets/` + `references/`, `forge-adapt` (`forge-kit-adapt`) uses `references/` (one signal→component→why map per recommendation category), and `closing-sessions` (`forge-kit-governance`) is the only user of `scripts/`. Only `assets/*.sh` is version-marker enforced; see the enforced path set under Key Conventions before adding an executable anywhere else. Triggered automatically when relevant or by user invocation. Includes: `forge-adapt`, `api-design-principles`, `owasp-api-security`, `architecture-patterns`, `microservices-patterns`, `cqrs-implementation`, `saga-orchestration`, `find-dead-code` (the source-code counterpart to the `dep-auditor` agent), `mutation-sweep` (coverage's blind spot: tests that cannot fail, engine adopted per stack), `release` (semver bump + version-check guard + tag + close shipped tickets), `release-automation` (the *enforced* sibling of `release`: a CI gate that blocks a merge to the production branch unless the version was bumped past the last release, built on a shared version↔tag primitive, plus optional auto-release lanes), `forge-host` (the `forge_*` adapter that makes governance host-aware across GitHub and Forgejo), `github-to-forgejo` (the GitHub-to-Forgejo migration playbook), `closing-sessions` (persist durable facts and resume state before a session ends), `working-overnight` (governed unattended overnight work shipped as branch-plus-PR, never merging).

**Issue Templates** (`.github/ISSUE_TEMPLATE/*.yml`): six templates. The five *work* templates (`feature.yml`, `bug.yml`, `security.yml`, `infrastructure.yml`, `design.yml`) carry `template-version: 6` and the mandatory sections: GWT scenarios, unit test specs, E2E test specs, personal-data handling, security checklist, documentation impact, and required reviews checkbox. `contribution.yml` is the odd one out: it proposes a component *to forge-kit itself* rather than describing project work, so it carries no `template-version` marker and no GWT sections. Don't "fix" it by adding them. The `ticket-gate` agent auto-synthesizes missing v6 sections from earlier-version tickets. The **rules** those sections must satisfy live in one canonical place, `docs/guides/ticket-standards.md` (the single source of truth): the templates carry the form fields, that doc holds the rules and rationale, `ticket-gate` enforces them, and `scripts/check-template-lockstep.sh` keeps the templates and that doc on one shared `template-version` so they cannot drift apart. That doc carries a **second** marker, `doc-rules-version`, which the lockstep guard deliberately ignores (issue #94): `template-version` says which FORM the doc describes and bumping it re-synthesises every open ticket, while `doc-rules-version` says which revision the RULES TEXT is at and costs nothing downstream. Bump the rules marker alone for a rules edit that changes no form field. See `docs/guides/template-versioning.md` for the versioning scheme and auto-synthesis logic.

## Plugin Structure

Each plugin group has a `.claude-plugin/plugin.json` with `name`, `description`, and a semver `version` (the ecosystem-standard plugin version, distinct from the per-component `<name>-version` markers):

```json
{ "name": "forge-kit-<group>", "version": "0.1.0", "description": "..." }
```

The root `.claude-plugin/marketplace.json` lists all plugins with their local `source` paths. This is the file the plugin marketplace reads to discover installable plugins.

**Three versioning levels (don't conflate them):** the **release tag** (`vX.Y.Z` on main) is the umbrella version naming the state of the whole marketplace at a point in time. It is a communication artifact, not a delivery mechanism: `/plugin marketplace add` tracks the repository, so a tag never changes what an existing user receives. The tag itself is the canonical source, and there is deliberately no `VERSION` file and no `version` field in `marketplace.json`, because a repo-level version file would be a mirror with nothing to check it against and no guard watching it. Nothing enforces the tag, and nothing needs to; there is only one place to be wrong. The **plugin** version (`version` in `plugin.json`, semver) is the standard unit-of-install version read by the marketplace/tooling, set per plugin group. The **component** version (`<!-- <name>-version: N -->` markers) is forge-kit's finer-grained signal for detecting drift in a single component that `forge-adapt` cherry-picked and rewrote into a project's `.claude/`. Divorced from its plugin, a loose adapted file needs its own marker. The `Validate` CI workflow enforces both: `scripts/validate-plugins.sh` checks structure + semver + marker presence; `scripts/check-version-bump.sh` fails a PR whose component changed without a marker bump (the authoritative, server-side counterpart to the opt-in `.githooks/pre-commit`); `scripts/check-plugin-version-bump.sh` fails a PR whose plugin GROUP changed without a `plugin.json` semver bump, so the unit-of-install version can no longer rot while markers move (it did exactly that in PRs #74/#75, which is why the guard exists). Cutting a release does **not** touch plugin semvers: those move on the PR that changes their group, which is the only moment a guard can see it. The full model, including when to bump the umbrella and why `template-version` is not one of these levels, is `docs/guides/versioning.md`; `CHANGELOG.md` carries the umbrella history.

## Key Conventions

**Agents vs. Skills vs. Commands:**
- Agents → isolated context, structured output, scoring, auditing
- Skills → injected knowledge, patterns, checklists; no isolation
- Commands → user-facing entry points; delegate to agents

**`{{GITHUB_REPO}}` placeholder:** Appears in agents that call the GitHub API (e.g., `ticket-gate`). Must be replaced with `owner/repo` at install time. `forge-adapt` handles this automatically; manual installs need `sed -i 's/{{GITHUB_REPO}}/owner\/repo/g'`.

**Installation paths:**
- Plugin marketplace: `/plugin marketplace add agigante80/forge-kit` then `/plugin install forge-kit-adapt@forge-kit`, after which forge-adapt installs everything else. The skill's frontmatter `name` is `forge-adapt`, but its directory is `skills/adapt/`, so the slash form is `/forge-kit-adapt:adapt` (not `/forge-adapt`); in conversation, "run forge-adapt" also triggers it.
- Manual: clone `~/forge-kit`, then run `forge-adapt` from the target project. It reads the codebase, recommends components, and writes adapted versions into `.claude/`
- `.claude/` in a project repo = project-scoped; `~/.claude/` = global across all projects

**forge-adapt flow (v2, recommender-style):** A quiet **Setup** (silent self-update via SHA-diff against the GitHub remote, locate/clone `~/forge-kit`, catalogue components) precedes a clean three-step dialogue: **Analyze** the project (stack, domain, installed components, signal indicators) → **Recommend** the top 1-2 forge-kit components per category (Subagents, Skills, Commands, Hooks), each with a ≤60-char reason → **Install** the chosen ones, adapting agents/skills/commands to the stack and copying hooks verbatim (wiring `block-dashes` into `.claude/settings.json`). Three **secondary modes** stay out of the main flow: `refresh`/`drift` reports which installed components lag forge-kit (version-marker comparison, writes nothing) and `refresh <name>` deep-compares one component and merges in missing forge-kit improvements while preserving project adaptation (report-first, never blind-overwrite); `forge-adapt contributions` surfaces project-only components worth contributing back; `forge-adapt templates` audits issue templates and can install the repo-level template governance (the `check-template-lockstep.sh` guard plus a canonical, host-aware `docs/guides/ticket-standards.md`, adapted with the project's own `template-version` and never clobbering an existing doc). Also responds to "upgrade-audit" for backward compatibility.

**Component version markers:** every agent, skill, and command carries an HTML-comment marker (`<!-- <name>-version: N -->`, e.g. `<!-- ticket-gate-version: 1 -->`); hooks and shipped shell assets (`plugins/*/skills/*/assets/*.sh`) use a `# <name>-version: N` comment. These are the cheap, false-positive-free drift signal forge-adapt's `drift`/`refresh` modes compare against (adaptation does not change the marker; staleness does). This is distinct from the `template-version: N` marker on issue templates. When you materially change a component's behavior, bump its marker. `forge-adapt` preserves the marker when it adapts a component into a project, so a project's installed copy stays detectable.

**Version-bump enforcement, split across two local stages.** `.githooks/pre-commit` checks the STAGED set: it blocks a commit that changes a component's body without bumping its `<name>-version` marker (and flags new components missing a marker), and a commit that changes a plugin group without strictly increasing its `plugin.json` semver (one shared implementation: the hook calls `check-plugin-version-bump.sh --staged`). `.githooks/pre-push` then runs the RANGE guards (`check-version-bump.sh` and `check-plugin-version-bump.sh` against the remote's default branch), which is the question CI asks on a PR and the one that only has an answer once you know what you are pushing. That stage matters most on the path CI never sees: both range guards are `pull_request`-only, so a **direct push to main is gated by pre-push alone**. Skips are always loud, never silent, and never block the push: a missing base ref or a missing `jq` prints why and defers to CI, the same posture pre-commit already takes for `jq`. Deliberately two committed hooks rather than adopting the `pre-commit` framework, which would give a one-command install and be the first package-manager dependency in a repo that has none. One-time enablement covers both: `git config core.hooksPath .githooks`. Bypass a trivial change with `git commit --no-verify` or `git push --no-verify`.

**The enforced path set is exactly ONE directory level deep, and four consumers implement it.** A file is marker-enforced only if it matches `plugins/*/agents/*.md`, `plugins/*/commands/*.md`, `plugins/*/skills/*/SKILL.md`, `plugins/*/hooks/*.{py,sh}`, or `plugins/*/skills/*/assets/*.sh`, with **no further nesting**: `plugins/<group>/agents/references/x.md` is not a component. Everything else under `plugins/` is unversioned and unguarded by construction: `references/*` (deliberate, they are supporting prose), but also `skills/*/scripts/*.py` and non-`.sh` assets, which is why `closing-sessions/scripts/memory.py` and `api-design-principles/assets/rest-api-template.py` carry no marker today.

Three of the four consumers share one **byte-identical** ERE: `scripts/validate-plugins.sh` (as `find -regextype posix-extended -regex "$COMPONENT_RE"`), `scripts/check-version-bump.sh` and `.githooks/pre-commit` (as a `grep -E` alternation). The fourth, `scripts/forge-adapt-catalogue.sh`, must use shell globs instead, because a glob is not a regex. `scripts/test-component-paths.sh` is what keeps all four agreeing: it fails if the three strings drift apart or if the catalogue's globs stop selecting the same files. Widening the set means editing the same regex in three places and the globs in the fourth, then updating that test.

**Why an ERE and not `find -path` (issue #112).** In `find -path`, unlike a shell glob, `*` **crosses `/`**, so `-path '*/agents/*.md'` matched at any depth. The result was a silent disagreement pointing two ways at once: `validate-plugins.sh` would have *demanded* a version marker on a nested reference file, while the catalogue could never see it, so `drift`, `refresh` and the generated index would never compare the marker it was forced to carry. Latent until something nested appeared; it surfaced while investigating #109's proposed `references/` split.

**Marker parsing is positional.** All three enforcement points (`scripts/validate-plugins.sh`, `scripts/check-version-bump.sh`, `.githooks/pre-commit`) read the marker with the same `ver_of` pipeline, built on `grep -oP '[a-z0-9-]+-version: \d+' | grep -v '^template-version' | head -1`. Change one and you must change all three. Three consequences: the marker must be lowercase-kebab followed by digits; it must be the *first* `<name>-version: N` string anywhere in the file (a version reference in prose above the real marker silently becomes the parsed version); and `template-version` is skipped only when it starts the match. Most components put the marker within the first few lines. `forge-adapt` and `github-to-forgejo` sit lower because of long frontmatter, which is fine as long as nothing version-shaped precedes them.

**A component's marker name is not guaranteed to equal its component name**, and exactly one component diverges: `skills/adapt/SKILL.md` is catalogued as `adapt` (its directory) but carries `forge-adapt-version`. The three enforcement points never notice, because `ver_of` matches any `[a-z0-9-]+-version` and does not care what the file is called. `scripts/forge-adapt-catalogue.sh` did care, and printed `vnone` for it until issue #95: it resolves by name first, anchored to the comment lead-in so a short name cannot substring-match a longer marker, and now falls back to that same first-marker-wins rule when the name lookup misses. Because the catalogue walks exactly the five marker-enforced path shapes, a `vnone` row can only mean a present marker went unread, so its contract test asserts no row prints one. Renaming the directory to match the marker was rejected: it would change the published `/forge-kit-adapt:adapt` invocation and every install path to fix one row.

**This repo runs `block-dashes.py` against itself.** `.claude/settings.json` wires it as a `PreToolUse` hook on `Write|Edit|MultiEdit|NotebookEdit|Bash`, so any tool call whose payload contains an em dash (U+2014) or en dash (U+2013) is denied. This is deliberate dogfooding of a `forge-kit-governance` hook. The correct response to a hit is to **restructure the sentence**, never to substitute a hyphen for the dash.

**Hooks reach a project three ways, and the script tells them apart by its own path shape.** A plugin group ships `hooks/hooks.json`, which Claude Code activates whenever **that plugin** is enabled, anchored to `${CLAUDE_PLUGIN_ROOT}`. That copy is live in *every* project, so an opinionated hook like `block-dashes` stays dormant until the project opts in by creating `.claude/no-dashes`. The other way is a project-local install (`.claude/hooks/<name>.py` plus a `settings.json` entry), which `forge-adapt` does whenever the governance plugin is not enabled; that copy is itself the opt-in and needs no sentinel. The third way is this repo running the hook against its own tree, which is what `.claude/settings.json` does here: it points at `plugins/forge-kit-governance/hooks/block-dashes.py`, a path that is neither a `.claude/hooks/` copy nor outside the project. `enforcement_enabled()` therefore branches three times, in order: a script in a `.claude/hooks/` directory always enforces; otherwise, a script that resolves *under* `CLAUDE_PROJECT_DIR` (falling back to the payload's `cwd`) also always enforces, opt-in implied by its presence in the tree; only a script resolving *outside* the project root is the plugin's own copy, and that is the single branch that consults the `.claude/no-dashes` sentinel. So **this repo has no `.claude/no-dashes` file and the guard is live anyway.** Do not add one to "fix" it, and do not read a missing sentinel as a disabled hook: pipe a payload through the script to find out. The `.claude/hooks/` test is keyed on path shape, so it holds regardless of the working directory or which environment variables were exported. An earlier version keyed on "is the script under the project root," falling back to the payload's `cwd`, which is the *session's* directory rather than the project root, so a session started in a subdirectory silently disabled the guard. One deliberate exception to the plugin path: `block-legacy-host-push.py` (`forge-kit-devops`) ships with **no** `hooks.json`. It must never be live in every project, so it is installed project-locally only, by the `github-to-forgejo` skill's cutover phase. Don't "fix" the missing wrapper.

The governance `hooks.json` wires three hooks in three different shapes, and the differences are deliberate. `block-dashes` is a `PreToolUse` hook shell-gated on a dedicated opt-in file, `.claude/no-dashes`. `overnight-guard` is also `PreToolUse` and shell-gated, but on `.claude/overnight/active.md`, the armed run's own manifest rather than a separate sentinel, so arming a run is the opt-in and no second file can fall out of sync with it; it also matches `Bash` alone, where `block-dashes` matches the full five-tool write set, because it polices commands rather than prose. `overnight-continue` is the exception to "gate in the shell, not the interpreter": it is a **Stop** hook wired straight to `python3` with no `sh` wrapper, gating internally on the same manifest. A Stop hook fires once per session end rather than once per matched tool call, so the 44 ms interpreter start is paid a handful of times a day instead of thousands, and the wrapper is not worth its own failure mode there. Do not "unify" these three onto one shape. `plugins/forge-kit-governance/hooks/README.md` carries the long form of the install model (sentinel, shell gate, measured costs), though it predates the overnight hooks and documents only the `block-dashes` shape; read it before changing how a hook reaches a project.

Two facts that are easy to conflate and must not be. **Where the component library lives** (`~/.claude/plugins/marketplaces/forge-kit`, or a `~/forge-kit` clone) says nothing about **which plugin groups are enabled**. The plugin *cache* (`~/.claude/plugins/cache/<marketplace>/<plugin>/<sha>/`) contains only an installed plugin's own files and never a `plugins/` tree, so it can never serve as the library. `forge-kit-governance` must be installed explicitly (`/plugin install forge-kit-governance@forge-kit`) for its `hooks.json` to load; the quick-start installs `forge-kit-adapt` alone. Prefer plugin registration where it applies, because it owns no user config and so has no wiring to drift, duplicate, or clobber, and that copy-and-mutate path was the origin of every hook bug in this repo's history.

**A plugin hook is live in every project, so gate it in the shell, not in the interpreter.** `hooks.json` runs `sh -c`, which tests for the sentinel and exits before `exec python3` unless the project opted in: 1.8 ms per matched tool call in a project that has not, against 44 ms if Python starts first, because the interpreter pays for `site` and its stdlib imports before it can read its own gate. The gate inside `block-dashes.py` stays as defence in depth, and is the only gate for the project-local install shape, which has no wrapper. The wrapper requires `sh` on `PATH` (Git Bash on Windows); where that is unavailable, install project-locally.

Wire hooks in **exec form** (`"command": "python3"` plus `"args": ["${CLAUDE_PROJECT_DIR}/..."]`), never as a bare command string.

The failure that actually bites is a **relative** path. It resolves only when Claude Code's working directory happens to be the repo root; from a subdirectory `python3` cannot open the script and exits 2, and exit code 2 is precisely the PreToolUse *deny* signal, so every matched `Write`/`Edit`/`Bash` call is blocked with a confusing `can't open file` message. The hook does not go quiet, it wedges the session.

An **unbraced** `$CLAUDE_PROJECT_DIR` in a shell-form command is *not* broken, contrary to what an earlier revision of this file claimed. `${CLAUDE_PROJECT_DIR}` is a placeholder Claude Code substitutes, and separately the same value is exported into every hook process: the [plugins reference](https://code.claude.com/docs/en/plugins-reference) states the path variables are "exported as environment variables to hook processes" and that `${CLAUDE_PROJECT_DIR}` "is the same directory hooks receive in their `CLAUDE_PROJECT_DIR` variable." Shell form runs via `sh -c`, so the shell expands it. Prefer exec form anyway, because it is what the docs recommend and it removes shell quoting from the picture entirely: with `args` present Claude Code spawns the executable directly with no shell, substituting `${CLAUDE_PROJECT_DIR}` into each argument as a plain string.

Two distinct fail-open behaviours, do not conflate them. The script itself denies by printing a `permissionDecision: deny` JSON object on stdout and **always exits 0**, so its `except (json.JSONDecodeError, ValueError): sys.exit(0)` is a real fail-open: unparseable input never blocks a call. A *missing* script never reaches that code, and the interpreter's own exit status is what Claude Code sees.

**Component size budget.** Prose components carry a word budget, enforced by `scripts/check-component-size.sh` and visible as the Words column of the generated index. Hooks and shell assets are code and are not counted.

| Type | Budget (warn above) | Hard ceiling (fail above) |
|---|---|---|
| agent | 2000 | 3000 |
| command | 2000 | 3000 |
| skill | 2500 | 3750 |

The ceiling is 1.5x the budget. These numbers are duplicated in `check-component-size.sh`, and `scripts/test-component-size.sh` fails if the two disagree, because a policy stated in prose that nothing applies is the defect this repo keeps finding.

**It is a smell detector, not a quality metric.** The justification is this repo's own defect record, not context-window research: three review rounds on `ticket-gate.md` produced findings that were all symptoms of size rather than of any single edit (the same rule in four places updated in two, a 21-line bullet carrying seven rules, rules drifting from the steps they govern 400 lines away). A 2000-word file can still state one rule three times, so treat a warning as a prompt to hunt duplication, never as a licence to compress prose until it is dense but unclear. The often-cited "lost in the middle" result is about retrieval, and at least one study finds no position effect for instruction following, so do not lean on it.

**Three components are exempt, and the exemption is a ratchet, not a pass:** `adapt` (7357), `ticket-gate` (5715), `full-review` (3998). Each baseline is that component's size when the budget landed. An exempt component may shrink freely and **may not grow by a single word**; growth fails the build exactly as the ceiling does. Retrofitting them is out of scope of the budget itself (#109 covers `ticket-gate`), and the ratchet keeps the debt from growing while that waits. When one shrinks, lower its baseline in the script to lock the gain in. Note that `full-review` is exempt because it measured 3998 against a 3000 ceiling, not because the ticket proposing the budget listed it; the exemption set was derived from measurement.

**Splitting convention, for when a component outgrows its budget.** Move *reference* material into a `references/` subdirectory beside the component, the pattern `forge-adapt` and `api-design-principles` already use. Reference material is what the orchestrator reads once (lens definitions, checklists, taxonomies), never the step-by-step instructions or the rules governing them. **The main file stays canonical for every rule.** A reference may point at a rule; it may never restate one, because this repo's review record shows content moved into a second location drifts from the first (the lens contract across two plugins, the doc-versus-gate restatement). If a rule appears in both, that is the bug, and the main file wins.

**Label → lens routing:** `docs/guides/labels.md` documents the label taxonomy, and `forge-host/assets/sync-labels.sh` is what puts it ON the host (issue #104: it was declarative with no applier for months, so `security`, `critical` and `api` did not exist here and the gate's routing was unexercisable in the repo that ships it). Labels modulate the gate's review set: `security` and `critical` add the security lens (and `critical` puts the critic in maximum scrutiny); `api` adds the API-design checklist to the critic's brief without an extra agent; `privacy` adds the project's installed `privacy-regime` skill the same way. To add routing for a new label, add a row to the lens table in `ticket-gate.md`, preferring a critic-brief modulation over a new agent.

**Extending ticket-gate's routing:** The lens table inside `ticket-gate.md` maps labels and body keywords to specialist lenses. Add a lens agent only for a genuinely independent domain perspective; otherwise modulate the critic's brief (the `api` row is the pattern).

**ci-health command** (`/ci-health`) discovers all `.github/workflows/*.yml` files, checks the latest run for each, creates P0 tickets for failures, gates each ticket, and auto-implements safe fixes (lint, type, unit, build failures). It does NOT auto-fix E2E or security scan failures.

**Template versioning:** The `template-version: N` HTML comment in issue templates enables the `ticket-gate` agent to detect outdated templates and auto-synthesize missing sections without requiring manual upgrades. `ticket-gate` computes the current version from the **template directory only** and never reads `ticket-standards.md`, so the doc-to-template coupling lives entirely in `check-template-lockstep.sh`. That is why splitting the doc's rules onto `doc-rules-version` needed no change to the gate or the guard.

**`.full-review/` directory** is a runtime artifact created by `/full-review`. It persists state across interruptions so a review can be resumed, and its `round-<N>/` archives are the loop's only cross-round memory (prior reports feed trajectory and trip-wire computation), so deleting it ends the loop's history, not just a session. It is not part of the scaffold; add it to `.gitignore` in projects that run `/full-review`.

**`.claude/overnight/`** is the `working-overnight` runtime store (manifest, queue, decisions, report), gitignored here for the same reason `.full-review/` is: it is per-run state, not scaffold.

**`.superpowers/sdd/`** is the superpowers spec-driven-development runtime store (task briefs, per-task reports, progress files, review diffs). It carries its own `.gitignore` containing `*`, so it self-ignores and never appears in `git status`; do not add it to the root `.gitignore` and do not cite its contents as tracked history. The durable counterpart is `docs/superpowers/`, which **is** tracked.

**`temp/`** is a gitignored scratch folder (`temp/*` ignored, `.gitkeep` tracked). Use it for throwaway analysis output. Anything there is untracked by design, so never cite it as a source of truth or assume a later session can see it.

**`.claude/memory/MEMORY.md`** is the tracked, team-visible project memory index. Durable decisions and in-flight context belong there, one line per entry pointing at a sibling file. **`.claude/handoffs/`** holds dated session-resume notes written by the `closing-sessions` skill; both stores are what that skill targets when a session wraps up.

**`docs/superpowers/`** is the design paper trail: `specs/` (brainstormed designs) and `plans/` (implementation plans) for shipped components such as `closing-sessions`, `working-overnight`, and the overnight-guard hook. Read the relevant spec before redesigning one of those.

## Workflow

Changes land through a branch and a PR, never a direct push to main. Both range guards
(`check-version-bump.sh`, `check-plugin-version-bump.sh`) run only on `pull_request`, so a direct
push to main is gated by nothing except the local pre-commit hook.

1. Branch as `feat/<issue-number>-<slug>` or `fix/<slug>`.
2. Commit with a conventional-commit subject (`feat(...)`, `fix(review)`, `docs(...)`, `chore(...)`),
   bumping the `<name>-version` marker of every component the commit touches, plus the `plugin.json`
   semver of every plugin group it touches.
3. Run the structural and contract checks above.
4. Push the branch and open a PR into main.

```bash
git checkout -b feat/<N>-<slug>
git add <changed files>
git commit -m "feat(<scope>): <concise message>"
git push -u origin HEAD
gh pr create --fill
```

Do this at the end of every task without waiting to be asked.
