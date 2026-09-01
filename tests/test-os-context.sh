. plugins/dev-standards/hooks/lib/os-context.sh 2>/dev/null

# A directory with no OpenSpec root anywhere above it. The system temp
# directory is used rather than a repository path because this
# repository is itself inside the workspace and may gain an openspec/
# later, which would silently invert this assertion.
outside=$(mktemp -d)
os_context "$outside"
check "no root outside an OpenSpec project" "$OS_ROOT" ""
check "no changes outside an OpenSpec project" "$OS_CHANGES" "0"
rmdir "$outside"

# A directory that does not exist at all.
os_context "/definitely/not/a/directory"
check "a missing directory yields no root" "$OS_ROOT" ""
check "a missing directory yields zero changes" "$OS_CHANGES" "0"

os_context "$outside" >/dev/null 2>&1
check "os_context always returns 0" "$?" "0"
