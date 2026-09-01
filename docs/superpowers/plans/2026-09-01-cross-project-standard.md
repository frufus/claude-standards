# Cross-Project Development Standard Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build a Claude Code plugin, a set of project templates and a global instruction file that make one spec-driven workflow and two prescribed tech stacks apply automatically in every project.

**Architecture:** A git repository acts as a local plugin marketplace. It ships one plugin whose hooks report conformance at session start and remind — never block — when source is edited without an active OpenSpec change or when a commit message breaks convention. Alongside the hooks it ships skills that scaffold a project, drive a change from proposal to archive, and write ADRs. A thin global `CLAUDE.md` carries the rules that must apply without anyone invoking anything.

**Tech Stack:** Bash for hooks (Git Bash on Windows), Node 22 for JSON parsing (`jq` is not installed on this machine), the `openspec` CLI v1.11.0 for spec state, and a hand-rolled Bash assertion harness for tests.

**Spec:** `docs/superpowers/specs/2026-09-01-cross-project-standard-design.md`

## Global Constraints

- **No hook may ever deny.** No hook emits `permissionDecision: "deny"`. Every hook exits 0 on every path, including malformed input and a missing `openspec` binary. A hook that fails loudly is a hook that gets disabled.
- **Source files are identified by exclusion**, not by an allowlist: everything except `openspec/`, `docs/`, `.claude/`, dotfiles and lockfiles.
- **The profile key** is a top-level `profile: web` or `profile: python` in `openspec/config.yaml`, next to `schema:`. A project without it is reported as unprofiled, never guessed at.
- **Repository language is English**: documentation, code comments, commit messages, identifiers.
- **Conventional Commits**, imperative mood, subject line ≤ 72 characters.
- **One branch per unit of work**, named `claude/<topic>`, branched from current `main`, never reused.
- **`*.sh` stays LF.** `.gitattributes` already enforces this; Git for Windows would otherwise check hooks out with CRLF and bash would reject the shebang.
- **Node is the only JSON dependency.** `jq` is absent from this machine; do not introduce it.
- **`openspec list --json`** prints `{"changes": [...], "root": {"path": "..."} | null}` and exits 0 both inside and outside an OpenSpec project.

## Deviation from the spec — read before Task 1

Section 4.5 of the spec sketches the plugin at the repository root, with
`marketplace.json` and `plugin.json` side by side in one `.claude-plugin/`
directory. This plan places the plugin in `plugins/dev-standards/` instead and
keeps only `marketplace.json` at the root.

The reason: every one of the 53 relative-source entries in the installed
official marketplace uses `"source": "./plugins/<name>"`. A repository that is
simultaneously marketplace and plugin may work, but it is unproven here, and
the first thing this standard does should not be an unproven layout. The plugin
is named `dev-standards` rather than carrying a personal handle, matching the
agnostic framing the spec adopted.

Everything else in section 4.5 is unchanged.

---

### Task 1: Marketplace manifest, plugin manifest, test harness

**Files:**
- Create: `.claude-plugin/marketplace.json`
- Create: `plugins/dev-standards/.claude-plugin/plugin.json`
- Create: `tests/lib/harness.sh`
- Create: `tests/run-tests.sh`
- Test: `tests/test-manifests.sh`

**Interfaces:**
- Consumes: nothing.
- Produces: `tests/lib/harness.sh` exporting shell functions `check <label> <actual> <expected>`, `contains <label> <haystack> <needle>`, `not_contains <label> <haystack> <needle>`, `summary` (returns non-zero if any check failed). `tests/run-tests.sh` sources every `tests/test-*.sh` and calls `summary`. Every later task adds one `tests/test-*.sh` file and adds nothing to the runner.

- [ ] **Step 1: Write the failing test**

Create `tests/test-manifests.sh`:

```bash
# Manifests must parse and carry the fields Claude Code requires to load
# the plugin. A malformed manifest fails silently at load time — the
# plugin simply does not appear — so it is worth asserting here.
MARKET=".claude-plugin/marketplace.json"
PLUGIN="plugins/dev-standards/.claude-plugin/plugin.json"

check "marketplace parses" \
  "$(node -e 'JSON.parse(require("fs").readFileSync(process.argv[1],"utf8"));console.log("ok")' "$MARKET" 2>/dev/null)" "ok"
check "marketplace name" \
  "$(node -p 'require("./.claude-plugin/marketplace.json").name' 2>/dev/null)" "claude-standards"
check "marketplace lists the plugin" \
  "$(node -p 'require("./.claude-plugin/marketplace.json").plugins[0].name' 2>/dev/null)" "dev-standards"
check "plugin source is the proven relative form" \
  "$(node -p 'require("./.claude-plugin/marketplace.json").plugins[0].source' 2>/dev/null)" "./plugins/dev-standards"
check "plugin manifest parses" \
  "$(node -e 'JSON.parse(require("fs").readFileSync(process.argv[1],"utf8"));console.log("ok")' "$PLUGIN" 2>/dev/null)" "ok"
check "plugin name matches marketplace entry" \
  "$(node -p 'require("./plugins/dev-standards/.claude-plugin/plugin.json").name' 2>/dev/null)" "dev-standards"
```

- [ ] **Step 2: Write the harness the test needs**

Create `tests/lib/harness.sh`:

```bash
#!/usr/bin/env bash
# Assertions for the hook and manifest tests. Deliberately tiny: the
# things under test are shell scripts, so the harness is shell too, and
# nothing here needs installing.
CHECKS_RUN=0
CHECKS_FAILED=0

_pass() { printf '  ok   %s\n' "$1"; }
_fail() { CHECKS_FAILED=$((CHECKS_FAILED + 1)); printf '  FAIL %s\n' "$1" >&2; }

check() { # label actual expected
    CHECKS_RUN=$((CHECKS_RUN + 1))
    if [ "$2" = "$3" ]; then _pass "$1"; else _fail "$1 — expected [$3], got [$2]"; fi
}

contains() { # label haystack needle
    CHECKS_RUN=$((CHECKS_RUN + 1))
    case "$2" in *"$3"*) _pass "$1" ;; *) _fail "$1 — [$2] lacks [$3]" ;; esac
}

not_contains() { # label haystack needle
    CHECKS_RUN=$((CHECKS_RUN + 1))
    case "$2" in *"$3"*) _fail "$1 — [$2] contains [$3]" ;; *) _pass "$1" ;; esac
}

summary() {
    printf '\n%s checks, %s failed\n' "$CHECKS_RUN" "$CHECKS_FAILED"
    [ "$CHECKS_FAILED" -eq 0 ]
}
```

Create `tests/run-tests.sh`:

```bash
#!/usr/bin/env bash
# Runs every tests/test-*.sh against the repository root.
set -uo pipefail
cd "$(dirname "$0")/.." || exit 1
. tests/lib/harness.sh

for t in tests/test-*.sh; do
    printf '\n%s\n' "$t"
    . "$t"
done

summary
```

- [ ] **Step 3: Run the tests to verify they fail**

Run: `bash tests/run-tests.sh`
Expected: FAIL — every check reports an empty actual value, because neither manifest exists yet.

- [ ] **Step 4: Write the manifests**

Create `.claude-plugin/marketplace.json`:

