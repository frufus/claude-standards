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

# The web profile builds its interface on the shared design system. Reported
# only once there is a package.json to depend on it - before that the project
# has no toolchain yet and the reminder would be noise - and never when an ADR
# records the decision to go without. The opt-out is deliberately an argument
# in writing rather than a config key: going without should cost a paragraph,
# not a line.
#
# The dependency is read out of the dependency fields rather than grepped for.
# A grep also matches the package's own `name`, which would silence the check
# for the design system itself by coincidence rather than on purpose - and
# would keep silencing it for anything that merely mentions the string.
if grep -qE '^profile:[[:space:]]*web[[:space:]]*$' "$cwd/openspec/config.yaml" 2>/dev/null &&
    [ -f "$cwd/package.json" ] &&
    ! ls "$cwd"/docs/adr/*design-system* >/dev/null 2>&1; then

    ds=$(node -e '
      const pkg = require(process.argv[1]);
      const name = "@frufus/design-system";
      // The design system is not asked to depend on itself.
      if (pkg.name === name) { console.log("exempt"); process.exit(0) }
      const has = ["dependencies", "devDependencies", "peerDependencies"]
        .some((field) => pkg[field] && name in pkg[field]);
      console.log(has ? "present" : "missing");
    ' "$cwd/package.json" 2>/dev/null)

    if [ "$ds" = "missing" ]; then
        add "no \`@frufus/design-system\` — the web profile builds on the shared design system. Install and wire it, or record the decision to go without as an ADR whose filename contains \`design-system\`."
    fi
fi

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
