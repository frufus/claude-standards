#!/usr/bin/env bash
# PreToolUse on Bash: checks a `git commit -m` subject line against
# Conventional Commits and the 72-character limit. Reports; never denies.
set -uo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

input=$(cat)
command_line=$(printf '%s' "$input" | node "$HERE/lib/json-fields.js" --raw tool_input.command 2>/dev/null)

# git-subject.js tokenises the command properly (quotes, escapes, command
# separators) so it only recognises a real `git commit` invocation and
# finds its message reliably. Only -m/--message forms are visible here.
# A message on stdin (`-F -`/`--file`) never reaches the command string,
# and inventing a warning for it would fire on every correctly-formed
# heredoc commit.
subject=$(printf '%s' "$command_line" | node "$HERE/lib/git-subject.js" 2>/dev/null)
[ -n "$subject" ] || exit 0

problems=""
if ! printf '%s' "$subject" | grep -qE '^(feat|fix|docs|chore|test|ci|refactor|perf|build|style|revert)(\([^)]+\))?!?: .+'; then
    problems="${problems}
- The subject does not follow Conventional Commits. Use \`type(scope): subject\` with one of feat, fix, docs, chore, test, ci, refactor, perf, build, style, revert."
fi
if [ "${#subject}" -gt 72 ]; then
    problems="${problems}
- The subject is ${#subject} characters; the limit is 72. Move the detail into the body."
fi

[ -n "$problems" ] || exit 0

notice="This commit message does not follow the standard:${problems}

Subject: ${subject}"

printf '%s' "$notice" | node -e '
let s="";process.stdin.on("data",d=>s+=d).on("end",()=>{
  process.stdout.write(JSON.stringify({
    hookSpecificOutput: { hookEventName: "PreToolUse", additionalContext: s }
  }));
});'
exit 0