```json
{
  "$schema": "https://anthropic.com/claude-code/marketplace.schema.json",
  "name": "claude-standards",
  "description": "Cross-project development standard: spec-driven workflow, prescribed stacks, conformance hooks",
  "owner": {
    "name": "Frufus",
    "email": "github@frufus.de"
  },
  "plugins": [
    {
      "name": "dev-standards",
      "description": "Spec-driven development standard. Reports project conformance at session start, reminds when source is edited without an active OpenSpec change, checks commit messages, and scaffolds new projects from two prescribed stack profiles.",
      "author": {
        "name": "Frufus",
        "email": "github@frufus.de"
      },
      "category": "development",
      "source": "./plugins/dev-standards"
    }
  ]
}
```

Create `plugins/dev-standards/.claude-plugin/plugin.json`:

```json
{
  "name": "dev-standards",
  "version": "0.1.0",
  "description": "Spec-driven development standard. Reports project conformance at session start, reminds when source is edited without an active OpenSpec change, checks commit messages, and scaffolds new projects from two prescribed stack profiles.",
  "author": {
    "name": "Frufus",
    "email": "github@frufus.de"
  }
}
```

- [ ] **Step 5: Run the tests to verify they pass**

Run: `bash tests/run-tests.sh`
Expected: `6 checks, 0 failed`

- [ ] **Step 6: Commit**

```bash
git add .claude-plugin plugins tests
git commit -m "feat: add marketplace and plugin manifests with a test harness"
```

---

### Task 2: `json-fields.js` — the single JSON reader

**Files:**
- Create: `plugins/dev-standards/hooks/lib/json-fields.js`
- Test: `tests/test-json-fields.sh`

**Interfaces:**
- Consumes: nothing.
- Produces: `node json-fields.js <path> [<path>...]` reads JSON on stdin and writes the values at those dotted paths to stdout, tab-separated, on one line, followed by a newline. A missing path, a non-scalar value, or unparseable input yields an empty field, never an error. Tabs, carriage returns and newlines inside values become spaces so the tab-separated line stays one line. Array length is reachable as `changes.length`. Every hook in Tasks 5–7 reads its input through exactly one call to this script.

- [ ] **Step 1: Write the failing test**

Create `tests/test-json-fields.sh`:

```bash
JF="plugins/dev-standards/hooks/lib/json-fields.js"

out=$(printf '%s' '{"tool_input":{"file_path":"C:\\src\\a.ts"},"cwd":"C:\\proj"}' \
      | node "$JF" tool_input.file_path cwd 2>/dev/null)
check "reads two dotted paths" "$out" "$(printf 'C:\\src\\a.ts\tC:\\proj')"

out=$(printf '%s' '{"changes":[{"id":"a"},{"id":"b"}],"root":{"path":"/p"}}' \
      | node "$JF" changes.length root.path 2>/dev/null)
check "array length and nested path" "$out" "$(printf '2\t/p')"

out=$(printf '%s' '{"root":null}' | node "$JF" root.path 2>/dev/null)
check "null parent yields empty" "$out" ""

out=$(printf '%s' '{"a":{"b":1}}' | node "$JF" a 2>/dev/null)
check "object value yields empty" "$out" ""

out=$(printf '%s' 'not json at all' | node "$JF" a.b 2>/dev/null)
check "unparseable input yields empty" "$out" ""

printf '%s' 'not json' | node "$JF" a.b >/dev/null 2>&1
check "unparseable input still exits 0" "$?" "0"

out=$(printf '%s' '{"m":"line one\nline two"}' | node "$JF" m 2>/dev/null)
check "newlines inside a value are flattened" "$out" "line one line two"
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `bash tests/run-tests.sh`
Expected: FAIL — `Cannot find module ... json-fields.js`, so every check gets an empty actual value.

- [ ] **Step 3: Write the implementation**

Create `plugins/dev-standards/hooks/lib/json-fields.js`:

```js
// Reads a JSON object on stdin and writes the values at the dotted paths
// given as arguments, tab-separated, on a single line.
//
// Hooks must never fail on unexpected input: a shape this script did not
// expect has to degrade to an empty field, not to a stack trace that
// Claude Code surfaces as a broken hook. So every failure path here ends
// in an empty string and exit code 0.
let raw = "";
process.stdin.on("data", (d) => (raw += d)).on("end", () => {
  let root;
  try {
    root = JSON.parse(raw);
  } catch {
    root = undefined;
  }

  const fields = process.argv.slice(2).map((path) => {
    let value = root;
    for (const key of path.split(".")) {
      if (value === null || typeof value !== "object") return "";
      value = value[key];
    }
    // Objects and arrays have no scalar rendering. `changes.length`
    // reaches a number through the same walk, which is the only way a
    // caller needs to ask about a collection.
    if (value === null || value === undefined || typeof value === "object") return "";
    // The output is one tab-separated line; anything in a value that
    // would break that becomes a space.
    return String(value).replace(/[\t\r\n]/g, " ");
  });

  process.stdout.write(fields.join("\t") + "\n");
});
```

- [ ] **Step 4: Run the test to verify it passes**

Run: `bash tests/run-tests.sh`
Expected: `13 checks, 0 failed`

- [ ] **Step 5: Commit**

```bash
git add plugins/dev-standards/hooks/lib/json-fields.js tests/test-json-fields.sh
git commit -m "feat: add json-fields reader for hook input"
```

---

### Task 3: `paths.sh` — source-file classification

**Files:**
- Create: `plugins/dev-standards/hooks/lib/paths.sh`
- Test: `tests/test-paths.sh`

**Interfaces:**
- Consumes: nothing.
- Produces: two shell functions, sourced by the hook in Task 6.
  - `rel_path <absolute_file> <project_root>` writes the file's path relative to the root, lowercased, with backslashes turned into forward slashes. When the file is not under the root it writes the converted absolute path unchanged.
  - `is_source_path <relative_path>` returns 0 for a source file and 1 for anything excluded: `openspec/`, `docs/`, `.claude/`, any dotfile at any depth, and lockfiles.

Lowercasing is deliberate. On Windows the same directory reaches a hook as `C:\Users\...` from one caller and `c:/users/...` from another, and a case-sensitive prefix strip would silently fail to make the path relative — which would classify every file as outside the project.

- [ ] **Step 1: Write the failing test**

Create `tests/test-paths.sh`:

```bash
. plugins/dev-standards/hooks/lib/paths.sh 2>/dev/null

check "strips the root and normalises separators" \
  "$(rel_path 'C:\proj\src\a.ts' 'C:\proj')" "src/a.ts"
check "tolerates a case-mismatched root" \
  "$(rel_path 'C:\Proj\Src\A.ts' 'c:/proj')" "src/a.ts"
check "a file outside the root stays absolute" \
  "$(rel_path 'D:\other\a.ts' 'C:\proj')" "d:/other/a.ts"

is_source_path "src/a.ts";            check "src is source" "$?" "0"
is_source_path "main.py";             check "a root module is source" "$?" "0"
is_source_path "backend/app/db.py";   check "nested source is source" "$?" "0"
is_source_path "openspec/config.yaml";check "openspec is excluded" "$?" "1"
is_source_path "docs/adr/0001-x.md";  check "docs is excluded" "$?" "1"
is_source_path ".claude/settings.json";check ".claude is excluded" "$?" "1"
is_source_path ".gitignore";          check "root dotfile is excluded" "$?" "1"
is_source_path "src/.env";            check "nested dotfile is excluded" "$?" "1"
is_source_path "package-lock.json";   check "npm lockfile is excluded" "$?" "1"
is_source_path "uv.lock";             check "uv lockfile is excluded" "$?" "1"
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `bash tests/run-tests.sh`
Expected: FAIL — `rel_path: command not found`, and every `is_source_path` check reports `127`.

- [ ] **Step 3: Write the implementation**

