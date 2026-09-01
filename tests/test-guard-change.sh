HOOK="plugins/dev-standards/hooks/guard-change.sh"

# Outside an OpenSpec project the guard has no opinion: a project that
# has not adopted the standard is the conformance hook's business, not
# this one's, and warning on every edit would train the user to ignore it.
plain=$(mktemp -d)
out=$(printf '{"cwd":"%s","tool_input":{"file_path":"%s/src/a.ts"}}' "$plain" "$plain" \
      | bash "$HOOK" 2>/dev/null)
check "silent outside an OpenSpec project" "$out" ""

# Excluded paths never warn, even inside a project with no active change.
proj=$(mktemp -d)
mkdir -p "$proj/openspec" "$proj/docs/adr"
for excluded in "openspec/config.yaml" "docs/adr/0001-x.md" ".gitignore" "package-lock.json"; do
    out=$(printf '{"cwd":"%s","tool_input":{"file_path":"%s/%s"}}' "$proj" "$proj" "$excluded" \
          | bash "$HOOK" 2>/dev/null)
    check "silent for $excluded" "$out" ""
done

out=$(printf '{"cwd":"%s","tool_input":{"file_path":""}}' "$proj" | bash "$HOOK" 2>/dev/null)
check "silent when no file path is given" "$out" ""

out=$(printf 'not json' | bash "$HOOK" 2>/dev/null)
check "silent on malformed input" "$out" ""
printf 'not json' | bash "$HOOK" >/dev/null 2>&1
check "exits 0 on malformed input" "$?" "0"

rm -rf "$plain" "$proj"
