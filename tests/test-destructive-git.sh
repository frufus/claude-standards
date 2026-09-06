LIB="plugins/dev-standards/hooks/lib/destructive-git.js"

kind() { printf '%s' "$1" | node "$LIB" 2>/dev/null; }

check "git push --force"             "$(kind 'git push --force origin main')" "force-push"
check "git push -f"                  "$(kind 'git push -f')" "force-push"
check "git push --force-with-lease"  "$(kind 'git push --force-with-lease')" "force-push"
check "git reset --hard"             "$(kind 'git reset --hard HEAD~1')" "hard-reset"
check "git clean -fd"                "$(kind 'git clean -fd')" "clean"
check "git clean --force"            "$(kind 'git clean --force')" "clean"
check "git branch -D"                "$(kind 'git branch -D claude/x')" "branch-delete"
check "after && is still seen"       "$(kind 'git fetch && git reset --hard origin/main')" "hard-reset"
check "on its own line is still seen" "$(kind "$(printf 'git add -A\ngit push --force')")" "force-push"
check "plain push is nothing"        "$(kind 'git push -u origin claude/x')" ""
check "soft reset is nothing"        "$(kind 'git reset --soft HEAD~1')" ""
check "clean dry run is nothing"     "$(kind 'git clean -n')" ""
check "branch -d is nothing"         "$(kind 'git branch -d merged')" ""
check "quoted text is nothing"       "$(kind "echo 'git push --force'")" ""
check "empty input is nothing"       "$(kind '')" ""
check "a -C path before the subcommand is skipped"   "$(kind 'git -C sub reset --hard')" "hard-reset"
check "--no-pager before the subcommand is skipped"  "$(kind 'git --no-pager push --force')" "force-push"
check "-c key=value before the subcommand is skipped" "$(kind 'git -c core.x=1 clean -fd')" "clean"
check "--force-if-includes alone is not a force"     "$(kind 'git push --force-if-includes')" ""
check "--force-with-lease with a value is a force"   "$(kind 'git push --force-with-lease=main:abc')" "force-push"

# The same four shapes, spelled the way a shell actually accepts them. A
# guard that only sees the canonical spelling is a guard with a hole.
check "a short cluster carrying f is a force"        "$(kind 'git push -fu origin main')" "force-push"
check "the same cluster the other way round"         "$(kind 'git push -uf origin main')" "force-push"
check "branch -Df is a force-delete"                 "$(kind 'git branch -Df x')" "branch-delete"
check "branch -fd is a force-delete"                 "$(kind 'git branch -fd x')" "branch-delete"
check "branch -d -f is a force-delete"               "$(kind 'git branch -d -f x')" "branch-delete"
check "branch --force -d is a force-delete"          "$(kind 'git branch --force -d x')" "branch-delete"
check "a + refspec is a force-push"                  "$(kind 'git push origin +main')" "force-push"

# A command position survives a leading assignment, a transparent prefix,
# a subshell, a brace group, a compound statement and an absolute path.
check "a leading environment assignment"             "$(kind 'GIT_TRACE=1 git reset --hard')" "hard-reset"
check "a quoted leading assignment"                  "$(kind 'GIT_SSH_COMMAND="ssh -i k" git push --force')" "force-push"
check "inside a subshell"                            "$(kind '(git push --force)')" "force-push"
check "inside a brace group"                         "$(kind '{ git push --force; }')" "force-push"
check "after then"                                   "$(kind 'if true; then git push --force; fi')" "force-push"
check "inside a for loop body"                       "$(kind 'for b in x; do git branch -D $b; done')" "branch-delete"
check "behind time"                                  "$(kind 'time git clean -fd')" "clean"
check "behind command"                               "$(kind 'command git reset --hard')" "hard-reset"
check "behind env with an assignment"                "$(kind 'env FOO=1 git reset --hard')" "hard-reset"
check "git by absolute path"                         "$(kind '/usr/bin/git reset --hard')" "hard-reset"

# The human's way through is a prefix on the segment that runs the
# command, not a string anywhere in the line.
check "the override silences its own segment"        "$(kind 'CLAUDE_STANDARDS_ALLOW_DESTRUCTIVE=1 git push --force')" ""
check "the override silences a later segment"        "$(kind 'git fetch && CLAUDE_STANDARDS_ALLOW_DESTRUCTIVE=1 git reset --hard origin/main')" ""
check "mentioning the override does not silence"     "$(kind 'git commit -m "chore: CLAUDE_STANDARDS_ALLOW_DESTRUCTIVE=1" && git push --force')" "force-push"

printf 'git push --force' | node "$LIB" >/dev/null 2>&1
check "always exits 0"               "$?" "0"
