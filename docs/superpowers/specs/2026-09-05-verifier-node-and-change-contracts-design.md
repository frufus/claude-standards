# Verifier Node and Change Contracts — Design

Date: 2026-09-05 · Status: proposed · Scope: the `dev-standards` plugin, both profiles
Extends: [2026-09-01 Cross-Project Development Standard](2026-09-01-cross-project-standard-design.md)

## 1. Context

The standard as built is a procedure: `sdd-change` walks a unit of work through
nine steps with a human gate at step two, three hooks put reminders where the
work happens, and the OpenSpec change directory is where the state of that work
lives. The procedure is enforced in text, read by the agent, which is the right
level for it — the model follows a written SOP well and a session can be
resumed.

Three things are missing from it, and they are the same three things that make
the difference between an agent that *reports* a change as done and one whose
report can be trusted without re-reading the diff.

**The agent that wrote the code is the agent that checks it.** Step seven of
`sdd-change` is `openspec validate` plus the test suite, run in the same session
that just implemented the change. That session holds a theory of why the code is
right, and a model checking its own work against its own theory finds what the
theory predicts. What the spec's scenarios say — including the unhappy path that
every spec is required to contain — is never driven end to end by anyone who
did not write the implementation.

**Deterministic steps are done by hand, every time.** Starting the dev server,
running lint, typecheck, units and end-to-end in the right order, knowing that
a Vite watcher left running makes `openspec archive` fail on Windows with
`EPERM` — each session rediscovers these. The standard prescribes commands but
no script, so the agent spends turns fighting the toolchain that a twenty-line
script would remove, and it fights it differently each time.

**The steps have no outputs.** The shared rules require every *task* to state
how it is verified, but the nine *steps* of the procedure produce nothing
checkable. "Implement" ends when the agent says so. Nothing in the change
directory says which task is current, what blocked the last session, or whether
the work was ever verified by anyone. A second session, or a hook, cannot tell
where a change is without reading the whole conversation that produced it.

The occasion for fixing this now is that the same three gaps are the ones named,
from the other direction, by teams running agents without a human prompting
each step: a verifier as a separate node, scripts for the deterministic edges,
an input/output contract per node, and a state artifact that any node can read.
The standard's human gate stays. What changes is that the steps after it become
checkable.

## 2. Goals

- Verification of a change is done by an agent that did not implement it,
  against the spec's scenarios, and leaves proof in the change directory.
- Every deterministic step a change needs — dev server up, full check — is one
  script, written once at scaffold time, in the same place in every project.
- Every step of `sdd-change` names what it produces, so that a session, a hook,
  or a human can see where a change is from the change directory alone.
- The boundary between what the agent does alone and what needs the human is
  written down once, in the always-loaded layer.

## 3. Non-goals

- **A code-as-graph version of the procedure.** Steps three to nine of
  `sdd-change` are mechanical enough for a dynamic workflow — implement,
  verify, simplify, PR — once each step has a contract. This change writes the
  contracts. The workflow is its own change, and it is not the default: a
  workflow starts fresh sessions that cannot be resumed, and the skill can.
- **Loops and triggers.** Running `sdd-change` on a schedule or on an event
  removes nobody's approval, but it is a different thing to design, and it
  needs the autonomy boundary in section 4.5 to exist first.
- **Hooks that block.** The reasoning in section 4.6 of the parent design
  stands. Every hook here reports.
- **A repository-wide log.** State belongs to the change and archives with it
  (section 4.4). A cross-change or cross-project memory is a separate question.
- **Migrating existing projects**, as before. A project that already has
  `openspec/` gets the new skill and hooks for free by installing the plugin;
  it gets the scripts only when someone runs `new-project` against it.

## 4. Decisions

### 4.1 Verification is a separate node

A new skill, **`verify`**, runs verification of a change as a fresh sub-agent.
The calling session gives it a brief containing exactly:

- the change id and the spec deltas under `openspec/changes/<id>/specs/`,
- the project's `scripts/verify` and `scripts/dev` entry points,
- the project's `context:` block from `openspec/config.yaml`.

