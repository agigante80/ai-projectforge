---
name: generated-index-and-size-budget
description: "Four hand-maintained inventories and 5-7k-word components are the root cause behind repeated review findings; #95 then #96 then #97"
metadata:
  type: project
---

Two structural weaknesses sit behind a large share of the review findings this repo keeps producing, both tracked as tickets (#96, #97) and both borrowed as diagnoses from [[sister-project-vibe-coding-prompts]]:

1. **The component inventory is hand-maintained in four places** (CLAUDE.md plugin table, README tables, forge-adapt's `references/*.md` maps, plugin.json descriptions) and nothing checks it against the tree. It drifted four separate times in the 2026-08-28 session, caught only by review agents. The extractor already exists (`scripts/forge-adapt-catalogue.sh`); only the rendering half and a `--check` gate are missing.

2. **There is no size budget for components.** `adapt/SKILL.md` is 7,357 words and `ticket-gate.md` is 5,794, against a 1,600-word cap for a whole prompt in the sister project. At that size the same rule ends up stated in four places and updated in two, which is precisely the finding shape that fired the review trip wire three times.

**Why:** both convert a recurring human-caught defect class into something mechanical, which is the repo's own stated preference (mechanical enforcement over prose persuasion, recorded in the CLAUDE.md boundary paragraph).

**How to apply:** when a review finds "this table is stale" or "this rule is stated in N places", treat it as an instance of one of these two, not as an isolated fix. Land #96 before #97 (the index provides the visibility the budget needs), and fix #95 before either, or the generated index will publish `vnone` for the adapt skill.

## Evidence: the drift keeps arriving on a cadence

Running `/init` against this repo is a **review pass, not a rewrite**, and two consecutive passes each found multiple inaccuracies in a CLAUDE.md that reads as authoritative:

- **2026-09-04** (PR #100, commit `15956d3`): 4 gaps, including a Workflow section that told the reader to push straight to main while the validation section three screens up said both range guards are PR-only.
- **2026-09-06** (same PR, commit `50a27ca`): 5 more gaps, including a stale one-line CI description and an absolute "gate in the shell, not the interpreter" rule that `overnight-continue` had already violated on purpose. See [[hook-install-model]].

CLAUDE.md is itself a hand-maintained inventory, and it is 4,241 words, so it is an instance of **both** weaknesses at once. Treat a periodic `/init` accuracy pass as maintenance to schedule, not as evidence that the last pass was careless. The prose parts (hook shapes, enforcement reasoning) drift as readily as the tables, so a generated index would fix only half of it.
