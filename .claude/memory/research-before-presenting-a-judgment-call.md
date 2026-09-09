---
name: research-before-presenting-a-judgment-call
description: "maintainer 2026-09-09: do not just cost my own options; check upstream docs and the reference implementation, then give pros, cons and a recommendation"
metadata:
  type: feedback
---

When a judgment call has to go to the maintainer, do not just cost the options I thought of. **Research external best practice and compare against prior art first**, then present pros, cons and a recommendation.

Asked to choose between three ways of closing a 14-word ratchet overage on 2026-09-09, the maintainer's answer was: "I'm not sure what the best option is here, research online, identify best practice, compare with superpower repository. Come back with pros cons and suggestions."

**Why:** all three options I had offered were internal trades priced against forge-kit's own invented metric. The research changed the question rather than the answer: the unit nobody outside this repo uses (words) was being defended on a file that is 63% over the unit Anthropic actually states (lines), so the grinding was optimising the wrong number. Two new tickets (#174, #175) came out of the research and would not have existed otherwise.

**How to apply:** before presenting a decision that turns on a threshold, a convention or a metric, check what the upstream docs say and what the reference implementation in `~/.claude/plugins/cache/claude-plugins-official/` actually does. Bring the comparison table. State the provenance of each number, since one plugin author's guidance is not a spec. Related: [[external-skill-size-guidance]], [[verify-against-installed-artifacts]].
