#!/usr/bin/env bash
# Contract test for check-template-dir-order.sh (issue #77).
#
# THE DEFECT. The template-directory resolution order is a five-entry, HOST-grouped list that five
# separate sites must agree on: check-template-lockstep.sh twice (its header comment and
# resolve_dir), ticket-gate.md, dep-auditor.md, and adapt/SKILL.md twice. The #61/#74 review found the copies had
# already diverged, case-grouped against host-grouped, before that PR merged, and only a review
# finding re-aligned them. Two of the sites are prose an LLM executor will paraphrase.
#
# WHY A GUARD AND NOT A SHARED SCRIPT. The ticket proposed extracting one implementation, and its
# own trade-off concedes that the prose sites must keep an inline fallback, so the duplication
# would shrink from four sites to two rather than to one. This repo already faced the identical
# shape with the enforced path set (#112), where the catalogue must use globs while the others use
# an ERE, and chose a guard (test-component-paths.sh) precisely because one implementation was
# impossible. A guard covers all five sites; a shared script would have covered two.
set -uo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
SCRIPT="$HERE/check-template-dir-order.sh"
T="$(mktemp -d)"; trap 'rm -rf "$T"' EXIT

pass=0
fail=0
ok()  { echo "  ok: $1"; pass=$((pass + 1)); }
bad() { echo "  FAIL: $1"; fail=$((fail + 1)); }
mk() { mkdir -p "$(dirname "$1")"; cat > "$1"; }

CANON='.forgejo/ISSUE_TEMPLATE .forgejo/issue_template .gitea/ISSUE_TEMPLATE .gitea/issue_template .github/ISSUE_TEMPLATE'

# --- all sites agreeing ------------------------------------------------------------------------
mk "$T/ok/a.sh" <<M
  for d in $CANON; do :; done
M
mk "$T/ok/b.md" <<M
TPL_DIR=\$(for d in $CANON; do :; done)
M
bash "$SCRIPT" "$T/ok" >/dev/null 2>&1
[ $? -eq 0 ] && ok "sites that agree pass" || bad "agreeing sites pass"

# --- a REORDERED copy is the exact defect #61 shipped -------------------------------------------
# Case-grouped instead of host-grouped: both ISSUE_TEMPLATE dirs first, then both lowercase. A
# migrated repo that kept a stale .github dir then gets the stale one checked, not its live one.
mk "$T/reordered/a.sh" <<M
  for d in $CANON; do :; done
M
mk "$T/reordered/b.md" <<'M'
TPL_DIR=$(for d in .forgejo/ISSUE_TEMPLATE .gitea/ISSUE_TEMPLATE .github/ISSUE_TEMPLATE .forgejo/issue_template .gitea/issue_template; do :; done)
M
out=$(bash "$SCRIPT" "$T/reordered" 2>&1); rc=$?
# EXACTLY 1. "Non-zero" would accept exit 2, the unreadable-root status, so a fixture path typo
# would read as a passing divergence test.
[ "$rc" -eq 1 ] && ok "a case-grouped copy fails against the host-grouped canon" || bad "reordered copy exits 1 (got $rc)"
case "$out" in *b.md*) ok "and it names the disagreeing file" ;;
               *) bad "names the file (got: $out)" ;; esac

# --- a DROPPED legacy entry leaves those repos silently unguarded --------------------------------
mk "$T/dropped/a.sh" <<M
  for d in $CANON; do :; done
M
mk "$T/dropped/b.md" <<'M'
TPL_DIR=$(for d in .forgejo/ISSUE_TEMPLATE .gitea/ISSUE_TEMPLATE .gitea/issue_template .github/ISSUE_TEMPLATE; do :; done)
M
bash "$SCRIPT" "$T/dropped" >/dev/null 2>&1
[ $? -eq 1 ] && ok "dropping a legacy lowercase entry fails" || bad "dropped entry fails"

# The DOCUMENTED limit, pinned rather than left to be rediscovered: a site cut below the
# four-token threshold stops looking like an ordering and drops out of the comparison entirely.
# What catches that in the real repo is the site COUNT asserted at the end of this file, not this
# comparison, and a reader deserves to see that stated as a test rather than only as a comment.
mk "$T/undercut/a.sh" <<M
  for d in $CANON; do :; done
M
mk "$T/undercut/b.md" <<'M'
TPL_DIR=$(for d in .forgejo/ISSUE_TEMPLATE .gitea/ISSUE_TEMPLATE .github/ISSUE_TEMPLATE; do :; done)
M
bash "$SCRIPT" "$T/undercut" >/dev/null 2>&1
[ $? -eq 0 ] && ok "a site cut to three entries drops out of the comparison (known limit)" \
  || bad "the three-entry limit behaves as documented"

# --- a line-continued copy is the same list, not a different one --------------------------------
mk "$T/wrapped/a.sh" <<M
  for d in $CANON; do :; done
M
mk "$T/wrapped/b.md" <<'M'
TPL_DIR=$(for d in .forgejo/ISSUE_TEMPLATE .forgejo/issue_template \
          .gitea/ISSUE_TEMPLATE .gitea/issue_template .github/ISSUE_TEMPLATE; do :; done)
