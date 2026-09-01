---
name: component
description: Decide where a new UI component belongs and build it there. Use when a project needs a component that does not exist yet, or when a local component starts looking like it should be shared.
---

# Adding a component

Most of the cost of a component is not writing it. It is that the second
project writes it again, slightly differently, and now two things claim to be
the same control.

So the first question is never how to build it. It is where it belongs.

## 1. Ask what it knows

- **Does it name anything from the product's domain** — a paint, an order, a
  deck? Then it belongs to the project. A component that knows what a thing
  *is* cannot be shared with a project where that thing does not exist.
- **Would an unrelated project want it unchanged?** Then it belongs in the
  design system.
- **Does it hold state that outlives the screen?** Then it is not a component.
  That is a store or a repository with markup attached.

When the answers disagree, it is usually two things: a generic primitive and a
thin domain wrapper around it. Split them and each answer becomes obvious.

## 2. If it belongs to the project

Build it in `src/components/`, composed from design-system primitives.

It declares no colour, no control height, no radius and no focus ring of its
own. Those exist and are measured; redeclaring one is how a project drifts from
the system while still importing it.

Needing a value that does not exist is the signal for step 4 — not permission to
invent one locally.

## 3. If it belongs to the design system

It goes through that repository's own change workflow, and being "just a
component" shortens none of it:

1. A proposal, with a Non-Goals subsection naming what it deliberately does not
   do.
2. A capability spec written as observable behaviour, including the unhappy
   path — what it does with no data, bad data, or a value outside its options.
3. A design note naming the alternatives you rejected and why. If you cannot
   name one, you have not made a decision yet.
4. Tests first, then the component. Accessibility asserted rather than assumed,
   and asserted in both appearances.
5. A story per state, so the catalog documents it.
6. An ADR if it sets a pattern the next component will copy.

**Use the platform before reimplementing it.** A native element that already
does the work — its keyboard behaviour, its focus handling, its announcements —
is worth more than a styled reimplementation of it. Where a pattern must be
implemented by hand, say so in the design note and take on the whole cost: every
key, every state, specified and tested.

## 4. The rule of two

Do not promote a component the first time it is needed. One example is not
enough to see the general case, and a shared component built from a guess is
worse than two local ones.

Write it locally. When a second, different project needs the same thing, propose
it then — with both call sites as the evidence for its shape.

**The exception is anything carrying accessibility behaviour**: a dialog, a
combobox, a menu, anything with a focus trap or a keyboard pattern. Those are
worth sharing on first sight, because the cost of getting them wrong twice is
paid by the people who can least afford it.

## 5. Names are the contract

A component's name and its prop names are a breaking change for every consumer
the moment it ships. Settle them in the proposal, where changing one costs a
sentence — not in review, where it costs a rewrite.

## What is not a new component

- **A variant of an existing one.** Add an entry to its map instead.
- **A layout.** Where things sit on a screen is the project's decision.
- **A wrapper that only sets props.** That is a default, or a function.
- **A one-off.** Used once, in one place, with no second caller in prospect:
  leave it inline until it has earned a name.
