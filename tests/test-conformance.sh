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

rm -rf "$bare" "$full" "$noprofile"
