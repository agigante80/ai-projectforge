#!/usr/bin/env bash
# forge-adapt-agent-skills.sh: read the `skills:` frontmatter field of an agent (issue #124).
#
# WHY THIS EXISTS. Claude Code's `agents/` directory is a FLAT namespace owned by the loader, which
# claims every .md under it at any depth, so an agent can never carry a `references/` directory the
# way a skill can (probed against `claude plugin validate`: a nested AGENT.md is silently skipped
# and the reference file is reported as the agent instead). The supported way to give an agent
# reference material is a COMPANION SKILL named in its `skills:` frontmatter, whose content Claude
# Code injects into the subagent at startup.
#
# forge-adapt therefore has a dependency edge to follow at install time: an agent that declares
# `skills:` needs those skills installed too, and the plugin-scoped `plugin-name:skill-name` form
# has to become the bare name a project skill answers to. Both steps are mechanical and fiddly, and
# this repo already knows what happens when a mechanical step stays prose: the S3 catalogue became
# a script because an LLM executor kept reintroducing fixed bugs. So forge-adapt runs this verbatim.
#
# THE FAILURE IT PREVENTS is silent. A declared skill that is missing is "skipped with a warning to
# the debug log", so an agent installed without its companion skill runs with its lens material
# gone and nothing in the project shows a problem.
#
# Usage:
#   forge-adapt-agent-skills.sh <agent.md>             print declared skills verbatim, one per line
#   forge-adapt-agent-skills.sh --names <agent.md>     print the bare skill names (project scope)
#   forge-adapt-agent-skills.sh --rewrite <agent.md>   rewrite the file's list to bare names
#
# Exit codes: 0 success (an agent with no `skills:` field prints nothing and is NOT an error, the
# normal case for most agents); 2 the file is missing or unreadable, so a caller cannot mistake a
# vanished file for an agent that declares nothing.
set -uo pipefail

mode=print
case "${1-}" in
  --names)   mode=names;   shift ;;
  --rewrite) mode=rewrite; shift ;;
  --*) echo "forge-adapt-agent-skills: unknown option '$1'" >&2; exit 2 ;;
esac

f="${1-}"
[ -n "$f" ] && [ -r "$f" ] || { echo "forge-adapt-agent-skills: cannot read agent file '${f:-<none>}'" >&2; exit 2; }

# Frontmatter is the block between the FIRST '---' on line 1 and the next '---'. A later '---' in
# the body cannot reopen it, and a `skills:` line in the body is prose, not a declaration.
extract() {
  awk '
    NR == 1 { if ($0 != "---") exit; infm = 1; next }
    infm && /^---[[:space:]]*$/ { exit }
    infm { print }
  ' "$1"
}

# This parses two YAML SHAPES, not YAML. Anything else has to fail closed: a half-understood
# rewrite leaves frontmatter that no longer parses, and the agent then stops loading entirely,
# which is a worse outcome than the silent missing skill this script exists to prevent.
#   supported: `skills:` followed by `  - name` lines, or `skills: [a, b]` closed on the SAME line.
#   refused:   a multi-line flow list, a plain scalar, a block scalar, anything else.
classify() {
  extract "$1" | awk '
    /^skills:[[:space:]]*$/            { print "block"; seen = 1; exit }
    /^skills:[[:space:]]*\[.*\]/       { print "flow";  seen = 1; exit }
    /^skills:/                         { print "bad";   seen = 1; exit }
    END { if (!seen) print "none" }
  '
}

# Both YAML shapes the field is written in: a block list, and an inline flow sequence.
parse() {
  awk '
    /^skills:[[:space:]]*\[/ {                       # inline: skills: [a, plugin:b]
      line = $0
      sub(/^skills:[[:space:]]*\[/, "", line)
      sub(/\].*$/, "", line)
      n = split(line, parts, ",")
      for (i = 1; i <= n; i++) {
        gsub(/^[[:space:]]+|[[:space:]]+$/, "", parts[i])
        gsub(/^["'"'"']|["'"'"']$/, "", parts[i])
        if (parts[i] != "") print parts[i]
      }
      next
    }
    /^skills:[[:space:]]*$/ { inlist = 1; next }     # block: skills: then "  - name" lines
    inlist && /^[[:space:]]*-[[:space:]]*/ {
      item = $0
      sub(/^[[:space:]]*-[[:space:]]*/, "", item)
      gsub(/^[[:space:]]+|[[:space:]]+$/, "", item)
      gsub(/^["'"'"']|["'"'"']$/, "", item)
      if (item != "") print item
      next
    }
    inlist && /^[^[:space:]]/ { inlist = 0 }         # a new top-level key ends the list
  '
}

# A project skill at .claude/skills/<name>/SKILL.md answers to its BARE name. The docs give the
# plugin form as plugin-name:skill-name, or plugin-name:folder:skill-name when a plugin groups its
# skills, and in both the SKILL name is the last segment.
bare() { sed 's/.*://'; }

shape="$(classify "$f")"
if [ "$shape" = bad ]; then
  echo "forge-adapt-agent-skills: unsupported 'skills:' shape in '$f'." >&2
  echo "  Supported: a block list, or an inline flow list closed on the same line." >&2
  exit 2
fi

case "$mode" in
  print) extract "$f" | parse ;;
  names) extract "$f" | parse | bare ;;
  rewrite)
    tmp="$(mktemp "${TMPDIR:-/tmp}/forge-adapt-skills.XXXXXX")" || exit 2
    # Rewrite only inside frontmatter, and only the identifiers themselves: every other key, and
    # the whole body, must survive byte for byte.
    awk '
      NR == 1 && $0 == "---" { infm = 1; print; next }
      infm && /^---[[:space:]]*$/ { infm = 0; print; next }
      infm && /^skills:[[:space:]]*\[/ {
        idx = index($0, "["); head = substr($0, 1, idx); rest = substr($0, idx + 1)
        cidx = index(rest, "]")
        body = substr(rest, 1, cidx - 1); tail = substr(rest, cidx)   # tail keeps ] and any comment
        n = split(body, parts, ","); out = ""
        for (i = 1; i <= n; i++) {
          gsub(/^[[:space:]]+|[[:space:]]+$/, "", parts[i])
          gsub(/^["'"'"']|["'"'"']$/, "", parts[i])
          sub(/.*:/, "", parts[i])
          if (parts[i] != "") out = out (out == "" ? "" : ", ") parts[i]
        }
        print head out tail; next
      }
      infm && /^skills:[[:space:]]*$/ { inlist = 1; print; next }
      infm && inlist && /^[[:space:]]*-[[:space:]]*/ {
        item = $0
        sub(/^[[:space:]]*-[[:space:]]*/, "", item)
        prefix = substr($0, 1, length($0) - length(item))   # preserve the exact indentation
        gsub(/^["'"'"']|["'"'"']$/, "", item)
        sub(/.*:/, "", item)
        print prefix item; next
      }
      infm && inlist && /^[^[:space:]]/ { inlist = 0 }
      { print }
    ' "$f" > "$tmp" || { rm -f "$tmp"; exit 2; }
    # Truncate in place rather than `mv`: mv would install mktemp's 0600 over the agent's own mode,
    # and a mode change does not show up in a git diff.
    cat "$tmp" > "$f" || { rm -f "$tmp"; exit 2; }
    rm -f "$tmp"
    ;;
esac
