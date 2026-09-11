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

4. **Write `AGENTS.md` and `CLAUDE.md`** from
   `${CLAUDE_PLUGIN_ROOT}/templates/<profile>/AGENTS.md` and
   `${CLAUDE_PLUGIN_ROOT}/templates/<profile>/CLAUDE.md`, filling the
   one-line description in `AGENTS.md`. `AGENTS.md` is what Codex, Cursor,
   Copilot and every other agent read; `CLAUDE.md` begins with `@AGENTS.md`
   so Claude Code reads the same file, and holds only what is
   Claude-specific. Keep both thin: orientation, commands, directories,
   boundaries. Rules belong in `openspec/config.yaml`, never in either.

5. **Create `docs/adr/`** with a `.gitkeep`.

6. **Write `scripts/`** from `${CLAUDE_PLUGIN_ROOT}/templates/<profile>/scripts/`:
   copy `dev` and `verify` verbatim, then `chmod +x scripts/dev scripts/verify`,
   `git add scripts/dev scripts/verify` and
   `git update-index --chmod=+x scripts/dev scripts/verify` — the index
   entry must exist before its mode can be set, and git on Windows does
   not record the mode from the filesystem. Write a
   `.gitattributes` in the project root containing `scripts/* text eol=lf`
   and `*.sh text eol=lf` — Git for Windows checks text out with CRLF by
   default, and bash refuses a script whose shebang ends in a carriage
   return. On `python`,
   replace `<package>` in `scripts/dev` with the real entry point. Add
   `.dev.pid` and `.dev.log` to `.gitignore`; the web `dev` script writes
   them. These two scripts are the deterministic steps of every change:
   `scripts/dev` brings the application up idempotently and prints where,
   `scripts/verify` runs lint, typecheck, the fitness check, units and
   end-to-end in that order (`--deep` adds mutation testing on `web`) and
   exits non-zero at the first failure. The `verify` skill
   runs both; a session never composes those steps by hand.

7. **Write `.github/pull_request_template.md`** from
   `${CLAUDE_PLUGIN_ROOT}/templates/shared/pull_request_template.md`,
   verbatim. It asks for intent, the change id, the verification report,
   proof, which parts were agent-written and their risk tier, and where
   human attention is wanted — so what reaches a reviewer does not depend
   on the session that opened the pull request.

8. **Install the toolchain** for the profile. On `web` this includes
   `@frufus/design-system`, wired with the four CSS lines it documents,
   unless the ADR described under that profile says otherwise. Set
   `reuseExistingServer: true` in `playwright.config.ts` so Playwright
   and `scripts/dev` agree about the server. Configure Vitest with
   `exclude: [...configDefaults.exclude, "e2e/**"]` in `vite.config.ts`
   (import `defineConfig` and `configDefaults` from `vitest/config`), so
   the Playwright specs are run by the e2e step only.

   Then install the sensors ADR-0003 adopted, so `scripts/verify`'s
   `fitness` and `--deep` mutation steps have something to run. On `web`:
   `npm install -D dependency-cruiser @stryker-mutator/core
   @stryker-mutator/vitest-runner`, then copy
   `${CLAUDE_PLUGIN_ROOT}/templates/web/.dependency-cruiser.cjs` and
   `${CLAUDE_PLUGIN_ROOT}/templates/web/stryker.config.json` verbatim into
   the project root. Pin TypeScript with `npm install -D typescript@^6`:
   dependency-cruiser cruises no TypeScript modules at all on 7, and the
   `fitness` step would then pass while proving nothing (ADR-0003). On
   `python`, add `import-linter` to the dev dependencies and append
   `${CLAUDE_PLUGIN_ROOT}/templates/python/importlinter.fragment.toml` to
   `pyproject.toml`, replacing `<package>` with the real package name;
   python has no mutation step yet (ADR-0003).

   Install the language server the code-intelligence plugin drives: on
   `web` `npm install -D typescript-language-server`, on `python`
   `uv add --dev pyright`. Then copy
   `${CLAUDE_PLUGIN_ROOT}/templates/<profile>/claude-settings.json` to
   `.claude/settings.json` and read it before committing: it enables
   `dev-standards` and `typescript-lsp` (web) or `pyright-lsp` (python)
   for every clone. A symbol lookup there replaces a grep and the file
   reads that follow it (ADR-0004).

9. **Install the code graph.** `uv tool install graphifyy==0.9.58` (pin;
   bump deliberately), then in the project root
   `graphify install --project --strict` — writes
   `.claude/skills/graphify/SKILL.md` and the read-redirect hook into
   `.claude/settings.json`; read both before committing them — and
   `graphify hook install` for the post-commit rebuild. Build it once with
   `/graphify .` and commit `graphify-out/graph.json` and
   `graphify-out/GRAPH_REPORT.md`, so the graph exists on every checkout
   and the strict hook has something to redirect to. Add to `.gitignore`:
   `graphify-out/cache/`, `graphify-out/graph.html`, `graphify-out/obsidian/`,
   `graphify-out/wiki/` (ADR-0004).

10. **Verify**: run `scripts/verify`. It must run to the end — an empty
    suite that runs is fine, a suite that cannot run is not.

11. **Confirm conformance**: the SessionStart conformance hook must report
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
`dependency-cruiser` for the architecture-fitness step and Stryker (with
`@stryker-mutator/vitest-runner`) for the `--deep` mutation step, on
`typescript@^6` (ADR-0003). Default posture: no backend, no secrets in the bundle, no external CDNs,
fonts or analytics.

**The user interface is built on `@frufus/design-system`.** Install it and
wire it with the four lines it documents; take colour, type, spacing and
the primitives from it rather than declaring them again. A project that
redeclares a colour or a control height has drifted from the system while
still importing it.

To go without it, write an ADR whose filename contains `design-system`
saying why. That is the whole opt-out — but it is an argument, made once,
in writing, rather than a decision that happens by nobody installing
anything. The conformance hook reports a `web` project that has neither
the dependency nor the ADR.

Adding a component to either side is the `component` skill's subject: it
decides where the component belongs before anything is built.

## Profile `python`

`uv` for dependencies and environments. `ruff` for both linting and
formatting. `mypy` in strict mode. `pytest`. `import-linter` for the
architecture-fitness step, contracts in `pyproject.toml`; no mutation
sensor yet (ADR-0003). A Dockerfile where the project is deployed.

## The rule above both profiles

Data entering the process is parsed into a known shape at the boundary —
network, storage, imports, URL payloads — before anything else touches it.
Which library does that is this project's decision; record it in
`openspec/config.yaml`. That something does it is not optional.
