---
name: verify
description: Verify a change in a fresh sub-agent against the spec's scenarios and leave proof in the change directory. Use at step 7 of sdd-change, and before any pull request or archive.
---

# Verifying a change

The session that wrote the code holds a theory of why the code is right,
and checks it against that theory. The scenarios it fails to drive are the
ones the theory says cannot fail. So verification is done by a
**fresh sub-agent** that gets the scenarios and the scripts — not the diff,
not the conversation, not `tasks.md`. Fresh context is the whole mechanism.

## Process

1. **Find the change.** `openspec list --json`; the change in flight is
   the one being worked on. Note its id and read
   `openspec/changes/<id>/specs/` — every scenario in every delta,
   happy and unhappy.
2. **Dispatch the verifier** with the Agent tool (`general-purpose`,
   `model: sonnet` — the per-invocation model outranks
   `CLAUDE_CODE_SUBAGENT_MODEL`, so the verifier is not downgraded to
   the exploration default), using the brief below verbatim with the
   placeholders filled. Give it nothing else.
3. **Read `openspec/changes/<id>/verification.md`** when it returns.
4. **Answer every finding.** Each `fail` and `not verifiable` is a review
   finding: fix it, or reject it with a stated reason. Write the answer
   as an `Answer:` line under the verdict it answers. A fix is named by
   its commit subject; a rejection states why. Nothing is left without
   one.
5. **Append to `progress.md`**: `- <date> — verified: <n> pass, <m> fail,
   <k> not verifiable; all answered`.

Do not archive and do not open a pull request while a finding has no
`Answer:`. The ship-check hook reminds if you try.

## The brief

```
You are verifying change `<id>` in <project root>. You have not seen the
implementation and you will not be shown it. Your job is to find out
whether the application does what the scenarios say, and to leave proof.

Project context (from openspec/config.yaml):
<the context: block, verbatim>

Scenarios to verify — every one, including the unhappy paths:
<the contents of openspec/changes/<id>/specs/, verbatim>

Tools:
- `openspec validate <id> --strict` checks the change's own artefacts. Run it
  first. A non-zero exit is a finding.
- `scripts/verify` runs lint, typecheck, unit and end-to-end checks in
  order and exits non-zero at the first failure. Run it next. A failure
  is a finding; continue to the scenarios unless nothing can run.
- `scripts/dev` brings the application up and prints its URL (or entry
  point) on the last line. It is idempotent. Run `scripts/dev down` when
  you are done if you started it.
- For a web project drive the URL with a browser (playwright-core is
  available; Chrome is at the path the project documents) and save a
  screenshot per scenario under openspec/changes/<id>/proof/<scenario>.png.
- For a python project call the entry point and capture the command and
  its output.

For each scenario record exactly one verdict:
- pass — you drove it and observed the specified behaviour;
- fail — you drove it and observed something else (say what);
- not verifiable — you could not drive it (say why: missing tool,
  missing data, ambiguous scenario).

Write openspec/changes/<id>/verification.md in this shape and nothing else:

# Verification: <id>

Verified: <date> by a fresh sub-agent
scripts/verify: exit <status>

## Scenarios

### <scenario name> — pass
Proof: openspec/changes/<id>/proof/<file>.png

### <scenario name> — fail
Proof: openspec/changes/<id>/proof/<file>.png
Finding: <what you observed instead>

### <scenario name> — not verifiable
Finding: <why>

Do not write an Answer: line — that is the implementer's job. Do not
edit source. Report the path of the file you wrote and stop.
```

## What is not verification

Reading the diff and agreeing with it. Running the unit suite alone.
Marking a scenario `pass` because the code for it exists. A verdict
without proof is an opinion; the point of this skill is that the change
directory holds evidence someone who cannot read the code can check.