Create `plugins/dev-standards/hooks/lib/paths.sh`:

```bash
#!/usr/bin/env bash
# Path classification for the source-guard hook.

rel_path() { # absolute_file project_root -> path relative to root
    local file="${1//\\//}" root="${2//\\//}"
    file=$(printf '%s' "$file" | tr '[:upper:]' '[:lower:]')
    root=$(printf '%s' "$root" | tr '[:upper:]' '[:lower:]')
    root="${root%/}"
    # Case is folded before the prefix strip because the same directory
    # reaches a hook as both `C:\proj` and `c:/proj` depending on who
    # called it. A failed strip would leave an absolute path, which
    # is_source_path would then read as a source file outside every
    # exclusion — the guard would fire on documentation.
    case "$file" in
        "$root"/*) file="${file#"$root"/}" ;;
    esac
    printf '%s' "$file"
}

is_source_path() { # relative_path -> 0 when it is source
    case "$1" in
        openspec/*|docs/*|.claude/*) return 1 ;;
        .*|*/.*) return 1 ;;
        *.lock|*-lock.json|*.lockb) return 1 ;;
        *) return 0 ;;
    esac
}
```

- [ ] **Step 4: Run the test to verify it passes**

Run: `bash tests/run-tests.sh`
Expected: `26 checks, 0 failed`

- [ ] **Step 5: Commit**

```bash
git add plugins/dev-standards/hooks/lib/paths.sh tests/test-paths.sh
git commit -m "feat: classify source paths by exclusion"
```

---

### Task 4: `os-context.sh` — OpenSpec state

**Files:**
- Create: `plugins/dev-standards/hooks/lib/os-context.sh`
- Test: `tests/test-os-context.sh`

**Interfaces:**
- Consumes: `json-fields.js` from Task 2.
- Produces: `os_context <directory>`, which sets two variables and always returns 0:
  - `OS_ROOT` — the absolute path of the OpenSpec root, or empty when the directory is not under one, or empty when the `openspec` binary is missing.
  - `OS_CHANGES` — the number of changes currently in flight, `0` when there are none or the state could not be read.

`openspec` is spawned exactly once per call and its output parsed in one `node` invocation. Two spawns per hook fire would be roughly 200 ms on Windows, which is felt on every edit.

- [ ] **Step 1: Write the failing test**

Create `tests/test-os-context.sh`:

```bash
. plugins/dev-standards/hooks/lib/os-context.sh 2>/dev/null

# A directory with no OpenSpec root anywhere above it. The system temp
# directory is used rather than a repository path because this
# repository is itself inside the workspace and may gain an openspec/
# later, which would silently invert this assertion.
outside=$(mktemp -d)
os_context "$outside"
check "no root outside an OpenSpec project" "$OS_ROOT" ""
check "no changes outside an OpenSpec project" "$OS_CHANGES" "0"

# `read` treats a tab as IFS whitespace regardless of what IFS is set
# to, so without pipefail — the bash default — a leading empty field
# used to be dropped and "0" shifted into OS_ROOT instead of
# OS_CHANGES. Exercise that path by turning pipefail off, then
# restoring it — not via a subshell, because `check`'s pass/fail
# counters are plain globals and a subshell's updates to them would
# never reach this script, letting a failing regression here pass
# `tests/run-tests.sh` silently.
pipefail_state=$(shopt -po pipefail)
set +o pipefail
os_context "$outside"
check "OS_ROOT stays empty without pipefail" "$OS_ROOT" ""
eval "$pipefail_state"

rmdir "$outside"

# A directory that does not exist at all.
os_context "/definitely/not/a/directory"
check "a missing directory yields no root" "$OS_ROOT" ""
check "a missing directory yields zero changes" "$OS_CHANGES" "0"

os_context "$outside" >/dev/null 2>&1
check "os_context always returns 0" "$?" "0"
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `bash tests/run-tests.sh`
Expected: FAIL — `os_context: command not found`; `OS_ROOT` and `OS_CHANGES` are unset.

- [ ] **Step 3: Write the implementation**

Create `plugins/dev-standards/hooks/lib/os-context.sh`:

```bash
#!/usr/bin/env bash
# Resolves OpenSpec state for a directory.

os_context() { # directory -> sets OS_ROOT, OS_CHANGES
    OS_ROOT=""
    OS_CHANGES=0

    local lib line
    lib="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/json-fields.js"

    command -v openspec >/dev/null 2>&1 || return 0
    [ -d "$1" ] || return 0

    # One openspec spawn, one node spawn. `openspec list --json` exits 0
    # both inside and outside a project and reports the difference as
    # root: null, so the exit code carries no information and only the
    # payload is read.
    line=$( (cd "$1" && openspec list --json 2>/dev/null) \
            | node "$lib" root.path changes.length 2>/dev/null ) || return 0

    # `read` always treats a tab as IFS whitespace no matter what IFS is
    # set to, so a leading empty field (no OpenSpec root) gets silently
    # collapsed and the change count shifts into OS_ROOT instead. Split
    # on the literal tab with parameter expansion, which does not.
    case "$line" in
        *$'\t'*)
            OS_ROOT="${line%%$'\t'*}"
            OS_CHANGES="${line#*$'\t'}"
            ;;
        *)
            # Defensive: json-fields.js always emits a tab-joined line,
            # so a line with none is malformed output, not a real
            # single-field result — treat it as no usable data at all.
            OS_ROOT=""
            OS_CHANGES=""
            ;;
    esac
    [ -n "$OS_CHANGES" ] || OS_CHANGES=0
    return 0
}
```

- [ ] **Step 4: Run the test to verify it passes**

Run: `bash tests/run-tests.sh`
Expected: `32 checks, 0 failed`

- [ ] **Step 5: Commit**

```bash
git add plugins/dev-standards/hooks/lib/os-context.sh tests/test-os-context.sh
git commit -m "feat: resolve OpenSpec root and in-flight change count"
```

---

### Task 5: SessionStart conformance hook

**Files:**
- Create: `plugins/dev-standards/hooks/check-conformance.sh`
- Create: `plugins/dev-standards/hooks/hooks.json`
- Test: `tests/test-conformance.sh`

**Interfaces:**
- Consumes: `json-fields.js` from Task 2. Not `os-context.sh` — see the comment in the hook.
- Produces: `hooks.json`, extended by Tasks 6 and 7. A `SessionStart` hook reading `{"cwd": "..."}` on stdin and writing `{"hookSpecificOutput": {"hookEventName": "SessionStart", "additionalContext": "..."}}` on stdout. When the project is fully conforming it writes nothing at all and exits 0, so a conforming project pays no context for the check.

- [ ] **Step 1: Write the failing test**

Create `tests/test-conformance.sh`:

```bash
HOOK="plugins/dev-standards/hooks/check-conformance.sh"

# A bare directory: no openspec/, no CLAUDE.md, no docs/adr/.
bare=$(mktemp -d)
out=$(printf '{"cwd":"%s"}' "$bare" | bash "$HOOK" 2>/dev/null)
contains "reports the missing openspec directory" "$out" "openspec"
contains "reports the missing CLAUDE.md"          "$out" "CLAUDE.md"
contains "reports the missing docs/adr"           "$out" "docs/adr"
contains "declares the SessionStart event"        "$out" "SessionStart"
not_contains "never denies"                       "$out" "permissionDecision"

printf '{"cwd":"%s"}' "$bare" | bash "$HOOK" >/dev/null 2>&1
check "exits 0 on a non-conforming project" "$?" "0"

