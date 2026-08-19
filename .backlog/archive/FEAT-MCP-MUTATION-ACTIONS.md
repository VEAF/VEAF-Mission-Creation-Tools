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
| 01 | Triage the 126 verbs by mission-maker intent | ✅ |
| 05 | Read the units, loadouts and routes — **do this first** | ✅ |
| 02 | Unit setters — loadout, skill, livery, heading, callsign | ✅ |
| 03 | Group setters — move, rename, late activation, hide | ✅ |
| 04 | Route and waypoint task editing | ✅ |
| 06 | Zone editing, including polygons | ✅ |
| 07 | F10 map drawings | ✅ |
| 08 | Capture the parking-slot data — 3 theatres captured 2026-08-15, 6521 slots | ✅ |
| 09 | `add_air_group` — flight-on-the-ramp, stands resolved from the bundled capture | ✅ |
| 10 | Ship the drawing shapes now measured — circle, oval, free | ✅ |
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

David chose to do it properly, with the data. Hence 08 (the capture
tooling, shipped — the running is his) and 09, which keeps the "is the
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

---

## 01 — Triage the 126 verbs by mission-maker intent

Status: ✅ done
Type: chore
Files: this lot's PRD, then new ticket files for whatever survives

### Why this is first

The temptation is to open `dcs-sms`'s `docs/cli/` and start implementing. 126 actions would drown
the domain composites that are VMCT's actual advantage — an agent facing 155 actions picks worse
than one facing 40 — and most of those verbs answer questions no VEAF mission maker asks.

So this ticket produces **a list, with reasons**, and tickets 05+ are written from it. Tickets 02–04
are already scoped because the exploration note names their use case outright.

### Method

For each of the six families, and each verb inside it, answer one question: **what would a mission
maker ask an agent, in a sentence, that needs this?** A verb with no such sentence does not ship.

- [x] Enumerate the 126 verbs from their `docs/cli/` (read-only; the code is GPL, the page titles
      are a checklist).
- [x] For each, write the mission-maker sentence or mark it rejected with why.
- [x] Group the survivors into actions. **One action per intent, not per verb** — "move that group
      5 km east" is one action taking a bearing and a distance, not `group set-x` + `group set-y`.
- [x] Check each survivor against what already exists: `list_catalog` on the current build, not
      memory. Some may be reachable by composing existing actions.
- [x] Flag the ones that need a **read** action to be usable at all. Mutating a unit's loadout
      presupposes being able to see the current one; `describe_mission` may or may not already
      expose it.
- [x] Note the ones that are **cheap because the parity layer already reaches them** versus the ones
      needing new `.miz` surgery — the difference decides ticket order.

### Output

A section appended to this lot's PRD: the surviving actions, grouped, each with its
mission-maker sentence and its cost class. Then one ticket file per group for anything beyond
02–04, and the gated line in the Scope table replaced by real rows.

### Notes

If the triage concludes that a family is not worth it, say so in the PRD and delete its row.
A recorded "we looked and decided no" is worth as much as an implementation — it is what stops
the next person re-reading 126 pages.

### Delivered — 2026-08-11

The triage itself is in the PRD, where tickets 05+ can be written from it. What follows is
what the method produced and what surprised it.

**Enumerated, not sampled.** The 126 page names came from the GitHub contents API on
`nielsvaes/dcs-sms/docs/cli`, and a script asserted that every one of them carries **exactly one**
verdict — no duplicates, none missed — before a word of the triage was written. That guard exists
because a hand-picked subset already cost this repository a false "the whole family is fixed" claim.

Verdicts: **65 keep, 22 reject, 18 read-first, 17 low value, 4 already have.** Their README's 141 pages
are these 126 plus 15 host commands (`setup`, `install-hook`, `tail-log`, …), which are not mission edits.

#### The finding that reorders the lot

The ticket said to flag what needs a read action to be usable, and guessed `describe_mission` "may or may
not already expose it". Measured: **it does not expose units at all.** Groups (name, coalition, country,
category) and zones (name, x, y, radius) — that is the entire surface. No loadout, no skill, no livery,
no route, no waypoint, no task.

So tickets 02 and 04 are not *nicer* with a read action, they are **blind without one**, and it goes
first as ticket 05. It also answers 18 of the 126 verbs by itself, which no setter approaches.

#### Three families rejected, and the one worth arguing with

`file`/`camera`/`group-focus` (7) manipulate an **open editor session**, which ADR 0017 declined on
measurements — the concept does not exist on our side. `resources-get/set` (2) are build-owned; an agent
editing `mapResource` by hand re-creates two bugs we have already paid for.

The contestable one is **arbitrary triggers (13)**, rejected as a family: VEAF *replaces* triggers rather
than authoring them, and the single trigger we generate exists to load the scripts that make the rest
unnecessary. Their `list-predicates`/`describe-predicate` design is genuinely good — descriptor-driven,
so it cannot rot when ED adds a predicate — but it is only worth having if we author triggers. **Flagged
for David to break**: it is the one verdict here that is a judgement about VEAF's shape rather than a
measurement.

#### The exploration note was wrong on three counts

Worth recording because this lot was scoped from that note: zones are **11** verbs and not 8, F10
drawings **19** and not 11, route + waypoint **27** and not 25. The conclusion holds; the surface is
wider than advertised. This is what enumerating buys over trusting a summary.

#### Output

Three new tickets — 05 read, 06 zones,
07 drawings — the gated row in the scope table replaced by real ones, and the
execution order set to **05 → 02 → 03 → 04 → 06 → 07**, which is not the numbering.

No code, so no version bump and no CHANGELOG entry: this ticket's whole product is the decision and the
tickets that follow from it.

---

## 02 — Unit setters

Status: ✅ done 2026-08-12 — shipped as `set_unit_properties`, with two of this ticket's own claims corrected by measurement
Type: feat
Files: `src/python/veaf-tools/veaf_mission_mcp/`, mission-maker catalogue doc, `test/python/`

Depends on: 01 for the final field list; the use case below is already committed.

### The use case

> *"Change this flight's loadout to the CAS one."*

Named in the exploration note as one of the three things that ought to be possible and is not.
dcs-sms exposes 17 unit verbs; this ticket is the subset with a VEAF sentence behind it.

### Behaviour

One action mutating a named unit inside a named group, addressing it the way a mission maker does —
by name, never by index:

- **loadout** — the pylons table. The hard case, and the one worth getting right: a loadout is a
  per-airframe structure, so the action needs either a named preset or a validated pylon map, not a
  free-form dict the agent can get wrong silently.
- **skill** — the four DCS values, rejected if not one of them.
- **livery** — a string DCS does not validate; a wrong value shows a default skin with no error, so
  warn when it is not in the known set for that type rather than fail.
- **heading** — degrees in, radians out, since the mission table stores radians and this is exactly
  the trap `resolve_coordinates` hides elsewhere.
- **callsign / onboard number** — plain fields, cheap, and asked for often.

Read-before-write: the action reports the previous value in its result. An agent that cannot see
what it changed cannot tell the mission maker what it did.

### What measurement changed, against what this ticket assumed

Two of the field descriptions above were wrong, and both were caught by reading real missions rather
than by reasoning:

