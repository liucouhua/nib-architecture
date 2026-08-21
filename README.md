# Nowcast-in-a-Box architecture

Working technical design for [Nowcast-in-a-Box](https://github.com/Nowcast-in-a-Box): how data packages and model packages meet, and who owns each module.

This repository is the review and ownership surface. Prototype code stays out until this design is accepted.

## Start here

1. [rfc/matching.md](rfc/matching.md) — task profiles and the Matcher (no universal tensor)
2. [modules.yaml](modules.yaml) — roster (ids, roles, owners)
3. [diagrams/](diagrams/) — editable draw.io files

| Role | Meaning |
| --- | --- |
| **interface** | Write the contract. Data: `B1`. Models: `C1`. |
| **implementation** | One package that implements that contract. SEVIR is one dataset, not the data layer. |
| **platform** | Runtime, evaluation, visualization, artifacts. |

## Layout

```text
README.md                 this file
rfc/matching.md           matching RFC
modules.yaml              source of truth for modules
modules.md                same roster as a table
modules.csv               Notion import
collaboration.md          Notion + GitHub issues
diagrams/
  module-map.drawio       claim map
  matching.drawio         data–model matching
  runtime.drawio          local Docker runtime
  add-package.drawio      how to add a data or model package
  export.sh               optional local PNG export (pngs are gitignored)
```

Edit the `.drawio` files in [diagrams.net](https://app.diagrams.net/) (**File → Open from → Device**). Keep module ids (`A1`, `B1`, `C2`, …) unchanged.

## Claim a module

Set `owner` in `modules.yaml`, or open a GitHub issue from `.github/ISSUE_TEMPLATE/claim-module.md`.

```text
module: B4
action: claim | comment | object
owner: <name>
comment:
```

Do not start implementation until the matching RFC is accepted. New datasets (radar, satellite, lightning) implement `B1`; they do not change `B1`.

## Status

| status | Meaning |
| --- | --- |
| `exists` | Already in the prototype |
| `design` | Interface will change later |
| `planned` | New package behind an existing interface |

See [collaboration.md](collaboration.md) for Notion.