M
bash "$SCRIPT" "$T/wrapped" >/dev/null 2>&1
[ $? -eq 0 ] && ok "a backslash-continued copy is read as one list" || bad "wrapped copy reads as one list"

# --- a passing mention of one or two dirs in prose is NOT a resolution order ---------------------
mk "$T/prose/a.sh" <<M
  for d in $CANON; do :; done
M
mk "$T/prose/b.md" <<'M'
Templates write to `.github/ISSUE_TEMPLATE/` on GitHub, or to `.forgejo/ISSUE_TEMPLATE/`
when the host is Forgejo.
M
bash "$SCRIPT" "$T/prose" >/dev/null 2>&1
[ $? -eq 0 ] && ok "a two-directory prose mention is not treated as an ordering" \
  || bad "prose mentions are not orderings"

# --- a tree with NO ordering at all must fail, or the guard can be defeated by deletion ----------
mk "$T/none/a.md" <<'M'
nothing relevant here
M
bash "$SCRIPT" "$T/none" >/dev/null 2>&1
[ $? -eq 1 ] && ok "a tree with no ordering at all fails rather than passing vacuously" \
  || bad "no-ordering tree fails"

# --- round 1: agreement is NOT enough; the canonical order itself must be pinned -----------------
# The guard originally compared the copies to each other only, so a sweep reordering EVERY site to
# case-grouped passed with CI green, reintroducing the exact #61 defect while the error message
# claimed a canon nothing enforced.
mk "$T/allwrong/a.sh" <<'M'
  for d in .forgejo/ISSUE_TEMPLATE .gitea/ISSUE_TEMPLATE .github/ISSUE_TEMPLATE .forgejo/issue_template .gitea/issue_template; do :; done
M
mk "$T/allwrong/b.md" <<'M'
TPL_DIR=$(for d in .forgejo/ISSUE_TEMPLATE .gitea/ISSUE_TEMPLATE .github/ISSUE_TEMPLATE .forgejo/issue_template .gitea/issue_template; do :; done)
M
out=$(bash "$SCRIPT" "$T/allwrong" 2>&1); rc=$?
[ "$rc" -eq 1 ] && ok "sites that AGREE on the wrong order still fail" \
  || bad "a uniform case-grouped sweep is caught (rc=$rc)"
case "$out" in *"Host-grouped is canonical"*) ok "and it says which order is canonical" ;;
               *) bad "names the canonical order (got: $out)" ;; esac

# --- round 1: two back-to-back copies are two sites, not one ten-entry site ---------------------
# The copies must be separated by PUNCTUATION ONLY to reproduce the merge: two `for` loops have
# the words "do" and "done" between them, which already stops the run.
mk "$T/backtoback/a.sh" <<M
# $CANON
# $CANON
M
bash "$SCRIPT" "$T/backtoback" >/dev/null 2>&1
[ $? -eq 0 ] && ok "adjacent identical copies read as two sites, not one merged run" \
  || bad "back-to-back copies do not merge"

# --- round 1: a shipped component named test-* is not a fixture ---------------------------------
# The skip was filename-based, so plugins/forge-kit-testing/agents/test-automator.md was excluded
# from the scan entirely. Only this directory's own contract tests are fixtures.
mk "$T/named/a.sh" <<M
  for d in $CANON; do :; done
M
mk "$T/named/plugins/g/agents/test-automator.md" <<'M'
TPL_DIR=$(for d in .forgejo/ISSUE_TEMPLATE .gitea/ISSUE_TEMPLATE .github/ISSUE_TEMPLATE .forgejo/issue_template .gitea/issue_template; do :; done)
M
bash "$SCRIPT" "$T/named" >/dev/null 2>&1
[ $? -eq 1 ] && ok "a component whose name starts with test- is still scanned" \
  || bad "test-named components are scanned"

# --- fail closed on a missing root ---------------------------------------------------------------
bash "$SCRIPT" "$T/does-not-exist" >/dev/null 2>&1
[ $? -eq 2 ] && ok "a missing root fails closed with exit 2" || bad "missing root fails closed"

# --- the real repo must agree across all its sites ----------------------------------------------
out=$(bash "$SCRIPT" 2>&1); rc=$?
[ "$rc" -eq 0 ] && ok "this repo's sites all carry the same order" || bad "repo sites agree ($out)"
# EXACTLY six, which pins the count as well as the agreement. Without this, a site edited down to
# three entries would simply drop out of the comparison and the guard would report agreement among
# the survivors. The ticket said four; the guard found dep-auditor.md and the lockstep header too.
# Anchored: a bare substring also matched "16 sites", which is the opposite of pinning a count.
case "$out" in "check-template-dir-order: 6 sites,"*) ok "and it finds exactly six of them, two more than the ticket listed" ;;
               *) bad "finds exactly six sites (got: $out)" ;; esac

echo ""
echo "template-dir-order tests: $pass passed, $fail failed"
[ "$fail" -eq 0 ]
