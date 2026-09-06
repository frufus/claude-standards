# Verifier Node and Change Contracts Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make verification of a change the job of a fresh sub-agent that leaves proof in the change directory, give every project the two scripts that make that mechanical, and give every step of `sdd-change` an artefact a hook can check.

**Architecture:** The `dev-standards` plugin gains one skill (`verify`), two script templates per profile (`scripts/dev`, `scripts/verify`), one hook (`check-ship.sh` on `PreToolUse` for `Bash`, reporting like the other three), one node helper (`lib/verification.js`, which counts unanswered findings in a `verification.md`), and a shared tokeniser extracted from `git-subject.js` so the new hook recognises `git push`, `gh pr create` and `openspec archive` at a real command position. The `sdd-change` skill gets a *Produces* line per step and a `progress.md` per change. The global `CLAUDE.md` gets the autonomy boundary. Every hook keeps the plugin's rule: report, never deny.

**Tech Stack:** Bash for hooks and scripts (Git Bash on Windows), Node 22 for JSON and text parsing (`jq` is not installed), the `openspec` CLI v1.11.0, and the repository's hand-rolled Bash assertion harness (`tests/lib/harness.sh`: `check`, `contains`, `not_contains`).

**Spec:** `docs/superpowers/specs/2026-09-05-verifier-node-and-change-contracts-design.md`

## Global Constraints

- **No hook may ever deny.** No hook emits `permissionDecision: "deny"`. Every hook exits 0 on every path, including malformed input, a missing directory and a missing `openspec` binary.
- **Hooks report through `hookSpecificOutput.additionalContext`** with `hookEventName: "PreToolUse"` or `"SessionStart"`, built with the same `node -e` JSON serialiser the existing hooks use. Never print raw text.
- **Node is the only JSON dependency.** No `jq`.
- **Shell scripts stay LF.** `.gitattributes` covers `*.sh`; the extensionless script templates need their own line (Task 1).
- **Profile `CLAUDE.md` templates stay ≤ 40 lines** (`tests/test-templates.sh`). **The global `CLAUDE.md` stays ≤ 60 lines** (`tests/test-global-claude-md.sh`); it is at 42.
- **Tests assert content, not existence.** Every new skill, template and hook gets assertions on what it says, in the same style as the existing `tests/test-*.sh` files. `tests/run-tests.sh` sources every `tests/test-*.sh`; a new test file needs no registration.
- **Conventional Commits**, imperative mood, subject ≤ 72 characters. Work happens on the branch `claude/verifier-node`, already created and holding the spec.
- **Repository language is English.**
- **`openspec list --json`** prints `{"changes":[{"name":"<id>","status":"in-progress",...}],"root":{"path":"..."}|null}`. The new hook does **not** call it: it reads `openspec/changes/*/` from disk, so it works without the binary and is testable with `mktemp -d`. A change in flight is any directory under `openspec/changes/` other than `archive/`.
- **The `verification.md` contract** (Task 4) is: one `### <scenario> — <verdict>` heading per scenario where verdict is `pass`, `fail` or `not verifiable`; every `fail` and `not verifiable` section carries an `Answer:` line, or it is an unanswered finding. Parsing accepts `—`, `–` or `-` before the verdict.
- **Run the suite** with `bash tests/run-tests.sh` from the repository root. It prints `N checks, M failed` and exits non-zero when M > 0.

## File map

| File | Responsibility |
| --- | --- |
| `plugins/dev-standards/templates/web/scripts/dev` | Idempotent Vite up/down for a human or a verifier |
| `plugins/dev-standards/templates/web/scripts/verify` | lint, typecheck, unit, e2e in order; exit status is the verdict |
| `plugins/dev-standards/templates/python/scripts/dev` | Entry point; no long-running process by default |
| `plugins/dev-standards/templates/python/scripts/verify` | lint, format check, typecheck, unit in order |
| `plugins/dev-standards/templates/web/CLAUDE.md`, `.../python/CLAUDE.md` | Commands: scripts first |
| `plugins/dev-standards/skills/new-project/SKILL.md` | Writes `scripts/`, gitignores `.dev.pid`/`.dev.log`, marks executable |
| `plugins/dev-standards/skills/verify/SKILL.md` | The fresh-context verifier and the `verification.md` contract |
| `plugins/dev-standards/hooks/lib/verification.js` | stdin `verification.md` → count of unanswered findings |
| `plugins/dev-standards/skills/sdd-change/SKILL.md` | Produces lines, `progress.md`, step 7 invokes `verify` |
| `plugins/dev-standards/templates/shared/config.rules.yaml` | `progress.md` on apply, `verification.md` on archive |
| `plugins/dev-standards/templates/global/CLAUDE.md` | "Alone and with the human" |
| `plugins/dev-standards/hooks/lib/tokenize.js` | Shell tokeniser, extracted from `git-subject.js` |
| `plugins/dev-standards/hooks/lib/ship-command.js` | stdin command line → `push`, `pr`, `archive` or nothing |
| `plugins/dev-standards/hooks/lib/paths.sh` | + `os_root_of` (walks up to the nearest `openspec/`) |
| `plugins/dev-standards/hooks/check-ship.sh` | PreToolUse/Bash: reminds when shipping an unverified change |
| `plugins/dev-standards/hooks/check-conformance.sh` | + reports a profiled project with no `scripts/verify` |
| `plugins/dev-standards/hooks/hooks.json` | + `check-ship` on `Bash` |
| `README.md`, `plugin.json`, `marketplace.json` | Five skills, four hooks, version 0.2.0 |

---

### Task 1: Script templates for both profiles

**Files:**
- Create: `plugins/dev-standards/templates/web/scripts/dev`
- Create: `plugins/dev-standards/templates/web/scripts/verify`
- Create: `plugins/dev-standards/templates/python/scripts/dev`
- Create: `plugins/dev-standards/templates/python/scripts/verify`
- Modify: `.gitattributes`
- Test: `tests/test-scripts.sh`

**Interfaces:**
- Consumes: nothing.
- Produces: four bash scripts. `scripts/dev [up|down]` — `up` is idempotent, prints `already up` on its first line when it is, and prints the URL or entry point on its last line; `down` stops only what `up` started. `scripts/verify` takes no arguments, runs its steps via a `run <label> <command...>` helper in the order lint → (format) → typecheck → unit → (e2e), and exits non-zero at the first failure. The web `dev` writes `.dev.pid` and `.dev.log` in the project root; Task 2 gitignores them.

- [ ] **Step 1: Write the failing test**

Create `tests/test-scripts.sh`:

```bash
T="plugins/dev-standards/templates"

# The scripts are the deterministic edges of the procedure: the agent
# runs them instead of rediscovering the toolchain each session. They
# are bash because the hooks already are, and they must parse before
# they are trusted.
for p in web python; do
    for s in dev verify; do
        f="$T/$p/scripts/$s"
        check "$p/scripts/$s has a bash shebang" "$(head -n 1 "$f" 2>/dev/null)" "#!/usr/bin/env bash"
        check "$p/scripts/$s parses" "$(bash -n "$f" 2>/dev/null && echo ok)" "ok"
        check "$p/scripts/$s has no CR line endings" "$(grep -c $'\r' "$f" 2>/dev/null)" "0"
    done
    dev=$(cat "$T/$p/scripts/dev" 2>/dev/null)
    contains "$p/scripts/dev handles up"   "$dev" "up)"
    contains "$p/scripts/dev handles down" "$dev" "down)"
    contains "$p/scripts/dev is idempotent" "$dev" "already up"
done

# The order is the contract: cheap checks before expensive ones, so a
# lint failure never waits on an end-to-end run.
labels() { grep -E '^run ' "$T/$1/scripts/verify" 2>/dev/null | awk '{print $2}' | tr '\n' ' '; }
check "web verify runs lint, typecheck, unit, e2e in order" \
  "$(labels web)" "lint typecheck unit e2e "
check "python verify runs lint, format, typecheck, unit in order" \
  "$(labels python)" "lint format typecheck unit "

web=$(cat "$T/web/scripts/verify" 2>/dev/null)
contains "web verify brings the dev server up for e2e" "$web" "scripts/dev up"
contains "web verify takes the server down again"      "$web" "scripts/dev down"
contains "web verify stops at the first failure"       "$web" "exit 1"

contains ".gitattributes keeps the script templates LF" \
  "$(cat .gitattributes 2>/dev/null)" "templates/*/scripts/* text eol=lf"
```

- [ ] **Step 2: Run the suite to verify it fails**

