#!/usr/bin/env bash
# Contract test for forge-host's forge-lib.sh (issues #62, #63). The library is driven with a
# stubbed forge_api standing in for the network layer (defined AFTER sourcing, so the real one
# is shadowed), a request log, and canned Forgejo responses. Covers:
#   - forge_issue_list (forgejo): concatenates ALL pages; a page SHORTER than the requested
#     limit but non-empty must NOT terminate the loop (server-side limit clamping, #62)
#   - forge_issue_list (forgejo): requests type=issues (PR exclusion is server-side)
#   - forge_issue_label (forgejo): resolves names across pages (#63 follow-up to the old
#     single-page ?limit=100 lookup), refuses the WHOLE call on any unresolvable name
#     (atomic, non-zero exit, stderr names the labels), zero-label repos get a distinct
#     message, and nothing is POSTed on refusal
#   - FORGE_DRY_RUN=1 sends nothing on either function
# The github branches shell out to `gh` and are unchanged by #62/#63; they are exercised by
# real use, not stubbed here.
set -uo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
LIB="${FORGE_LIB_UNDER_TEST:-$HERE/../plugins/forge-kit-devops/skills/forge-host/assets/forge-lib.sh}"
T=$(mktemp -d); trap 'rm -rf "$T"' EXIT
pass=0; fail=0
ok()   { echo "  ok: $1"; pass=$((pass+1)); }
bad()  { echo "  FAIL: $1"; fail=$((fail+1)); }

# Each case runs in a subshell: source the lib, shadow forge_api with the stub, act, assert.
# The stub logs every request to REQLOG and serves canned pages keyed on the query string.

# --- forge_issue_list pagination (#62) ---
(
  . "$LIB"
  REQLOG="$T/a.log"; : > "$REQLOG"
  export FORGE_HOST=forgejo FORGE_REPO=o/r
  forge_api() {
    echo "$1 $2" >> "$REQLOG"
    case "$2" in
      *"/issues?"*page=1*) printf '[{"number":1},{"number":2}]' ;;   # short page (2 < limit): clamp shape
      *"/issues?"*page=2*) printf '[{"number":3}]' ;;
      *"/issues?"*page=3*) printf '[]' ;;
      *) printf '[]' ;;
    esac
  }
  out=$(forge_issue_list) || exit 9
  len=$(printf '%s' "$out" | jq 'length')
  [ "$len" = 3 ] || exit 1
  grep -q 'type=issues' "$REQLOG" || exit 2
  exit 0
)
case $? in
  0) ok "issue_list concatenates all pages; short-but-nonempty page does not terminate (clamp-safe)";;
  1) bad "issue_list did not return all 3 issues across pages (#62 truncation)";;
  2) bad "issue_list dropped the type=issues PR exclusion";;
  *) bad "issue_list errored";;
esac

# --- forge_issue_list small repo: terminates (no infinite loop) and returns the page ---
(
  . "$LIB"
  export FORGE_HOST=forgejo FORGE_REPO=o/r
  forge_api() { case "$2" in *page=1*) printf '[{"number":1}]';; *) printf '[]';; esac; }
  out=$(forge_issue_list) || exit 9
  [ "$(printf '%s' "$out" | jq 'length')" = 1 ]
)
[ $? -eq 0 ] && ok "issue_list on a sub-page repo returns the single page and terminates" \
             || bad "issue_list on a sub-page repo"

# --- forge_issue_label: resolves across pages, POSTs resolved ids (#63 AC6) ---
(
  . "$LIB"
  REQLOG="$T/c.log"; : > "$REQLOG"
  export FORGE_HOST=forgejo FORGE_REPO=o/r
  forge_api() {
    echo "$1 $2 ${3-}" >> "$REQLOG"
    case "$1 $2" in
      "GET "*"/labels?"*page=1*) seq 1 50 | jq -sc 'map({name:("l"+tostring),id:.})' ;;
      "GET "*"/labels?"*page=2*) printf '[{"name":"bug","id":99}]' ;;
      "GET "*"/labels?"*)        printf '[]' ;;
      "POST "*)                  printf '{}' ;;
    esac
  }
  forge_issue_label 7 bug || exit 1
  grep -q '^POST /repos/o/r/issues/7/labels {"labels":\[99\]}' "$REQLOG" || exit 2
)
case $? in
  0) ok "issue_label resolves a name on label page 2 and POSTs its id";;
  1) bad "issue_label failed on a resolvable name found beyond page 1 (#63 AC6)";;
  2) bad "issue_label did not POST the resolved id";;
  *) bad "issue_label multi-page case errored";;
