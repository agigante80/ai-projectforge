---
name: external-skill-size-guidance
description: Anthropic says 500 LINES and references one level deep; superpowers says description under 500 chars and states when-to-use not what-it-does
metadata:
  type: reference
---

Anthropic states ONE number for a skill body, and it is not words:

> Keep `SKILL.md` under 500 lines. Move detailed reference material to separate files.

Plus a rule with a mechanical reason rather than a stylistic one:

> **Keep references one level deep from SKILL.md.** Agents may partially read files when they are referenced from other referenced files, using `head -100` to preview rather than reading whole, resulting in incomplete information.

The superpowers plugin (`writing-skills/SKILL.md`) adds frontmatter targets: max 1024 characters of frontmatter, description under 500 characters if possible, and the substantive rule that a description states **only when to use** a component and NEVER summarises its workflow. Treat those as a sane default rather than authority: that same file states "other skills: <500 words" and is itself 3,779 words.

**Calibration, measured 2026-09-09.** superpowers' largest skills are 568 and 679 lines, both over the 500-line tip. forge-kit's `adapt` is 816 lines (274 of them fenced code), `full-review` 729, `ticket-gate` 633. So the kit is worse than the reference implementation but in the same league, and the 500-line number is a tip that experienced authors exceed.

**The consequence for this repo's size budget:** it counts WORDS, a unit nobody outside forge-kit uses, and only the BODY, which is the on-invoke cost. The always-on cost is the description, and it is unmeasured (#174). The line count is free to compute and externally anchored, so it is the cheaper cross-check.

**Do not "fix" `ticket-gate`'s shape.** Agent to companion skill to `references/` looks like two hops and is not: the companion body is preloaded into the agent, so those references are one hop from content it already holds. See [[component-size-is-what-preloads]].

Sources: https://code.claude.com/docs/en/skills and superpowers `writing-skills/anthropic-best-practices.md`.
