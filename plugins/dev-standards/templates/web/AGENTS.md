# AGENTS.md

<one or two sentences: what this project is, for whom>

**The binding project truth is `openspec/config.yaml`.** Product, non-negotiables,
tech stack and domain vocabulary live in its `context:` block. Current
requirements are the capability specs under `openspec/specs/`; anything under
`openspec/changes/` is proposed, not built. A unit of work starts as a change
proposal there and is approved before it is implemented.

## Commands

```
scripts/verify     # lint, typecheck, unit, e2e — the whole check, in order
scripts/dev        # dev server up (idempotent, prints the URL); `down` stops it
npm run test       # Vitest only
npm run lint       # ESLint only
npm run typecheck  # vue-tsc only
npm run format     # Prettier
```

## Directories

```
scripts/           Deterministic steps: dev up/down, verify
src/               Application code
openspec/          Binding specs and change proposals
docs/adr/          Architecture decisions
tests/             Unit tests
e2e/               Playwright specs
```

## Boundaries

- Always: run `scripts/verify` before calling a change done; commit as each
  task completes; answer every review finding as fixed or rejected with a
  stated reason.
- Ask: before deviating from the spec, before merging, before anything
  destructive or hard to reverse.
- Never: delete, skip or weaken a test to make a check pass; declare a
  colour, control height, radius or focus ring the design system already
  defines; put a secret in the bundle.
