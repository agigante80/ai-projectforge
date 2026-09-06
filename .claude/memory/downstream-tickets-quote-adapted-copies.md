---
name: downstream-tickets-quote-adapted-copies
description: "A ticket filed from a forge-adapt install may quote ITS adapted text as forge-kit canon; #101 did, and the quote was in no branch of the history"
metadata:
  type: project
---

Tickets filed against forge-kit from a downstream install may quote that project's **adapted** copy of a component and attribute it to forge-kit's canonical text. Verify every quotation before acting on it.

Found 2026-09-06 on issue #101 (privacy regime hardcoding, filed from a downstream project running forge-adapt v48). Its argument turned on a sentence attributed to `docs/guides/ticket-standards.md`:

> "A GDPR section here would auto-score N/A on every ticket forever, which trains authors to skip sections."

That sentence is in no file in this repository and in no branch of its history:

```
grep -rniE "auto-score|on every ticket forever|trains authors to skip" .   # nothing
git log --all -S "on every ticket forever" --oneline                        # nothing
```

The canonical doc says close to the opposite. Its section "The N/A rule (load-bearing)" designs FOR permanently inapplicable sections: a rule outside a ticket's scope is "marked N/A with a one-line justification, never failed."

**Why:** forge-adapt's entire job is to rewrite components into a project's own words, so a downstream reader is looking at adapted text that carries the upstream component name and version marker. Quoting it back upstream is a natural mistake, not carelessness, and it is invisible unless someone greps. The claim it supported here ("the kit agrees with the reasoning and still ships the default that causes it") was the ticket's whole rhetorical load, and nothing was behind it.

**How to apply:** when a ticket quotes forge-kit at itself, run the grep before believing it, and check `git log --all -S` in case the text was removed rather than never present. When the citation fails, separate it from the argument: #101's jurisdiction half was strong and survived intact, so the fix was a rewrite plus a public correction comment, never a close. Also check scope: the same ticket counted 3 sites where the real surface was 8 files, because a downstream reader only sees the components their project installed.

Related: [[generated-index-and-size-budget]] (the same class, prose asserted about a tree nobody re-checked).
