HOOK="plugins/dev-standards/hooks/check-conformance.sh"

# A bare directory: no openspec/, no CLAUDE.md, no docs/adr/.
bare=$(mktemp -d)
out=$(printf '{"cwd":"%s"}' "$bare" | bash "$HOOK" 2>/dev/null)
contains "reports the missing openspec directory" "$out" "openspec"
contains "reports the missing CLAUDE.md"          "$out" "CLAUDE.md"
contains "reports the missing docs/adr"           "$out" "docs/adr"
contains "declares the SessionStart event"        "$out" "SessionStart"
not_contains "never denies"                       "$out" "permissionDecision"

printf '{"cwd":"%s"}' "$bare" | bash "$HOOK" >/dev/null 2>&1
check "exits 0 on a non-conforming project" "$?" "0"

# A project carrying every artifact, with a declared profile.
full=$(mktemp -d)
mkdir -p "$full/openspec" "$full/docs/adr" "$full/scripts"
printf 'schema: spec-driven\nprofile: web\n' > "$full/openspec/config.yaml"
printf '@AGENTS.md\n' > "$full/CLAUDE.md"
printf '@AGENTS.md\n' > "$full/AGENTS.md"
printf '#!/usr/bin/env bash\n' > "$full/scripts/verify"
out=$(printf '{"cwd":"%s"}' "$full" | bash "$HOOK" 2>/dev/null)
check "a conforming project produces no output" "$out" ""

# A project with an openspec/ but no profile key.
noprofile=$(mktemp -d)
mkdir -p "$noprofile/openspec" "$noprofile/docs/adr"
printf 'schema: spec-driven\n' > "$noprofile/openspec/config.yaml"
printf '# CLAUDE.md\n' > "$noprofile/CLAUDE.md"
out=$(printf '{"cwd":"%s"}' "$noprofile" | bash "$HOOK" 2>/dev/null)
contains "reports an unprofiled project" "$out" "unprofiled"

out=$(printf 'not json' | bash "$HOOK" 2>/dev/null)
check "malformed input produces no output" "$out" ""
printf 'not json' | bash "$HOOK" >/dev/null 2>&1
check "malformed input still exits 0" "$?" "0"

# A scaffolded web project that does not depend on the design system.
nods=$(mktemp -d)
mkdir -p "$nods/openspec" "$nods/docs/adr"
printf 'schema: spec-driven
profile: web
' > "$nods/openspec/config.yaml"
printf '# CLAUDE.md
' > "$nods/CLAUDE.md"
printf '{"name":"x","devDependencies":{"vue":"^3"}}' > "$nods/package.json"
out=$(printf '{"cwd":"%s"}' "$nods" | bash "$HOOK" 2>/dev/null)
contains "reports a web project without the design system" "$out" "design-system"

# The same project, with the dependency.
withds=$(mktemp -d)
mkdir -p "$withds/openspec" "$withds/docs/adr" "$withds/scripts"
printf 'schema: spec-driven
profile: web
' > "$withds/openspec/config.yaml"
printf '@AGENTS.md
' > "$withds/CLAUDE.md"
printf '@AGENTS.md
' > "$withds/AGENTS.md"
printf '#!/usr/bin/env bash
' > "$withds/scripts/verify"
printf '{"dependencies":{"@frufus/design-system":"^0.1.0"}}' > "$withds/package.json"
out=$(printf '{"cwd":"%s"}' "$withds" | bash "$HOOK" 2>/dev/null)
check "says nothing once the design system is a dependency" "$out" ""

# The opt-out is an ADR, not a config key: an argument in writing.
optout=$(mktemp -d)
mkdir -p "$optout/openspec" "$optout/docs/adr" "$optout/scripts"
printf 'schema: spec-driven
profile: web
' > "$optout/openspec/config.yaml"
printf '@AGENTS.md
' > "$optout/CLAUDE.md"
printf '@AGENTS.md
' > "$optout/AGENTS.md"
printf '#!/usr/bin/env bash
' > "$optout/scripts/verify"
printf '{"name":"x"}' > "$optout/package.json"
printf '# ADR-0001
' > "$optout/docs/adr/0001-no-design-system-here.md"
out=$(printf '{"cwd":"%s"}' "$optout" | bash "$HOOK" 2>/dev/null)
check "an ADR settles it, and the reminder stops" "$out" ""

