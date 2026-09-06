LIB="plugins/dev-standards/hooks/lib/change-lint.js"

lint() { node "$LIB" "$1" 2>/dev/null; }

# A compliant change: Non-Goals, two scenarios per requirement, every task
# says how it is verified.
ok=$(mktemp -d)
mkdir -p "$ok/specs/greeting"
printf '# Proposal\n\n## What Changes\n\n### Non-Goals\n\n- styling\n' > "$ok/proposal.md"
printf '## ADDED Requirements\n\n### Requirement: Greeting\nText.\n\n#### Scenario: a name\n- WHEN x\n- THEN y\n\n#### Scenario: no name\n- WHEN x\n- THEN error\n' > "$ok/specs/greeting/spec.md"
printf '# Tasks\n\n- [ ] 1. Function — verified by greeting.test.ts\n- [x] 2. UI — verified by the verifier\n' > "$ok/tasks.md"
check "a compliant change is silent" "$(lint "$ok")" ""

# Each rule on its own.
ng=$(mktemp -d)
printf '# Proposal\n\n## What Changes\n\nstuff\n' > "$ng/proposal.md"
contains "reports a proposal without Non-Goals" "$(lint "$ng")" "Non-Goals"

one=$(mktemp -d)
mkdir -p "$one/specs/x"
printf '### Requirement: Only happy\nText.\n\n#### Scenario: works\n- WHEN a\n- THEN b\n' > "$one/specs/x/spec.md"
out=$(lint "$one")
contains "reports a requirement with one scenario" "$out" "Only happy"
contains "names the unhappy path"                  "$out" "unhappy path"

tv=$(mktemp -d)
printf '# Tasks\n\n- [ ] 1. Do the thing\n- [x] 2. Other — verified by a test\n' > "$tv/tasks.md"
out=$(lint "$tv")
contains "reports a task without a verification statement" "$out" "Do the thing"
not_contains "a verified task is not reported"              "$out" "Other"

# A spec delta's REMOVED section lists requirements being deleted. They
# carry no scenarios by construction, so asking them for an unhappy path
# reports a rule break that does not exist.
rmv=$(mktemp -d)
mkdir -p "$rmv/specs/x"
printf '## REMOVED Requirements\n\n### Requirement: Old\n**Reason**: superseded by Greeting\n' > "$rmv/specs/x/spec.md"
check "a removed requirement is not asked for scenarios" "$(lint "$rmv")" ""

# The exemption is the section, not the rule: an added requirement with
# no scenarios is still reported.
added=$(mktemp -d)
mkdir -p "$added/specs/x"
printf '## ADDED Requirements\n\n### Requirement: New thing\nText.\n' > "$added/specs/x/spec.md"
contains "an added requirement with no scenarios is still reported" "$(lint "$added")" "New thing"

# Git for Windows checks text out with CRLF. A lint that only reads LF
# reports every rule broken in every project on this machine.
crlf=$(mktemp -d)
mkdir -p "$crlf/specs/greeting"
printf '# Proposal\r\n\r\n## What Changes\r\n\r\n### Non-Goals\r\n\r\n- styling\r\n' > "$crlf/proposal.md"
printf '## ADDED Requirements\r\n\r\n### Requirement: Greeting\r\nText.\r\n\r\n#### Scenario: a name\r\n- WHEN x\r\n- THEN y\r\n\r\n#### Scenario: no name\r\n- WHEN x\r\n- THEN error\r\n' > "$crlf/specs/greeting/spec.md"
printf '# Tasks\r\n\r\n- [ ] 1. Function - verified by greeting.test.ts\r\n' > "$crlf/tasks.md"
check "a compliant change with CRLF endings is silent" "$(lint "$crlf")" ""

# A finding must be findable. An empty task line has no title to quote,
# so it is named by where it is.
bare=$(mktemp -d)
printf '# Tasks\n\n- [ ]\n' > "$bare/tasks.md"
contains "an empty task is reported by its line" "$(lint "$bare")" "task on line 3"

# Robustness: missing files are someone else's problem, not a crash.
empty=$(mktemp -d)
check "an empty change directory is silent" "$(lint "$empty")" ""
check "a missing directory is silent"       "$(lint "/definitely/not/here")" ""
node "$LIB" "/definitely/not/here" >/dev/null 2>&1
check "always exits 0" "$?" "0"
check "no argument is silent" "$(node "$LIB" 2>/dev/null)" ""

rm -rf "$ok" "$ng" "$one" "$tv" "$empty" "$rmv" "$added" "$crlf" "$bare"
