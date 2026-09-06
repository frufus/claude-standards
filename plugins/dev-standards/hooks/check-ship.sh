#!/usr/bin/env bash
# PreToolUse on Bash: when the command pushes, opens a pull request or
# archives, and a change in flight has no verification.md — or one with
# a finding nobody answered — reminds. Reports; never denies.
#
# A Stop hook would be the obvious place ("the agent is about to say it
# is done"), but a Stop hook's only channel back into the session is a
# block, and a blocking guard is the one this plugin refuses. The moment
# the work leaves the machine is a Bash command, and Bash hooks can report.
#
# Reads openspec/changes/ from disk rather than calling `openspec list`:
# no binary needed, and a change in flight is any directory there other
# than archive/.
set -uo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$HERE/lib/paths.sh"

input=$(cat)
command_line=$(printf '%s' "$input" | node "$HERE/lib/json-fields.js" --raw tool_input.command 2>/dev/null)
cwd=$(printf '%s' "$input" | node "$HERE/lib/json-fields.js" cwd 2>/dev/null)
[ -n "${command_line:-}" ] || exit 0
[ -n "${cwd:-}" ] || exit 0

kind=$(printf '%s' "$command_line" | node "$HERE/lib/ship-command.js" 2>/dev/null)
[ -n "$kind" ] || exit 0

root=$(os_root_of "$cwd")
[ -n "$root" ] || exit 0
[ -d "$root/openspec/changes" ] || exit 0

case "$kind" in
    push)    action="push" ;;
    pr)      action="open a pull request" ;;
    archive) action="archive" ;;
    *)       exit 0 ;;
esac

missing=""
add() { missing="${missing}
- $1"; }

for dir in "$root"/openspec/changes/*/; do
    [ -d "$dir" ] || continue
    id=$(basename "$dir")
    [ "$id" = "archive" ] && continue
    report="$dir/verification.md"
    if [ ! -f "$report" ]; then
        add "\`$id\` has no \`verification.md\`. Run the \`verify\` skill first."
    else
        n=$(node "$HERE/lib/verification.js" < "$report" 2>/dev/null)
        if [ "${n:-0}" -gt 0 ] 2>/dev/null; then
            add "\`$id\` has $n unanswered finding(s) in \`verification.md\`. Each is fixed or rejected with a stated reason — write the \`Answer:\` line."
        fi
    fi

    # The proposal rules are reported at the same moment, for the same
    # reason: this is when the work leaves the machine.
    lint=$(node "$HERE/lib/change-lint.js" "$dir" 2>/dev/null)
    if [ -n "$lint" ]; then
        while IFS= read -r line; do
            [ -n "$line" ] && add "\`$id\`: $line"
        done <<EOF
$lint
EOF
    fi
done

[ -n "$missing" ] || exit 0

notice="You are about to ${action} with a change in flight that is not ready:${missing}

A change does not leave the machine before it is verified and its proposal follows the rules. If this is intended — a hotfix, or a push to back up work in progress — say so and continue."

printf '%s' "$notice" | node -e '
let s="";process.stdin.on("data",d=>s+=d).on("end",()=>{
  process.stdout.write(JSON.stringify({
    hookSpecificOutput: { hookEventName: "PreToolUse", additionalContext: s }
  }));
});'
exit 0
