# FEAT-MCP-MUTATION-ACTIONS — the MCP can create a mission but cannot change one

Status: ✅ done 2026-08-15 — all ten tickets shipped (arbitrary triggers rejected by the triage). 08's
capture and 09's blocker were both settled in a DCS session; `add_air_group` (09) and the circle/oval/
free drawing shapes (10) are the last pieces. `arrow`/`icon` are refused with a reason, each awaiting
its own future measurement — not part of this lot's scope

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
| 01 | [Triage the 126 verbs by mission-maker intent](tickets/01-triage-by-intent.md) | ✅ |
| 05 | [Read the units, loadouts and routes](tickets/05-describe-units.md) — **do this first** | ✅ |
| 02 | [Unit setters](tickets/02-unit-setters.md) — loadout, skill, livery, heading, callsign | ✅ |
| 03 | [Group setters](tickets/03-group-setters.md) — move, rename, late activation, hide | ✅ |
| 04 | [Route and waypoint task editing](tickets/04-route-and-waypoints.md) | ✅ |
| 06 | [Zone editing, including polygons](tickets/06-zone-editing.md) | ✅ |
| 07 | [F10 map drawings](tickets/07-map-drawings.md) | ✅ |
| 08 | [Capture the parking-slot data](tickets/08-capture-parking-data.md) — 3 theatres captured 2026-08-15, 6521 slots | ✅ |
| 09 | [`add_air_group`](tickets/09-add-air-group.md) — flight-on-the-ramp, stands resolved from the bundled capture | ✅ |
| 10 | [Ship the drawing shapes now measured](tickets/10-remaining-drawing-shapes.md) — circle, oval, free | ✅ |
| — | Arbitrary triggers — **the triage says no**, with its reasoning below. No ticket | 🚫 |

Execution order is **05 → 02 → 03 → 04 → 06 → 07**, not the numbering: the read action is a
prerequisite, not a convenience. See the triage. 08 and 09 sit outside that order — 09 cannot start
before 08's data exists, and 08 cannot finish without a DCS session.

Delivered in **two pull requests** rather than one, on David's call: the two cheap setter families
first (a reviewable pair), then the route surgery, the zones and the drawings.

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

---

## Triage — 2026-08-11 (ticket 01)

**All 126 verbs enumerated from their `docs/cli/` page names**, then given a verdict each. Enumerated,
not sampled: the page list came from the GitHub contents API and a script asserted every one of the 126
carries exactly one verdict before this section was written. Their own README count of 141 pages is 126
`me <noun> <verb>` plus 15 host commands (`setup`, `install-hook`, `tail-log`, …), which are not mission
edits at all.

**The exploration note's per-family counts were off**, which is worth recording since this lot was scoped
from that note: zones are **11** verbs and not 8, F10 drawings **19** and not 11, and route + waypoint
**27** and not 25. Same conclusion, wider surface.

| Verdict | Verbs | Meaning |
|---|---|---|
| **Keep** | 65 | A mission maker's sentence exists |
| **Reject** | 22 | No such sentence, for a structural reason |
| **Read first** | 18 | A `get`/`list`; **blocks** the setters below |
| **Low value** | 17 | Survives, but nobody has asked |
| **Already have** | 4 | In our catalogue today |

### The finding that reorders the lot: we cannot see a unit at all

`describe_mission` returns **groups** (name, coalition, country, category) and **zones** (name, x, y,
radius). That is all. No units, no loadout, no skill, no livery, no route, no waypoint, no task.

The ticket asked us to flag what needs a read action to be usable, and the answer is bigger than
expected: **tickets 02 and 04 are unusable without one.** "Give this flight an air-to-ground loadout"
presupposes seeing the current loadout and the pylon layout; "add a waypoint after the third"
presupposes seeing the route. Without it an agent mutates blind, and the failure mode is a mission that
opens fine and flies wrong — the worst kind here.

So **a read action comes first**, as ticket 05, and it is a prerequisite rather than a nicety. It also
answers 18 of the 126 verbs in one action, which no setter does.

### Rejected, with the reason

