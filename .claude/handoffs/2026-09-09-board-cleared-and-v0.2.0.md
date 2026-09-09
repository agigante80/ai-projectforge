# Handoff, 2026-09-09: the board is empty and v0.2.0 is out

## Where things stand

- **Zero open issues.** Four phases closed today; none is open (Backlog aside).
- `main` and `develop` are identical, CI green, `v0.2.0` tagged and released.
- The next session's first job is **deciding what the next phase is**, not pulling a ticket. There
  is nothing to pull.

## What shipped after the first overnight wind-down

#150 (orchestrator budget), #103 (round table + lens-contract guard), #88 (overnight loop honours
the iteration contract), #129 (`decision-brief` skill). Full detail in
`.claude/overnight/report.md`, which covers both sittings.

## Three things worth carrying, none of them obvious from the diff

**The metric was measuring the wrong thing for weeks.** An agent PRELOADS every skill named in its
`skills:` frontmatter, so `ticket-gate` was loading 6355 words while the guard reported 5259, and
#109's split had moved 308 words from one preloaded file to another while reporting a reduction.
Anything reasoning about component size before today was reasoning from a false number.

**The ratchet is now the only thing holding `ticket-gate`.** At 5778 against a 6000 orchestrator
ceiling it has headroom for the first time. That is the policy working as intended, and it also
means the next growth will not be caught by the ceiling; it will be caught by the ratchet or not at
all.

**Converting prose to a tested script was used five times this week and it is not infinite.** Each
time the rule was mechanical. The moment it is applied to a judgment rule, it moves prose into a
file that cannot test it, which is worse than leaving it. #150's plan named this as a way the phase
could fail; it did not, but only because every candidate was deterministic.

## Open questions for you, none blocking

- Whether the four unreleased tickets warrant their own tag or ride the next batch. I left them in
  `## Unreleased` and said why in the report.
- `decision-brief` and #166's install behaviour are both prose that cannot be exercised here. The
  first real `forge-adapt` run against another project is the only thing that will prove them.