# Before the toolchain exists there is nothing to depend on, so no reminder.
early=$(mktemp -d)
mkdir -p "$early/openspec" "$early/docs/adr" "$early/scripts"
printf 'schema: spec-driven
profile: web
' > "$early/openspec/config.yaml"
printf '@AGENTS.md
' > "$early/CLAUDE.md"
printf '@AGENTS.md
' > "$early/AGENTS.md"
printf '#!/usr/bin/env bash
' > "$early/scripts/verify"
out=$(printf '{"cwd":"%s"}' "$early" | bash "$HOOK" 2>/dev/null)
check "stays quiet before there is a package.json" "$out" ""

# A python project is not asked to install a Vue design system.
py=$(mktemp -d)
mkdir -p "$py/openspec" "$py/docs/adr" "$py/scripts"
printf 'schema: spec-driven
profile: python
' > "$py/openspec/config.yaml"
printf '@AGENTS.md
' > "$py/CLAUDE.md"
printf '@AGENTS.md
' > "$py/AGENTS.md"
printf '#!/usr/bin/env bash
' > "$py/scripts/verify"
printf '{"name":"x"}' > "$py/package.json"
out=$(printf '{"cwd":"%s"}' "$py" | bash "$HOOK" 2>/dev/null)
check "never asks a python project for it" "$out" ""

# The design system is not asked to depend on itself - by its name, not by the
# accident of that string appearing anywhere in the file.
itself=$(mktemp -d)
mkdir -p "$itself/openspec" "$itself/docs/adr" "$itself/scripts"
printf 'schema: spec-driven
profile: web
' > "$itself/openspec/config.yaml"
printf '@AGENTS.md
' > "$itself/CLAUDE.md"
printf '@AGENTS.md
' > "$itself/AGENTS.md"
printf '#!/usr/bin/env bash
' > "$itself/scripts/verify"
printf '{"name":"@frufus/design-system","version":"0.1.0"}' > "$itself/package.json"
out=$(printf '{"cwd":"%s"}' "$itself" | bash "$HOOK" 2>/dev/null)
check "the design system is exempt from depending on itself" "$out" ""

# Mentioning the name is not depending on it. A grep would pass this.
mention=$(mktemp -d)
mkdir -p "$mention/openspec" "$mention/docs/adr"
printf 'schema: spec-driven
profile: web
' > "$mention/openspec/config.yaml"
printf '# CLAUDE.md
' > "$mention/CLAUDE.md"
printf '{"name":"x","description":"a fork of @frufus/design-system"}' > "$mention/package.json"
out=$(printf '{"cwd":"%s"}' "$mention" | bash "$HOOK" 2>/dev/null)
contains "a mention is not a dependency" "$out" "design-system"

# A devDependency counts: the package is a build-time dependency for a
# consumer that only compiles it.
dev=$(mktemp -d)
mkdir -p "$dev/openspec" "$dev/docs/adr" "$dev/scripts"
printf 'schema: spec-driven
profile: web
' > "$dev/openspec/config.yaml"
printf '@AGENTS.md
' > "$dev/CLAUDE.md"
printf '@AGENTS.md
' > "$dev/AGENTS.md"
printf '#!/usr/bin/env bash
' > "$dev/scripts/verify"
printf '{"devDependencies":{"@frufus/design-system":"^0.1.0"}}' > "$dev/package.json"
out=$(printf '{"cwd":"%s"}' "$dev" | bash "$HOOK" 2>/dev/null)
check "a devDependency counts too" "$out" ""

# A package.json that cannot be parsed must not crash the hook or nag falsely.
broken=$(mktemp -d)
mkdir -p "$broken/openspec" "$broken/docs/adr"
printf 'schema: spec-driven
profile: web
' > "$broken/openspec/config.yaml"
printf '# CLAUDE.md
' > "$broken/CLAUDE.md"
printf 'not json at all' > "$broken/package.json"
printf '{"cwd":"%s"}' "$broken" | bash "$HOOK" >/dev/null 2>&1
check "an unparsable package.json still exits 0" "$?" "0"