- **An open editor's commands (7)** — `file-new/open/save/save-as`, `camera-focus/get`, `group-focus`.
  These manipulate a *session*: a mission is open, a camera looks somewhere, a selection is focused. We
  mutate a **closed `.miz`**, and a path is a parameter rather than state
  ([ADR 0017](../../docs/adr/0017-no-live-mission-editor-bridge.md) settled that on measurements). There
  is nothing to port — the concept does not exist on our side.
- **Build-owned surface (2)** — `resources-get/set`. Embedded resources are produced by the build
  (`mapResource`, checklist pictures, CTLD sounds) and `write_miz` keeps the table and the archive
  consistent. An agent editing that table by hand re-creates `FIX-MAPRESOURCE-KEY` and
  `FIX-COMMUNITY-SOUNDS-PRUNED`, two bugs we have already paid for.
- **Arbitrary triggers (13)** — the whole `trigger` family. **This is the one worth arguing with**, so
  the reasoning is explicit: VEAF *replaces* triggers rather than authoring them. A combat zone, a QRA,
  a spawn, a CAP are modules configured in `mission.yaml`, and the one trigger we do generate
  (`add_startup_script_trigger`) exists to load the scripts that make the rest unnecessary. Asked "add a
  trigger that messages the player on entering the zone", the VEAF answer is a combat zone or five lines
  in `mission-script.lua` — not fifteen actions assembling conditions and actions by hand. And for an
  *adopted* mission, `strip_native_triggers` deliberately removes the upstream ones.
  Their `list-predicates` / `describe-predicate` pair is genuinely good design — descriptor-driven, so it
  cannot rot when ED adds a predicate — but it is only worth having *if* we author triggers, so it goes
  with the family. **Recorded as "we looked and decided no"**, which is what stops the next person
  re-reading 126 pages.

### Kept, grouped by intent — one action per intent, not per verb

Cost class: **cheap** = the editor-parity layer already reaches that table; **surgery** = new `.miz`
structure work.

| # | Action | Covers | The mission maker's sentence | Cost |
|---|--------|--------|------------------------------|------|
| 05 | `describe_units` | 18 read verbs | *"What is in this mission — who flies what, with which loadout, on what route?"* | cheap |
| 02 | `set_unit_properties` | 10 unit setters | *"Give Colt flight an air-to-ground loadout and the squadron livery."* | cheap |
| 03 | `set_group_properties` | 13 group setters | *"Move that SAM battery 5 km east, rename it to the convention, and leave it uncontrolled."* | cheap |
| 03 | `add_air_group` | 5 `group-create-*` | *"Put a two-ship of F-16s on the ramp at Incirlik."* | surgery |
| 04 | `edit_route` | 17 route/waypoint verbs | *"Add a waypoint after the third, at 20 000 ft, with an attack task on that zone."* | surgery |
| 06 | `edit_zone` | 6 zone verbs | *"Make that zone a polygon along the ridge, and have it follow the carrier."* | cheap |
| 07 | `add_map_drawing` | 13 drawing verbs | *"Draw the FSCL and label the ingress corridor on the F10 map."* | cheap |
| — | `resolve_coordinates` extension | `coords-magvar` | *"What is the magnetic heading for that leg?"* — a conversion, so it belongs on the existing action rather than a new one | cheap |

**17 verbs kept but low value**, deliberately not scoped: `unit-set-chaff/flare/gun/parking`,
`group-set-formation/uncontrollable`, `waypoint-set-eta/eta-locked/speed-locked/mode/formation`,
`zone-set-color/hidden`, `drawing-set-angle/color/fill-color/thickness`. Each has a conceivable sentence
but nobody has said it. They are cheap to add **to an action that already exists**, so the rule is: add
one when a mission maker asks, never speculatively. `unit-set-parking` is the exception worth naming — it
needs per-airfield parking-slot ids we do not have, so it is surgery wearing a setter's clothes.

### Order, and why it is not the numbering

