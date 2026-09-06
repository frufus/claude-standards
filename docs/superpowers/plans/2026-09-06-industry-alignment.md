# Industry Alignment Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Close the five gaps the industry review found: `AGENTS.md` as the instruction file, the test ratchet and session rules, a pull-request contract with risk tiers, a compound step, a reporting proposal lint, tagged releases with one denying hook for destructive git, and a decided trial of fitness and mutation sensors.

**Architecture:** The `dev-standards` plugin gains two `AGENTS.md` templates (with the profile `CLAUDE.md` templates reduced to an `@AGENTS.md` import plus Claude-only notes), a shared pull-request template, three rule lines in the global layer, a new step 9 **Compound** in `sdd-change`, a node helper `lib/change-lint.js` that the ship check calls, a fifth hook `guard-destructive-git.sh` that is the one hook allowed to deny (recorded as ADR-0002, with a `CLAUDE_STANDARDS_ALLOW_DESTRUCTIVE=1` prefix as the human's way through), and ADR-0003 recording a trial of `dependency-cruiser`/Stryker and `import-linter`/`mutmut` with adoption into `scripts/verify` only where the trial's numbers allow. Every other hook keeps reporting.

**Tech Stack:** Bash (Git Bash on Windows), Node 22 for helpers (`jq` absent), the shared tokeniser in `hooks/lib/tokenize.js`, the hand-rolled bash suite (`bash tests/run-tests.sh`; helpers `check`, `contains`, `not_contains`; `tests/test-eol.sh` fails on any CRLF file in the index under plugins/ or tests/).

**Spec:** `docs/superpowers/specs/2026-09-06-industry-alignment-design.md`

## Global Constraints

- **Only `guard-destructive-git.sh` may deny.** It emits `permissionDecision: "deny"` for exactly four command shapes; every other hook exits 0 with reporting output or nothing, and their tests keep `not_contains … "permissionDecision"`.
- **Hooks report through `hookSpecificOutput.additionalContext`** with the `node -e` serialiser the existing hooks use. Helpers never fail loudly: unreadable input degrades to empty output, exit 0.
- **Files are LF in the index.** After editing any file, run `sed -i 's/\r$//' FILE`, stage, and confirm `git ls-files --eol plugins tests docs README.md | grep 'i/crlf'` prints nothing. This Git Bash's grep strips carriage returns, so never check for CR with grep; use `tr -cd '\r' < FILE | wc -c`.
- **Line budgets, all tested:** global `CLAUDE.md` ≤ 60 (it is at 50; this plan adds 9); profile `CLAUDE.md` ≤ 40; profile `AGENTS.md` ≤ 60 (new).
- **`sdd-change` `Produces:` count becomes exactly 10** (was 9); the test is updated in Task 4 and nowhere else.
- **Conventional Commits**, subject ≤ 72 characters. Branch `claude/industry-alignment` already exists and holds the spec.
- **The test-check-ship fixture `$p`** currently has a `proposal.md` with no Non-Goals; Task 5 makes the lint report that, so Task 5 also updates that fixture to a compliant proposal wherever the test expects silence.
- **`uv` is not installed on this machine.** Task 7's python spike uses `python -m venv` and `pip`, and says so in the ADR.

## File map

| File | Responsibility |
| --- | --- |
| `templates/web/AGENTS.md`, `templates/python/AGENTS.md` | Tool-agnostic instruction file: description, config pointer, commands, directories, boundaries |
| `templates/web/CLAUDE.md`, `templates/python/CLAUDE.md` | `@AGENTS.md` import plus Claude-only notes |
| `templates/global/CLAUDE.md` | + test ratchet, Sessions, risk tier |
| `templates/shared/pull_request_template.md` | The PR contract |
| `skills/new-project/SKILL.md` | writes AGENTS.md, CLAUDE.md, the PR template |
| `skills/sdd-change/SKILL.md` | step 4 sessions; step 9 Compound; step 10 Archive with counts |
| `hooks/lib/change-lint.js` | change dir → one line per broken proposal rule |
| `hooks/check-ship.sh` | + lint lines in the notice |
| `hooks/check-conformance.sh` | + AGENTS.md report |
| `hooks/lib/destructive-git.js` | command line → `force-push`, `hard-reset`, `clean`, `branch-delete` or nothing |
| `hooks/guard-destructive-git.sh` | the one denying hook, with the override prefix |
| `hooks/hooks.json` | + guard on Bash |
| `docs/adr/0002-…`, `docs/adr/0003-…` | the two decisions |
| `README.md`, manifests | five hooks, 0.3.0, the exception sentence |

---

### Task 1: `AGENTS.md` templates, thin `CLAUDE.md`, new-project, conformance

**Files:**
- Create: `plugins/dev-standards/templates/web/AGENTS.md`, `plugins/dev-standards/templates/python/AGENTS.md`
- Modify: `plugins/dev-standards/templates/web/CLAUDE.md`, `plugins/dev-standards/templates/python/CLAUDE.md`
- Modify: `plugins/dev-standards/skills/new-project/SKILL.md` (step 4)
- Modify: `plugins/dev-standards/hooks/check-conformance.sh`
- Test: `tests/test-templates.sh`, `tests/test-skills.sh`, `tests/test-conformance.sh`

**Interfaces:**
- Consumes: nothing.
- Produces: `AGENTS.md` per profile (≤ 60 lines) holding everything tool-agnostic; `CLAUDE.md` per profile whose first line is exactly `@AGENTS.md`; the conformance hook reports a profiled project with no `AGENTS.md`.

- [ ] **Step 0: Tag the previous release**

```bash
git tag -a v0.2.0 aa3235d -m "dev-standards 0.2.0: verifier node, scripts, change contracts"
git tag
```
Expected: `v0.2.0` listed. (Spec section 8, step 1. Tags are local until pushed; nothing here pushes.)

- [ ] **Step 1: Rewrite the template tests**

In `tests/test-templates.sh`, replace the first loop (`for p in web python; do … done`, the one with "points at the config" and "stays thin") with:

```bash
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
```

Replace the later loop (`# The scripts are the first thing …` through its `done`) with:

```bash
# The scripts are the first thing a session should reach for, so they
# come first in the Commands block of both AGENTS.md files.
for p in web python; do
    first=$(awk '/^```/{f=!f; next} f{print; exit}' "$T/$p/AGENTS.md" 2>/dev/null)
    contains "$p AGENTS.md lists scripts/verify first" "$first" "scripts/verify"
    contains "$p AGENTS.md lists scripts/dev"  "$(cat "$T/$p/AGENTS.md" 2>/dev/null)" "scripts/dev"
done
```

Leave the three `web template …` assertions (design system, redeclare, component) as they are; they still hold on the new web `CLAUDE.md`.

In `tests/test-skills.sh`, after `contains "new-project keeps Playwright specs out of Vitest" …`, append:

```bash
contains "new-project writes AGENTS.md"            "$np" "templates/<profile>/AGENTS.md"
contains "new-project imports it from CLAUDE.md"   "$np" "@AGENTS.md"
```

In `tests/test-conformance.sh`: every fixture that expects empty output (`full`, `withds`, `optout`, `early`, `py`, `itself`, `dev`) gains `printf '@AGENTS.md\n' > "$X/AGENTS.md"` right after its `CLAUDE.md` printf (use the same printf style as the surrounding lines). Then, before the final `rm -rf`, append:

```bash
# A profiled project without AGENTS.md is invisible to every agent that is
# not Claude Code. Reported once, like the scripts.
noagents=$(mktemp -d)
mkdir -p "$noagents/openspec" "$noagents/docs/adr" "$noagents/scripts"
printf 'schema: spec-driven
profile: python
' > "$noagents/openspec/config.yaml"
printf '# CLAUDE.md
' > "$noagents/CLAUDE.md"
printf '#!/usr/bin/env bash
' > "$noagents/scripts/verify"
out=$(printf '{"cwd":"%s"}' "$noagents" | bash "$HOOK" 2>/dev/null)
contains "reports a profiled project without AGENTS.md" "$out" "AGENTS.md"
not_contains "an unprofiled project is not asked for AGENTS.md" \
  "$(printf '{"cwd":"%s"}' "$noprofile" | bash "$HOOK" 2>/dev/null)" "AGENTS.md"
```
and add `"$noagents"` to the `rm -rf` list.

- [ ] **Step 2: Run the suite to verify it fails**

Run: `bash tests/run-tests.sh 2>&1 | grep -E 'FAIL|checks,'`
Expected: FAIL for every AGENTS.md assertion, the CLAUDE.md import checks, the two new-project checks, "reports a profiled project without AGENTS.md", and the seven silent conformance fixtures (they now carry AGENTS.md but the hook does not look for it yet — those seven pass; only the new report check fails). If "does not repeat the commands" also fails, that is expected until Step 4.

- [ ] **Step 3: Write the `AGENTS.md` templates**

Create `plugins/dev-standards/templates/web/AGENTS.md`:

````markdown
# AGENTS.md

<one or two sentences: what this project is, for whom>

**The binding project truth is `openspec/config.yaml`.** Product, non-negotiables,
tech stack and domain vocabulary live in its `context:` block. Current
requirements are the capability specs under `openspec/specs/`; anything under
`openspec/changes/` is proposed, not built. A unit of work starts as a change
proposal there and is approved before it is implemented.

## Commands

```
scripts/verify     # lint, typecheck, unit, e2e — the whole check, in order
scripts/dev        # dev server up (idempotent, prints the URL); `down` stops it
npm run test       # Vitest only
npm run lint       # ESLint only
npm run typecheck  # vue-tsc only
npm run format     # Prettier
```

## Directories

```
scripts/           Deterministic steps: dev up/down, verify
src/               Application code
openspec/          Binding specs and change proposals
docs/adr/          Architecture decisions
tests/             Unit tests
e2e/               Playwright specs
```

## Boundaries

- Always: run `scripts/verify` before calling a change done; commit as each
  task completes; answer every review finding as fixed or rejected with a
  stated reason.
- Ask: before deviating from the spec, before merging, before anything
  destructive or hard to reverse.
- Never: delete, skip or weaken a test to make a check pass; declare a
  colour, control height, radius or focus ring the design system already
  defines; put a secret in the bundle.
````

Create `plugins/dev-standards/templates/python/AGENTS.md`:

````markdown
# AGENTS.md

<one or two sentences: what this project is, for whom>

**The binding project truth is `openspec/config.yaml`.** Product, non-negotiables,
tech stack and domain vocabulary live in its `context:` block. Current
requirements are the capability specs under `openspec/specs/`; anything under
`openspec/changes/` is proposed, not built. A unit of work starts as a change
proposal there and is approved before it is implemented.

## Commands

```
scripts/verify     # lint, format check, typecheck, unit — the whole check, in order
scripts/dev        # the entry point (no long-running process by default)
uv sync            # install dependencies
uv run pytest      # tests only
uv run ruff check  # lint only
uv run mypy .      # typecheck only, strict
```

## Directories

```
scripts/           Deterministic steps: dev, verify
src/               Application code
openspec/          Binding specs and change proposals
docs/adr/          Architecture decisions
tests/             Tests
```

## Boundaries

- Always: run `scripts/verify` before calling a change done; commit as each
  task completes; answer every review finding as fixed or rejected with a
  stated reason.
- Ask: before deviating from the spec, before merging, before anything
  destructive or hard to reverse.
- Never: delete, skip or weaken a test to make a check pass; add a
  dependency outside `pyproject.toml`; commit a secret.
````

- [ ] **Step 4: Rewrite the `CLAUDE.md` templates**

Replace `plugins/dev-standards/templates/web/CLAUDE.md` with:

```markdown
@AGENTS.md

# Claude-specific notes

Everything tool-agnostic — what this project is, the commands, the
directories, the boundaries — is in `AGENTS.md`, imported above. Rules live
in `openspec/config.yaml`, never here.

## Design system

The interface is built on `@frufus/design-system`: tokens, primitives and the
two stylesheets it documents. Do not redeclare a colour, a control height, a
radius or a focus ring — take them from it. New components go through the
`component` skill, which decides whether they belong here or there.
```

Replace `plugins/dev-standards/templates/python/CLAUDE.md` with:

```markdown
@AGENTS.md

# Claude-specific notes

Everything tool-agnostic — what this project is, the commands, the
directories, the boundaries — is in `AGENTS.md`, imported above. Rules live
in `openspec/config.yaml`, never here. Nothing is Claude-specific yet.
```

- [ ] **Step 5: Update new-project step 4**

In `plugins/dev-standards/skills/new-project/SKILL.md`, replace step 4 with:

```markdown
4. **Write `AGENTS.md` and `CLAUDE.md`** from
   `${CLAUDE_PLUGIN_ROOT}/templates/<profile>/AGENTS.md` and
   `${CLAUDE_PLUGIN_ROOT}/templates/<profile>/CLAUDE.md`, filling the
   one-line description in `AGENTS.md`. `AGENTS.md` is what Codex, Cursor,
   Copilot and every other agent read; `CLAUDE.md` begins with `@AGENTS.md`
   so Claude Code reads the same file, and holds only what is
   Claude-specific. Keep both thin: orientation, commands, directories,
   boundaries. Rules belong in `openspec/config.yaml`, never in either.
```

- [ ] **Step 6: Add the conformance report**

In `plugins/dev-standards/hooks/check-conformance.sh`, directly after the `scripts/verify` block (the `if grep … [ ! -f "$cwd/scripts/verify" ]; then … fi`), insert:

```bash
# Every agent that is not Claude Code reads AGENTS.md and nothing else of
# ours. A profiled project without it is invisible to them.
if grep -qE '^profile:[[:space:]]*(web|python)[[:space:]]*$' "$cwd/openspec/config.yaml" 2>/dev/null &&
    [ ! -f "$cwd/AGENTS.md" ]; then
    add "no \`AGENTS.md\` — agents other than Claude Code read nothing else. Write it from the profile template (the \`new-project\` skill, step 4) and make \`CLAUDE.md\` start with \`@AGENTS.md\`."
fi
```

- [ ] **Step 7: Run the suite to verify it passes**

Run: `bash tests/run-tests.sh 2>&1 | grep -E 'FAIL|checks,'`
Expected: `0 failed`. Confirm `wc -l` on both AGENTS.md files ≤ 60 and both CLAUDE.md files ≤ 40.

- [ ] **Step 8: Commit**

```bash
git add plugins/dev-standards/templates plugins/dev-standards/skills/new-project/SKILL.md plugins/dev-standards/hooks/check-conformance.sh tests/test-templates.sh tests/test-skills.sh tests/test-conformance.sh
git commit -m "feat: make AGENTS.md the instruction file and import it from CLAUDE.md"
```

---

### Task 2: The test ratchet, Sessions, the risk tier, and one-task-per-session

**Files:**
- Modify: `plugins/dev-standards/templates/global/CLAUDE.md`
- Modify: `plugins/dev-standards/skills/sdd-change/SKILL.md` (step 4)
- Test: `tests/test-global-claude-md.sh`, `tests/test-skills.sh`

**Interfaces:**
- Consumes: nothing.
- Produces: three new rule statements in the always-loaded layer; the file stays ≤ 60 lines.

- [ ] **Step 1: Write the failing tests**

In `tests/test-global-claude-md.sh`, before the line-budget check, append:

```bash
# The shortcut every long-running-agent source names first is deleting or
# weakening a test to get green. The rule must live where it applies in a
# project with no openspec/: here.
contains "carries the test ratchet"        "$g" "weaken"
contains "a failing test is a finding"     "$g" "failing test is a finding"
contains "carries the compaction line"     "$g" "## Sessions"
contains "says what survives a compact"    "$g" "When compacting"
contains "names the code that always gets a human" "$g" "whatever the verdict"
contains "names untrusted input"           "$g" "untrusted input"
```

In `tests/test-skills.sh`, after `contains "sdd-change clears a stale archive lock" …`, append:

```bash
contains "sdd-change implements one task per session on large changes" "$sc" "one task per session"
contains "sdd-change leaves the tree mergeable at session end"        "$sc" "mergeable"
```

- [ ] **Step 2: Run the suite to verify it fails**

Run: `bash tests/run-tests.sh 2>&1 | grep -E 'FAIL|checks,'`
Expected: FAIL for the six global checks and the two sdd-change checks.

- [ ] **Step 3: Edit the global layer**

In `plugins/dev-standards/templates/global/CLAUDE.md`:

Under `## Quality`, after the "Data entering a process…" bullet, add:
```markdown
- A test is never deleted, skipped or weakened to make a check pass. A
  failing test is a finding, answered like any other.
```

Under `## Alone and with the human`, after the `"With the human" means stop and wait` bullet, add:
```markdown
- With the human, whatever the verdict: any change to authentication,
  payments, secrets handling or the parsing of untrusted input.
```

Before `## Language`, add:
```markdown
## Sessions

- When compacting, keep the change id, the list of modified files and the
  test commands.

```

Run `wc -l plugins/dev-standards/templates/global/CLAUDE.md`: expected 59. If it is above 60, shorten the second sentence of the branch bullet under **Git** ("A reused branch makes it impossible to say which commits a pull request contains.") to "A reused branch hides which commits a pull request contains." so it fits on the first line's continuation.

- [ ] **Step 4: Edit sdd-change step 4**

Replace step 4 with:

```markdown
4. **Implement**, task by task, tests first. Commit as each task
   completes — the commit-message and cadence rules live in the global
   CLAUDE.md. After each task: tick it in `tasks.md`, append a log line
   with the commit subject, update `Current:`. When the change has more
   than three tasks, implement one task per session, and leave the tree
   committed and mergeable at the end of every session, so a session that
   dies costs one task.
   Produces: one commit per task; `tasks.md` ticked; `progress.md` current
   with `Status: in-progress`.
```

- [ ] **Step 5: Run the suite to verify it passes**

Run: `bash tests/run-tests.sh 2>&1 | grep -E 'FAIL|checks,'`
Expected: `0 failed`, including "stays within its budget".

- [ ] **Step 6: Commit**

```bash
git add plugins/dev-standards/templates/global/CLAUDE.md plugins/dev-standards/skills/sdd-change/SKILL.md tests/test-global-claude-md.sh tests/test-skills.sh
git commit -m "docs: add the test ratchet, session rules and the risk tier"
```

---

### Task 3: The pull-request contract

**Files:**
- Create: `plugins/dev-standards/templates/shared/pull_request_template.md`
- Modify: `plugins/dev-standards/skills/new-project/SKILL.md` (new step 7, renumber 7→8, 8→9, 9→10)
- Test: `tests/test-templates.sh`, `tests/test-skills.sh`

**Interfaces:**
- Consumes: nothing.
- Produces: `.github/pull_request_template.md` in every scaffolded project, in the spec's shape.

- [ ] **Step 1: Write the failing tests**

Append to `tests/test-templates.sh`:

```bash
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
```

Append to `tests/test-skills.sh` after the AGENTS.md lines from Task 1:

```bash
contains "new-project writes the PR template" "$np" "pull_request_template.md"
```

- [ ] **Step 2: Run the suite to verify it fails**

Expected: FAIL for the seven template checks and the new-project check.

- [ ] **Step 3: Write the template**

Create `plugins/dev-standards/templates/shared/pull_request_template.md`:

```markdown
## Intent

<what and why, two sentences>

## Change

openspec/changes/<id> — proposal, spec deltas, tasks

## Proof

- verification.md: <n> pass, <m> fail answered, <k> not verifiable answered
- proof/: <screenshots or captured output>
- scripts/verify: exit 0

## Provenance and risk

- Agent-written: <files or areas>
- Risk tier: low | medium | high (auth, payments, secrets, untrusted input)

## Where human attention is wanted

<one or two areas: an architectural choice, a trade-off, a deviation>
```

- [ ] **Step 4: Add the new-project step**

In `plugins/dev-standards/skills/new-project/SKILL.md`, insert after step 6 (`Write scripts/`) and renumber the following steps (Install the toolchain → 8, Verify → 9, Confirm conformance → 10):

```markdown
7. **Write `.github/pull_request_template.md`** from
   `${CLAUDE_PLUGIN_ROOT}/templates/shared/pull_request_template.md`,
   verbatim. It asks for intent, the change id, the verification report,
   proof, which parts were agent-written and their risk tier, and where
   human attention is wanted — so what reaches a reviewer does not depend
   on the session that opened the pull request.
```

Confirm no other text in the file refers to the old numbers of the renumbered steps (the conformance hook's message refers to "step 6" for scripts and "step 4" for AGENTS.md, both unchanged).

- [ ] **Step 5: Run the suite to verify it passes**

Expected: `0 failed`.

- [ ] **Step 6: Commit**

```bash
git add plugins/dev-standards/templates/shared/pull_request_template.md plugins/dev-standards/skills/new-project/SKILL.md tests/test-templates.sh tests/test-skills.sh
git commit -m "feat: scaffold a pull-request contract with proof and risk tier"
```

---

### Task 4: The compound step

**Files:**
- Modify: `plugins/dev-standards/skills/sdd-change/SKILL.md` (new step 9, archive → 10, progress.md example)
- Test: `tests/test-skills.sh`

**Interfaces:**
- Consumes: nothing.
- Produces: ten steps with ten `Produces:` lines; `compound:` and `archived:` log-line shapes.

- [ ] **Step 1: Update the tests**

In `tests/test-skills.sh`, change `check "sdd-change gives every step a Produces line" … "9"` to `"10"`, and append after `contains "sdd-change leaves the tree mergeable at session end" …`:

```bash
contains "sdd-change has a compound step"            "$sc" "**Compound.**"
contains "sdd-change asks the compound question"     "$sc" "catch this automatically next time"
contains "sdd-change names the four compound outcomes" "$sc" "test, a hook, a rule, or nothing"
contains "sdd-change logs compound decisions"        "$sc" "compound:"
contains "sdd-change counts findings at archive"     "$sc" "archived:"
```

- [ ] **Step 2: Run the suite to verify it fails**

Expected: FAIL for the Produces count (9 ≠ 10) and the five new checks.

- [ ] **Step 3: Insert step 9 and renumber archive to 10**

In `plugins/dev-standards/skills/sdd-change/SKILL.md`, insert between step 8 and the current step 9:

```markdown
9. **Compound.** For every finding the verifier or a reviewer raised, ask:
   would the system catch this automatically next time? Decide one of
   four things — a test, a hook, a rule, or nothing — and log it. A rule
   goes into `openspec/config.yaml`, `AGENTS.md` or an ADR, never into a
   file an agent cannot see. "Nothing" states why it will not recur.
   Produces: one `compound:` log line per finding in `progress.md`.
```

Change the archive step's number to `10.` and add to the end of its Produces line: `; a log line `archived: <n> verifier findings, <m> review findings, <k> rounds`.` so it reads:

```
   Produces: the change, with `progress.md` and `verification.md`, under
   `openspec/changes/archive/`; a log line `archived: <n> verifier
   findings, <m> review findings, <k> rounds`.
```

In the `## progress.md` example block, after the `verified:` line add:

```
- 2026-09-07 — compound: empty name shows a greeting → test (e2e/greeter.spec.ts)
- 2026-09-07 — compound: reviewer wanted a null check → nothing (input is parsed at the boundary)
- 2026-09-07 — archived: 1 verifier findings, 1 review findings, 1 rounds
```

Confirm `grep -c 'Produces:'` prints 10.

- [ ] **Step 4: Run the suite to verify it passes**

Expected: `0 failed`.

- [ ] **Step 5: Commit**

```bash
git add plugins/dev-standards/skills/sdd-change/SKILL.md tests/test-skills.sh
git commit -m "feat: add the compound step so every finding leaves a decision"
```

---

### Task 5: `lib/change-lint.js` and the ship-check integration

**Files:**
- Create: `plugins/dev-standards/hooks/lib/change-lint.js`
- Modify: `plugins/dev-standards/hooks/check-ship.sh`
- Test: `tests/test-change-lint.sh` (new), `tests/test-check-ship.sh`

**Interfaces:**
- Consumes: a change directory path as `argv[2]`.
- Produces: `node lib/change-lint.js <dir>` prints one line per broken rule, nothing when clean or unreadable, always exit 0. The ship check prefixes each line with the change id and adds it to the notice.

- [ ] **Step 1: Write the failing tests**

Create `tests/test-change-lint.sh`:

```bash
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

# Robustness: missing files are someone else's problem, not a crash.
empty=$(mktemp -d)
check "an empty change directory is silent" "$(lint "$empty")" ""
check "a missing directory is silent"       "$(lint "/definitely/not/here")" ""
node "$LIB" "/definitely/not/here" >/dev/null 2>&1
check "always exits 0" "$?" "0"
check "no argument is silent" "$(node "$LIB" 2>/dev/null)" ""

rm -rf "$ok" "$ng" "$one" "$tv" "$empty"
```

In `tests/test-check-ship.sh`: change the first fixture's proposal line from `printf '# Proposal\n' > "$p/openspec/changes/2026-09-05-thing/proposal.md"` to `printf '# Proposal\n\n### Non-Goals\n- none\n' > "$p/openspec/changes/2026-09-05-thing/proposal.md"` (that fixture must be lint-clean, because later assertions expect silence once the finding is answered). Then, before the `# No change in flight` block, append:

```bash
# The proposal rules are checked at the same moment: when the work ships.
q2=$(mktemp -d)
mkdir -p "$q2/openspec/changes/2026-09-06-loose/specs/x"
printf '# Proposal\n' > "$q2/openspec/changes/2026-09-06-loose/proposal.md"
printf '### Requirement: R\n\n#### Scenario: only one\n- WHEN a\n- THEN b\n' > "$q2/openspec/changes/2026-09-06-loose/specs/x/spec.md"
printf '- [ ] 1. Unverified task\n' > "$q2/openspec/changes/2026-09-06-loose/tasks.md"
printf '# Verification\n\n### a — pass\n' > "$q2/openspec/changes/2026-09-06-loose/verification.md"
out=$(ship "$q2" "git push")
contains "reports a shipped proposal without Non-Goals"      "$out" "Non-Goals"
contains "reports a requirement missing its unhappy path"   "$out" "unhappy path"
contains "reports a task without a verification statement"  "$out" "Unverified task"
contains "the lint lines name the change"                   "$out" "2026-09-06-loose"
not_contains "the lint never denies"                        "$out" "permissionDecision"
rm -rf "$q2"
```

- [ ] **Step 2: Run the suite to verify it fails**

Expected: FAIL for every test-change-lint check and the five new check-ship checks.

- [ ] **Step 3: Write the helper**

Create `plugins/dev-standards/hooks/lib/change-lint.js`:

```js
// Takes a change directory and prints one line per rule of the shared
// config.rules.yaml the change breaks — the three that are structural
// enough to check: a proposal names its Non-Goals, every requirement has
// at least two scenarios (the rule asks for an unhappy path, and two is
// what following it produces), and every task says how it is verified.
//
// Reports only; the ship check turns these lines into a reminder. A
// missing file is not a finding here — the change may be half-written,
// and other checks own that. Anything unreadable degrades to no output
// and exit 0, like every helper in this directory.
const fs = require("fs");
const path = require("path");

function read(file) {
  try {
    return fs.readFileSync(file, "utf8");
  } catch {
    return null;
  }
}

function specFiles(dir) {
  let found = [];
  let entries;
  try {
    entries = fs.readdirSync(dir, { withFileTypes: true });
  } catch {
    return found;
  }
  for (const entry of entries) {
    const full = path.join(dir, entry.name);
    if (entry.isDirectory()) found = found.concat(specFiles(full));
    else if (entry.name === "spec.md") found.push(full);
  }
  return found;
}

function lint(dir) {
  const findings = [];

  const proposal = read(path.join(dir, "proposal.md"));
  if (proposal !== null && !/^#{1,6}\s.*Non-Goals/im.test(proposal)) {
    findings.push("proposal.md has no Non-Goals section");
  }

  for (const file of specFiles(path.join(dir, "specs"))) {
    const text = read(file);
    if (text === null) continue;
    for (const block of text.split(/^### Requirement:/m).slice(1)) {
      const name = block.split(/\r?\n/)[0].trim();
      const scenarios = (block.match(/^#### Scenario:/gm) || []).length;
      if (scenarios < 2) {
        findings.push(`requirement "${name}" has ${scenarios} scenario(s); the unhappy path is missing`);
      }
    }
  }

  const tasks = read(path.join(dir, "tasks.md"));
  if (tasks !== null) {
    for (const line of tasks.split(/\r?\n/)) {
      if (/^\s*-\s\[[ xX]\]/.test(line) && !/verif/i.test(line)) {
        const title = line.replace(/^\s*-\s\[[ xX]\]\s*/, "").slice(0, 60);
        findings.push(`task "${title}" does not say how it is verified`);
      }
    }
  }

  return findings;
}

try {
  const dir = process.argv[2];
  if (dir) {
    const findings = lint(dir);
    if (findings.length) process.stdout.write(findings.join("\n") + "\n");
  }
} catch {
  // degrade to no output
}
```

- [ ] **Step 4: Integrate into the ship check**

In `plugins/dev-standards/hooks/check-ship.sh`, inside the `for dir in …` loop, after the `if [ ! -f "$report" ]; then … fi` block and before `done`, insert:

```bash
    # The proposal rules are reported at the same moment, for the same
    # reason: this is when the work leaves the machine.
    lint=$(node "$HERE/lib/change-lint.js" "$dir" 2>/dev/null)
    if [ -n "$lint" ]; then
        while IFS= read -r line; do
            [ -n "$line" ] && add "\`$id\`: $line"
        done <<EOF
$lint
EOF
    fi
```

Change the notice's first line from `You are about to ${action} with a change in flight that is not verified:` to `You are about to ${action} with a change in flight that is not ready:` and its closing sentence from `A change does not leave the machine before it is verified.` to `A change does not leave the machine before it is verified and its proposal follows the rules.` Keep the escape clause.

Run `bash -n plugins/dev-standards/hooks/check-ship.sh`.

- [ ] **Step 5: Run the suite to verify it passes**

Expected: `0 failed`. If "silent once every finding is answered" or "silent with nothing in flight" fail, the first fixture's proposal was not updated in Step 1.

- [ ] **Step 6: Commit**

```bash
git add plugins/dev-standards/hooks/lib/change-lint.js plugins/dev-standards/hooks/check-ship.sh tests/test-change-lint.sh tests/test-check-ship.sh
git commit -m "feat: report a shipped proposal that breaks the shared rules"
```

---

### Task 6: The one hook that denies, and ADR-0002

**Files:**
- Create: `plugins/dev-standards/hooks/lib/destructive-git.js`
- Create: `plugins/dev-standards/hooks/guard-destructive-git.sh`
- Create: `docs/adr/0002-destructive-git-is-the-one-hook-that-denies.md`
- Modify: `plugins/dev-standards/hooks/hooks.json`
- Modify: `README.md` (lines 20–22 only; the rest of the README is Task 8)
- Test: `tests/test-destructive-git.sh`, `tests/test-guard-destructive-git.sh` (both new)

**Interfaces:**
- Consumes: `tokenize` and `isCommandStart` from `hooks/lib/tokenize.js`.
- Produces: `destructive-git.js` reads a command line on stdin and prints `force-push`, `hard-reset`, `clean` or `branch-delete` for the first destructive git command at a command position, else nothing. The hook denies with `permissionDecision: "deny"` unless the command line contains `CLAUDE_STANDARDS_ALLOW_DESTRUCTIVE=1`.

- [ ] **Step 1: Write the failing tests**

Create `tests/test-destructive-git.sh`:

```bash
LIB="plugins/dev-standards/hooks/lib/destructive-git.js"

kind() { printf '%s' "$1" | node "$LIB" 2>/dev/null; }

check "git push --force"             "$(kind 'git push --force origin main')" "force-push"
check "git push -f"                  "$(kind 'git push -f')" "force-push"
check "git push --force-with-lease"  "$(kind 'git push --force-with-lease')" "force-push"
check "git reset --hard"             "$(kind 'git reset --hard HEAD~1')" "hard-reset"
check "git clean -fd"                "$(kind 'git clean -fd')" "clean"
check "git clean --force"            "$(kind 'git clean --force')" "clean"
check "git branch -D"                "$(kind 'git branch -D claude/x')" "branch-delete"
check "after && is still seen"       "$(kind 'git fetch && git reset --hard origin/main')" "hard-reset"
check "on its own line is still seen" "$(kind "$(printf 'git add -A\ngit push --force')")" "force-push"
check "plain push is nothing"        "$(kind 'git push -u origin claude/x')" ""
check "soft reset is nothing"        "$(kind 'git reset --soft HEAD~1')" ""
check "clean dry run is nothing"     "$(kind 'git clean -n')" ""
check "branch -d is nothing"         "$(kind 'git branch -d merged')" ""
check "quoted text is nothing"       "$(kind "echo 'git push --force'")" ""
check "empty input is nothing"       "$(kind '')" ""
printf 'git push --force' | node "$LIB" >/dev/null 2>&1
check "always exits 0"               "$?" "0"
```

Create `tests/test-guard-destructive-git.sh`:

```bash
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
printf 'not json' | bash "$HOOK" >/dev/null 2>&1
check "exits 0 on malformed input"          "$?" "0"
check "malformed input produces no output"  "$(printf 'not json' | bash "$HOOK" 2>/dev/null)" ""

contains "hooks.json registers the guard on Bash" \
  "$(node -p 'JSON.stringify(require("./plugins/dev-standards/hooks/hooks.json").hooks.PreToolUse.filter(h=>h.matcher==="Bash").flatMap(h=>h.hooks.map(x=>x.command)))' 2>/dev/null)" \
  "guard-destructive-git.sh"
contains "ADR-0002 records the exception" "$(cat docs/adr/0002-destructive-git-is-the-one-hook-that-denies.md 2>/dev/null)" "## Decisions"
contains "README states the exception"    "$(cat README.md 2>/dev/null)" "one exception"
```

- [ ] **Step 2: Run the suite to verify it fails**

Expected: FAIL for every non-empty expectation in both new files (the `check … ""` lines pass trivially until the hook exists).

- [ ] **Step 3: Write the recogniser**

Create `plugins/dev-standards/hooks/lib/destructive-git.js`:

```js
// Reads a raw shell command line on stdin and writes the kind of the
// first destructive git command at a command position — `force-push`,
// `hard-reset`, `clean` or `branch-delete` — or nothing. These four are
// the shapes that destroy something the working tree cannot restore;
// everything else git does is reversible enough to stay a reminder.
//
// Hooks must never fail on unexpected input: every failure path ends in
// no output and exit code 0.
const { tokenize, isCommandStart } = require("./tokenize.js");

function segmentArgs(tokens, from) {
  const args = [];
  for (let j = from; j < tokens.length && tokens[j].type === "word"; j++) args.push(tokens[j].value);
  return args;
}

function classify(sub, args) {
  if (sub === "push" && args.some((a) => a === "-f" || a.startsWith("--force"))) return "force-push";
  if (sub === "reset" && args.includes("--hard")) return "hard-reset";
  if (sub === "clean" && args.some((a) => a === "--force" || /^-[a-zA-Z]*f[a-zA-Z]*$/.test(a))) return "clean";
  if (sub === "branch" && (args.includes("-D") || (args.includes("--delete") && args.includes("--force")))) return "branch-delete";
  return null;
}

function destructiveKind(tokens) {
  for (let idx = 0; idx < tokens.length; idx++) {
    const t = tokens[idx];
    if (t.type !== "word" || t.value !== "git" || !isCommandStart(tokens, idx)) continue;
    const next = tokens[idx + 1];
    if (!next || next.type !== "word") continue;
    const kind = classify(next.value, segmentArgs(tokens, idx + 2));
    if (kind) return kind;
  }
  return null;
}

let raw = "";
process.stdin.on("data", (d) => (raw += d)).on("end", () => {
  try {
    const kind = destructiveKind(tokenize(raw));
    if (kind) process.stdout.write(kind);
  } catch {
    // degrade to empty output
  }
});
```

Note: `isCommandStart` treats a word after an environment assignment like `CLAUDE_STANDARDS_ALLOW_DESTRUCTIVE=1 git push --force` as not at a command position (the assignment is the first word). That is fine: the hook checks for the override before calling this helper.

- [ ] **Step 4: Write the hook**

Create `plugins/dev-standards/hooks/guard-destructive-git.sh`:

```bash
#!/usr/bin/env bash
# PreToolUse on Bash: the one hook in this plugin that denies. Four git
# shapes destroy something the working tree cannot restore — a force-push,
# a hard reset, a clean, a branch force-delete — and for those a reminder
# arrives after the decision was made. ADR-0002 records the exception.
#
# The human's way through: run it themselves, or say so, after which the
# session reruns the command prefixed with CLAUDE_STANDARDS_ALLOW_DESTRUCTIVE=1.
# A guard with no way through gets switched off, and then it protects
# nothing — the parent design's argument, kept.
set -uo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

input=$(cat)
command_line=$(printf '%s' "$input" | node "$HERE/lib/json-fields.js" --raw tool_input.command 2>/dev/null)
[ -n "${command_line:-}" ] || exit 0

case "$command_line" in
    *CLAUDE_STANDARDS_ALLOW_DESTRUCTIVE=1*) exit 0 ;;
esac

kind=$(printf '%s' "$command_line" | node "$HERE/lib/destructive-git.js" 2>/dev/null)
[ -n "$kind" ] || exit 0

reason="Denied: this command is a ${kind}, which destroys something the working tree cannot restore. Ask the human. If they say yes, rerun it prefixed with CLAUDE_STANDARDS_ALLOW_DESTRUCTIVE=1, or let them run it. (ADR-0002.)"

printf '%s' "$reason" | node -e '
let s="";process.stdin.on("data",d=>s+=d).on("end",()=>{
  process.stdout.write(JSON.stringify({
    hookSpecificOutput: { hookEventName: "PreToolUse", permissionDecision: "deny", permissionDecisionReason: s }
  }));
});'
exit 0
```

- [ ] **Step 5: Register the hook, write the ADR, amend the README sentence**

In `plugins/dev-standards/hooks/hooks.json`, add to the `Bash` matcher's `hooks` array, as the first entry (before `check-commit-msg.sh`), and change the top-level description to `"Development standard: conformance report at session start, reminders on source edits, commits and shipping; one denial for destructive git"`:

```json
          {
            "type": "command",
            "command": "bash \"${CLAUDE_PLUGIN_ROOT}/hooks/guard-destructive-git.sh\""
          },
```

Create `docs/adr/0002-destructive-git-is-the-one-hook-that-denies.md`:

```markdown
# ADR-0002: Destructive git is the one hook that denies

Status: accepted · Date: 2026-09-06 · Affects: `guard-destructive-git.sh`; supersedes "nothing here can deny" in the 2026-09-01 design, section 4.6, for four command shapes

## Context

The 2026-09-01 design rejected hard denial for every hook: a guard that
fires on legitimate work — a typo in a comment, a hotfix, repairing a
broken build — gets switched off, and then it protects nothing. That
argument is about routine work, and it stands.

Four git commands are not routine work. `git push --force` (any `--force`
form, including `--force-with-lease`), `git reset --hard`, `git clean -f`
and `git branch -D` each destroy something the working tree cannot
restore: remote history, uncommitted changes, untracked files, a branch's
commits. A reminder reaches the agent after it has chosen the command.
The costs are asymmetric: a false block costs one rerun with a prefix; a
false allow costs commits.

## Decisions

1. A fifth hook denies exactly these four shapes, recognised at a command
   position by the shared tokeniser. Rejected: reporting only — for a
   reversible action a reminder is enough; for these four it is the one
   place a reminder arrives too late.
2. The human's way through is a prefix on the command,
   `CLAUDE_STANDARDS_ALLOW_DESTRUCTIVE=1`, which the hook honours by
   exiting silently. Rejected: denying with no way through — that is the
   guard that gets switched off. Rejected: a settings toggle — it would be
   set once and forgotten, where a prefix is a decision per command.
3. Every other hook keeps reporting. The exception is these four shapes
   and nothing else; adding a fifth needs a new ADR.

## Consequences

The README's "nothing here can deny" becomes "one exception, recorded in
ADR-0002". A session that needs a force-push stops and asks, which is what
the autonomy boundary already says for anything hard to reverse. The test
suite asserts the denial, the override and the silence on plain commands;
every other hook's tests keep asserting that they never deny.
```

In `README.md`, replace the sentence spanning lines 20–22 (`This plugin puts the standard where the work happens. Four hooks and five skills, all of which **report rather than block**. Nothing here can deny a tool call. A guard that stops legitimate work … protects nothing.`) with:

```markdown
This plugin puts the standard where the work happens. Five hooks and five
skills. Four of the hooks **report rather than block**: a guard that stops
legitimate work — a typo in a comment, a hotfix, repairing a broken build —
gets switched off, and then it protects nothing. There is one exception,
recorded in [ADR-0002](docs/adr/0002-destructive-git-is-the-one-hook-that-denies.md):
a force-push, a hard reset, a clean or a branch force-delete is denied until
the human says otherwise, because for those four a reminder arrives after the
decision.
```

(Read the actual current wording of those lines first and replace the whole sentence group; the README's hook table and counts are Task 8's job.)

- [ ] **Step 6: Run the suite to verify it passes**

Run `bash -n plugins/dev-standards/hooks/guard-destructive-git.sh`, `node -e 'require("./plugins/dev-standards/hooks/hooks.json");console.log("ok")'`, then the suite. Expected: `0 failed`. Every pre-existing `never denies` assertion in the other hook tests must still pass.

- [ ] **Step 7: Commit**

```bash
git add plugins/dev-standards/hooks/lib/destructive-git.js plugins/dev-standards/hooks/guard-destructive-git.sh plugins/dev-standards/hooks/hooks.json docs/adr/0002-destructive-git-is-the-one-hook-that-denies.md README.md tests/test-destructive-git.sh tests/test-guard-destructive-git.sh
git commit -m "feat: deny four destructive git shapes, with the human's way through"
```

---

### Task 7: The two sensor spikes and ADR-0003

**Files:**
- Create: `docs/adr/0003-fitness-and-mutation-sensors.md`
- Modify only if adopted: `plugins/dev-standards/templates/web/scripts/verify`, `plugins/dev-standards/templates/python/scripts/verify`, `plugins/dev-standards/skills/new-project/SKILL.md` (step 8, toolchain), `tests/test-scripts.sh`
- Test: `tests/test-adr.sh` (new)

**Interfaces:**
- Consumes: the scripts/verify templates from the previous change (`run <label> <command…>` helper; labels lint, typecheck, unit, e2e / lint, format, typecheck, unit).
- Produces: ADR-0003 with numbers; where adopted, a `run fitness …` step after `typecheck` and a `--deep` mode that runs the mutation tool.

- [ ] **Step 1: Write the ADR test**

Create `tests/test-adr.sh`:

```bash
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
```

- [ ] **Step 2: Run the suite to verify it fails**

Expected: FAIL for the ADR-0003 checks only (ADR-0002 exists from Task 6).

- [ ] **Step 3: Web spike**

In a throwaway directory under the scratchpad (`C:\Users\frufus\AppData\Local\Temp\claude\C--Users-frufus-development\2795d07b-aa29-4e34-988c-4a372eae8d78\scratchpad\sensor-web`), run:

```bash
npm create vite@latest sensor-web -- --template vue-ts && cd sensor-web && npm install --no-audit --no-fund
npm install --no-audit --no-fund -D vitest dependency-cruiser @stryker-mutator/core @stryker-mutator/vitest-runner
mkdir -p src/components src/repositories
printf 'export const load = () => 1;\n' > src/repositories/load.ts
printf 'import { load } from "../repositories/load";\nexport const view = () => load();\n' > src/components/view.ts
printf 'export function greeting(n: string): string { return n ? `Hello, ${n}` : "Please enter a name"; }\n' > src/greeting.ts
printf 'import { describe, it, expect } from "vitest";\nimport { greeting } from "./greeting";\ndescribe("greeting", () => { it("greets", () => expect(greeting("A")).toBe("Hello, A")); });\n' > src/greeting.test.ts
```

Write `.dependency-cruiser.cjs` (count its lines; the adoption bound is 20):

```js
module.exports = {
  forbidden: [
    {
      name: "components-do-not-touch-repositories",
      severity: "error",
      from: { path: "^src/components" },
      to: { path: "^src/repositories" },
    },
  ],
  options: { tsPreCompilationDeps: true, exclude: "node_modules" },
};
```

Run and time: `time npx depcruise src --config .dependency-cruiser.cjs`. Expected: one violation reported (view.ts → load.ts), non-zero exit. Record wall-clock seconds and the config's line count.

Write `stryker.config.json`:

```json
{ "testRunner": "vitest", "mutate": ["src/**/*.ts", "!src/**/*.test.ts"], "reporters": ["clear-text"] }
```

Run and time: `time npx stryker run`. Record seconds, the mutation score, and whether the deliberately weak test (it never checks the empty-name branch) left a surviving mutant. If the run exceeds 5 minutes, stop it and record that.

- [ ] **Step 4: Python spike**

In `…\scratchpad\sensor-py`:

```bash
python -m venv .venv && . .venv/Scripts/activate
pip install -q pytest import-linter mutmut
mkdir -p src/app/domain src/app/adapters tests
printf '' > src/app/__init__.py; printf '' > src/app/domain/__init__.py; printf '' > src/app/adapters/__init__.py
printf 'def greeting(n: str) -> str:\n    return f"Hello, {n}" if n else "Please enter a name"\n' > src/app/domain/greeting.py
printf 'from app.domain.greeting import greeting\n' > src/app/adapters/cli.py
printf 'from app.adapters import cli\n' > src/app/domain/bad.py
printf 'from app.domain.greeting import greeting\n\ndef test_greets():\n    assert greeting("A") == "Hello, A"\n' > tests/test_greeting.py
```

Write `pyproject.toml` (count its lint-relevant lines):

```toml
[tool.importlinter]
root_package = "app"
[[tool.importlinter.contracts]]
name = "domain does not import adapters"
type = "forbidden"
source_modules = ["app.domain"]
forbidden_modules = ["app.adapters"]
[tool.mutmut]
paths_to_mutate = "src/"
tests_dir = "tests/"
```

Run and time with `PYTHONPATH=src`: `time lint-imports` (expected: one broken contract, domain/bad.py), then `time mutmut run` and `mutmut results`. Record seconds, mutants killed/survived, and whether the empty-name branch survived. Stop at 5 minutes.

- [ ] **Step 5: Decide and record**

Apply the spec's bounds per tool: config ≤ 20 lines, one clear rule, mutation run ≤ 5 minutes on the throwaway. Write `docs/adr/0003-fitness-and-mutation-sensors.md` in the ADR template's shape (`## Context`, `## Decisions` numbered with `Rejected:` for each, `## Consequences`), stating for each of the four tools: install size, config line count, wall-clock seconds, what it caught, and **adopted** or **deferred** with the bound that decided it. Note that `uv` was absent and pip was used.

- [ ] **Step 6: Apply what was adopted**

For each adopted fitness sensor, in the profile's `scripts/verify` add after the `run typecheck …` line:
- web: `run fitness   npx depcruise src --config .dependency-cruiser.cjs`
- python: `run fitness   uv run lint-imports`

For each adopted mutation sensor, add a `--deep` mode: at the top of the script after `cd …`, `deep=0; [ "${1:-}" = "--deep" ] && deep=1`, and at the end before `all green`: `if [ "$deep" -eq 1 ]; then run mutation <command>; fi` with `npx stryker run` / `uv run mutmut run`. Update the header comment: `--deep` adds mutation testing; the default run does not. Update `tests/test-scripts.sh`'s ordered-labels checks to include `fitness` after `typecheck` where adopted, and add `contains "<p> verify offers a deep mode" … "--deep"` where a mutation sensor was adopted. Add to new-project step 8 (toolchain) one sentence per adopted tool naming the config file the template expects. Nothing is changed for deferred tools.

- [ ] **Step 7: Run the suite to verify it passes; clean up**

Expected: `0 failed`. Delete both throwaway directories.

- [ ] **Step 8: Commit**

```bash
git add docs/adr/0003-fitness-and-mutation-sensors.md tests/test-adr.sh plugins/dev-standards/templates plugins/dev-standards/skills/new-project/SKILL.md tests/test-scripts.sh
git commit -m "docs: trial fitness and mutation sensors and record the outcome"
```

---

### Task 8: README, manifests, version 0.3.0

**Files:**
- Modify: `README.md`, `plugins/dev-standards/.claude-plugin/plugin.json`, `.claude-plugin/marketplace.json`
- Test: `tests/test-manifests.sh`

- [ ] **Step 1: Write the failing tests**

In `tests/test-manifests.sh`: change `check "plugin version is 0.2.0" … "0.2.0"` to `"0.3.0"`, change `contains "README counts four hooks" "$readme" "Four hooks"` to `"Five hooks"`, and append:

```bash
contains "README documents AGENTS.md"         "$readme" "AGENTS.md"
contains "README documents the PR contract"   "$readme" "pull_request_template"
contains "README documents the compound step" "$readme" "compound"
contains "README documents the proposal lint" "$readme" "Non-Goals"
contains "README documents the tag"           "$readme" "v0.3.0"
contains "plugin description names AGENTS.md" \
  "$(node -p 'require("./plugins/dev-standards/.claude-plugin/plugin.json").description' 2>/dev/null)" "AGENTS.md"
```

- [ ] **Step 2: Run the suite to verify it fails**

Expected: FAIL for the version, the hook count and the six new checks.

- [ ] **Step 3: Manifests**

`plugin.json`: version `0.3.0`; description: `Spec-driven development standard. Reports project conformance at session start, reminds when source is edited without an active OpenSpec change, checks commit messages, reminds when an unverified or rule-breaking change is pushed or archived, denies four destructive git commands until the human says otherwise, scaffolds new projects from two prescribed stack profiles with AGENTS.md, dev and verify scripts and a pull-request contract, verifies a change in a fresh sub-agent against the spec's scenarios, and decides where a new UI component belongs before it is built. Web projects build on the shared design system unless an ADR says otherwise.`
`marketplace.json` plugin description: `Spec-driven development standard. Conformance report, reminders on edits, commits and shipping, one denial for destructive git, fresh-context verification, AGENTS.md and scripts from two stack profiles.`

- [ ] **Step 4: README**

1. `### Four hooks` → `### Five hooks`; add a row: `| `PreToolUse` on `Bash` | **Denies** a force-push, hard reset, clean or branch force-delete until the human says otherwise (`CLAUDE_STANDARDS_ALLOW_DESTRUCTIVE=1`). The one exception; see ADR-0002. |` and amend the ship-check row to end `… or an unanswered finding in it, or a proposal that breaks the shared rules (no Non-Goals, a requirement without its unhappy path, a task without a verification statement).`
2. Under **What `new-project` writes**, replace the CLAUDE.md step with `3. `AGENTS.md` from the profile template — commands, directories, boundaries — and a `CLAUDE.md` that begins with `@AGENTS.md`, so Claude Code and every other agent read the same file.` and add `6. `.github/pull_request_template.md`: intent, proof, provenance and risk tier, and where human attention is wanted.` (renumber the list).
3. Under **What a change leaves behind**, add a third bullet: `- A `compound:` line per finding in `progress.md`: whether it became a test, a hook, a rule, or a recorded "nothing"; and an `archived:` line with the counts.`
4. Under **The standard itself**, after the verification paragraph, add: `**A test is never deleted, skipped or weakened to make a check pass.** Changes to authentication, payments, secrets or the parsing of untrusted input are reviewed by the human whatever the verdict.`
5. Under **Install**, add: `Releases are tagged. The current release is `v0.3.0`; check the marketplace checkout out at a tag to pin it.`
6. Repository layout: `hooks/  Five hooks`; templates line gains `AGENTS.md`; `docs/adr/` line mentions three decisions.
7. **Verifying**: replace the count with what the suite prints, `all five hooks`.
8. **Status and licence**: `Version 0.3.0`.

- [ ] **Step 5: Run the suite to verify it passes; confirm the README count matches**

- [ ] **Step 6: Commit**

```bash
git add README.md plugins/dev-standards/.claude-plugin/plugin.json .claude-plugin/marketplace.json tests/test-manifests.sh
git commit -m "docs: document AGENTS.md, the PR contract, compound and the guard; bump to 0.3.0"
```

---

### Task 9: Probe (spec section 8, step 8) — controller

**Files:** none in this repository. Everything happens in a scratch directory and is deleted afterwards.

- [ ] **Step 1:** Scaffold a throwaway web project by hand following the updated `new-project` (AGENTS.md, CLAUDE.md with `@AGENTS.md`, PR template, scripts, `.gitattributes`). Run the conformance hook: expected empty.
- [ ] **Step 2:** Create a change whose `proposal.md` lacks Non-Goals and whose spec has one scenario; run the ship check on `git push`: expected lines naming Non-Goals and the unhappy path. Fix both; expected silent (with a verification.md present).
- [ ] **Step 3:** Run the guard with `git push --force`: expected a deny JSON. Run it with the `CLAUDE_STANDARDS_ALLOW_DESTRUCTIVE=1` prefix: expected silent.
- [ ] **Step 4:** If a fitness sensor was adopted, copy the template `scripts/verify` in and run it: expected the `fitness` step appears and passes on the empty project.
- [ ] **Step 5:** Delete the scratch directory; record the four outcomes in the ledger.

---

## Self-review

**Spec coverage.** 4.1 → Task 1. 4.2 → Task 2. 4.3 → Task 3. 4.4 → Task 4. 4.5 → Task 5. 4.6 tags → Task 1 step 0 and finishing (`v0.3.0` after merge); 4.6 guard → Task 6. 4.7 → Task 7. README/manifests → Task 8; probe → Task 9. Section 7's file list: every file has a task; `test-adr.sh` is Task 7.

**Placeholders.** `<one or two sentences …>`, `<id>`, `<n>` are template placeholders the templates are meant to contain. Task 7's numbers are produced by the spike, and the ADR test requires the word "seconds" so a spike that records none fails.

**Type consistency.** `destructive-git.js` prints the four kinds Task 6's hook and tests use verbatim. `change-lint.js` phrases ("Non-Goals section", "unhappy path is missing", "does not say how it is verified") match Task 5's tests in both files. `Produces:` count 10 is set once, in Task 4. The conformance hook's step references (4 for AGENTS.md, 6 for scripts) match the new-project numbering after Task 3's renumbering (7 is the PR template; 8–10 follow).
