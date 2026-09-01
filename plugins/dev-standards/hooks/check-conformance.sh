#!/usr/bin/env bash
# SessionStart: reports which parts of the standard this project is
# missing. Reports only — a project is allowed to be non-conforming, and
# saying so once per session is the whole job.
set -uo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Deliberately does NOT use os-context.sh. That helper resolves the
# nearest OpenSpec root, which may be a parent directory; this hook asks
# whether THIS project carries the artifacts, so it tests the directory.
input=$(cat)
cwd=$(printf '%s' "$input" | node "$HERE/lib/json-fields.js" cwd 2>/dev/null)
[ -n "$cwd" ] || exit 0
[ -d "$cwd" ] || exit 0

missing=""
add() { missing="${missing}
- $1"; }

if [ ! -d "$cwd/openspec" ]; then
    add "no \`openspec/\` — this project has no specification mechanism. Run \`openspec init --tools claude\`."
elif ! grep -qE '^profile:[[:space:]]*(web|python)[[:space:]]*$' "$cwd/openspec/config.yaml" 2>/dev/null; then
    add "unprofiled — \`openspec/config.yaml\` declares no \`profile: web\` or \`profile: python\`."
fi

[ -f "$cwd/CLAUDE.md" ] || add "no \`CLAUDE.md\` — nothing orients a session in this project."
[ -d "$cwd/docs/adr" ] || add "no \`docs/adr/\` — architecture decisions have nowhere to live."

# A conforming project gets no output at all. Anything written here is
# spent context in every session for the life of the project.
[ -n "$missing" ] || exit 0

notice="This project does not follow the development standard:${missing}

Offer to fix this before starting work; do not fix it silently."

printf '%s' "$notice" | node -e '
let s="";process.stdin.on("data",d=>s+=d).on("end",()=>{
  process.stdout.write(JSON.stringify({
    hookSpecificOutput: { hookEventName: "SessionStart", additionalContext: s }
  }));
});'
exit 0
