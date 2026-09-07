#!/usr/bin/env bash
# Contract test for check-ticket-mechanics.sh, the scripted half of ticket-gate Step 3A (#149).
#
# WHY EVERY REFER PATH IS TESTED EXPLICITLY. The script's heuristics are deliberately narrower
# than the canonical rules, so where it cannot decide it must emit `referred` and let the critic
# rule. A naive implementation fails outright instead, which would reject doc-compliant tickets:
# strictly worse than the prose it replaced. The refer cases are therefore the point of this
# suite, not an afterthought.
#
# One case here is a REGRESSION for a bug this suite caught on its first run: the literal `N/A`
# matches a "contains a slash" path test (N, /, A), so a unit-test N/A read as a named file path
# and PASSED a check whose whole job was to refer it.

set -uo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SCRIPT="$ROOT/plugins/forge-kit-governance/skills/ticket-gate-reference/assets/check-ticket-mechanics.sh"
TEMPLATE="$ROOT/.github/ISSUE_TEMPLATE/feature.yml"
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

passed=0; failed=0
ok()   { printf '  ok: %s\n' "$1"; passed=$((passed+1)); }
bad()  { printf '  FAIL: %s\n' "$1"; failed=$((failed+1)); }

[ -f "$SCRIPT" ]   || { echo "missing script: $SCRIPT"; exit 1; }
[ -f "$TEMPLATE" ] || { echo "missing template: $TEMPLATE"; exit 1; }

# A body with every template section filled, so any single override isolates one check.
SUMMARY="a change"; SCENARIOS=""; UNIT=""; E2E=""; DOCS=""
reset_fields() {
  SCENARIOS='**Condition: login**

Positive
- Given: a valid user
- When: they submit
- Then: a session starts

Negative
- Given: a bad password
- When: they submit
- Then: 401 with AUTH_FAILED'
  UNIT='- [ ] Positive: `tests/unit/auth.test.ts` - valid input -> session'
  E2E='- [ ] `tests/e2e/login.spec.ts` happy and unhappy paths'
  DOCS='Updates `docs/guides/auth.md`'
}

mkbody() {
  local out="$WORK/$1"; shift
  {
    echo "<!-- template-version: 6 -->"
    echo
    while IFS= read -r label; do
      [ -n "$label" ] || continue
      echo "### $label"
      echo
      case "$label" in
        "Test scenarios (Given / When / Then)") echo "$SCENARIOS" ;;
        "Unit tests")           echo "$UNIT" ;;
        "E2E test scenarios")   echo "$E2E" ;;
        "Documentation impact") echo "$DOCS" ;;
        *)                      echo "filled in" ;;
      esac
      echo
    done < <(awk '
      /^[[:space:]]*-[[:space:]]*type:[[:space:]]*/ { t=$0; sub(/^.*type:[[:space:]]*/,"",t); gsub(/[[:space:]]/,"",t); type=t; next }
      /^      label: / { if (type != "markdown") { l=substr($0,14); sub(/[ \t]+$/,"",l); print l } }
    ' "$TEMPLATE")
  } > "$out"
  printf '%s' "$out"
}

# outcome_of <bodyfile> <check> [extra args...]
outcome_of() {
  local body="$1" check="$2"; shift 2
  bash "$SCRIPT" --body "$body" --template "$TEMPLATE" \
    --tpl-version 6 --current-tpl-version 6 --labels "backend,feature" "$@" 2>/dev/null \
    | awk -F'\t' -v c="$check" '$1 == c { print $2 }'
}

expect() { # <label> <expected> <actual>
  if [ "$2" = "$3" ]; then ok "$1"; else bad "$1 (expected $2, got '$3')"; fi
}

echo "check-ticket-mechanics: template version"
reset_fields; B="$(mkbody good.md)"
expect "current version passes" pass "$(outcome_of "$B" template_version)"
expect "older marker fails" fail \
  "$(bash "$SCRIPT" --body "$B" --template "$TEMPLATE" --tpl-version 4 --current-tpl-version 6 --labels "backend,feature" | awk -F'\t' '$1=="template_version"{print $2}')"