- **`skill` has seven values, not "the four DCS values".** `Average`, `Good`, `High`, `Excellent` and
  `Random` are AI levels — `Random` is a real one, DCS picks at mission start. `Client` and `Player`
  are **not skills at all**: they are human slots. Writing an AI level over a `Client` *deletes a
  multiplayer slot*, and writing `Client` over an AI unit *creates one* — which is the bug
  `FIX-TEMPLATE-SLOTS-VISIBLE` was opened for. Both directions are refused naming the reason, which
  is more than the ticket asked for and less dangerous than what it described.
- **`callsign` is not a "plain field, cheap".** An aircraft carries
  `{1: family, 2: flight, 3: number, name: "Colt11"}`, where `name` is the family's word followed by
  the two indices (`{1:1, 2:1, 3:2}` reads `Enfield12`, `{1:4, 2:1, 3:1}` reads `Colt11`). Writing
  `name` alone desynchronises the radio call from the editor's display. So the action edits the
  indices and **rebuilds** `name` from the word already there; changing the *family* needs DCS's
  family→word table, which this repository does not ship, and is refused unless the caller passes the
  resulting `name` too. A ground unit's callsign really is a bare number, and stays one.

And one limit the ticket asked for that **cannot** be delivered as written: "a validated pylon map".
The *shape* is validated (a station is an integer ≥ 1, and a bad key is an error rather than a
dropped key, as required) but a **CLSID cannot be checked against the airframe** — no per-type weapon
table ships with veaf-tools. DCS drops an impossible weapon silently, so the action returns that limit
as a warning instead of implying it by saying nothing. Same for the livery, as the ticket foresaw.

### Tasks

- [x] Action implemented, addressing unit by group name + unit name — by **exact** name, not a
      fragment: `describe_units` filters on one, but an edit landing on whichever group matched first
      is not recoverable.
- [x] Loadout takes a validated shape, not an arbitrary dict; a bad pylon index is an error, not a
      silently dropped key. `replace` / `merge` modes, and an empty CLSID empties a station.
- [x] Heading converts degrees → radians, with a test pinning the direction of the conversion (and
      normalising −90 onto 270).
- [x] Unknown skill rejected naming the valid values; unknown livery warns and proceeds.
- [x] Result carries the previous values, per field.
- [x] Backup-before-write, as the existing editor-parity actions do.
- [x] Mission-maker catalogue doc updated **in this ticket**, plus the developer reference — the
      `docs-check` gate turns out to enforce that second one, which is better than remembering it.

### Acceptance criteria

