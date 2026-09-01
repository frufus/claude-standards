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
mkdir -p "$full/openspec" "$full/docs/adr"
printf 'schema: spec-driven\nprofile: web\n' > "$full/openspec/config.yaml"
printf '# CLAUDE.md\n' > "$full/CLAUDE.md"
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
mkdir -p "$withds/openspec" "$withds/docs/adr"
printf 'schema: spec-driven
profile: web
' > "$withds/openspec/config.yaml"
printf '# CLAUDE.md
' > "$withds/CLAUDE.md"
printf '{"dependencies":{"@frufus/design-system":"^0.1.0"}}' > "$withds/package.json"
out=$(printf '{"cwd":"%s"}' "$withds" | bash "$HOOK" 2>/dev/null)
check "says nothing once the design system is a dependency" "$out" ""

# The opt-out is an ADR, not a config key: an argument in writing.
optout=$(mktemp -d)
mkdir -p "$optout/openspec" "$optout/docs/adr"
printf 'schema: spec-driven
profile: web
' > "$optout/openspec/config.yaml"
printf '# CLAUDE.md
' > "$optout/CLAUDE.md"
printf '{"name":"x"}' > "$optout/package.json"
printf '# ADR-0001
' > "$optout/docs/adr/0001-no-design-system-here.md"
out=$(printf '{"cwd":"%s"}' "$optout" | bash "$HOOK" 2>/dev/null)
check "an ADR settles it, and the reminder stops" "$out" ""

# Before the toolchain exists there is nothing to depend on, so no reminder.
early=$(mktemp -d)
mkdir -p "$early/openspec" "$early/docs/adr"
printf 'schema: spec-driven
profile: web
' > "$early/openspec/config.yaml"
printf '# CLAUDE.md
' > "$early/CLAUDE.md"
out=$(printf '{"cwd":"%s"}' "$early" | bash "$HOOK" 2>/dev/null)
check "stays quiet before there is a package.json" "$out" ""

# A python project is not asked to install a Vue design system.
py=$(mktemp -d)
mkdir -p "$py/openspec" "$py/docs/adr"
printf 'schema: spec-driven
profile: python
' > "$py/openspec/config.yaml"
printf '# CLAUDE.md
' > "$py/CLAUDE.md"
printf '{"name":"x"}' > "$py/package.json"
out=$(printf '{"cwd":"%s"}' "$py" | bash "$HOOK" 2>/dev/null)
check "never asks a python project for it" "$out" ""

# The design system is not asked to depend on itself - by its name, not by the
# accident of that string appearing anywhere in the file.
itself=$(mktemp -d)
mkdir -p "$itself/openspec" "$itself/docs/adr"
printf 'schema: spec-driven
profile: web
' > "$itself/openspec/config.yaml"
printf '# CLAUDE.md
' > "$itself/CLAUDE.md"
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
mkdir -p "$dev/openspec" "$dev/docs/adr"
printf 'schema: spec-driven
profile: web
' > "$dev/openspec/config.yaml"
printf '# CLAUDE.md
' > "$dev/CLAUDE.md"
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

rm -rf "$bare" "$full" "$noprofile" "$nods" "$withds" "$optout" "$early" "$py"   "$itself" "$mention" "$dev" "$broken"
