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
        head = $0; sub(/\[.*$/, "[", head)
        body = $0; sub(/^[^[]*\[/, "", body); tail = "]"; sub(/\].*$/, "", body)
        n = split(body, parts, ","); out = ""
        for (i = 1; i <= n; i++) {
          gsub(/^[[:space:]]+|[[:space:]]+$/, "", parts[i])
          sub(/.*:/, "", parts[i])
          out = out (i > 1 ? ", " : "") parts[i]
        }
        print head out tail; next
      }
      infm && /^skills:[[:space:]]*$/ { inlist = 1; print; next }
      infm && inlist && /^[[:space:]]*-[[:space:]]*/ {
        item = $0
        sub(/^[[:space:]]*-[[:space:]]*/, "", item)
        prefix = substr($0, 1, length($0) - length(item))   # preserve the exact indentation
        sub(/.*:/, "", item)
        print prefix item; next
      }
      infm && inlist && /^[^[:space:]]/ { inlist = 0 }
      { print }
    ' "$f" > "$tmp" && mv "$tmp" "$f" || { rm -f "$tmp"; exit 2; }
    ;;
esac