Run: `bash tests/run-tests.sh 2>&1 | grep -E 'FAIL|checks,'`
Expected: FAIL lines for every `scripts/` assertion; the final line reports a non-zero failed count.

- [ ] **Step 3: Add the `.gitattributes` line**

Append to `.gitattributes`:

```
# The script templates have no extension, so the rule above does not
# reach them. They are bash and must stay LF for the same reason.
plugins/dev-standards/templates/*/scripts/* text eol=lf
```

- [ ] **Step 4: Write the web `dev` script**

Create `plugins/dev-standards/templates/web/scripts/dev`:

```bash
#!/usr/bin/env bash
# Brings the dev server up for a human or a verifier, and takes it down.
#
#   scripts/dev        start Vite if it is not up; print the URL last
#   scripts/dev down   stop what this script started
#
# Idempotent: a second `up` prints "already up" and the URL and exits 0.
# It never starts a second instance. A running watcher holds the project
# directory on Windows, which is why `down` exists: `openspec archive`
# fails with EPERM while Vite is up.
set -uo pipefail
cd "$(dirname "$0")/.." || exit 1

PORT="${PORT:-5173}"
URL="http://localhost:${PORT}"
PIDFILE=".dev.pid"
LOG=".dev.log"

is_up() { curl -sf -o /dev/null "$URL" 2>/dev/null; }

stop_pid() { # pid
    # On Windows the pid is npm's; Vite is its child and survives a plain
    # kill. taskkill //T takes the tree. Git Bash would rewrite /T as a
    # path, hence the doubled slashes.
    if command -v taskkill >/dev/null 2>&1; then
        taskkill //PID "$1" //T //F >/dev/null 2>&1
    else
        kill "$1" 2>/dev/null
    fi
}

case "${1:-up}" in
    up)
        if is_up; then
            echo "already up"
            echo "$URL"
            exit 0
        fi
        npm run dev -- --port "$PORT" --strictPort > "$LOG" 2>&1 &
        echo $! > "$PIDFILE"
        for _ in $(seq 1 60); do
            if is_up; then echo "$URL"; exit 0; fi
            sleep 0.5
        done
        echo "dev server did not answer on $URL within 30 s; see $LOG" >&2
        exit 1
        ;;
    down)
        if [ -f "$PIDFILE" ]; then
            stop_pid "$(cat "$PIDFILE")"
            rm -f "$PIDFILE"
            echo "stopped"
        else
            echo "not started by this script; nothing to stop"
        fi
        exit 0
        ;;
    *)
        echo "usage: scripts/dev [up|down]" >&2
        exit 2
        ;;
esac
```

- [ ] **Step 5: Write the web `verify` script**

Create `plugins/dev-standards/templates/web/scripts/verify`:

```bash
#!/usr/bin/env bash
# Lint, typecheck, unit tests, end-to-end tests — in that order, stopping
# at the first failure. The exit status is the verdict. Takes no
# arguments: a verifier that could be told to skip a step is not one.
set -uo pipefail
cd "$(dirname "$0")/.." || exit 1

run() { # label command...
    local label="$1"; shift
    printf '\n== %s\n' "$label"
    "$@" && return 0
    printf '\nverify: %s failed (exit %s)\n' "$label" "$?" >&2
    exit 1
}

# The server is started here rather than by Playwright's own webServer
# hook so that a verifier which already has it up (via scripts/dev) is
# not fought over the port. Set reuseExistingServer: true in
# playwright.config.ts and both paths agree.
started=0
cleanup() { [ "$started" -eq 1 ] && scripts/dev down >/dev/null; }
trap cleanup EXIT

run lint      npm run lint
run typecheck npm run typecheck
run unit      npm run test -- --run

up=$(scripts/dev up) || { printf '%s\n' "$up" >&2; exit 1; }
case "$up" in "already up"*) ;; *) started=1 ;; esac
run e2e       npm run test:e2e

printf '\nverify: all green\n'
```

- [ ] **Step 6: Write the python `dev` script**

Create `plugins/dev-standards/templates/python/scripts/dev`:

```bash
#!/usr/bin/env bash
# The project's entry point, for a human or a verifier.
#
# Most python projects here have no long-running process: the verifier
# calls the CLI or module directly. new-project replaces the entry point
# below with the real one. If this project grows a server, make `up`
# start it idempotently and print its URL last, and make `down` stop it.
set -uo pipefail
cd "$(dirname "$0")/.." || exit 1

ENTRY="uv run python -m <package>"

case "${1:-up}" in
    up)
        echo "no long-running process; already up"
        echo "$ENTRY"
        exit 0
        ;;
    down)
        exit 0
        ;;
    *)
        echo "usage: scripts/dev [up|down]" >&2
        exit 2
        ;;
esac
```

- [ ] **Step 7: Write the python `verify` script**

Create `plugins/dev-standards/templates/python/scripts/verify`:

```bash
#!/usr/bin/env bash
# Lint, format check, typecheck, unit tests — in that order, stopping at
# the first failure. The exit status is the verdict. Takes no arguments.
set -uo pipefail
cd "$(dirname "$0")/.." || exit 1

run() { # label command...
    local label="$1"; shift
    printf '\n== %s\n' "$label"
    "$@" && return 0
    printf '\nverify: %s failed (exit %s)\n' "$label" "$?" >&2
    exit 1
}

run lint      uv run ruff check .
run format    uv run ruff format --check .
run typecheck uv run mypy .
run unit      uv run pytest

printf '\nverify: all green\n'
```

- [ ] **Step 8: Run the suite to verify it passes**

Run: `bash tests/run-tests.sh 2>&1 | grep -E 'FAIL|checks,'`
Expected: no FAIL lines; `... checks, 0 failed`.

- [ ] **Step 9: Commit**

```bash
git add .gitattributes plugins/dev-standards/templates/web/scripts plugins/dev-standards/templates/python/scripts tests/test-scripts.sh
git commit -m "feat: add dev and verify script templates for both profiles"
```

---

### Task 2: `new-project` writes the scripts; profile `CLAUDE.md` lists them first

**Files:**
- Modify: `plugins/dev-standards/skills/new-project/SKILL.md`
- Modify: `plugins/dev-standards/templates/web/CLAUDE.md`
- Modify: `plugins/dev-standards/templates/python/CLAUDE.md`
- Test: `tests/test-skills.sh`, `tests/test-templates.sh`

**Interfaces:**
- Consumes: the four script templates from Task 1.
- Produces: a scaffolded project has `scripts/dev` and `scripts/verify`, executable in git's index, with `.dev.pid` and `.dev.log` gitignored, and a `CLAUDE.md` whose **Commands** block starts with the two scripts.

- [ ] **Step 1: Write the failing tests**

Append to `tests/test-skills.sh`, after the existing `new-project` assertions:

```bash
contains "new-project writes the scripts"        "$np" "scripts/verify"
contains "new-project makes them executable in git" "$np" "update-index --chmod=+x"
contains "new-project gitignores the dev pidfile" "$np" ".dev.pid"
```

Append to `tests/test-templates.sh`:

```bash
# The scripts are the first thing a session should reach for, so they
# come first in the Commands block of both profiles.
for p in web python; do
    first=$(awk '/^```/{f=!f; next} f{print; exit}' "$T/$p/CLAUDE.md" 2>/dev/null)
    contains "$p CLAUDE.md lists scripts/verify first" "$first" "scripts/verify"
    contains "$p CLAUDE.md lists scripts/dev"  "$(cat "$T/$p/CLAUDE.md" 2>/dev/null)" "scripts/dev"
done
```

- [ ] **Step 2: Run the suite to verify it fails**

Run: `bash tests/run-tests.sh 2>&1 | grep -E 'FAIL|checks,'`
Expected: FAIL for the three `new-project` lines and the two `lists scripts` lines per profile.

- [ ] **Step 3: Update the `new-project` skill**

In `plugins/dev-standards/skills/new-project/SKILL.md`, replace step 5 (`Create docs/adr/`) and renumber, so the process reads:

```markdown
5. **Create `docs/adr/`** with a `.gitkeep`.

6. **Write `scripts/`** from `${CLAUDE_PLUGIN_ROOT}/templates/<profile>/scripts/`:
   copy `dev` and `verify` verbatim, then `chmod +x scripts/dev scripts/verify`
   and `git update-index --chmod=+x scripts/dev scripts/verify` — git on
   Windows does not record the mode from the filesystem. On `python`,
   replace `<package>` in `scripts/dev` with the real entry point. Add
   `.dev.pid` and `.dev.log` to `.gitignore`; the web `dev` script writes
   them. These two scripts are the deterministic steps of every change:
   `scripts/dev` brings the application up idempotently and prints where,
   `scripts/verify` runs lint, typecheck, units and end-to-end in that
   order and exits non-zero at the first failure. The `verify` skill
   runs both; a session never composes those steps by hand.

