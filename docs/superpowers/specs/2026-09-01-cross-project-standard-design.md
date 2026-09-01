# Cross-Project Development Standard — Design

Date: 2026-09-01 · Status: proposed · Scope: every project in the workspace

## 1. Context

Projects accumulate their own conventions. Left alone, each one answers the
same questions differently: where the binding requirements live, whether a
change starts as a proposal or as code, what a commit looks like, when tests
have to be green, what happens to a review finding nobody agrees with. The cost
is not felt inside any single project — it is felt when moving between them,
because nothing learned in one carries over to the next.

Two things have to be settled to make that stop, and they are independent:

- **A specification mechanism** — how requirements are written, kept current,
  and connected to the work that changes them.
- **A working discipline** — binding non-negotiables, architecture decisions
  that survive their authors, branch and commit rules, test gates, and a rule
  for handling review findings.

A mechanism without discipline produces well-formatted documents nobody honours.
Discipline without a mechanism produces careful work whose requirements drift
out of date. This design settles both, and anchors them where they take effect
rather than in a document that has to be remembered.

## 2. Goals

- One method for specifying and building work, in every project, regardless of language.
- Prescriptive tech stacks, so a new project does not re-litigate its toolchain.
- The standard is written down where it actually takes effect, not in a document nobody loads.
- Non-web projects get real requirements, not an exemption.

## 3. Non-goals

- Migrating existing projects. The standard applies to new projects and new
  work; each existing project's migration is decided separately. Converting a
  large hand-maintained specification into capability specs is a project of its
  own, with real risk of losing binding detail in the move.
- Mandating a second AI reviewer. Routing pull requests through a second vendor
  is a legitimate practice but presumes that vendor, so it is not part of the
  standard. How review findings are *answered* is part of it (section 4.7).
- Replacing what OpenSpec already does. No phase model, no separate CHANGELOG —
  see section 4.3.

## 4. Decisions

### 4.1 OpenSpec is the specification mechanism

Capability specs under `openspec/specs/<capability>/spec.md` hold current truth.
Proposals in flight live in `openspec/changes/<id>/`. Archiving a change folds
its spec deltas back into the capability specs, so the specification is updated
by the act of finishing work rather than by remembering to update it afterwards.

The alternative is a single binding specification document, extended over time.
It works, and it has one genuine advantage: everything is in one place, readable
front to back. But it scales only by growing. Past roughly a thousand lines plus
extension files, keeping it internally consistent becomes its own task, and the
document's age is invisible — nothing marks which sections still describe the
system and which describe an intention from months ago. A change-based mechanism
makes that visible by construction: what is in `specs/` was archived, what is in
`changes/` is not built yet.

### 4.2 The OpenSpec config is the single source of project truth

A common arrangement keeps rules in two places — an agent instruction file and
a specification document — and then needs an explicit conflict rule saying which
one wins. That rule is a symptom. It manages duplication instead of removing it,
and it only works as long as everyone remembers the precedence.

Under this standard the project's non-negotiables, tech stack, domain vocabulary
and language convention live in the `context:` block of `openspec/config.yaml`.
The project's `CLAUDE.md` becomes thin: orientation, commands, directory map,
and a pointer to the config. No conflict rule is needed, because there is
nothing left to conflict with.

### 4.3 No phase model, no per-project CHANGELOG

A phase model — an ordered plan of build stages, with a hand-maintained log
recording which stage is current — answers the questions "what was decided",
"what was built" and "in what order". The OpenSpec change archive answers the
same three. Keeping both means maintaining two records of what is done, which
will eventually disagree, and at that point neither can be trusted without
checking the other.

Release notes for users, where a project needs them, are a different artifact
with a different audience, and are generated from commits rather than maintained
by hand.

### 4.4 Two stack profiles

Both profiles share the method — OpenSpec, ADRs, branch and commit discipline,
test gates, review handling. Only the toolchain differs.

**Profile `web`**:

- Vue 3 with `<script setup>`, TypeScript strict, Vite
- Tailwind v4: design tokens only in `@theme`; no dynamically composed class
  names — state colours as explicit maps, so that every class a build sees is
  greppable and nothing is purged by surprise
- Pinia for ephemeral UI state only; persistent data goes through a repository layer
- vue-router; i18n from the first UI change, no hardcoded user-facing strings
- Vitest for units, Playwright for a thin end-to-end layer
- ESLint and Prettier, `vue-tsc` for typechecking
- Default posture: no backend, no secrets in the bundle, no external CDNs,
  fonts or analytics

**Profile `python`**:

- `uv` for dependency and environment management
- `ruff` for both linting and formatting
- `mypy` in strict mode
- `pytest`
- A Dockerfile where the project is deployed

Both lists are toolchain preferences. One rule sits above them and is not a
preference: **data entering the process is parsed into a known shape at the
boundary — network, storage, imports, URL payloads — before anything else
touches it.** Which library does that is a project decision, made in the
project's `openspec/config.yaml` and not by this standard; the requirement that
something does it is standard-wide.

### 4.5 Three layers of anchoring

**Layer 1 — `~/.claude/CLAUDE.md`.** Loaded automatically in every session, in
every directory. Holds only what is project-independent: the SDD workflow, the
branch and commit rules, ADR location and shape, the language convention, the
deviation rule, the test gate, and the review rule (section 4.7). Roughly 50
lines. This is the only layer that applies without anyone invoking anything,
which is why it carries the rules that must never depend on being remembered.

