# Session handoff: the plugin-CLI phase, and one pending ratchet decision

Date: 2026-09-10

## Summary

Cleared the whole board (83 issues, all closed), released v0.2.0, then probed the installed Claude
Code CLI and found enough divergence between what it now ships and what this kit hand-rolled to
open a new phase with seven tickets. One decision is waiting on the maintainer and blocks exactly
one acceptance criterion.

## Done this session

- **#150, #103, #88, #129 shipped**, closing the phases *The ticket-gate size decision* and *What
  the loop hands back to the human*. `ticket-gate` went 6355 to 5778 words with no capability
  dropped; `decision-brief` is a new skill; the overnight loop now chains rounds with `--since` and
  defers on the trip wire.
- **v0.2.0 released.** The CHANGELOG had gone stale at roughly #124, so 32 entries were written
  first. 72 commits, 47 issues, three days.
- **Phase *What Claude Code now ships itself* opened** with its plan, seven tickets filed
  (#169 to #175).
- **`scripts/forge-adapt-marketplace-status.sh`** landed with 21 contract tests, 6 mutants killed,
  wired into CI. CLAUDE.md's cache-path claim corrected from `<sha>` to `<version>`.

## In progress (where we left off)

**#172 is 14 words from complete.** The script and its tests are merged; the line that wires it
into `drift` is not, because `adapt/SKILL.md` sits exactly on its 7300-word ratchet. The pending
change is saved as `.claude/handoffs/2026-09-10-adapt-marketplace-line.patch` and applies cleanly:

```bash
git apply .claude/handoffs/2026-09-10-adapt-marketplace-line.patch
```

It already includes 30 words of payment (a genuine #64 restatement that #167 moved into
`forge-adapt-drift-status.sh`) and my own addition compressed 47 words to 24.

## Next steps

1. **Answer the ratchet question** (see Open questions). Applying the patch needs the baseline at
   7314 in `scripts/check-component-size.sh` AND in CLAUDE.md, or CI fails.
2. Then work the phase. Suggested order from the plan: #172 to completion, then #169 and #173
   (which share a deliverable: `scripts/test-validate-plugins.sh` does not exist yet), then #170,
   #171, #174, #175.
3. **Update the maintainer's own install**, which is four minor versions behind and was the origin
   of #172: `claude plugin marketplace update forge-kit && claude plugin update forge-kit-governance`.

## Decisions and why

- **`stale`, not `behind`.** `git ls-remote` establishes that the checkout and the remote DIFFER;
  deciding behind-versus-diverged needs the remote objects, which needs a fetch, which is a WRITE
  into a directory Claude Code owns. The word says what was measured. The ticket's own GWT said
  "behind"; the probe said that word could not be earned.
- **The probes came before any code**, because four of the seven tickets could have ended as
  documentation-only. Two answers changed a ticket: `dependencies` IS honoured (so #169 is real
  work), and `plugin details` does NOT charge preloads (so #170 cannot be a straight adoption).
- **No second release tag.** v0.2.0 was cut this session; the four tickets that followed sit in
  `## Unreleased`. A tag names the state of the marketplace at a point in time and two within the
  hour tell a reader nothing.

## Open questions / blocked on

- **The 14-word ratchet raise on `adapt`.** Options as costed: raise 7300 to 7314 (the #147
  precedent, second raise ever); ship without the drift wiring and leave #172's criterion 3 unmet;
  or extract the `refresh <name>` asset rules into a tested script first, freeing about 60 words.
  My recommendation after research: raise it, and file a ticket to move `adapt`'s 274 fenced-code
  lines into `references/`, because the word ratchet defends a unit nobody outside this repo uses
  while the file is 63% over the unit Anthropic does state.
- **Not this repo's business, but worth acting on:** there is a plaintext Forgejo token in
  `~/.claude/settings.json` under `env`, which is global and therefore present in every project.
  Deliberately not ticketed: a public tracker is the wrong place to record a private credential.

## Key context to reload

- `docs/plans/what-claude-code-ships.md` (the phase plan, premortem included)
- `.claude/memory/claude-plugin-cli-facts.md` and `external-skill-size-guidance.md` (this session's
  probe results, so nobody re-runs them)
- `scripts/forge-adapt-marketplace-status.sh` header (why `stale` and why it never writes)
- `gh issue view 172` and `gh issue view 174` (the two with the sharpest findings)
