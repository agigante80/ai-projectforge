---
name: claude-plugin-cli-facts
description: "probed 2.1.265, re-probed 2.1.267: cache keyed by version, a broken dependency installs silently, details ignores preloads and needs --plugin-dir, plugin tag checks an entry version we do not keep"
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

**Re-probed 2.1.267 on 2026-09-10, closing #169 to #175.** Everything above holds, plus:

- **`marketplace add` takes no `-y`** in 2.1.267 (`unknown option '-y'`), and it needs an absolute path or `./path`; a bare `.` is rejected as an invalid source format.
- **An unresolvable dependency is caught by NOTHING.** `claude plugin validate` passes it (only the author warning), and `claude plugin install` then succeeds with no dependency line and no error. The CLI validates the SHAPE and never the TARGET. That gap is why `validate-plugins.sh` now resolves declared dependencies against `marketplace.json`.
- **`author` must be an object with a NON-EMPTY `name`**: a bare string gives `author: Invalid input`, `{"name": ""}` gives `author.name: Author name cannot be empty`, and `url` is optional.
- **`claude plugin details <name>` refuses unless the plugin is INSTALLED**, but `claude --plugin-dir <path> plugin details <name>` reports on a bare checkout with no install and no network. That is the only form usable from CI.
- **`plugin details` still does not charge preloads**, re-confirmed: a companion grown from 14 to 5,000 words moved its own on-invoke figure from `< 20` to `~7.2k` and left the declaring agent at `~40`. Its numbers round to two significant figures with a `< 20` floor, so nothing can ratchet on them.
- **`claude plugin tag <path> --dry-run`** validates plugin.json against the enclosing MARKETPLACE ENTRY's `version` field, and fires only where an entry HAS one (`✘ Version mismatch: plugin.json says "0.1.0" but ... plugins[0].version says "9.9.9"`). forge-kit's entries carry none by design, so the check is vacuous here and is a different invariant from `check-plugin-version-bump.sh`.
- **Probe safely with `CLAUDE_CONFIG_DIR=<tmpdir>`**: every plugin subcommand honours it, so an install probe never touches the real config. Verified afterwards that no probe marketplace reached `~/.claude`.
