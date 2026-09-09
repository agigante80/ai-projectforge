<!-- Memory index. Each line: - [Title](file.md) - one-line description (~150 chars max) -->
<!-- Add entries here as Claude Code builds up project memory across conversations. -->

- [Hook install model](hook-install-model.md) - three install shapes (plugin, project-local, repo dogfooding) and three gate shapes in hooks.json; the sentinel gates only ONE branch
- [Sister project: vibe-coding-prompts](sister-project-vibe-coding-prompts.md) - Same author's prompt library; shares forge-kit's version-gate DNA and has mechanisms worth borrowing; cross-review 2026-08-28 filed tickets both ways
- [Recovering findings from a dead code-review fork](code-review-fork-recovery.md) - Subagent transcripts under subagents/agent-*.jsonl hold complete reports; recover rather than re-run, and check which SHA was reviewed
- [The review-loop trip wire in practice](bounded-review-loop-in-practice.md) - Fired 6 times plus a preemptive stop; on prose the loop injects defects and on code it converges, so ask whether a TEST can hold the fix down
- [Inventory drift and component size](generated-index-and-size-budget.md) - Both #96 and #97 shipped; the ratchet paid for seven fixes then exhausted, so #150 needs a capability or policy decision, not more compression
- [Downstream tickets quote adapted copies](downstream-tickets-quote-adapted-copies.md) - A ticket filed from a forge-adapt install may quote ITS adapted text as forge-kit canon; #101 did, and the quote was in no branch of the history
- [gh CLI cannot read /tmp (snap confinement)](gh-cli-cannot-read-tmp.md) - Snap-confined gh has a private /tmp, so --body-file from the scratchpad fails; stage issue bodies in the repo's gitignored temp/ instead
- [Mutation harness quoting](mutation-harness-quoting.md) - apply shell mutants with python + an assert; a mutant that fails to apply reads exactly like one that survived
- [Shipped assets resolve by search, not by CLAUDE_PLUGIN_ROOT](shipped-asset-path-resolution.md) - An agent's Bash never gets CLAUDE_PLUGIN_ROOT; a missing asset degrades silently, and forge-adapt copies assets only because the write step says so
- [Work on develop, merge to main, no PRs](develop-branch-workflow.md) - maintainer decision 2026-09-08; the range guards are pull_request-only so pre-push is now the only enforcement (#158)
- [Component size is what an agent PRELOADS](component-size-is-what-preloads.md) - skills: frontmatter injects full bodies; references/ do not; the metric was wrong until #150
- [What the claude plugin CLI actually does](claude-plugin-cli-facts.md) - probed 2.1.265 and 2.1.267: cache keyed by version, a broken dependency installs silently, details ignores preloads and needs --plugin-dir, plugin tag checks an entry version we do not keep
- [The external numbers for skill size, and how forge-kit compares](external-skill-size-guidance.md) - Anthropic says 500 LINES and references one level deep; superpowers says description under 500 chars and states when-to-use not what-it-does
- [Research external practice before handing over a judgment call](research-before-presenting-a-judgment-call.md) - maintainer 2026-09-09: do not just cost my own options; check upstream docs and the reference implementation, then give pros, cons and a recommendation