# A project carrying every artifact, with a declared profile.
full=$(mktemp -d)
mkdir -p "$full/openspec" "$full/docs/adr"
printf 'schema: spec-driven\nprofile: web\n' > "$full/openspec/config.yaml"
printf '# CLAUDE.md\n' > "$full/CLAUDE.md"
out=$(printf '{"cwd":"%s"}' "$full" | bash "$HOOK" 2>/dev/null)
check "a conforming project produces no output" "$out" ""

# A project with an openspec/ but no profile key.
noprofile=$(mktemp -d)
mkdir -p "$noprofile/openspec" "$noprofile/docs/adr"
printf 'schema: spec-driven\n' > "$noprofile/openspec/config.yaml"
printf '# CLAUDE.md\n' > "$noprofile/CLAUDE.md"
out=$(printf '{"cwd":"%s"}' "$noprofile" | bash "$HOOK" 2>/dev/null)
contains "reports an unprofiled project" "$out" "unprofiled"

out=$(printf 'not json' | bash "$HOOK" 2>/dev/null)
check "malformed input produces no output" "$out" ""
printf 'not json' | bash "$HOOK" >/dev/null 2>&1
check "malformed input still exits 0" "$?" "0"

rm -rf "$bare" "$full" "$noprofile"
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `bash tests/run-tests.sh`
Expected: FAIL — the hook does not exist, so `bash` reports "No such file or directory" and every `contains` check finds an empty string.

- [ ] **Step 3: Write the hook**

Create `plugins/dev-standards/hooks/check-conformance.sh`:

```bash
#!/usr/bin/env bash
# SessionStart: reports which parts of the standard this project is
# missing. Reports only — a project is allowed to be non-conforming, and
# saying so once per session is the whole job.
set -uo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Deliberately does NOT use os-context.sh. That helper resolves the
# nearest OpenSpec root, which may be a parent directory; this hook asks
# whether THIS project carries the artifacts, so it tests the directory.
input=$(cat)
cwd=$(printf '%s' "$input" | node "$HERE/lib/json-fields.js" cwd 2>/dev/null)
[ -n "$cwd" ] || exit 0
[ -d "$cwd" ] || exit 0

missing=""
add() { missing="${missing}
- $1"; }

if [ ! -d "$cwd/openspec" ]; then
    add "no \`openspec/\` — this project has no specification mechanism. Run \`openspec init --tools claude\`."
elif ! grep -qE '^profile:[[:space:]]*(web|python)[[:space:]]*$' "$cwd/openspec/config.yaml" 2>/dev/null; then
    add "unprofiled — \`openspec/config.yaml\` declares no \`profile: web\` or \`profile: python\`."
fi

[ -f "$cwd/CLAUDE.md" ] || add "no \`CLAUDE.md\` — nothing orients a session in this project."
[ -d "$cwd/docs/adr" ] || add "no \`docs/adr/\` — architecture decisions have nowhere to live."

# A conforming project gets no output at all. Anything written here is
# spent context in every session for the life of the project.
[ -n "$missing" ] || exit 0

notice="This project does not follow the development standard:${missing}

Offer to fix this before starting work; do not fix it silently."

printf '%s' "$notice" | node -e '
let s="";process.stdin.on("data",d=>s+=d).on("end",()=>{
  process.stdout.write(JSON.stringify({
    hookSpecificOutput: { hookEventName: "SessionStart", additionalContext: s }
  }));
});'
exit 0
```

- [ ] **Step 4: Write `hooks.json`**

Create `plugins/dev-standards/hooks/hooks.json`:

```json
{
  "description": "Development standard: conformance report at session start, reminders on source edits and commits",
  "hooks": {
    "SessionStart": [
      {
        "hooks": [
          {
            "type": "command",
            "command": "bash \"${CLAUDE_PLUGIN_ROOT}/hooks/check-conformance.sh\""
          }
        ]
      }
    ]
  }
}
```

- [ ] **Step 5: Run the tests to verify they pass**

Run: `bash tests/run-tests.sh`
Expected: `41 checks, 0 failed`

- [ ] **Step 6: Commit**

```bash
git add plugins/dev-standards/hooks/check-conformance.sh plugins/dev-standards/hooks/hooks.json tests/test-conformance.sh
git commit -m "feat: report project conformance at session start"
```

---

### Task 6: PreToolUse source-guard hook

**Files:**
- Create: `plugins/dev-standards/hooks/guard-change.sh`
- Modify: `plugins/dev-standards/hooks/hooks.json`
- Test: `tests/test-guard-change.sh`

**Interfaces:**
- Consumes: `paths.sh` from Task 3, `os-context.sh` from Task 4, `json-fields.js` from Task 2.
- Produces: a `PreToolUse` hook matching `Edit|Write`. It reads `{"tool_input": {"file_path": "..."}, "cwd": "..."}` and writes `{"hookSpecificOutput": {"hookEventName": "PreToolUse", "additionalContext": "..."}}` when a source file is edited inside an OpenSpec project with no change in flight. It stays silent in every other case, and never emits `permissionDecision`.

- [ ] **Step 1: Write the failing test**

Create `tests/test-guard-change.sh`:

```bash
HOOK="plugins/dev-standards/hooks/guard-change.sh"

# Outside an OpenSpec project the guard has no opinion: a project that
# has not adopted the standard is the conformance hook's business, not
# this one's, and warning on every edit would train the user to ignore it.
plain=$(mktemp -d)
out=$(printf '{"cwd":"%s","tool_input":{"file_path":"%s/src/a.ts"}}' "$plain" "$plain" \
      | bash "$HOOK" 2>/dev/null)
check "silent outside an OpenSpec project" "$out" ""

# Excluded paths never warn, even inside a project with no active change.
proj=$(mktemp -d)
mkdir -p "$proj/openspec" "$proj/docs/adr"
for excluded in "openspec/config.yaml" "docs/adr/0001-x.md" ".gitignore" "package-lock.json"; do
    out=$(printf '{"cwd":"%s","tool_input":{"file_path":"%s/%s"}}' "$proj" "$proj" "$excluded" \
          | bash "$HOOK" 2>/dev/null)
    check "silent for $excluded" "$out" ""
done

out=$(printf '{"cwd":"%s","tool_input":{"file_path":""}}' "$proj" | bash "$HOOK" 2>/dev/null)
check "silent when no file path is given" "$out" ""

out=$(printf 'not json' | bash "$HOOK" 2>/dev/null)
check "silent on malformed input" "$out" ""
printf 'not json' | bash "$HOOK" >/dev/null 2>&1
check "exits 0 on malformed input" "$?" "0"

rm -rf "$plain" "$proj"
```

The warning path itself is verified end to end in Task 12 against a real
OpenSpec project. Simulating an OpenSpec root here would mean reimplementing
the CLI's root resolution in the test, and a test that reimplements the thing
it is testing proves nothing.

- [ ] **Step 2: Run the test to verify it fails**

Run: `bash tests/run-tests.sh`
Expected: FAIL — the hook does not exist; `bash` writes "No such file or directory" to stderr and the `check` for a silent run on malformed input reports exit code `127`.

- [ ] **Step 3: Write the hook**

Create `plugins/dev-standards/hooks/guard-change.sh`:

