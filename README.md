# claude-standards

A Claude Code plugin marketplace holding one plugin, **`dev-standards`**: the
development standard every project here is built to, made executable rather than
merely written down.

It reports what a project is missing when a session opens, reminds when code is
written without an approved proposal behind it, checks commit subjects, and
scaffolds a new project onto the standard in one command.

---

## The problem it solves

A written standard that lives in a document is a standard nobody follows past
the second week. It is invisible at the moment it applies — when someone is
about to edit a file, or about to write a commit message, or three months into a
project that quietly never adopted it.

This plugin puts the standard where the work happens. Five hooks and five
skills. Four of the hooks **report rather than block**: a guard that stops
legitimate work — a typo in a comment, a hotfix, repairing a broken build —
gets switched off, and then it protects nothing. There is one exception,
recorded in [ADR-0002](docs/adr/0002-destructive-git-is-the-one-hook-that-denies.md):
a force-push, a hard reset, a clean or a branch force-delete is denied until
the human says otherwise, because for those four a reminder arrives after the
decision.

## The standard itself

Loaded into every session as an always-on rule layer
([`templates/global/CLAUDE.md`](plugins/dev-standards/templates/global/CLAUDE.md)).
A project's own `openspec/config.yaml` is binding for that project and may be
stricter; it may not be looser.

**Work starts as a proposal.** In a project with an `openspec/` directory, a
unit of work begins as a change proposal and is approved before it is
implemented. A deviation from the spec is named and justified *before it is
built*, never discovered afterwards in the diff.

**Git.** One branch per unit of work, named `claude/<topic>`, branched from
current `main`, ended by its merge and never reused. Conventional Commits,
imperative mood, subject ≤ 72 characters. Commit as each unit completes, not in
one batch at the end.

**Quality.** Tests green before a change is archived or a PR opened. Data
entering a process is parsed into a known shape at the boundary — network,
storage, imports, payloads — before anything else touches it.

**Verification is done by someone who did not write the code.** A fresh
sub-agent drives every scenario in the change's spec deltas, unhappy paths
included, and leaves a verdict and proof per scenario in the change directory.
Every *fail* and *not verifiable* is answered — fixed, or rejected with a
reason — before the change is pushed, PR'd or archived.

**A test is never deleted, skipped or weakened to make a check pass.**
Changes to authentication, payments, secrets or the parsing of untrusted
input are reviewed by the human whatever the verdict.

**Reviews are answered, not obeyed.** Every finding — human, AI, linter, CI —
ends as *fixed* or *rejected with a stated reason*. Nothing is silently dropped.
Where a project has specs, they and its ADRs outrank any reviewer. A disputed
finding is settled with a test, not an argument.

---

## Install

```
/plugin marketplace add frufus/claude-standards
/plugin install dev-standards@claude-standards
```

Releases are tagged. The current release is `v0.3.0`; check the
marketplace clone out at that tag to pin it.

## What you get

### Five skills

| Skill        | When it runs                                                                 |
| ------------ | ---------------------------------------------------------------------------- |
| `new-project`| Starting any new project, or bringing an existing one onto the standard. Takes `web` or `python`. |
| `sdd-change` | Any feature, fix or refactor in a project that has an `openspec/` directory.  |
| `adr`        | A change makes a choice that outlives it — a format, a boundary, a dependency, a data model. |
| `component`  | A project needs a UI component that does not exist yet, or a local one starts looking shared. |
| `verify`     | Step 7 of every change, and before any pull request or archive. Runs a fresh sub-agent against the spec's scenarios; writes `verification.md` and `proof/`. |

**`sdd-change`** is the centre of gravity. It drives a unit of work from
proposal to archive: propose → **stop for approval** → branch → implement task
by task, tests first → record decisions as ADRs → verify → archive. Step two is
the point of the whole workflow; skipping it makes the rest ceremony.

**`adr`** enforces the one thing that makes an ADR worth writing: for every
decision, the alternative that was rejected and why. *If you cannot name one,
you have recorded a fact, not a decision.*

**`component`** asks where a component belongs before asking how to build it —
because most of a component's cost is not writing it, but the second project
writing it again, slightly differently. Does it name something from the
product's domain? It belongs to the project. Would an unrelated project want it
unchanged? It belongs in the design system. Does it hold state that outlives the
screen? It is not a component at all.

**`verify`** withholds the diff, the conversation and `tasks.md` from the
verifier on purpose. The session that wrote the code checks it against its
own theory of the code; the scenarios it fails to drive are the ones the
theory says cannot fail. Fresh context is the whole mechanism.

### Five hooks

| Event                       | What it does                                                                    |
| --------------------------- | ------------------------------------------------------------------------------- |
| `SessionStart`              | Reports which parts of the standard this project is missing — no `openspec/`, unprofiled, no `CLAUDE.md`, no `docs/adr/`, no design-system dependency in a web project. |
| `PreToolUse` on `Edit\|Write` | Reminds when a **source** file is edited with no OpenSpec change in flight.     |
| `PreToolUse` on `Bash`      | Checks a `git commit -m` subject against Conventional Commits and the 72-character limit. |
| `PreToolUse` on `Bash`      | **Denies** a force-push, hard reset, clean or branch force-delete until the human says otherwise (`CLAUDE_STANDARDS_ALLOW_DESTRUCTIVE=1`). The one exception; see ADR-0002. |
| `PreToolUse` on `Bash`      | Reminds on `git push`, `gh pr create` or `openspec archive` while a change in flight has no `verification.md` or an unanswered finding in it, or a proposal that breaks the shared rules (no Non-Goals, a requirement without its unhappy path, a task without a verification statement). |