expect "newer marker warns, never fails, or a re-run cannot converge" warn \
  "$(bash "$SCRIPT" --body "$B" --template "$TEMPLATE" --tpl-version 7 --current-tpl-version 6 --labels "backend,feature" | awk -F'\t' '$1=="template_version"{print $2}')"
expect "no versioned templates is N/A" na \
  "$(bash "$SCRIPT" --body "$B" --template "$TEMPLATE" --tpl-version 6 --current-tpl-version "" --labels "backend,feature" | awk -F'\t' '$1=="template_version"{print $2}')"
expect "missing marker fails" fail \
  "$(bash "$SCRIPT" --body "$B" --template "$TEMPLATE" --tpl-version "" --current-tpl-version 6 --labels "backend,feature" | awk -F'\t' '$1=="template_version"{print $2}')"

echo "check-ticket-mechanics: labels"
expect "area and type pass" pass \
  "$(bash "$SCRIPT" --body "$B" --template "$TEMPLATE" --tpl-version 6 --current-tpl-version 6 --labels "backend,feature" | awk -F'\t' '$1=="labels"{print $2}')"
expect "missing area fails" fail \
  "$(bash "$SCRIPT" --body "$B" --template "$TEMPLATE" --tpl-version 6 --current-tpl-version 6 --labels "feature" | awk -F'\t' '$1=="labels"{print $2}')"
expect "missing type warns only" warn \
  "$(bash "$SCRIPT" --body "$B" --template "$TEMPLATE" --tpl-version 6 --current-tpl-version 6 --labels "backend" | awk -F'\t' '$1=="labels"{print $2}')"

echo "check-ticket-mechanics: sections"
expect "all sections present passes" pass "$(outcome_of "$B" sections)"
grep -v '^### Acceptance criteria$' "$B" > "$WORK/nosec.md"
expect "absent heading fails" fail "$(outcome_of "$WORK/nosec.md" sections)"
sed '/^### Dependencies$/{n;n;s/^filled in$//}' "$B" > "$WORK/empty.md"
expect "heading with empty content fails" fail "$(outcome_of "$WORK/empty.md" sections)"
sed '/^### Dependencies$/{n;n;s/^filled in$/_No response_/}' "$B" > "$WORK/noresp.md"
expect "GitHub's _No response_ is not content" fail "$(outcome_of "$WORK/noresp.md" sections)"

echo "check-ticket-mechanics: GWT structure"
expect "positive and negative with a specific Then passes" pass "$(outcome_of "$B" gwt)"
reset_fields; SCENARIOS="${SCENARIOS/- Then: 401 with AUTH_FAILED/- Then: it should not work}"
expect "vague negative Then is REFERRED, not failed" referred "$(outcome_of "$(mkbody vague.md)" gwt)"
reset_fields; SCENARIOS="${SCENARIOS/- Then: 401 with AUTH_FAILED/- Then: rejected with \"bad credentials\"}"
expect "quoted message is mechanically specific" pass "$(outcome_of "$(mkbody quoted.md)" gwt)"
reset_fields; SCENARIOS="${SCENARIOS/- When: they submit$'\n'- Then: a session starts/- When: they submit
- When: and again
- Then: a session starts}"
expect "two When lines in one block fails" fail "$(outcome_of "$(mkbody twowhen.md)" gwt)"
reset_fields; SCENARIOS="${SCENARIOS%%Negative*}"
expect "positive only fails" fail "$(outcome_of "$(mkbody posonly.md)" gwt)"
reset_fields; SCENARIOS="Positive
- Given: a user
- When: they submit
- Then: it works

Negative
- Given: a bad password
- When: they submit"
expect "negative block with no Then fails" fail "$(outcome_of "$(mkbody nothen.md)" gwt)"
reset_fields; SCENARIOS=""
expect "empty scenarios section fails" fail "$(outcome_of "$(mkbody noscen.md)" gwt)"

