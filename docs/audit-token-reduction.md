# Audit: Token-Reduktion gegen den Stand des Repos

Datum: 2026-09-10 · Basis: `main` @ `ecf9696` (v0.3.0) · Art: Audit, kein Umbau.
Externe Fakten wurden gegen die Claude-Code-Doku (Stand 2026-09-10), die
Upstream-Repos von RTK und graphify und den JetBrains-Benchmark geprüft;
wo etwas nicht belegbar war, steht das ausdrücklich dabei.

---

## 1. Inventur

1. **Auslieferung**: ein Marketplace (`.claude-plugin/marketplace.json`) mit
   genau einem Plugin, `dev-standards` (`plugins/dev-standards/`), Version
   0.3.0, Tag `v0.3.0`. Pinning ist ein `git checkout v0.3.0` im
   Marketplace-Clone (README:70–83); `marketplace.json` selbst pinnt nichts.
2. **Drei Ebenen** (Spec 2026-09-01 §4.5): (a) eine globale Regelschicht
   `templates/global/CLAUDE.md`, die **von Hand** nach `~/.claude/CLAUDE.md`
   kopiert wird — das README nennt diesen Schritt nirgends; (b) das Plugin
   mit 5 Hooks und 5 Skills; (c) pro Projekt Templates, die der Skill
   `new-project` schreibt (`openspec/config.yaml`, `AGENTS.md`, `CLAUDE.md`,
   `scripts/dev|verify`, PR-Template).
3. **Settings-Ebene: keine.** Es gibt keine `settings.json`, keine
   `managed-settings.json`, keine `.mcp.json`, keine `.lsp.json`, keine
   Statuszeile, keinen `env`-Block irgendwo im Repo (`find`/`grep` leer).
4. **Hooks** (`hooks/hooks.json:4–41`): `SessionStart` → Konformitätsbericht;
   `PreToolUse Edit|Write` → Erinnerung ohne Change; `PreToolUse Bash` →
   Deny für 4 destruktive git-Formen (ADR-0002), Commit-Subject-Check,
   Ship-Check. Vier berichten, einer verweigert. Keiner filtert Output,
   keiner setzt `updatedInput`.
5. **Env-Variablen**: das Repo *liest* eine (`CLAUDE_STANDARDS_ALLOW_DESTRUCTIVE`),
   *setzt* keine.
6. **CLAUDE.md-Regeln** (global, 59 Zeilen, Budget 60 per Test):
   Proposal-first, Git-Konvention, Qualität/Test-Ratchet, Reviews,
   Autonomiegrenze, eine Compaction-Zeile (`## Sessions`), Sprache. Die
   Profil-`CLAUDE.md` sind 14 (web) und 7 (python) Zeilen, importieren
   `AGENTS.md` (42/40 Zeilen). Workflow steht in Skills (461 Zeilen gesamt).
7. **Gepinnte Versionen**: Plugin 0.3.0; `typescript@^6` in `new-project`
   Schritt 8 (ADR-0003). Keine Drittanbieter-Plugins, kein LSP, kein
   Telemetrie-Export.
8. **Tests**: 476 Checks grün (`bash tests/run-tests.sh`). Sie erzwingen die
   Zeilenbudgets und den Textinhalt der Templates — jeder Vorschlag unten,
   der ein Template anfasst, muss die zugehörige Test-Zeile mit ändern.

---

## 2. Bewertung der 19 Empfehlungen

