---
name: bounded-review-loop-in-practice
description: Fired 4 times now; close out by fixing merge-blockers only and ticketing the rest, say so in the commit, and verify the reviewer's factual claims first
metadata:
  type: feedback
---

The bounded review loop from the global CLAUDE.md is not a theoretical safeguard here: across four PRs on 2026-08-28 the TRIP WIRE fired three times (PR #85 at round 3, #87 at round 2, #89 at round 3), each time because two consecutive rounds found defects inside the previous round's fixes.

The close-out pattern that worked, and that should be the default when the wire fires:

1. Fix ONLY the merge-blockers surgically (a rule contradicting its own step, a guarantee with no mechanism, a check that cannot fail).
2. File everything else as one consolidated ticket with the verified findings quoted, rather than iterating (this produced #86, #88, #94).
3. Say in the commit message that the loop stopped at the trip wire and why, so the next session does not read the remaining findings as neglect.

**Why:** prose state machines (ticket-gate.md, full-review.md) accumulate contradictions faster than a review loop converges on them; the third round consistently found defects introduced by the second. Iterating further removed value, exactly as the rule predicts.

**Fired a fourth time on 2026-09-07** (PR #128, forge-lib hardening), at round 3, and the close-out
pattern above held exactly: four findings fixed, three ticketed as #131, and the commit subject says
the loop stopped at the trip wire. Two things that instance added.

A round's report can be WRONG, and checking it is part of the round. Round 3 reported the config
leak as a regression introduced by the branch, citing the pre-#78 baseline as correct. Measured on
both versions, the baseline leaked identically on any call made outside a `$(...)` substitution; what
the branch changed was the reach, not the behaviour. The fix was unaffected, but shipping the
reviewer's framing would have put a false provenance claim in the header comment, which is the exact
class of defect the two previous rounds had already found there. Reproduce a report's factual claims
before you write them into the code.

The trip wire is not only about prose components. This one fired on a 250-line shell library, where
the recurring defect was four consecutive unfalsifiable tests rather than contradictory clauses.

**How to apply:** when a round's findings are mostly "this new clause contradicts an older clause it did not update", stop and ticket. That signal usually means the component is too large ([[generated-index-and-size-budget]] tracks the size half of this problem), not that the reviewer is being picky.