```bash
#!/usr/bin/env bash
# PreToolUse on Edit|Write: reminds when source is edited with no
# OpenSpec change in flight.
#
# This hook NEVER denies. A guard that blocks legitimate work — a typo in
# a comment, a hotfix, repairing a broken build — gets switched off, and
# then it protects nothing.
set -uo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$HERE/lib/paths.sh"
. "$HERE/lib/os-context.sh"

input=$(cat)
IFS=$'\t' read -r file_path cwd < <(
    printf '%s' "$input" | node "$HERE/lib/json-fields.js" tool_input.file_path cwd 2>/dev/null
)

[ -n "${file_path:-}" ] || exit 0
[ -n "${cwd:-}" ] || exit 0

os_context "$cwd"
# No OpenSpec root means the project has not adopted the standard. That
# is the conformance hook's subject, once per session; repeating it on
# every edit would make both messages ignorable.
[ -n "$OS_ROOT" ] || exit 0
# A change is already in flight — this edit is the work it describes.
[ "$OS_CHANGES" = "0" ] || exit 0

rel=$(rel_path "$file_path" "$OS_ROOT")
is_source_path "$rel" || exit 0

notice="No OpenSpec change is in flight, and \`$rel\` is a source file.

Work starts as a change proposal, not as code. Write one with \`openspec change\` and get it approved before implementing, unless this edit is a hotfix or a repair — in which case say so and continue."

printf '%s' "$notice" | node -e '
let s="";process.stdin.on("data",d=>s+=d).on("end",()=>{
  process.stdout.write(JSON.stringify({
    hookSpecificOutput: { hookEventName: "PreToolUse", additionalContext: s }
  }));
});'
exit 0
```

- [ ] **Step 4: Register the hook**

In `plugins/dev-standards/hooks/hooks.json`, add a `PreToolUse` key as a sibling of `SessionStart`:

```json
    "PreToolUse": [
      {
        "matcher": "Edit|Write",
        "hooks": [
          {
            "type": "command",
            "command": "bash \"${CLAUDE_PLUGIN_ROOT}/hooks/guard-change.sh\""
          }
        ]
      }
    ]
```

- [ ] **Step 5: Run the tests to verify they pass**

Run: `bash tests/run-tests.sh`
Expected: `49 checks, 0 failed`

- [ ] **Step 6: Commit**

```bash
git add plugins/dev-standards/hooks/guard-change.sh plugins/dev-standards/hooks/hooks.json tests/test-guard-change.sh
git commit -m "feat: remind when source is edited without an active change"
```

---

### Task 7: PreToolUse commit-message hook

**Files:**
- Create: `plugins/dev-standards/hooks/check-commit-msg.sh`
- Modify: `plugins/dev-standards/hooks/hooks.json`
- Test: `tests/test-commit-msg.sh`

**Interfaces:**
- Consumes: `json-fields.js` from Task 2.
- Produces: a `PreToolUse` hook matching `Bash`. It inspects `tool_input.command`, ignores everything that is not a `git commit`, and reports when the subject line is not a Conventional Commit or exceeds 72 characters.

**Known limitation, stated deliberately:** a message passed via `-F -` or `--file` arrives on the command's stdin, not in the command string, so the hook cannot see it and stays silent. Only `-m` messages are checked. Making this a denial would therefore punish exactly the callers that use the more robust invocation.

- [ ] **Step 1: Write the failing test**

Create `tests/test-commit-msg.sh`:

```bash
HOOK="plugins/dev-standards/hooks/check-commit-msg.sh"

msg_out() { printf '{"tool_input":{"command":%s}}' "$1" | bash "$HOOK" 2>/dev/null; }

check "a conventional subject passes" \
  "$(msg_out '"git commit -m \"feat: add the thing\""')" ""
check "a scoped subject passes" \
  "$(msg_out '"git commit -m \"fix(parser): handle empty input\""')" ""
check "a breaking-change marker passes" \
  "$(msg_out '"git commit -m \"feat!: drop the old format\""')" ""

contains "an unconventional subject is reported" \
  "$(msg_out '"git commit -m \"added the thing\""')" "Conventional Commits"

long=$(printf 'feat: %0.sx' $(seq 1 80))
contains "an over-long subject is reported" \
  "$(msg_out "\"git commit -m \\\"$long\\\"\"")" "72"

check "a non-commit git command is ignored" \
  "$(msg_out '"git status --short"')" ""
check "an unrelated command is ignored" \
  "$(msg_out '"npm run test"')" ""
check "a heredoc message is out of reach and stays silent" \
  "$(msg_out '"git commit -F -"')" ""

not_contains "never denies" \
  "$(msg_out '"git commit -m \"added the thing\""')" "permissionDecision"

printf 'not json' | bash "$HOOK" >/dev/null 2>&1
check "exits 0 on malformed input" "$?" "0"
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `bash tests/run-tests.sh`
Expected: FAIL — the hook does not exist; the two `contains` checks find an empty string and the malformed-input check reports `127`.

- [ ] **Step 3: Write the hook**

Create `plugins/dev-standards/hooks/check-commit-msg.sh`:

```bash
#!/usr/bin/env bash
# PreToolUse on Bash: checks a `git commit -m` subject line against
# Conventional Commits and the 72-character limit. Reports; never denies.
set -uo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

input=$(cat)
command_line=$(printf '%s' "$input" | node "$HERE/lib/json-fields.js" tool_input.command 2>/dev/null)

case "$command_line" in
    *"git commit"*) ;;
    *) exit 0 ;;
esac

# Only -m messages are visible here. A message on stdin (`-F -`) never
# reaches the command string, and inventing a warning for it would fire
# on every correctly-formed heredoc commit.
subject=$(printf '%s' "$command_line" \
    | sed -n 's/.*-m[[:space:]]*"\([^"]*\)".*/\1/p' \
    | head -n 1)
[ -n "$subject" ] || exit 0

problems=""
if ! printf '%s' "$subject" | grep -qE '^(feat|fix|docs|chore|test|ci|refactor|perf|build|style|revert)(\([^)]+\))?!?: .+'; then
    problems="${problems}
- The subject is not a Conventional Commit. Use \`type(scope): subject\` with one of feat, fix, docs, chore, test, ci, refactor, perf, build, style, revert."
fi
if [ "${#subject}" -gt 72 ]; then
    problems="${problems}
- The subject is ${#subject} characters; the limit is 72. Move the detail into the body."
fi

[ -n "$problems" ] || exit 0

notice="This commit message does not follow the standard:${problems}

Subject: ${subject}"

printf '%s' "$notice" | node -e '
let s="";process.stdin.on("data",d=>s+=d).on("end",()=>{
  process.stdout.write(JSON.stringify({
    hookSpecificOutput: { hookEventName: "PreToolUse", additionalContext: s }
  }));
});'
exit 0
```

- [ ] **Step 4: Register the hook**

In `plugins/dev-standards/hooks/hooks.json`, add a second entry to the existing `PreToolUse` array:

```json
      {
        "matcher": "Bash",
        "hooks": [
          {
            "type": "command",
            "command": "bash \"${CLAUDE_PLUGIN_ROOT}/hooks/check-commit-msg.sh\""
          }
        ]
      }
```

- [ ] **Step 5: Run the tests to verify they pass**

Run: `bash tests/run-tests.sh`
Expected: `59 checks, 0 failed`

- [ ] **Step 6: Commit**

```bash
git add plugins/dev-standards/hooks/check-commit-msg.sh plugins/dev-standards/hooks/hooks.json tests/test-commit-msg.sh
git commit -m "feat: check commit subjects against the convention"
```

---

### Task 8: Templates — shared rules, ADR, and both profiles

