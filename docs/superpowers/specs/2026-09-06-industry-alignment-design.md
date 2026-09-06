# Industry Alignment — Design

Date: 2026-09-06 · Status: proposed · Scope: the `dev-standards` plugin, both profiles
Extends: [2026-09-05 Verifier Node and Change Contracts](2026-09-05-verifier-node-and-change-contracts-design.md)
Source: the research memo *Agentic Coding Standards Review* (6 September 2026), whose seven ranked recommendations this design implements.

## 1. Context

The review compared the plugin against what Anthropic, OpenAI, Thoughtworks,
DORA, METR, OWASP and the practitioner community have converged on for working
with coding agents. On six of eleven themes the plugin is at or ahead of the
field. It is behind on five, and the gaps share a shape: the plugin has the
right rule in prose and no mechanism, artefact or step that carries it.

- **Nothing outside Claude Code reads the standard.** The rules live in
  `openspec/config.yaml` and the profile `CLAUDE.md`; Codex, Cursor, Copilot
  and twenty other tools read `AGENTS.md`, a Linux Foundation standard in more
  than 60,000 repositories, and open neither of ours.
- **The shortcut every long-running-agent source names first is not forbidden.**
  Deleting or weakening a test to make a check pass appears in Anthropic's
  harness, in Osmani's summary and in the Ralph guidance as the single most
  common way an agent declares itself done. The global layer says tests must
  be green; it does not say a test may not be removed to get there.
- **What reaches a reviewer depends on the session.** DORA names the
  "verification tax" of reviewing agent-written code as a cause of the
  productivity dip; Osmani's PR contract (intent, proof, risk tier, where
  human input is wanted) is the field's answer. `new-project` writes no
  pull-request template and nothing names the code that always gets a human.
- **A finding is answered and then forgotten.** Every's compound engineering
  adds the one step the others lack: after review, ask whether the system
  would catch this next time, and make it a test, a hook or a rule. Today's
  probe turned three defects into three tests because a controller chose to;
  the procedure did not ask.
- **The proposal rules are advisory.** Non-Goals, an unhappy-path scenario and
  a verification statement per task are the three most-skipped rules, and no
  hook or validator checks them.
- **The plugin is unpinned and one class of command is still only a reminder.**
  OWASP's Agentic Skills Top 10 is aimed at exactly this: pin what you
  install, and give destructive actions a hard gate.
- **Two computational sensors the field uses are absent from both profiles:**
  architecture fitness (dependency direction) and mutation testing.

## 2. Goals

- A project scaffolded by `new-project` is legible to any agent that reads
  `AGENTS.md`, with Claude Code reading the same file through an import.
- The three rules that protect an unattended run — no test ratchet, one unit
  per session, a mergeable tree at session end — are in the always-loaded
  layer or the procedure, not in a memo.
- Every pull request carries intent, proof, provenance and a risk tier, and
  the code that always gets a human is named once.
- Every verifier or review finding ends with a recorded decision about what
  the system will do about it next time.
- The proposal rules are checked mechanically, still reporting.
- The plugin is installable by tag, and the one exception to "hooks never
  deny" is decided and recorded.
- Architecture-fitness and mutation sensors are tried on both profiles and
  adopted into `scripts/verify` only where the trial earns it.

## 3. Non-goals

- **Migrating existing projects** to `AGENTS.md`, as before. Running
  `new-project` against an existing directory is the migration path.
- **A second AI reviewer or a multi-reviewer fan-out.** The review rule and
  the PR contract are the standard's part; who reviews is a project decision.
- **Metrics beyond one log line.** The archive step records finding counts and
  rounds; nothing aggregates them. Twenty changes make a trend; a dashboard
  does not belong to a one-developer standard.
- **Loops, triggers and the code-as-graph workflow**, still deferred.
- **Blocking anything but destructive git.** Section 4.6 is a single, named
  exception with its own ADR; every other hook keeps reporting.

## 4. Decisions

### 4.1 `AGENTS.md` is the project's instruction file; `CLAUDE.md` imports it

`new-project` writes `AGENTS.md` from a per-profile template
(`templates/<profile>/AGENTS.md`) and `CLAUDE.md` from a template whose first
content line is `@AGENTS.md`. Everything tool-agnostic moves into `AGENTS.md`:
the one-line description, the pointer to `openspec/config.yaml`, the Commands
block (scripts first), the Directories block, and a three-line boundary
section (always / ask / never) that restates the autonomy boundary in the form
the AGENTS.md guidance recommends. `CLAUDE.md` keeps only what is
Claude-specific: the import, the design-system paragraph and the pointer to
the `component` skill on `web`, nothing on `python`.

Both templates stay under the existing 40-line test; `AGENTS.md` gets its own
budget of 60 lines, tested. The conformance hook reports a profiled project
with no `AGENTS.md`, in the same sentence shape as the `scripts/verify` report.

