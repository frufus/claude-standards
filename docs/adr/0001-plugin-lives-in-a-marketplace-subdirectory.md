# ADR-0001: Plugin lives in a marketplace subdirectory

Status: accepted · Date: 2026-09-01 · Affects: repository layout

## Context

The spec for this repository sketched a single `.claude-plugin/` directory at
the repository root, holding both `marketplace.json` and `plugin.json` — the
repository would be, at once, the marketplace and the one plugin it lists.

Before adopting that, the layout of an installed, production marketplace was
checked: the official Anthropic marketplace, already registered in this
environment. It lists 53 plugins. All 53 of their `source` entries are
relative paths of the form `"source": "./plugins/<name>"` — every plugin
lives in a subdirectory under the marketplace root, and the marketplace root
itself holds no plugin manifest of its own. Zero of the 53 use the
root-doubles-as-a-plugin shape the spec sketched.

## Decisions

1. The plugin lives in `plugins/dev-standards/`, with its own
   `.claude-plugin/plugin.json`, `hooks/`, and templates beneath it. The
   repository root holds only `.claude-plugin/marketplace.json`, listing
   `dev-standards` with `"source": "./plugins/dev-standards"`.

   Rejected: the spec's original root layout, where the repository root
   itself is both marketplace and plugin (one `.claude-plugin/` at the top
   holding both `marketplace.json` and `plugin.json`). Rejected because every
   one of the 53 relative-source entries in the installed official
   marketplace uses the `./plugins/<name>` subdirectory shape, and no
   evidence was found of a marketplace that is simultaneously its own single
   plugin. The first thing this standard does inside a user's environment
   should not be an unproven layout — it should match the shape every
   existing plugin in that environment already uses.

## Consequences

- Adding a second plugin to this repository later costs nothing: it is
  another sibling directory under `plugins/`, listed as another entry in the
  existing `marketplace.json`. The root-as-plugin layout would have required
  a restructuring to add one.
- The paths shown in the spec's section 4.5 directory tree are one level
  deeper than written there: anything the spec placed directly under
  `.claude-plugin/` at the repository root instead lives under
  `plugins/dev-standards/`.