| Nr. | Empfehlung | Status | Beleg (Pfad:Zeile) | Vorschlag |
|---|---|---|---|---|
| 1 | `CLAUDE_CODE_SUBAGENT_MODEL=haiku` | **fehlt** | keine settings-Datei im Repo (Inventur 3); `skills/verify/SKILL.md:20` dispatcht `general-purpose` ohne `model` | §3.1 `templates/global/settings.json` + Verifier explizit auf `sonnet` (§3.2.1), sonst läuft die Verifikation auf haiku |
| 2 | Effort-/Thinking-Default zentral | **fehlt** | wie 1 | `effortLevel: "medium"` in §3.1. `MAX_THINKING_TOKENS` **nicht** setzen: wirkt nur bei Fixed-Budget-Modellen (Opus/Sonnet 4.6), adaptive Modelle ignorieren es |
| 3 | `CLAUDE_CODE_MAX_OUTPUT_TOKENS` | **passt nicht zum Repo** | Variable in aktueller Doku (settings, env-vars, model-config, costs) nicht gelistet | Keine undokumentierte Variable als Standard; stattdessen 2 und 11 (§4) |
| 4 | Statuszeile mit Kontextanzeige | **fehlt** | keine `statusLine` im Repo | `templates/global/statusline.js` + Eintrag in §3.1 |
| 5 | `typescript-lsp` im Standard-Set | **fehlt** | README:67–83 nennt nur `dev-standards`; `skills/new-project/SKILL.md:67–88` installiert keinen Language Server | Projekt-`.claude/settings.json`-Template mit `enabledPlugins` (§3.3.1) + `new-project` Schritt 8 |
| 6 | Regel: Agent-Teams nur bewusst (≈7×) | **fehlt** | `templates/global/CLAUDE.md` (59 Z.) erwähnt Teams nicht | eine Zeile in §3.1.3; Doku-Beleg: „approximately 7x more tokens … when teammates run in plan mode" |
| 7 | CLAUDE.md < 200 Zeilen, Workflow in Skills | **vorhanden** | `tests/test-global-claude-md.sh:41–42` (Budget 60), `tests/test-templates.sh:17–22` (AGENTS 60, CLAUDE 40); Workflow in `skills/sdd-change`, `verify`, `new-project` | nichts; Budget nach §3.1.3 auf 70 heben |
| 8 | Compaction-Anweisung | **teilweise** | `templates/global/CLAUDE.md:51–54` („When compacting, keep …") | Abschnitt in der von der Doku genannten Form `Compact instructions` fassen, um „drop tool output" und den `progress.md`-Zeiger ergänzen (§3.1.3) |
| 9 | Output-Stil: Edit statt Rewrite, kein Preamble/Summary | **fehlt** | keine Regel in global/web/python `CLAUDE.md` oder `AGENTS.md` | §3.1.3 |
| 10 | Exploration: erst LSP/Graph, dann Grep/Read | **fehlt** | wie 9 | §3.1.3, bedingt formuliert („where available"), wirkt erst mit 5/13 |
| 11 | PreToolUse-Hook filtert Test-Output | **fehlt** | `hooks/hooks.json:25–39` — die drei Bash-Hooks liefern nur `additionalContext`/`deny`, kein `updatedInput` | neuer Hook `filter-test-output.sh` + `lib/test-command.js` + `lib/test-filter.js` (§3.2.2), an vitest/pytest/`scripts/verify` angepasst |
| 12 | Hook-Review-Prozess dokumentiert | **fehlt** | README:122–134 beschreibt nur *was* die Hooks tun; Spec 09-01 §7 Schritt 6 verlangt einen Probelauf, aber kein Review beim Einbinden fremder Hooks | README-Abschnitt + PR-Template-Risikostufe „hooks" + eine Zeile Autonomiegrenze (§3.2.3). Hinweis: „SessionStart läuft vor Trust" ist in der aktuellen Doku so nicht belegt; belegt ist „hooks run with your credentials" und dass Plugin-Hooks auch in Subagents laufen |
| 13 | graphify als Plugin (SKILL, `--project --strict`, gitignore, git-hook) | **fehlt** (Form abweichend) | kein `graphify` im Repo; Spec 09-06 §9 vertagt „code-as-graph" ausdrücklich | nicht als Marketplace-Plugin nachbauen, sondern `new-project`-Schritt + Konformitätsbericht (§3.2.4); `graphify-out/graph.json` **committen**, nur `cache/` ignorieren (§4) |
| 14 | RTK über `enixCode/rtk-plugin`, gepinnt | **passt nicht zum Repo** | `marketplace.json:10–22` listet ein Plugin; Benchmark: theoretisches Maximum ≈3 %, gemessen **+7,6 % Kosten** bei low effort (p=0,004), +0,1 % bei high | nicht als Standard; 11 deckt denselben Kanal (Bash-Output) gezielt ab. Opt-in-Eintrag mit SHA-Pin in §3.4, falls trotzdem gewünscht |
| 15 | Lokale Messung im Pilot (CodeBurn/ccusage) | **fehlt** | kein Mess-Dokument; README:235–246 misst nur die Testsuite | `docs/token-measurement.md` (§3.2.5) |
| 16 | OpenTelemetry-Export als Rollout-Standard | **fehlt** | kein `CLAUDE_CODE_ENABLE_TELEMETRY`/`OTEL_*` im Repo | Env-Block für `managed-settings.json` in §3.2.5, Endpoint projektspezifisch |
| 17 | Headroom-Proxy nicht Pflicht | **vorhanden** (Ausschluss erfüllt) | `marketplace.json:10–22`, `hooks.json:4–41`: kein Proxy, kein `ANTHROPIC_BASE_URL` | nichts |
| 18 | kein claude-code-router | **vorhanden** (Ausschluss erfüllt) | wie 17; `grep -ri router` leer | nichts |
| 19 | tokenwar nicht Standard, nur Audit | **vorhanden** (Ausschluss erfüllt) | `grep -ri tokenwar` leer | Grenze in `docs/token-measurement.md` festschreiben (§3.2.5), damit sie nicht aus Versehen kippt |

Zählung: 4 × vorhanden (7, 17, 18, 19), 1 × teilweise (8), 12 × fehlt
(1, 2, 4, 5, 6, 9, 10, 11, 12, 13, 15, 16), 2 × passt nicht (3, 14).

---

## 3. Diffs, einsortiert nach der Ebene, die das Repo nutzt

### 3.1 Ebene „global" — was neben `~/.claude/CLAUDE.md` installiert wird

Das Repo liefert die globale Schicht als Template unter
`plugins/dev-standards/templates/global/`. Env-Variablen, Effort und
Statuszeile gehören auf dieselbe Ebene: ein Plugin darf per Doku in seiner
`settings.json` nur `agent` und `subagentStatusLine` setzen, keinen
`env`-Block und keine `statusLine`. Die JSON unten funktioniert unverändert
auch in einer `managed-settings.json`, falls das Team später dorthin geht.

#### 3.1.1 Neu: `plugins/dev-standards/templates/global/settings.json` (Punkte 1, 2, 4)

```json
{
  "env": {
    "CLAUDE_CODE_SUBAGENT_MODEL": "haiku"
  },
  "effortLevel": "medium",
  "statusLine": {
    "type": "command",
    "command": "node \"$HOME/.claude/statusline.js\""
  }
}
```

Anmerkungen aus der Doku:

- `CLAUDE_CODE_SUBAGENT_MODEL` gilt für Subagents ohne eigenes `model`.
  Die eingebauten Explore/Plan-Subagents bleiben davon **ausgenommen**
  (sie nutzen beim Planen Opus); erst `CLAUDE_CODE_SUBAGENT_MODEL_FORCE=1`
  zieht auch sie mit — und dann ebenso den Verifier aus `verify`. Deshalb
  kein FORCE, sondern 3.2.1.
- `effortLevel` akzeptiert `low|medium|high|xhigh`; `/effort high` bleibt
  je Sitzung möglich. `maxEffortLevel` wäre die Deckelung für Managed
  Settings.
- Auf Windows den absoluten Pfad eintragen (`C:\\Users\\<name>\\.claude\\statusline.js`).

#### 3.1.2 Neu: `plugins/dev-standards/templates/global/statusline.js` (Punkt 4)

```js
#!/usr/bin/env node
// Status line: model, context used, session cost. Reads the JSON Claude
// Code passes on stdin and prints one line. Never fails: an empty line
// is better than a stack trace in the status bar.
let s = "";
process.stdin.on("data", (d) => (s += d)).on("end", () => {
  let j = {};
  try { j = JSON.parse(s); } catch { /* print what we can */ }
  const cw = j.context_window || {};
  const used = Math.max(0, Math.min(100, Math.round(cw.used_percentage ?? 0)));
  const size = cw.context_window_size ? Math.round(cw.context_window_size / 1000) + "k" : "?";
  const model = (j.model && j.model.display_name) || "";
  const cost = j.cost && typeof j.cost.total_cost_usd === "number"
    ? ` · $${j.cost.total_cost_usd.toFixed(2)}` : "";
  const tenths = Math.floor(used / 10);
  const bar = "█".repeat(tenths) + "░".repeat(10 - tenths);
  process.stdout.write(`${model} · ctx ${bar} ${used}% of ${size}${cost}`);
});
```

Felder laut Doku `statusline`: `context_window.used_percentage`,
`context_window.context_window_size`, `model.display_name`,
`cost.total_cost_usd`.

#### 3.1.3 `plugins/dev-standards/templates/global/CLAUDE.md` (Punkte 6, 8, 9, 10)

Die Datei steht bei 59 von 60 Zeilen. Die vier Regeln kosten sechs Zeilen
netto. Vorschlag: Budget auf 70 heben — die Datei wird in jeder Sitzung
geladen, und genau dort zahlt sich eine Token-Regel in jeder Sitzung aus;
das ist die Rechnung, die das Budget schützen soll. Alternative ohne
Budgetänderung: die Zeilen in `templates/web/CLAUDE.md` und
`templates/python/CLAUDE.md` (26 bzw. 33 Zeilen Luft), dann gelten sie aber
nur in profilierten Projekten.

```diff
--- a/plugins/dev-standards/templates/global/CLAUDE.md
+++ b/plugins/dev-standards/templates/global/CLAUDE.md
@@ -46,12 +46,20 @@
 - "With the human" means stop and wait, not proceed and mention.
 - With the human, whatever the verdict: any change to authentication,
-  payments, secrets handling or the parsing of untrusted input.
+  payments, secrets handling, hooks, or the parsing of untrusted input.
 
-## Sessions
+## Compact instructions
 
-- When compacting, keep the change id, the list of modified files and the
-  test commands.
+- When compacting, keep the change id, the list of modified files, the
+  test commands and the last line of `progress.md`; drop tool output.
+
+## Tokens
+
+- Edit files in place; never rewrite a whole file to change a few lines.
+  Answer without preamble and without restating what was done.
+- Where a language server or a code graph is available, resolve a symbol
+  there before grepping or reading whole files.
+- An agent team costs about seven sessions' worth of tokens. Start one
+  only when the human asks for it.
 
 ## Language
```

Zugehörige Test-Änderung (`tests/test-global-claude-md.sh`):

```diff
-contains "carries the compaction line"     "$g" "## Sessions"
+contains "carries the compaction line"     "$g" "## Compact instructions"
 contains "says what survives a compact"    "$g" "When compacting"
+contains "carries the edit-in-place rule"  "$g" "never rewrite a whole file"
+contains "carries the exploration rule"    "$g" "before grepping"
+contains "carries the agent-team rule"     "$g" "agent team"
+contains "hooks always get a human"        "$g" "hooks,"
@@
-check "stays within its budget" "$([ "$lines" -le 60 ] && echo ok)" "ok"
+check "stays within its budget" "$([ "$lines" -le 70 ] && echo ok)" "ok"
```

Dazu in Spec 2026-09-06 §4.2 der Satz „The budget is not raised" durch
einen Verweis auf dieses Audit ersetzen (oder ein ADR-0004 „Token rules
live in the always-loaded layer", weil es eine Entscheidung mit
verworfener Alternative ist — die Profil-Dateien).

#### 3.1.4 README: Install-Schritt für die globale Ebene

Das README nennt weder das Kopieren der globalen `CLAUDE.md` noch die
neue `settings.json`. Unter „## Install" (README:67) ergänzen:

```diff
 /plugin marketplace add frufus/claude-standards
 /plugin install dev-standards@claude-standards
 ```
+
+Then install the global layer once per machine — it is not a plugin
+artefact, Claude Code loads it from `~/.claude/`:
+
+```
+cp plugins/dev-standards/templates/global/CLAUDE.md      ~/.claude/CLAUDE.md
+cp plugins/dev-standards/templates/global/statusline.js  ~/.claude/statusline.js
+# merge templates/global/settings.json into ~/.claude/settings.json
+```
```

### 3.2 Ebene „Plugin" — Hooks, Skills, README

#### 3.2.1 `skills/verify/SKILL.md` — Verifier nicht auf haiku (Punkt 1)

Mit 3.1.1 liefe der Verifier auf haiku, weil `general-purpose` kein
`model` trägt. Er fährt einen Browser und beurteilt Szenarien; das ist
keine Explorationsaufgabe.

```diff
-2. **Dispatch the verifier** with the Agent tool (`general-purpose`),
-   using the brief below verbatim with the placeholders filled. Give it
-   nothing else.
+2. **Dispatch the verifier** with the Agent tool (`general-purpose`,
+   `model: sonnet` — the per-invocation model outranks
+   `CLAUDE_CODE_SUBAGENT_MODEL`, so the verifier is not downgraded to
+   the exploration default), using the brief below verbatim with the
+   placeholders filled. Give it nothing else.
```

#### 3.2.2 Neuer Hook: Test-Output filtern (Punkt 11)

Das offizielle Beispiel (`costs` → „Offload processing to hooks") matcht
`^(npm test|pytest|go test)`, hängt `| grep -A 5 -E '(FAIL|ERROR|error:)' | head -100`
an und setzt `permissionDecision: allow`. Drei Dinge daran passen nicht
zu diesem Repo und sind unten geändert: (a) `grep` ohne Treffer liefert
Exit 1, ein grüner Lauf sähe wie ein Fehlschlag aus — die Pipeline unten
setzt `pipefail` und der Filter selbst endet immer mit 0, so bleibt der
Exit-Status des Runners der Verdict; (b) ein Regex auf den Anfang der
Zeile erkennt `cd x && npm test` nicht und rewritet `npm test > log`
falsch — unten wird der vorhandene Tokenizer benutzt und bei jedem
Operator (`&&`, `|`, `;`, Newline) oder einer Umleitung **nicht**
umgeschrieben; (c) der Filter kennt die Runner der beiden Profile
(vitest, pytest) und `scripts/verify`.

Zu `permissionDecision`: die Doku sagt, `updatedInput` wird ohne
`allow`/`ask` ignoriert. `allow` unten ist auf die erkannten Runner ohne
Operator beschränkt — genau die Kommandos, die ein Team ohnehin
freigibt. Wer keinen Hook mit `allow` will, setzt `ask` und bekommt die
umgeschriebene Zeile einmal pro Lauf gezeigt.

`plugins/dev-standards/hooks/hooks.json`:

```diff
       {
         "matcher": "Bash",
         "hooks": [
+          {
+            "type": "command",
+            "command": "bash \"${CLAUDE_PLUGIN_ROOT}/hooks/filter-test-output.sh\""
+          },
           {
             "type": "command",
             "command": "bash \"${CLAUDE_PLUGIN_ROOT}/hooks/guard-destructive-git.sh\""
```

Neu `plugins/dev-standards/hooks/filter-test-output.sh`:

```bash
#!/usr/bin/env bash
# PreToolUse on Bash: when the command is a test runner on its own —
# vitest, pytest or scripts/verify, with no pipe, chain or redirection —
# rewrites it so its output reaches the session through a filter that
# keeps failures and the summary and drops the passing noise. The
# runner's exit status is preserved (pipefail; the filter always exits
# 0), so the verdict is unchanged; only the transcript is shorter.
#
# Anything the recogniser is unsure about passes through untouched: a
# hook that rewrites the wrong command costs more than the tokens it
# saves.
set -uo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

input=$(cat)
command_line=$(printf '%s' "$input" | node "$HERE/lib/json-fields.js" --raw tool_input.command 2>/dev/null)
[ -n "${command_line:-}" ] || exit 0

kind=$(printf '%s' "$command_line" | node "$HERE/lib/test-command.js" 2>/dev/null)
[ "$kind" = "filter" ] || exit 0

printf '%s' "$input" | node "$HERE/lib/rewrite-test-command.js" "$HERE/lib/test-filter.js" 2>/dev/null
exit 0
```

Neu `plugins/dev-standards/hooks/lib/test-command.js`:

```js
// Reads a raw shell command line on stdin and writes `filter` when the
// whole line is one test-runner invocation at a command position:
// `npm test`, `npm run test`, `npx vitest`, `pnpm test`, `pnpm vitest`,
// `vitest`, `pytest`, `uv run pytest`, `python -m pytest`, or
// `scripts/verify`. Writes nothing otherwise — including when the line
// carries any operator (`&&`, `||`, `;`, `|`, newline) or a redirection,
// because a rewrite must wrap exactly one command and nothing else.
//
// Hooks must never fail on unexpected input: every failure path ends in
// no output and exit code 0.
const { tokenize, isCommandStart } = require("./tokenize.js");

const RUNNERS = [
  ["npm", "test"], ["npm", "run", "test"], ["npx", "vitest"],
  ["pnpm", "test"], ["pnpm", "vitest"], ["vitest"],
  ["pytest"], ["uv", "run", "pytest"], ["python", "-m", "pytest"],
  ["scripts/verify"], ["./scripts/verify"], ["bash", "scripts/verify"],
];

function testKind(tokens) {
  if (tokens.length === 0) return "";
  if (tokens.some((t) => t.type !== "word")) return "";           // any operator
  if (tokens.some((t) => /[<>]/.test(t.value))) return "";         // any redirection
  if (!isCommandStart(tokens, 0)) return "";
  const words = tokens.map((t) => t.value);
  const hit = RUNNERS.some((r) => r.every((w, k) => words[k] === w));
  return hit ? "filter" : "";
}

let raw = "";
process.stdin.on("data", (d) => (raw += d)).on("end", () => {
  try {
    const kind = testKind(tokenize(raw));
    if (kind) process.stdout.write(kind);
  } catch { /* silence */ }
});
```

Neu `plugins/dev-standards/hooks/lib/rewrite-test-command.js`:

```js
// Reads the hook input on stdin and the filter script path as argv[2];
// writes the PreToolUse output that replaces the command with the same
// command piped through the filter. pipefail keeps the runner's exit
// status as the pipeline's; the subshell keeps the runner's own cwd and
// env untouched.
const filter = process.argv[2];
let raw = "";
process.stdin.on("data", (d) => (raw += d)).on("end", () => {
  let input;
  try { input = JSON.parse(raw); } catch { return; }
  const cmd = input && input.tool_input && input.tool_input.command;
  if (typeof cmd !== "string" || !filter) return;
  const rewritten = `set -o pipefail; ( ${cmd} ) 2>&1 | node ${JSON.stringify(filter)}`;
  process.stdout.write(JSON.stringify({
    hookSpecificOutput: {
      hookEventName: "PreToolUse",
      permissionDecision: "allow",
      updatedInput: { ...input.tool_input, command: rewritten },
    },
  }));
});
```

Neu `plugins/dev-standards/hooks/lib/test-filter.js`:

```js
// Filters a test runner's combined output. Keeps: step markers from
// scripts/verify, failure headers and the lines that follow them,
// assertion lines, and the summary. Drops per-test pass lines. Always
// exits 0 — the pipeline's status is the runner's, not the filter's.
const KEEP = [
  /^== /, /^verify: /,                                   // scripts/verify
  /\bFAIL\b/, /^\s*[×✗]/, /AssertionError/, /^\s*Error[: ]/, // vitest
  /Test Files\s/, /^\s*Tests\s/, /Duration\s/, /Snapshots\s/, /⎯⎯/,
  /^FAILED /, /^ERROR /, /^E\s{2,}/, /^_{3,} .* _{3,}$/,     // pytest
  /^={3,} .*(passed|failed|error|skipped).* ={3,}$/,
  /^\s+at .*\(.*:\d+:\d+\)$/, /^[^\s].*:\d+(:\d+)?: /,      // locations
  /error TS\d+/, /^\s*\d+:\d+\s+error/,                     // tsc, eslint
];
const AFTER = 12;      // lines kept after a failure header
const CAP = 300;       // hard cap on lines forwarded

let raw = "";
process.stdin.on("data", (d) => (raw += d)).on("end", () => {
  const lines = raw.split(/\r?\n/);
  const out = [];
  let tail = 0;
  for (const line of lines) {
    const header = /\bFAIL\b|^\s*[×✗]|^FAILED |^ERROR |^_{3,} .* _{3,}$/.test(line);
    if (header) tail = AFTER;
    if (header || tail > 0 || KEEP.some((re) => re.test(line))) {
      out.push(line);
      if (!header && tail > 0) tail--;
    }
  }
  const shown = out.slice(0, CAP);
  process.stdout.write(shown.join("\n"));
  if (shown.length < lines.length) {
    process.stdout.write(`\n(filtered: ${shown.length} of ${lines.length} lines; rerun with a pipe or redirection to see everything)\n`);
  }
  process.exit(0);
});
```

Tests (`tests/test-filter-test-output.sh`, im Stil von `test-check-ship.sh`):

```bash
HOOK="plugins/dev-standards/hooks/filter-test-output.sh"
run() { printf '{"cwd":"/p","tool_input":{"command":"%s"}}' "$1" | bash "$HOOK" 2>/dev/null; }

contains "rewrites npm test"            "$(run 'npm test')"         "updatedInput"
contains "pipes through the filter"     "$(run 'npm test')"         "test-filter.js"
contains "keeps the runner's status"    "$(run 'npm test')"         "pipefail"
contains "rewrites pytest"              "$(run 'uv run pytest')"    "updatedInput"
contains "rewrites scripts/verify"      "$(run 'scripts/verify')"   "updatedInput"
check "silent on a chained command"     "$(run 'cd x \&\& npm test')" ""
check "silent on a redirected command"  "$(run 'npm test > out.log')" ""
check "silent on an unrelated command"  "$(run 'git status')"       ""
check "silent when quoted text only"    "$(run 'echo npm test')"    ""

f="plugins/dev-standards/hooks/lib/test-filter.js"
out=$(printf ' ✓ a.test.ts (3)\n ✗ b.test.ts > fails\nAssertionError: expected 1 to be 2\n Test Files  1 failed | 1 passed\n' | node "$f")
not_contains "drops passing tests"  "$out" "✓ a.test.ts"
contains     "keeps the failure"    "$out" "✗ b.test.ts"
contains     "keeps the assertion"  "$out" "AssertionError"
contains     "keeps the summary"    "$out" "Test Files"
```

README-Folgen: „Five hooks" wird „Six hooks" (README:20, 122, 217, 241) und
`tests/test-manifests.sh:28` entsprechend; Hook-Tabelle bekommt eine Zeile.

#### 3.2.3 Hook-Review-Prozess (Punkt 12)

README, neuer Abschnitt nach „### Five hooks" (README:134):

```markdown
### Before a hook runs on your machine

A hook is code that runs with your credentials, in every session and —
for plugin and settings-file hooks — inside every sub-agent too. So a
hook is reviewed like a dependency, not like a config line:

1. Read the script and everything it invokes before enabling it. A hook
   that downloads or executes something it did not ship with is not
   installed until that download is pinned and checked.
2. A change to `hooks/` in this repository, or to a hook a project adds
   under `.claude/settings.json`, is risk tier *high* in the pull-request
   template and gets a human whatever the verifier says.
3. Third-party hooks enter only through this marketplace, pinned by `sha`
   in `marketplace.json`, never by `/plugin install` from another
   marketplace on the fly.
4. `/hooks` shows what is registered; anything you do not recognise is a
   finding.
```

PR-Template (`templates/shared/pull_request_template.md:18`):

```diff
-- Risk tier: low | medium | high (auth, payments, secrets, untrusted input)
+- Risk tier: low | medium | high (auth, payments, secrets, untrusted input, hooks)
```

Autonomiegrenze: die Zeile ist im Diff 3.1.3 enthalten („secrets handling,
hooks, …"). `tests/test-templates.sh:91` bleibt gültig.

Belegbar in der Doku: „Review hooks before adding them. Hooks run with your
credentials …"; Plugin- und Settings-Hooks feuern auch in Subagents;
Frontmatter-Hooks eines Projekt-Skills registrieren sich auch in einem noch
nicht vertrauten Ordner bei `-p`. **Nicht** belegbar in der aktuellen Doku:
dass `SessionStart` aus Projekt-Settings vor dem Trust-Dialog läuft. Der
Prozess oben hängt davon nicht ab.

#### 3.2.4 graphify (Punkt 13)

Was upstream heute ist (PyPI `graphifyy` 0.9.58, 2026-09-10; Strict-Mode
seit 0.9.28, 2026-07-27): `graphify install --project --strict` schreibt
`.claude/skills/graphify/SKILL.md` und einen **PreToolUse-Hook auf Read/
Grep** in `.claude/settings.json`, der die erste Roh-Lesung einer Sitzung
auf `graphify query` umlenkt (`GRAPHIFY_HOOK_STRICT=1/0` schaltet zur
Laufzeit). `graphify hook install` ist ein **git post-commit-Hook**, der den
Graph nachzieht. Empfohlene Arbeitsweise upstream: einer baut mit
`/graphify .`, **committet `graphify-out/`**, alle anderen lesen den Graph
beim Checkout.

Daraus folgt für die Form: graphify bringt Installer, Skill und Hook selbst
mit und ändert sie schnell (0.9.28 → 0.9.58 in sechs Wochen). Ein
Marketplace-Plugin, das SKILL.md und Hook nachbaut, wäre eine zweite
Wahrheit, die driftet. Das Repo hat dafür bereits den passenden Ort: der
Skill `new-project` installiert die Toolchain, der Konformitäts-Hook meldet,
was fehlt.

`skills/new-project/SKILL.md`, neuer Schritt nach 8:

```markdown
9. **Install the code graph.** `uv tool install graphifyy==0.9.58` (pin;
   bump deliberately), then in the project root
   `graphify install --project --strict` — writes
   `.claude/skills/graphify/SKILL.md` and the read-redirect hook into
   `.claude/settings.json`; read both before committing them — and
   `graphify hook install` for the post-commit rebuild. Build it once with
   `/graphify .` and commit `graphify-out/graph.json` and
   `graphify-out/GRAPH_REPORT.md`, so the graph exists on every checkout
   and the strict hook has something to redirect to. Add to `.gitignore`:
   `graphify-out/cache/`, `graphify-out/graph.html`, `graphify-out/obsidian/`,
   `graphify-out/wiki/`.
```

(Die bisherigen Schritte 9 und 10 werden 10 und 11; `tests/test-skills.sh:24`
prüft nur, dass der Skill mit „conformance" endet — bleibt grün.)

`hooks/check-conformance.sh`, nach Zeile 36:

```bash
# A project that installed the graph skill but has no graph is one where
# the strict hook redirects the first read into nothing. Reported once.
if [ -f "$cwd/.claude/skills/graphify/SKILL.md" ] && [ ! -f "$cwd/graphify-out/graph.json" ]; then
    add "no \`graphify-out/graph.json\` — the graph skill is installed but the graph was never built or committed. Run \`/graphify .\` and commit \`graphify-out/graph.json\`."
fi
```

Kein `graphify install` im `SessionStart`: das würde bei jedem Start
`.claude/settings.json` des Projekts umschreiben, gegen die Linie des
Konformitäts-Hooks („Offer to fix this before starting work; do not fix it
silently", `check-conformance.sh:89`).

#### 3.2.5 Messung (Punkte 15, 16, 19) — neu `docs/token-measurement.md`

```markdown
# Measuring tokens

The number that matters is the paired bill: the same tasks, with and
without a change, measured on what the API charged — not what a tool
reports it saved. (JetBrains' rtk benchmark is the worked example: the tool
reported 60–90 %, the bill went up 7.6 % at low effort.)

## In a session

`/usage` — tokens by model, cache share, cost at list price. The status
line (templates/global/statusline.js) shows context use continuously.

## Locally, across sessions (pilot)

Both read `~/.claude/projects/` and send nothing anywhere:

    npx ccusage@20.0.20 daily          # tokens and cost per day
    npx ccusage@20.0.20 session        # per session
    npx codeburn@0.9.24                # per task type, per project

Pilot protocol: two weeks baseline before a change, two weeks after, same
people, same projects; compare `ccusage daily` totals and the
`cache read` share. A change that does not move the paired bill is
reverted, whatever its own dashboard says.

## Rollout: OpenTelemetry

For the whole team, export metrics from every machine. The env block goes
into `managed-settings.json` (org scope); the endpoint is per organisation
and is not committed here:

    {
      "env": {
        "CLAUDE_CODE_ENABLE_TELEMETRY": "1",
        "OTEL_METRICS_EXPORTER": "otlp",
        "OTEL_LOGS_EXPORTER": "otlp",
        "OTEL_EXPORTER_OTLP_PROTOCOL": "grpc",
        "OTEL_EXPORTER_OTLP_ENDPOINT": "http://collector.example.com:4317",
        "OTEL_EXPORTER_OTLP_HEADERS": "Authorization=Bearer <token>"
      }
    }

Metrics to chart: `claude_code.token.usage` (attributes `type` =
input | output | cacheRead | cacheCreation, `model`) and
`claude_code.cost.usage`. Leave `OTEL_LOG_USER_PROMPTS` unset.

## Not a standard

Proxies (Headroom), routers (claude-code-router) and tokenwar are not part
of the standard. tokenwar may be run once, by hand, as an audit — it is not
installed, not hooked, not in any settings file.
```

### 3.3 Ebene „Projekt-Template" — was `new-project` schreibt

#### 3.3.1 Neu: `templates/web/claude-settings.json` und `templates/python/claude-settings.json` (Punkt 5, stützt 12)

Wird von `new-project` als `.claude/settings.json` ins Projekt geschrieben.
Damit bekommt jeder Clone die Standards und den passenden Language Server
angeboten, statt dass es an der Maschine hängt.

web:

```json
{
  "extraKnownMarketplaces": {
    "claude-standards": {
      "source": { "source": "github", "repo": "frufus/claude-standards" }
    }
  },
  "enabledPlugins": {
    "dev-standards@claude-standards": true,
    "typescript-lsp@claude-plugins-official": true
  }
}
```

python: identisch mit `"pyright-lsp@claude-plugins-official": true`.

`skills/new-project/SKILL.md` Schritt 8, Ergänzung:

```diff
    Then install the sensors ADR-0003 adopted, ...
+
+   Install the language server the code-intelligence plugin drives: on
+   `web` `npm install -D typescript-language-server`, on `python`
+   `uv add --dev pyright`. Then copy
+   `${CLAUDE_PLUGIN_ROOT}/templates/<profile>/claude-settings.json` to
+   `.claude/settings.json` and read it before committing: it enables
+   `dev-standards` and `typescript-lsp` (web) or `pyright-lsp` (python)
+   for every clone.
```

`tests/test-templates.sh`, Ergänzung:

```bash
for p in web python; do
    cs=$(cat "$T/$p/claude-settings.json" 2>/dev/null)
    contains "$p settings enable the standard"  "$cs" "dev-standards@claude-standards"
    contains "$p settings enable code intelligence" "$cs" "-lsp@claude-plugins-official"
    check "$p settings are valid JSON" \
      "$(node -e 'JSON.parse(require("fs").readFileSync(process.argv[1],"utf8"));console.log("ok")' "$T/$p/claude-settings.json" 2>/dev/null)" "ok"
done
```

Hinweis zur Ebene: der Konformitäts-Hook könnte zusätzlich melden, wenn
`.claude/settings.json` fehlt; erst sinnvoll, wenn die Datei Standard ist.

### 3.4 Ebene „Marketplace" — RTK nur als Opt-in (Punkt 14)

Nicht empfohlen (Begründung §4). Falls trotzdem gewünscht, ist das der
gepinnte Eintrag in `.claude-plugin/marketplace.json` — `sha` ist der
Commit hinter dem annotierten Tag `v0.1.2` (2026-05-18), aufgelöst per
`git ls-remote`:

```json
{
  "name": "rtk-plugin",
  "description": "Opt-in: compresses the output of git/cargo/pnpm calls in Bash. Measured ceiling about 3 % of input tokens; Read/Grep untouched. See docs/token-measurement.md.",
  "category": "productivity",
  "source": {
    "source": "url",
    "url": "https://github.com/enixCode/rtk-plugin.git",
    "ref": "v0.1.2",
    "sha": "6e1bd90ecb1cf7cfde934657540e9062fe37cd92"
  }
}
```

Plus `tests/test-manifests.sh:12` („marketplace lists the plugin" prüft
`plugins[0]`) bleibt gültig, solange `dev-standards` an Index 0 steht.

---

## 4. „Passt nicht zum Repo" — je ein Satz und die Alternative

- **3 · `CLAUDE_CODE_MAX_OUTPUT_TOKENS`**: die Variable ist in der aktuellen
  Doku (settings, env-vars, model-config, costs; 2026-09-10) nicht
  gelistet, und ein Standard, der auf einer undokumentierten Variable
  steht, ist keiner. Stattdessen: `effortLevel` (Punkt 2) senkt die
  Output-Seite dort, wo sie entsteht (Thinking), und der Test-Filter
  (Punkt 11) die Input-Seite, die Output verursacht. Falls sie in
  `claude --help` oder im Changelog wieder auftaucht, gehört sie in
  dieselbe `templates/global/settings.json`.
- **14 · RTK als gepinntes Standard-Plugin**: der JetBrains-Benchmark
  (Claude Code 2.1.201, Sonnet 5, 86 SkillsBench-Aufgaben) misst ein
  theoretisches Maximum von ≈3 % der Input-Tokens und real **+7,6 %
  Kosten bei low effort** (p = 0,004), +0,1 % bei high — weil Read/Grep am
  Bash-Hook vorbeigehen, etwa die Hälfte der Bash-Aufrufe Pipes/Heredocs
  nutzt, die RTK nicht anfasst, und der Rest unter 20 % der
  Tool-Result-Zeichen trägt. Dazu lädt der `SessionStart`-Hook des Plugins
  bei jedem ersten Start ein ~5-MB-Binary ohne dokumentierte Prüfsumme —
  genau das, was Punkt 12 verbietet — und braucht auf Windows Git Bash.
  Stattdessen: Punkt 11 filtert denselben Kanal (Bash-Output) für genau die
  Kommandos, die dieser Stack laut `scripts/verify` ausführt, ohne Binary
  und mit erhaltenem Exit-Status. Die erwartete Obergrenze „≈3 %, Read/Grep
  nicht erfasst" steht in `docs/token-measurement.md` (§3.2.5), damit die
  Entscheidung nachlesbar bleibt.
- **13 · graphify, Form**: kein Marketplace-Nachbau (siehe 3.2.4) und
  `graphify-out/` nicht komplett ignorieren — der Strict-Hook lenkt die
  erste Lesung auf einen Graph um, der beim frischen Checkout sonst nicht
  existiert und pro Entwickler neu (und mit Modell-Tokens) gebaut würde.
  Stattdessen: `graph.json` und `GRAPH_REPORT.md` committen, `cache/`,
  `graph.html`, `obsidian/`, `wiki/` ignorieren.

---

## 5. Reihenfolge der Umsetzung (Aufwand → Nutzen)

| # | Schritt | Punkte | Aufwand | Nutzen |
|---|---|---|---|---|
| 1 | `templates/global/settings.json` + `statusline.js` + README-Install-Schritt (3.1.1, 3.1.2, 3.1.4) | 1, 2, 4 | 1 h | hoch: haiku für Subagents und `medium` Effort wirken sofort in jeder Sitzung; die Statuszeile macht Kontextwachstum sichtbar |
| 2 | `verify`-Skill `model: sonnet` (3.2.1) | 1 | 10 min | Pflicht zu Schritt 1, sonst verifiziert haiku |
| 3 | Globale `CLAUDE.md` + Test-Budget 70 + Spec-Notiz/ADR (3.1.3) | 6, 8, 9, 10, 12 | 1 h | hoch: vier Verhaltensregeln in jeder Sitzung; Zeilenbudget ist die einzige Reibung |
| 4 | Test-Output-Hook mit Lib und Tests, README „Six hooks" (3.2.2) | 11 | 3–4 h | mittel–hoch: `scripts/verify`-Läufe sind der größte einzelne Bash-Output dieses Stacks |
| 5 | Projekt-`claude-settings.json` + `new-project` Schritt 8 + Tests (3.3.1) | 5, 12 | 2 h | mittel: LSP ersetzt Grep+Read-Ketten in TypeScript/Python-Projekten; Plugin wird pro Clone aktiv |
| 6 | README-Abschnitt Hook-Review + PR-Template (3.2.3) | 12 | 30 min | Voraussetzung, bevor irgendein Dritt-Hook (13, 14) angefasst wird |
| 7 | `docs/token-measurement.md` (3.2.5) | 15, 16, 19 | 1 h | Ohne Baseline ist jeder weitere Schritt nicht bewertbar; vor 8 anlegen |
| 8 | graphify in `new-project` + Konformitäts-Hook (3.2.4) | 13 | 2 h + Pilot | erst nach zwei Wochen Messung mit 1–5: Nutzen hängt vom Projekt ab (71,5× je Query ist eine Upstream-Zahl auf gemischtem Korpus) |
| 9 | RTK-Opt-in-Eintrag (3.4) | 14 | 15 min | nur wenn eine eigene Messung den Benchmark widerlegt; sonst nicht |

Nicht in der Liste: 3 (nicht setzen), 7 und 17–19 (bereits erfüllt).

Alle Schritte hier sind Vorschläge; nichts davon ist im Repo umgesetzt.
Die Testsuite steht unverändert bei 476 Checks, 0 Fehler.