**Rejected: a symlink `CLAUDE.md → AGENTS.md`.** Symlinks need a privilege on
Windows and are silently checked out as files by some git configurations; an
import is a plain file that works everywhere.

**Rejected: keeping the commands in both files.** That is the duplication the
parent design removed from `config.yaml` and `CLAUDE.md`; two lists of
commands drift the same way two lists of rules do.

### 4.2 The test ratchet, the session rules and the compaction line

The global layer gains, under **Quality**:

> - A test is never deleted, skipped or weakened to make a check pass. A
>   failing test is a finding, answered like any other.

and a new two-line section **Sessions**:

> - When compacting, keep the change id, the list of modified files and the
>   test commands.

`sdd-change` step 4 gains: implement one task per session when the change has
more than three tasks, and leave the tree committed and mergeable at the end of
every session, so a session that dies costs one task. The existing
session-boundary log line already records where it stopped.

The global file is at 50 lines of a 60-line budget; sections 4.2 and 4.3
together add about eight. The budget is not raised; if it does not hold, the
explanatory second sentence of the branch rule under **Git** is the line that
gives way, because `sdd-change` states it too.

**Rejected: putting the ratchet in the shared rules only.** The rule must
apply in a project with no `openspec/`; only the always-loaded layer is true
there.

### 4.3 A pull-request contract and the code that always gets a human

`new-project` writes `.github/pull_request_template.md` from
`templates/shared/pull_request_template.md`:

```
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

The global layer's **Alone and with the human** gains one bullet:

> - With the human, whatever the verdict: any change to authentication,
>   payments, secrets handling or the parsing of untrusted input.

**Rejected: risk tiers in the shared rules.** The tier names code that exists
in projects without `openspec/`; the always-loaded layer is the only place
that reaches them.

### 4.4 A compound step in `sdd-change`

A new step 9, **Compound**, between review and archive; archive becomes step 10.
For every finding the verifier or a reviewer raised, the session decides one
of four things and logs it in `progress.md`:

```
- 2026-09-06 — compound: <finding> → test (<file>)
- 2026-09-06 — compound: <finding> → hook (<hook>)
- 2026-09-06 — compound: <finding> → rule (<file>: <line>)
- 2026-09-06 — compound: <finding> → nothing (<why it will not recur>)
```

The question is the one Every's plugin asks: would the system catch this
automatically next time? A rule line goes into `openspec/config.yaml`,
`AGENTS.md` or an ADR, never into a file the agent cannot see. Produces: one
`compound:` line per finding. Step 10's archive log line records the counts:
`archived: <n> verifier findings, <m> review findings, <k> rounds`.

**Rejected: making the compound decision mechanical.** Whether a finding
deserves a test is judgement; the mechanism is that the judgement is recorded,
so the archive shows the findings that were answered with "nothing" and why.

### 4.5 The proposal rules are checked, still reporting

A new helper, `hooks/lib/change-lint.js`, takes a change directory and prints
one line per rule the change breaks:

| Rule (from `config.rules.yaml`)                  | Check                                                                 |
| ------------------------------------------------ | --------------------------------------------------------------------- |
| Proposal names its Non-Goals                     | `proposal.md` has a heading containing `Non-Goals`                    |
| Every requirement has an unhappy-path scenario   | every `### Requirement:` in `specs/**/spec.md` has at least two `#### Scenario:` blocks |
| Every task states how it is verified             | every `- [ ]`/`- [x]` line in `tasks.md` contains `verif`             |

The ship check calls it for every change in flight and adds its lines to the
notice, in the same reporting form as the verification checks. Nothing denies.
The heuristic for the unhappy path is structural, not semantic: two scenarios
per requirement is what the rule produces when followed, and a requirement
with one scenario is worth a sentence at the moment the work leaves the
machine.

**Rejected: a hook on `Write` under `openspec/changes/`.** It would fire while
a proposal is being drafted, which is exactly when Non-Goals are not yet
written. The moment to report is when the change ships.

**Rejected: relying on `openspec validate --strict`.** It checks OpenSpec's
own structure, not this standard's rules.

### 4.6 Releases are tagged, and destructive git is the one hook that denies

**Tags.** Every merge to `main` that changes the plugin gets an annotated tag
`vMAJOR.MINOR.PATCH` matching `plugin.json`. The README documents installing
from a tag: register the local checkout as a marketplace and check out the
tag, or `/plugin marketplace add frufus/claude-standards` followed by checking
out the tag in the marketplace cache. `v0.2.0` is tagged on today's merge
commit; this change ships as `v0.3.0`.