esac

# --- forge_issue_label: unresolvable name refuses the WHOLE call, names it, POSTs nothing ---
(
  . "$LIB"
  REQLOG="$T/d.log"; : > "$REQLOG"
  export FORGE_HOST=forgejo FORGE_REPO=o/r
  forge_api() {
    echo "$1 $2" >> "$REQLOG"
    case "$1 $2" in
      "GET "*"/labels?"*page=1*) printf '[{"name":"bug","id":1}]' ;;
      "GET "*"/labels?"*)        printf '[]' ;;
      "POST "*)                  printf '{}' ;;
    esac
  }
  err=$(forge_issue_label 7 bug nosuchlabel 2>&1 >/dev/null); rc=$?
  [ "$rc" -ne 0 ]                          || exit 1
  printf '%s' "$err" | grep -q 'nosuchlabel' || exit 2
  ! grep -q '^POST' "$REQLOG"              || exit 3
)
case $? in
  0) ok "issue_label refuses atomically on an unresolvable name, names it, sends no POST";;
  1) bad "issue_label exited 0 despite an unresolvable name (#63: the silent-drop bug)";;
  2) bad "issue_label error does not name the failing label";;
  3) bad "issue_label POSTed despite refusing (not atomic)";;
  *) bad "issue_label unresolvable case errored";;
esac

# --- forge_issue_label: zero-label repo gets a distinct error, no POST ---
(
  . "$LIB"
  REQLOG="$T/e.log"; : > "$REQLOG"
  export FORGE_HOST=forgejo FORGE_REPO=o/r
  forge_api() {
    echo "$1 $2" >> "$REQLOG"
    case "$1 $2" in "GET "*"/labels?"*) printf '[]' ;; "POST "*) printf '{}' ;; esac
  }
  err=$(forge_issue_label 7 bug 2>&1 >/dev/null); rc=$?
  [ "$rc" -ne 0 ]                            || exit 1
  printf '%s' "$err" | grep -qi 'no labels'  || exit 2
  ! grep -q '^POST' "$REQLOG"                || exit 3
)
case $? in
  0) ok "issue_label on a zero-label repo errors with the distinct no-labels message";;
  1) bad "issue_label exited 0 on a zero-label repo (#63: fresh-repo silent no-op)";;
  2) bad "issue_label zero-label error is not distinct (should say the repo has no labels)";;
  3) bad "issue_label POSTed on a zero-label repo";;
  *) bad "issue_label zero-label case errored";;
esac

# --- forge_issue_list at scale: pages totalling well past the ~128KiB argv limit (F1) ---
# Accumulating pages via a jq --argjson argument dies at Linux MAX_ARG_STRLEN; one real page of
# template-v4-sized issues already sits near the ceiling, so pagination must not build argv.
(
  . "$LIB"
  export FORGE_HOST=forgejo FORGE_REPO=o/r
  PAD="$(head -c 1300 /dev/zero | tr '\0' x)"
  BIGPAGE="$(jq -nc --arg pad "$PAD" '[range(50)] | map({number:., body:$pad})')"
  forge_api() {
    case "$2" in
      *"/issues?"*page=1*|*"/issues?"*page=2*|*"/issues?"*page=3*) printf '%s' "$BIGPAGE" ;;
      *) printf '[]' ;;
    esac
  }
  out=$(forge_issue_list) || exit 1
  [ "$(printf '%s' "$out" | jq 'length')" = 150 ] || exit 2
)
case $? in
  0) ok "issue_list survives pages totalling ~200KB (no argv-limit accumulation)";;
  1) bad "issue_list hard-failed on large pages (argv MAX_ARG_STRLEN, the E2BIG regression)";;
  2) bad "issue_list returned the wrong count on large pages";;
  *) bad "issue_list large-page case errored";;
