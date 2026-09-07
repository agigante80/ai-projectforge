#!/usr/bin/env bash
# Contract test for forge-adapt-agent-skills.sh, the mechanical half of issue #124.
#
# WHY A SCRIPT AND NOT PROSE. forge-adapt is prose an LLM executes, and this repo already learned
# where that fails: the S3 catalogue became a script because "an LLM executor kept reintroducing
# fixed bugs". Parsing a YAML list out of frontmatter and rewriting plugin-scoped identifiers is
# exactly that kind of fiddly mechanical step, so it is a script the skill runs verbatim.
#
# THE FAILURE THIS PREVENTS. An agent that declares `skills:` and is installed WITHOUT them loses
# that content silently: Claude Code "skips it and logs a warning to the debug log". Nothing in the
# project would show a problem, and the agent would run with its lens material missing.
set -uo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
SCRIPT="$HERE/forge-adapt-agent-skills.sh"
T="$(mktemp -d)"; trap 'rm -rf "$T"' EXIT

pass=0
fail=0
ok()  { echo "  ok: $1"; pass=$((pass + 1)); }
bad() { echo "  FAIL: $1"; fail=$((fail + 1)); }
eq()  { [ "$2" = "$3" ] && ok "$1" || bad "$1 (want '$3', got '$2')"; }

agent() { mkdir -p "$(dirname "$1")"; cat > "$1"; }

# --- block-list form, the shape the docs use ---------------------------------------------------
agent "$T/block.md" <<'M'
---
name: ticket-gate
description: gate a ticket
skills:
  - forge-kit-governance:gate-lenses
  - privacy-regime
tools: ["Bash"]
---
Body mentioning skills: not-a-declaration
M
eq "block list prints each declared skill verbatim" \
   "$(bash "$SCRIPT" "$T/block.md" | tr '\n' ',')" "forge-kit-governance:gate-lenses,privacy-regime,"
eq "--names strips the plugin scope for a project install" \
   "$(bash "$SCRIPT" --names "$T/block.md" | tr '\n' ',')" "gate-lenses,privacy-regime,"

# --- inline flow form ---------------------------------------------------------------------------
agent "$T/flow.md" <<'M'
---
name: a
skills: [forge-kit-governance:gate-lenses, privacy-regime]
---
body
M
eq "inline flow form is parsed too" \
   "$(bash "$SCRIPT" --names "$T/flow.md" | tr '\n' ',')" "gate-lenses,privacy-regime,"

# --- plugin:folder:skill, per the docs: the SKILL name is the last segment -----------------------
agent "$T/folder.md" <<'M'
---
name: a
skills:
  - some-plugin:nested:deep-skill
---
body
M
eq "plugin:folder:skill resolves to the skill name" \
   "$(bash "$SCRIPT" --names "$T/folder.md")" "deep-skill"

# --- a following top-level key must END the list, or its items read as skills --------------------
# Mutation-driven: making the list run to the end of frontmatter left the suite green without this.
agent "$T/nextkey.md" <<'M'
---
name: a
skills:
  - gate-lenses
tools:
  - Bash
  - Read
---
body
M
eq "a following top-level key ends the skills list" \
   "$(bash "$SCRIPT" "$T/nextkey.md" | tr '\n' ',')" "gate-lenses,"

# --- an agent with no skills: field is NORMAL and must not read as a failure ---------------------
agent "$T/none.md" <<'M'
---
name: a
description: no companion skills
---
body
M
out=$(bash "$SCRIPT" "$T/none.md"); rc=$?
eq "no skills: field prints nothing" "$out" ""
eq "no skills: field still exits 0" "$rc" "0"

# --- a skills: mention in the BODY is not a declaration ------------------------------------------
agent "$T/body.md" <<'M'
---
name: a
description: d
---
The install step must handle skills:
  - not-a-real-declaration
M
eq "a skills: line in the body is ignored" "$(bash "$SCRIPT" "$T/body.md")" ""

# --- frontmatter ends at the SECOND ---, so a later --- cannot reopen it -------------------------
agent "$T/reopen.md" <<'M'
---
name: a
---
body
---
skills:
  - sneaky
M
eq "a second --- block in the body does not reopen frontmatter" "$(bash "$SCRIPT" "$T/reopen.md")" ""

# --- --rewrite converts the installed copy to project scope, in place ----------------------------
cp "$T/block.md" "$T/rewrite.md"
bash "$SCRIPT" --rewrite "$T/rewrite.md"
eq "--rewrite drops the plugin scope in the file" \
   "$(bash "$SCRIPT" "$T/rewrite.md" | tr '\n' ',')" "gate-lenses,privacy-regime,"
grep -q '^name: ticket-gate' "$T/rewrite.md" \
  && ok "--rewrite leaves the rest of the frontmatter intact" \
  || bad "--rewrite preserved the other frontmatter keys"
grep -q 'Body mentioning skills: not-a-declaration' "$T/rewrite.md" \
  && ok "--rewrite does not touch the body" \
  || bad "--rewrite left the body alone"

# --- fail closed on a missing file, rather than printing nothing and exiting 0 -------------------
err=$(bash "$SCRIPT" "$T/does-not-exist.md" 2>&1 >/dev/null); rc=$?
eq "a missing agent file exits 2 (fail closed, not a silent empty list)" "$rc" "2"
# rc alone is not enough: awk also exits 2 on a missing file, so removing the guard entirely left
# this green. Assert the deliberate message, which only the guard emits.
case "$err" in
  *"cannot read agent file"*) ok "a missing agent file reports WHY, not an awk error" ;;
  *) bad "a missing agent file reports why (got '$err')" ;;
esac

echo ""
echo "forge-adapt-agent-skills tests: $pass passed, $fail failed"
[ "$fail" -eq 0 ]
