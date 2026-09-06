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
   with the commit subject, update `Current:`. When the change has more
   than three tasks, implement one task per session, and leave the tree
   committed and mergeable at the end of every session, so a session that
   dies costs one task.
   Produces: one commit per task; `tasks.md` ticked; `progress.md` current
   with `Status: in-progress`.
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
   finished, not because someone remembered to update it. If an earlier
   archive attempt failed, remove the stale
   `openspec/changes/archive/.openspec-archive.lock` before retrying.
   After archiving, replace the `Purpose: TBD` the archiver writes into a
   newly created capability spec.
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