It does **not** receive the conversation, the diff, or `tasks.md`. The verifier
must derive what to check from the scenarios, not from what the implementer
says was done.

The verifier:

1. Runs `scripts/verify`. A non-zero exit is a finding; the run stops there
   only if nothing else can be exercised.
2. For every scenario in the deltas — happy and unhappy — drives it against the
   running application (`scripts/dev` for a `web` project; the CLI, module or
   test entry point for `python`) and records a verdict: **pass**, **fail**,
   or **not verifiable** with the reason.
3. Writes `openspec/changes/<id>/verification.md`: the verdict per scenario,
   the proof next to each — screenshot paths under
   `openspec/changes/<id>/proof/` for `web`, captured command output for
   `python` — and the `scripts/verify` exit status.

The calling session treats every **fail** and every **not verifiable** as a
review finding under section 4.7 of the parent design: fixed, or rejected with
a stated reason, written into `verification.md` under the verdict it answers. A
change is not archived and no pull request is opened while a finding is
unanswered.

`sdd-change` step seven becomes: invoke `verify`; answer its findings. The
implementer no longer runs the suite as the verification step — it runs the
touched area's tests while implementing, as the shared rules already say, and
the verifier runs everything.

**Rejected: verification in the same session.** The implementer's context is
the problem, not its competence. A model that just wrote the code checks it
against its own model of the code; the scenarios it fails to drive are the
ones its theory says cannot fail. Fresh context is the whole mechanism, and it
costs one sub-agent.

**Rejected: a per-project `/verify` skill scaffolded into each repository.**
This is the shape one public harness uses. The project-specific part of
verification is how to start the app and how to run the checks — and that is
what `scripts/` is for. Everything else is the same in every project. A skill
copied into every repository drifts from the standard the moment the standard
changes, and the plugin exists to prevent exactly that.

**Rejected: proof as a test suite only.** The suite is necessary and
`scripts/verify` runs it. But the spec's scenarios are written as observable
behaviour so that someone who cannot read the code can check them, and a green
suite is not that check. Screenshots and command output are.

### 4.2 Deterministic steps are scripts

Every conforming project carries a `scripts/` directory with two entry points,
both bash, written by `new-project` from a per-profile template:

| Script           | Contract                                                                                                         |
| ---------------- | ---------------------------------------------------------------------------------------------------------------- |
| `scripts/dev`    | Brings the application up for a human or a verifier. Idempotent: if it is already up, prints where and exits 0. Prints the URL or entry point on the last line. Never starts a second instance. `scripts/dev down` stops it. |
| `scripts/verify` | Runs, in order: lint, typecheck, unit tests, end-to-end tests. Stops at the first failure with its output. Exit status is the verdict. Takes no arguments. |

The `web` template starts Vite in the background, waits for the port, and
records the process so `down` can stop it — which is what makes the archive
step reliable on Windows, where a live watcher holds the directory. The
`python` template's `dev` is the project's entry point under `uv run`; where a
project has no long-running process, the template says so and exits 0 with a
note.

The profile `CLAUDE.md` templates list `scripts/dev` and `scripts/verify`
first under **Commands**, then the individual tools. The conformance hook
reports a profiled project that has no `scripts/verify`.

**Rejected: npm scripts and `pyproject` tasks only.** The `python` profile has
no equivalent of `npm run`, so the agent needs to know the toolchain to compose
the check. And neither toolchain composes "start the server, wait, run e2e,
stop the server" — that is a script whatever it is called. Putting it in one
place with one name in both profiles is the point.

**Rejected: PowerShell.** The hooks already require bash and node; every
project here runs under Git Bash. One shell.

**Rejected: `scripts/test` as a third entry point.** Unit tests alone are what
the implementer runs while working, and the profile's own command does that.
A third script is one more thing to keep consistent for a case the toolchain
already handles.

### 4.3 Every step of the procedure produces something

`sdd-change` gains a **Produces** line per step. The artefacts, in order:

