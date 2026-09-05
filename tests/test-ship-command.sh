LIB="plugins/dev-standards/hooks/lib/ship-command.js"

kind() { printf '%s' "$1" | node "$LIB" 2>/dev/null; }

check "git push is a push"                    "$(kind 'git push -u origin claude/x')" "push"
check "gh pr create is a pr"                  "$(kind 'gh pr create --fill')" "pr"
check "openspec archive is an archive"        "$(kind 'openspec archive 2026-09-05-x')" "archive"
check "a ship command after && is recognised" "$(kind 'git add -A && git push')" "push"
check "a ship command after ; is recognised"  "$(kind 'cd /x; gh pr create')" "pr"
check "git status is nothing"                 "$(kind 'git status')" ""
check "openspec list is nothing"              "$(kind 'openspec list --json')" ""
check "gh pr view is nothing"                 "$(kind 'gh pr view 12')" ""
check "the words inside another command are nothing" "$(kind "echo 'git push'")" ""
check "empty input is nothing"                "$(kind '')" ""
printf 'git push' | node "$LIB" >/dev/null 2>&1
check "always exits 0"                        "$?" "0"

# The tokeniser now lives in its own module; the commit hook must still
# behave exactly as before (its own tests cover that) and must load it.
contains "git-subject requires the shared tokeniser" \
  "$(cat plugins/dev-standards/hooks/lib/git-subject.js 2>/dev/null)" 'require("./tokenize.js")'