- [ ] 🧑 Round trip: mutate a real `.miz`, reopen it in the DCS Mission Editor, no complaint. **Not
      doable on the workstation this was written on** (no DCS installed, no `.miz` outside the
      repository's fixtures), so it is David's to do. The cheap half is covered: every test re-reads
      the written archive, so a write that no longer parses fails here.
- [x] Tests: each field, plus the rejection paths, plus "group not found" and "unit not found in
      group" naming what was looked for — 49 cases.
- [x] `ruff` / `mypy` / `pytest` green over the whole tree; coverage gate bumped per the ratchet.

---

## 03 — Group setters

Status: ✅ done 2026-08-12 — shipped as `set_group_properties`. `add_air_group` **left this ticket** for 09, on David's call: it needs parking data nobody has yet
Type: feat
Files: `src/python/veaf-tools/veaf_mission_mcp/`, mission-maker catalogue doc, `test/python/`

Depends on: 01 for the final field list; the use case below is already committed.

### The use case

> *"Move that group 5 km east."*

The second of the three the exploration note names. dcs-sms has 23 group verbs; this is the subset a
VEAF mission maker would actually ask for.

### Behaviour

**Move** is the one with a real design question, and it is not "set x and y":

- A group is not a point — it is units in a formation, plus possibly a route. Moving it must
  translate **every unit and every waypoint by the same delta**, or the formation shears and the
  route detaches from the units.
- Take a bearing and a distance, or a target coordinate, and reuse the existing geodesic offset from
  `FEAT-GEO-PLACEMENT` rather than adding metres to `x` — the projection work is already done and
  ADR 0015 owns it.
- The destination has to be checked: dropping a ground group in the sea is the failure this makes
  easy. Surface-type validation belongs here, and it is the design-time cousin of the runtime
  `veaf.findSpawnPoint` shipped by `FEAT-SCENERY-AWARE-SPAWN`.

**Rename** must respect the reserved VEAF naming conventions the MCP already knows
(`validate_group_name`, `describe_naming_conventions`) — a rename that breaks a convention breaks the
runtime module that keys off it, silently, at mission time.

**Late activation / hide / uncontrolled** are plain booleans and cheap.

**Frequency** must not be set blind: `FIX-PRIMARY-FREQ-HUMANRADIO` established that an aircraft has
two constraints (`panelRadio.range` for presets, `HumanRadio` for the group's primary) and that
ignoring the second makes the editor refuse to save the mission. Reuse `dcs-radio-specs.yaml`, do not
re-derive.

### The surface check cannot be delivered, and that is a measurement

The ticket asks the move to refuse a destination whose surface is wrong for the group. **There is no
terrain data on the Python side at all**: `land.getSurfaceType` is a *runtime* API and only its schema
ships here, and no heightmap or land-type table exists in the repository. So a design-time surface
check would have to invent its answer.

That is not an oversight in the ticket — it is the same wall `FEAT-SCENERY-AWARE-SPAWN` hit, which is
exactly why that lot solved the problem **at runtime**, around DCS's own `Disposition` singleton
(ADR 0018). The design-time cousin the ticket hoped for does not exist yet, and would be a data lot of
its own.

Delivered instead: the move **says** it could not look, in the action's `warnings`, in both catalogue
languages, and in the action description the calling agent reads. A validation that lied would be
worse than an absent one, because a mission maker would stop checking.

### What `add_air_group` turned into

The triage filed it here and flagged the question as unsettled: *"decide that when 03 is picked up,
with the composite in front of you"*. Measured while doing so — a parked unit carries **two** distinct
numbers, `parking` **and** `parking_id` (28 and 24 on the same aircraft in
`test/veaf-tools/test.miz`), matching the runtime's `Term_Index` / `Term_Index_0` — so putting a
two-ship "on the ramp at Incirlik" needs per-airfield slot ids that no data in this repository holds.

David's call (2026-08-12): **do it, with the parking data**, which makes it two tickets rather than a
line in this one — 08 captures the data, 09
spends it.

### Tasks

- [x] Move translates all units **and** all waypoints by one delta — plus the group's own `x`/`y`
      anchor, which the ticket did not mention and the editor draws from. The shear test was proven
      discriminating by breaking the translation on purpose and watching exactly those two tests fail.
- [x] Move uses the existing geodesic offset, not naive metre arithmetic — pinned against
      `veaf_libs.coordinates` itself, so the projection cannot be quietly bypassed later.
- [x] Move **warns** rather than refuses on the destination's surface, for the reason above.
- [x] Rename runs the existing convention validation and refuses a name that breaks it, with
      `acknowledge_conventions` for the legitimate case of renaming *into* a convention. Also refuses
      a **collision**, which the ticket did not ask for: two groups sharing a name makes every later
      edit ambiguous, including undoing this one.
- [x] Frequency gated on the aircraft's `HumanRadio` bounds from `dcs-radio-specs.yaml`, reusing the
      presets injector's validator. **Every** unit type in the group is checked, not just the first —
      a mixed group would otherwise pass here and be refused by the editor because of another member.
- [x] Booleans: late activation, hidden, uncontrolled. `None` means "not given" and `False` means
      "off", so a flag can actually be cleared.
- [x] Mission-maker catalogue doc updated in this ticket, plus the developer reference.

### Acceptance criteria

- [ ] 🧑 Round trip through the DCS Mission Editor with no complaint, including a moved group with a
      route. David's to do — no DCS on the workstation this was written on.
- [x] Tests: the shear case (units move, waypoints do not) must fail before the fix and pass after.
      **Verified by sabotage**: dropping the waypoints from the translation made
      `test_the_route_travels_with_the_units` and `test_a_move_to_a_target_still_carries_the_route`
      fail, and nothing else — so they measure the shear rather than the move in general.
- [x] `ruff` / `mypy` / `pytest` green over the whole tree; coverage gate bumped per the ratchet.

---

## 04 — Route and waypoint task editing

Status: ✅ done 2026-08-12 — shipped as `edit_route`; the named task set is seven tasks, each signature read out of a real mission
Type: feat
Files: `src/python/veaf-tools/veaf_mission_mcp/`, mission-maker catalogue doc, `test/python/`

Depends on: 01 for scope, 03 for the move semantics it shares.

### The use case

> *"Add a waypoint with an attack task."*

The third the exploration note names, and the largest of the three: dcs-sms spends **25 verbs** here,
more than on units. That is a signal about where mission-editing effort actually goes.

### Behaviour

Two layers, and the second is where the value is:

**The route** — add, insert, move, remove a waypoint; set its altitude, speed, and type. Mechanical,
and mostly a list operation on `route.points`.

**The waypoint's tasks** — what a waypoint *does*: attack a group, orbit, land, refuel, set a
frequency, switch a flag. This is a nested structure of `task` / `params` whose shape depends on the
task id, so the same trap as their trigger predicates applies: hardcoding each shape means rotting
the day ED adds one.

Prefer **a small named set of tasks a mission maker asks for**, each with a validated signature, over
a generic "write this task table" action. A generic action is a foot-gun: an agent produces a
plausible task table, DCS ignores it silently, and the mission maker discovers the flight does
nothing an hour into testing. If 01's triage finds the named set too limiting, an escape hatch can
come later — but it starts closed.

`ETA locked` deserves a mention: `FIX-WAYPOINTS-ETA-LOCKED` exists as a branch name in this repo's
history, so the interaction between an edited waypoint and its ETA is known to be delicate. Check
what that work concluded before touching timing fields.

### What `FIX-WAYPOINTS-ETA-LOCKED` concluded, and why it shaped the whole module

The ticket said to check before touching a timing field. It concluded something stronger than
"delicate": **DCS refuses to save a mission whose route has no waypoint with a locked time**, with the
error *"Route has no waypoints with locked time!"*, and its own repair is to lock the first waypoint.

That turns route editing from a list operation into surgery, because **removing or reordering can take
out the only locked waypoint** — and the failure surfaces in the editor, on a different day, naming the
route rather than the edit. So every operation restores the invariant and says so when it had to. The
lock is *at least one*, not *the first*: an authored lock further down the route survives.

### The task set, and the three traps measured inside it

Seven tasks, chosen from what real missions actually carry (counted across the fixtures: `Orbit` 169,
`Land` 184, `EngageTargets` 152, `EngageTargetsInZone` 109, `GoToWaypoint` 82, `Escort` 23,
`Bombing` 13): **orbit, land, attack_group, bombing, engage_targets_in_zone, set_frequency,
switch_waypoint**. An unknown name is refused naming the set — the escape hatch starts closed, exactly
as the ticket asked.

Three signatures are traps a generic writer walks into:

- **`SetFrequency` takes hertz** — `31000000` for 31 MHz — while a *group's* frequency (ticket 03) is
  in MHz. Two units for the same notion in one file. The action takes MHz and converts.
- **`EngageTargetsInZone` stores its target list twice**: a `targetTypes` array *and* a serialised
  `value` string (`"Air;Cruise missiles;"`). Writing only the array leaves the mission carrying two
  versions of the same decision, so both come from the one list the caller gave.
- **`SetFrequency` and `SwitchWaypoint` are not tasks but *actions***, carried inside a `WrappedAction`
  envelope. Written as bare tasks, DCS ignores them in silence.

Two more things measurement added that the ticket did not foresee: a waypoint's `type` and `action` are
a **pair** (`Land` goes with `Landing`), so setting one alone produces a point the editor shows and DCS
does not fly; and an added waypoint must **inherit** its neighbour's altitude and speed, or it lands at
altitude 0 and the flight dives to reach it.

### Tasks

- [x] Route-level operations on waypoints: add, insert at index, remove, reorder. Removing the **last**
      waypoint is refused — a route with none is not a route.
- [x] Altitude, speed, waypoint type, with the units in the **parameter names** (`altitude_ft`,
      `speed_kt`) rather than only in the description, and both unit systems in the result.
- [x] A named set of waypoint tasks, each validated; an unknown task name is refused naming the set,
      and a missing required parameter is refused naming the parameter.
- [x] Read the current route back — the result carries the resulting route, so an agent sees what it
      just did without a second call.
- [x] Checked what `FIX-WAYPOINTS-ETA-LOCKED` concluded, and made its invariant the module's spine.
- [x] Mission-maker catalogue doc updated in this ticket, plus the developer reference.

### Acceptance criteria

- [ ] 🧑 Round trip through the DCS Mission Editor with no complaint; a flight with an added attack-task
      waypoint **flies it** in game, since the editor accepting a task table is not proof DCS runs it.
      David's to do — no DCS here. Listed in `DCS-SESSION-TODO.md`.
- [x] Tests: each operation, each task, plus the refusal path for an unknown task — 43 cases.
- [x] `ruff` / `mypy` / `pytest` green over the whole tree; coverage gate bumped per the ratchet.

---

## 05 — Read the units, loadouts and routes

Status: ✅ done
Type: feat
Files: `veaf_mission_mcp/describe_mission.py` (or a sibling), `actions.py`, the catalogue doc, tests

### Why this is first, ahead of its own number

The triage went looking for what needs a read action to be usable and found that **the
agent cannot see a unit at all**. `describe_mission` returns groups (name, coalition, country, category)
and zones (name, x, y, radius) — nothing else. No units, no loadout, no skill, no livery, no route, no
waypoint, no task.

So tickets 02 and 04 are not merely more convenient with this: they are **blind without it**. "Give
Colt flight an air-to-ground loadout" needs the current loadout and the pylon layout; "add a waypoint
after the third" needs the route. An agent that mutates without reading produces a mission that opens
in the editor and flies wrong, which is the failure mode nothing here catches.

It also answers **18 of the 126 verbs** in one action — `unit-get/list/payload`, `group-get/list`,
`route-get/list`, `waypoint-get/list-tasks/describe-task`, `zone-get/list`, `airbase-get/list`,
`drawing-get/list`, `trigger-get/list` — which no setter comes close to.

### Behaviour

One read action, shaped by what a mission maker asks: *"what is in this mission — who flies what, with
which loadout, on what route?"*

- Per **unit**: name, type, skill, livery, callsign, onboard number, position, heading, altitude, fuel,
  and the **loadout** (pylon → weapon, plus the pylon layout so a setter can be written against it).
- Per **group**: what `describe_mission` already gives, plus late activation, uncontrolled, frequency,
  country, hidden flags, and the group task.
- Per **group**: the **route** — waypoints in order with type, action, position, altitude, speed, and
  each waypoint's tasks.

Decide before writing:

- **Extend `describe_mission` or add an action?** Extending risks a wall of JSON for a mission with
  three hundred groups, and `describe_mission` is documented as situational awareness before a write.
  A separate action with a **filter** (by group name, by coalition, by category) is probably right —
  but check how the existing callers use `describe_mission` before splitting.
- **Verbosity has a cost the caller pays.** A full Foothold mission has thousands of units; returning
  everything unfiltered would blow an agent's context and make the action unusable for the very missions
  that need it most. Whatever the shape, a caller must be able to ask for one flight.

### Tasks

- [x] Decide and record: extend `describe_mission`, or a new filtered action.
- [x] Read units with their loadout and pylon layout, from the mission table (no DCS needed).
- [x] Read each group's route with per-waypoint tasks.
- [x] Filtering, so one flight can be asked for without the other 299 groups.
- [x] Catalogue doc updated in the same ticket (lockstep — an action missing from it is invisible).
- [x] Tests over a fixture `.miz` holding at least: a multi-unit air group with a loadout, a group with
      a route and a waypoint task, and a late-activated group.

### Acceptance criteria

- [x] Every field tickets 02 and 04 need to mutate can be **read** first.
- [x] A single flight can be described without dumping the mission.
- [x] `ruff` / `mypy` / `pytest` green; coverage gate bumped per the ratchet.

### Delivered — 2026-08-11

`describe_units`, a **new action** rather than a bigger `describe_mission`. The decision the ticket
asked for, taken on evidence: `describe_mission` has exactly one caller (the catalogue) and no internal
consumer depends on its shape, but it is *documented* as a light look before a write — and a Foothold
mission is megabytes of detail, so folding this into it would have made both unusable on the missions
that need them most.

#### Three shapes, each measured rather than assumed

All three came out of a real mission (Foothold Caucasus 4.4.1, 357 armed units), read before writing
any code.

**1. `pylons` is keyed by pylon number, never positional.** DCS numbers stations and the numbers are
**not contiguous** — a real FA-18C carries 1, 4, 5, 6 and 9. Measured: **170 of 357** armed units have a
gapped layout, and the Lua parser hands *those* back as a dict while it flattens the contiguous ones
into a list. So a reader treating pylons as an ordered list is right about half the time and silently
wrong the rest, which is precisely how the setter in ticket 02 would have hung a weapon on the wrong
station. Two tests pin the gap explicitly (stations 2 and 3 absent, the GBU still on 4).

**2. The editor's auto options are flagged and stripped.** A waypoint task is a `ComboTask` whose
`params.tasks` mixes the authored task with the options the editor writes itself (ROE, radar, formation),
all `auto = true`. Measured across the mission: **1093 automatic entries against 189 authored**. Both are
reported — hiding them would misrepresent the mission — but only authored ones carry their `params`,
because forty option bodies bury the one entry someone put there on purpose.

**3. A cap the caller is told about.** The whole mission is **1.9 MB** of JSON; a single 62-waypoint
group is **18 KB**. Hence `group_name` (matching a fragment, since a mission maker says "Colt"),
`coalition`, `category`, a 50-group default with `matched` and `truncated` in the answer, and
`include_route: false` — which **omits the key** rather than returning `[]`, because "not asked for" is a
different fact from "this group has no route". `include_route` was added *after* measuring the 18 KB, not
guessed up front.

Booleans are returned as booleans: DCS **omits** a key that is false, and a caller reading `null` cannot
tell "off" from "the reader did not look". Same reasoning as the callsign, reported by its readable name
rather than as the index table DCS stores.

#### Verified against the real mission, not only the fixture

Run over Foothold Caucasus it reports 189 plane groups, truncation flagged, pylons numbered 1-10 on an
F-14A, callsign `Ford11`, a 62-waypoint route — and the auto/authored split behaves as measured. The
fixture in the test file was then built to hold each of those shapes, including a gapped loadout and an
authored `Bombing` task among the editor's options.

#### Lockstep

Catalogued in **both** places the gate names: the mission-maker catalogue (FR + EN, inserted as row 2
beside its sibling with every later row renumbered) and the developer reference (FR + EN). `docs-check`
found the second one — the developer page is enforced against the code, which is how an action stops
being invisible.

32 tests. Coverage 80.81 % against a 79 gate, so the ratchet does not move. Version 6.13.91.

### What this unblocks

Tickets **02** (unit setters) and **04** (route editing) are no longer blind: every field they mutate can
now be read first. The pylon numbering in particular is the contract 02 should be written against —
a setter taking a station number, not a list position.

---

## 06 — Zone editing, including polygons

Status: ✅ done 2026-08-12 — shipped as `edit_zone`; `veafCombatZone` **does** handle a polygon, measured in its source
Type: feat
Files: `veaf_mission_mcp/add_trigger_zone.py` (or a sibling), `actions.py`, the catalogue doc, tests

### Why

`add_trigger_zone` creates a **circular** zone and nothing edits one afterwards. The
triage keeps 6 of the 11 zone verbs, and the one that matters most is the one we cannot
express at all:

> *"Make that zone a polygon along the ridge, and have it follow the carrier."*

A VEAF combat zone is a trigger zone, so a zone that cannot be reshaped or moved is a combat zone that
has to be deleted and rebuilt to be adjusted.

### Behaviour

Kept verbs and their intent:

| Verb | The sentence |
|---|---|
| `zone-set-vertices` | *"Follow the ridge line rather than a circle"* — a quad/polygon zone |
| `zone-set-pos` | *"Move the combat zone 3 km north"* |
| `zone-set-radius` | *"Make the QRA trigger zone bigger"* |
| `zone-set-name` | *"Rename it to the VEAF convention"* |
| `zone-set-link` | *"Have the zone follow the carrier"* — a zone linked to a unit |
| `zone-remove` | *"Drop that zone"* |

Rejected as low value, and why: `zone-set-color` / `zone-set-hidden` are editor cosmetics — they change
how a zone looks to whoever opens the mission in the ME, not what it does in game.

### Decide before implementing

- **A quad zone is a different shape in the mission table**, not a circle with extra fields (`type`,
  `verticies` — note DCS's own spelling). Read a real polygon zone out of a `.miz` before writing
  anything, the way `FEAT-CUSTOM-SCRIPT-LOAD-DELAY` read an upstream trigger rather than assuming its
  shape.
- **Does `veafCombatZone` support a polygon zone?** If the Lua side only handles circles, a polygon
  zone the MCP can create would be a zone the framework mishandles — worse than not offering it. Check
  the runtime before shipping the write.
- `zone-set-link` needs the linked unit to exist; decide what happens when it does not (refuse, or warn
  and leave unlinked).

### The two measurements this ticket demanded

**A polygon zone's exact shape**, read out of `test/veaf-tools/demo-mission/veaf-demo-mission.miz`
(`czBatumi`):

```
{ name = "czBatumi", type = 2, zoneId = 670,
  x = -356734.48, y = 617270.72, radius = 4572,
  verticies = { {x = -359753.86, y = 614918.84}, {x = -355602.86, y = 622688.92},
                {x = -352849.44, y = 617192.50}, {x = -358731.76, y = 614282.63} },
  color = {1, 1, 1, 0.15}, hidden = false, properties = {} }
```

Two things follow. The list is spelled **`verticies`** — DCS's own typo, kept verbatim, because
"correcting" it writes a field DCS ignores. And `x`, `y` and `radius` **stay present** on a polygon, so
a polygon is not a circle with extra fields and reshaping does not strip the rest.

**`veafCombatZone` does handle a polygon.** `veafCombatZone.lua:1506-1510` branches on the zone type:
`0` → `mist.getUnitsInZones`, `2` → `mist.getUnitsInPolygon(triggerZone.verticies)`. But there is **no
`else`**: a zone of any other type leaves `units` empty and the combat zone finds nobody, silently.
That is worse than not offering the shape, so the action writes only types 0 and 2 — the answer to the
ticket's "or scope the action to what it handles".

**David's call on the vertex count (2026-08-12)**: accept three or more, since "follow the ridge line"
is the actual use case and mist handles any polygon — but **warn** whenever the count is not four,
because the DCS editor only draws quads and whether it preserves more is an in-game question.

### Tasks

- [x] Read a real quad/polygon zone from a `.miz` and record its exact shape in this ticket (above).
- [x] Confirm `veafCombatZone` handles a non-circular zone — it does, for type 2 only, and the action
      is scoped to that.
- [x] One `edit_zone` action covering the six kept verbs, backup-before-write like its siblings.
- [x] Catalogue doc updated in the same ticket (lockstep), plus the developer reference.
- [x] Tests: circle → polygon, move, resize, rename, link, remove — 31 cases, each asserting what
      landed **in the written archive** rather than in memory.

### Two open questions, decided

- **`zone-set-link` when the unit does not exist**: *refused*, not warned. A zone linked to nothing
  never follows anything, in silence, and the mission maker would be left inspecting the zone instead
  of the link. DCS links by `unitId`, so the id is resolved from the name here.
- **Renaming**: refused on a **collision** (zones are referenced by name from `mission.yaml`), and it
  **warns that references do not follow** — the combat zone's own entry and its member groups' name
  prefix both need doing by hand. Nothing here can see those references.

### Acceptance criteria

- [x] A zone can be reshaped, moved, renamed, linked and removed without deleting and recreating it.
      Moving a polygon carries its vertices, or the shape would stay behind while the centre moved.
- [x] A polygon zone the action creates is one `veafCombatZone` actually handles (type 2, via mist).
- [ ] 🧑 One editor check that a **non-quad** polygon survives a save, since the ME has no UI for it.
      Listed in `DCS-SESSION-TODO.md`.
- [x] `ruff` / `mypy` / `pytest` green; coverage gate bumped per the ratchet.

---

## 07 — F10 map drawings

Status: ✅ done 2026-08-12 — shipped as `add_map_drawing` / `edit_map_drawing`, **scoped to the three shapes that could be measured**
Type: feat
Files: a new `veaf_mission_mcp/map_drawings.py`, `actions.py`, the catalogue doc, tests

### Why

The triage keeps 13 of the 19 drawing verbs, because the sentence is real and recurring:

> *"Draw the FSCL and label the ingress corridor on the F10 map."*

Nothing in VMCT touches F10 drawings today. A briefing line, a corridor, a target ring, a no-fly box —
all of it is currently drawn by hand in the Mission Editor, and lost the moment a mission is
regenerated from its folder.

That last part is the argument for having it here rather than leaving it to the editor: **a drawing
placed by hand does not survive a rebuild**, while one an agent can place is part of the recipe.

### Behaviour

One action taking a **shape** parameter rather than nine `create-*` verbs — the triage rule is one action
per intent:

| Shape | Kept from |
|---|---|
| line, arrow | `drawing-create-line/arrow` |
| circle, oval, rect, polygon | `drawing-create-circle/oval/rect/polygon` |
| textbox, icon | `drawing-create-textbox/icon` |

> **`chevron` was in this table and does not exist.** David, 2026-08-15, with the editor open: *"chevron ?
> y'a pas ça"*. It came from the proposed verb list above rather than from the editor, and rode into
> `_UNMEASURED_SHAPES` — so the list whose job is to stop invented shapes was carrying one. Removed,
> with a test asserting its absence.

Plus `drawing-remove`, `drawing-set-pos`, `drawing-set-text`, `drawing-set-name`.

Rejected as low value: `drawing-set-angle/color/fill-color/thickness` — styling, which a caller can pass
at creation. Add one later if a mission maker asks; never speculatively.

### The five unmeasured shapes, measured — 2026-08-15

David drew one of each in the editor and saved (`tmp\bridge-maps\collect\bridge-Syria-editeur.miz`).
**There were five, not six**: no `chevron` tool exists, see the note above. Every one is a
`primitiveType: "Polygon"` distinguished by `polygonMode`, except the icon.

| Shape | `primitiveType` / `polygonMode` | Its own fields | Points |
|---|---|---|---|
| circle | `Polygon` / `circle` | `radius` | **none** |
| oval | `Polygon` / `oval` | `angle`, `r1`, `r2` | **none** |
| free | `Polygon` / `free` | — | `points`, first at `{0,0}` |
| arrow | `Polygon` / `arrow` | `angle`, **`length`** | `points` **as well** — 8 of them |
| icon | `Icon` | `file`, `scale`, `angle` | **none** |

All of them also carry the common set already known from line/rect/textbox: `name`, `layerName`,
`mapX`, `mapY`, `visible`, `colorString`, `thickness`, `style` (`"solid"`), plus `fillColorString` on
every `Polygon`. An `Icon` has `colorString` but **no** `fillColorString`; a `Line` has no fill either.

Two of the five are not the free win the others are:

- **`arrow` carries both `length`/`angle` and 8 `points`.** The editor stores the computed outline
  alongside the parameters, so writing the parameters alone produces an unknown result. Whether DCS
  recomputes the points on load is exactly the kind of thing to test with a round-trip rather than
  reason about.
- **`icon` needs a `file`** — the sample is `P91000007.png`, an opaque name from the editor's own icon
  set. Shipping `icon` means shipping a catalogue of valid names, or accepting one from the caller and
  refusing to validate it. That is a decision, not an implementation detail.

`circle`, `oval` and `free` are each a handful of fields and can ship as they are.

### Decide before implementing

- **Where do drawings live in the mission table?** `drawingLayers`, with per-coalition layers (Common,
  Red, Blue, Neutral, and the author layer). A drawing on the wrong layer is invisible to the pilots who
  need it and visible to the ones who should not see it — so the layer is a first-class parameter, not a
  default. Read a real `.miz` with drawings on several layers before writing.
- **Coordinates.** Drawings are positioned in mission-table `{x, y}` — read
  `docs/agents/dcs-coordinates.md` first, since a drawing at `y = altitude` lands a hundred kilometres
  away and nothing errors.
- **Does the editor prune what it does not recognise?** `FIX-MAPRESOURCE-KEY` and
  `FIX-COMMUNITY-SOUNDS-PRUNED` are both "the write looked right and the editor disagreed". Open the
  result in the real ME before calling this done.

### What the fixtures actually contain, and the scope that follows

Drawings were read across every `.miz` in the repository — two layers as the ticket asked (`Blue` in
`test/test.miz`, `Author` in `test/veaf-tools/test.miz`), and **three** primitive types in total:

```
('Line',    lineMode='segment')   3   points[] relative, closed, thickness, colorString, style
('Line',    lineMode='segments')  4   same, 3+ points
('TextBox', -)                    1   text, font='DejaVuLGCSansCondensed.ttf', fontSize, angle,
                                      borderThickness, fillColorString — NO points
('Polygon', polygonMode='rect')   1   width, height, angle, fillColorString, thickness — NO points
```

**The measurement that governs everything**: `points` are **relative to the drawing's `mapX`/`mapY`
anchor**, the first one being `{0, 0}`. A drawing written in absolute coordinates lands hundreds of
kilometres away and nothing errors. So the actions take absolute coordinates and anchor them
themselves — and moving a drawing becomes moving its anchor, with the shape following for free.

**Deliberate scope reduction, stated rather than slipped in.** The ticket lists nine `create-*` shapes.
Only three field layouts exist in this repository — line, rect, textbox — so `circle`, `oval`, `free`,
`arrow` and `icon` are **refused by name**, pointing at what does work. Inventing their
layout is exactly what the ticket's own "read a real `.miz` before writing" rule forbids, and what
`FIX-MAPRESOURCE-KEY` and `FIX-COMMUNITY-SOUNDS-PRUNED` already cost: a write that looks right and the
editor disagrees. The functional need is still met — `line` with `closed=true` outlines a free-form
area, and `rect` is the no-fly box.

Measuring the missing six needs one drawing of each made in the editor and saved; it is listed in
`DCS-SESSION-TODO.md`, and adding them afterwards is a table entry each.

### Tasks

- [x] Read a `.miz` carrying drawings on at least two layers; record the exact shape in this ticket.
- [x] One `add_map_drawing` action with a shape parameter and an explicit layer — never defaulted,
      since the layer decides which coalition sees it.
- [x] Remove, move, retitle and rename an existing drawing (`edit_map_drawing`).
- [x] Catalogue doc updated in the same ticket (lockstep), plus the developer reference.
- [x] Tests per shape, plus one asserting a drawing survives a read/write round trip — 40 cases,
      including the anchoring, which is the part that silently ruins a drawing.

### Acceptance criteria

- [ ] 🧑 A drawing placed through the action appears on the intended coalition's F10 map. Needs the
      game; listed in `DCS-SESSION-TODO.md`.
- [x] It survives a read/write round trip, which is the whole reason it is not left to the editor. The
      full folder → `.miz` rebuild is part of the same in-game check.
- [x] `ruff` / `mypy` / `pytest` green; coverage gate bumped per the ratchet.

---

## 08 — Capture the parking-slot data an aircraft needs to stand on a ramp

Status: ✅ done — tooling shipped 2026-08-12; Caucasus, Syria and PersianGulf captured, committed and
analysed 2026-08-15. **Ticket 09 is unblocked.**
Type: feat
Files: `veaf_libs/dcs_bridge_capture.py`, `veaf_tools/commands/capture_map.py`, locales, `test/python/`

Depends on: nothing. **Blocks** 09.

### Why this ticket exists at all

The triage filed `add_air_group` under 03 and left one question open: whether it
should exist, *"decided when 03 is picked up, with the composite in front of you rather than from
memory"*. Doing that turned up a hard dependency nobody had costed.

**A parked aircraft carries two different numbers.** Read out of `test/veaf-tools/test.miz`:

| Group | `parking` | `parking_id` | First waypoint |
|---|---|---|---|
| `Mustang4 F-14A` | 28 | **24** | `TakeOffParking` / `From Parking Area`, `airdromeId: 12` |
| `Elvis5 F-14A` | 1 | 1 | `TakeOff` / `From Runway`, `helipadId: 58` |

They match the runtime's `Term_Index` and `Term_Index_0` — and the first row proves they are **not**
interchangeable. So "put a two-ship on the ramp at Incirlik" needs that airfield's real slot ids, and
guessing them puts aircraft on the grass, on a taxiway, or inside each other.

Nothing in this repository holds them. `veaf_build/dcs_data/airbase_dumps/<theatre>.json` — 15
theatres, captured by David with the kit from `FEAT-AIRDROMES-RUNTIME-SOURCE` — carries exactly
`{id, name, lat, lon, coalition}` per airbase and no parking at all. The API schema shipped here
declares `AirbaseParking` with four fields, which is **already known to be incomplete** given the pair
above, so the shape has to come from the runtime rather than from the schema.

David's call (2026-08-12): do `add_air_group` properly, **with** the parking data.

### What ships in this ticket (done)

The capture side, so the only thing left is running it:

- `capture_parking()` runs `Airbase:getParking(false)` over the existing dcs-bridge and returns
  `{airbase id: [slot, ...]}`. It dumps **every key** each slot carries, flattening a nested table one
  level (`vTerminalPos.x`), and keeps values as **strings** — the point is to record what the runtime
  returns, not to interpret it. A test pins that an unknown future field survives, precisely because
  the schema is known incomplete.
- `write_parking_dump()` writes `parking/<theatre>.json`, a **separate** file: a large theatre has
  hundreds of airfields with dozens of slots each, and inflating a dump that 15 theatres already use
  would be a migration for no reason.
- `veaf-tools capture-map --parking` does both captures in one run, airbases **first**, so a maker who
  loses the slower second call still has the useful half. Its own longer timeout, and FR + EN strings.

### What is left, and it needs DCS

Exactly what `FEAT-AIRDROMES-RUNTIME-SOURCE` did for airbases — the kit makes it a five-minute job per
map, and **starting DCS is David's**:

```bash
veaf-tools capture-map --parking --out-dir veaf_build/dcs_data
```

- [x] 🧑 **Caucasus, Syria and PersianGulf captured 2026-08-15** by David — the three theatres this
      ticket named. Other maps can follow the same way; `tmp\bridge-maps\collect\` holds bridge
      missions for GermanyCW, MarianaIslands, Normandy and SinaiMap too.
- [x] Committed as `veaf_build/dcs_data/airbase_dumps/parking/Caucasus.json`, beside the airbase dump
      rather than in a sibling `parking/` folder, so the two files that share a key sit together.
- [x] **Shape recorded below, and it contradicts the table above**: `Term_Index_0` is `-1` on every
      slot, so `parking_id` does not come from this capture.

### The runtime shape, from a real capture — Caucasus, 2026-08-15

Captured by David with a bridge mission loaded, committed as
`veaf_build/dcs_data/airbase_dumps/parking/Caucasus.json`. **21 airfields, 942 slots**, between 7 and
94 per field. The file is `{theatre, parking_by_airbase}`, keyed by **airbase id as a string** — the
same ids as the airbase dump beside it (21 of 21 match), so a mission's `airdromeId` indexes straight
into it. Every value is a **string**, including the numbers.

A slot carries exactly eight keys:

```json
{"TO_AC": "false", "Term_Index": "43", "Term_Index_0": "-1", "Term_Type": "104",
 "fDistToRW": "1476.5401611328", "vTerminalPos.x": "-318191.53125",
 "vTerminalPos.y": "18.01001739502", "vTerminalPos.z": "635663.3125"}
```

**Syria and PersianGulf followed the same day.** Three theatres, and every structural property holds
across all of them:

| Theatre | Airfields | Slots | Keys matching the airbase dump | Field sets | `Term_Index_0` |
|---|---|---|---|---|---|
| Caucasus | 21 | 942 | 21/21 | 1 | `-1` ×942 |
| Syria | 225 | 4202 | 225/225 | 1 | `-1` ×4202 |
| PersianGulf | 30 | 1377 | 30/30 | 1 | `-1` ×1377 |
| **Total** | **276** | **6521** | **100 %** | **1** | **`-1` throughout** |

So the eight fields below are **the** shape, not one theatre's shape. Sizes are the part that varies:
7–94 slots per field on Caucasus, 1–195 on Syria, and no field anywhere reports zero.

#### `parking_id` is **not** `Term_Index_0` — the assumption above is wrong

`Term_Index_0` is **`-1` on all 6521 slots of all three theatres**, and `TO_AC` is `"false"`
throughout. Three theatres agreeing rules out a one-map accident. Yet the A-10 that flies at Kobuleti
declares
`parking: "43"` **and** `parking_id: "16"`, and David's own declares `6` / `"01"` — a zero-padded
string, which reads like the sign painted on the ramp rather than an index. **Ticket 09 must not
derive `parking_id` from this capture**; where it comes from is an open question, and guessing it is
what puts an aircraft on the grass.

`Term_Index` is the half that is confirmed: slot `43` exists at Kobuleti (airbase 24), which is the
one the working A-10 sits on.

#### The coordinate mapping, confirmed by superposition

The same slot's position matches the flying A-10's group **exactly**:

| | runtime slot | mission group |
|---|---|---|
| `vTerminalPos.x` | `-318191.53125` | `x` = `-318191.53125` |
| `vTerminalPos.z` | `635663.3125` | `y` = `635663.3125` |
| `vTerminalPos.y` | `18.01001739502` | `alt` = `18` |

So **mission `y` is runtime `z`**, and runtime `y` is the altitude — exactly the trap
`docs/agents/dcs-coordinates.md` warns about, here confirmed on real data rather than argued.

`Term_Type` is the **one** thing that is not stable, and each theatre carries a different subset:

| Theatre | `Term_Type` values, by frequency |
|---|---|
| Caucasus | `104` ×510, `68` ×340, `72` ×46, `16` ×42, `40` ×4 |
| Syria | `104` ×1893, `40` ×914, `68` ×469, `72` ×433, **`100` ×283**, `16` ×210 |
| PersianGulf | `104` ×710, `72` ×503, `40` ×92, `16` ×72 — **no `68` at all** |

`100` appears on Syria alone; `68` is on two maps out of three; `40` runs from 4 slots to 914. A
reader hard-coding one theatre's set drops the others' in silence. What the values mean is not
captured, and ticket 09 should not assume: filtering a slot by type without knowing which type
accepts an A-10 is the next silent failure in line.

### Careful

- `getParking(false)` asks for **every** slot, not just the free ones (`true` filters to available).
  An empty bridge mission has everything free, so the distinction does not bite today — but a capture
  run inside a populated mission with `true` would silently record a subset.
- A theatre whose airfields report no slots is **data, not a failure**: a WWII map may genuinely have
  none, and the capture accepts an empty result rather than raising.
- Slot ids are terrain data, so they change when ED reworks a map. That argues for recording the DCS
  version alongside a capture — not done, and worth deciding in 09 rather than guessing here.

### Acceptance criteria

- [x] `capture-map --parking` implemented, tested, documented in both locales.
- [ ] 🧑 At least one theatre captured and committed.
- [ ] 🧑 The runtime shape of a slot recorded in this ticket, from a real capture.

---

## 09 — `add_air_group`: a flight on the ramp, not a flight in a field

Status: ✅ done 2026-08-15 — `add_air_group` ships (parking/runway/air starts, stand resolution from
the bundled capture, collision refusal). Blocker lifted in game the same day; a final multi-ship
in-game confirmation through the action itself is David's step.
Type: feat
Files: `veaf_mission_mcp/add_group.py` (or a sibling), `actions.py`, the catalogue docs, `test/python/`

Depends on: 08 (parking slots per airfield). Split out of
03 on David's call, 2026-08-12.

### The use case

> *"Put a two-ship of F-16s on the ramp at Incirlik."*

`add_group` today inserts a **ground/vehicle** group. An aircraft group is different in kind, not in
degree: it needs a first waypoint that says *how it starts* — and DCS has four ways of starting, each
with its own waypoint shape, which is where a plausible-looking write goes wrong.

### What was measured before this ticket was written

From `test/veaf-tools/test.miz`, two real player flights:

```
Mustang4 F-14A   unit.parking = 28, unit.parking_id = 24
                 route.points[1] = { type = "TakeOffParking", action = "From Parking Area",
                                     airdromeId = 12, alt = 43, ETA_locked = true }

Elvis5 F-14A     unit.parking = 1,  unit.parking_id = 1
                 route.points[1] = { type = "TakeOff", action = "From Runway",
                                     helipadId = 58, alt = 0, ETA_locked = true }
```

Four things follow, and each is a way to get it wrong:

1. **The two parking numbers differ** (28 vs 24). Both are written, and inventing either puts the
   aircraft somewhere nobody asked for. This is what blocks the ticket on 08.
2. **`airdromeId` and `helipadId` are alternatives**, not synonyms: a real airfield uses the first, a
   carrier or FARP the second. Writing both, or the wrong one, is a mission the editor may open and
   DCS may not fly.
3. **`ETA_locked` is `true` on the first waypoint of both.** `FIX-WAYPOINTS-ETA-LOCKED` established
   why: DCS **refuses to save** a mission whose route has no locked-time waypoint, and the fix there
   was to lock the first when nothing else is locked. A generated route must do the same.
4. **The start altitude is not zero for a parked aircraft** (43 m at Incirlik's elevation, 0 for the
   runway case where DCS resolved it). Worth checking against the terrain elevation rather than
   hardcoding.

### The blocker, and how it was lifted (2026-08-15)

**Lifted.** A witness mission placed three A-10s at Kobuleti stands 42/41/40 using the capture's exact
`vTerminalPos` and `parking`=`Term_Index`, with `parking_id` set **equal to `parking`** (deliberately
not the editor's own value), beside the demo's known-good A-10 at stand 43. David loaded it: all three
parked correctly on their stands and were takeable. So **`parking_id` is not load-bearing when the
position and `parking` are exact** — DCS seats the aircraft from the position, and `parking_id` can be
set to `parking`. The capture (position + `Term_Index`) is therefore sufficient to synthesise a ramp
start, no editor-internal value needed. The investigation's step 1 (correlate the real `parking_id`)
is moot and is not pursued.

### The blocker as first measured — `parking_id` is not in the capture (2026-08-15)

Ticket 08 flagged it; picking 09 up confirmed it hard. A ramp start needs **both** `parking` and
`parking_id`, and they differ (Kobuleti A-10: 43 / 16). The committed capture gives one and not the
other:

- **`parking` = `Term_Index`** — confirmed: the stand whose `Term_Index` is 43 sits at the flying
  A-10's exact position (`vTerminalPos.x/z` match to the millimetre, `.y` = its altitude).
- **`parking_id` is nowhere in the capture.** `Term_Index_0` is `-1` on all 6521 slots of all three
  theatres. The ordinal hypothesis fails (Term_Index 43 is the 1st entry, not the 16th). Across
  `test.miz`'s ~90 parked flights the `parking`→`parking_id` pairs have no derivable function — the
  same airfield (id 24) carries 28→01, 32→05, 35→08, 36→09, 23→17, 4→40. No code in the repo derives
  it either; every caller supplies it by hand.

So the position is exact and `parking` is known, but `parking_id` — likely the terminal index DCS
actually binds to — cannot be synthesised from the data we hold. Inventing it is exactly what this
ticket and 08 forbid.

**David's call (2026-08-15): investigate `parking_id` in a DCS session before building.** The
investigation is specified in `DCS-SESSION-TODO.md`. Two things it must establish:

1. **Where `parking_id` comes from** — place 3-4 aircraft by hand on known stands at one airfield,
   save, read each `(parking, parking_id)`, and correlate against the capture's `Term_Index` and
   position. Either it maps to something we can capture (then extend ticket 08's capture to dump it),
   or it is editor-internal and must be obtained another way.
2. **Whether it is load-bearing given an exact position** — build a mission (via `add_player_slot`)
   with the captured position + `parking`, and `parking_id` set equal to `parking`, load it, and see
   whether the aircraft parks on the intended stand. If DCS snaps to the position regardless, a ramp
   start needs no true `parking_id` and 09 is unblocked as-is; if it repositions or refuses, 09 needs
   the real value from step 1.

Until then, only the start types that need **no** parking spot are buildable here (air, runway) — and
`add_player_slot` already covers the single-slot air case, so there is little to ship before the
blocker lifts.

### Decided while doing it (2026-08-15)

- **Distinct action, not `create_cap_mission`, and not folded into `add_player_slot`.**
  `create_cap_mission` makes a Late-Activation *template* wired into VEAF's on-demand system;
  `add_air_group` places a concrete flight *physically on the ramp* at mission start — a different
  purpose. `add_player_slot` places one aircraft when the caller already knows the spot; `add_air_group`
  places a flight and *resolves* the spots by airfield name. So it ships as its own action.
- **A stand is chosen by "nearest to the runway among the free ones."** The capture *does* report
  `fDistToRW`, so the default is deterministic and sensible; the caller may pass an explicit `parking`
  list to override. "Any free stand" is what auto-selection means, reading the mission's occupied
  stands to avoid them.
- **Collision is refused, naming the holder.** `_occupied_stands` scans aircraft groups whose first
  waypoint targets this airbase and collects their `parking`; a requested occupied stand is refused by
  name, and auto-selection skips them.

### Tasks

- [x] Aircraft group insertion with a correct first waypoint per start type: parking-cold,
      parking-hot, runway, air.
- [x] Parking stands resolved from the committed capture (slimmed + bundled as
      `veaf_libs/data/parking/<theatre>.json`, generated by `veaf-build update-dcs-data --parking`),
      refusing an unknown airfield / uncaptured theatre / unknown stand by name. Only terminal types
      104 and 68 are offered (measured), so an aircraft never lands on a runway threshold.
- [x] A stand already occupied in the mission is refused, naming the group that holds it; auto-select
      skips occupied stands.
- [x] `ETA_locked` honoured on the first waypoint, per `FIX-WAYPOINTS-ETA-LOCKED`.
- [x] Catalogue doc + developer reference updated in this ticket, both languages.

### Acceptance criteria

- [~] Round trip through the DCS Mission Editor with no complaint, **and** the flight starts where it
      was put — the placement mechanism (exact position + `parking`, `parking_id` = `parking`) is the
      one **already confirmed in game** on 2026-08-15 via the witness mission; a final multi-ship
      confirmation through `add_air_group` itself is David's step.
- [x] Tests per start type, plus the refusal paths (unknown airfield, uncaptured theatre, occupied
      stand, not enough free stands, air start without a position).
- [x] `ruff` / `mypy` / `pytest` green over the whole tree; coverage within the ratchet (81.47% ≥ 81%).
- **What happens on a collision?** Two groups on the same stand is a mission that loads with aircraft
  merged into one another. This action can see the mission it is writing to, so it can refuse — but
  only if the stands already taken are readable, which is the same data question.

### Tasks

- [ ] Aircraft group insertion with a correct first waypoint per start type: parking, runway, hot
      start, air start.
- [ ] Parking slots resolved from the committed capture, refusing an unknown airfield or slot by name
      rather than writing a number DCS will reinterpret.
- [ ] A stand already occupied in the mission is refused, naming the group that holds it.
- [ ] `ETA_locked` honoured on the first waypoint, per `FIX-WAYPOINTS-ETA-LOCKED`.
- [ ] Catalogue doc + developer reference updated in this ticket (the `docs-check` gate enforces the
      second one).

### Acceptance criteria

- [ ] Round trip through the DCS Mission Editor with no complaint, **and** the flight starts where it
      was put — the editor accepting a parking id is not proof DCS parks the aircraft there.
- [ ] Tests per start type, plus the refusal paths (unknown airfield, unknown slot, occupied slot).
- [ ] `ruff` / `mypy` / `pytest` green over the whole tree; coverage gate bumped per the ratchet.

---

## 10 — Ship the drawing shapes now that their layout is measured

Status: ✅ done 2026-08-15 — circle/oval/free ship (measured from bridge-Syria-editeur.miz); arrow and
icon stay refused, each with its own reason (arrow needs an in-game outline round-trip, icon needs an
icon-name catalogue).
Type: feat
Files: `src/python/veaf-tools/veaf_mission_mcp/map_drawings.py`, the mission-maker action catalogue
(both languages), tests

Depends on: 07, whose measurement table this spends.

### Why now

Ticket 07 shipped three shapes and refused five by name, on the rule that a field layout is read out
of a real `.miz` rather than invented. **That data now exists** — David drew one of each in the editor
on 2026-08-15 — so the reason for the refusal is gone for most of them.

### What ships, and what does not

- **`circle`** (`radius`), **`oval`** (`angle`, `r1`, `r2`) and **`free`** (`points`, relative to the
  anchor exactly like `line`): a handful of fields each, no open question. These ship.
- **`arrow`**: ships **only** if a round-trip settles the `points` question first — the editor stores
  `length` + `angle` **and** an 8-point outline. Write the parameters without the outline, save in the
  editor, and see whether DCS recomputes it. If it does not, the action must compute the outline, which
  is a different piece of work and deserves its own ticket rather than a guess.
- **`icon`**: does **not** ship here. It needs a `file` (`P91000007.png` in the sample), an opaque name
  from the editor's icon set, and nothing in this repository lists the valid ones. Shipping it means
  either a catalogue nobody has, or an unvalidated string that renders as nothing when wrong — the
  silent failure this whole ticket family exists to avoid. Keep it refused, and say why in the refusal.

### Careful

The refusal list is not decoration: `chevron` sat in it until 2026-08-15 and turned out not to exist.
Whatever stays refused must name a shape the editor actually draws, and the test added with that fix
asserts a shape is either shipped or refused, never both.

### TDD

- One test per new shape asserting the **exact** field set from the measured table, so a missing key
  fails rather than producing a drawing DCS drops.
- `free` anchors its first point at `{0,0}` like `line` — the anchoring bug this module was written to
  prevent, so it gets its own assertion.
- `icon` and `arrow` are still refused, each with a message naming its reason.

### Acceptance criteria

- [x] `circle`, `oval`, `free` ship, documented in both locales.
- [~] `arrow` **deferred** to its own future ticket rather than shipped or guessed: the editor stores a
      computed 8-point outline beside its `length`/`angle`, and whether DCS recomputes it needs a DCS
      round-trip nobody has run yet. Refused with that exact reason.
- [x] `icon` stays refused with a reason a maker can act on (needs a `file` from the editor's icon set,
      which nothing here enumerates).
- [x] Full Python gate green; coverage ratchet respected.
