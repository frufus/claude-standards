@AGENTS.md

# Claude-specific notes

Everything tool-agnostic — what this project is, the commands, the
directories, the boundaries — is in `AGENTS.md`, imported above. Rules live
in `openspec/config.yaml`, never here.

## Design system

The interface is built on `@frufus/design-system`: tokens, primitives and the
two stylesheets it documents. Do not redeclare a colour, a control height, a
radius or a focus ring — take them from it. New components go through the
`component` skill, which decides whether they belong here or there.