A project is *allowed* to be non-conforming. Saying so once per session is the
whole job. The edit reminder stays quiet when the project has not adopted the
standard at all — repeating it on every edit would make both messages ignorable.

### Two stack profiles

The profile is chosen once and decides the toolchain for the life of the
project, so `new-project` asks rather than inferring it from files that happen
to be present.

- **`web`** — Vue 3 + TypeScript strict + Vite, Tailwind v4 CSS-first,
  Vitest + Playwright, ESLint/Prettier/`vue-tsc`. The interface is built on
  [`@frufus/design-system`](https://github.com/frufus/design-system): tokens,
  primitives and its two stylesheets. Colours, control heights, radii and focus
  rings are taken from it, never redeclared.
- **`python`** — `uv`, pytest, ruff, mypy strict.

Both profiles carry two scripts, written by `new-project`: `scripts/dev`
brings the application up idempotently and prints where, `scripts/verify`
runs lint, typecheck, the fitness check, units and end-to-end in that order
and exits non-zero at the first failure (`--deep` adds mutation testing on
`web`; see ADR-0003). They are the deterministic steps of every change; a
session runs them instead of rediscovering the toolchain.

Going without the design system in a web project is possible, but the opt-out is
deliberately **an ADR, not a config key**: it should cost a paragraph, not a
line. The conformance hook reads the dependency out of `package.json`'s
dependency fields rather than grepping for the name — a grep also matches the
package's own `name`, which would silence the check for the design system itself
by coincidence rather than on purpose.

---

## What `new-project` writes

1. `openspec init --tools claude`
2. `openspec/config.yaml`, assembled in order from the profile fragment
   (`schema:` and `profile:` — the key the conformance hook reads), a `context:`
   block written **with the human**, and the shared rule set verbatim.
3. `AGENTS.md` from the profile template — commands, directories,
   boundaries — and a `CLAUDE.md` that begins with `@AGENTS.md`, so Claude
   Code and every other agent read the same file.
4. `docs/adr/` for decisions to live in.
5. `scripts/dev` and `scripts/verify` from the profile, executable in git's
   index.
6. `.github/pull_request_template.md`: intent, proof, provenance and risk
   tier, and where human attention is wanted.

The `context:` block is the binding project truth: product, non-negotiable
principles, tech stack, language convention and domain vocabulary. Everything a
session must not get wrong belongs there and nowhere else.

The shared rules then bind every proposal, spec, design note and task list —
for example: a proposal names its Non-Goals; a spec includes at least one
unhappy-path scenario; a design note names the alternatives it rejected; every
task states how it is verified.

---

## What a change leaves behind

Every step of `sdd-change` produces an artefact, and a step whose artefact
is missing has not happened. Three of them are new:

- `openspec/changes/<id>/progress.md` — a status header (overwritten) and
  an append-only log: approval, each task's commit, each deviation, each
  verification, and the end of every session that leaves the change
  in-progress. The next session reads the last line first.
- `openspec/changes/<id>/verification.md` — one verdict per scenario with
  its proof, and an `Answer:` under every finding. The ship-check hook
  reads it.
- A `compound:` line per finding in `progress.md`: whether it became a
  test, a hook, a rule, or a recorded "nothing"; and an `archived:` line
  with the counts.

Both archive with the change.

---

## Repository layout

```
.claude-plugin/marketplace.json    The marketplace; lists one plugin
plugins/dev-standards/             The plugin
  .claude-plugin/plugin.json
  hooks/                           Five hooks, plus shared bash and node helpers
  skills/                          adr, component, new-project, sdd-change, verify
  templates/
    global/CLAUDE.md               The always-loaded rule layer
    shared/config.rules.yaml       Rules bound into every project
    shared/pull_request_template.md
    web/  python/                  Per-profile AGENTS.md, CLAUDE.md, config fragment and scripts/
    adr/TEMPLATE.md
tests/                             Bash harness, one file per subject
docs/adr/                          This repository's own decisions — three so far
```

The plugin lives in a subdirectory rather than at the repository root, matching
the shape all 53 plugins in the installed official marketplace use. The
reasoning is [ADR-0001](docs/adr/0001-plugin-lives-in-a-marketplace-subdirectory.md)
— which is also this repository's own worked example of the ADR format it
prescribes.

## Verifying

```
bash tests/run-tests.sh
```

406 checks over the manifests, both helper libraries, all five hooks,
all five skills, the script templates and every other template. The suite asserts the
*content* of the skills and templates, not merely that the files exist — so a
skill that stops prescribing the design system, or a template that grows fat,
fails the build.

## Status and licence

Version 0.3.0. Complete and green; not published beyond this account. No licence
file — all rights reserved.
