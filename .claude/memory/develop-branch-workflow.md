---
name: develop-branch-workflow
description: Work lands on develop and merges to main with no PRs (2026-09-08); the range guards are pull_request-only, so pre-push is now the only thing enforcing them
metadata:
  type: feedback
---

Maintainer decision, 2026-09-08: **work on `develop`, merge to `main` when green, no pull
requests, and do not wait for confirmation to commit or merge.** This replaces the branch-plus-PR
flow CLAUDE.md described until then.

**Why:** the PR was pure ceremony for a single-maintainer repo. Every gate that mattered already
ran locally, and the review round happened in conversation rather than on the PR.

**How to apply:** commit to `develop`, `git push origin develop`, then `git checkout main && git
merge --ff-only develop && git push origin main`. Watch the `Validate` run on main with `gh run
watch` rather than assuming it passed: there is no PR check standing between a bad commit and
main, so CI is a report after the fact rather than a gate.

**Two consequences, and the first one was missed when this was written.** `validate.yml`
triggered on `pull_request` and `push: [main]` only, so with no PRs there was **no CI on develop
at all** and every check ran for the first time after the merge to main. Fixed by adding `develop`
to the push branches; a code review found it, not the workflow change itself.

The second still stands. Both range guards (`check-version-bump.sh`,
`check-plugin-version-bump.sh`) are wired `pull_request`-only in `validate.yml`, so they run in CI
on NO path. `.githooks/pre-push` is the only thing enforcing them, which
makes `git config core.hooksPath .githooks` a requirement and `--no-verify` a decision rather than
a shortcut. Issue #158 tracks restoring the server-side half. Until it lands, never assume a
version bump was checked by anything except the local hook.

Related: [[bounded-review-loop-in-practice]], [[generated-index-and-size-budget]].
