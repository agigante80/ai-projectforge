#!/usr/bin/env bash
# check-ticket-mechanics-version: 1
#
# Step 3A's mechanical checks, as a script rather than as prose for the agent to read.
#
# WHY THIS IS A SCRIPT. Step 3A was always written "so a future script can adopt them verbatim",
# and it is the highest-traffic deterministic surface in the kit with no test, because prose
# cannot be tested. Issue #149. It is also the only lever left on ticket-gate.md's size: the
# splitting convention forbids moving a rule the agent obeys into a companion skill, so prose
# that becomes code is the one route that removes words without removing capability (#150).
#
# WHAT THIS SCRIPT MUST NEVER DO: decide a verdict. It emits one row per check and nothing else.
# Every semantic question stays with the critic in Step 3B: WHICH conditions are independent,
# whether an N/A is legitimate under the derived-scope rule, whether a "none" reason holds. The
# heuristics here are deliberately NARROWER than the canonical rules in ticket-standards.md, so
# where a check cannot decide mechanically it emits `referred` and the critic rules on it. A
# check that failed outright on a heuristic miss would reject doc-compliant tickets, which is
# strictly worse than the prose it replaces.
#
# Usage:
#   check-ticket-mechanics.sh --body FILE --template FILE \
#     --tpl-version N --current-tpl-version N --labels "area,type,..."
#
# Emits TSV to stdout: <check>\t<outcome>\t<evidence>
#   outcome is one of: pass fail warn na referred
# Exit 0 whenever the checks ran, so a FAIL is data. Non-zero ONLY when input is unusable,
# because a run that cannot read its input must never look like a body full of passes.

set -uo pipefail

BODY=""; TEMPLATE=""; TPL_VERSION=""; CURRENT_TPL_VERSION=""; LABELS=""

die() { printf 'check-ticket-mechanics: %s\n' "$1" >&2; exit 2; }

while [ $# -gt 0 ]; do
  case "$1" in
    --body)                 BODY="${2:-}"; shift 2 ;;
    --template)             TEMPLATE="${2:-}"; shift 2 ;;
    --tpl-version)          TPL_VERSION="${2:-}"; shift 2 ;;
    --current-tpl-version)  CURRENT_TPL_VERSION="${2:-}"; shift 2 ;;
    --labels)               LABELS="${2:-}"; shift 2 ;;
    -h|--help)              sed -n '2,30p' "$0"; exit 0 ;;
    *) die "unknown argument: $1" ;;
  esac
done

[ -n "$BODY" ] || die "--body is required"
[ -f "$BODY" ] || die "body file not found: $BODY"
[ -n "$TEMPLATE" ] || die "--template is required"
[ -f "$TEMPLATE" ] || die "template file not found: $TEMPLATE"

row() { printf '%s\t%s\t%s\n' "$1" "$2" "$3"; }

# Everything under a `### <label>` heading, up to the next heading. Compared literally, never
# as a regex, because labels carry `/` and parentheses ("Test scenarios (Given / When / Then)").
section_of() {
  awk -v want="$1" '
    /^### / { cur = substr($0, 5); sub(/[ \t]+$/, "", cur); inside = (cur == want); next }
    inside { print }
  ' "$BODY"
}

# GitHub renders an unfilled optional textarea as `_No response_`, which is presence without
# content and must not read as a filled section.
has_content() {
  local squashed
  squashed="$(printf '%s' "$1" | tr -d '[:space:]')"
  [ -n "$squashed" ] && [ "$squashed" != "_Noresponse_" ]
}

first_line() {
  printf '%s' "$1" | grep -m1 -v '^[[:space:]]*$' | cut -c1-120
}

# Field labels sit at exactly six spaces. A checkboxes OPTION label sits deeper and carries a
# leading dash, so anchoring the indent is what keeps option text out of the section list.
template_labels() {
  awk '
    /^[[:space:]]*-[[:space:]]*type:[[:space:]]*/ {
      t = $0; sub(/^.*type:[[:space:]]*/, "", t); gsub(/[[:space:]]/, "", t); type = t; next
    }
    /^      label: / {
      if (type != "markdown") { l = substr($0, 14); sub(/[ \t]+$/, "", l); print l }
    }
  ' "$TEMPLATE"
}

