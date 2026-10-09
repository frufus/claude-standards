# ADR-0005: Subagent models are pinned to the current generation

Status: accepted · Date: 2026-10-09 · Affects: `templates/global/settings.json`, `skills/verify/SKILL.md` step 2; amends ADR-0004 decision 4

## Context

ADR-0004 set `CLAUDE_CODE_SUBAGENT_MODEL=haiku`, and the `verify` skill
dispatches its verifier with `model: sonnet`. Both are aliases, and an
alias is only as current as the provider makes it. Per the Claude Code
model configuration page (read 2026-10-09):

| Provider | `opus` | `sonnet` | `haiku` |
| --- | --- | --- | --- |
| Anthropic API | Opus 5.5 | Sonnet 5.5 | Haiku 5.5 |
| Claude Platform on AWS | Opus 5.5 | Sonnet 4.6 | Haiku 4.5 |
| Amazon Bedrock, Google Cloud | Opus 5.5 | Sonnet 4.5 | Haiku 4.5 |
| Microsoft Foundry | Opus 4.6 | Sonnet 4.5 | Haiku 4.5 |

So the same standard put a subagent on Haiku 5.5 on one machine and on
Haiku 4.5 — a model a generation older, with a 200K context window
instead of 1M and ten times the per-token price — on another. The
verifier could land on Sonnet 4.5.

Two further constraints shape the fix. The Agent tool's per-invocation
`model` parameter takes aliases only (`sonnet`, `opus`, `haiku`,
`fable`), so the `verify` skill cannot name `claude-sonnet-5-5`
directly. And the documented way to pin what an alias means is the
`ANTHROPIC_DEFAULT_<TIER>_MODEL` variable.

## Decisions

1. `templates/global/settings.json` pins all three tier aliases to the
   current generation: `ANTHROPIC_DEFAULT_HAIKU_MODEL=claude-haiku-5-5`,
   `ANTHROPIC_DEFAULT_SONNET_MODEL=claude-sonnet-5-5`,
   `ANTHROPIC_DEFAULT_OPUS_MODEL=claude-opus-5-5`.
   `CLAUDE_CODE_SUBAGENT_MODEL` stays the alias `haiku`, and the
   verifier stays `model: sonnet`; the pins decide what those resolve
   to, on every provider.

   Rejected: relying on the aliases alone. Rejected because they track
   the newest model only on the Anthropic API; on four other providers
   they resolve to 4.5 or 4.6, and nothing in the session says so.

   Rejected: `CLAUDE_CODE_SUBAGENT_MODEL=claude-haiku-5-5` without the
   tier pins. Rejected because it fixes only the default and leaves the
   verifier's `sonnet` and any `opus` a session passes per invocation
   on the provider's older alias target.

2. All three pins name the same generation and are bumped together, by
   hand, when Anthropic ships the next one. The test suite asserts that
   the three IDs share one generation suffix, so a half-done bump fails
   the build.

   Rejected: leaving the pins out on the Anthropic API, where aliases
   already track the newest model. Rejected because a pin the standard
   ships everywhere is one fact to check; a pin that depends on the
   provider is a matrix nobody reads.

3. `CLAUDE_CODE_SUBAGENT_MODEL_FORCE` stays unset, as ADR-0004 decided.
   With it set, Claude Code ignores the per-invocation model, and the
   verifier would run on Haiku instead of Sonnet.

## Consequences

- General-purpose and custom subagents without their own `model` run on
  Claude Haiku 5.5, the verifier on Claude Sonnet 5.5, a per-invocation
  `opus` on Claude Opus 5.5 — on every provider.
- The built-in Explore and Plan subagents are not affected by
  `CLAUDE_CODE_SUBAGENT_MODEL`; they follow the main conversation's
  model, which is the newest one whenever the session runs on it.
- The pins also apply to the main conversation when it is switched to
  `/model sonnet`, `opus` or `haiku`, and `ANTHROPIC_DEFAULT_HAIKU_MODEL`
  covers Claude Code's background functionality. Both now run on the
  current generation too.
- The IDs are Anthropic API IDs, which Google Cloud accepts unchanged.
  On Amazon Bedrock or Microsoft Foundry, replace the three values with
  that provider's IDs for the same models; the decision is the
  generation, not the spelling.
- Staleness is the cost: when a newer generation ships, the pins hold
  sessions on 5.5 until someone bumps them. That is deliberate — a
  model change is a change to every session's behaviour and bill, and
  `docs/token-measurement.md` is how it is checked.
