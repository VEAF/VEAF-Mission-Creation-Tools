---
status: accepted
---

# Externalize spawn unit/group definitions to YAML (SPAWN-EXTERNALIZE-001 spike)

`veafUnits.lua` (2287 lines) hand-codes two large data tables consumed at runtime
by the `_spawn` marker commands:

- `veafUnits.UnitsDatabase` — `{ aliases = {...}, unitType = "..." }` entries, the
  alias table for `_spawn unit <alias>`.
- `veafUnits.GroupsDatabase` — `{ aliases = {...}, group = { disposition, units,
  description, groupName } }` entries (~78: SAM sites, convoys, …), the table for
  `_spawn group <alias>`.

Editing these means editing Lua by hand; there is no per-mission way to add a
custom spawn group (a mission maker can only edit the shared framework file).
This note records the design for moving them to YAML. (The sibling `dcsUnits.lua`
DCS unit DB was already externalized to `dcsUnits.yaml` by DCSDATA-008; it is out
of scope here — HANDOFF §6: this is the *generate-a-Lua-base* axis, distinct from
the *inject-groups* axis of TODO0609-AIRCRAFT-INJECT.)

## Decision

**Source of truth is YAML; the Lua tables are generated.** Two YAML sources:

- **Framework data** — `veaf-units.yaml`, shipped with the tool (in `published.zip`
  beside the community scripts), replacing the hand-coded `UnitsDatabase` /
  `GroupsDatabase` literals in `veafUnits.lua`.
- **Per-mission data** — `src/spawn-groups.yaml` (and optionally `src/spawn-units.yaml`)
  in the mission folder, letting a mission maker add or override spawn groups/units.

**Generation happens at the MISSION build (`veaf-tools build`), not at `veaf-build`.**
This is the key difference from `dcsUnits` (which `veaf-build update-dcs-data`
regenerates into a committed framework file): here a new `veaf-tools build`
pipeline step reads the shipped framework YAML, merges the mission's YAML over it,
renders a Lua data module, and injects it into the `.miz`. Rationale: the
per-mission overrides only exist at mission-build time, so the merge + render must
live there; doing the framework data the same way keeps a single code path.

**DCS Lua cannot parse YAML at runtime** (no YAML library in the mission
environment), so runtime consumption stays Lua: the injected data module assigns
`veafUnits.UnitsDatabase` / `veafUnits.GroupsDatabase`. It is loaded **after** the
framework bundle (`veafUnits.lua` defines the functions and now defaults the two
tables to empty); the injected module then populates them.

**Merge semantics** (confirmed in -004): per-mission entries are appended; if a
mission entry shares **any** alias (case-insensitive) with a framework entry, it
**replaces** that entry, so a mission can override a framework unit/group by
reusing one of its aliases. Implemented in `spawn_data_injector.merge_spawn_data`.

## Consequences

- The mission build **always** runs the spawn-data step (even with no per-mission
  YAML) so the framework groups are present; a mission built by an older tool that
  skips it would have empty databases — acceptable since the step ships on by default.
- `veafUnits.lua` stops carrying ~1400 lines of data; a one-time extraction must be
  **parity-checked** (generated Lua semantically equal to today's tables) before the
  literals are removed — same oracle approach as DCSDATA-008.
- This unblocks de-duplicating the spawn subsystem (SPAWN-REFACTOR-002): with the
  data external and the parser characterized (SPAWN-REFACTOR-001), the duplicated
  validation/debug blocks can be consolidated safely.

## Implementation tickets

See the SPAWN-EXTERNALIZE lot in `backlog.md` (002 extract framework YAML +
parity; 003 mission-build render+inject + runtime; 004 per-mission overrides;
005 spawn de-dup).
