# FEAT-MCP-MUTATION-ACTIONS — the MCP can create a mission but cannot change one

Status: ⬜ ready

Origin: [`docs/exploration/DCS-SMS-EXPLOIT.md`](../../docs/exploration/DCS-SMS-EXPLOIT.md) §1,
identified 2026-08-04. The next wave of `NL-MISSION-GEN` ([ROADMAP](../../ROADMAP.md) §4).

## Problem

The MCP catalogue is **29 actions** plus `capabilities` and `list_catalog`. Counted by hand on
2026-08-05, the nine `set_*` among them are:

```
set_airbase_coalition  set_log_level  set_mission_log_level  set_mission_module
set_mission_security   set_mission_setting  set_module_enabled  set_security_disabled
set_veaf_config
```

Every one operates on **mission configuration** — modules, security, logging, a whole airbase's
coalition. **Not one mutates an object the mission already contains.** No unit setter, no group
setter, no route or waypoint editing, one trigger action against their fifteen, zones creatable but
not editable and never as a polygon, no F10 drawings.

Cross-read against `dcs-sms`'s `docs/cli/` — 126 `me <noun> <verb>` pages, which is a free checklist
of what an agent should be able to do to a `.miz`:

| Area | dcs-sms | VMCT |
|---|---|---|
| Unit: skill, livery, position, heading, altitude, onboard number, callsign, loadout, fuel, chaff/flare, parking | 17 verbs | **none** |
| Group: rename, move, hide, frequency, country, formation, late activation, uncontrolled, remove, add/remove unit | 23 | **none** |
| Route and navigation, incl. waypoint tasks | 25 | **none** |
| Arbitrary triggers: create, conditions, actions, reorder, predicate introspection | 15 | `add_startup_script_trigger` only |
| Zones | 8 | creation only, no polygon |
| F10 map drawings | 11 | **none** |

We are strong exactly where they are absent — `geocode`, reserved VEAF naming conventions, one-pass
domain composites (`create_combat_zone` / `create_qra` / `create_cap_mission`), the whole
scaffold → validate → build chain. The gap is one-sided and it is about *editing*.

The concrete consequence: **"change this flight's loadout", "move that group 5 km east", "add a
waypoint with an attack task" are impossible through the MCP today**, while every other link in the
chain exists. A mission maker can have an agent build a mission from nothing and cannot have it
adjust the result.

## This is not a port of 126 verbs

Stated up front because it is the way this lot goes wrong. Their catalogue is a *coverage grid to
read*, not a specification to implement. 126 actions would bury the domain composites that are our
actual advantage, and most of those verbs answer questions no VEAF mission maker asks.

Ticket 01 is therefore a **triage by mission-maker intent**, and it decides what tickets 05+ even
are. Only the three families the exploration note names explicitly — unit setters, group move and
rename, waypoint tasks — are pre-scoped, because those are the ones with a named use case.

## Scope

| # | Ticket | Status |
|---|--------|--------|
| 01 | [Triage the 126 verbs by mission-maker intent](tickets/01-triage-by-intent.md) | ⬜ |
| 02 | [Unit setters](tickets/02-unit-setters.md) — loadout, skill, livery, heading, callsign | ⬜ |
| 03 | [Group setters](tickets/03-group-setters.md) — move, rename, late activation, hide | ⬜ |
| 04 | [Route and waypoint task editing](tickets/04-route-and-waypoints.md) | ⬜ |
| — | Arbitrary triggers, zone polygons, F10 drawings — **gated on 01**, no ticket until it decides | — |

## Borrow their trigger design, not their trigger code

For the triggers family (if 01 keeps it), the exploration note flags the part worth stealing in
spirit: their approach is **descriptor-driven**. `trigger list-predicates` and `describe-predicate`
query ED's own `me_predicates.rulesDescr` instead of hardcoding each predicate's parameter shape —
so the tool does not rot when ED adds a condition. Their `trigger_export` / `trigger_import` also
handle the hard parts we would otherwise discover the hard way: dictionary re-keying, embedded
media, dangling references.

**Licensing fence:** `tools/` in `dcs-sms` is **GPL v3** and that is where all of this lives. VMCT is
permissive. We read their design specs, we understand, we rewrite. Nothing is copied.

## Out of scope

- A live Mission Editor bridge. Rejected on measurements — [ADR 0017](../../docs/adr/0017-no-live-mission-editor-bridge.md).
  These actions mutate a **closed `.miz`**, as [ADR 0014](../../docs/adr/0014-mission-editor-mcp-editor-parity-layer.md)'s
  editor-parity layer already does.
- Their `framework/` Lua. Explicitly marked "not ready for real missions" by its author, unstable
  public surface under 0.x. A source of ideas, not a dependency.

## Definition of Done

- Each shipped action round-trips: read the mission, mutate, write, and the DCS Mission Editor opens
  the result without complaint. That last part is not optional — `FIX-MAPRESOURCE-KEY` is what
  happens when a write looks right and the editor disagrees.
- Backup-before-write honoured, as the existing editor-parity actions do.
- **Catalogue lockstep**: every new action also lands in the mission-maker catalogue doc in the same
  ticket. The catalogue is how an agent discovers what exists; an action missing from it is invisible.
- `ruff` / `mypy` / `pytest` green over the whole tree; Python coverage gate bumped per the ratchet.
- Version bumped in `pyproject.toml` **and** `plugin/.claude-plugin/plugin.json` (enforced by
  `test_plugin_version.py`).
