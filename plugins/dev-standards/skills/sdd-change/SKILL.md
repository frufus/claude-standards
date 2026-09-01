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
2. **Stop.** Present the proposal and wait until it is approved. This gate
   is the point of the whole workflow; skipping it makes the rest
   ceremony. Nothing in step 3 onward begins before that approval.
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
