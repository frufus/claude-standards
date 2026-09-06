#!/usr/bin/env bash
# PreToolUse on Bash: the one hook in this plugin that denies. Four git
# shapes destroy something the working tree cannot restore — a force-push,
# a hard reset, a clean, a branch force-delete — and for those a reminder
# arrives after the decision was made. ADR-0002 records the exception.
#
# The human's way through: run it themselves, or say so, after which the
# session reruns the command prefixed with CLAUDE_STANDARDS_ALLOW_DESTRUCTIVE=1.
# A guard with no way through gets switched off, and then it protects
# nothing — the parent design's argument, kept.
set -uo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

input=$(cat)
command_line=$(printf '%s' "$input" | node "$HERE/lib/json-fields.js" --raw tool_input.command 2>/dev/null)
[ -n "${command_line:-}" ] || exit 0

case "$command_line" in
    *CLAUDE_STANDARDS_ALLOW_DESTRUCTIVE=1*) exit 0 ;;
esac

kind=$(printf '%s' "$command_line" | node "$HERE/lib/destructive-git.js" 2>/dev/null)
[ -n "$kind" ] || exit 0

reason="Denied: this command is a ${kind}, which destroys something the working tree cannot restore. Ask the human. If they say yes, rerun it prefixed with CLAUDE_STANDARDS_ALLOW_DESTRUCTIVE=1, or let them run it. (ADR-0002.)"

printf '%s' "$reason" | node -e '
let s="";process.stdin.on("data",d=>s+=d).on("end",()=>{
  process.stdout.write(JSON.stringify({
    hookSpecificOutput: { hookEventName: "PreToolUse", permissionDecision: "deny", permissionDecisionReason: s }
  }));
});'
exit 0
