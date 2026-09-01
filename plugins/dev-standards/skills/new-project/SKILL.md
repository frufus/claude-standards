---
name: new-project
description: Scaffold a new project onto the development standard. Takes one argument, web or python. Use when starting any new project, or when bringing an existing one onto the standard.
---

# Scaffolding a project

Argument: `web` or `python`. If it is missing, ask — do not infer the
profile from files that happen to be present, because the answer decides
the toolchain for the life of the project.

## Process

1. **Confirm the target directory** and that it is a git repository. If it
   is not, `git init` and say so.

2. **Initialise OpenSpec**: `openspec init --tools claude`.

3. **Write `openspec/config.yaml`** by assembling, in this order:
   - `${CLAUDE_PLUGIN_ROOT}/templates/<profile>/config.fragment.yaml` —
     the `schema:` and `profile:` keys. The `profile:` key is what the
     conformance hook reads; without it the project reports as unprofiled.
   - a `context:` block you write with the human: what the product is, its
     non-negotiable principles, the tech stack from the profile below, the
     language convention, and the domain vocabulary. This block is the
     binding project truth — everything a session must not get wrong
     belongs here and nowhere else.
   - `${CLAUDE_PLUGIN_ROOT}/templates/shared/config.rules.yaml` verbatim.

4. **Write `CLAUDE.md`** from
   `${CLAUDE_PLUGIN_ROOT}/templates/<profile>/CLAUDE.md`, filling the
   one-line description. Keep it thin: orientation, commands, directories.
   Rules belong in `openspec/config.yaml`, never in both.

5. **Create `docs/adr/`** with a `.gitkeep`.

6. **Install the toolchain** for the profile.

7. **Verify**: run the project's test command and its linter. Both must
   run — an empty suite that runs is fine, a suite that cannot run is not.

8. **Confirm conformance**: the SessionStart conformance hook must report
   nothing for this project. Start a session in it, or run
   `bash "${CLAUDE_PLUGIN_ROOT}/hooks/check-conformance.sh"` with
   `{"cwd":"<project>"}` on stdin and confirm the output is empty.

## Profile `web`

Vue 3 with `<script setup>`, TypeScript strict, Vite. Tailwind v4 with
design tokens only in `@theme` and no dynamically composed class names —
state colours as explicit maps, so every class the build sees is greppable.
Pinia for ephemeral UI state only; persistent data goes through a
repository layer. vue-router. i18n from the first UI change, with no
hardcoded user-facing strings. Vitest for units, Playwright for a thin
end-to-end layer. ESLint and Prettier. `vue-tsc` for typechecking.
Default posture: no backend, no secrets in the bundle, no external CDNs,
fonts or analytics.

## Profile `python`

`uv` for dependencies and environments. `ruff` for both linting and
formatting. `mypy` in strict mode. `pytest`. A Dockerfile where the
project is deployed.

## The rule above both profiles

Data entering the process is parsed into a known shape at the boundary —
network, storage, imports, URL payloads — before anything else touches it.
Which library does that is this project's decision; record it in
`openspec/config.yaml`. That something does it is not optional.
