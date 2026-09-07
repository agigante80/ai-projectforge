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
if [ "$#" -eq 1 ]; then
  echo "check-restatements: give BOTH a doc and at least one gate file, or no arguments at all" >&2
  exit 2
elif [ "$#" -ge 2 ]; then
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
# An item runs from its "N. " line through its INDENTED continuations and blank lines, and stops
# at the first unindented line that is not another item. Bounding the last one at end-of-block
# swallowed the allowlist comment and the closing prose, whose rule mentions then joined that
# item's rule set: its single anchor went on to whitelist that section for rules 4 and 5.
items, cur = [], None
for line in block.split('\n'):
    if re.match(r'^\d+\. ', line):
        if cur is not None: items.append('\n'.join(cur))
        cur = [line]; continue
    if cur is None: continue
    if line.strip() == '' or line.startswith((' ', '\t')):
        cur.append(line); continue
    items.append('\n'.join(cur)); cur = None
if cur is not None: items.append('\n'.join(cur))
if not items:
    print("check-restatements: the Precedence section lists no numbered items", file=sys.stderr)
    sys.exit(2)

ANCHOR = re.compile(r'<!--\s*anchor:\s*"(.*?)"\s*-->', re.S)
RULEREF = re.compile(r'\brule[-\s](\d+)', re.I)
# "rules 2, 3, 4 and 7" is one mention of four rules; matching only the first granted rule 1 alone.
RULES_PLURAL = re.compile(r'\brules\s+((?:\d+(?:\s*(?:,|and)\s*)?)+)', re.I)

def rules_in(text):
    found = set(RULEREF.findall(text))
    for mm in RULES_PLURAL.finditer(text):
        found.update(re.findall(r'\d+', mm.group(1)))
    return found

# Allowlist: "<section> :: rule <N> :: <reason>". The reason is mandatory.
allow, allow_bad = set(), []
for a in re.finditer(r'<!--\s*restatement-allow:\s*(.*?)\s*-->', doc, re.S):
    parts = [p.strip() for p in a.group(1).split('::')]
    if len(parts) < 3 or not parts[2]:
        allow_bad.append(a.group(1).strip()); continue
    rn = re.search(r'(\d+)', parts[1])
    if rn: allow.add((parts[0], rn.group(1)))

# Gate text, attributed to its nearest preceding heading.
sections = []
for path in gate_paths:
    name = path.split('/')[-1]
    sec, fenced = f"{name} (top)", False
    for line in open(path):
        if line.lstrip().startswith('```'):
            fenced = not fenced
        elif not fenced:
            h = re.match(r'^#{2,4} (.+)', line)
            # Keyed by FILE too: ticket-gate.md and its companion skill share heading names, and
            # without this an anchor in one silently granted coverage in the other.
            if h: sec = f"{name} :: {h.group(1).strip()}"
        sections.append((sec, line))

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
    rules = rules_in(item)
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
        # Matched by PREFIX against the heading, so an entry can say "Step 2.5" rather than
        # repeating the whole heading, and optionally against the file-qualified
        # "<file> :: <heading>" form when a heading name is shared across files. It still has to
        # name a real section, so it cannot be used to silence the file.
        head = sec.split(' :: ', 1)[1] if ' :: ' in sec else sec
        if any(rr == r and (head.startswith(ss) or sec.startswith(ss)) for ss, rr in allow):
            continue
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
