# Session handoff: CLAUDE.md second accuracy pass

Date: 2026-09-06

## Summary

Ran `/init` against a repo that already had a mature `CLAUDE.md`, so the output was a
review rather than a rewrite (the second such pass; the first was 2026-09-04). Five gaps
found and fixed, all verified against the tree rather than against prose. Committed as
`50a27ca` and pushed onto the existing branch `docs/claude-md-workflow-accuracy`, which
means it landed inside the already-open **PR #100** rather than a new PR.

## Done this session

- **Verified the existing CLAUDE.md before changing it.** Ran all eight validation
  scripts (all pass, including the CI-less `test-closing-sessions-memory.py`), diffed the
  plugin inventory against `plugins/`, and read the three marker guards. Everything the
  2026-09-04 pass covered is still accurate.
- **Fixed five gaps in `CLAUDE.md`:**
  1. **The enforced path set.** The three marker guards share a path glob as well as a
     `ver_of` pipeline. Documented the set and, more usefully, what falls outside it:
     `skills/*/scripts/*.py` and non-`.sh` assets are unversioned by construction.
  2. **`memory.py` has zero enforcement, not just a CI gap.** It sits in `scripts/`,
     which no guard globs, so it carries no `<name>-version` marker either. It is the
     only shipped executable with no test gate, no marker bump, and no drift signal.
  3. **`hooks.json` wires three hooks in three shapes**, not one. `overnight-guard`
     gates on the run manifest rather than a dedicated sentinel; `overnight-continue`
     is a Stop hook with no `sh` wrapper at all, which read as a violation of the
     file's own absolute "gate in the shell" rule until the reason was written down.
  4. **Skills have a third subdirectory shape**, `scripts/`, used only by
     `closing-sessions`.
  5. **`.superpowers/sdd/`** carries its own `.gitignore` containing `*`, so it
     self-ignores and never appears in `git status`. Its tracked counterpart is
     `docs/superpowers/`.
  Also corrected the one-line CI description, which claimed the `Validate` workflow only
  checks structure and markers; it runs four contract suites and one advisory
  `continue-on-error` step as well.
- **Updated two memories** (see `.claude/memory/`): `hook-install-model` (its "only
  `block-dashes` is plugin-registered" claim was factually wrong, and its shell-gate rule
  was stated absolutely) and `generated-index-and-size-budget` (added the two-pass drift
  cadence as evidence).

## In progress (where we left off)

- **PR #100 now has two commits** (`15956d3` from 2026-09-04, `50a27ca` from today) but
  still carries the first commit's title, "docs(claude-md): the workflow says
  branch-and-PR, matching the guards", which now understates the content. **I offered to
  retitle it and rewrite the body to cover both passes, and the user closed the session
  before answering. Do not treat the offer as approved.**
- The memory writes above are uncommitted in the working tree, along with this note and
  the still-untracked `2026-09-04` note.

## Next steps

1. Decide on PR #100: retitle plus rewrite the body to cover both accuracy passes, then
   review and merge. Nothing blocks the merge.
2. Commit the two memory updates and both handoff notes. Precedent is a separate
   `chore(session):` commit on main (as `257ae5a` did), kept out of the docs-only PR diff.
3. Consider filing the two enforcement gaps this pass surfaced as tickets rather than
   leaving them as prose in CLAUDE.md, since the repo prefers mechanical enforcement:
   wire `test-closing-sessions-memory.py` into `validate.yml`, and widen the marker glob
   to cover `skills/*/scripts/*` (both currently documented as known blind spots).

## Decisions and why

- **Committed onto `docs/claude-md-workflow-accuracy` instead of a new branch.** It is
  literally the same topic, PR #100 has no review on it yet, and a second docs branch
  would either stack on an unmerged branch or fork from a main that lacks `15956d3`.
- **No marker or `plugin.json` bump.** Docs only; no component under `plugins/` was
  touched, so neither range guard applies. Same call the 2026-09-04 pass made.
- **Did not create a new memory file for the CLAUDE.md findings.** They now live in
  CLAUDE.md itself, and the skill's rule is to skip what is already captured there. Only
  the two facts that contradicted existing memories were written back.

## Open questions / blocked on

- The PR #100 retitle offer, above. Unanswered.
- **Carried over, still unanswered from 2026-09-04:** the user asked whether all plugins
  can be force-updated. There is no `--all` flag, but `claude plugin marketplace update`
  with no name refreshes every marketplace, and `claude plugin list --json | jq` feeds a
  per-plugin loop calling `claude plugin update "$id" -s "$scope" -y`. The offer to run
  that loop for `user`-scope plugins was never answered, so it was never run. Traps to
  keep: `-y` is mandatory without a TTY; `-s <scope>` must match, and `local`/`project`
  installs resolve against the current working directory, so `forge-kit-adapt`'s three
  `local` records (`AgentGate`, two `actual-mcp-server` checkouts, all at commit
  `0ea013e1`) only update if the command runs inside each repo; every update needs a
  restart to apply.
- **Carried over:** the `forge-kit-governance` plugin loaded in these sessions was pinned
  at 0.4.1 and was updated to 0.7.11 on 2026-09-04, but a restart is required before the
  new copy loads. Verify which version is actually live before trusting gate behaviour.

## Key context to reload

- `CLAUDE.md`, and the prior note `.claude/handoffs/2026-09-04-claude-md-accuracy-and-plugin-updates.md`.
- `.claude/memory/hook-install-model.md` and `.claude/memory/generated-index-and-size-budget.md`.
- PR: `gh pr view 100` (https://github.com/agigante80/forge-kit/pull/100), branch
  `docs/claude-md-workflow-accuracy`, head `50a27ca`.
- The three marker guards, if the glob-widening ticket gets picked up:
  `scripts/validate-plugins.sh` (a `find` expression), `scripts/check-version-bump.sh`
  and `.githooks/pre-commit` (a `grep -E` alternation). All three must change together.
- Validation suite: the command block near the top of `CLAUDE.md`. All eight scripts
  passed at `50a27ca`.
