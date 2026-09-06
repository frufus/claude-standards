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
  `docs/adr/NNNN-title.md`.

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
- A test is never deleted, skipped or weakened to make a check pass. A
  failing test is a finding, answered like any other.

## Reviews are answered, not obeyed

- Every finding — from a human, an AI, a linter, CI — ends in one of two
  states: fixed, or rejected with a stated reason. Nothing is silently
  dropped.
- Where a project has specs, they and its ADRs outrank any reviewer.
- A disputed finding is settled with a test, not an argument.

## Alone and with the human

- Alone: propose, branch, implement approved tasks, verify, open a pull
  request, answer review findings, archive after merge.
- With the human: approve a proposal, accept a deviation, merge, and any
  action that is destructive or hard to reverse.
- "With the human" means stop and wait, not proceed and mention.
- With the human, whatever the verdict: any change to authentication,
  payments, secrets handling or the parsing of untrusted input.

## Sessions

- When compacting, keep the change id, the list of modified files and the
  test commands.

## Language

- Repository language is English: documentation, code comments, commit
  messages, identifiers.