7. **Install the toolchain** for the profile. On `web` this includes
   `@frufus/design-system`, wired with the four CSS lines it documents,
   unless the ADR described under that profile says otherwise. Set
   `reuseExistingServer: true` in `playwright.config.ts` so Playwright
   and `scripts/dev` agree about the server.

8. **Verify**: run `scripts/verify`. It must run to the end — an empty
   suite that runs is fine, a suite that cannot run is not.

9. **Confirm conformance**: the SessionStart conformance hook must report
   nothing for this project. Start a session in it, or run
   `bash "${CLAUDE_PLUGIN_ROOT}/hooks/check-conformance.sh"` with
   `{"cwd":"<project>"}` on stdin and confirm the output is empty.
```

Leave steps 1–4 and the profile sections unchanged. (The old step 7 "Verify: run the project's test command and its linter" is replaced by step 8 above.)

- [ ] **Step 4: Update the web `CLAUDE.md` template**

Replace the **Commands** block in `plugins/dev-standards/templates/web/CLAUDE.md` with:

````markdown
## Commands

```
scripts/verify     # lint, typecheck, unit, e2e — the whole check, in order
scripts/dev        # dev server up (idempotent, prints the URL); `down` stops it
npm run test       # Vitest only
npm run lint       # ESLint only
npm run typecheck  # vue-tsc only
npm run format     # Prettier
```
````

Then add `scripts/           Deterministic steps: dev up/down, verify` as the first line of the **Directories** block. Confirm the file is still ≤ 40 lines: `wc -l plugins/dev-standards/templates/web/CLAUDE.md`.

- [ ] **Step 5: Update the python `CLAUDE.md` template**

Replace the **Commands** block in `plugins/dev-standards/templates/python/CLAUDE.md` with:

````markdown
## Commands

```
scripts/verify     # lint, format check, typecheck, unit — the whole check, in order
scripts/dev        # the entry point (no long-running process by default)
uv sync            # install dependencies
uv run pytest      # tests only
uv run ruff check  # lint only
uv run mypy .      # typecheck only, strict
```
````

Add `scripts/           Deterministic steps: dev, verify` as the first line of the **Directories** block. Confirm ≤ 40 lines.

- [ ] **Step 6: Run the suite to verify it passes**

Run: `bash tests/run-tests.sh 2>&1 | grep -E 'FAIL|checks,'`
Expected: `0 failed`.

- [ ] **Step 7: Commit**

```bash
git add plugins/dev-standards/skills/new-project/SKILL.md plugins/dev-standards/templates/web/CLAUDE.md plugins/dev-standards/templates/python/CLAUDE.md tests/test-skills.sh tests/test-templates.sh
git commit -m "feat: scaffold the scripts and list them first in CLAUDE.md"
```

---

### Task 3: The `verify` skill

**Files:**
- Create: `plugins/dev-standards/skills/verify/SKILL.md`
- Test: `tests/test-skills.sh`

**Interfaces:**
- Consumes: `scripts/dev` and `scripts/verify` from Task 1; the spec deltas under `openspec/changes/<id>/specs/`.
- Produces: `openspec/changes/<id>/verification.md` in the exact shape below, and screenshots under `openspec/changes/<id>/proof/`. Task 4's parser and Task 8's hook read that shape; Task 5's `sdd-change` invokes this skill at step 7.

- [ ] **Step 1: Write the failing tests**

Append to `tests/test-skills.sh`. First extend the frontmatter loop: change `for skill in adr sdd-change new-project component; do` to `for skill in adr sdd-change new-project component verify; do`. Then append:

```bash
vf=$(cat "$S/verify/SKILL.md" 2>/dev/null)
contains "verify runs in a fresh sub-agent"         "$vf" "fresh sub-agent"
contains "verify withholds the diff"                "$vf" "not the diff"
contains "verify withholds the conversation"        "$vf" "not the conversation"
contains "verify runs scripts/verify first"         "$vf" "scripts/verify"
contains "verify brings the app up with scripts/dev" "$vf" "scripts/dev"
contains "verify drives the unhappy path"           "$vf" "unhappy"
contains "verify names the three verdicts"          "$vf" "not verifiable"
contains "verify writes verification.md"            "$vf" "verification.md"
contains "verify keeps proof in the change"         "$vf" "proof/"
contains "verify requires every finding answered"   "$vf" "Answer:"
contains "verify appends to progress.md"            "$vf" "progress.md"
```

- [ ] **Step 2: Run the suite to verify it fails**

Run: `bash tests/run-tests.sh 2>&1 | grep -E 'FAIL|checks,'`
Expected: FAIL for the `verify` frontmatter checks and the eleven content checks.

- [ ] **Step 3: Write the skill**

Create `plugins/dev-standards/skills/verify/SKILL.md`:

````markdown
---
name: verify
description: Verify a change in a fresh sub-agent against the spec's scenarios and leave proof in the change directory. Use at step 7 of sdd-change, and before any pull request or archive.
---

# Verifying a change

The session that wrote the code holds a theory of why the code is right,
and checks it against that theory. The scenarios it fails to drive are the
ones the theory says cannot fail. So verification is done by a
**fresh sub-agent** that gets the scenarios and the scripts — not the diff,
not the conversation, not `tasks.md`. Fresh context is the whole mechanism.

## Process

1. **Find the change.** `openspec list --json`; the change in flight is
   the one being worked on. Note its id and read
   `openspec/changes/<id>/specs/` — every scenario in every delta,
   happy and unhappy.
2. **Dispatch the verifier** with the Agent tool (`general-purpose`),
   using the brief below verbatim with the placeholders filled. Give it
   nothing else.
3. **Read `openspec/changes/<id>/verification.md`** when it returns.
4. **Answer every finding.** Each `fail` and `not verifiable` is a review
   finding: fix it, or reject it with a stated reason. Write the answer
   as an `Answer:` line under the verdict it answers. A fix is named by
   its commit subject; a rejection states why. Nothing is left without
   one.
5. **Append to `progress.md`**: `- <date> — verified: <n> pass, <m> fail,
   <k> not verifiable; all answered`.

Do not archive and do not open a pull request while a finding has no
`Answer:`. The ship-check hook reminds if you try.

## The brief

```
You are verifying change `<id>` in <project root>. You have not seen the
implementation and you will not be shown it. Your job is to find out
whether the application does what the scenarios say, and to leave proof.

Project context (from openspec/config.yaml):
<the context: block, verbatim>

Scenarios to verify — every one, including the unhappy paths:
<the contents of openspec/changes/<id>/specs/, verbatim>

Tools:
- `scripts/verify` runs lint, typecheck, unit and end-to-end checks in
  order and exits non-zero at the first failure. Run it first. A failure
  is a finding; continue to the scenarios unless nothing can run.
- `scripts/dev` brings the application up and prints its URL (or entry
  point) on the last line. It is idempotent. Run `scripts/dev down` when
  you are done if you started it.
- For a web project drive the URL with a browser (playwright-core is
  available; Chrome is at the path the project documents) and save a
  screenshot per scenario under openspec/changes/<id>/proof/<scenario>.png.
- For a python project call the entry point and capture the command and
  its output.

For each scenario record exactly one verdict:
- pass — you drove it and observed the specified behaviour;
- fail — you drove it and observed something else (say what);
- not verifiable — you could not drive it (say why: missing tool,
  missing data, ambiguous scenario).

Write openspec/changes/<id>/verification.md in this shape and nothing else:

# Verification: <id>

Verified: <date> by a fresh sub-agent
scripts/verify: exit <status>

## Scenarios

### <scenario name> — pass
Proof: openspec/changes/<id>/proof/<file>.png

### <scenario name> — fail
Proof: openspec/changes/<id>/proof/<file>.png
Finding: <what you observed instead>

### <scenario name> — not verifiable
Finding: <why>

