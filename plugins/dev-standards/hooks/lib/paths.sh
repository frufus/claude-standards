#!/usr/bin/env bash
# Path classification for the source-guard hook.

rel_path() { # absolute_file project_root -> path relative to root
    local file="${1//\\//}" root="${2//\\//}"
    file=$(printf '%s' "$file" | tr '[:upper:]' '[:lower:]')
    root=$(printf '%s' "$root" | tr '[:upper:]' '[:lower:]')
    root="${root%/}"
    # Case is folded before the prefix strip because the same directory
    # reaches a hook as both `C:\proj` and `c:/proj` depending on who
    # called it. A failed strip would leave an absolute path, which
    # is_source_path would then read as a source file outside every
    # exclusion — the guard would fire on documentation.
    case "$file" in
        "$root"/*) file="${file#"$root"/}" ;;
    esac
    printf '%s' "$file"
}

is_source_path() { # relative_path -> 0 when it is source
    case "$1" in
        openspec/*|docs/*|.claude/*) return 1 ;;
        .*|*/.*) return 1 ;;
        *.lock|*-lock.json|*.lockb) return 1 ;;
        *) return 0 ;;
    esac
}