esac

# --- forge_issue_label: org-level labels resolve (repo list alone is not the label universe) ---
(
  . "$LIB"
  REQLOG="$T/g.log"; : > "$REQLOG"
  export FORGE_HOST=forgejo FORGE_REPO=o/r
  forge_api() {
    echo "$1 $2 ${3-}" >> "$REQLOG"
    case "$1 $2" in
      "GET /repos/"*"/labels?"*page=1*) printf '[{"name":"bug","id":1}]' ;;
      "GET /orgs/"*"/labels?"*page=1*)  printf '[{"name":"org-wide","id":42}]' ;;
      "GET "*"/labels?"*)               printf '[]' ;;
      "POST "*)                         printf '{}' ;;
    esac
  }
  forge_issue_label 7 org-wide || exit 1
  grep -q '^POST /repos/o/r/issues/7/labels {"labels":\[42\]}' "$REQLOG" || exit 2
)
case $? in
  0) ok "issue_label resolves an org-level label and POSTs its id (id distinct from the issue number)";;
  1) bad "issue_label refused a valid org-level label (repo list treated as the whole universe)";;
  2) bad "issue_label did not POST the org label id";;
  *) bad "issue_label org-label case errored";;
esac

# --- forge_issue_label: an EMPTY-STRING name must be refused, not slip past the gate ---
# join(" ") of [""] is "", so a string-emptiness gate reads an empty name as "nothing missing"
# and would POST [null, ...]: the silent-partial class again, reached by an argv quoting slip.
(
  . "$LIB"
  REQLOG="$T/h.log"; : > "$REQLOG"
  export FORGE_HOST=forgejo FORGE_REPO=o/r
  forge_api() {
    echo "$1 $2" >> "$REQLOG"
    case "$1 $2" in
      "GET "*"/labels?"*page=1*) printf '[{"name":"bug","id":1}]' ;;
      "GET "*"/labels?"*)        printf '[]' ;;
      "POST "*)                  printf '{}' ;;
    esac
  }
  err=$(forge_issue_label 7 "" bug 2>&1 >/dev/null); rc=$?
  [ "$rc" -ne 0 ]             || exit 1
  ! grep -q '^POST' "$REQLOG" || exit 2
)
case $? in
  0) ok "issue_label refuses an empty-string name (no null id ever POSTed)";;
  1) bad "issue_label accepted an empty-string name (refusal gate bypass, POSTs null ids)";;
  2) bad "issue_label POSTed despite an empty-string name";;
  *) bad "issue_label empty-name case errored";;
esac

# --- pagination: an EMPTY 200 body mid-run is an ERROR, not a silent end-of-list ---
(
  . "$LIB"
  export FORGE_HOST=forgejo FORGE_REPO=o/r
  forge_api() { case "$2" in *page=1*) printf '[{"number":1}]';; *) printf '';; esac; }
  out=$(forge_issue_list 2>/dev/null); rc=$?
  [ "$rc" -ne 0 ]
)
[ $? -eq 0 ] && ok "paginate treats an empty response body as an error, not completion"              || bad "paginate silently truncated on an empty 200 body (rc 0, partial list)"

# --- pagination: a NON-ARRAY 200 body (error object) is an ERROR, not counted by key ---
(
  . "$LIB"
  export FORGE_HOST=forgejo FORGE_REPO=o/r
  forge_api() { printf '{"message":"temporarily unavailable"}'; }
  out=$(forge_issue_list 2>/dev/null); rc=$?
  [ "$rc" -ne 0 ]
)
[ $? -eq 0 ] && ok "paginate treats a non-array body as an error (jq length on an object counts keys)"              || bad "paginate accepted a non-array body (object keys counted as items)"

