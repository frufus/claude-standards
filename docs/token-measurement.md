# Measuring tokens

The number that matters is the paired bill: the same tasks, with and
without a change, measured on what the API charged — not what a tool
reports it saved. JetBrains' rtk benchmark (Claude Code 2.1.201, Sonnet 5,
86 SkillsBench tasks) is the worked example: the tool reported 60–90 %
savings, the theoretical ceiling was about 3 % of input tokens, and the
bill went up 7.6 % at low effort (p = 0.004). ADR-0004 records what this
repository adopted instead and why.

## In a session

`/usage` — tokens by model, cache share, cost at list price. The status
line (`templates/global/statusline.js`, installed per the README) shows
context use continuously; `/context` shows what is filling it.

## Locally, across sessions (pilot)

Both read `~/.claude/projects/` and send nothing anywhere:

    npx ccusage@20.0.20 daily          # tokens and cost per day
    npx ccusage@20.0.20 session        # per session
    npx codeburn@0.9.24                # per task type, per project

Pilot protocol: two weeks baseline before a change, two weeks after, same
people, same projects; compare `ccusage daily` totals and the
`cache read` share. A change that does not move the paired bill is
reverted, whatever its own dashboard says.

## Rollout: OpenTelemetry

For the whole team, export metrics from every machine. The env block goes
into `managed-settings.json` (organisation scope); the endpoint is per
organisation and is not committed here:

    {
      "env": {
        "CLAUDE_CODE_ENABLE_TELEMETRY": "1",
        "OTEL_METRICS_EXPORTER": "otlp",
        "OTEL_LOGS_EXPORTER": "otlp",
        "OTEL_EXPORTER_OTLP_PROTOCOL": "grpc",
        "OTEL_EXPORTER_OTLP_ENDPOINT": "http://collector.example.com:4317",
        "OTEL_EXPORTER_OTLP_HEADERS": "Authorization=Bearer <token>"
      }
    }

Metrics to chart: `claude_code.token.usage` (attributes `type` =
input | output | cacheRead | cacheCreation, `model`) and
`claude_code.cost.usage`. Leave `OTEL_LOG_USER_PROMPTS` unset.

## Not a standard

Proxies (Headroom), routers (claude-code-router), Bash-output compressors
(rtk) and tokenwar are not part of the standard. tokenwar may be run once,
by hand, as an audit — it is not installed, not hooked, not in any
settings file. rtk's expected ceiling is the ~3 % above, with `Read` and
`Grep` untouched; the test-output hook in this plugin covers the same
channel for the commands this stack actually runs.
