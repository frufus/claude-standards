T="plugins/dev-standards/templates"

for p in web python; do
    f="$T/$p/config.fragment.yaml"
    contains "$p fragment declares the schema" "$(cat "$f" 2>/dev/null)" "schema: spec-driven"
    contains "$p fragment declares its profile" "$(cat "$f" 2>/dev/null)" "profile: $p"
    contains "$p CLAUDE.md points at the config" \
      "$(cat "$T/$p/CLAUDE.md" 2>/dev/null)" "openspec/config.yaml"
    # The thin-CLAUDE.md rule from spec section 4.2: orientation only.
    # A template that grows rules is the duplication the standard removes.
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
# come first in the Commands block of both profiles.
for p in web python; do
    first=$(awk '/^```/{f=!f; next} f{print; exit}' "$T/$p/CLAUDE.md" 2>/dev/null)
    contains "$p CLAUDE.md lists scripts/verify first" "$first" "scripts/verify"
    contains "$p CLAUDE.md lists scripts/dev"  "$(cat "$T/$p/CLAUDE.md" 2>/dev/null)" "scripts/dev"
done