# A profiled project without scripts/verify has no deterministic check
# for the verifier to run, so it is reported. Unprofiled projects are
# already told the bigger thing and are not nagged twice.
noscript=$(mktemp -d)
mkdir -p "$noscript/openspec" "$noscript/docs/adr"
printf 'schema: spec-driven
profile: python
' > "$noscript/openspec/config.yaml"
printf '# CLAUDE.md
' > "$noscript/CLAUDE.md"
out=$(printf '{"cwd":"%s"}' "$noscript" | bash "$HOOK" 2>/dev/null)
contains "reports a profiled project without scripts/verify" "$out" "scripts/verify"
not_contains "an unprofiled project is not asked for scripts" \
  "$(printf '{"cwd":"%s"}' "$noprofile" | bash "$HOOK" 2>/dev/null)" "scripts/verify"

# A profiled project without AGENTS.md is invisible to every agent that is
# not Claude Code. Reported once, like the scripts.
noagents=$(mktemp -d)
mkdir -p "$noagents/openspec" "$noagents/docs/adr" "$noagents/scripts"
printf 'schema: spec-driven
profile: python
' > "$noagents/openspec/config.yaml"
printf '# CLAUDE.md
' > "$noagents/CLAUDE.md"
printf '#!/usr/bin/env bash
' > "$noagents/scripts/verify"
out=$(printf '{"cwd":"%s"}' "$noagents" | bash "$HOOK" 2>/dev/null)
contains "reports a profiled project without AGENTS.md" "$out" "AGENTS.md"
not_contains "an unprofiled project is not asked for AGENTS.md" \
  "$(printf '{"cwd":"%s"}' "$noprofile" | bash "$HOOK" 2>/dev/null)" "AGENTS.md"

# AGENTS.md present but not imported is the failure the import exists to
# prevent: two files, two lists of commands, drifting apart.
noimport=$(mktemp -d)
mkdir -p "$noimport/openspec" "$noimport/docs/adr" "$noimport/scripts"
printf 'schema: spec-driven\nprofile: python\n' > "$noimport/openspec/config.yaml"
printf '# CLAUDE.md\n' > "$noimport/CLAUDE.md"
printf '# AGENTS.md\n' > "$noimport/AGENTS.md"
printf '#!/usr/bin/env bash\n' > "$noimport/scripts/verify"
out=$(printf '{"cwd":"%s"}' "$noimport" | bash "$HOOK" 2>/dev/null)
contains "reports a CLAUDE.md that does not import AGENTS.md" "$out" "does not import"
not_contains "and does not also claim AGENTS.md is missing"   "$out" "no \`AGENTS.md\`"

# The graph skill installed with no graph to read: the strict hook would
# redirect the first read into nothing. Reported once; silent once the
# graph is there.
nograph=$(mktemp -d)
mkdir -p "$nograph/openspec" "$nograph/docs/adr" "$nograph/scripts" "$nograph/.claude/skills/graphify"
printf 'schema: spec-driven\nprofile: python\n' > "$nograph/openspec/config.yaml"
printf '@AGENTS.md\n' > "$nograph/CLAUDE.md"
printf '@AGENTS.md\n' > "$nograph/AGENTS.md"
printf '#!/usr/bin/env bash\n' > "$nograph/scripts/verify"
printf '# graphify\n' > "$nograph/.claude/skills/graphify/SKILL.md"
out=$(printf '{"cwd":"%s"}' "$nograph" | bash "$HOOK" 2>/dev/null)
contains "reports an installed graph skill with no graph" "$out" "graphify-out/graph.json"
mkdir -p "$nograph/graphify-out"
printf '{}' > "$nograph/graphify-out/graph.json"
check "says nothing once the graph is committed" "$(printf '{"cwd":"%s"}' "$nograph" | bash "$HOOK" 2>/dev/null)" ""
check "a project without the graph skill is not asked for a graph" "$(printf '{"cwd":"%s"}' "$full" | bash "$HOOK" 2>/dev/null)" ""

rm -rf "$bare" "$full" "$noprofile" "$nods" "$withds" "$optout" "$early" "$py"   "$itself" "$mention" "$dev" "$broken" "$noscript" "$noagents" "$noimport" "$nograph"
