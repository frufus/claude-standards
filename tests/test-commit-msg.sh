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

# --- Round-1-review regressions: the subject-extraction rewrite ---

# A `-m subject -m body` is the ordinary subject-plus-body idiom. The
# FIRST -m is the subject; grading the second -m as the subject punished
# perfectly normal commits.
check "a subject-plus-body commit judges the first -m and stays silent" \
  "$(msg_out '"git commit -m \"feat: x\" -m \"body text\""')" ""

# `-am` is one of the most common commit invocations and must be checked,
# both when it is well-formed and when it is not.
check "a well-formed -am subject stays silent" \
  "$(msg_out '"git commit -am \"feat: x\""')" ""
contains "a badly-formed -am subject is reported" \
  "$(msg_out '"git commit -am \"added the thing\""')" "Conventional Commits"

# `git commit` appearing only as plain text inside another command's
# argument is not a commit at all and must never trigger a warning.
check "git commit as plain text inside another command stays silent" \
  "$(msg_out "\"echo 'git commit -m \\\"added the thing\\\"'\"")" ""

# An apostrophe in the message must not confuse the tokeniser into
# reporting a false unconventional-subject warning.
check "an apostrophe in a conventional subject stays silent" \
  "$(msg_out "\"git commit -m \\\"feat: don't break this\\\"\"")" ""

# An escaped inner quote must not truncate the captured subject: a subject
# that is long BECAUSE of what follows the escaped quote must still be
# measured in full and reported over the limit.
escq='"git commit -m \"feat: subject with an escaped \\\" quote inside it that keeps going past seventeen characters total\""'
contains "a subject with an escaped inner quote is measured in full and reported over the limit" \
  "$(msg_out "$escq")" "72"

# A real commit after a command separator is still a commit that must be
# checked, even though it is not the first command on the line.
contains "a commit after && is still checked" \
  "$(msg_out '"cd /tmp && git commit -m \"added thing\""')" "Conventional Commits"
