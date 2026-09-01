HOOK="plugins/dev-standards/hooks/check-commit-msg.sh"

msg_out() { printf '{"tool_input":{"command":%s}}' "$1" | bash "$HOOK" 2>/dev/null; }

check "a conventional subject passes" \
  "$(msg_out '"git commit -m \"feat: add the thing\""')" ""
check "a scoped subject passes" \
  "$(msg_out '"git commit -m \"fix(parser): handle empty input\""')" ""
check "a breaking-change marker passes" \
  "$(msg_out '"git commit -m \"feat!: drop the old format\""')" ""

contains "an unconventional subject is reported" \
  "$(msg_out '"git commit -m \"added the thing\""')" "Conventional Commits"

long=$(printf 'feat: %0.sx' $(seq 1 80))
contains "an over-long subject is reported" \
  "$(msg_out "\"git commit -m \\\"$long\\\"\"")" "72"

check "a non-commit git command is ignored" \
  "$(msg_out '"git status --short"')" ""
check "an unrelated command is ignored" \
  "$(msg_out '"npm run test"')" ""
check "a heredoc message is out of reach and stays silent" \
  "$(msg_out '"git commit -F -"')" ""

not_contains "never denies" \
  "$(msg_out '"git commit -m \"added the thing\""')" "permissionDecision"

printf 'not json' | bash "$HOOK" >/dev/null 2>&1
check "exits 0 on malformed input" "$?" "0"
