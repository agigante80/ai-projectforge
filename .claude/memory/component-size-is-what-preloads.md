# Component size is what an agent PRELOADS, not what is in its file

Verified against the installed Claude Code (2.1.263), issue #150: the subagent spawn path renders
every skill named in an agent's `skills:` frontmatter and pushes it into the message list BEFORE the
run starts. A companion skill is not somewhere else; it is in the same context.

Consequences that cost real work to learn:

- The size guard measured one file for weeks. `ticket-gate` was loading **6355** words while the
  guard reported 5259, so every option in #150 was costed against a false number.
- #109's `references/` split therefore reduced NOTHING: it moved 308 words from one preloaded file
  into another and reported a win.
- **`references/` under a skill are NOT preloaded.** They are read on demand, which is what makes
  the two-hop split real: moving read-once artifacts out of a companion SKILL.md into its
  `references/` took 582 words out of every run at no cost in capability.

So: to shrink an agent, move read-once material two hops (agent -> companion skill -> references),
not one. And never trust a size number that was taken from a single file.

**Corroborated and contradicted, 2026-09-09.** `claude plugin details` reports token cost per
component and does NOT charge an agent for its preloaded companions: a companion grown from 210 to
6k tokens left the declaring agent at under 20. So the CLI disagrees with the finding above and
cannot be used as a drop-in for this measurement (#170). The finding above was verified against
2.1.263 by probing the spawn path and has NOT been re-verified against 2.1.265; if it ever stops
holding, this guard becomes the wrong one and the CLI's number becomes right.

Related: [[claude-plugin-cli-facts]], [[external-skill-size-guidance]], [[verify-against-installed-artifacts]] - this was found by probing the binary, not by
reading docs, which is the only reason it was found at all.
