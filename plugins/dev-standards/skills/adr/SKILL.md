---
name: adr
description: Write an architecture decision record. Use when a change makes a choice that outlives it — a format, a boundary, a dependency, a data model — or when a spec's open question must be settled before work can continue.
---

# Writing an ADR

An ADR exists so the decision can be re-evaluated later by someone who was
not there. That means it must record what was rejected, not only what was
chosen: a decision without its alternatives cannot be revisited when the
constraint that drove it changes.

## Process

1. Read `${CLAUDE_PLUGIN_ROOT}/templates/adr/TEMPLATE.md`.
2. Find the next number: `ls docs/adr/ | sort | tail -n 1`. Numbers are
   four digits and never reused, including for superseded records.
3. Write `docs/adr/NNNN-kebab-title.md` from the template.
4. State the numbers that make the decision hard — sizes, limits, rates,
   measured timings. A decision recorded without them reads as a
   preference a year later.
5. For every decision, name the alternative you rejected and why. If you
   cannot name one, you have recorded a fact, not a decision — either find
   the alternative or leave it out of the ADR.
6. Link the ADR from the change that produced it.

## What is not an ADR

A choice the spec already binds, a library version bump, a naming
preference, or anything you would not defend in six months. ADRs that
record trivia make the ones that matter unfindable.