**Layer 2 — the standards plugin**, a git repository registered as a local
marketplace and enabled globally:

```
claude-standards/
  .claude-plugin/
    marketplace.json
    plugin.json
  skills/
    new-project/SKILL.md      # scaffold a project; argument: web | python
    sdd-change/SKILL.md       # proposal -> apply -> archive, with the gates
    adr/SKILL.md              # write an ADR
  templates/
    shared/config.rules.yaml  # the rules: blocks common to both profiles
    web/                      # config fragment, package.json, tsconfig,
                              # eslint, prettier, vitest, playwright, CLAUDE.md
    python/                   # pyproject.toml, CLAUDE.md
    adr/TEMPLATE.md
  hooks/
    hooks.json
    check-conformance.sh
    guard-change.sh
  docs/
    superpowers/specs/        # this document
    adr/                      # decisions about the standard itself
```

**Layer 3 — per project**: `openspec/` with a `config.yaml` written from the
profile template plus project-specific context, a thin `CLAUDE.md`, and
`docs/adr/`.

The profile is declared in `openspec/config.yaml` as a top-level key,
`profile: web` or `profile: python`, next to `schema:`. That key is what the
conformance hook reads; a project without it is reported as unprofiled rather
than guessed at.

### 4.6 Hooks warn; they do not block

| Hook | Matcher | Behaviour |
|---|---|---|
| `SessionStart` | — | Conformance report: is there an `openspec/`? a `CLAUDE.md`? a `docs/adr/`? does the toolchain match the declared profile? Reports; never aborts. |
| `PreToolUse` | `Edit`, `Write` | Source files only, defined by exclusion: everything except `openspec/`, `docs/`, `.claude/`, dotfiles and lockfiles. Runs `openspec list`; if no change is active, emits a reminder to write a proposal first. Does not deny. |
| `PreToolUse` | `Bash(git commit:*)` | Checks the message against Conventional Commits and the 72-character subject limit. Reports. |

Source files are identified by exclusion rather than by an allowlist of `src/`,
`app/` and `backend/`, because a flat layout keeps its modules at the repository
root. An allowlist would silently exempt exactly those projects — the ones with
the least structure, where the guard is worth the most.

Hard denial was rejected. It necessarily catches legitimate work — a typo in a
comment, a hotfix, repairing a broken build — and a guard that fires on
legitimate work gets switched off, at which point it protects nothing. A warning
that lands in the agent's context is reliable enough, because the agent reads it
and the human sees it.

### 4.7 Reviews are answered, not obeyed

- A review finding — from a human, a second AI, a linter, CI, `/code-review`,
  the `pr-review-toolkit` agents — ends in one of exactly two states: fixed, or
  rejected with a stated reason. Nothing is silently dropped.
- The spec and the ADRs outrank any reviewer.
- A disputed finding is settled with a test, not an argument.

The third rule is the reason to keep this at all: it converts disagreement into
evidence instead of discussion, and it means a reviewer being wrong costs one
test rather than an exchange of opinions.

## 5. What a conforming project looks like

```
<project>/
  openspec/
    config.yaml          # binding: product, non-negotiables, stack,
                         # vocabulary, rules for proposal/specs/design/tasks
    specs/<capability>/spec.md
    changes/<id>/        # proposal.md, tasks.md, design.md, specs/ deltas
    changes/archive/
  docs/
    adr/NNNN-title.md    # Context / Decisions / Consequences
  CLAUDE.md              # thin: orientation, commands, directories, pointer
```

## 6. Workflow

1. A unit of work starts as an OpenSpec change proposal, not as code.
2. The proposal is approved by the human before `tasks.md` is executed.
3. Architecture decisions inside the change become ADRs under `docs/adr/`.
4. Implementation runs on a branch `claude/<topic>`, branched from current
   `main`, one branch per unit of work, never reused. A reused branch makes it
   impossible to say which commits a given pull request contains.
5. Commits are conventional, focused, and made as work completes — not batched
   at the end.
6. Tests are green before the change is archived.
7. Review findings are handled per section 4.7.
8. Archiving folds the change's spec deltas into the capability specs.
9. A deviation from the spec is named and justified before it is built, never
   discovered afterwards in the diff.

## 7. Bootstrap order

1. Create the standards repository; commit this design.
2. Write `~/.claude/CLAUDE.md`.
3. Write the profile templates.
4. Build the plugin: `marketplace.json`, `plugin.json`, skills, hooks.
5. Register the marketplace locally and enable the plugin.
6. Verify the hooks against a throwaway project — confirm the conformance
   report fires, the source-edit reminder fires and does not block, and the
   commit check catches a malformed message.
7. Only then scaffold the first real project with `new-project`.

Step 6 is not optional. A hook that fails silently is worse than no hook,
because it is trusted.

## 8. Deferred

- Migration of existing projects, per section 3. Each gets its own decision;
  a project already using OpenSpec is the cheapest first candidate, and one
  with a large hand-maintained specification is the most expensive.
- Whether `new-project` should also initialise the remote and a CI workflow.
  Out of scope until the standard itself is proven.