**Files:**
- Create: `plugins/dev-standards/templates/shared/config.rules.yaml`
- Create: `plugins/dev-standards/templates/adr/TEMPLATE.md`
- Create: `plugins/dev-standards/templates/web/config.fragment.yaml`
- Create: `plugins/dev-standards/templates/web/CLAUDE.md`
- Create: `plugins/dev-standards/templates/python/config.fragment.yaml`
- Create: `plugins/dev-standards/templates/python/CLAUDE.md`
- Test: `tests/test-templates.sh`

**Interfaces:**
- Consumes: nothing.
- Produces: the files Task 11's `new-project` skill assembles. A generated `openspec/config.yaml` is the profile fragment, then the shared rules block, then a project-specific `context:` the skill writes. Each `config.fragment.yaml` carries `schema: spec-driven` and its `profile:` key so the conformance hook of Task 5 recognises the result.

- [ ] **Step 1: Write the failing test**

Create `tests/test-templates.sh`:

```bash
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
    check "$(basename "$(dirname "$f")")/$(basename "$f") has no tab indentation" \
      "$(grep -cP '^\t' "$f" 2>/dev/null || echo 0)" "0"
done
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `bash tests/run-tests.sh`
Expected: FAIL — no template file exists, so every `contains` check finds an empty string.

- [ ] **Step 3: Write the shared rules and the ADR template**

Create `plugins/dev-standards/templates/shared/config.rules.yaml`:

```yaml
rules:
  proposal:
    - Include a "Non-Goals" subsection under "What Changes" naming what this change deliberately does not do.
    - State the user-visible outcome. A change whose outcome is only internal says so explicitly and justifies itself.
  specs:
    - Write requirements as observable behaviour, checkable by someone who cannot read the code.
    - Include at least one scenario for the unhappy path - no data, bad data, or a failure of something external.
    - Data crossing a process boundary is parsed into a known shape before anything else touches it. Say which shape.
  design:
    - Name the alternatives that were rejected and why, not only the chosen approach.
    - Call out anything that depends on third-party behaviour or data quality as an explicit risk.
  tasks:
    - Every task states how it is verified - a test name, a command, or an observable check.
    - Group tasks so that pure logic is testable before any UI or I/O task starts.

operations:
  apply:
    guidance:
      - Run the touched area's tests before the full suite.
      - A deviation from the spec is named and justified before it is built, never discovered afterwards in the diff.
  archive:
    guidance:
      - Keep the completion summary to what changed in observable behaviour.
      - Note any spec requirement this change made obsolete.
```

Create `plugins/dev-standards/templates/adr/TEMPLATE.md`:

```markdown
# ADR-NNNN: <title>

Status: proposed | accepted | superseded by ADR-NNNN · Date: YYYY-MM-DD · Affects: <capability or change id>

## Context

What forces this decision, and what constraint makes it hard. State the
numbers that matter — sizes, limits, rates — because they are what make
the decision reviewable later.

## Decisions

Numbered. Each one states what was chosen AND what was rejected, with the
reason. A decision without its rejected alternative cannot be re-evaluated
when the constraint changes.

## Consequences

What this makes easy, what it makes hard, and what now has to stay true
for it to keep working.
```

- [ ] **Step 4: Write the profile fragments and CLAUDE.md templates**

Create `plugins/dev-standards/templates/web/config.fragment.yaml`:

```yaml
schema: spec-driven
profile: web
```

Create `plugins/dev-standards/templates/python/config.fragment.yaml`:

```yaml
schema: spec-driven
profile: python
```

Create `plugins/dev-standards/templates/web/CLAUDE.md`:

```markdown
# CLAUDE.md

<one or two sentences: what this project is, for whom>

**The binding project truth is `openspec/config.yaml`.** Product, non-negotiables,
tech stack and domain vocabulary live in its `context:` block. Current
requirements are the capability specs under `openspec/specs/`; anything under
`openspec/changes/` is proposed, not built.

## Commands

```
npm run dev        # Vite dev server
npm run test       # Vitest
npm run test:e2e   # Playwright
npm run lint       # ESLint
npm run typecheck  # vue-tsc
npm run format     # Prettier
```

## Directories

```
src/               Application code
openspec/          Binding specs and change proposals
docs/adr/          Architecture decisions
tests/             Unit and end-to-end tests
```
```

Create `plugins/dev-standards/templates/python/CLAUDE.md`:

```markdown
# CLAUDE.md

<one or two sentences: what this project is, for whom>

**The binding project truth is `openspec/config.yaml`.** Product, non-negotiables,
tech stack and domain vocabulary live in its `context:` block. Current
requirements are the capability specs under `openspec/specs/`; anything under
`openspec/changes/` is proposed, not built.

## Commands

```
uv sync            # install dependencies
uv run pytest      # tests
uv run ruff check  # lint
uv run ruff format # format
uv run mypy .      # typecheck, strict
```

## Directories

```
src/               Application code
openspec/          Binding specs and change proposals
docs/adr/          Architecture decisions
tests/             Tests
```
```

- [ ] **Step 5: Run the tests to verify they pass**

Run: `bash tests/run-tests.sh`
Expected: `76 checks, 0 failed`

- [ ] **Step 6: Commit**

```bash
git add plugins/dev-standards/templates tests/test-templates.sh
git commit -m "feat: add shared rules, ADR template and both stack profiles"
```

---

### Task 9: Skills `adr` and `sdd-change`

**Files:**
- Create: `plugins/dev-standards/skills/adr/SKILL.md`
- Create: `plugins/dev-standards/skills/sdd-change/SKILL.md`
- Test: `tests/test-skills.sh`

**Interfaces:**
- Consumes: `templates/adr/TEMPLATE.md` from Task 8.
- Produces: two invocable skills. Task 11 adds a third to the same directory and extends the same test file.

- [ ] **Step 1: Write the failing test**

Create `tests/test-skills.sh`:

```bash
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
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `bash tests/run-tests.sh`
Expected: FAIL — neither `SKILL.md` exists; the frontmatter checks report an empty first line.

- [ ] **Step 3: Write the ADR skill**

Create `plugins/dev-standards/skills/adr/SKILL.md`:

```markdown
---
name: adr
description: Write an architecture decision record. Use when a change makes a choice that outlives it — a format, a boundary, a dependency, a data model — or when a spec's open question must be settled before work can continue.
---

# Writing an ADR

An ADR exists so the decision can be re-evaluated later by someone who was
not there. That means it must record what was rejected, not only what was
chosen: a decision without its alternatives cannot be revisited when the
constraint that drove it changes.

## Process

1. Read `${CLAUDE_PLUGIN_ROOT}/templates/adr/TEMPLATE.md`.
2. Find the next number: `ls docs/adr/ | sort | tail -n 1`. Numbers are
   four digits and never reused, including for superseded records.
3. Write `docs/adr/NNNN-kebab-title.md` from the template.
4. State the numbers that make the decision hard — sizes, limits, rates,
   measured timings. A decision recorded without them reads as a
   preference a year later.
5. For every decision, name the alternative you rejected and why. If you
   cannot name one, you have recorded a fact, not a decision — either find
   the alternative or leave it out of the ADR.
6. Link the ADR from the change that produced it.

## What is not an ADR

A choice the spec already binds, a library version bump, a naming
preference, or anything you would not defend in six months. ADRs that
record trivia make the ones that matter unfindable.
```

- [ ] **Step 4: Write the change-workflow skill**

Create `plugins/dev-standards/skills/sdd-change/SKILL.md`:

```markdown
---
name: sdd-change
description: Drive a unit of work from proposal to archive under the spec-driven standard. Use when starting any feature, fix, or refactor in a project that has an openspec/ directory.
---

# Running a change

Work starts as a proposal, not as code. The proposal is what the human
approves; the code is what follows from it.

## Process

1. **Propose.** `openspec change` — write `proposal.md` with a Non-Goals
   subsection, the affected capability spec deltas under `specs/`, and
   `tasks.md` where every task states how it is verified.
2. **Stop.** Present the proposal and wait for approval. This gate is the
   point of the whole workflow; skipping it makes the rest ceremony.
3. **Branch.** `git switch -c claude/<topic>` from current `main`. One
   branch per unit of work, never reused — a reused branch makes it
   impossible to say which commits a pull request contains.
4. **Implement**, task by task, tests first. Commit as each task
   completes, not in one batch at the end.
5. **Record decisions.** Anything that outlives the change becomes an ADR
   — invoke the `adr` skill.
6. **Deviate openly.** If the implementation must depart from the spec,
   say so and justify it before building the departure. A deviation found
   afterwards in the diff is a defect in the process, not a detail.
7. **Verify.** `openspec validate` plus the project's full test suite.
   Both green before the next step.
8. **Handle review findings.** Every finding — human, AI, linter, CI —
   ends as fixed or as rejected with a stated reason. Nothing is silently
   dropped. The specs and the ADRs outrank any reviewer. A disputed
   finding is settled with a test, not an argument.
9. **Archive.** `openspec archive <change-id>` folds the spec deltas into
   the capability specs. The specification is now current because the work
   finished, not because someone remembered to update it.

## When the guard fires and you are not starting a change

The source-guard hook reminds on any source edit with no change in flight.
For a hotfix or a build repair that is expected: say which it is, and
continue. The reminder exists to catch the case where a feature quietly
began without a proposal.
```

- [ ] **Step 5: Run the tests to verify they pass**

Run: `bash tests/run-tests.sh`
Expected: `87 checks, 0 failed`

- [ ] **Step 6: Commit**

```bash
git add plugins/dev-standards/skills tests/test-skills.sh
git commit -m "feat: add adr and sdd-change skills"
```

---

### Task 10: Skill `new-project`

**Files:**
- Create: `plugins/dev-standards/skills/new-project/SKILL.md`
- Modify: `tests/test-skills.sh:1-14` — add `new-project` to the loop's skill list
- Test: `tests/test-skills.sh`

**Interfaces:**
- Consumes: every template from Task 8.
- Produces: a skill taking `web` or `python` as its argument and leaving behind a project that the Task 5 conformance hook reports as fully conforming.

- [ ] **Step 1: Write the failing test**

In `tests/test-skills.sh`, change the loop list and append checks:

```bash
for skill in adr sdd-change new-project; do
```

Append at the end of the file:

```bash
np=$(cat "$S/new-project/SKILL.md" 2>/dev/null)
contains "new-project names both profiles"   "$np" "web"
contains "new-project names the python profile" "$np" "python"
contains "new-project initialises openspec"  "$np" "openspec init"
contains "new-project creates the ADR home"  "$np" "docs/adr"
contains "new-project ends with the conformance check" "$np" "conformance"
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `bash tests/run-tests.sh`
Expected: FAIL — `new-project/SKILL.md` does not exist; its frontmatter and content checks all report empty.

- [ ] **Step 3: Write the skill**

Create `plugins/dev-standards/skills/new-project/SKILL.md`:

```markdown
---
name: new-project
description: Scaffold a new project onto the development standard. Takes one argument, web or python. Use when starting any new project, or when bringing an existing one onto the standard.
---

# Scaffolding a project

Argument: `web` or `python`. If it is missing, ask — do not infer the
profile from files that happen to be present, because the answer decides
the toolchain for the life of the project.

## Process

1. **Confirm the target directory** and that it is a git repository. If it
   is not, `git init` and say so.

2. **Initialise OpenSpec**: `openspec init --tools claude`.

3. **Write `openspec/config.yaml`** by assembling, in this order:
   - `${CLAUDE_PLUGIN_ROOT}/templates/<profile>/config.fragment.yaml` —
     the `schema:` and `profile:` keys. The `profile:` key is what the
     conformance hook reads; without it the project reports as unprofiled.
   - a `context:` block you write with the human: what the product is, its
     non-negotiable principles, the tech stack from the profile below, the
     language convention, and the domain vocabulary. This block is the
     binding project truth — everything a session must not get wrong
     belongs here and nowhere else.
   - `${CLAUDE_PLUGIN_ROOT}/templates/shared/config.rules.yaml` verbatim.

4. **Write `CLAUDE.md`** from
   `${CLAUDE_PLUGIN_ROOT}/templates/<profile>/CLAUDE.md`, filling the
   one-line description. Keep it thin: orientation, commands, directories.
   Rules belong in `openspec/config.yaml`, never in both.

5. **Create `docs/adr/`** with a `.gitkeep`.

6. **Install the toolchain** for the profile.

7. **Verify**: run the project's test command and its linter. Both must
   run — an empty suite that runs is fine, a suite that cannot run is not.

8. **Confirm conformance**: the SessionStart conformance hook must report
   nothing for this project. Start a session in it, or run
   `bash "${CLAUDE_PLUGIN_ROOT}/hooks/check-conformance.sh"` with
   `{"cwd":"<project>"}` on stdin and confirm the output is empty.

## Profile `web`

Vue 3 with `<script setup>`, TypeScript strict, Vite. Tailwind v4 with
design tokens only in `@theme` and no dynamically composed class names —
state colours as explicit maps, so every class the build sees is greppable.
Pinia for ephemeral UI state only; persistent data goes through a
repository layer. vue-router. i18n from the first UI change, with no
hardcoded user-facing strings. Vitest for units, Playwright for a thin
end-to-end layer. ESLint and Prettier. `vue-tsc` for typechecking.
Default posture: no backend, no secrets in the bundle, no external CDNs,
fonts or analytics.

## Profile `python`

`uv` for dependencies and environments. `ruff` for both linting and
formatting. `mypy` in strict mode. `pytest`. A Dockerfile where the
project is deployed.

## The rule above both profiles

Data entering the process is parsed into a known shape at the boundary —
network, storage, imports, URL payloads — before anything else touches it.
Which library does that is this project's decision; record it in
`openspec/config.yaml`. That something does it is not optional.
```

- [ ] **Step 4: Run the tests to verify they pass**

Run: `bash tests/run-tests.sh`
Expected: `96 checks, 0 failed`

- [ ] **Step 5: Commit**

```bash
git add plugins/dev-standards/skills/new-project tests/test-skills.sh
git commit -m "feat: add new-project scaffolding skill"
```

---

### Task 11: Global `~/.claude/CLAUDE.md`

**Files:**
- Create: `C:\Users\frufus\.claude\CLAUDE.md`
- Create: `plugins/dev-standards/templates/global/CLAUDE.md` (the version-controlled copy)
- Test: `tests/test-global-claude-md.sh`

**Interfaces:**
- Consumes: nothing.
- Produces: the always-loaded rule layer. The repository holds the authoritative copy; the file in `~/.claude/` is installed from it in Task 12, so the standard's own rules are under version control like everything else.

- [ ] **Step 1: Write the failing test**

Create `tests/test-global-claude-md.sh`:

```bash
G="plugins/dev-standards/templates/global/CLAUDE.md"
g=$(cat "$G" 2>/dev/null)

contains "carries the proposal-first rule"   "$g" "proposal"
contains "carries the branch convention"     "$g" "claude/"
contains "carries Conventional Commits"      "$g" "Conventional Commits"
contains "carries the 72-character limit"    "$g" "72"
contains "carries the ADR location"          "$g" "docs/adr/"
contains "carries the review rule"           "$g" "settled with a test"
contains "carries the deviation rule"        "$g" "before it is built"
contains "carries the language convention"   "$g" "English"

