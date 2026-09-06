# Session handoff: CLAUDE.md third accuracy pass, then a full backlog triage

Date: 2026-09-06

## Summary

Two halves. First a third `/init` accuracy pass on `CLAUDE.md` (same day as the second),
which found 3 more gaps. Then the user asked whether the open tickets were all valid and
authorised rewriting or closing any of them, which turned into a full backlog triage:
2 closed, 4 rewritten, 3 filed, priorities and dependency wiring applied throughout.

## Done this session

### Half 1: CLAUDE.md third pass (commits `da12cc9`, `551c36a`, pushed to PR #100)

Verified first: all eight validation scripts pass at `50a27ca`, and the plugin inventory
matches `plugins/` exactly. Then fixed 3 gaps:

1. **CI runs five contract suites, not four.** Three cover shipped executables; two cover
   the repo's own guards (`test-template-lockstep.sh`, `test-check-plugin-version-bump.sh`)
   and both run unconditionally even though one of the guards they test is PR only.
2. **`enforcement_enabled()` branches three times, not two.** The file described a plugin
   versus project-local split gated by `.claude/no-dashes`. This repo's own
   `.claude/settings.json` points at `plugins/forge-kit-governance/hooks/block-dashes.py`,
   which is neither, and takes a third branch: under `CLAUDE_PROJECT_DIR`, opt-in implied.
   **There is no `.claude/no-dashes` file here and the guard is live anyway**, verified by
   piping an em-dash payload through the script (exit 0, `permissionDecision: deny`). The
   old text invited a reader to add a redundant sentinel or call the wiring broken.
   Written back to [[hook-install-model]].
3. **`overnight-guard` matches `Bash` alone**, where `block-dashes` matches five tools.

`551c36a` also committed the two previously untracked handoff notes (09-04, 09-06) and the
memory updates the earlier session left in the working tree.

### Half 2: backlog triage

Read all 14 open tickets in full including comments, and verified their claims against the
tree rather than accepting them. Verified live: #95 (both halves reproduce), #98 (unpinned
checkout, zero `concurrency`, zero `timeout-minutes`), #97 (word counts exact to the word),
#76, #84.

**Closed 2**, each with a comment recording the decision:

- **#20** (portability spike): decided hybrid, which #69 had already framed and #81's audit
  measured (7 portable, 5 path-bound, 24 Claude-native). Remaining experiment needs a
  non-Claude harness nobody has committed to.
- **#21** (multi-channel): closed on its own stated criterion, verbatim from its body.
  Its extractable half shipped as #79.

**Rewrote 4:**

- **#101**: its central quotation is in no file and no branch of this repo's history. Posted
  a public correction comment with the greps, then rewrote the body onto the jurisdiction
  argument alone, widened scope from 3 sites to the real 8 files, marked it blocked by #94.
  See [[downstream-tickets-quote-adapted-copies]].
- **#94**: split. It keeps the maintainer decision (doc fork, overloaded `template-version`
  integer, plus the two Precedence findings). Mechanism halves became #102 and #103.
- **#99**: folded its addendum's allowlist-of-roots rule into the design as rule B, where an
  implementer reads it, since the body's original design provably missed the second leak.
  Added the verified note that forge-kit's own tree is clean.
- Bodies of #76, #77, #78, #84, #88, #96, #97 gained a blocked-by or builds-on line only.

**Filed 3:** #102 (round state block), #103 (re-run model plus lens version handshake),
#104 (label taxonomy never applied).

**Created 18 labels** from `.github/labels.yml` and applied priorities across the backlog.

## In progress (where we left off)

- **Nothing is half-finished.** `git status` is clean and every ticket action completed.
- The memory writes and this handoff note are uncommitted in the working tree.

## Next steps

1. **Decide PR #100.** It now carries four commits (`15956d3`, `50a27ca`, `da12cc9`,
   `551c36a`) and still has the first commit's title, which badly understates it. Retitle,
   rewrite the body to cover three accuracy passes, merge. Nothing blocks it.
2. Commit the memory updates plus this note. Precedent is a separate `chore(session):`
   commit; `551c36a` put one on the docs branch this time rather than leaving them loose.
3. **Start on the P1s**, in dependency order: **#95** first (it blocks #96 and is a live
   rotten-green assertion sitting in CI), then **#96**, then **#98**. **#94** is P1 but is a
   maintainer decision, not implementation work, and it blocks #101 and #102.
4. #103 is independent and startable at any time.

## Decisions and why

- **Closed #20 and #21 rather than leaving them parked.** Both contained their own closure
  criteria and both criteria were met. Two months open with no movement was the symptom.
- **Rewrote #101 rather than closing it.** The false citation killed one of its two problems;
  the jurisdiction argument is strong and survives entirely. A public correction comment went
  up first so the record shows what changed and why, since the original text was public.
- **Split #94 rather than editing it.** Its own acceptance criteria conceded that item 5
  blocks items 1 to 4, so it could never close as a unit.
- **Created the labels immediately, then filed #104 for the mechanism.** The immediate gap
  was one command; the durable defect is that nothing applies or checks `labels.yml`.
- **Recommended against wiring #104's `--check` into CI as a hard gate**: it needs a token to
  read labels, and a required check that needs a secret is a check that gets disabled.

## Open questions / blocked on

- **PR #100 retitle.** Offered in the previous session, offered again, still unanswered.
- **#94 is a maintainer decision** and blocks #101 and #102. Two questions: where the six
  gate-only bars live, and whether to split `template-version` into a separate
  `doc-rules-version` (option a), declare prose-only doc changes bumpless (option b), or
  admit the fork (option c). Recommendation not taken; this one is genuinely the user's.
- **Carried, still unanswered:** the plugin force-update loop
  (`claude plugin list --json | jq` feeding `claude plugin update "$id" -s "$scope" -y`).
  `-y` is mandatory without a TTY, `-s <scope>` must match, and `local`/`project` installs
  resolve against the current working directory.
- **Resolved this session:** the carried question about which `forge-kit-governance` version
  is live. The `closing-sessions` skill loaded from
  `~/.claude/plugins/cache/forge-kit/forge-kit-governance/0.7.11/`, so **0.7.11 is live**;
  the restart happened. The old 0.4.1 pin is gone.

## Key context to reload

- `CLAUDE.md`, and the two prior notes in `.claude/handoffs/` (09-04, 09-06 second pass).
- `.claude/memory/`: [[hook-install-model]], [[generated-index-and-size-budget]],
  [[downstream-tickets-quote-adapted-copies]], [[gh-cli-cannot-read-tmp]].
- `gh pr view 100`, branch `docs/claude-md-workflow-accuracy`, head `551c36a`.
- `gh issue list --state open` now shows 15 tickets, all prioritised, each opening with a
  blocked-by or builds-on line.
- **Tooling trap that will bite immediately:** `gh` is snap confined and cannot read `/tmp`,
  so stage issue and PR bodies in the repo's gitignored `temp/` and pass
  `--body-file temp/<name>.md`. See [[gh-cli-cannot-read-tmp]].
- The validation suite is the command block near the top of `CLAUDE.md`. All eight scripts
  passed at `50a27ca` and again after the `da12cc9` edits.
