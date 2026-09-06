#!/usr/bin/env bash
# Contract test for forge-host/assets/sync-labels.sh (issue #104).
#
# Driven with a STUBBED forge-lib.sh placed next to a copy of the script, so the script sources the
# stub instead of the real transport. Nothing here touches a network or a real forge. This is the
# same shape as test-forge-lib.sh's stubbed `forge_api`, one level out: there the library was under
# test, here the library IS the seam.
set -uo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(git -C "$HERE" rev-parse --show-toplevel)"
SRC="$ROOT/plugins/forge-kit-devops/skills/forge-host/assets/sync-labels.sh"

pass=0
fail=0
ok()  { echo "  ok: $1"; pass=$((pass + 1)); }
bad() { echo "  FAIL: $1"; fail=$((fail + 1)); }

T=$(mktemp -d); trap 'rm -rf "$T"' EXIT
cp "$SRC" "$T/sync-labels.sh"

cat > "$T/forge-lib.sh" <<'STUB'
forge_repo() { printf 'o/r'; }
forge_host() { printf '%s' "${STUB_HOST:-github}"; }
forge_api_paginate() { cat "$HOST_LABELS"; }
forge_api() { printf '%s %s %s\n' "$1" "$2" "${3:-}" >> "$REQLOG"; printf '{}'; }
STUB

# declared <file> <<'Y' ... Y   writes a labels.yml fixture
host_json() { printf '%s' "$1" > "$T/host.json"; }

run() {  # run [args...] -> $out, $rc, and $REQLOG holds every write attempted
  REQLOG="$T/req.log"; : > "$REQLOG"
  out=$(cd "$T" && HOST_LABELS="$T/host.json" REQLOG="$REQLOG" \
        bash ./sync-labels.sh --labels "$T/labels.yml" "$@" 2>&1); rc=$?
}

cat > "$T/labels.yml" <<'Y'
- name: bug
  color: "d73a4a"
  description: Something isn't working

- name: security
  color: "e4e669"
  description: Security vulnerability or hardening
Y

# --- 1. host matches the declaration ----------------------------------------------------------
host_json '[{"id":1,"name":"bug","color":"d73a4a","description":"Something isn'"'"'t working"},
            {"id":2,"name":"security","color":"e4e669","description":"Security vulnerability or hardening"}]'
run --check
[ "$rc" -eq 0 ] && ok "--check passes when the host matches" || bad "--check passes when host matches (rc=$rc: $out)"
[ ! -s "$REQLOG" ] && ok "--check writes nothing" || bad "--check writes nothing (log: $(cat "$REQLOG"))"

# --- 2. a declared label the host lacks -------------------------------------------------------
host_json '[{"id":1,"name":"bug","color":"d73a4a","description":"Something isn'"'"'t working"}]'
run --check
[ "$rc" -ne 0 ] && ok "--check fails when a declared label is absent" || bad "--check fails on absent (rc=$rc)"
printf '%s' "$out" | grep -q 'missing  security' && ok "--check names the absent label" || bad "--check names the absent label"

# --- 3. sync creates it, with the declared colour and description ------------------------------
run
[ "$rc" -eq 0 ] && ok "sync exits 0 after creating" || bad "sync exits 0 (rc=$rc: $out)"
grep -q '^POST /repos/o/r/labels ' "$REQLOG" && ok "sync POSTs the missing label" || bad "sync POSTs the missing label"
grep -q '"name":"security"' "$REQLOG" && grep -q '"color":"e4e669"' "$REQLOG" \
  && ok "the created label carries its declared colour" || bad "created label carries its colour"

# --- 4. drift in the description --------------------------------------------------------------
host_json '[{"id":1,"name":"bug","color":"d73a4a","description":"Something isn'"'"'t working"},
            {"id":2,"name":"security","color":"e4e669","description":"WRONG"}]'
run --check
[ "$rc" -ne 0 ] && ok "--check fails on a drifted description" || bad "--check fails on drifted description"
printf '%s' "$out" | grep -q 'drifted  security' && ok "--check names the drifted label" || bad "--check names the drifted label"

# --- 5. drift in the colour -------------------------------------------------------------------
host_json '[{"id":1,"name":"bug","color":"d73a4a","description":"Something isn'"'"'t working"},
            {"id":2,"name":"security","color":"000000","description":"Security vulnerability or hardening"}]'
run --check
[ "$rc" -ne 0 ] && ok "--check fails on a drifted colour" || bad "--check fails on drifted colour"

