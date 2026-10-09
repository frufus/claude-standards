S="plugins/dev-standards/skills"

# A skill whose frontmatter is malformed does not fail loudly — it simply
# never loads. Asserting the shape here is the only cheap way to catch it.
for skill in adr sdd-change new-project component verify; do
    f="$S/$skill/SKILL.md"
    check "$skill starts with frontmatter" "$(head -n 1 "$f" 2>/dev/null)" "---"
    contains "$skill declares its name"        "$(cat "$f" 2>/dev/null)" "name: $skill"
    contains "$skill declares a description"   "$(cat "$f" 2>/dev/null)" "description:"
    check "$skill closes its frontmatter" \
      "$(sed -n '2,12p' "$f" 2>/dev/null | grep -c '^---$')" "1"
done

contains "adr points at the template" "$(cat "$S/adr/SKILL.md" 2>/dev/null)" "templates/adr/TEMPLATE.md"
contains "sdd-change covers archiving" "$(cat "$S/sdd-change/SKILL.md" 2>/dev/null)" "openspec archive"
contains "sdd-change requires approval before implementing" \
  "$(cat "$S/sdd-change/SKILL.md" 2>/dev/null)" "approved"

np=$(cat "$S/new-project/SKILL.md" 2>/dev/null)
contains "new-project names both profiles"   "$np" "web"
contains "new-project names the python profile" "$np" "python"
contains "new-project initialises openspec"  "$np" "openspec init"
contains "new-project creates the ADR home"  "$np" "docs/adr"
contains "new-project ends with the conformance check" "$np" "conformance"

cp=$(cat "$S/component/SKILL.md" 2>/dev/null)
contains "component decides where it belongs first"  "$cp" "where it belongs"
contains "component names the rule of two"           "$cp" "rule of two"
contains "component excepts accessibility behaviour" "$cp" "accessibility behaviour"
contains "component prefers the platform"            "$cp" "platform"
contains "component says names are a contract"       "$cp" "breaking change"
contains "component says what is not a component"    "$cp" "What is not a new component"

contains "new-project prescribes the design system" "$np" "@frufus/design-system"
contains "new-project gives the opt-out a written form" "$np" "ADR"
contains "new-project points at the component skill" "$np" "component"

contains "new-project writes the scripts"        "$np" "scripts/verify"
contains "new-project makes them executable in git" "$np" "update-index --chmod=+x"
contains "new-project stages the scripts before chmod" "$np" "git add scripts/dev scripts/verify"
contains "new-project gitignores the dev pidfile" "$np" ".dev.pid"
contains "new-project keeps the scripts LF on clone"   "$np" "scripts/* text eol=lf"
contains "new-project keeps Playwright specs out of Vitest" "$np" 'configDefaults.exclude, "e2e/**"'
contains "new-project writes AGENTS.md"            "$np" "templates/<profile>/AGENTS.md"
contains "new-project imports it from CLAUDE.md"   "$np" "@AGENTS.md"
contains "new-project writes the PR template" "$np" "pull_request_template.md"

# Step 8 installs the sensors rather than expecting their configs to
# appear: a step that expects a file is a step that silently does not run.
contains "new-project installs dependency-cruiser"   "$np" "dependency-cruiser"
contains "new-project installs the Stryker runner"   "$np" "@stryker-mutator/vitest-runner"
contains "new-project installs import-linter"        "$np" "import-linter"
contains "new-project pins TypeScript to 6"          "$np" "typescript@^6"
contains "new-project copies the fitness config"     "$np" ".dependency-cruiser.cjs"
contains "new-project copies the mutation config"    "$np" "stryker.config.json"
contains "new-project appends the import-linter table" "$np" "importlinter.fragment.toml"

# Step 8 wires code intelligence and step 9 the code graph (ADR-0004):
# a symbol lookup or a graph query before a grep and the reads after it.
contains "new-project installs the TypeScript language server" "$np" "typescript-language-server"
contains "new-project installs pyright"                        "$np" "uv add --dev pyright"
contains "new-project writes the project settings"             "$np" "claude-settings.json"
contains "new-project pins graphify"                           "$np" "graphifyy==0.9.58"
contains "new-project installs the graph in strict mode"       "$np" "graphify install --project --strict"
contains "new-project installs the graph's git hook"           "$np" "graphify hook install"
contains "new-project commits the graph"                       "$np" "commit \`graphify-out/graph.json\`"
contains "new-project ignores the graph cache"                 "$np" "graphify-out/cache/"

vf=$(cat "$S/verify/SKILL.md" 2>/dev/null)
contains "verify runs in a fresh sub-agent"         "$vf" "fresh sub-agent"
contains "verify names the verifier's model"        "$vf" "model: sonnet"
contains "verify points at the generation pin"      "$vf" "ADR-0005"
contains "verify withholds the diff"                "$vf" "not the diff"
contains "verify withholds the conversation"        "$vf" "not the conversation"
contains "verify runs scripts/verify first"         "$vf" "scripts/verify"
contains "verify validates the change before the scripts" "$vf" "openspec validate"
contains "verify brings the app up with scripts/dev" "$vf" "scripts/dev"
contains "verify drives the unhappy path"           "$vf" "unhappy"
contains "verify names the three verdicts"          "$vf" "not verifiable"
contains "verify writes verification.md"            "$vf" "verification.md"
contains "verify keeps proof in the change"         "$vf" "proof/"
contains "verify requires every finding answered"   "$vf" "Answer:"
contains "verify appends to progress.md"            "$vf" "progress.md"

sc=$(cat "$S/sdd-change/SKILL.md" 2>/dev/null)
check "sdd-change gives every step a Produces line" "$(printf '%s' "$sc" | grep -c 'Produces:')" "10"
contains "sdd-change invokes verify at step 7"       "$sc" "\`verify\` skill"
contains "sdd-change names verification.md"         "$sc" "verification.md"
contains "sdd-change keeps state in progress.md"    "$sc" "progress.md"
contains "sdd-change states the missing-artefact rule" "$sc" "has not happened"
contains "sdd-change logs the session boundary"     "$sc" "session ended"
contains "sdd-change sets Status in-progress"       "$sc" "Status: in-progress"
contains "sdd-change clears a stale archive lock"   "$sc" ".openspec-archive.lock"
contains "sdd-change implements one task per session on large changes" "$sc" "one task per session"
contains "sdd-change leaves the tree mergeable at session end"        "$sc" "mergeable"
contains "sdd-change has a compound step"            "$sc" "**Compound.**"
contains "sdd-change asks the compound question"     "$sc" "catch this automatically next time"
contains "sdd-change names the four compound outcomes" "$sc" "test, a hook, a rule, or nothing"
contains "sdd-change logs compound decisions"        "$sc" "compound:"
contains "sdd-change counts findings at archive"     "$sc" "archived:"
