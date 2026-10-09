# ADR-0006: Effort starts at high

Status: accepted · Date: 2026-10-09 · Affects: `templates/global/settings.json`, `templates/<profile>/claude-settings.json`, `skills/verify/SKILL.md` step 2; supersedes ADR-0004 decision 4's `effortLevel: medium`

## Context

ADR-0004 set `effortLevel: medium` in the global settings as a token
lever. The human has now set the floor at `high`: no session, sub-agent
or verifier of this standard should reason at less than `high` by
default.

What that meant in practice, per the Claude Code model configuration
and settings reference (read 2026-10-09):

- Opus 5.5, Sonnet 5.5 and Haiku 5.5 default to `medium`; Fable 5.1,
  Opus 5, Sonnet 5 and Opus 4.8 default to `high`.
- A top-level `effortLevel` in the *user* settings file is the legacy
  form: Opus 5.5 and later models ignore it and start at their own
  default. They read a level saved per model under `modelSettings`.
- A top-level `effortLevel` in *project* settings applies to every
  model.
- A sub-agent without its own `effort` has no documented level of its
  own; the docs imply it runs at the session's level. A per-invocation
  `effort` on the Agent tool overrides that (Claude Code v2.1.292+).
- There is no minimum-effort key. `maxEffortLevel` and organization
  effort limits are caps, not floors.

So `medium` was what every 5.5 model ran at, through the template or
without it, and the old key changed nothing for them.

## Decisions

1. `high` is the default at every layer this standard writes:
   `effortLevel: high` in the global settings for Fable 5.1 and older
   models; `modelSettings` entries at `high` for the three pinned 5.5
   models, because the user-file top-level key does not reach them;
   `effortLevel: high` in each profile's project settings, which applies
   to every model in that project; and `effort: high` on the `verify`
   skill's verifier dispatch, so the one sub-agent the standard starts
   itself does not depend on inheritance the docs do not state.

   Rejected: `CLAUDE_CODE_EFFORT_LEVEL=high`. Rejected because it fixes
   the level instead of setting a floor: it outranks `/effort`, `--effort`
   and every skill or sub-agent `effort` field, so `xhigh` and `max`
   would be unreachable for exactly the work that needs them.

   Rejected: `maxEffortLevel`. It is a cap; it bounds the level from
   above and does nothing for the floor.

2. The floor is a default, not a lock. A human can still type
   `/effort low` for a session, and nothing in Claude Code can prevent
   that short of fixing the level as above. This standard trusts that
   choice when a human makes it; what it guarantees is that no session
   starts below `high` unasked.

3. The `modelSettings` keys are the same three IDs as the
   `ANTHROPIC_DEFAULT_<TIER>_MODEL` pins of ADR-0005, and the test suite
   asserts it, so a generation bump that forgets the effort entries
   fails the build.

## Consequences

- Every session, every sub-agent and the verifier start at `high` or
  above on the 5.5 models; Fable 5.1 sessions move from `medium` to
  `high`.
- Token spend rises against ADR-0004's baseline. That trade was the
  human's call; `docs/token-measurement.md` is how its size is read off
  the bill.
- Merging the global template into `~/.claude/settings.json` replaces a
  per-model level saved earlier with `/effort` for those three models.
- Verified against the test suite only; the level a running session
  actually uses is shown by `/effort` and, for sub-agents, by `/tasks`.