Do not write an Answer: line — that is the implementer's job. Do not
edit source. Report the path of the file you wrote and stop.
```

## What is not verification

Reading the diff and agreeing with it. Running the unit suite alone.
Marking a scenario `pass` because the code for it exists. A verdict
without proof is an opinion; the point of this skill is that the change
directory holds evidence someone who cannot read the code can check.
````

- [ ] **Step 4: Run the suite to verify it passes**

Run: `bash tests/run-tests.sh 2>&1 | grep -E 'FAIL|checks,'`
Expected: `0 failed`.

- [ ] **Step 5: Commit**

```bash
git add plugins/dev-standards/skills/verify/SKILL.md tests/test-skills.sh
git commit -m "feat: add the verify skill with a fresh-context verifier"
```

---

### Task 4: `lib/verification.js` — count unanswered findings

**Files:**
- Create: `plugins/dev-standards/hooks/lib/verification.js`
- Test: `tests/test-verification.sh`

**Interfaces:**
- Consumes: a `verification.md` in Task 3's shape on stdin.
- Produces: a single integer on stdout: the number of `### … — fail` or `### … — not verifiable` sections with no line starting with `Answer:` before the next `###`. Empty or malformed input prints `0`. Always exits 0. Task 8's hook calls it as `node "$HERE/lib/verification.js" < "$file"`.

- [ ] **Step 1: Write the failing test**

Create `tests/test-verification.sh`:

```bash
LIB="plugins/dev-standards/hooks/lib/verification.js"

count() { printf '%s' "$1" | node "$LIB" 2>/dev/null; }

check "an all-pass report has no findings" \
  "$(count '# Verification: x

### login shows the form — pass
Proof: p.png
### empty list shows the empty state — pass
Proof: q.png')" "0"

check "an unanswered fail counts" \
  "$(count '### bad input is rejected — fail
Finding: it was accepted')" "1"

check "an unanswered not-verifiable counts" \
  "$(count '### offline mode — not verifiable
Finding: no way to cut the network')" "1"

check "an answered fail does not count" \
  "$(count '### bad input is rejected — fail
Finding: it was accepted
Answer: fixed in fix: reject malformed input')" "0"

check "an answered rejection does not count" \
  "$(count '### offline mode — not verifiable
Finding: no way to cut the network
Answer: rejected — covered by the unit test for the repository layer')" "0"

check "the answer must belong to its own section" \
  "$(count '### a — fail
Finding: x
Answer: fixed
### b — fail
Finding: y')" "1"

check "a plain hyphen before the verdict is accepted" \
  "$(count '### a - fail
Finding: x')" "1"

check "verdict matching is case-insensitive" \
  "$(count '### a — FAIL
Finding: x')" "1"

check "empty input is zero" "$(count '')" "0"
printf 'not a report at all' | node "$LIB" >/dev/null 2>&1
check "always exits 0" "$?" "0"
```

- [ ] **Step 2: Run the suite to verify it fails**

Run: `bash tests/run-tests.sh 2>&1 | grep -E 'FAIL|checks,'`
Expected: FAIL for every `test-verification` check (node cannot find the module; `count` prints nothing).

- [ ] **Step 3: Write the helper**

Create `plugins/dev-standards/hooks/lib/verification.js`:

```js
// Reads a verification.md on stdin and writes the number of unanswered
// findings: sections headed `### <scenario> — fail` or
// `### <scenario> — not verifiable` that carry no `Answer:` line before
// the next `###` heading. The dash may be an em dash, an en dash or a
// hyphen; the verdict is matched case-insensitively.
//
// Hooks must never fail on unexpected input: anything this script cannot
// read counts as zero findings and exits 0. A hook that crashes on a
// hand-edited report gets disabled, and then it protects nothing.
const VERDICT = /^###\s.*[—–-]\s*(fail|not verifiable)\s*$/i;

let raw = "";
process.stdin.on("data", (d) => (raw += d)).on("end", () => {
  let unanswered = 0;
  try {
    let inFinding = false;
    let answered = false;
    const close = () => {
      if (inFinding && !answered) unanswered++;
    };
    for (const line of raw.split(/\r?\n/)) {
      if (line.startsWith("### ")) {
        close();
        inFinding = VERDICT.test(line);
        answered = false;
      } else if (inFinding && /^Answer:/.test(line)) {
        answered = true;
      }
    }
    close();
  } catch {
    unanswered = 0;
  }
  process.stdout.write(String(unanswered));
});
```

- [ ] **Step 4: Run the suite to verify it passes**

Run: `bash tests/run-tests.sh 2>&1 | grep -E 'FAIL|checks,'`
Expected: `0 failed`.

- [ ] **Step 5: Commit**

```bash
git add plugins/dev-standards/hooks/lib/verification.js tests/test-verification.sh
git commit -m "feat: count unanswered findings in a verification report"
```

---

### Task 5: `sdd-change` contracts, `progress.md`, shared-rule lines

**Files:**
- Modify: `plugins/dev-standards/skills/sdd-change/SKILL.md`
- Modify: `plugins/dev-standards/templates/shared/config.rules.yaml`
- Test: `tests/test-skills.sh`, `tests/test-templates.sh`

**Interfaces:**
- Consumes: the `verify` skill (Task 3).
- Produces: every step of `sdd-change` names what it produces; `openspec/changes/<id>/progress.md` in the shape below; the shared rules require `progress.md` on apply and an answered `verification.md` on archive.

- [ ] **Step 1: Write the failing tests**

Append to `tests/test-skills.sh`:

```bash
sc=$(cat "$S/sdd-change/SKILL.md" 2>/dev/null)
check "sdd-change gives every step a Produces line" "$(printf '%s' "$sc" | grep -c 'Produces:')" "9"
contains "sdd-change invokes verify at step 7"       "$sc" "\`verify\` skill"
contains "sdd-change names verification.md"         "$sc" "verification.md"
contains "sdd-change keeps state in progress.md"    "$sc" "progress.md"
contains "sdd-change states the missing-artefact rule" "$sc" "has not happened"
contains "sdd-change logs the session boundary"     "$sc" "session ended"
```

Append to `tests/test-templates.sh`:

```bash
rules=$(cat "$T/shared/config.rules.yaml" 2>/dev/null)
contains "shared rules update progress.md on apply"       "$rules" "progress.md"
contains "shared rules require verification on archive"   "$rules" "verification.md"
```

- [ ] **Step 2: Run the suite to verify it fails**

Run: `bash tests/run-tests.sh 2>&1 | grep -E 'FAIL|checks,'`
Expected: FAIL for the six `sdd-change` checks and the two shared-rule checks.

- [ ] **Step 3: Rewrite the `sdd-change` skill**

Replace the whole of `plugins/dev-standards/skills/sdd-change/SKILL.md` with:

````markdown
---
name: sdd-change
description: Drive a unit of work from proposal to archive under the spec-driven standard. Use when starting any feature, fix, or refactor in a project that has an openspec/ directory.
---

# Running a change

Work starts as a proposal, not as code. The proposal is what the human
approves; the code is what follows from it.

Every step produces an artefact in the change directory or the repository.
**A step whose artefact is missing has not happened** — that is what lets a
hook, or the next session, say where a change is without asking.

## Process

1. **Propose.** `openspec change` — write `proposal.md` with a Non-Goals
   subsection, the affected capability spec deltas under `specs/`, and
   `tasks.md` where every task states how it is verified. Write
   `progress.md` (shape below) with `Status: proposed`.
   Produces: `openspec/changes/<id>/` with `proposal.md`, `specs/`,
   `tasks.md`, `progress.md`.
2. **Stop.** Present the proposal and wait until it is approved. This gate
   is the point of the whole workflow; skipping it makes the rest
   ceremony. Nothing in step 3 onward begins before that approval.
   Produces: the first log line in `progress.md` — `approved` — and
   `Status: approved`. Nothing else.
3. **Branch.** `git switch -c claude/<topic>` from current `main`. The
   branch-naming and no-reuse rule lives in the global CLAUDE.md.
   Produces: the branch, named in `progress.md`.
4. **Implement**, task by task, tests first. Commit as each task
   completes — the commit-message and cadence rules live in the global
   CLAUDE.md. After each task: tick it in `tasks.md`, append a log line
   with the commit subject, update `Current:`.
   Produces: one commit per task; `tasks.md` ticked; `progress.md` current.
5. **Record decisions.** Anything that outlives the change becomes an ADR
   — invoke the `adr` skill.
   Produces: `docs/adr/NNNN-title.md`, linked from `proposal.md`.
6. **Deviate openly.** If the implementation must depart from the spec,
   say so and justify it before building the departure. A deviation found
   afterwards in the diff is a defect in the process, not a detail.
   Produces: a dated `deviation:` log line in `progress.md`, written
   before the deviation is built.
7. **Verify.** Invoke the `verify` skill. It runs a fresh sub-agent
   against the spec's scenarios and writes `verification.md`. Answer
   every finding it raises: fixed, or rejected with a stated reason.
   Produces: `openspec/changes/<id>/verification.md` with an `Answer:`
   under every `fail` and `not verifiable`; `Status: verified`.
8. **Handle review findings**: every finding is fixed or rejected with a
   stated reason, never silently dropped. The review rule — including what
   outranks a reviewer and how a dispute is settled — is in the global
   CLAUDE.md.
   Produces: every finding answered in the review itself;
   `Status: reviewed`.
9. **Archive.** `scripts/dev down` if the server is up, then
   `openspec archive <change-id>` folds the spec deltas into the
   capability specs. The specification is now current because the work
   finished, not because someone remembered to update it.
   Produces: the change, with `progress.md` and `verification.md`, under
   `openspec/changes/archive/`.

## progress.md

```
# Progress: <id>

