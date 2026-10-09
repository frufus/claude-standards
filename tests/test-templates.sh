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

    # The project settings enable the standard and the language server
    # for every clone, so neither depends on the machine (ADR-0004).
    cs=$(cat "$T/$p/claude-settings.json" 2>/dev/null)
    contains "$p settings enable the standard"        "$cs" "dev-standards@claude-standards"
    contains "$p settings enable code intelligence"   "$cs" "-lsp@claude-plugins-official"
    contains "$p settings register the marketplace"   "$cs" "frufus/claude-standards"
    check "$p settings are valid JSON" \
      "$(node -e 'JSON.parse(require("fs").readFileSync(process.argv[1],"utf8"));console.log("ok")' "$T/$p/claude-settings.json" 2>/dev/null)" "ok"
done
contains "web settings pick the TypeScript server" "$(cat "$T/web/claude-settings.json" 2>/dev/null)" "typescript-lsp"
contains "python settings pick pyright"           "$(cat "$T/python/claude-settings.json" 2>/dev/null)" "pyright-lsp"

# The global layer ships the settings Claude Code reads from ~/.claude/:
# a plugin cannot set env or a status line itself (ADR-0004).
gs=$(cat "$T/global/settings.json" 2>/dev/null)
contains "global settings default subagents to haiku" "$gs" '"CLAUDE_CODE_SUBAGENT_MODEL": "haiku"'

# Outside the Anthropic API the tier aliases resolve to 4.5 or 4.6, so the
# standard pins all three to the current generation (ADR-0005). The three
# pins are bumped together: a half-done bump fails here.
pins=$(node -e '
  const env = JSON.parse(require("fs").readFileSync(process.argv[1], "utf8")).env || {};
  const ids = ["HAIKU", "SONNET", "OPUS"].map((t) => env["ANTHROPIC_DEFAULT_" + t + "_MODEL"] || "");
  const tiers = ids.every((id, i) => id.startsWith("claude-" + ["haiku", "sonnet", "opus"][i] + "-"));
  const gens = new Set(ids.map((id) => id.replace(/^claude-[a-z]+-/, "")));
  console.log(tiers && gens.size === 1 && !gens.has("") ? "ok " + [...gens][0] : "bad " + ids.join(","));
' "$T/global/settings.json" 2>/dev/null)
check "global settings pin all three tiers to one generation" "${pins%% *}" "ok"
contains "global settings pin the haiku alias to Haiku 5.5"   "$gs" '"ANTHROPIC_DEFAULT_HAIKU_MODEL": "claude-haiku-5-5"'
contains "global settings pin the sonnet alias to Sonnet 5.5" "$gs" '"ANTHROPIC_DEFAULT_SONNET_MODEL": "claude-sonnet-5-5"'
contains "global settings pin the opus alias to Opus 5.5"     "$gs" '"ANTHROPIC_DEFAULT_OPUS_MODEL": "claude-opus-5-5"'
# FORCE would make Claude Code ignore the verifier's per-invocation model.
not_contains "global settings do not force one subagent model" "$gs" "CLAUDE_CODE_SUBAGENT_MODEL_FORCE"
contains "global settings set an effort default"      "$gs" '"effortLevel"'
contains "global settings configure the status line"  "$gs" '"statusLine"'
check "global settings are valid JSON" \
  "$(node -e 'JSON.parse(require("fs").readFileSync(process.argv[1],"utf8"));console.log("ok")' "$T/global/settings.json" 2>/dev/null)" "ok"
sl=$(printf '{"model":{"display_name":"Sonnet 5"},"context_window":{"used_percentage":42.4,"context_window_size":200000},"cost":{"total_cost_usd":1.234}}' | node "$T/global/statusline.js" 2>/dev/null)
contains "status line shows the model"        "$sl" "Sonnet 5"
contains "status line shows context use"      "$sl" "42% of 200k"
contains "status line shows the session cost" "$sl" '$1.23'
check "status line survives malformed input" "$(printf 'not json' | node "$T/global/statusline.js" 2>/dev/null)" " · ctx ░░░░░░░░░░ 0% of ?"

# The sensor configs are templates, not prose in a skill: step 8 copies
# them, so a project gets the rule ADR-0003 adopted rather than whatever
# a session invents on the day.
dc=$(cat "$T/web/.dependency-cruiser.cjs" 2>/dev/null)
contains "web fitness config states the one rule"   "$dc" "components-do-not-touch-repositories"
contains "web fitness config forbids the direction" "$dc" '^src/components'
contains "web fitness config names the forbidden target" "$dc" '^src/repositories'
contains "web fitness config sees TypeScript imports" "$dc" "tsPreCompilationDeps"
dclines=$(wc -l < "$T/web/.dependency-cruiser.cjs" 2>/dev/null || echo 999)
check "web fitness config stays under the 20-line bound" "$([ "$dclines" -le 20 ] && echo ok)" "ok"

st=$(cat "$T/web/stryker.config.json" 2>/dev/null)
contains "stryker config runs vitest"        "$st" '"testRunner": "vitest"'
contains "stryker config has a break floor"  "$st" '"break": 50'
check "stryker config is valid JSON" \
  "$(node -e 'JSON.parse(require("fs").readFileSync(process.argv[1],"utf8"));console.log("ok")' "$T/web/stryker.config.json" 2>/dev/null)" "ok"

il=$(cat "$T/python/importlinter.fragment.toml" 2>/dev/null)
contains "python fitness fragment declares the table" "$il" "[tool.importlinter]"
contains "python fitness fragment names a contract"   "$il" "[[tool.importlinter.contracts]]"
contains "python fitness fragment forbids the direction" "$il" "<package>.adapters"
contains "python fitness fragment leaves the package to fill in" "$il" "root_package = \"<package>\""

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
contains "PR template puts hooks in the high tier" "$pr" "hooks)"
contains "PR template asks where to look"    "$pr" "human attention"
