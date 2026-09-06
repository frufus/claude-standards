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

# The two sensors have a failure mode each — a fitness step that cruises
# nothing, a mutation step that reports survivors and exits 0 — and the
# ADR is where the measure against each is recorded.
adr3=$(cat docs/adr/0003-fitness-and-mutation-sensors.md 2>/dev/null)
contains "ADR-0003 names the TypeScript pin"     "$adr3" "typescript@^6"
contains "ADR-0003 names the fitness safeguard"  "$adr3" "fitness()"
contains "ADR-0003 names the mutation floor"     "$adr3" "break"
not_contains "ADR-0003 does not blame ADR-0002 for the python gap" "$adr3" "ADR-0002's asymmetric-cost"
not_contains "ADR-0003 carries no leftover instruction to itself"  "$adr3" "record it separately"
