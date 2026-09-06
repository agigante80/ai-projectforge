---
name: hook-install-model
description: three install shapes (plugin, project-local, repo dogfooding) and three gate shapes in hooks.json; the no-dashes sentinel gates only one branch
metadata:
  type: project
---

Decided 2026-07-09 (PRs #27 to #36); the three-shapes correction landed 2026-09-06.

A hook reaches a project three ways, and this is the load-bearing distinction.

**Plugin-registered.** `plugins/<group>/hooks/hooks.json` activates the hook whenever
*that plugin group* is installed. Anchored to `${CLAUDE_PLUGIN_ROOT}`. Owns no user
config, so there is no wiring to drift, duplicate, or clobber. It requires
`/plugin install forge-kit-governance@forge-kit`; the quick-start installs
`forge-kit-adapt` alone, so it is NOT on by default.

**Project-local.** `.claude/hooks/<name>.py` plus a `settings.json` entry, written by
`forge-adapt`. Copying the script in IS the opt-in, so it needs no sentinel.

**Repo dogfooding (verified 2026-09-06).** forge-kit's own `.claude/settings.json` points
at `plugins/forge-kit-governance/hooks/block-dashes.py`: neither a `.claude/hooks/` copy
nor a path outside the project. `enforcement_enabled()` branches three times in order:
a `.claude/hooks/` script always enforces; otherwise a script resolving *under*
`CLAUDE_PROJECT_DIR` (falling back to the payload's `cwd`) also always enforces, opt-in
implied by living in the tree; only a script resolving *outside* the root is the plugin
copy, and that lone branch consults `.claude/no-dashes`. Consequence that reads as a bug
and is not one: **this repo has no `.claude/no-dashes` file and the guard is live anyway**
(confirmed by piping an em-dash payload through the script, exit 0 with a `deny`). Never
infer a hook's state from the sentinel's absence; run it.

## The governance hooks.json registers three hooks in three shapes

An earlier version of this memory said only `block-dashes` was plugin-registered. That
was wrong, and the correction matters because the shapes differ on purpose:

| Hook | Event | Gate |
|---|---|---|
| `block-dashes` | PreToolUse (5 tools) | `sh` tests a dedicated opt-in file, `.claude/no-dashes` |
| `overnight-guard` | PreToolUse (Bash) | `sh` tests `.claude/overnight/active.md`, the armed run's own manifest, so arming IS the opt-in and no second file can fall out of sync |
| `overnight-continue` | **Stop** | **no `sh` wrapper at all**; `python3` starts every time and gates internally on the same manifest |

`overnight-continue` is the deliberate exception to the shell-gate rule below: a Stop
hook fires once per session end rather than once per matched tool call, so the ~40ms
interpreter start is paid a handful of times a day and the wrapper is not worth its own
failure mode. Do not "unify" the three onto one shape.

## Decisions that must not be re-litigated

- **`block-legacy-host-push` must never be plugin-registered.** The only signal a
  `hooks.json` could gate on is `.forge.conf`, which `github-to-forgejo` writes at the
  *start* of a migration, while the hook belongs at *cutover*. Between them the skill
  supports a dual-remote / push-mirror window that depends on legacy pushes working.
  Installing it into the project IS the cutover signal. `scripts/test-hooks.py` asserts
  this so nobody "fixes" it.
- **A PreToolUse plugin hook is live in every project, so gate in the shell, not the
  interpreter.** Python pays ~40ms for `site` and stdlib imports before it can read its
  own gate. `hooks.json` runs `sh -c`, tests for the sentinel, and reaches `exec python3`
  only where the project opted in: 1.8ms dormant. Needs `sh` on PATH (Git Bash on
  Windows). The rule is scoped to per-tool-call events; see the Stop-hook exception above.
- **Exec form (`command` + `args`) with `${CLAUDE_PROJECT_DIR}`, never a relative path.**
  A relative path resolves only when cwd is the project root; from a subdirectory
  `python3` exits 2, which is the PreToolUse *deny* code, so every matched tool call is
  blocked with `can't open file`. It wedges the session rather than going quiet.

## Where the truth lives

`CLAUDE.md` (conventions), `plugins/forge-kit-governance/hooks/README.md` (both shapes,
but it predates the overnight hooks and documents only the `block-dashes` shape),
`plugins/forge-kit-adapt/skills/adapt/references/hooks.md` (install branch),
`scripts/test-hooks.py` (runs in CI; asserts all three registrations).

Related: [[generated-index-and-size-budget]], since the stale "only block-dashes" claim
is another instance of a hand-maintained inventory drifting from the tree.
