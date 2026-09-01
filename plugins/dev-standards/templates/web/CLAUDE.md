# CLAUDE.md

<one or two sentences: what this project is, for whom>

**The binding project truth is `openspec/config.yaml`.** Product, non-negotiables,
tech stack and domain vocabulary live in its `context:` block. Current
requirements are the capability specs under `openspec/specs/`; anything under
`openspec/changes/` is proposed, not built.

## Commands

```
npm run dev        # Vite dev server
npm run test       # Vitest
npm run test:e2e   # Playwright
npm run lint       # ESLint
npm run typecheck  # vue-tsc
npm run format     # Prettier
```

## Directories

```
src/               Application code
openspec/          Binding specs and change proposals
docs/adr/          Architecture decisions
tests/             Unit and end-to-end tests
```