Status: proposed | approved | in-progress | verified | reviewed
Branch: claude/<topic>
Current: <task number and title, or —>
Blocked: <what, or —>

## Log
- 2026-09-05 — approved
- 2026-09-05 — task 1 done: feat: add the thing
- 2026-09-06 — deviation: <what and why>
- 2026-09-06 — session ended at task 3, blocked on <what>
- 2026-09-07 — verified: 4 pass, 1 fail, 0 not verifiable; all answered
```

The header is overwritten; the log is append-only. Append a line at every
task boundary, every deviation, every verification, and **at the end of
every session that leaves the change in-progress** — that last line is
the one the next session reads first.

## When the guard fires and you are not starting a change

The source-guard hook reminds on any source edit with no change in flight.
For a hotfix or a build repair that is expected: say which it is, and
continue. The reminder exists to catch the case where a feature quietly
began without a proposal.
````

- [ ] **Step 4: Add the shared-rule lines**

In `plugins/dev-standards/templates/shared/config.rules.yaml`, change the `operations:` block to:

```yaml
operations:
  apply:
    guidance:
      - Run the touched area's tests before the full suite.
      - A deviation from the spec is named and justified before it is built, never discovered afterwards in the diff.
      - Update the change's progress.md as each task completes; append a log line at the end of any session that leaves the change in-progress.
  archive:
    guidance:
      - Keep the completion summary to what changed in observable behaviour.
      - Note any spec requirement this change made obsolete.
      - verification.md exists for the change and every fail or not-verifiable verdict in it carries an Answer.
```

Indent with spaces only (`tests/test-templates.sh` rejects tabs).

- [ ] **Step 5: Run the suite to verify it passes**

Run: `bash tests/run-tests.sh 2>&1 | grep -E 'FAIL|checks,'`
Expected: `0 failed`. If "gives every step a Produces line" reports a count other than 9, the skill text has a stray or missing `Produces:`; fix the text, not the test.

- [ ] **Step 6: Commit**

```bash
git add plugins/dev-standards/skills/sdd-change/SKILL.md plugins/dev-standards/templates/shared/config.rules.yaml tests/test-skills.sh tests/test-templates.sh
git commit -m "feat: give every sdd-change step an artefact and add progress.md"
```

---

### Task 6: The autonomy boundary in the global layer

**Files:**
- Modify: `plugins/dev-standards/templates/global/CLAUDE.md`
- Test: `tests/test-global-claude-md.sh`

**Interfaces:**
- Consumes: nothing.
- Produces: a section `## Alone and with the human` in the always-loaded layer; the file stays ≤ 60 lines.

- [ ] **Step 1: Write the failing tests**

Append to `tests/test-global-claude-md.sh`, before the line-budget check:

```bash
# The boundary between what the agent does alone and what needs the
# human is what the procedure already does; it is written down so it
# can be checked, and so a future loop has a rule rather than a habit.
contains "carries the autonomy boundary"  "$g" "## Alone and with the human"
contains "names what the agent does alone" "$g" "- Alone:"
contains "names what needs the human"      "$g" "- With the human:"
contains "with-the-human means wait"       "$g" "stop and wait"
```

- [ ] **Step 2: Run the suite to verify it fails**

Run: `bash tests/run-tests.sh 2>&1 | grep -E 'FAIL|checks,'`
Expected: FAIL for the four new global checks.

- [ ] **Step 3: Add the section**

In `plugins/dev-standards/templates/global/CLAUDE.md`, insert after the **Reviews are answered, not obeyed** section and before **Language**:

```markdown
## Alone and with the human

- Alone: propose, branch, implement approved tasks, verify, open a pull
  request, answer review findings, archive after merge.
- With the human: approve a proposal, accept a deviation, merge, and any
  action that is destructive or hard to reverse.
- "With the human" means stop and wait, not proceed and mention.
```

Run `wc -l plugins/dev-standards/templates/global/CLAUDE.md`; expected ≤ 60 (about 50).

- [ ] **Step 4: Run the suite to verify it passes**

Run: `bash tests/run-tests.sh 2>&1 | grep -E 'FAIL|checks,'`
Expected: `0 failed`, including "stays within its budget".

- [ ] **Step 5: Commit**

```bash
git add plugins/dev-standards/templates/global/CLAUDE.md tests/test-global-claude-md.sh
git commit -m "docs: state the autonomy boundary in the global rule layer"
```

---

### Task 7: Extract the tokeniser; recognise ship commands

**Files:**
- Create: `plugins/dev-standards/hooks/lib/tokenize.js`
- Modify: `plugins/dev-standards/hooks/lib/git-subject.js`
- Create: `plugins/dev-standards/hooks/lib/ship-command.js`
- Modify: `plugins/dev-standards/hooks/lib/paths.sh`
- Test: `tests/test-ship-command.sh`, `tests/test-paths.sh`

**Interfaces:**
- Consumes: the `tokenize` function currently defined inside `git-subject.js`.
- Produces: `tokenize.js` exporting `{ tokenize, isCommandStart }` via `module.exports`; `git-subject.js` requiring it with behaviour unchanged (`tests/test-git-subject.sh` and `tests/test-commit-msg.sh` keep passing); `ship-command.js` reading a command line on stdin and printing `push`, `pr` or `archive` when a command at a command position is `git push …`, `gh pr create …` or `openspec archive …`, else nothing; `os_root_of <dir>` in `paths.sh` printing the nearest ancestor (or the dir itself) that contains `openspec/`, or nothing.

- [ ] **Step 1: Write the failing tests**

Create `tests/test-ship-command.sh`:

```bash
LIB="plugins/dev-standards/hooks/lib/ship-command.js"

kind() { printf '%s' "$1" | node "$LIB" 2>/dev/null; }

check "git push is a push"                    "$(kind 'git push -u origin claude/x')" "push"
check "gh pr create is a pr"                  "$(kind 'gh pr create --fill')" "pr"
check "openspec archive is an archive"        "$(kind 'openspec archive 2026-09-05-x')" "archive"
check "a ship command after && is recognised" "$(kind 'git add -A && git push')" "push"
check "a ship command after ; is recognised"  "$(kind 'cd /x; gh pr create')" "pr"
check "git status is nothing"                 "$(kind 'git status')" ""
check "openspec list is nothing"              "$(kind 'openspec list --json')" ""
check "gh pr view is nothing"                 "$(kind 'gh pr view 12')" ""
check "the words inside another command are nothing" "$(kind "echo 'git push'")" ""
check "empty input is nothing"                "$(kind '')" ""
printf 'git push' | node "$LIB" >/dev/null 2>&1
check "always exits 0"                        "$?" "0"

# The tokeniser now lives in its own module; the commit hook must still
# behave exactly as before (its own tests cover that) and must load it.
contains "git-subject requires the shared tokeniser" \
  "$(cat plugins/dev-standards/hooks/lib/git-subject.js 2>/dev/null)" 'require("./tokenize.js")'
```

Append to `tests/test-paths.sh`:

```bash
# The ship check needs the project root without calling openspec, so it
# walks up from cwd to the nearest directory holding openspec/.
root=$(mktemp -d)
mkdir -p "$root/openspec" "$root/src/deep"
check "finds openspec in the directory itself" "$(os_root_of "$root")" "$root"
check "finds openspec above a nested cwd"      "$(os_root_of "$root/src/deep")" "$root"
check "normalises backslashes"                 "$(os_root_of "${root//\//\\}/src")" "$root"
none=$(mktemp -d)
check "finds nothing where there is nothing"   "$(os_root_of "$none")" ""
check "a missing directory yields nothing"     "$(os_root_of "/definitely/not/here")" ""
rm -rf "$root" "$none"
```

- [ ] **Step 2: Run the suite to verify it fails**

Run: `bash tests/run-tests.sh 2>&1 | grep -E 'FAIL|checks,'`
Expected: FAIL for every `test-ship-command` check and the five `os_root_of` checks.

