# AGENTS.md

<one or two sentences: what this project is, for whom>

**The binding project truth is `openspec/config.yaml`.** Product, non-negotiables,
tech stack and domain vocabulary live in its `context:` block. Current
requirements are the capability specs under `openspec/specs/`; anything under
`openspec/changes/` is proposed, not built. A unit of work starts as a change
proposal there and is approved before it is implemented.

## Commands

```
scripts/verify     # lint, format check, typecheck, unit — the whole check, in order
scripts/dev        # the entry point (no long-running process by default)
uv sync            # install dependencies
uv run pytest      # tests only
uv run ruff check  # lint only
uv run mypy .      # typecheck only, strict
```

## Directories

```
scripts/           Deterministic steps: dev, verify
src/               Application code
openspec/          Binding specs and change proposals
docs/adr/          Architecture decisions
tests/             Tests
```

## Boundaries

- Always: run `scripts/verify` before calling a change done; commit as each
  task completes; answer every review finding as fixed or rejected with a
  stated reason.
- Ask: before deviating from the spec, before merging, before anything
  destructive or hard to reverse.
- Never: delete, skip or weaken a test to make a check pass; add a
  dependency outside `pyproject.toml`; commit a secret.
