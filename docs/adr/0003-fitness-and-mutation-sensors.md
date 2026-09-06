# ADR-0003: Fitness and mutation sensors

Status: accepted · Date: 2026-09-06 · Affects: `templates/web/scripts/verify`, `templates/python/scripts/verify`, `skills/new-project/SKILL.md` step 8

## Context

The 2026-09-01 design gestures at "architectural fitness functions" and
"mutation testing" without naming tools or bounds. Before either becomes
part of the shipped profile, the spec set three numbers a candidate must
clear: a config of 20 lines or fewer, expressing one clear rule; and, for
a mutation tool, a run of 5 minutes or less on a throwaway project. Two
fitness candidates and two mutation candidates were built and timed
against a deliberately small pair of throwaway projects — `sensor-web`
(Vite, Vue 3, TypeScript) and `sensor-py` (a plain venv) — each seeded
with one architectural violation the tool should catch and one weak test
that never exercises an empty-name branch, to see whether the tool
notices what the test suite misses. `uv` is not installed on this
machine, so the python spike used `python -m venv` and `pip` in place of
`uv venv` / `uv add`; the numbers below are pip's, not uv's, and are
recorded as such.

## Decisions

1. Adopt **dependency-cruiser** for the web profile's fitness step.
   `.dependency-cruiser.cjs` is 11 lines and expresses one rule
   (`components` must not import `repositories`). Install added 260
   packages in 10.8 seconds on top of the scaffolded project. `time npx
   depcruise src --config .dependency-cruiser.cjs` ran in 3.9 seconds and
   reported exactly the seeded violation, `src/components/view.ts ->
   src/repositories/load.ts`, exit 1, zero false positives and zero false
   negatives against the two clean files.

   Rejected: a hand-written ESLint boundary rule (e.g. a custom
   `no-restricted-imports` pattern per directory pair). Rejected because
   that logic has to be written and kept in sync in JavaScript, where
   dependency-cruiser expresses the same one rule as 11 lines of
   declarative data, comfortably under the 20-line bound, with no
   authored rule-matching code to maintain.

2. Adopt **Stryker** for the web profile's mutation step, gated behind
   `--deep`. `stryker.config.json` is 1 line. `time npx stryker run`
   completed in 10.0 seconds, well inside the 5-minute bound, against 4
   mutated source files (6 mutants). It killed 0, found 4 with no test
   coverage, and left 2 survivors — both on `greeting.ts`'s empty-name
   branch (the ternary's condition and its consequent), exactly the
   branch the seeded test never exercises. Exit code was 0: Stryker does
   not fail the run on survivors unless a break threshold is configured,
   so a survivor is a signal in the report, not (yet) a build failure.

   Rejected: running the mutation step inside the default `run`
   sequence. Rejected because mutation testing's cost scales with the
   codebase, not with the 4 files in this spike, and `test-scripts.sh`'s
   cheap-checks-first ordering exists precisely so a slow step never sits
   ahead of a fast one; `--deep` keeps the sensor available without
   taxing every invocation of `scripts/verify`.

3. Adopt **import-linter** for the python profile's fitness step.
   `pyproject.toml` carries its `[tool.importlinter]` table in 7 lines
   (10 lines counting the unrelated `[tool.mutmut]` table below it),
   expressing one contract: `app.domain` must not import `app.adapters`.
   Install (`pip install -q pytest import-linter mutmut`, all three
   together) took 18.6 seconds. `time lint-imports` with `PYTHONPATH=src`
   ran in 0.3 seconds and reported exactly the seeded contract break,
   `app.domain.bad -> app.adapters.cli`, exit 1.

   Rejected: a grep- or AST-based check in a pre-commit script. Rejected
   for the same reason as decision 1 — import-linter's contract is 7
   lines of declarative TOML under the 20-line bound, where a hand-rolled
   checker is code that has to be written, tested and maintained for one
   rule.

4. Defer **mutmut** for the python profile. `mutmut run` (version 3.7.0)
   does not execute on native Windows at all: it printed "To run mutmut
   on Windows, please use the WSL" and exited 1 after 0.2 seconds,
   without instrumenting a single mutant. The 5-minute bound was never
   reached because the tool never started.

   Rejected: adopting it and documenting WSL as a prerequisite. Rejected
   because that adds a second operating system to a toolchain that
   otherwise runs on the machine a python project is developed on
   (native Windows, via pip in this spike); the bound is about a run
   that finishes in 5 minutes, not one that needs a different OS to run
   at all. This decision is about the tool's platform support, not
   `uv` — record it separately from the pip note above; a future retrial
   under WSL, or of an alternative mutation tool with native Windows
   support, is what would overturn it.

## Consequences

- Both adopted fitness steps land in their profile's `scripts/verify`
  immediately after `typecheck`: `run fitness npx depcruise src
  --config .dependency-cruiser.cjs` (web) and `run fitness uv run
  lint-imports` (python) — cheap enough (3.9 s and 0.3 s here) that they
  cost little ahead of the unit step they now precede.
- Web's `scripts/verify --deep` adds a mutation step whose cost grows
  with the codebase; 10 seconds on 4 files here is not a projection for
  a real project, and the 5-minute bound should be re-measured there
  before `--deep` is relied on in CI.
- Python has no mutation sensor. A survivor on an untested branch — the
  exact failure mode this spike seeded — currently goes uncaught in
  python projects built on this profile until mutmut runs on Windows,
  WSL is adopted as a project dependency, or another candidate is
  trialed; this is a real gap against ADR-0002's asymmetric-cost
  reasoning, and it should be revisited rather than left implicit.
- The python install numbers above (18.6 seconds for three packages via
  pip) are not what `uv` would report; the profile's `scripts/verify`
  still invokes `uv run lint-imports`, so a project built on this
  profile needs `uv` regardless of what this spike used to measure it.
