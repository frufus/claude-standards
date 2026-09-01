S="plugins/dev-standards/skills"

# A skill whose frontmatter is malformed does not fail loudly — it simply
# never loads. Asserting the shape here is the only cheap way to catch it.
for skill in adr sdd-change; do
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