**Destructive git.** A fifth hook, `guard-destructive-git.sh` on `PreToolUse`
for `Bash`, **denies** four command shapes at a command position:
`git push --force` / `-f` (including `--force-with-lease`),
`git reset --hard`, `git clean` with `-f`, and `git branch -D`. The denial
reason names the command and the way through: the human runs it, or says so
and the session reruns it with `CLAUDE_STANDARDS_ALLOW_DESTRUCTIVE=1` in the
environment, which the hook honours. Everything else stays a reminder.

This is recorded as **ADR-0002**, which supersedes the parent design's
"nothing here can deny" for these four shapes and states the reasoning: the
parent argument was that a guard which fires on legitimate routine work gets
switched off. A force-push, a hard reset, a clean and a branch force-delete are
not routine work; each destroys something that cannot be recovered from the
working tree, and the cost asymmetry between a false block (one rerun with the
variable set) and a false allow (lost commits) is the whole case. The README's
sentence "Nothing here can deny a tool call" is replaced by the exception.

**Rejected: reporting only.** By the time a reminder is read, the command has
been chosen; for a reversible action that is fine, for these four it is the
one place a reminder arrives too late.

**Rejected: denying with no way through.** A hook that cannot be overridden by
the human gets switched off, which is the parent design's argument again.

### 4.7 Fitness and mutation sensors are tried, then adopted or deferred

A spike per profile, in a throwaway project, each with a written outcome:

| Profile  | Fitness sensor         | Mutation sensor      | Adopt when                                                              |
| -------- | ---------------------- | -------------------- | ----------------------------------------------------------------------- |
| `web`    | `dependency-cruiser`   | Stryker (Vitest)     | config under 20 lines, one clear rule (e.g. `src/components` never imports `src/repositories`), mutation run under 5 minutes on the probe |
| `python` | `import-linter`        | `mutmut`             | same bounds                                                             |

Where adopted, `scripts/verify` gains a `run fitness …` step after `typecheck`
and mutation runs as an explicit `scripts/verify --deep` mode rather than on
every run; the profile templates gain the config. Where not adopted, ADR-0003
records what was tried, the numbers, and why it waits.

**Rejected: prescribing without the spike.** Both sensors are known to be
noisy on small projects; a standard that adds five minutes to every check on a
throwaway earns the reputation the parent design warned about.

## 5. What a conforming project looks like

```
<project>/
  AGENTS.md                      # commands, directories, boundaries, pointer to config
  CLAUDE.md                      # @AGENTS.md + Claude-specific notes
  .github/pull_request_template.md
  .gitattributes                 # scripts/* and *.sh stay LF
  scripts/ dev verify            # + fitness step where adopted
  openspec/ …                    # unchanged
  docs/adr/
```

## 6. Workflow, revised

Steps 1–8 unchanged from the parent design. Step 9 is **Compound**: every
finding becomes a test, a hook, a rule or a recorded "nothing". Step 10 is
**Archive**, whose log line carries the counts.

## 7. Plugin changes

```
plugins/dev-standards/
  templates/web/AGENTS.md, templates/python/AGENTS.md      # new
  templates/web/CLAUDE.md, templates/python/CLAUDE.md      # @AGENTS.md + Claude-only
  templates/shared/pull_request_template.md                # new
  templates/global/CLAUDE.md                               # ratchet, sessions, risk tier
  skills/new-project/SKILL.md                              # AGENTS.md, PR template
  skills/sdd-change/SKILL.md                               # step 4 sessions, step 9 compound, step 10 archive
  hooks/lib/change-lint.js                                 # new
  hooks/check-ship.sh                                      # + change-lint lines
  hooks/check-conformance.sh                               # + AGENTS.md
  hooks/guard-destructive-git.sh                           # new, denies
  hooks/hooks.json                                         # + guard
  .claude-plugin/plugin.json, marketplace.json             # 0.3.0
docs/adr/0002-destructive-git-is-the-one-hook-that-denies.md
docs/adr/0003-fitness-and-mutation-sensors.md
README.md
tests/                                                     # every file above asserted
```

## 8. Bootstrap order

1. Tag `v0.2.0` on the current `main`.
2. AGENTS.md templates, CLAUDE.md rewrite, new-project, conformance, tests.
3. Global layer lines; sdd-change steps 4, 9, 10; tests (`Produces:` becomes 10).
4. PR template and new-project; tests.
5. change-lint.js, its tests, the ship-check integration.
6. guard-destructive-git.sh, ADR-0002, README sentence, hooks.json; tests must show a denial and the override.
7. The two spikes; ADR-0003; template changes if adopted.
8. README, manifests, version 0.3.0; probe against a throwaway project: AGENTS.md written and imported, PR template present, the ship check reports a proposal without Non-Goals, the guard denies a force-push and honours the override.
9. Tag `v0.3.0` after the merge.

## 9. Deferred

- Migrating kochbuch and the other existing projects onto `AGENTS.md`.
- A signed release; OWASP recommends it and nothing here consumes the signature yet.
- The code-as-graph workflow, unchanged.
