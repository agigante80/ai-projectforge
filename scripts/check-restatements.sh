#!/usr/bin/env bash
# check-restatements.sh: verify ticket-standards.md's Precedence list against the gate (issue #125).
#
# THE DEFECT THIS REPLACES. The Precedence section enumerates every place `ticket-gate` restates a
# doc rule, and it used to certify itself as the complete set. That claim was false every time it
# was made: three consecutive review rounds on PR #123 each found more entries, nine and counting.
# A maintainer editing a rule consults the list, edits what it names, and ships a fork in the exact
# place the doc calls drift-free. Same class as the component inventory (#96) and the label
# taxonomy (#104), both already converted from declarative prose to a guard.
#
# HOW IT CHECKS, and why not fingerprints. The ticket proposed matching normalised phrases against
# paraphrased prose, accepting false positives. Declared ANCHORS get both directions with no fuzzy
# matching at all:
#   listed-but-absent  an item's anchor no longer appears in the gate  -> the entry is stale.
#   found-but-unlisted a `rule N` reference sits in a section that no item's anchor covers.
# The cost is that an author must name the location precisely, which is the thing they were getting
# wrong. An item with NO anchor fails too: it can never be checked, so it would rot silently.
#
# A mention that genuinely does not restate anything (a routing pointer that states no bar of its
# own) goes in the allowlist, which REQUIRES a reason, so waving one through is a visible edit.
#
# Usage: check-restatements.sh [<ticket-standards.md> <ticket-gate.md> [<extra file>...]]
# With no arguments it checks this repo, including the gate's companion reference skill, whose
# content is part of the gate for this purpose (issue #109 moved the lens briefs there).
set -uo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
if [ "$#" -ge 2 ]; then
  DOC="$1"; shift; GATE_FILES=("$@")
else
  ROOT="$(git -C "$HERE" rev-parse --show-toplevel 2>/dev/null)" || {
    echo "check-restatements: not a git checkout and no explicit paths given" >&2; exit 2; }
  DOC="$ROOT/docs/guides/ticket-standards.md"
  GATE_FILES=("$ROOT/plugins/forge-kit-governance/agents/ticket-gate.md"
              "$ROOT/plugins/forge-kit-governance/skills/ticket-gate-reference/SKILL.md")
fi

[ -r "$DOC" ] || { echo "check-restatements: cannot read '$DOC'" >&2; exit 2; }
for f in "${GATE_FILES[@]}"; do
  [ -r "$f" ] || { echo "check-restatements: cannot read '$f'" >&2; exit 2; }
done

python3 - "$DOC" "${GATE_FILES[@]}" <<'PY'
import re, sys

doc_path, gate_paths = sys.argv[1], sys.argv[2:]
doc = open(doc_path).read()

m = re.search(r'^## Precedence\s*$(.*?)^## ', doc, re.M | re.S)
if not m:
    print("check-restatements: no '## Precedence' section in the doc", file=sys.stderr)
    sys.exit(2)
block = m.group(1)

# Numbered items. An item runs to the next "N. " at the start of a line, or the end of the block.
starts = [mm.start() for mm in re.finditer(r'^\d+\. ', block, re.M)]
items = []
for i, s in enumerate(starts):
    e = starts[i + 1] if i + 1 < len(starts) else len(block)
    items.append(block[s:e])
if not items:
    print("check-restatements: the Precedence section lists no numbered items", file=sys.stderr)
    sys.exit(2)

ANCHOR = re.compile(r'<!--\s*anchor:\s*"(.*?)"\s*-->', re.S)
RULEREF = re.compile(r'\brule[-\s](\d+)', re.I)

# Allowlist: "<section> :: rule <N> :: <reason>". The reason is mandatory.
allow, allow_bad = set(), []
for a in re.finditer(r'<!--\s*restatement-allow:\s*(.*?)\s*-->', doc, re.S):
    parts = [p.strip() for p in a.group(1).split('::')]
    if len(parts) < 3 or not parts[2]:
        allow_bad.append(a.group(1).strip()); continue
    rn = re.search(r'(\d+)', parts[1])
    if rn: allow.add((parts[0], rn.group(1)))

# Gate text, attributed to its nearest preceding heading.
sections, text = [], ""
for path in gate_paths:
    sec = "(top)"
    for line in open(path):
        h = re.match(r'^#{2,4} (.+)', line)
        if h: sec = h.group(1).strip()
        sections.append((sec, line))
        text += line

def section_of(needle):
    """The set of sections whose text contains this literal anchor."""
    found, buf, cur = set(), "", None
    for sec, line in sections:
        if cur is None: cur = sec
        if sec != cur:
            if needle in buf: found.add(cur)
            buf, cur = "", sec
        buf += line
    if cur is not None and needle in buf: found.add(cur)
    return found

errors = []
for bad in allow_bad:
    errors.append(f"allowlist entry has no reason (needs '<section> :: rule N :: <why>'): {bad}")

# Direction 1, listed-but-absent: every item needs an anchor, and every anchor must resolve.
covered = {}                     # rule -> set of sections an item claims for it
for n, item in enumerate(items, 1):
    anchors = ANCHOR.findall(item)
    rules = set(RULEREF.findall(item))
    if not anchors:
        errors.append(f"Precedence item {n} declares no anchor, so nothing can verify it")
        continue
    for a in anchors:
        secs = section_of(a)
        if not secs:
            errors.append(f"Precedence item {n} is STALE: anchor no longer appears in the gate: \"{a}\"")
        else:
            for r in rules:
                covered.setdefault(r, set()).update(secs)

# Direction 2, found-but-unlisted: every rule reference must sit in a covered section.
seen = set()
for sec, line in sections:
    for r in RULEREF.findall(line):
        if (sec, r) in seen: continue
        seen.add((sec, r))
        # The section is matched by PREFIX so an entry can say "Step 2.5" rather than repeating
        # the whole heading. It still has to name a real section, so it cannot silence the file.
        if any(rr == r and sec.startswith(ss) for ss, rr in allow): continue
        if sec not in covered.get(r, set()):
            errors.append(f"UNLISTED restatement: rule {r} is referenced in [{sec}] "
                          f"but no Precedence item anchors rule {r} there")

if errors:
    print("check-restatements: the Precedence list does not match the gate.\n", file=sys.stderr)
    for e in errors: print(f"  x {e}", file=sys.stderr)
    print(f"\n{len(errors)} problem(s). Fix the list, or add an allowlist entry with a reason.",
          file=sys.stderr)
    sys.exit(1)

print(f"check-restatements: {len(items)} Precedence items, all anchored and current.")
PY
