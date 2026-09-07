---
name: mutation-harness-quoting
description: Apply shell mutants with python, not perl/sed; a failed-to-apply mutant silently reads as a surviving one
metadata:
  type: feedback
---

When mutation-testing shell assets here, apply the mutation with a python heredoc that asserts the
target string was found, never with `perl -0pi -e` or `sed`. On PR #128 a perl mutation of a line
containing `"$k"` and `'%s'` failed to apply because of escaping, and the suite then reported
`36 passed, 0 failed`. Read without the assert, that is indistinguishable from a surviving mutant,
and round 2 of that review shipped a commit saying "I will not claim a kill" over exactly this.
Re-applied with python, the same mutant died immediately.

The pattern that works:

```python
python3 - <<'PY'
s=open(p).read()
assert old in s, "mutation target not found"   # this line is the point
open(p,'w').write(s.replace(old,new,1))
PY
```

**Why:** a mutation harness that can fail silently inverts the meaning of a green suite, which is
the one thing mutation testing exists to prevent. The assert converts a silent no-op into a loud
failure.

**How to apply:** every mutant needs a positive confirmation that it was applied before you read
the suite's verdict, and restore from a `cp` backup afterwards, never `git checkout`
([[never-git-checkout-uncommitted-work]]). See [[bounded-review-loop-in-practice]] for the loop
this sits inside.