- [ ] **Step 3: Extract the tokeniser**

Create `plugins/dev-standards/hooks/lib/tokenize.js` by moving the `tokenize` and `isCommandStart` functions out of `git-subject.js`, verbatim, with their comments, and ending the file with:

```js
module.exports = { tokenize, isCommandStart };
```

The file header comment:

```js
// Tokenises a shell-ish command line, respecting single quotes, double
// quotes (with backslash escapes for `"` `\` `$` `` ` ``) and backslash
// escapes outside quotes. `&&`, `||`, `;` and `|` are emitted as separate
// "op" tokens so callers can tell a real command boundary from plain text
// that happens to contain those characters mid-word.
//
// Shared by git-subject.js (commit subjects) and ship-command.js (push,
// PR and archive). One tokeniser, so the two hooks cannot disagree about
// what a command position is.
```

Then in `git-subject.js`, delete the two functions and add at the top, after the header comment:

```js
const { tokenize, isCommandStart } = require("./tokenize.js");
```

Run `bash tests/run-tests.sh 2>&1 | grep -E 'test-git-subject|test-commit-msg|FAIL'` — the existing commit-subject tests must all still pass before continuing.

- [ ] **Step 4: Write `ship-command.js`**

Create `plugins/dev-standards/hooks/lib/ship-command.js`:

```js
// Reads a raw shell command line on stdin and writes `push`, `pr` or
// `archive` when a command at a command position is `git push`,
// `gh pr create` or `openspec archive` — the three moments a change
// leaves the machine. Writes nothing otherwise.
//
// Hooks must never fail on unexpected input: every failure path ends in
// no output and exit code 0.
const { tokenize, isCommandStart } = require("./tokenize.js");

const SHIP = [
  { words: ["git", "push"], kind: "push" },
  { words: ["gh", "pr", "create"], kind: "pr" },
  { words: ["openspec", "archive"], kind: "archive" },
];

function shipKind(tokens) {
  for (let idx = 0; idx < tokens.length; idx++) {
    if (tokens[idx].type !== "word" || !isCommandStart(tokens, idx)) continue;
    for (const { words, kind } of SHIP) {
      const match = words.every(
        (w, k) => tokens[idx + k] && tokens[idx + k].type === "word" && tokens[idx + k].value === w
      );
      if (match) return kind;
    }
  }
  return null;
}

let raw = "";
process.stdin.on("data", (d) => (raw += d)).on("end", () => {
  try {
    const kind = shipKind(tokenize(raw));
    if (kind) process.stdout.write(kind);
  } catch {
    // degrade to empty output
  }
});
```

- [ ] **Step 5: Add `os_root_of` to `paths.sh`**

Append to `plugins/dev-standards/hooks/lib/paths.sh`:

```bash
os_root_of() { # directory -> nearest ancestor (or itself) holding openspec/, else nothing
    local d="${1//\\//}"
    d="${d%/}"
    [ -d "$d" ] || return 0
    while :; do
        if [ -d "$d/openspec" ]; then printf '%s' "$d"; return 0; fi
        local parent="${d%/*}"
        # `C:` has no slash to strip and would loop forever; an empty
        # parent means the root was reached.
        [ "$parent" = "$d" ] && return 0
        [ -n "$parent" ] || return 0
        d="$parent"
    done
}
```

- [ ] **Step 6: Run the suite to verify it passes**

Run: `bash tests/run-tests.sh 2>&1 | grep -E 'FAIL|checks,'`
Expected: `0 failed`.

- [ ] **Step 7: Commit**

```bash
git add plugins/dev-standards/hooks/lib/tokenize.js plugins/dev-standards/hooks/lib/git-subject.js plugins/dev-standards/hooks/lib/ship-command.js plugins/dev-standards/hooks/lib/paths.sh tests/test-ship-command.sh tests/test-paths.sh
git commit -m "feat: share the tokeniser and recognise push, PR and archive"
```

---

### Task 8: `check-ship.sh` and its registration

**Files:**
- Create: `plugins/dev-standards/hooks/check-ship.sh`
- Modify: `plugins/dev-standards/hooks/hooks.json`
- Test: `tests/test-check-ship.sh`

**Interfaces:**
- Consumes: `ship-command.js` and `os_root_of` (Task 7), `verification.js` (Task 4).
- Produces: a `PreToolUse` hook on `Bash` that, when the command is a ship command and the project has a change in flight with no `verification.md` or with unanswered findings, emits `additionalContext` naming the change and the artefact. Silent otherwise. Never denies.

- [ ] **Step 1: Write the failing test**

Create `tests/test-check-ship.sh`:

```bash
HOOK="plugins/dev-standards/hooks/check-ship.sh"

ship() { # cwd command
    printf '{"cwd":"%s","tool_input":{"command":"%s"}}' "$1" "$2" | bash "$HOOK" 2>/dev/null
}

# A change in flight with no verification.md at all.
p=$(mktemp -d)
mkdir -p "$p/openspec/changes/2026-09-05-thing" "$p/openspec/changes/archive/old"
printf '# Proposal\n' > "$p/openspec/changes/2026-09-05-thing/proposal.md"
out=$(ship "$p" "git push -u origin claude/thing")
contains "reports a push of an unverified change"    "$out" "2026-09-05-thing"
contains "names the missing artefact"                "$out" "verification.md"
contains "points at the verify skill"                "$out" "verify"
contains "declares the PreToolUse event"             "$out" "PreToolUse"
not_contains "never denies"                          "$out" "permissionDecision"
not_contains "the archive directory is not a change" "$out" "old"
contains "reports on gh pr create too"               "$(ship "$p" "gh pr create --fill")" "verification.md"
contains "reports on openspec archive too"           "$(ship "$p" "openspec archive 2026-09-05-thing")" "verification.md"
check "silent on a non-ship command"                 "$(ship "$p" "git status")" ""
check "silent when git push is only quoted text"     "$(ship "$p" "echo git push")" ""

# From a nested cwd the project is still found.
mkdir -p "$p/src/deep"
contains "finds the project above a nested cwd" "$(ship "$p/src/deep" "git push")" "verification.md"

# A verification with an unanswered finding.
printf '# Verification\n\n### a — fail\nFinding: broke\n' > "$p/openspec/changes/2026-09-05-thing/verification.md"
out=$(ship "$p" "git push")
contains "reports an unanswered finding" "$out" "1 unanswered"

# Once answered, silence.
printf '# Verification\n\n### a — fail\nFinding: broke\nAnswer: fixed in fix: x\n' > "$p/openspec/changes/2026-09-05-thing/verification.md"
check "silent once every finding is answered" "$(ship "$p" "git push")" ""

# No change in flight: nothing to say, whatever the command.
q=$(mktemp -d)
mkdir -p "$q/openspec/changes/archive"
check "silent with nothing in flight" "$(ship "$q" "git push")" ""

# Outside an OpenSpec project entirely.
r=$(mktemp -d)
check "silent outside an OpenSpec project" "$(ship "$r" "git push")" ""

out=$(printf 'not json' | bash "$HOOK" 2>/dev/null)
check "malformed input produces no output" "$out" ""
printf 'not json' | bash "$HOOK" >/dev/null 2>&1
check "malformed input still exits 0" "$?" "0"

# Registration: the hook must be wired to Bash in hooks.json, or it
# never runs and every assertion above is theatre.
contains "hooks.json registers check-ship on Bash" \
  "$(node -p 'JSON.stringify(require("./plugins/dev-standards/hooks/hooks.json").hooks.PreToolUse.filter(h=>h.matcher==="Bash").flatMap(h=>h.hooks.map(x=>x.command)))' 2>/dev/null)" \
  "check-ship.sh"

rm -rf "$p" "$q" "$r"
```

- [ ] **Step 2: Run the suite to verify it fails**

Run: `bash tests/run-tests.sh 2>&1 | grep -E 'FAIL|checks,'`
Expected: FAIL for every `contains` in `test-check-ship` and for the registration check; the `check "silent …"` lines pass trivially (the hook does not exist yet) — that is expected and not a problem.

- [ ] **Step 3: Write the hook**

Create `plugins/dev-standards/hooks/check-ship.sh`:

```bash
#!/usr/bin/env bash
# PreToolUse on Bash: when the command pushes, opens a pull request or
# archives, and a change in flight has no verification.md — or one with
# a finding nobody answered — reminds. Reports; never denies.
#
# A Stop hook would be the obvious place ("the agent is about to say it
# is done"), but a Stop hook's only channel back into the session is a
# block, and a blocking guard is the one this plugin refuses. The moment
# the work leaves the machine is a Bash command, and Bash hooks can report.
#
# Reads openspec/changes/ from disk rather than calling `openspec list`:
# no binary needed, and a change in flight is any directory there other
# than archive/.
set -uo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$HERE/lib/paths.sh"