echo "check-ticket-mechanics: test specs"
reset_fields
expect "named unit and E2E paths pass" pass "$(outcome_of "$(mkbody specs.md)" test_specs)"
reset_fields; UNIT="add unit tests"
expect "bare 'add unit tests' fails" fail "$(outcome_of "$(mkbody bareunit.md)" test_specs)"
reset_fields; UNIT="N/A docs-only change"
expect "unit N/A is REFERRED, never auto-accepted" referred "$(outcome_of "$(mkbody unitna.md)" test_specs)"
reset_fields; UNIT="N/A"
expect "REGRESSION: bare N/A is not read as a file path" referred "$(outcome_of "$(mkbody bareNA.md)" test_specs)"
reset_fields; UNIT="covers the and/or branch"
expect "REGRESSION: prose containing a slash is not a path" fail "$(outcome_of "$(mkbody slashprose.md)" test_specs)"
reset_fields; E2E="N/A, this ticket changes no UI-visible behaviour at all"
expect "E2E N/A with a reason is REFERRED, since rule 3 is the critic's call" referred "$(outcome_of "$(mkbody e2ena.md)" test_specs)"
reset_fields; E2E="N/A"
expect "E2E N/A with no reason fails" fail "$(outcome_of "$(mkbody e2ebare.md)" test_specs)"
reset_fields; E2E="we will test it somehow"
expect "E2E naming no path and claiming no N/A fails" fail "$(outcome_of "$(mkbody e2evague.md)" test_specs)"
reset_fields; E2E=""
expect "empty E2E section fails" fail "$(outcome_of "$(mkbody e2eempty.md)" test_specs)"

echo "check-ticket-mechanics: documentation impact"
reset_fields
expect "naming a doc passes" pass "$(outcome_of "$(mkbody docs.md)" docs_impact)"
reset_fields; DOCS="None, this changes no documented behaviour whatsoever"
expect "a reasoned none is REFERRED, since rule 7 applies to every work ticket" referred "$(outcome_of "$(mkbody docsnone.md)" docs_impact)"
reset_fields; DOCS="none"
expect "bare none fails" fail "$(outcome_of "$(mkbody docsbare.md)" docs_impact)"
reset_fields; DOCS="we should think about it"
expect "neither a doc nor a none claim fails" fail "$(outcome_of "$(mkbody docsvague.md)" docs_impact)"
reset_fields; DOCS=""
expect "empty docs section fails" fail "$(outcome_of "$(mkbody docsempty.md)" docs_impact)"

echo "check-ticket-mechanics: the runner itself"
reset_fields; B="$(mkbody run.md)"
out="$(bash "$SCRIPT" --body "$B" --template "$TEMPLATE" --tpl-version 6 --current-tpl-version 6 --labels "backend,feature")"
[ "$(printf '%s\n' "$out" | wc -l)" -eq 6 ] && ok "emits exactly one row per check" || bad "expected 6 rows, got $(printf '%s\n' "$out" | wc -l)"
printf '%s\n' "$out" | awk -F'\t' 'NF != 3 { bad=1 } END { exit bad+0 }' && ok "every row is three tab-separated fields" || bad "a row is not three fields"
bash "$SCRIPT" --body "$WORK/does-not-exist" --template "$TEMPLATE" --tpl-version 6 --current-tpl-version 6 --labels "x" >"$WORK/o" 2>/dev/null
rc=$?; [ $rc -ne 0 ] && ok "a missing body exits non-zero" || bad "a missing body exited 0"
[ ! -s "$WORK/o" ] && ok "a missing body emits NO rows, so it cannot read as all-pass" || bad "a missing body emitted rows"
bash "$SCRIPT" --body "$B" --template "$WORK/nope.yml" --tpl-version 6 --current-tpl-version 6 --labels "x" >/dev/null 2>&1
[ $? -ne 0 ] && ok "a missing template exits non-zero" || bad "a missing template exited 0"
bash "$SCRIPT" --body "$B" --template "$TEMPLATE" --bogus 1 >/dev/null 2>&1
[ $? -ne 0 ] && ok "an unknown argument exits non-zero" || bad "an unknown argument was ignored"
bash "$SCRIPT" --body "$B" --template "$TEMPLATE" --tpl-version 6 --current-tpl-version 6 --labels "backend,feature" >/dev/null 2>&1
[ $? -eq 0 ] && ok "a run with FAIL rows still exits 0, so a fail is data" || bad "a normal run exited non-zero"

grep -q '# check-ticket-mechanics-version: [0-9]' "$SCRIPT" && ok "carries a version marker" || bad "no version marker"

echo
echo "check-ticket-mechanics tests: $passed passed, $failed failed"
[ "$failed" -eq 0 ]
