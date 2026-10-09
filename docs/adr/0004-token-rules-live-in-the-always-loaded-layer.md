# ADR-0004: Token rules live in the always-loaded layer

Status: accepted; decision 4 amended by ADR-0005 (subagent models pinned to the current generation) and ADR-0006 (effort starts at high, replacing `medium`) · Date: 2026-09-11 · Affects: `templates/global/CLAUDE.md` and its 60-line budget (spec 2026-09-06 §4.2), `templates/global/settings.json`, `hooks/filter-test-output.sh`, `skills/new-project/SKILL.md` steps 8–9

## Context

The token audit (`docs/audit-token-reduction.md`, 2026-09-10) found that
the plugin ships no settings layer at all — no `env`, no effort default,
no status line, no code-intelligence plugin — and that four behaviour
rules (edit in place, explore through a language server or graph first,
agent teams only on request, what survives a compaction) had no home.
The always-loaded layer stood at 59 of the 60 lines spec 2026-09-06 §4.2
budgeted and said would not be raised. Two third-party tools were on the
table: rtk, a Bash-output compressor shipped as a plugin, and graphify, a
code graph with its own installer.

## Decisions

1. The four behaviour rules go into `templates/global/CLAUDE.md`, and
   the budget rises from 60 to 70 lines (the file lands at 68). The
   budget exists because every line is paid in every session; a rule
   that saves tokens in every session is the one kind of line that
   earns its place there.

   Rejected: the per-profile `CLAUDE.md` files (26 and 33 lines of
   headroom). Rejected because they load only in profiled projects,
   and the rules apply wherever a session runs — the same argument that
   put the test ratchet in the global layer (spec 2026-09-06 §4.2).

   Rejected: a skill. Skills load on invocation; a rule about how to
   explore or how to answer must be present before anything is invoked.

2. Test-runner output is shortened by a hook in this plugin
   (`filter-test-output.sh`), built on the shared tokeniser, rewriting
   only a bare `vitest`/`pytest`/`scripts/verify` invocation with no
   operator or redirection, preserving the runner's exit status.

   Rejected: rtk via `enixCode/rtk-plugin` (v0.1.2). Rejected on
   JetBrains' paired measurement — a theoretical ceiling of about 3 %
   of input tokens, a measured +7.6 % cost at low effort (p = 0.004)
   and +0.1 % at high, because `Read`/`Grep` bypass the Bash hook and
   about half of Bash calls carry pipes or heredocs it will not touch —
   and because its `SessionStart` hook downloads a ~5 MB binary with no
   documented checksum, which the README's hook-review rule forbids.

3. graphify enters through `new-project` step 9 and a conformance
   report, pinned by PyPI version (`graphifyy==0.9.58`), with
   `graphify-out/graph.json` and `GRAPH_REPORT.md` committed and only
   `cache/`, `graph.html`, `obsidian/`, `wiki/` ignored.

   Rejected: wrapping graphify as a marketplace plugin. Rejected because
   graphify ships its own skill, hook and installer and moved from
   0.9.28 to 0.9.58 in six weeks; a copy in this repository would be a
   second truth that drifts.

   Rejected: ignoring `graphify-out/` entirely. Rejected because strict
   mode redirects the first raw read of a session to the graph, which
   on a fresh clone would not exist and would be rebuilt by every
   developer, with model tokens, to the same result.

4. The settings that Claude Code reads from `~/.claude/` —
   `CLAUDE_CODE_SUBAGENT_MODEL=haiku`, `effortLevel: medium`, the status
   line — ship as `templates/global/settings.json` and are installed by
   hand next to the global `CLAUDE.md`, because a plugin's own
   `settings.json` may carry only `agent` and `subagentStatusLine`.

   Rejected: `CLAUDE_CODE_SUBAGENT_MODEL_FORCE=1`. It would drag the
   `verify` skill's verifier onto haiku; the skill now names its model
   per invocation instead.

## Consequences

- `tests/test-global-claude-md.sh` budgets 70 lines and asserts the four
  rules; the global file is at 68.
- A sixth hook; the README's "five hooks" becomes six, and the
  hook-review section applies to it like to any other.
- `new-project` writes `.claude/settings.json` from the profile template,
  enabling the plugin and the language-server plugin for every clone.
- The measurement protocol in `docs/token-measurement.md` is the check
  on all of this: a change that does not move the paired bill within a
  pilot is reverted, whatever its own numbers say.
