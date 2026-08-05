# TOOLING-DOC-AUTOGEN — generate the two references that are derivable, gate their freshness

Status: ⬜ ready

Origin: [`docs/exploration/DCS-SMS-EXPLOIT.md`](../../docs/exploration/DCS-SMS-EXPLOIT.md) §3.

## Problem

`docs-check` validates that links resolve and anchors exist. It cannot tell whether a reference still
describes the code — and four hand-written references have drifted apart from it before:

| File | Size | Hand-written? |
|---|---|---|
| `doc/LUA_API_REFERENCE.md` | 118 KB | entirely |
| `doc/MISSION_YAML_REFERENCE.md` | 39 KB | entirely |
| `doc/PIPELINE_REFERENCE.md` | 31 KB | entirely |
| `doc/ALIASES.md` | 8 KB | entirely, and **derivable** |

`DOC-AUDIT-PASS` found a stale `addSubMenu` signature and a "6.5.25 / June 2026" header in
`LUA_API_REFERENCE` — silent rot, exactly what a freshness gate catches. And this session added 73
lines to that file **by hand**, which is the pattern continuing.

`dcs-sms` runs `dcs-sms doc` to regenerate its 141 CLI pages and a `cli-docs-fresh` CI job that fails
when the committed result differs. That is the mechanism worth having.

## What is actually derivable — and what is not

This is the whole scoping decision, and getting it wrong means promising a generator for prose.

**Derivable, ship it:**

- **`ALIASES.md`** — the aliases live in `veaf_libs/data/veaf-units.yaml`. The doc is a rendering of a
  data file, so it should be rendered from it.
- **An MCP catalogue reference** — `list_catalog()` already returns every action's spec
  (`veaf_mission_mcp/server.py`). The mission-maker catalogue doc is maintained by hand today, which
  is why "adding an action means remembering to update the catalogue" is a standing trap. Generate it.

**Not derivable, leave alone:**

- `LUA_API_REFERENCE.md` — 118 KB of prose explaining *behaviour*, caveats and in-game consequences.
  Signatures could be extracted; the value is in the sentences around them. A generator here would
  destroy the useful part to automate the trivial one. **Explicitly out of scope**, and this PRD says
  so to stop the next person trying.
- `MISSION_YAML_REFERENCE.md`, `PIPELINE_REFERENCE.md` — same reason.

Partial extraction of `LUA_API_REFERENCE` signatures with a check that they match the source is a
*possible* later lot, and a different one. Not here.

## Scope

| # | Ticket | Status |
|---|--------|--------|
| 01 | [Generate `ALIASES.md` from `veaf-units.yaml`](tickets/01-aliases-generated.md) | ⬜ |
| 02 | [Generate the MCP catalogue reference from `list_catalog`](tickets/02-mcp-catalog-generated.md) | ⬜ |
| 03 | [CI freshness gate](tickets/03-freshness-gate.md) | ⬜ |

## Definition of Done

- Both generated files are byte-identical to what the generator produces, and CI fails when they are
  not — the gate is the deliverable, not the generator.
- The generated files keep a header saying they are generated and naming the command, so nobody edits
  them by hand and loses the edit on the next run.
- Both languages where the file is user-facing. `DOC-QUALITY-GATE` refuses an untranslated page and
  `docs-check` enforces it.
- The MCP catalogue generator retires the manual lockstep, and the doc that describes that lockstep is
  updated to say it is automatic now.
