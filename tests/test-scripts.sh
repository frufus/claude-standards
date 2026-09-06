T="plugins/dev-standards/templates"

# The scripts are the deterministic edges of the procedure: the agent
# runs them instead of rediscovering the toolchain each session. They
# are bash because the hooks already are, and they must parse before
# they are trusted.
for p in web python; do
    for s in dev verify; do
        f="$T/$p/scripts/$s"
        check "$p/scripts/$s has a bash shebang" "$(head -n 1 "$f" 2>/dev/null)" "#!/usr/bin/env bash"
        check "$p/scripts/$s parses" "$(bash -n "$f" 2>/dev/null && echo ok)" "ok"
        check "$p/scripts/$s has no CR bytes" "$(tr -cd '\r' < "$f" 2>/dev/null | wc -c | tr -d ' ')" "0"
    done
    dev=$(cat "$T/$p/scripts/dev" 2>/dev/null)
    contains "$p/scripts/dev handles up"   "$dev" "up)"
    contains "$p/scripts/dev handles down" "$dev" "down)"
    contains "$p/scripts/dev is idempotent" "$dev" "already up"
done

# The order is the contract: cheap checks before expensive ones, so a
# lint failure never waits on an end-to-end run.
labels() { grep -E '^run ' "$T/$1/scripts/verify" 2>/dev/null | awk '{print $2}' | tr '\n' ' '; }
check "web verify runs lint, typecheck, unit, e2e in order" \
  "$(labels web)" "lint typecheck unit e2e "
check "python verify runs lint, format, typecheck, unit in order" \
  "$(labels python)" "lint format typecheck unit "

web=$(cat "$T/web/scripts/verify" 2>/dev/null)
contains "web verify brings the dev server up for e2e" "$web" "scripts/dev up"
contains "web verify takes the server down again"      "$web" "scripts/dev down"
contains "web verify stops at the first failure"       "$web" "exit 1"

# Under Git Bash a background job's pid is an MSYS pid that taskkill does
# not know, and netstat's state column is localised. The listener is found
# by its port and zero foreign address, never by the word LISTENING.
contains "web dev finds the listener by port"       "$(cat "$T/web/scripts/dev" 2>/dev/null)" "netstat -ano"
contains "web dev matches a zero foreign address"   "$(cat "$T/web/scripts/dev" 2>/dev/null)" ':0$/'
not_contains "web dev never matches the localised state word" "$(cat "$T/web/scripts/dev" 2>/dev/null)" '/LISTENING/'
contains "web dev warns when it cannot find the listener" "$(cat "$T/web/scripts/dev" 2>/dev/null)" "could not find the listener"
contains "web dev confirms the server is gone after down"  "$(cat "$T/web/scripts/dev" 2>/dev/null)" "still answers"

contains ".gitattributes keeps the script templates LF" \
  "$(cat .gitattributes 2>/dev/null)" "templates/*/scripts/* text eol=lf"
