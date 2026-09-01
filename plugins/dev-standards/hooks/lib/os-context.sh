#!/usr/bin/env bash
# Resolves OpenSpec state for a directory.

os_context() { # directory -> sets OS_ROOT, OS_CHANGES
    OS_ROOT=""
    OS_CHANGES=0

    local lib line
    lib="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/json-fields.js"

    command -v openspec >/dev/null 2>&1 || return 0
    [ -d "$1" ] || return 0

    # One openspec spawn, one node spawn. `openspec list --json` exits 0
    # both inside and outside a project and reports the difference as
    # root: null, so the exit code carries no information and only the
    # payload is read.
    line=$( (cd "$1" && openspec list --json 2>/dev/null) \
            | node "$lib" root.path changes.length 2>/dev/null ) || return 0

    IFS=$'\t' read -r OS_ROOT OS_CHANGES <<< "$line"
    [ -n "$OS_CHANGES" ] || OS_CHANGES=0
    return 0
}
