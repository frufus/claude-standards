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

This plugin puts the standard where the work happens. Three hooks and four
skills, all of which **report rather than block**. Nothing here can deny a tool
call. A guard that stops legitimate work — a typo in a comment, a hotfix,
repairing a broken build — gets switched off, and then it protects nothing.

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

## What you get

### Four skills

| Skill        | When it runs                                                                 |
| ------------ | ---------------------------------------------------------------------------- |
| `new-project`| Starting any new project, or bringing an existing one onto the standard. Takes `web` or `python`. |
| `sdd-change` | Any feature, fix or refactor in a project that has an `openspec/` directory.  |
| `adr`        | A change makes a choice that outlives it — a format, a boundary, a dependency, a data model. |
| `component`  | A project needs a UI component that does not exist yet, or a local one starts looking shared. |

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

### Three hooks

| Event                       | What it does                                                                    |
| --------------------------- | ------------------------------------------------------------------------------- |
| `SessionStart`              | Reports which parts of the standard this project is missing — no `openspec/`, unprofiled, no `CLAUDE.md`, no `docs/adr/`, no design-system dependency in a web project. |
| `PreToolUse` on `Edit\|Write` | Reminds when a **source** file is edited with no OpenSpec change in flight.     |
| `PreToolUse` on `Bash`      | Checks a `git commit -m` subject against Conventional Commits and the 72-character limit. |

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
3. `CLAUDE.md` from the profile template — deliberately thin, because it points
   at the config rather than restating it.
4. `docs/adr/` for decisions to live in.

The `context:` block is the binding project truth: product, non-negotiable
principles, tech stack, language convention and domain vocabulary. Everything a
session must not get wrong belongs there and nowhere else.

The shared rules then bind every proposal, spec, design note and task list —
for example: a proposal names its Non-Goals; a spec includes at least one
unhappy-path scenario; a design note names the alternatives it rejected; every
task states how it is verified.

---

## Repository layout

```
.claude-plugin/marketplace.json    The marketplace; lists one plugin
plugins/dev-standards/             The plugin
  .claude-plugin/plugin.json
  hooks/                           Three hooks, plus shared bash and node helpers
  skills/                          adr, component, new-project, sdd-change
  templates/
    global/CLAUDE.md               The always-loaded rule layer
    shared/config.rules.yaml       Rules bound into every project
    web/  python/                  Per-profile CLAUDE.md and config fragment
    adr/TEMPLATE.md
tests/                             Bash harness, one file per subject
docs/adr/                          This repository's own decisions
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

163 checks over the manifests, both helper libraries, all three hooks, all four
skills and every template. The suite asserts the *content* of the skills and
templates, not merely that the files exist — so a skill that stops prescribing
the design system, or a template that grows fat, fails the build.

## Status and licence

Version 0.1.0. Complete and green; not published beyond this account. No licence
file — all rights reserved.