**05 → 02 → 03 → 04 → 06 → 07.** The read action first, because 02 and 04 are blind without it and
because it alone answers 18 verbs. Then the two cheap setter families, which the parity layer already
reaches. Then the route work, which is the real surgery and has the most ways to produce a mission the
editor opens happily and DCS flies wrong. 06 and 07 are worth having and block nobody.

### One thing this triage did not settle — answered 2026-08-12

Whether `add_air_group` should exist at all, or whether `create_cap_mission` plus the group-create
surgery covers it. It was filed under ticket 03 because it is the same `.miz` surgery, but a mission maker
asking for "a two-ship on the ramp" may well be better served by an existing composite.

Picking up 03 answered the *cost* question rather than the design one, and the cost decides the shape: a
parked aircraft carries **two distinct numbers** — `parking` and `parking_id`, measured at 28 and 24 on
the same F-14A — which are the runtime's `Term_Index` / `Term_Index_0`. No data in this repository holds
them: the 15 committed airbase dumps carry `{id, name, lat, lon, coalition}` and nothing more. So "on the
ramp at Incirlik" is not a setter with a stand parameter, it is a **data capture** first.

David chose to do it properly, with the data. Hence [08](tickets/08-capture-parking-data.md) (the capture
tooling, shipped — the running is his) and [09](tickets/09-add-air-group.md), which keeps the "is the
composite enough?" question open where it belongs: in front of the composite.

### What the second PR measured, and where it reduced its own scope

**Ticket 04** found the invariant that turns route editing into surgery: `FIX-WAYPOINTS-ETA-LOCKED`
concluded that DCS **refuses to save** a route with no locked-time waypoint, so removing or reordering
can produce a mission the editor rejects on a different day. Every operation restores it. Its task set
is seven tasks chosen from what real missions carry, and three of their signatures are traps —
`SetFrequency` takes **hertz** where a group's frequency is MHz, `EngageTargetsInZone` stores its
target list **twice**, and `SetFrequency`/`SwitchWaypoint` are *actions* inside a `WrappedAction`
envelope rather than tasks.

**Ticket 06** answered its own blocking question by reading `veafCombatZone.lua`: the runtime **does**
handle a polygon (`mist.getUnitsInPolygon`), for type 2 only, and its `if/elseif` has **no `else`** — so
any other type finds no units at all, in silence. The action is scoped to 0 and 2 for that reason.

**Ticket 07 reduced its own scope deliberately, and it is stated rather than slipped in.** The ticket
lists nine drawing shapes; only **three** field layouts exist anywhere in this repository (line, rect,
textbox), so the other six are refused by name. Inventing a layout is what the ticket's own "read a real
`.miz` first" rule forbids, and it is the failure `FIX-MAPRESOURCE-KEY` already paid for. The functional
need still lands: a closed line outlines an area, a rect is the no-fly box. Measuring the rest is one
editor session, listed in `DCS-SESSION-TODO.md`.

One refactor came with them, on the lesson `REFACTOR-MARKER-PARSER` paid for: the mission-table quirks
every action re-implemented — a 1-based table arriving as a dict *or* a list, numeric key ordering,
finding a group and naming what exists — now live once in `mission_table.py`, with three callers.

### What the two setter families cost, against what the triage predicted

Both were classed **cheap** ("the editor-parity layer already reaches that table"), and that held — the
work was not in reaching the tables but in the shapes the tickets described wrongly. Four corrections
worth keeping, each found by reading a real mission:

- **`skill` has seven values, not four**, and two of them (`Client`, `Player`) are human slots rather
  than competence levels. Crossing that line adds or removes a **multiplayer slot** — the
  `FIX-TEMPLATE-SLOTS-VISIBLE` bug — so both directions are refused.
- **An aircraft's `callsign` is a structured table**, not a plain field: `name` is the family's word plus
  the flight and number indices, and writing it alone desynchronises the radio from the display.
- **A group's own `x`/`y` anchor** has to move with its units and waypoints; ticket 03 listed the first
  two and not the third, and the editor draws the group from it.
- **A design-time surface check is impossible** — no terrain data exists on the Python side at all,
  which is why `FEAT-SCENERY-AWARE-SPAWN` solved that problem at runtime. The move warns instead of
  pretending.