# --- check 1: template version currency -------------------------------------------------
# Two shapes are deliberately NOT failures, or a re-run could never converge: a marker NEWER
# than the project's templates (a fork ahead of us) warns, and no versioned templates at all
# is N/A. Only missing-or-older fails, and 0c auto-synthesis is its repair path.
if [ -z "$CURRENT_TPL_VERSION" ]; then
  row template_version na "no versioned templates in this project"
elif [ -z "$TPL_VERSION" ]; then
  row template_version fail "no template-version marker in body (current: v$CURRENT_TPL_VERSION)"
elif [ "$TPL_VERSION" -gt "$CURRENT_TPL_VERSION" ] 2>/dev/null; then
  row template_version warn "body v$TPL_VERSION is NEWER than templates v$CURRENT_TPL_VERSION; update the templates"
elif [ "$TPL_VERSION" -lt "$CURRENT_TPL_VERSION" ] 2>/dev/null; then
  row template_version fail "body v$TPL_VERSION is older than templates v$CURRENT_TPL_VERSION"
else
  row template_version pass "template-version: $TPL_VERSION"
fi

# --- check 2: labels --------------------------------------------------------------------
# Records Step 0b's rule exactly: an area label is required, a type label warns only. This
# check never demands a label no step requires.
AREA_LABELS="api web mobile backend frontend infrastructure database design"
TYPE_LABELS="bug feature enhancement security documentation testing"
has_label_from() {
  local wanted found=1 l w
  for w in $1; do
    for l in ${LABELS//,/ }; do
      [ "$l" = "$w" ] && { found=0; break 2; }
    done
  done
  return $found
}
if ! has_label_from "$AREA_LABELS"; then
  row labels fail "no area label on the issue (one of: ${AREA_LABELS// /, })"
elif ! has_label_from "$TYPE_LABELS"; then
  row labels warn "no type label on the issue (one of: ${TYPE_LABELS// /, })"
else
  row labels pass "labels: $LABELS"
fi

# --- check 3: required sections present -------------------------------------------------
missing=""
empty=""
while IFS= read -r label; do
  [ -n "$label" ] || continue
  if ! grep -qxF "### $label" "$BODY"; then
    missing="$missing${missing:+; }$label"
  else
    content="$(section_of "$label")"
    has_content "$content" || empty="$empty${empty:+; }$label"
  fi
done <<EOF
$(template_labels)
EOF
if [ -n "$missing" ]; then
  row sections fail "heading absent: $missing"
elif [ -n "$empty" ]; then
  row sections fail "heading present but empty: $empty"
else
  row sections pass "every template section present with content"
fi

# --- check 4: GWT structure (rule 1, the checkable half) --------------------------------
# WHICH conditions are independent is the critic's judgment, never this check's.
SCENARIOS="$(section_of "Test scenarios (Given / When / Then)")"
if ! has_content "$SCENARIOS"; then
  row gwt fail "no Test scenarios section content"
else
  pos_count=$(printf '%s\n' "$SCENARIOS" | grep -cE '^[[:space:]]*\**Positive\**[[:space:]]*$')
  neg_count=$(printf '%s\n' "$SCENARIOS" | grep -cE '^[[:space:]]*\**Negative\**[[:space:]]*$')
  if [ "$pos_count" -eq 0 ] || [ "$neg_count" -eq 0 ]; then
    row gwt fail "needs at least one Positive and one Negative block (found $pos_count positive, $neg_count negative)"
  else
    # Exactly one When per block. Blocks run from a Positive/Negative marker to the next one.
    multi_when="$(printf '%s\n' "$SCENARIOS" | awk '
      /^[[:space:]]*\**(Positive|Negative)\**[[:space:]]*$/ {
        if (block != "" && whens != 1) { print block ": " whens " When lines" }
        block = $0; gsub(/[^A-Za-z]/, "", block); whens = 0; next
      }
      block != "" && /^[[:space:]]*[-*][[:space:]]*\**When\**[[:space:]]*:/ { whens++ }
      END { if (block != "" && whens != 1) { print block ": " whens " When lines" } }
    ' | head -3 | paste -sd'; ' -)"
    if [ -n "$multi_when" ]; then
      row gwt fail "each scenario block needs exactly one When ($multi_when)"
    else
      # The negative Then must be specific. A digit-bearing status, a quoted message, or an
      # UPPER_SNAKE identifier passes mechanically. Anything else is REFERRED, never failed:
      # this heuristic is narrower than rule 1's quality bar on purpose and must not reject a
      # message the canonical doc allows.
      neg_then="$(printf '%s\n' "$SCENARIOS" | awk '
        /^[[:space:]]*\**Negative\**[[:space:]]*$/ { inneg = 1; next }
        /^[[:space:]]*\**Positive\**[[:space:]]*$/ { inneg = 0; next }
        inneg && /^[[:space:]]*[-*][[:space:]]*\**Then\**[[:space:]]*:/ { print; exit }
      ')"
      if [ -z "$neg_then" ]; then
        row gwt fail "the Negative block has no Then line"
      elif printf '%s' "$neg_then" | grep -qE '[0-9]|"[^"]+"|'"'"'[^'"'"']+'"'"'|[A-Z][A-Z0-9_]{2,}'; then
        row gwt pass "$(first_line "$neg_then")"
      else
        row gwt referred "negative Then is not mechanically specific: $(first_line "$neg_then")"
      fi
    fi
  fi
fi

# --- check 5: test specs concrete -------------------------------------------------------
# A unit-test N/A is REFERRED, never auto-accepted: it is legitimate only where the gate
# derives rule 2 out of scope (docs-only, research, infra-only), and that is the critic's call.
looks_na() { printf '%s' "$1" | grep -qiE '(^|[^a-z])n/?a([^a-z]|$)|not applicable'; }
# A path is a backticked token containing a slash, or a bare filename with a known extension.
# Deliberately NOT "anything containing a slash": the literal `N/A` matches that, so an N/A
# claim read as a named path and passed a check that must refer it. So did prose like "and/or".
names_path() {
  printf '%s' "$1" | grep -qE '`[^`]*/[^`]*`|[A-Za-z0-9_-]+\.(ts|tsx|js|jsx|mjs|cjs|py|go|rb|rs|java|kt|php|cs|sh|sql|md|yml|yaml)([^A-Za-z0-9]|$)'
}

UNIT="$(section_of "Unit tests")"
E2E="$(section_of "E2E test scenarios")"
if ! has_content "$UNIT"; then
  row test_specs fail "no Unit tests section content"
elif looks_na "$UNIT" && ! names_path "$UNIT"; then
  row test_specs referred "unit tests claim N/A; legitimate only where rule 2 is out of scope: $(first_line "$UNIT")"
elif ! names_path "$UNIT"; then
  row test_specs fail "unit tests name no file path: $(first_line "$UNIT")"
elif ! has_content "$E2E"; then
  row test_specs fail "no E2E test scenarios section content"
elif names_path "$E2E"; then
  row test_specs pass "unit and E2E specs name file paths"
elif looks_na "$E2E"; then
  # An N/A needs a reason beside it. Whether the reason HOLDS, and whether the ticket touches
  # UI at all (rule 3), is Step 3B's call, so a reasoned N/A is referred rather than passed.
  e2e_words=$(printf '%s' "$E2E" | tr -d '[:space:]' | wc -c)
  if [ "$e2e_words" -gt 12 ]; then
    row test_specs referred "E2E N/A with a reason; rule 3 says a UI-touching ticket cannot claim it: $(first_line "$E2E")"
  else
    row test_specs fail "E2E N/A with no reason given"
  fi
else
  row test_specs fail "E2E section names no file path and makes no N/A claim: $(first_line "$E2E")"
fi

# --- check 6: documentation impact present ----------------------------------------------
# Presence only. Whether a "none" reason HOLDS is rule 7, judged by the critic.
DOCS="$(section_of "Documentation impact")"
if ! has_content "$DOCS"; then
  row docs_impact fail "no Documentation impact section content"
elif names_path "$DOCS"; then
  row docs_impact pass "$(first_line "$DOCS")"
elif printf '%s' "$DOCS" | grep -qiE 'none|no doc'; then
  docs_len=$(printf '%s' "$DOCS" | tr -d '[:space:]' | wc -c)
  if [ "$docs_len" -gt 12 ]; then
    row docs_impact referred "claims no docs needed; rule 7 applies to every work ticket: $(first_line "$DOCS")"
  else
    row docs_impact fail "claims no docs needed with no reason given"
  fi
else
  row docs_impact fail "names no docs and makes no explicit none claim: $(first_line "$DOCS")"
fi

exit 0
