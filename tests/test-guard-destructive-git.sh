HOOK="plugins/dev-standards/hooks/guard-destructive-git.sh"

guard() { printf '{"tool_input":{"command":"%s"}}' "$1" | bash "$HOOK" 2>/dev/null; }

out=$(guard 'git push --force origin main')
contains "denies a force-push"              "$out" '"permissionDecision":"deny"'
contains "the reason names the command"     "$out" "force-push"
contains "the reason names the way through" "$out" "CLAUDE_STANDARDS_ALLOW_DESTRUCTIVE=1"
contains "declares the PreToolUse event"    "$out" "PreToolUse"
contains "denies a hard reset"              "$(guard 'git reset --hard')" '"permissionDecision":"deny"'
contains "denies a clean"                   "$(guard 'git clean -fdx')" '"permissionDecision":"deny"'
contains "denies a branch force-delete"     "$(guard 'git branch -D x')" '"permissionDecision":"deny"'
check "silent on a plain push"              "$(guard 'git push')" ""
check "silent on a commit"                  "$(guard 'git commit -m \"feat: x\"')" ""
check "silent when the human said so"       "$(guard 'CLAUDE_STANDARDS_ALLOW_DESTRUCTIVE=1 git push --force')" ""
check "silent when the override prefixes a later segment" \
  "$(guard 'git fetch && CLAUDE_STANDARDS_ALLOW_DESTRUCTIVE=1 git reset --hard origin/main')" ""
contains "merely mentioning the override does not excuse the push" \
  "$(guard 'git commit -m \"chore: CLAUDE_STANDARDS_ALLOW_DESTRUCTIVE=1\" && git push --force')" \
  '"permissionDecision":"deny"'
printf 'not json' | bash "$HOOK" >/dev/null 2>&1
check "exits 0 on malformed input"          "$?" "0"
check "malformed input produces no output"  "$(printf 'not json' | bash "$HOOK" 2>/dev/null)" ""

contains "hooks.json registers the guard on Bash" \
  "$(node -p 'JSON.stringify(require("./plugins/dev-standards/hooks/hooks.json").hooks.PreToolUse.filter(h=>h.matcher==="Bash").flatMap(h=>h.hooks.map(x=>x.command)))' 2>/dev/null)" \
  "guard-destructive-git.sh"
contains "ADR-0002 records the exception" "$(cat docs/adr/0002-destructive-git-is-the-one-hook-that-denies.md 2>/dev/null)" "## Decisions"
contains "README states the exception"    "$(cat README.md 2>/dev/null)" "one exception"
