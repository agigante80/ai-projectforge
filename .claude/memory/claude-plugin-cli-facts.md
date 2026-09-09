---
name: claude-plugin-cli-facts
description: "probed 2.1.265: cache keyed by version not sha, dependencies resolve but fail silently, details does not charge preloads, nothing auto-updates"
metadata:
  type: reference
---

Probed against the installed CLI 2.1.265 on 2026-09-09. These are facts about the harness, not about this repo, so they outlive any ticket here.

**The plugin cache leaf is the SEMVER, not a commit sha.** `~/.claude/plugins/cache/<marketplace>/<plugin>/<version>/`, and versions sit side by side (`0.4.1/` and `0.7.11/`). CLAUDE.md said sha for months. The **marketplace checkout** (`~/.claude/plugins/marketplaces/<name>`) is by contrast an ordinary git clone with an `origin` remote, so it is the one of the two that can be compared against a remote.

**Nothing auto-updates.** `claude plugin marketplace update [name]` refreshes the checkout, `claude plugin update <plugin>` the installed copy. There is no `autoUpdate` settings key and no daemon. Every plugin subcommand takes `-y`, documented as required when stdout is not a TTY, which is a scripting affordance rather than automatic behaviour.

**`plugin.json` accepts `dependencies`, and the installer honours it.** An ARRAY of `plugin@marketplace` strings (an object of version ranges is rejected). Installing a dependent prints `+ 1 dependency: <name>` and enables both; `claude plugin prune` finds the orphan after an uninstall. **But an unresolvable dependency installs silently and `claude plugin validate` does not catch it.**

**`author` must be an object** with a `name` (and optional `url`). A bare string fails validation. `userConfig` entries need a `title`.

**`claude plugin details <name>` reports token cost in two columns**, always-on and on-invoke, and it does NOT charge an agent for its preloaded companion skills: a companion grown from 210 to 6k tokens left the declaring agent at under 20. So it disagrees with what [[component-size-is-what-preloads]] established, and it cannot be used as a drop-in for that measurement.

**`claude plugin tag <path>`** creates a `{name}--v{version}` git tag, validating that `plugin.json` and the enclosing marketplace entry agree. It needs a path per plugin; there is no bulk mode.

Related: [[verify-against-installed-artifacts]], which is why every line above was probed rather than read.
