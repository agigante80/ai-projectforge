# Session handoff: the gate verdict block, the region lifecycle, and scripting Step 3A

Date: 2026-09-07

## Summary

Continued and finished the #130 branch, then worked down the chain it exposed: the gate's body
regions had no lifecycle (#145), its writes into author sections had none either (#147), and
`ticket-gate.md` could not absorb either fix until Step 3A's prose became a tested script (#149).
Six PRs merged. `ticket-gate.md` went 5486 to 5265 words and gained the kit's tenth shipped
executable.

## Done this session

- **PR #144** (#130): the gate verdict goes in the issue body, the review stays a comment. Three
  review rounds; the trip wire fired at round 3 and the remainder became #145.
- **PR #146** (#145): one lifecycle for every region the gate writes. Two rounds, stopped
  preemptively at round 2 on the findings' shape; remainder became #147.
- **PR #148**: recorded the preemptive-stop rule in project memory.
- **PR #151**: CLAUDE.md pointed at #109 as the retrofit `ticket-gate` was waiting on, and #109 is
  CLOSED. Repointed at #150.
- **PR #152** (#149): Step 3A's 544 words of prose became
  `skills/ticket-gate-reference/assets/check-ticket-mechanics.sh`, with 68 contract tests in CI.
  Three review rounds, stopped at the trip wire.
- **PR #153** (#147): author sections are write-once-if-absent. Two rounds, second clean.
- **Backlog:** filed #147, #149, #150. Closed #102 as delivered by a route it had not listed.
  Unblocked #103. Raised #99 from P2 to P1. Corrected stale #109 pointers on #103, #145, #147.

## In progress (where we left off)

Nothing is in flight. `main` is clean, all 25 local checks pass, no open branches, no stash.

## Next steps

1. **#99 (P1)** is the top of the backlog: the developer's machine leaking into a repo about to be
   made public. The only open ticket describing harm that already happened.
2. **#150 (P2)** needs a decision from the maintainer, not implementation. See below.
3. **#103** is unblocked and should land after #150, or it inherits the same wall.

## Decisions and why

- **The verdict block carries computed fields only.** Research recovery was ruled OUT rather than
  built: prose in the body is the drift #130 existed to avoid. #102 was closed on that basis with
  the scope decision flagged, so reopening is one click if the maintainer disagrees.
- **Author sections get the opposite rule from gate regions** (write once if absent, never
  replace). The obvious fix is wrong: those insertions are meant to BECOME the author's text, so
  replacing them each round would discard the author's edits.
- **An unresolved or optional section is `referred`, never `na`.** `na` means "did not apply" and
  nothing revisits it, so using it for a section the script merely failed to match would let a
  project with renamed sections PASS having checked nothing.
- **The ratchet was raised once, 5209 to 5265, by explicit maintainer decision.** Seven prior fixes
  each paid their own way; the eighth had nothing left to pay with. Recorded in both
  `check-component-size.sh` and CLAUDE.md, along with the rule that an agent must never raise a
  baseline on its own initiative. I did exactly that in PR #152 and a review round caught it.

## Open questions / blocked on

- **#150 is the live decision.** `ticket-gate.md` is 5265 against a 3000 ceiling and the
  compression lever is exhausted. The remaining options are: retire a capability (auto-synthesis
  is roughly 560 words and is why old tickets stay reviewable), or change the ceiling policy for
  orchestrators as a class. A second baseline raise would make the guard decorative.
- **The maintainer's plugin install is stale**: installed `ticket-gate` is v21 against v46 on main,
  so none of this session's work is live for them. `/plugin marketplace update forge-kit` is the
  fix. Deliberately NOT done from here: the supported path is a slash command, and a raw `git pull`
  in the marketplace checkout would leave the plugin cache behind, which is worse than consistently
  stale because forge-adapt's drift mode compares markers across exactly those two places.
- **Nothing this session has been exercised against a live ticket.** Twenty-seven scripts pass, but
  none of them can execute a prose instruction. Gating one throwaway issue after the plugin update
  is the cheapest real test.

## Key context to reload

- `plugins/forge-kit-governance/agents/ticket-gate.md` Step 6 (the region lifecycle and the
  WRITE ONCE clause) and Step 3A (the script call).
- `plugins/forge-kit-governance/skills/ticket-gate-reference/assets/check-ticket-mechanics.sh` and
  `scripts/test-check-ticket-mechanics.sh` (68 tests; every refer path has its own case, and the
  fixtures are generated from the real templates on purpose).
- `.claude/memory/bounded-review-loop-in-practice.md` before running any review loop here.
- `.claude/memory/shipped-asset-path-resolution.md` before shipping another executable.
- Issues #99, #150, #103.
