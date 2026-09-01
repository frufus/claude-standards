# Cross-Project Development Standard — Design

Date: 2026-09-01 · Status: proposed · Scope: all projects under `C:\Users\frufus\development`

## 1. Context

Six projects live side by side under `development/`, and they disagree about
how work is specified and how it is built:

| Project | Stack | Spec mechanism |
|---|---|---|
| `Mtg-Commander-builder-` | Vue 3 + TS strict, Vite, Tailwind v4, Dexie, Comlink, Pinia, Zod | monolithic binding `docs/SPEC.md` (1130 lines) + `SPEC-EXT-01..06`, phases, `docs/CHANGELOG.md`, `docs/adr/` |
| `Palette-swap` | Vue 3 + TS, Vite, Pinia, culori | OpenSpec (`openspec/specs/<capability>/`, 31 archived changes) |
| `ink` | Vite + TS | none |
| `GraphRAG` | `app` + `backend`, docker-compose | none |
| `kraken_grid_bot` | Python, bare `main.py` + `requirements.txt` | none |
| `news_agent` | loose HTML | none |

`Mtg-Commander-builder-` is the reference for how work should be done. Its
strength is not its specification format but its **discipline**: binding
non-negotiables, ADRs for architecture decisions, one branch per unit of work,
conventional commits, green tests as a gate, and a rule that a deviation from
the spec is named and justified before it is built.

`Palette-swap` is the reference for the specification *mechanism*. Its
`openspec/config.yaml` already carries a product brief, non-negotiable
principles, a tech stack, a language convention, a sourcing rule and a domain
vocabulary — and the OpenSpec change flow (proposal, apply, archive) keeps the
specs alive instead of letting one large document drift.

This design combines the two and makes the result binding across all projects.

## 2. Goals

- One method for specifying and building work, in every project, regardless of language.
- Prescriptive tech stacks, so a new project does not re-litigate its toolchain.
- The standard is written down where it actually takes effect, not in a document nobody loads.
- Non-web projects get real requirements, not an exemption.

## 3. Non-goals

- Migrating the existing projects. The standard applies to new projects and new
  work; each existing migration is decided separately. Converting the
  1130-line `SPEC.md` into OpenSpec capability specs is a project of its own
  with real risk of losing binding detail.
- Mandating a second AI reviewer. `Mtg-Commander-builder-` routes pull requests
  through Gemini (`docs/ai-review.md`); that presumes a second vendor and is not
  part of the standard. How reviews are *answered* is part of it (section 4.7).
- Replacing what OpenSpec already does. No phase model, no separate CHANGELOG —
  see section 4.3.

## 4. Decisions

### 4.1 OpenSpec is the specification mechanism

`openspec` v1.11.0 is installed globally and proven in `Palette-swap` across 31
archived changes. Capability specs under `openspec/specs/<capability>/spec.md`
hold current truth; `openspec/changes/<id>/` holds proposals in flight;
archiving folds the deltas back into the specs.

The alternative — the monolithic `SPEC.md` of the reference project — was
rejected. It works there because it was written before the code and is actively
maintained, but it scales by growing, and a 1130-line binding document plus six
extension files is already at the edge of what stays consistent.

### 4.2 The OpenSpec config is the single source of project truth