| Step | Produces                                                                                                         |
| ---- | ---------------------------------------------------------------------------------------------------------------- |
| 1 Propose   | `openspec/changes/<id>/` with `proposal.md`, `specs/` deltas, `tasks.md`; `progress.md` with status *proposed*. |
| 2 Stop      | The human's approval, recorded as the first entry in `progress.md`. Nothing else.                           |
| 3 Branch    | `claude/<topic>` from current `main`; branch name recorded in `progress.md`.                                 |
| 4 Implement | One commit per task; the task ticked in `tasks.md`; `progress.md` status updated after each.                  |
| 5 Record    | An ADR under `docs/adr/` for anything that outlives the change, linked from `proposal.md`.                  |
| 6 Deviate   | A dated entry in `progress.md` naming the deviation and its justification, written before the deviation is built. |
| 7 Verify    | `verification.md` from the `verify` skill, with every finding answered.                                       |
| 8 Review    | Every finding answered in the review itself; `progress.md` status *reviewed*.                                |
| 9 Archive   | The change under `openspec/changes/archive/`, `progress.md` and `verification.md` with it.                   |

The rule that follows: **a step whose artefact is missing has not happened.**
That is what lets a hook (section 4.6) or a second session say where a change
is without asking.

The shared rules in `config.rules.yaml` gain one line under `operations.apply`:
the change's `progress.md` is updated as each task completes, and one under
`operations.archive`: `verification.md` exists with no unanswered finding.

**Rejected: contracts as JSON schemas.** A schema is what a code-as-graph
workflow would need, and the non-goals defer that. For a procedure the model
follows in text, a named file with a stated shape is the contract; a schema
now would be maintained for a consumer that does not exist yet.

### 4.4 State lives in the change

`openspec/changes/<id>/progress.md` is the state artefact. Its shape:

```
# Progress: <id>

Status: proposed | approved | in-progress | verified | reviewed
Branch: claude/<topic>
Current: <task number and title, or "—">
Blocked: <what, or "—">

## Log
- 2026-09-05 — proposal approved
- 2026-09-05 — task 1 done: <commit subject>
- 2026-09-06 — deviation: <what and why>
- 2026-09-06 — session ended at task 3, blocked on <what>
```

The header is overwritten; the log is append-only. `sdd-change` writes the
header at every status change and appends a line at every task boundary,
every deviation, and at the end of every session that leaves the change
in-progress. The `verify` skill appends its verdict summary.

OpenSpec's `archive` moves the whole change directory, so the state goes to the
archive with the change and needs no separate lifecycle.

**Rejected: `tasks.md` checkboxes as the only state.** They say what is done,
not what is current, what blocked, or why a deviation was taken. They also
cannot carry a session boundary, and the session boundary is the moment the
state is needed.

**Rejected: a repository-wide `LOG.md`.** One file for every change, never
archived, growing for the life of the project, is context spent in every
session for the life of the project. State scoped to the change is read only
by sessions working on that change and disappears from the working set when the
change does.

### 4.5 The autonomy boundary is written down

The always-loaded layer (`templates/global/CLAUDE.md`) gains one section:

> ## Alone and with the human
>
> - Alone: propose, branch, implement approved tasks, verify, open a pull
>   request, answer review findings, archive after merge.
> - With the human: approve a proposal, accept a deviation, merge, and any
>   action that is destructive or hard to reverse.
>
> "With the human" means stop and wait, not proceed and mention.

This is what the procedure already does; it is written down so that it can be
checked, and so that a trigger-based loop, if one is ever built, has a rule to
obey rather than a habit to infer. The section is eight lines; the global file
is at 42 of its 60-line budget, so nothing has to give way for it.

**Rejected: putting it in the shared rules.** The boundary is
project-independent and must apply in a project that has no `openspec/` yet.
The always-loaded layer is the only place that is true.

### 4.6 A ship check, reporting

A new hook, `check-ship.sh`, on `PreToolUse` for `Bash`, alongside the commit
check. It reads the command; when it is `gh pr create`, `git push` to a
`claude/` branch, or `openspec archive`, and the project has a change in
flight whose `verification.md` is absent or contains an unanswered finding, it
emits a reminder naming the change and the missing artefact. It never denies.

The conformance hook gains the `scripts/verify` report from section 4.2.

