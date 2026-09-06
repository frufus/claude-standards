T="plugins/dev-standards/templates"

for p in web python; do
    f="$T/$p/config.fragment.yaml"
    contains "$p fragment declares the schema" "$(cat "$f" 2>/dev/null)" "schema: spec-driven"
    contains "$p fragment declares its profile" "$(cat "$f" 2>/dev/null)" "profile: $p"
    # AGENTS.md is the instruction file every tool reads; CLAUDE.md is an
    # import plus Claude-only notes. The config pointer and the commands
    # therefore live in AGENTS.md, and CLAUDE.md must start with the import.
    a=$(cat "$T/$p/AGENTS.md" 2>/dev/null)
    contains "$p AGENTS.md points at the config" "$a" "openspec/config.yaml"
    contains "$p AGENTS.md says work starts as a proposal" "$a" "change proposal"
    contains "$p AGENTS.md names the always boundary" "$a" "- Always:"
    contains "$p AGENTS.md names the ask boundary"    "$a" "- Ask:"
    contains "$p AGENTS.md names the never boundary"  "$a" "- Never:"
    contains "$p AGENTS.md carries the test ratchet"  "$a" "weaken a test"
    alines=$(wc -l < "$T/$p/AGENTS.md" 2>/dev/null || echo 999)
    check "$p AGENTS.md stays within its budget" "$([ "$alines" -le 60 ] && echo ok)" "ok"
    check "$p CLAUDE.md imports AGENTS.md on its first line" "$(head -n 1 "$T/$p/CLAUDE.md" 2>/dev/null)" "@AGENTS.md"
    not_contains "$p CLAUDE.md does not repeat the commands" "$(cat "$T/$p/CLAUDE.md" 2>/dev/null)" "scripts/verify"
    lines=$(wc -l < "$T/$p/CLAUDE.md" 2>/dev/null || echo 999)
    check "$p CLAUDE.md stays thin" "$([ "$lines" -le 40 ] && echo ok)" "ok"
done

contains "shared rules cover proposals" "$(cat "$T/shared/config.rules.yaml" 2>/dev/null)" "proposal:"
contains "shared rules cover specs"     "$(cat "$T/shared/config.rules.yaml" 2>/dev/null)" "specs:"
contains "shared rules cover tasks"     "$(cat "$T/shared/config.rules.yaml" 2>/dev/null)" "tasks:"

adr=$(cat "$T/adr/TEMPLATE.md" 2>/dev/null)
contains "ADR template has Context"      "$adr" "## Context"
contains "ADR template has Decisions"    "$adr" "## Decisions"
contains "ADR template has Consequences" "$adr" "## Consequences"

# Every fragment must parse as YAML — a broken one produces a project
# whose config the openspec CLI silently refuses.
for f in "$T/shared/config.rules.yaml" "$T/web/config.fragment.yaml" "$T/python/config.fragment.yaml"; do
    n=$(grep -c "$(printf '^\t')" "$f" 2>/dev/null)
    check "$(basename "$(dirname "$f")")/$(basename "$f") has no tab indentation" \
      "${n:-0}" "0"
done

web=$(cat "$T/web/CLAUDE.md" 2>/dev/null)
contains "web template names the design system" "$web" "@frufus/design-system"
contains "web template forbids redeclaring its values" "$web" "redeclare"
contains "web template points at the component skill" "$web" "component"

# The scripts are the first thing a session should reach for, so they
# come first in the Commands block of both AGENTS.md files.
for p in web python; do
    first=$(awk '/^```/{f=!f; next} f{print; exit}' "$T/$p/AGENTS.md" 2>/dev/null)
    contains "$p AGENTS.md lists scripts/verify first" "$first" "scripts/verify"
    contains "$p AGENTS.md names the fitness step" "$first" "fitness"
    contains "$p AGENTS.md lists scripts/dev"  "$(cat "$T/$p/AGENTS.md" 2>/dev/null)" "scripts/dev"
done

rules=$(cat "$T/shared/config.rules.yaml" 2>/dev/null)
contains "shared rules update progress.md on apply"       "$rules" "progress.md"
contains "shared rules require verification on archive"   "$rules" "verification.md"

# What reaches a reviewer must not depend on the session. The template asks
# for the four things the review literature agrees on.
pr=$(cat "$T/shared/pull_request_template.md" 2>/dev/null)
contains "PR template asks for intent"       "$pr" "## Intent"
contains "PR template asks for proof"        "$pr" "## Proof"
contains "PR template links verification"    "$pr" "verification.md"
contains "PR template asks for provenance"   "$pr" "Agent-written"
contains "PR template asks for a risk tier"  "$pr" "Risk tier"
contains "PR template names the high tier"   "$pr" "untrusted input"
contains "PR template asks where to look"    "$pr" "human attention"
