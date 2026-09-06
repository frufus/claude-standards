# The verify template is behaviour, not prose: which steps run, in what
# order, that it stops at the first failure, that a fitness step which
# proved nothing does not pass, and that an argument it does not know is
# refused rather than ignored. So it is run — against stub executables on
# a prepended PATH, which needs no toolchain and no network.
VT="plugins/dev-standards/templates/web/scripts/verify"

vt_setup() { # -> a fresh project directory holding the template and its stubs
    local t
    t=$(mktemp -d)
    mkdir -p "$t/scripts" "$t/bin"
    cp "$VT" "$t/scripts/verify"

    cat > "$t/bin/npm" <<'SH'
#!/usr/bin/env bash
printf 'npm %s\n' "$*" >> "$CALLS"
SH

    # depcruise is the interesting stub: it can succeed, it can fail, and
    # it can do the thing ADR-0003 is about — exit 0 having cruised
    # nothing, because the installed TypeScript is newer than it knows.
    cat > "$t/bin/npx" <<'SH'
#!/usr/bin/env bash
printf 'npx %s\n' "$*" >> "$CALLS"
[ "${1:-}" = "depcruise" ] || exit 0
if [ -n "${FAIL_DEPCRUISE:-}" ]; then
    echo "  error components-do-not-touch-repositories: src/components/a.ts -> src/repositories/b.ts"
    exit 1
fi
if [ -n "${TS7:-}" ]; then
    echo "  => Support for typescript@>=7 will follow"
    exit 0
fi
echo "2 modules, 1 dependencies cruised"
SH

    cat > "$t/scripts/dev" <<'SH'
#!/usr/bin/env bash
printf 'dev %s\n' "$*" >> "$CALLS"
[ "${1:-}" = "up" ] && echo "http://localhost:5173"
exit 0
SH

    chmod +x "$t/bin/npm" "$t/bin/npx" "$t/scripts/dev" "$t/scripts/verify"
    : > "$t/calls.log"
    printf '%s' "$t"
}

vt_verify() { # dir [args...] -> runs the template in that project
    local d="$1"; shift
    ( cd "$d" && PATH="$PWD/bin:$PATH" CALLS="$PWD/calls.log" bash scripts/verify "$@" )
}

vt_steps() { cut -d' ' -f1-3 "$1/calls.log" | tr '\n' '|'; }

# A plain run: cheap checks before expensive ones, the server up only for
# the end-to-end step, and no mutation testing at all.
vt1=$(vt_setup)
vt_verify "$vt1" >/dev/null 2>&1; vt_status=$?
check "web verify runs its steps in order" "$(vt_steps "$vt1")" \
  "npm run lint|npm run typecheck|npx depcruise src|npm run test|dev up|npm run test:e2e|dev down|"
check "a green run exits 0" "$vt_status" "0"
not_contains "a plain run never mutates" "$(cat "$vt1/calls.log")" "stryker"

# --deep adds the mutation step, and adds it last.
vt2=$(vt_setup)
vt_verify "$vt2" --deep >/dev/null 2>&1
contains "--deep adds the mutation step" "$(cat "$vt2/calls.log")" "npx stryker run"
check "--deep runs mutation after the end-to-end step" "$(vt_steps "$vt2")" \
  "npm run lint|npm run typecheck|npx depcruise src|npm run test|dev up|npm run test:e2e|npx stryker run|dev down|"

# The first failure is the verdict: nothing after it runs, and the status
# survives the EXIT trap that takes the dev server down.
vt3=$(vt_setup)
export FAIL_DEPCRUISE=1
vt_verify "$vt3" >/dev/null 2>&1; vt_status=$?
unset FAIL_DEPCRUISE
check "a failing fitness step exits 1" "$vt_status" "1"
not_contains "and no step after it runs" "$(cat "$vt3/calls.log")" "npm run test"

# ADR-0003: dependency-cruiser exits 0 and cruises nothing on a TypeScript
# it does not support. A step that proved nothing must not pass.
vt4=$(vt_setup)
export TS7=1
vt_err=$(vt_verify "$vt4" 2>&1 >/dev/null); vt_status=$?
unset TS7
check "a fitness step that cruised no TypeScript fails" "$vt_status" "1"
contains "and points at the reasoning"    "$vt_err" "ADR-0003"

# An argument it does not understand is refused, not silently treated as
# a plain run — the difference between a deep run and a typo.
vt5=$(vt_setup)
vt_verify "$vt5" --quick >/dev/null 2>&1; vt_status=$?
check "an unknown argument exits 2" "$vt_status" "2"
check "and nothing ran"             "$(cat "$vt5/calls.log")" ""

# The python template takes no arguments at all.
vt6=$(mktemp -d)
mkdir -p "$vt6/scripts"
cp plugins/dev-standards/templates/python/scripts/verify "$vt6/scripts/verify"
( cd "$vt6" && bash scripts/verify --deep ) >/dev/null 2>&1
check "python verify refuses an unknown argument" "$?" "2"

rm -rf "$vt1" "$vt2" "$vt3" "$vt4" "$vt5" "$vt6"
