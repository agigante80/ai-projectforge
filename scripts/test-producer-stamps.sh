#!/usr/bin/env bash
# Contract test for check-producer-stamps.sh (issue #84).
#
# THE DEFECT IT GUARDS. A component that EMITS ticket bodies used to hardcode the template-version
# it stamped. `dep-auditor` and `/ci-health` both did, still writing v4 after the v5 bump, and
# check-template-lockstep.sh could not see it because its scope is the template dir plus the
# canonical doc. Every machine-filed ticket was then born stale and triggered a synthesis
# round-trip against a ticket the kit itself had just created. PR #83 fixed the two instances by
# making both producers read the current version; nothing mechanical stopped the next one.
#
# WHY ITS OWN SCRIPT. The ticket suggested extending the lockstep guard or validate-plugins.sh.
# validate-plugins.sh has no contract test to extend, and this repo's record is that an untested
# guard is the defect. Widening lockstep breaks its hermetic argument contract, since the tests
# pass it fixture paths precisely so it never reads the real repo. One guard, one concern, one test.
set -uo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
SCRIPT="$HERE/check-producer-stamps.sh"
T="$(mktemp -d)"; trap 'rm -rf "$T"' EXIT

pass=0
fail=0
ok()  { echo "  ok: $1"; pass=$((pass + 1)); }
bad() { echo "  FAIL: $1"; fail=$((fail + 1)); }

mk() { mkdir -p "$(dirname "$1")"; cat > "$1"; }

# --- the legitimate forms must all pass ---------------------------------------------------------
mk "$T/clean/g/agents/a.md" <<'M'
Emit the CURRENT `<!-- template-version: N -->` marker, never a hardcoded number.
Replace `template-version: N` with `template-version: $CURRENT_TPL_VER` (read at runtime).
A generic placeholder like `<!-- template-version: <current> -->` is fine too.
M
bash "$SCRIPT" "$T/clean" >/dev/null 2>&1
[ $? -eq 0 ] && ok "the N form, a shell variable and a placeholder all pass" \
  || bad "legitimate forms pass"

# --- a hardcoded digit stamp must fail, and name the file ---------------------------------------
mk "$T/dirty/g/agents/dep-auditor.md" <<'M'
Create the issue with this body:
<!-- template-version: 4 -->
## Problem
M
out=$(bash "$SCRIPT" "$T/dirty" 2>&1); rc=$?
[ "$rc" -ne 0 ] && ok "a hardcoded digit stamp fails the build" || bad "digit stamp fails"
case "$out" in *dep-auditor.md*) ok "and it names the offending file" ;;
               *) bad "names the file (got: $out)" ;; esac
case "$out" in *"template-version: 4"*) ok "and quotes the stamp it found" ;;
               *) bad "quotes the stamp (got: $out)" ;; esac

# --- the bare (non-comment) form is the same defect ----------------------------------------------
mk "$T/bare/g/commands/c.md" <<'M'
body: |
  template-version: 6
M
bash "$SCRIPT" "$T/bare" >/dev/null 2>&1
[ $? -ne 0 ] && ok "the bare form without an HTML comment is caught too" || bad "bare form caught"

# --- a component version marker is NOT a template stamp -----------------------------------------
# Every component carries `<!-- <name>-version: N -->` with a real digit. Matching those would make
# the guard fire on every file in the tree, so it must anchor on the word template-version.
mk "$T/markers/g/agents/a.md" <<'M'
<!-- ticket-gate-version: 33 -->
<!-- forge-adapt-version: 56 -->
<!-- doc-rules-version: 12 -->
M
bash "$SCRIPT" "$T/markers" >/dev/null 2>&1
[ $? -eq 0 ] && ok "component version markers are not mistaken for template stamps" \
  || bad "component markers pass"

# --- multiple offenders are all reported, not just the first ------------------------------------
mk "$T/many/g/agents/a.md" <<'M'
<!-- template-version: 4 -->
M
mk "$T/many/g/commands/b.md" <<'M'
<!-- template-version: 5 -->
M
out=$(bash "$SCRIPT" "$T/many" 2>&1)
n=$(printf '%s\n' "$out" | grep -c 'template-version:')
[ "$n" -ge 2 ] && ok "every offender is reported, not only the first" || bad "reports all offenders (got $n)"

# --- fail closed on a missing root, never pass vacuously ----------------------------------------
bash "$SCRIPT" "$T/does-not-exist" >/dev/null 2>&1
[ $? -eq 2 ] && ok "a missing root fails closed with exit 2" || bad "missing root fails closed"

# --- an EMPTY tree is a pass, not a failure: a project may ship no producers --------------------
mkdir -p "$T/empty"
bash "$SCRIPT" "$T/empty" >/dev/null 2>&1
[ $? -eq 0 ] && ok "a tree with no files passes rather than reading as broken" || bad "empty tree passes"

# --- the real repo must pass, or the guard is not actually adopted -------------------------------
bash "$SCRIPT" >/dev/null 2>&1
[ $? -eq 0 ] && ok "this repo's own plugins/ tree is free of hardcoded stamps" \
  || bad "repo plugins/ tree is clean"

echo ""
echo "producer-stamp tests: $pass passed, $fail failed"
[ "$fail" -eq 0 ]
