#!/usr/bin/env bash
# sync-labels-version: 1
# sync-labels.sh: make the host's labels match `.github/labels.yml`, or report that they do not.
#
# WHY THIS EXISTS (issue #104). forge-kit shipped a label taxonomy, documented that labels drive
# ticket-gate's lens routing, and never imported it into its own repository: 18 labels declared,
# 4 present. `security`, `critical` and `api` are executable inputs to the gate, so the kit's most
# distinctive mechanism was unexercisable in the one repo guaranteed to be running it. The taxonomy
# was a declarative file with no applier and no checker, and `docs/guides/labels.md` said only
# "create all labels using gh label create", which is a manual instruction someone runs once.
#
# Host-aware via forge-lib.sh, because labels are already a forge_* concern (#63): GitHub takes
# label NAMES on update, Forgejo takes label IDs, and this hides that difference the way
# forge_issue_label does.
#
# Usage:
#   sync-labels.sh [--check] [--labels FILE] [--repo OWNER/NAME]
#     default   create missing labels and update drifted ones
#     --check   change nothing; exit 1 listing what is missing or drifted (for humans and CI)
#   FORGE_DRY_RUN=1  print what would be written and send nothing (as elsewhere in forge-host)
#
# NEVER DELETES. A label on the host that is not declared is reported and left alone: GitHub ships
# stock defaults (duplicate, help wanted, invalid, question, wontfix), projects add their own, and
# a sync script that deletes what it does not recognise is a footgun aimed at other people's data.
set -uo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=forge-lib.sh
if [ -f "$HERE/forge-lib.sh" ]; then . "$HERE/forge-lib.sh"
elif [ -f "$HERE/../../../../../scripts/forge-lib.sh" ]; then . "$HERE/../../../../../scripts/forge-lib.sh"
else echo "sync-labels: forge-lib.sh not found next to this script" >&2; exit 2; fi

MODE=sync
LABELS_FILE=""
REPO_OVERRIDE=""
while [ $# -gt 0 ]; do
  case "$1" in
    --check)  MODE=check; shift ;;
    --labels) LABELS_FILE="$2"; shift 2 ;;
    --repo)   REPO_OVERRIDE="$2"; shift 2 ;;
    *) echo "sync-labels: unknown argument '$1'" >&2; exit 2 ;;
  esac
done

if [ -z "$LABELS_FILE" ]; then
  root="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
  for c in "$root/.github/labels.yml" "$root/.forgejo/labels.yml" "$root/.gitea/labels.yml"; do
    [ -f "$c" ] && { LABELS_FILE="$c"; break; }
  done
fi
[ -n "$LABELS_FILE" ] && [ -f "$LABELS_FILE" ] || {
  echo "sync-labels: no labels file found (looked for .github/labels.yml)" >&2; exit 2; }

command -v jq >/dev/null 2>&1 || { echo "sync-labels: jq is required" >&2; exit 2; }

REPO="${REPO_OVERRIDE:-$(forge_repo)}"
[ -n "$REPO" ] || { echo "sync-labels: could not resolve the repo" >&2; exit 2; }

