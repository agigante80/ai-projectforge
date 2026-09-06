---
name: gh-cli-cannot-read-tmp
description: Snap-confined gh has a private /tmp, so --body-file from the scratchpad fails; stage issue bodies in the repo's gitignored temp/ instead
metadata:
  type: project
---

The `gh` CLI on this machine is snap confined, so it **cannot read files under `/tmp`**, including the session scratchpad. `gh issue create --body-file /tmp/...` fails with `no such file or directory` for a file that `ls` and `cat` both show.

Snap gives the process a private `/tmp` namespace. The file is real; gh is looking in a different `/tmp`.

**Why:** it costs two failed tool calls and reads like a race or a permissions problem, because every other tool in the session can see the file. Nothing in the error names snap.

**How to apply:** write issue and PR body files into the repo's gitignored `temp/` directory instead (`temp/*` is ignored, `.gitkeep` tracked, exactly the throwaway-output use CLAUDE.md describes), then `gh ... --body-file temp/<name>.md` and delete them afterwards. Verified working 2026-09-06 across roughly a dozen `gh issue create`, `edit`, and `comment` calls during the backlog triage. Inline `--body` also works but is painful for long markdown and puts the whole body through the shell, where the `block-dashes` hook then scans it.
