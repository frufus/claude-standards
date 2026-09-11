#!/usr/bin/env bash
# PreToolUse on Bash: when the command is a test runner on its own —
# vitest, pytest or scripts/verify, with no pipe, chain or redirection —
# rewrites it so its output reaches the session through a filter that
# keeps failures and the summary and drops the passing noise. The
# runner's exit status is preserved (pipefail; the filter always exits
# 0), so the verdict is unchanged; only the transcript is shorter.
#
# Anything the recogniser is unsure about passes through untouched: a
# hook that rewrites the wrong command costs more than the tokens it
# saves. ADR-0004 records why this lives here and not in a third-party
# compression plugin.
set -uo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

input=$(cat)
command_line=$(printf '%s' "$input" | node "$HERE/lib/json-fields.js" --raw tool_input.command 2>/dev/null)
[ -n "${command_line:-}" ] || exit 0

kind=$(printf '%s' "$command_line" | node "$HERE/lib/test-command.js" 2>/dev/null)
[ "$kind" = "filter" ] || exit 0

printf '%s' "$input" | node "$HERE/lib/rewrite-test-command.js" "$HERE/lib/test-filter.js" 2>/dev/null
exit 0
