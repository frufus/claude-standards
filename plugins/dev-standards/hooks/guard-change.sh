#!/usr/bin/env bash
# PreToolUse on Edit|Write: reminds when source is edited with no
# OpenSpec change in flight.
#
# This hook NEVER denies. A guard that blocks legitimate work — a typo in
# a comment, a hotfix, repairing a broken build — gets switched off, and
# then it protects nothing.
set -uo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$HERE/lib/paths.sh"
. "$HERE/lib/os-context.sh"

input=$(cat)
IFS=$'\t' read -r file_path cwd < <(
    printf '%s' "$input" | node "$HERE/lib/json-fields.js" tool_input.file_path cwd 2>/dev/null
)

[ -n "${file_path:-}" ] || exit 0
[ -n "${cwd:-}" ] || exit 0

os_context "$cwd"
# No OpenSpec root means the project has not adopted the standard. That
# is the conformance hook's subject, once per session; repeating it on
# every edit would make both messages ignorable.
[ -n "$OS_ROOT" ] || exit 0
# A change is already in flight — this edit is the work it describes.
[ "$OS_CHANGES" = "0" ] || exit 0

rel=$(rel_path "$file_path" "$OS_ROOT")
is_source_path "$rel" || exit 0

notice="No OpenSpec change is in flight, and \`$rel\` is a source file.

Work starts as a change proposal, not as code. Write one with \`openspec change\` and get it approved before implementing, unless this edit is a hotfix or a repair — in which case say so and continue."

printf '%s' "$notice" | node -e '
let s="";process.stdin.on("data",d=>s+=d).on("end",()=>{
  process.stdout.write(JSON.stringify({
    hookSpecificOutput: { hookEventName: "PreToolUse", additionalContext: s }
  }));
});'
exit 0
