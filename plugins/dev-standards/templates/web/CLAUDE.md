# CLAUDE.md

<one or two sentences: what this project is, for whom>

**The binding project truth is `openspec/config.yaml`.** Product, non-negotiables,
tech stack and domain vocabulary live in its `context:` block. Current
requirements are the capability specs under `openspec/specs/`; anything under
`openspec/changes/` is proposed, not built.

## Commands

```
scripts/verify     # lint, typecheck, unit, e2e — the whole check, in order
scripts/dev        # dev server up (idempotent, prints the URL); `down` stops it
npm run test       # Vitest only
npm run lint       # ESLint only
npm run typecheck  # vue-tsc only
npm run format     # Prettier
```

## Design system

The interface is built on `@frufus/design-system`: tokens, primitives and the
two stylesheets it documents. Do not redeclare a colour, a control height, a
radius or a focus ring — take them from it. New components go through the
`component` skill, which decides whether they belong here or there.

## Directories

```
scripts/           Deterministic steps: dev up/down, verify
src/               Application code
openspec/          Binding specs and change proposals
docs/adr/          Architecture decisions
tests/             Unit and end-to-end tests
```
