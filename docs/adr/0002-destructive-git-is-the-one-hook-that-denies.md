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