# --- parse the declaration -------------------------------------------------------------------
# Deliberately strict rather than tolerant. The accepted shape is exactly what forge-kit ships:
#   - name: <name>
#     color: "<hex>"
#     description: <free text>
# An unrecognised non-blank, non-comment line is a hard ERROR, never a skip: silently ignoring a
# malformed entry would drop a label from the sync and reproduce the very drift this script exists
# to end, with a green exit code.
declared=$(awk '
  /^[[:space:]]*#/ || /^[[:space:]]*$/ { next }
  /^-[[:space:]]+name:[[:space:]]*/ {
    if (n != "") print n "\t" c "\t" d
    n = $0; sub(/^-[[:space:]]+name:[[:space:]]*/, "", n); gsub(/^"|"$/, "", n)
    c = ""; d = ""; next
  }
  /^[[:space:]]+color:[[:space:]]*/ {
    c = $0; sub(/^[[:space:]]+color:[[:space:]]*/, "", c); gsub(/^"|"$/, "", c); sub(/^#/, "", c); next
  }
  /^[[:space:]]+description:[[:space:]]*/ {
    d = $0; sub(/^[[:space:]]+description:[[:space:]]*/, "", d); gsub(/^"|"$/, "", d); next
  }
  { print "sync-labels: unparsable line " NR ": " $0 > "/dev/stderr"; bad = 1 }
  END { if (n != "") print n "\t" c "\t" d; if (bad) exit 3 }
' "$LABELS_FILE") || { echo "sync-labels: $LABELS_FILE is not in the expected shape; refusing to sync a partial set" >&2; exit 3; }

[ -n "$declared" ] || { echo "sync-labels: $LABELS_FILE declares no labels" >&2; exit 3; }

# --- read the host's current labels (all pages) -----------------------------------------------
existing=$(forge_api_paginate "/repos/$REPO/labels") || {
  echo "sync-labels: could not list labels on $REPO" >&2; exit 2; }
echo "$existing" | jq -e 'type == "array"' >/dev/null 2>&1 || {
  echo "sync-labels: unexpected label-list response for $REPO" >&2; exit 2; }

host_field() {  # host_field <name> <field>  -> the value, or empty when the label is absent
  printf '%s' "$existing" | jq -r --arg n "$1" --arg f "$2" \
    'map(select(.name == $n)) | if length == 0 then "" else (.[0][$f] // "" | tostring) end'
}

missing=0 drifted=0 created=0 updated=0
report=""

while IFS=$'\t' read -r name color desc; do
  [ -n "$name" ] || continue
  cur_color=$(host_field "$name" color)
  cur_desc=$(host_field "$name" description)
  if [ -z "$(host_field "$name" name)" ]; then
    missing=$((missing + 1)); report="${report}  missing  $name"$'\n'
    if [ "$MODE" = sync ]; then
      if [ "${FORGE_DRY_RUN:-0}" = 1 ]; then
        echo "[dry-run] create label '$name' (#$color) on $REPO" >&2
      else
        body=$(jq -nc --arg n "$name" --arg c "$color" --arg d "$desc" \
                 '{name:$n, color:$c, description:$d}')
        forge_api POST "/repos/$REPO/labels" "$body" >/dev/null || {
          echo "sync-labels: failed to create '$name'" >&2; exit 1; }
      fi
      created=$((created + 1))
    fi
    continue
  fi
  # Colour comparison is case-insensitive and '#'-insensitive: hosts normalise differently and a
  # case difference is not drift anyone means.
  lc() { printf '%s' "$1" | tr 'A-Z' 'a-z' | sed 's/^#//'; }
  if [ "$(lc "$cur_color")" != "$(lc "$color")" ] || [ "$cur_desc" != "$desc" ]; then
    drifted=$((drifted + 1))
    report="${report}  drifted  $name (color '$cur_color' vs '$color'; description '$cur_desc' vs '$desc')"$'\n'
    if [ "$MODE" = sync ]; then
      if [ "${FORGE_DRY_RUN:-0}" = 1 ]; then
        echo "[dry-run] update label '$name' on $REPO" >&2
      else
        body=$(jq -nc --arg n "$name" --arg c "$color" --arg d "$desc" \
                 '{name:$n, color:$c, description:$d}')
        # GitHub addresses a label by NAME on update; Forgejo by ID, the same split forge-lib
        # already hides for forge_issue_label.
        case "$(forge_host)" in
          forgejo) id=$(host_field "$name" id)
                   [ -n "$id" ] || { echo "sync-labels: no id for '$name' on forgejo" >&2; exit 1; }
                   forge_api PATCH "/repos/$REPO/labels/$id" "$body" >/dev/null ;;
          *)       forge_api PATCH "/repos/$REPO/labels/$name" "$body" >/dev/null ;;
        esac || { echo "sync-labels: failed to update '$name'" >&2; exit 1; }
      fi
      updated=$((updated + 1))
    fi
  fi
done <<< "$declared"

# --- labels on the host that nobody declared: report, never touch -----------------------------
undeclared=$(printf '%s' "$existing" | jq -r '.[].name' \
  | grep -vxF -f <(printf '%s\n' "$declared" | cut -f1) || true)
if [ -n "$undeclared" ]; then
  echo "sync-labels: on $REPO but not declared (left alone, never deleted):" >&2
  printf '%s\n' "$undeclared" | sed 's/^/  extra    /' >&2
fi

if [ "$MODE" = check ]; then
  if [ "$missing" -gt 0 ] || [ "$drifted" -gt 0 ]; then
    echo "sync-labels: $REPO is out of sync with $LABELS_FILE"
    printf '%s' "$report"
    echo "Run: sync-labels.sh   (to create the missing labels and fix the drifted ones)"
    exit 1
  fi
  echo "sync-labels: $REPO matches $LABELS_FILE (all declared labels present and current)."
  exit 0
fi

echo "sync-labels: $REPO synced from $LABELS_FILE ($created created, $updated updated)."
exit 0
