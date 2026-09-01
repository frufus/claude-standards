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

    # `read` always treats a tab as IFS whitespace no matter what IFS is
    # set to, so a leading empty field (no OpenSpec root) gets silently
    # collapsed and the change count shifts into OS_ROOT instead. Split
    # on the literal tab with parameter expansion, which does not.
    case "$line" in
        *$'\t'*)
            OS_ROOT="${line%%$'\t'*}"
            OS_CHANGES="${line#*$'\t'}"
            ;;
        *)
            # Defensive: json-fields.js always emits a tab-joined line,
            # so a line with none is malformed output, not a real
            # single-field result — treat it as no usable data at all.
            OS_ROOT=""
            OS_CHANGES=""
            ;;
    esac
    [ -n "$OS_CHANGES" ] || OS_CHANGES=0
    return 0
}