input=$(cat)
IFS=$'\t' read -r command_line cwd < <(
    printf '%s' "$input" | node "$HERE/lib/json-fields.js" tool_input.command cwd 2>/dev/null
)
[ -n "${command_line:-}" ] || exit 0
[ -n "${cwd:-}" ] || exit 0

kind=$(printf '%s' "$command_line" | node "$HERE/lib/ship-command.js" 2>/dev/null)
[ -n "$kind" ] || exit 0

root=$(os_root_of "$cwd")
[ -n "$root" ] || exit 0
[ -d "$root/openspec/changes" ] || exit 0

case "$kind" in
    push)    action="push" ;;
    pr)      action="open a pull request" ;;
    archive) action="archive" ;;
esac

missing=""
add() { missing="${missing}
- $1"; }

for dir in "$root"/openspec/changes/*/; do
    [ -d "$dir" ] || continue
    id=$(basename "$dir")
    [ "$id" = "archive" ] && continue
    report="$dir/verification.md"
    if [ ! -f "$report" ]; then
        add "\`$id\` has no \`verification.md\`. Run the \`verify\` skill first."
    else
        n=$(node "$HERE/lib/verification.js" < "$report" 2>/dev/null)
        if [ "${n:-0}" -gt 0 ] 2>/dev/null; then
            add "\`$id\` has $n unanswered finding(s) in \`verification.md\`. Each is fixed or rejected with a stated reason — write the \`Answer:\` line."
        fi
    fi
done

[ -n "$missing" ] || exit 0

notice="You are about to ${action} with a change in flight that is not verified:${missing}

A change does not leave the machine before it is verified. If this is intended — a hotfix, or a push to back up work in progress — say so and continue."

printf '%s' "$notice" | node -e '
let s="";process.stdin.on("data",d=>s+=d).on("end",()=>{
  process.stdout.write(JSON.stringify({
    hookSpecificOutput: { hookEventName: "PreToolUse", additionalContext: s }
  }));
});'
exit 0
```

- [ ] **Step 4: Register the hook**

In `plugins/dev-standards/hooks/hooks.json`, change the top-level `description` to `"Development standard: conformance report at session start, reminders on source edits, commits and shipping an unverified change"` and add a second entry to the `Bash` matcher's `hooks` array, after `check-commit-msg.sh`:

```json
          {
            "type": "command",
            "command": "bash \"${CLAUDE_PLUGIN_ROOT}/hooks/check-ship.sh\""
          }
```

Confirm it still parses: `node -e 'require("./plugins/dev-standards/hooks/hooks.json");console.log("ok")'`.

- [ ] **Step 5: Run the suite to verify it passes**

Run: `bash tests/run-tests.sh 2>&1 | grep -E 'FAIL|checks,'`
Expected: `0 failed`.

- [ ] **Step 6: Commit**

```bash
git add plugins/dev-standards/hooks/check-ship.sh plugins/dev-standards/hooks/hooks.json tests/test-check-ship.sh
git commit -m "feat: remind when an unverified change is pushed, PR'd or archived"
```

---

### Task 9: Conformance reports a missing `scripts/verify`

**Files:**
- Modify: `plugins/dev-standards/hooks/check-conformance.sh`
- Modify: `tests/test-conformance.sh`

**Interfaces:**
- Consumes: nothing new.
- Produces: a profiled project without an executable-or-not `scripts/verify` file is reported once per session. Unprofiled projects and projects with no `openspec/` are not asked (they already get the bigger report).

- [ ] **Step 1: Update the existing fixture and write the failing tests**

In `tests/test-conformance.sh`, the `full` fixture ("a conforming project produces no output") must now carry the script. Change its setup to:

```bash
full=$(mktemp -d)
mkdir -p "$full/openspec" "$full/docs/adr" "$full/scripts"
printf 'schema: spec-driven\nprofile: web\n' > "$full/openspec/config.yaml"
printf '# CLAUDE.md\n' > "$full/CLAUDE.md"
printf '#!/usr/bin/env bash\n' > "$full/scripts/verify"
```

Do the same `mkdir … "$X/scripts"` plus `printf '#!/usr/bin/env bash\n' > "$X/scripts/verify"` for every fixture that currently expects empty output: `withds`, `optout`, `early`, `py`, `itself`, `dev`. Then append, before the final `rm -rf`:

```bash
# A profiled project without scripts/verify has no deterministic check
# for the verifier to run, so it is reported. Unprofiled projects are
# already told the bigger thing and are not nagged twice.
noscript=$(mktemp -d)
mkdir -p "$noscript/openspec" "$noscript/docs/adr"
printf 'schema: spec-driven
profile: python
' > "$noscript/openspec/config.yaml"
printf '# CLAUDE.md
' > "$noscript/CLAUDE.md"
out=$(printf '{"cwd":"%s"}' "$noscript" | bash "$HOOK" 2>/dev/null)
contains "reports a profiled project without scripts/verify" "$out" "scripts/verify"
not_contains "an unprofiled project is not asked for scripts" \
  "$(printf '{"cwd":"%s"}' "$noprofile" | bash "$HOOK" 2>/dev/null)" "scripts/verify"
```

and add `"$noscript"` to the `rm -rf` list.

- [ ] **Step 2: Run the suite to verify it fails**

Run: `bash tests/run-tests.sh 2>&1 | grep -E 'FAIL|checks,'`
Expected: FAIL for "reports a profiled project without scripts/verify" only.

- [ ] **Step 3: Add the check**

In `plugins/dev-standards/hooks/check-conformance.sh`, after the `[ -d "$cwd/docs/adr" ] || add …` line, insert:

```bash
# A profiled project carries the two scripts the verifier runs. Only a
# profiled one: a project still missing openspec/ or a profile has been
# told the bigger thing already.
if grep -qE '^profile:[[:space:]]*(web|python)[[:space:]]*$' "$cwd/openspec/config.yaml" 2>/dev/null &&
    [ ! -f "$cwd/scripts/verify" ]; then
    add "no \`scripts/verify\` — the verifier has no deterministic check to run. Copy \`scripts/dev\` and \`scripts/verify\` from the profile template (the \`new-project\` skill, step 6)."
fi
```

- [ ] **Step 4: Run the suite to verify it passes**

Run: `bash tests/run-tests.sh 2>&1 | grep -E 'FAIL|checks,'`
Expected: `0 failed`.

- [ ] **Step 5: Commit**

```bash
git add plugins/dev-standards/hooks/check-conformance.sh tests/test-conformance.sh
git commit -m "feat: report a profiled project that has no scripts/verify"
```

---

### Task 10: Manifests, README, version

**Files:**
- Modify: `plugins/dev-standards/.claude-plugin/plugin.json`
- Modify: `.claude-plugin/marketplace.json`
- Modify: `README.md`
- Test: `tests/test-manifests.sh`

**Interfaces:**
- Consumes: everything above.
- Produces: version `0.2.0`; descriptions naming the verifier; README sections for five skills, four hooks, the scripts, `progress.md` and `verification.md`.

- [ ] **Step 1: Write the failing tests**

Append to `tests/test-manifests.sh`:

```bash
check "plugin version is 0.2.0" \
  "$(node -p 'require("./plugins/dev-standards/.claude-plugin/plugin.json").version' 2>/dev/null)" "0.2.0"
contains "plugin description names verification" \
  "$(node -p 'require("./plugins/dev-standards/.claude-plugin/plugin.json").description' 2>/dev/null)" "verif"
contains "marketplace description names verification" \
  "$(node -p 'require("./.claude-plugin/marketplace.json").plugins[0].description' 2>/dev/null)" "verif"

readme=$(cat README.md 2>/dev/null)
contains "README counts five skills"          "$readme" "Five skills"
contains "README counts four hooks"           "$readme" "Four hooks"
contains "README documents the verify skill"  "$readme" "\`verify\`"
contains "README documents the scripts"       "$readme" "scripts/verify"
contains "README documents progress.md"       "$readme" "progress.md"
contains "README documents the ship check"    "$readme" "verification.md"
```

- [ ] **Step 2: Run the suite to verify it fails**

Run: `bash tests/run-tests.sh 2>&1 | grep -E 'FAIL|checks,'`
Expected: FAIL for the version, both descriptions and the six README checks.

- [ ] **Step 3: Bump the manifests**

In `plugins/dev-standards/.claude-plugin/plugin.json` set `"version": "0.2.0"` and the description to:

```
Spec-driven development standard. Reports project conformance at session start, reminds when source is edited without an active OpenSpec change, checks commit messages, reminds when an unverified change is pushed or archived, scaffolds new projects from two prescribed stack profiles with their dev and verify scripts, verifies a change in a fresh sub-agent against the spec's scenarios, and decides where a new UI component belongs before it is built. Web projects build on the shared design system unless an ADR says otherwise.
```

In `.claude-plugin/marketplace.json` set the plugin's description to:

```
Spec-driven development standard. Reports project conformance at session start, reminds when source is edited without an active OpenSpec change, checks commit messages, verifies changes in a fresh sub-agent, and scaffolds new projects from two prescribed stack profiles.
```

- [ ] **Step 4: Update the README**

Make these edits in `README.md`:

1. Line 20: `Three hooks and four` → `Four hooks and five`.
2. Under **The standard itself**, after the **Quality** paragraph, add:

```markdown
**Verification is done by someone who did not write the code.** A fresh
sub-agent drives every scenario in the change's spec deltas, unhappy paths
included, and leaves a verdict and proof per scenario in the change directory.
Every *fail* and *not verifiable* is answered — fixed, or rejected with a
reason — before the change is pushed, PR'd or archived.
```

3. `### Four skills` → `### Five skills`, and add a row to the table:

```markdown
| `verify`     | Step 7 of every change, and before any pull request or archive. Runs a fresh sub-agent against the spec's scenarios; writes `verification.md` and `proof/`. |
```

4. After the `**`component`**` paragraph, add:

```markdown
**`verify`** withholds the diff, the conversation and `tasks.md` from the
verifier on purpose. The session that wrote the code checks it against its
own theory of the code; the scenarios it fails to drive are the ones the
theory says cannot fail. Fresh context is the whole mechanism.
```

5. `### Three hooks` → `### Four hooks`, and add a row:

```markdown
| `PreToolUse` on `Bash`      | Reminds on `git push`, `gh pr create` or `openspec archive` while a change in flight has no `verification.md` or an unanswered finding in it. |
```

6. Replace the `### Two stack profiles` intro sentence's following text with nothing changed, but add after the two profile bullets:

```markdown
Both profiles carry two scripts, written by `new-project`: `scripts/dev`
brings the application up idempotently and prints where, `scripts/verify`
runs lint, typecheck, units and end-to-end in that order and exits non-zero
at the first failure. They are the deterministic steps of every change; a
session runs them instead of rediscovering the toolchain.
```

7. In **What `new-project` writes**, add a step `5. `scripts/dev` and `scripts/verify` from the profile, executable in git's index.` after step 4.

8. Add a new section after **What `new-project` writes**:

```markdown
## What a change leaves behind

Every step of `sdd-change` produces an artefact, and a step whose artefact
is missing has not happened. Two of them are new:

- `openspec/changes/<id>/progress.md` — a status header (overwritten) and
  an append-only log: approval, each task's commit, each deviation, each
  verification, and the end of every session that leaves the change
  in-progress. The next session reads the last line first.
- `openspec/changes/<id>/verification.md` — one verdict per scenario with
  its proof, and an `Answer:` under every finding. The ship-check hook
  reads it.

Both archive with the change.
```

9. In **Repository layout**, `hooks/  Three hooks` → `Four hooks`; `skills/  adr, component, new-project, sdd-change` → `adr, component, new-project, sdd-change, verify`; add `web/ python/  Per-profile CLAUDE.md, config fragment and scripts/`.

10. In **Verifying**, replace `163 checks over the manifests, both helper libraries, all three hooks, all four skills` with the number the suite now prints (read it from `bash tests/run-tests.sh | tail -n 1`) and `all four hooks, all five skills, the script templates`.

11. **Status and licence**: `Version 0.1.0` → `Version 0.2.0`.

- [ ] **Step 5: Run the suite to verify it passes**

Run: `bash tests/run-tests.sh 2>&1 | grep -E 'FAIL|checks,'`
Expected: `0 failed`. Then confirm the count in the README matches the count printed.

- [ ] **Step 6: Commit**

```bash
git add plugins/dev-standards/.claude-plugin/plugin.json .claude-plugin/marketplace.json README.md tests/test-manifests.sh
git commit -m "docs: document the verifier, scripts and change artefacts; bump to 0.2.0"
```

---

### Task 11: Prove it against a throwaway project (spec section 8, step 6)

**Files:**
- None in this repository. Everything happens in a scratch directory and is deleted afterwards. A finding here is fixed in the task that owns the file, with its own test and commit.

**Interfaces:**
- Consumes: the whole plugin as installed from this branch.
- Produces: evidence, reported in the final summary, for each of the four checks below. A verifier that has never been seen to fail is trusted and should not be.

- [ ] **Step 1: Reload the plugin from the branch**

The marketplace is registered locally from this repository. In a fresh Claude Code session run `/plugin` and reinstall `dev-standards@claude-standards` so the new skill and hook load, or confirm via `/hooks` that four `PreToolUse` entries exist (Edit|Write, Bash ×2 … the second Bash entry names `check-ship.sh`).

- [ ] **Step 2: Scaffold a throwaway web project**

```bash
mkdir -p "$TMP/verifier-probe" && cd "$TMP/verifier-probe" && git init -q
```

In a session in that directory, invoke `new-project web`. Confirm afterwards:

```bash
ls -l scripts/dev scripts/verify          # both present
git ls-files -s scripts | awk '{print $1}' # both 100755
grep -c 'dev.pid' .gitignore              # 1
bash scripts/verify; echo "exit $?"       # runs to "all green" on the empty project
bash scripts/dev; bash scripts/dev; bash scripts/dev down   # second `dev` prints "already up"
```

Expected: both scripts executable in the index, verify exits 0, second `dev` prints `already up` then the URL, `down` prints `stopped`.

- [ ] **Step 3: A change with a deliberately failing unhappy path**

In the same session, run `sdd-change` for a one-component change whose spec delta has two scenarios: a happy path the implementation satisfies, and an unhappy path (`WHEN the input is empty THEN an error message is shown`) that the implementation deliberately does **not** satisfy. Approve the proposal, implement the happy path only, then invoke `verify`.

Expected: `openspec/changes/<id>/verification.md` exists with one `— pass` and one `— fail` section, the fail carries a `Finding:`, and `proof/` holds two screenshots. If the verifier marks the unhappy path `pass`, the brief in Task 3 is not strong enough — that is a finding against Task 3.

- [ ] **Step 4: The ship check fires, then stops**

Still with the finding unanswered, ask the session to run `git push -u origin claude/probe` (there is no remote; the command may fail, the hook runs before it). Expected: the session reports the reminder naming the change and `1 unanswered`. Then write an `Answer:` line under the finding and repeat. Expected: no reminder.

- [ ] **Step 5: Archive with the server down**

Run `scripts/dev` to bring the server up, then `openspec archive <id>`. Expected: the ship check is silent (the finding is answered), and if the archive fails with `EPERM`, `scripts/dev down` followed by a second archive succeeds — record which happened.

- [ ] **Step 6: Clean up and report**

```bash
cd .. && rm -rf verifier-probe
```

Record, for the final summary: the four expected outcomes and whether each was observed; every finding and the task it was fixed in.

---

## Self-review

**Spec coverage.** 4.1 verifier → Tasks 3, 4, 11. 4.2 scripts → Tasks 1, 2, 9. 4.3 contracts → Task 5. 4.4 `progress.md` → Tasks 3, 5. 4.5 boundary → Task 6. 4.6 ship check and conformance → Tasks 7, 8, 9. Section 7 plugin changes → all files listed there have a task; `test-global-claude-md.sh` is Task 6, `test-check-ship.sh` is Task 8. Section 8 bootstrap → task order matches; step 6 is Task 11. README and manifests → Task 10.

**Placeholders.** `<package>` in the python `dev` template and `<id>`, `<scenario>` in the skill texts are deliberate template placeholders the skill instructs the agent to fill; they are not plan placeholders.

**Type consistency.** `os_root_of` (Task 7) is the name used in Task 8. `ship-command.js` prints `push|pr|archive` (Task 7) and Task 8's `case` matches those three. `verification.js` prints a bare integer (Task 4) and Task 8 compares it with `-gt 0`. The `verification.md` heading form `### <name> — <verdict>` is identical in Task 3's brief, Task 4's tests and Task 8's fixtures. `Answer:` is the line prefix in Tasks 3, 4, 5, 8 and the README.
