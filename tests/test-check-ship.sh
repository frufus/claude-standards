HOOK="plugins/dev-standards/hooks/check-ship.sh"

ship() { # cwd command
    printf '{"cwd":"%s","tool_input":{"command":"%s"}}' "$1" "$2" | bash "$HOOK" 2>/dev/null
}

# A change in flight with no verification.md at all.
p=$(mktemp -d)
mkdir -p "$p/openspec/changes/2026-09-05-thing" "$p/openspec/changes/archive/old"
printf '# Proposal\n\n### Non-Goals\n- none\n' > "$p/openspec/changes/2026-09-05-thing/proposal.md"
out=$(ship "$p" "git push -u origin claude/thing")
contains "reports a push of an unverified change"    "$out" "2026-09-05-thing"
contains "names the missing artefact"                "$out" "verification.md"
contains "points at the verify skill"                "$out" "verify"
contains "declares the PreToolUse event"             "$out" "PreToolUse"
not_contains "never denies"                          "$out" "permissionDecision"
not_contains "the archive directory is not a change" "$out" "old"
contains "reports on gh pr create too"               "$(ship "$p" "gh pr create --fill")" "verification.md"
contains "reports on openspec archive too"           "$(ship "$p" "openspec archive 2026-09-05-thing")" "verification.md"
check "silent on a non-ship command"                 "$(ship "$p" "git status")" ""
check "silent when git push is only quoted text"     "$(ship "$p" "echo git push")" ""
contains "a push on the second line of a command is still checked" "$(ship "$p" 'git add -A\ngit push')" "verification.md"

# From a nested cwd the project is still found.
mkdir -p "$p/src/deep"
contains "finds the project above a nested cwd" "$(ship "$p/src/deep" "git push")" "verification.md"

# A verification with an unanswered finding.
printf '# Verification\n\n### a — fail\nFinding: broke\n' > "$p/openspec/changes/2026-09-05-thing/verification.md"
out=$(ship "$p" "git push")
contains "reports an unanswered finding" "$out" "1 unanswered"

# Once answered, silence.
printf '# Verification\n\n### a — fail\nFinding: broke\nAnswer: fixed in fix: x\n' > "$p/openspec/changes/2026-09-05-thing/verification.md"
check "silent once every finding is answered" "$(ship "$p" "git push")" ""

# The proposal rules are checked at the same moment: when the work ships.
q2=$(mktemp -d)
mkdir -p "$q2/openspec/changes/2026-09-06-loose/specs/x"
printf '# Proposal\n' > "$q2/openspec/changes/2026-09-06-loose/proposal.md"
printf '### Requirement: R\n\n#### Scenario: only one\n- WHEN a\n- THEN b\n' > "$q2/openspec/changes/2026-09-06-loose/specs/x/spec.md"
printf -- '- [ ] 1. Unverified task\n' > "$q2/openspec/changes/2026-09-06-loose/tasks.md"
printf '# Verification\n\n### a — pass\n' > "$q2/openspec/changes/2026-09-06-loose/verification.md"
out=$(ship "$q2" "git push")
contains "reports a shipped proposal without Non-Goals"      "$out" "Non-Goals"
contains "reports a requirement missing its unhappy path"   "$out" "unhappy path"
contains "reports a task without a verification statement"  "$out" "Unverified task"
contains "the lint lines name the change"                   "$out" "2026-09-06-loose"
not_contains "the lint never denies"                        "$out" "permissionDecision"
rm -rf "$q2"

# No change in flight: nothing to say, whatever the command.
q=$(mktemp -d)
mkdir -p "$q/openspec/changes/archive"
check "silent with nothing in flight" "$(ship "$q" "git push")" ""

# Outside an OpenSpec project entirely.
r=$(mktemp -d)
check "silent outside an OpenSpec project" "$(ship "$r" "git push")" ""

out=$(printf 'not json' | bash "$HOOK" 2>/dev/null)
check "malformed input produces no output" "$out" ""
printf 'not json' | bash "$HOOK" >/dev/null 2>&1
check "malformed input still exits 0" "$?" "0"

# Registration: the hook must be wired to Bash in hooks.json, or it
# never runs and every assertion above is theatre.
contains "hooks.json registers check-ship on Bash" \
  "$(node -p 'JSON.stringify(require("./plugins/dev-standards/hooks/hooks.json").hooks.PreToolUse.filter(h=>h.matcher==="Bash").flatMap(h=>h.hooks.map(x=>x.command)))' 2>/dev/null)" \
  "check-ship.sh"

rm -rf "$p" "$q" "$r"
