S="plugins/dev-standards/skills"

# A skill whose frontmatter is malformed does not fail loudly — it simply
# never loads. Asserting the shape here is the only cheap way to catch it.
for skill in adr sdd-change new-project component; do
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
contains "new-project gitignores the dev pidfile" "$np" ".dev.pid"