# --- pagination cap survives a NON-NUMERIC override (a junk cap must not mean no cap) ---
(
  . "$LIB"
  export FORGE_HOST=forgejo FORGE_REPO=o/r FORGE_PAGINATE_MAX_PAGES=junk
  forge_api() { printf '[{"number":1}]'; }   # non-empty forever: only the cap can stop this
  out=$(timeout 30 bash -c '
    . "'"$LIB"'"
    export FORGE_HOST=forgejo FORGE_REPO=o/r FORGE_PAGINATE_MAX_PAGES=junk
    forge_api() { printf "[{\"number\":1}]"; }
    forge_issue_list 2>/dev/null
  '); rc=$?
  [ "$rc" -ne 0 ] && [ "$rc" -ne 124 ]
)
[ $? -eq 0 ] && ok "a non-numeric FORGE_PAGINATE_MAX_PAGES falls back to the default cap (errors, no spin)"              || bad "a non-numeric page cap disabled the spin guard (timed out or exited 0)"

# --- forge_api_paginate directly under dry-run: prints [] and sends nothing real ---
(
  . "$LIB"
  export FORGE_HOST=forgejo FORGE_REPO=o/r FORGE_API_URL=https://forge.example FORGE_DRY_RUN=1
  forge_api() { printf '[{"number":1}]'; }
  out=$(forge_api_paginate "/repos/o/r/milestones" 2>/dev/null) || exit 1
  [ "$out" = "[]" ] || exit 2
)
case $? in
  0) ok "paginate under dry-run prints [] (direct callers like dep-auditor stay side-effect free)";;
  *) bad "paginate dry-run case (rc=$?)";;
esac

# --- FORGE_DRY_RUN: nothing is sent by either function ---
(
  . "$LIB"
  REQLOG="$T/f.log"; : > "$REQLOG"
  export FORGE_HOST=forgejo FORGE_REPO=o/r FORGE_API_URL=https://forge.example FORGE_DRY_RUN=1
  forge_api() { echo "$1 $2" >> "$REQLOG"; printf '[]'; }   # must never be reached for writes
  forge_issue_list  >/dev/null 2>&1 || exit 1
  forge_issue_label 7 bug 2>/dev/null || exit 2
  ! grep -q '^POST' "$REQLOG" || exit 3
)
case $? in
  0) ok "dry-run sends no writes from issue_list or issue_label";;
  *) bad "dry-run case (rc=$?)";;
esac

# --- #78.1: the config is resolved ONCE per process, not once per call -------------------------
# Every page used to re-run _forge_load_conf about four times (forge_host, forge_api_base,
# _forge_token), each a `git rev-parse` plus a fork per config line.
# The OBSERVABLE consequence of memoizing is that a mid-process change to the file is not picked
# up for the same root. Asserting that is the only way to distinguish a memo from no memo; an
# earlier version of this test checked that the guard variable was merely SET, which is true
# whether or not the memo is honoured, and a mutant deleting the guard survived it.
(
  . "$LIB"
  mkdir -p "$T/memo"
  _forge_root() { printf '%s' "$T/memo"; }
  printf 'FORGE_HOST=forgejo\nFORGE_REPO=a/one\n' > "$T/memo/.forge.conf"
  unset FORGE_REPO FORGE_HOST _FORGE_CONF_ROOT
  _forge_load_conf; first="${FORGE_REPO:-}"
  printf 'FORGE_HOST=forgejo\nFORGE_REPO=b/two\n' > "$T/memo/.forge.conf"
  unset FORGE_REPO
  _forge_load_conf; second="${FORGE_REPO:-}"
  [ "$first" = a/one ] && [ -z "$second" ]
)
[ $? -eq 0 ] && ok "the config file is parsed ONCE per root, so a mid-process edit is not re-read (#78.1)" \
  || bad "config load is memoized (#78.1)"

