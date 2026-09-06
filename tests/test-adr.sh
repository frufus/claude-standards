# The repository's own decisions are worked examples of the ADR format it
# prescribes: numbered decisions, each with its rejected alternative.
for f in docs/adr/0002-destructive-git-is-the-one-hook-that-denies.md docs/adr/0003-fitness-and-mutation-sensors.md; do
    a=$(cat "$f" 2>/dev/null)
    contains "$(basename "$f") has Context"      "$a" "## Context"
    contains "$(basename "$f") has Decisions"    "$a" "## Decisions"
    contains "$(basename "$f") has Consequences" "$a" "## Consequences"
    contains "$(basename "$f") names a rejected alternative" "$a" "Rejected:"
done
contains "ADR-0003 records the web fitness trial"    "$(cat docs/adr/0003-fitness-and-mutation-sensors.md 2>/dev/null)" "dependency-cruiser"
contains "ADR-0003 records the python fitness trial" "$(cat docs/adr/0003-fitness-and-mutation-sensors.md 2>/dev/null)" "import-linter"
contains "ADR-0003 records the mutation trials"      "$(cat docs/adr/0003-fitness-and-mutation-sensors.md 2>/dev/null)" "mutmut"
contains "ADR-0003 states numbers"                   "$(cat docs/adr/0003-fitness-and-mutation-sensors.md 2>/dev/null)" "seconds"
