HOOK="plugins/dev-standards/hooks/filter-test-output.sh"
FILTER="plugins/dev-standards/hooks/lib/test-filter.js"

run() { # command
    printf '{"cwd":"/p","tool_input":{"command":"%s","description":"x"}}' "$1" | bash "$HOOK" 2>/dev/null
}

# One bare runner invocation is rewritten; the runner keeps its status.
out=$(run 'npm test')
contains "rewrites npm test"                 "$out" "updatedInput"
contains "declares the PreToolUse event"     "$out" "PreToolUse"
contains "pipes through the filter"          "$out" "test-filter.js"
contains "keeps the runner's exit status"    "$out" "pipefail"
contains "keeps the other input fields"      "$out" '"description":"x"'
contains "rewrites pytest under uv"          "$(run 'uv run pytest')"      "updatedInput"
contains "rewrites npx vitest with flags"    "$(run 'npx vitest --run')"   "updatedInput"
contains "rewrites scripts/verify"           "$(run 'scripts/verify')"     "updatedInput"
contains "rewrites ./scripts/verify"         "$(run './scripts/verify')"   "updatedInput"

# Anything the recogniser is unsure about passes through untouched.
check "silent on a chained command"          "$(run 'cd x && npm test')"   ""
check "silent on a piped command"            "$(run 'npm test | tail')"    ""
check "silent on a redirected command"       "$(run 'npm test > out.log')" ""
check "silent on a multi-line command"       "$(run 'npm test\ngit status')" ""
check "silent on an unrelated command"       "$(run 'git status')"         ""
check "silent when the runner is quoted text" "$(run 'echo npm test')"     ""
check "silent on a prefixed assignment"      "$(run 'CI=1 npm test')"      ""
check "malformed input produces no output"   "$(printf 'not json' | bash "$HOOK" 2>/dev/null)" ""
printf 'not json' | bash "$HOOK" >/dev/null 2>&1
check "malformed input still exits 0" "$?" "0"

# The filter keeps failures and the summary, drops the passing noise.
out=$(printf ' ✓ a.test.ts (3)\n ✗ b.test.ts > fails\nAssertionError: expected 1 to be 2\n    at foo (src/b.ts:3:4)\n ✓ c.test.ts (1)\n Test Files  1 failed | 1 passed\n' | node "$FILTER")
not_contains "drops passing tests"        "$out" "✓ a.test.ts"
contains     "keeps the failure"          "$out" "✗ b.test.ts"
contains     "keeps the assertion"        "$out" "AssertionError"
contains     "keeps the location"         "$out" "src/b.ts:3:4"
contains     "keeps the summary"          "$out" "Test Files"
contains     "says how much was filtered" "$out" "filtered:"

out=$(printf 'tests/test_a.py::test_ok PASSED\ntests/test_a.py::test_bad FAILED\n___ test_bad ___\nE   assert 1 == 2\n=== 1 failed, 1 passed in 0.1s ===\n' | node "$FILTER")
not_contains "drops pytest passes"        "$out" "test_ok PASSED"
contains     "keeps pytest failures"      "$out" "test_bad FAILED"
contains     "keeps pytest assertions"    "$out" "E   assert"
contains     "keeps the pytest summary"   "$out" "1 failed, 1 passed"

out=$(printf '\n== lint\n\n== unit\n ✓ a.test.ts (3)\n\nverify: all green\n' | node "$FILTER")
contains     "keeps scripts/verify step markers" "$out" "== unit"
contains     "keeps the verify verdict"          "$out" "verify: all green"

# The pipeline's status is the runner's, not the filter's.
bash -c "set -o pipefail; ( exit 3 ) 2>&1 | node $FILTER" >/dev/null 2>&1
check "a failing runner still fails through the filter" "$?" "3"
bash -c "set -o pipefail; ( printf 'ok\n' ) 2>&1 | node $FILTER" >/dev/null 2>&1
check "a passing runner still passes through the filter" "$?" "0"