# The memo is keyed on the ROOT, not a bare boolean, so a caller that moves between repos is
# still correct. Two roots must both be loadable in one process.
(
  . "$LIB"
  mkdir -p "$T/r1" "$T/r2"
  printf 'FORGE_HOST=forgejo\nFORGE_REPO=a/one\n' > "$T/r1/.forge.conf"
  printf 'FORGE_HOST=forgejo\nFORGE_REPO=b/two\n' > "$T/r2/.forge.conf"
  _forge_root() { printf '%s' "$CUR"; }
  CUR="$T/r1"; unset FORGE_REPO FORGE_HOST; _forge_load_conf; one="${FORGE_REPO:-}"
  CUR="$T/r2"; unset FORGE_REPO FORGE_HOST; _forge_load_conf; two="${FORGE_REPO:-}"
  [ "$one" = a/one ] && [ "$two" = b/two ]
)
[ $? -eq 0 ] && ok "the memo is keyed on the repo root, so moving repos re-reads (#78.1)" \
  || bad "memo keyed on root"

# --- #78.2: the HTTP status is surfaced, not flattened into exit 22 ----------------------------
# `curl -f` collapsed every >=400 into exit 22 with no body and no status, so a caller could not
# tell 404 (an org with no labels: fine) from 401 or 500 (a real failure).
grep -qE '^[^#]*curl -f' "$LIB" && bad "no curl -f INVOCATION remains (it flattens the status)" \
  || ok "no curl -f invocation remains (it flattens the status)"
grep -q 'return 44' "$LIB" && ok "forge_api reports 404 as exit 44, a channel that survives \$( ) (#78.2)" \
  || bad "forge_api reports the status as an exit code"
# forge_issue_label must treat an org 404 as ordinary and anything else as flagged.
(
  . "$LIB"
  export FORGE_HOST=forgejo FORGE_REPO=o/r
  forge_api() { case "$2" in *"/repos/"*) printf '[{"id":1,"name":"bug"}]' ;; *) return 1 ;; esac; }
  forge_api_paginate() {
    case "$1" in
      /orgs/*) return 44 ;;
      *) printf '[{"id":1,"name":"bug"}]' ;;
    esac
  }
  err=$(forge_issue_label 7 nope 2>&1 >/dev/null)
  printf '%s' "$err" | grep -q 'org-level labels could not be listed' && exit 1 || exit 0
)
[ $? -eq 0 ] && ok "an org 404 is not reported as an org-access failure (#78.2)" \
  || bad "org 404 is treated as ordinary"
(
  . "$LIB"
  export FORGE_HOST=forgejo FORGE_REPO=o/r
  forge_api_paginate() {
    case "$1" in
      /orgs/*) return 22 ;;
      *) printf '[{"id":1,"name":"bug"}]' ;;
    esac
  }
  err=$(forge_issue_label 7 nope 2>&1 >/dev/null)
  printf '%s' "$err" | grep -q 'org-level labels could not be listed'
)
[ $? -eq 0 ] && ok "an org 401 IS reported as an org-access failure (#78.2)" \
  || bad "org 401 is flagged"

# --- #78.3: one temp dir per process, and no leak on a signal ----------------------------------
grep -q 'mktemp)' "$LIB" && bad "no bare per-call mktemp files remain (#78.3)" \
  || ok "no bare per-call mktemp files remain (#78.3)"
# The helper must SET a variable, never print a path: a caller reading it with $( ) would run it
# in a subshell, discarding both the assignment and the trap, so every call would leak a dir.
grep -q '_forge_tmp_init' "$LIB" && ok "the temp dir is created via a variable, not \$( ) (#78.3)" \
  || bad "temp dir helper sets a variable"
# And it must not clobber a caller's existing EXIT trap.
(
  . "$LIB"
  trap 'printf CALLER' EXIT
  _forge_tmp_init
  t=$(trap -p EXIT); case "$t" in *CALLER*) exit 0 ;; *) exit 1 ;; esac
)
[ $? -eq 0 ] && ok "a caller's existing EXIT trap is not overwritten (#78.3)" \
  || bad "caller EXIT trap preserved"

echo ""
echo "forge-lib tests: $pass passed, $fail failed"
[ "$fail" -eq 0 ]
