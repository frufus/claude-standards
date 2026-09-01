#!/usr/bin/env bash
# Assertions for the hook and manifest tests. Deliberately tiny: the
# things under test are shell scripts, so the harness is shell too, and
# nothing here needs installing.
CHECKS_RUN=0
CHECKS_FAILED=0

_pass() { printf '  ok   %s\n' "$1"; }
_fail() { CHECKS_FAILED=$((CHECKS_FAILED + 1)); printf '  FAIL %s\n' "$1" >&2; }

check() { # label actual expected
    CHECKS_RUN=$((CHECKS_RUN + 1))
    if [ "$2" = "$3" ]; then _pass "$1"; else _fail "$1 — expected [$3], got [$2]"; fi
}

contains() { # label haystack needle
    CHECKS_RUN=$((CHECKS_RUN + 1))
    case "$2" in *"$3"*) _pass "$1" ;; *) _fail "$1 — [$2] lacks [$3]" ;; esac
}

not_contains() { # label haystack needle
    CHECKS_RUN=$((CHECKS_RUN + 1))
    case "$2" in *"$3"*) _fail "$1 — [$2] contains [$3]" ;; *) _pass "$1" ;; esac
}

summary() {
    printf '\n%s checks, %s failed\n' "$CHECKS_RUN" "$CHECKS_FAILED"
    [ "$CHECKS_FAILED" -eq 0 ]
}
