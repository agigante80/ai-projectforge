#!/usr/bin/env bash
# check-template-dir-order.sh: every copy of the template-dir resolution order must match (#77).
#
# THE DEFECT. The order is a five-entry, HOST-grouped list that SIX separate sites must agree on:
# check-template-lockstep.sh twice (its header comment and resolve_dir), ticket-gate.md,
# dep-auditor.md, and adapt/SKILL.md twice. The #61/#74 review found the copies had already diverged, case-grouped
# against host-grouped, before that PR merged. Two of the sites are prose an LLM executor will
# paraphrase, which is the failure mode forge-adapt-catalogue.sh was extracted to end.
#
# WHY THIS IS A GUARD AND NOT A SHARED SCRIPT, against the ticket's own proposal. Its trade-off
# concedes that the prose sites must keep an inline fallback for repos where the script is not
# installed, so extraction shrinks the duplication from four sites to two rather than to one, and
# the two left behind are the fragile ones. The repo already met this shape with the enforced path
# set (#112), where the catalogue must use globs while three others use an ERE, and answered it
# with a guard (test-component-paths.sh) because one implementation was impossible. Same answer
# here, and it covers all five sites instead of two.
#
# WHY HOST-GROUPED ORDER MATTERS, since a future editor will be tempted to "tidy" it into case
# groups: a repo migrated to Forgejo that kept a stale .github/ISSUE_TEMPLATE must have its LIVE
# lowercase Forgejo dir resolved, not the stale GitHub one. Case-grouping silently inverts that.
#
# Usage: check-template-dir-order.sh [ROOT]     (default: this repo)
# Exit: 0 all copies agree, 1 they disagree or none were found, 2 the root is unreadable.
set -uo pipefail

if [ "$#" -ge 1 ]; then ROOT="$1"; else
  ROOT="$(git -C "$(dirname "$0")" rev-parse --show-toplevel 2>/dev/null)" || {
    echo "check-template-dir-order: not a git checkout and no root given" >&2; exit 2; }
fi
[ -d "$ROOT" ] || { echo "check-template-dir-order: '$ROOT' is not a directory" >&2; exit 2; }

python3 - "$ROOT" <<'PY'
import os, re, sys

root = sys.argv[1]
TOKEN = re.compile(r'\.(?:forgejo|gitea|github)/(?:ISSUE_TEMPLATE|issue_template)\b')
# FOUR or more directories in one run is an ORDERING; fewer is prose. The threshold was set by the
# real tree, not by taste: forge-host/references/forgejo.md names three of them in a sentence about
# what Forgejo reads, and adapt/SKILL.md names two in a sentence about where templates are written.
# Neither is a copy of the resolution order, and treating them as one would make the guard cry wolf
# at documentation. The residual gap, a real site edited down to three entries dropping out of the
# comparison entirely, is closed by the site COUNT its contract test asserts.
MIN = 4

# THE CANON, pinned here rather than merely inferred from whatever the copies happen to say. The
# first version compared the sites only to each other, so one sweep reordering ALL of them passed
# with CI green and reintroduced the exact #61 defect, while the error message claimed a canonical
# order that nothing enforced. This line is now the single definition the ticket asked for; every
# site is checked against it.
CANON = ('.forgejo/ISSUE_TEMPLATE', '.forgejo/issue_template',
         '.gitea/ISSUE_TEMPLATE', '.gitea/issue_template', '.github/ISSUE_TEMPLATE')

sites = []
for dirpath, dirnames, filenames in os.walk(root):
    dirnames[:] = [d for d in dirnames if d not in ('.git', 'node_modules', 'temp', '.full-review')]
    for fn in sorted(filenames):
        path = os.path.join(dirpath, fn)
        rel_ = os.path.relpath(path, root)
        # THIS DIRECTORY's contract tests carry deliberately wrong orders as fixtures, so scanning
        # them would make every such test a permanent failure. Matching on the bare filename was
        # too broad: it silently excluded the shipped component
        # plugins/forge-kit-testing/agents/test-automator.md from the scan entirely.
        if re.match(r'scripts/test-[^/]*\.sh$', rel_):
            continue
        try:
            lines = open(path, encoding='utf-8', errors='replace').read().split('\n')
        except OSError:
            continue
        # An ORDERING is a bare list: the tokens are separated only by punctuation (whitespace,
        # commas, backticks, slashes, a comment hash, a line continuation). PROSE puts WORDS
        # between them, as in "`.github/ISSUE_TEMPLATE/` on GitHub, or to `.forgejo/...`". Keying
        # on that is what separates the six real sites from the two documentation passages, with
        # no allowlist and no hand-maintained site list.
        text = '\n'.join(lines)
        for m in re.finditer(
                r'(?:%s)(?:[\s,`/\\#()]*(?:%s))+' % (TOKEN.pattern, TOKEN.pattern), text):
            seq = TOKEN.findall(m.group(0))
            ln = text[:m.start()].count('\n') + 1
            # Two back-to-back copies separated only by punctuation matched as ONE run, so a file
            # whose copies were identical and correct failed with "the order differs between
            # sites". Restart a site wherever the canon's first entry appears again.
            groups, cur = [], []
            for tok in seq:
                if tok == CANON[0] and cur:
                    groups.append(cur); cur = []
                cur.append(tok)
            if cur: groups.append(cur)
            for g in groups:
                if len(g) >= MIN:
                    sites.append((rel_, ln, tuple(g)))

if not sites:
    print(f"check-template-dir-order: no resolution order found under {root}. "
          f"Deleting every copy must not read as agreement.", file=sys.stderr)
    sys.exit(1)

orders = {}
for rel, ln, seq in sites:
    orders.setdefault(seq, []).append(f"{rel}:{ln}")

if len(orders) > 1 or (CANON not in orders):
    if CANON not in orders:
        print("check-template-dir-order: NO site carries the canonical order.\n", file=sys.stderr)
    else:
        print("check-template-dir-order: the resolution order differs between sites.\n", file=sys.stderr)
    print(f"  canonical: {' '.join(CANON)}\n", file=sys.stderr)
    for seq, where in sorted(orders.items(), key=lambda kv: -len(kv[1])):
        print(f"  {len(where)} site(s): {' '.join(seq)}", file=sys.stderr)
        for w in where: print(f"      {w}", file=sys.stderr)
        print("", file=sys.stderr)
    print("Host-grouped is canonical: all Forgejo dirs, then Gitea, then GitHub, uppercase "
          "before the legacy lowercase within each host.", file=sys.stderr)
    sys.exit(1)

seq = next(iter(orders))
print(f"check-template-dir-order: {len(sites)} sites, all carrying the same {len(seq)}-entry order.")
PY
