. plugins/dev-standards/hooks/lib/os-context.sh 2>/dev/null

# A directory with no OpenSpec root anywhere above it. The system temp
# directory is used rather than a repository path because this
# repository is itself inside the workspace and may gain an openspec/
# later, which would silently invert this assertion.
outside=$(mktemp -d)
os_context "$outside"
check "no root outside an OpenSpec project" "$OS_ROOT" ""
check "no changes outside an OpenSpec project" "$OS_CHANGES" "0"

# `read` treats a tab as IFS whitespace regardless of what IFS is set
# to, so without pipefail — the bash default — a leading empty field
# used to be dropped and "0" shifted into OS_ROOT instead of
# OS_CHANGES. Exercise that path by turning pipefail off, then
# restoring it — not via a subshell, because `check`'s pass/fail
# counters are plain globals and a subshell's updates to them would
# never reach this script, letting a failing regression here pass
# `tests/run-tests.sh` silently.
pipefail_state=$(shopt -po pipefail)
set +o pipefail
os_context "$outside"
check "OS_ROOT stays empty without pipefail" "$OS_ROOT" ""
eval "$pipefail_state"

rmdir "$outside"

# A directory that does not exist at all.
os_context "/definitely/not/a/directory"
check "a missing directory yields no root" "$OS_ROOT" ""
check "a missing directory yields zero changes" "$OS_CHANGES" "0"

os_context "$outside" >/dev/null 2>&1
check "os_context always returns 0" "$?" "0"