# --- 6. colour CASE is not drift --------------------------------------------------------------
host_json '[{"id":1,"name":"bug","color":"D73A4A","description":"Something isn'"'"'t working"},
            {"id":2,"name":"security","color":"#E4E669","description":"Security vulnerability or hardening"}]'
run --check
[ "$rc" -eq 0 ] && ok "colour case and a leading # are not drift" || bad "colour case is not drift (rc=$rc: $out)"

# --- 7. an undeclared label is reported and NEVER deleted -------------------------------------
host_json '[{"id":1,"name":"bug","color":"d73a4a","description":"Something isn'"'"'t working"},
            {"id":2,"name":"security","color":"e4e669","description":"Security vulnerability or hardening"},
            {"id":9,"name":"wontfix","color":"ffffff","description":"stock default"}]'
run
printf '%s' "$out" | grep -q 'extra    wontfix' && ok "an undeclared label is reported" || bad "an undeclared label is reported"
grep -qi 'DELETE' "$REQLOG" && bad "sync never DELETEs" || ok "sync never DELETEs"
[ "$rc" -eq 0 ] && ok "an undeclared label is not itself a failure" || bad "an undeclared label is not a failure (rc=$rc)"

# --- 8. update addresses the label by NAME on github, by ID on forgejo -------------------------
host_json '[{"id":1,"name":"bug","color":"d73a4a","description":"Something isn'"'"'t working"},
            {"id":42,"name":"security","color":"e4e669","description":"WRONG"}]'
run
grep -q '^PATCH /repos/o/r/labels/security ' "$REQLOG" \
  && ok "github updates a label by name" || bad "github updates by name (log: $(cat "$REQLOG"))"
REQLOG="$T/req.log"; : > "$REQLOG"
out=$(cd "$T" && HOST_LABELS="$T/host.json" REQLOG="$REQLOG" STUB_HOST=forgejo \
      bash ./sync-labels.sh --labels "$T/labels.yml" 2>&1); rc=$?
grep -q '^PATCH /repos/o/r/labels/42 ' "$REQLOG" \
  && ok "forgejo updates a label by id" || bad "forgejo updates by id (log: $(cat "$REQLOG"))"

# --- 9. dry run sends nothing -----------------------------------------------------------------
host_json '[{"id":1,"name":"bug","color":"d73a4a","description":"Something isn'"'"'t working"}]'
REQLOG="$T/req.log"; : > "$REQLOG"
out=$(cd "$T" && HOST_LABELS="$T/host.json" REQLOG="$REQLOG" FORGE_DRY_RUN=1 \
      bash ./sync-labels.sh --labels "$T/labels.yml" 2>&1); rc=$?
[ ! -s "$REQLOG" ] && ok "FORGE_DRY_RUN=1 sends nothing" || bad "dry run sends nothing (log: $(cat "$REQLOG"))"
printf '%s' "$out" | grep -q "\[dry-run\] create label 'security'" \
  && ok "dry run says what it would create" || bad "dry run says what it would create"

# --- 10. a malformed declaration REFUSES rather than syncing a partial set ---------------------
cp "$T/labels.yml" "$T/labels.good.yml"
printf -- '- name: ok\n  color: "ffffff"\n  description: fine\nthis line is not valid\n' > "$T/labels.yml"
run
[ "$rc" -ne 0 ] && ok "a malformed labels file refuses" || bad "a malformed labels file refuses (rc=$rc)"
[ ! -s "$REQLOG" ] && ok "...and writes nothing (no partial sync)" || bad "malformed file writes nothing"
printf '%s' "$out" | grep -q 'unparsable line 4' && ok "...naming the offending line" || bad "names the offending line"
cp "$T/labels.good.yml" "$T/labels.yml"

# --- 11. the real repo's own labels.yml parses ------------------------------------------------
n=$(awk '/^-[[:space:]]+name:/ {c++} END {print c+0}' "$ROOT/.github/labels.yml")
host_json '[]'
REQLOG="$T/req.log"; : > "$REQLOG"
out=$(cd "$T" && HOST_LABELS="$T/host.json" REQLOG="$REQLOG" FORGE_DRY_RUN=1 \
      bash ./sync-labels.sh --labels "$ROOT/.github/labels.yml" 2>&1); rc=$?
got=$(printf '%s' "$out" | grep -c '\[dry-run\] create label')
[ "$rc" -eq 0 ] && [ "$got" -eq "$n" ] \
  && ok "forge-kit's own labels.yml parses to all $n labels" \
  || bad "forge-kit's own labels.yml parses ($got of $n, rc=$rc)"

echo ""
echo "sync-labels tests: $pass passed, $fail failed"
[ "$fail" -eq 0 ]