The reference project keeps rules in two places, `CLAUDE.md` and `docs/SPEC.md`,
and therefore needs an explicit conflict rule ("if this file and the spec
conflict, the spec wins"). That is duplication management, not architecture.

Under this standard the project non-negotiables, tech stack, domain vocabulary
and language convention live in the `context:` block of `openspec/config.yaml`,
exactly as `Palette-swap` already does. The project `CLAUDE.md` becomes thin:
orientation, commands, directory map, and a pointer. No conflict rule is needed
because there is nothing to conflict with.

### 4.3 No phase model, no per-project CHANGELOG

`Mtg-Commander-builder-` tracks progress as phases in `SPEC` section 12, with
the current phase derived from the topmost entry in `docs/CHANGELOG.md`. The
OpenSpec change archive carries the same information — what was decided, what
was built, in what order — and maintaining both would be double bookkeeping
with two sources of truth about what is done.

Release notes for users, if a project ever needs them, are a different artifact
and are generated from commits, not maintained by hand.

### 4.4 Two stack profiles

Both profiles share the method: OpenSpec, ADRs, commit and branch discipline,
test gates, review handling. Only the toolchain differs.

**Profile `web`** — the intersection of what the two reference projects already
run, so it is proven rather than aspirational:

- Vue 3 with `<script setup>`, TypeScript strict, Vite
- Tailwind v4: design tokens only in `@theme`; no dynamically composed class
  names — state colours as explicit maps
- Pinia for ephemeral UI state only; persistent data goes through a repository layer
- vue-router; i18n (German and English) from the first UI change, no hardcoded
  user-facing strings
- Zod at every outside boundary (network, storage, imports, URL payloads)
- Vitest for units, Playwright for a thin end-to-end layer
- ESLint and Prettier, `vue-tsc` for typechecking
- Default posture: no backend, no secrets in the bundle, no external
  CDNs, fonts or analytics

**Profile `python`** — deliberately stricter than the current state of
`kraken_grid_bot`:

- `uv` for dependency and environment management, replacing `requirements.txt`
- `ruff` for both linting and formatting
- `mypy` in strict mode
- `pytest`
- `pydantic` at every outside boundary — the role Zod plays in the web profile
- A Dockerfile where the project is deployed

### 4.5 Three layers of anchoring

**Layer 1 — `~/.claude/CLAUDE.md`.** Loaded automatically in every session in
every directory. Holds only what is project-independent: the SDD workflow, the
commit and branch rules, ADR location and shape, the language convention, the
deviation rule, the test gate, and the review rule (section 4.7). Roughly 50
lines. It is the only mechanism that applies without anyone invoking anything.

**Layer 2 — plugin `frufus-standards`**, a git repository at
`C:\Users\frufus\development\claude-standards\`, registered as a local
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
| `PreToolUse` | `Edit`, `Write` | Source files only, defined by exclusion: everything except `openspec/`, `docs/`, `.claude/`, dotfiles and lockfiles. An exclusion list rather than an allowlist of `src/`, because a flat Python layout keeps its modules at the repository root and an allowlist would silently exempt the whole project. Runs `openspec list`; if no change is active, emits a reminder to write a proposal first. Does not deny. |
| `PreToolUse` | `Bash(git commit:*)` | Checks the message against Conventional Commits and the 72-character subject limit. Reports. |

Hard denial was rejected. It necessarily catches legitimate work — a typo in a
comment, a hotfix, repairing a broken build — and a guard that fires on
legitimate work gets switched off, at which point it protects nothing. A warning
that lands in the agent context is reliable enough, because the agent reads it
and the human sees it.

### 4.7 Reviews are answered, not obeyed

From `Mtg-Commander-builder-`, generalised away from any specific reviewer:

- A review finding — from a human, a second AI, a linter, CI, `/code-review`,
  the `pr-review-toolkit` agents — ends in one of exactly two states: fixed, or
  rejected with a stated reason. Nothing is silently dropped.
- The spec and the ADRs outrank any reviewer.
- A disputed finding is settled with a test, not an argument.

The third rule is the reason to keep this at all: it converts disagreement into
evidence instead of discussion.

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
   `main`, one branch per unit of work, never reused.
5. Commits are conventional, focused, and made as work completes — not batched
   at the end.
6. Tests are green before the change is archived.
7. Review findings are handled per section 4.7.
8. Archiving folds the spec deltas of the change into the capability specs.

## 7. Bootstrap order

1. Create `claude-standards` as a git repository; commit this design.
2. Write `~/.claude/CLAUDE.md`.
3. Distil the templates from `Mtg-Commander-builder-` and `Palette-swap`.
4. Build the plugin: `marketplace.json`, `plugin.json`, skills, hooks.
5. Register the marketplace locally and enable the plugin.
6. Verify the hooks against a throwaway project — confirm the conformance
   report fires, the source-edit reminder fires and does not block, and the
   commit check catches a malformed message.
7. Only then scaffold the first real project with `new-project`.

## 8. Deferred

- Migration of `Mtg-Commander-builder-` from `SPEC.md` to OpenSpec capability
  specs. Decided separately, per section 3.
- Migration of `ink`, `GraphRAG`, `kraken_grid_bot`, `news_agent`. Each gets its
  own decision; `Palette-swap` is already close to conforming and is the
  cheapest first candidate.
- Whether `new-project` should also initialise the GitHub remote and CI
  workflow. Out of scope until the standard itself is proven.