**Rejected: a `Stop` hook.** It is the obvious place — "the agent is about to
say it is done" — but a `Stop` hook's only channel back into the session is a
block with a reason. There is no reporting output; plain text goes to the
transcript and not to the agent. A blocking `Stop` hook is exactly the guard
the parent design rejected, and it can loop. The moment the work leaves the
machine — push, PR, archive — is a Bash command, and Bash hooks can report.

**Rejected: checking on every commit.** Commits happen per task, long before
verification is due. A reminder on each would be ignored by the time it
mattered.

## 5. What a conforming project looks like

```
<project>/
  scripts/
    dev                  # up (idempotent, prints URL) / down
    verify               # lint, typecheck, unit, e2e; exit status is the verdict
  openspec/
    config.yaml
    specs/<capability>/spec.md
    changes/<id>/
      proposal.md  tasks.md  design.md  specs/
      progress.md          # status header + append-only log
      verification.md      # verdict per scenario, proof, findings answered
      proof/               # screenshots (web) — committed with the change
    changes/archive/
  docs/adr/
  CLAUDE.md                # commands: scripts first, then the tools
```

## 6. Workflow, revised

Steps one to six and eight to nine of the parent design's section 6 are
unchanged in substance and gain the artefacts of section 4.3. Step seven reads:

7. Verification is done by the `verify` skill in a fresh sub-agent, against
   the spec's scenarios, and every finding it raises is fixed or rejected with
   a stated reason before the change is archived or a pull request opened.

## 7. Plugin changes

```
plugins/dev-standards/
  skills/verify/SKILL.md            # new
  skills/sdd-change/SKILL.md        # Produces lines; step 7; progress.md
  skills/new-project/SKILL.md       # writes scripts/; lists them in CLAUDE.md
  templates/web/scripts/dev         # new
  templates/web/scripts/verify      # new
  templates/python/scripts/dev      # new
  templates/python/scripts/verify   # new
  templates/web/CLAUDE.md           # Commands: scripts first (stays ≤ 40 lines)
  templates/python/CLAUDE.md        # same
  templates/shared/config.rules.yaml  # progress.md on apply; verification.md on archive
  templates/global/CLAUDE.md        # "Alone and with the human"
  hooks/check-ship.sh               # new
  hooks/check-conformance.sh        # + scripts/verify
  hooks/hooks.json                  # + check-ship on Bash
tests/
  test-skills.sh                    # verify skill shape; sdd-change Produces; step 7
  test-templates.sh                 # scripts exist, are bash, verify runs all four
  test-check-ship.sh                # new
  test-conformance.sh               # + scripts/verify case
  test-global-claude-md.sh          # + boundary section, line budget
```

The tests assert content, as the suite already does: that `verify` forbids
passing the diff to the sub-agent, that `sdd-change` names `verification.md`
at step seven, that each `scripts/verify` template runs lint, typecheck, unit
and e2e in that order, that the global file names both lists of the boundary.

## 8. Bootstrap order

1. Script templates and the `new-project` changes, with tests.
2. The `verify` skill, with tests.
3. `sdd-change` contracts and `progress.md`; the shared-rule lines.
4. The global boundary section; check the line budget.
5. `check-ship.sh` and the conformance addition; `hooks.json`.
6. Verify against a throwaway `web` project: `new-project` writes both
   scripts and they run; `verify` on a change with a deliberately failing
   unhappy-path scenario produces a **fail** with a screenshot; `check-ship`
   reports on `gh pr create` while the finding is unanswered and is silent
   after it is answered.
7. Only then use it on a real change.

Step six is the same rule as before: a verifier that has never been seen to
fail is trusted, and should not be.

## 9. Deferred

- The code-as-graph workflow for steps three to nine, once these contracts have
  been used on real changes and their shapes have stopped moving.
- Whether `verify` should run a second time after review findings are
  answered, or whether answering a finding with a test is sufficient. Decide
  from the first three changes that go through it.
- A conformance report for projects that predate `scripts/` but have adopted
  everything else. Today they are reported as missing `scripts/verify`, which
  is true, and the fix is `new-project` against the existing directory.
