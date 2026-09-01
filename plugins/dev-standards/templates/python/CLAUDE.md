# CLAUDE.md

<one or two sentences: what this project is, for whom>

**The binding project truth is `openspec/config.yaml`.** Product, non-negotiables,
tech stack and domain vocabulary live in its `context:` block. Current
requirements are the capability specs under `openspec/specs/`; anything under
`openspec/changes/` is proposed, not built.

## Commands

```
uv sync            # install dependencies
uv run pytest      # tests
uv run ruff check  # lint
uv run ruff format # format
uv run mypy .      # typecheck, strict
```

## Directories

```
src/               Application code
openspec/          Binding specs and change proposals
docs/adr/          Architecture decisions
tests/             Tests
```
