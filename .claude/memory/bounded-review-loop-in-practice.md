---
name: bounded-review-loop-in-practice
description: Fired 6 times plus a preemptive stop; on prose the loop injects defects and on code it converges, so ask whether a TEST can hold the fix down
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

**Fired a fifth time on 2026-09-07** (PR #133, the agent companion-skill resolver), at round 3, and
it added the most useful diagnostic yet: **when three consecutive rounds each find a different face
of the same defect, the defect is duplication, and the fix is to unify rather than to patch.**

`parse` and the rewrite branch of a small awk script each normalised a YAML list item their own way.
Round 1 found the rewriter never unquoting. Round 2 found my fix unquoting before trimming, so a
trailing space left a stray quote: the same malformed output through a different door. Round 3 found
the reader tolerating a comment the classifier still rejected. Three rounds, three symptoms, one
cause: the same rule implemented twice and drifting whenever either copy was touched. Once they
shared a single `norm()`, that whole class stopped.

Two of round 3's findings were also regressions from my own earlier fixes, including one that
falsified a claim in the previous commit message (an atomicity fix that was not atomic, because the
temp file was in TMPDIR rather than beside the target). Fix those in the close-out even when they
are low severity: a false claim left standing in the history is worse than the bug it describes.

**Fired a sixth time on 2026-09-07** (PR #144, the gate-verdict body block), at round 3, and it
named the mechanism behind the injection rather than another instance of it: **a round that fixes
a false claim tends to fix it against the one counterexample the review supplied, and ships a claim
that is still false.**

Round 1 wrote "this step is the body's only writer." Round 2 found it false, and corrected it to
"the only writer after the Step 1 fetch," naming the single writer the report had named. Round 3
found a third writer, so the corrected claim was false for the same reason as the original. Two
rounds asserted an invariant about a set without enumerating the set. The fix that held was to
count: three steps write the body, each named. When a review falsifies a universal claim, the
repair is to enumerate the domain, not to subtract the counterexample you were handed.

The size-budget close-out worked a third consecutive time and is now the reliable way to pay for a
fix in an exempt component: the unification a round forces always exposes duplication worth more
words than the fix costs. Three rounds ratcheted 5495 to 5492 while ADDING content, each time out
of a rule that turned out to be stated twice (PASS defined in both Step 6 and Rules, the thin check
stating its purpose three times, Step 5 restating the block rationale Step 6 owned).

One process note. Two guards caught the same NUMBER recorded in a second and third place (the
ratchet baseline lives in the script, in CLAUDE.md prose, and in the generated index). That is the
guard set doing precisely its job, and it is worth expecting: lowering a ratchet is a three-file
edit, not a one-file edit.

**Stopped preemptively at round 2 on 2026-09-07** (PR #146, the body-region lifecycle), which is
the first time the "mostly contradictions" signal was used to END a loop rather than to explain one
after the fact. Round 2 found defects in round 1's fixes, which ARMS the wire without firing it,
and the contract would have permitted a round 3. Nine of its eleven findings were "this new clause
contradicts an older clause it did not update", so the loop stopped there and the remainder became
#147. Treat the shape of the findings as sufficient on its own; waiting for the wire's second
consecutive round just buys one more round of injection.

That PR also produced the cleanest example yet of the right way to pay for a fix: **delete the
rules that cannot execute rather than patch them.** Two survived rounds of review because an
unexecutable instruction reads as covered: Step 1.5 re-triggering on a body that "shrank" with no
prior body persisted anywhere, and Step 4 marking report sections "carried forward" when the prior
review lives in a comment nothing can read. Deleting the second paid for the entire round. An
instruction that cannot run is worse than an absent one, because absence gets noticed.

**Seventh and eighth firings, 2026-09-07** (PRs #152 and #153, the Step 3A script), and together
they draw the line this note was missing: **the loop behaves differently on prose than on code,
and the trip wire should be read differently in each case.**

On PROSE the loop injects. PR #146 stopped at round 2 with nine of eleven findings being "this new
clause contradicts an older clause it did not update", and each round's fix created the next
round's defect. On CODE it converges. PR #152 ran three rounds on a new shell asset, each found
real fail-opens, and each fix is now pinned by a mutant-killed test, so the same defect cannot
return. Same loop, opposite verdicts. The distinguishing question is whether a TEST can hold the
fix down: if it can, keep going; if the only thing holding it is prose, stop and ticket.

That instance also produced the strongest single diagnostic yet, and it is about claims rather than
code: **a universal claim asserted without enumerating what it quantifies over will be false, and
the repair will be false the same way.** "This step is the body's only writer" was wrong; the fix
that named the one other writer the review had supplied was wrong again; a third writer existed.
"No write touches author text" was wrong in a new place. The repair that held was to COUNT, not to
subtract the counterexample handed to you.

Two more from the same pair of PRs. **Delete rules that cannot execute rather than patching them**:
an instruction referring to state nothing persists reads as covered rather than missing, so it
survives review after review (a thin-check comparing against a body no one stores, a carry-forward
rule needing a comment nothing can read). Deleting one paid for an entire round under the size
ratchet. And **a fixture written by a copy of the parser it tests agrees with the parser's bugs**:
the independent oracle that replaced it disagreed on its first run, and the parser was right, which
is the oracle doing its job in the direction nobody expects.

**How to apply:** when a round's findings are mostly "this new clause contradicts an older clause it did not update", stop and ticket. That signal usually means the component is too large ([[generated-index-and-size-budget]] tracks the size half of this problem), not that the reviewer is being picky.