# Spec section 4.5 budgets this file at roughly 50 lines. It is loaded
# into every session in every directory, so growth here is paid for
# continuously and by every project, including the ones it does not
# apply to.
lines=$(wc -l < "$G" 2>/dev/null || echo 999)
check "stays within its budget" "$([ "$lines" -le 60 ] && echo ok)" "ok"
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `bash tests/run-tests.sh`
Expected: FAIL — the template does not exist; all eight `contains` checks find an empty string and the line count reports 999.

- [ ] **Step 3: Write the file**

Create `plugins/dev-standards/templates/global/CLAUDE.md`:

```markdown
# Development standard

These rules apply in every project. A project's own `openspec/config.yaml`
is binding for that project and may be stricter; it may not be looser.

## Work starts as a proposal

- In a project with an `openspec/` directory, a unit of work begins as a
  change proposal and is approved before it is implemented. The `sdd-change`
  skill runs the full cycle.
- A deviation from the spec is named and justified **before it is built**,
  never discovered afterwards in the diff.
- Architecture decisions that outlive their change become ADRs under
  `docs/adr/NNNN-title.md`, with Context, Decisions and Consequences. Every
  decision names the alternative it rejected.

## Git

- One branch per unit of work, named `claude/<topic>`, branched from current
  `main`, ended by its merge and never reused. A reused branch makes it
  impossible to say which commits a pull request contains.
- Conventional Commits, imperative mood, subject line ≤ 72 characters, body
  explaining the why where it helps. Only related changes in one commit.
- Commit as each unit of work completes, not in one batch at the end.

## Quality

- Tests are green before a change is archived or a pull request opened.
- Data entering a process is parsed into a known shape at the boundary —
  network, storage, imports, payloads — before anything else touches it.

## Reviews are answered, not obeyed

- Every finding — from a human, an AI, a linter, CI — ends in one of two
  states: fixed, or rejected with a stated reason. Nothing is silently
  dropped.
- The specs and the ADRs outrank any reviewer.
- A disputed finding is settled with a test, not an argument.

## Language

- Repository language is English: documentation, code comments, commit
  messages, identifiers.
- User-facing strings are never hardcoded; they go through the project's
  i18n layer.
```

- [ ] **Step 4: Run the tests to verify they pass**

Run: `bash tests/run-tests.sh`
Expected: `105 checks, 0 failed`

- [ ] **Step 5: Commit**

```bash
git add plugins/dev-standards/templates/global tests/test-global-claude-md.sh
git commit -m "docs: add the global always-loaded rule layer"
```

---

### Task 12: Install and verify end to end

**Files:**
- Create: `C:\Users\frufus\.claude\CLAUDE.md` (copied from the template)
- Modify: `C:\Users\frufus\.claude\settings.json` — add the marketplace and enable the plugin
- Create: `docs/adr/0001-plugin-lives-in-a-marketplace-subdirectory.md`

**Interfaces:**
- Consumes: everything built in Tasks 1–11.
- Produces: a working installation, and the first ADR of this repository recording the layout deviation named at the top of this plan.

- [ ] **Step 1: Run the full suite one more time**

Run: `bash tests/run-tests.sh`
Expected: `105 checks, 0 failed`

Nothing is installed until the suite is green. A hook that fails silently is
worse than no hook, because it is trusted.

- [ ] **Step 2: Install the global rule layer**

```bash
cp plugins/dev-standards/templates/global/CLAUDE.md "$HOME/.claude/CLAUDE.md"
```

- [ ] **Step 3: Register the marketplace and enable the plugin**

Ask the human to run, in Claude Code:

```
/plugin marketplace add C:\Users\frufus\development\claude-standards
/plugin install dev-standards@claude-standards
```

Then confirm `~/.claude/settings.json` gained
`"dev-standards@claude-standards": true` under `enabledPlugins`, and that
`~/.claude/plugins/known_marketplaces.json` lists `claude-standards`.

- [ ] **Step 4: Verify the conformance hook against a real non-conforming project**

Run:

```bash
printf '{"cwd":"C:/Users/frufus/development/ink"}' \
  | bash plugins/dev-standards/hooks/check-conformance.sh
```

Expected: JSON naming the missing `openspec/`, `CLAUDE.md` and `docs/adr/`.

- [ ] **Step 5: Verify the conformance hook stays silent where it should**

Run:

```bash
printf '{"cwd":"C:/Users/frufus/development/Palette-swap"}' \
  | bash plugins/dev-standards/hooks/check-conformance.sh
```

Expected: output naming the unprofiled config, the missing `CLAUDE.md` and the
missing `docs/adr/` — but **not** a missing `openspec/`, because that directory
exists. Verified against the real project: it has `openspec/` with
`schema: spec-driven` and no `profile:` key, and neither `CLAUDE.md` nor
`docs/adr/`. This is the check that proves the hook distinguishes states rather
than always firing the same message.

- [ ] **Step 6: Verify the source guard warns inside a real OpenSpec project**

`Palette-swap` has an OpenSpec root and, as of writing, zero changes in flight.

```bash
printf '{"cwd":"C:/Users/frufus/development/Palette-swap","tool_input":{"file_path":"C:/Users/frufus/development/Palette-swap/src/main.ts"}}' \
  | bash plugins/dev-standards/hooks/guard-change.sh
```

Expected: JSON with `additionalContext` naming `src/main.ts`, and no
`permissionDecision` field anywhere in the output.

Then confirm the exclusion works in the same project:

```bash
printf '{"cwd":"C:/Users/frufus/development/Palette-swap","tool_input":{"file_path":"C:/Users/frufus/development/Palette-swap/openspec/config.yaml"}}' \
  | bash plugins/dev-standards/hooks/guard-change.sh
```

Expected: empty output.

If a change is in flight in `Palette-swap` by the time this runs, the first
command correctly produces empty output. Verify with `openspec list` first and
say which case was observed.

- [ ] **Step 7: Verify the commit-message hook**

```bash
printf '{"tool_input":{"command":"git commit -m \\"added stuff\\""}}' \
  | bash plugins/dev-standards/hooks/check-commit-msg.sh
```

Expected: JSON reporting the Conventional Commits violation.

- [ ] **Step 8: Record the layout deviation as an ADR**

Create `docs/adr/0001-plugin-lives-in-a-marketplace-subdirectory.md` using
`plugins/dev-standards/templates/adr/TEMPLATE.md`. Context: the spec sketched
one `.claude-plugin/` at the repository root holding both manifests. Decision:
the plugin lives in `plugins/dev-standards/` and the root holds only
`marketplace.json`, because all 53 relative-source entries in the installed
official marketplace use `"source": "./plugins/<name>"` and a
marketplace-that-is-also-a-plugin is unproven here. Rejected: the root layout,
for that reason. Consequences: adding a second plugin later costs nothing;
paths in the spec's section 4.5 tree are one level deeper than written.

- [ ] **Step 9: Commit**

```bash
git add docs/adr
git commit -m "docs: record the marketplace subdirectory layout as ADR-0001"
```

- [ ] **Step 10: Report what was verified**

State, for each of Steps 4–7, the command run and its actual output. Do not
report the installation as working on the strength of the unit tests alone —
they exercise the scripts, not the wiring that makes Claude Code call them.
The wiring is confirmed only when a fresh session in a non-conforming project
shows the conformance report.
