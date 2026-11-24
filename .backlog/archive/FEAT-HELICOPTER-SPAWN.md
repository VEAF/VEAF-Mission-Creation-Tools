# FEAT-HELICOPTER-SPAWN — spawn a helicopter group from a marker, without a mission template

Status: ✅ done — merged in #1050 (2026-10-03); every task read in game (R23–R33) · archived 2026-11-24

Origin: [#164](https://github.com/VEAF/VEAF-Mission-Creation-Tools/issues/164) (David, 2023-01). Opened
2026-10-02 from a sweep of the open issues against the backlog: #164 had been sent to
`CHORE-ISSUE-VERIFY-SESSION` on 2026-08-18 as *"probably already done, needs a check"*, but that lot's
archive never mentions it, so the check never ran. Reading the code settles it without DCS: **it is not
done**, and the 2026-08-18 comment on the issue rests on a wrong reading.

## What the code says (2026-10-02, `develop` at `12bedb8f`)

- **`_spawn unit` refuses every aircraft.** `veafSpawn.spawnUnit` returns early on `unit.air and not
  static` with *"Air units cannot be spawned at the moment (work in progress)"* (`veafSpawnAircraft.lua:74`,
  i18n key `spawn.air_wip`). `test_spawnUnit_air_no_static` (`test/lua/test_veafSpawn.lua:1559`) pins that
  refusal. Only `static` gets an aircraft on the map, and a static does not fly.
- **`_spawn group` has nothing to spawn.** `veafUnits.GroupsDatabase` is filled from
  `veaf_libs/data/veaf-units.yaml`, which names none of the 26 helicopter types of `dcsUnits.lua` — neither
  as a unit alias nor inside a group.
- **The group path would file a helicopter as an airplane.** Were a group to contain one,
  `veafSpawn.doSpawnGroup` submits every air group with `category = "AIRPLANE"` (`veafSpawnCore.lua:822`),
  as `spawnUnit` does with `"PLANE"` (`veafSpawnAircraft.lua:191`), although `veafUnits` carries the DCS
  category (`"Helicopter"`) on every unit it resolves. Same family as FIX-MCP-AIRCRAFT-CATEGORY, on the
  runtime side. What DCS does with a helicopter submitted under `Unit.Category.AIRPLANE` is **not
  measured**. The same path also gives an air unit `speed = 0`, the ground height as `alt` and no route.
- What the 2026-08-18 comment cited as proof — `veafUnits.lua` handling `unit.air` — is the spawn-position
  check, which only asks whether the point is under the terrain.

**Helicopters do spawn when the Mission Editor holds them.** David, 2026-10-02: the Caucasus Open Training
v5 spawns one with a combat zone — `combatZone_SaveTheHostages-Prohladniy-CAS-helo`, a CAS group filed under
`helicopter` in the mission, activated with *Hostages at Prohladniy*. In v6 the zone rebuilds an element from
its editor record, whose category (`helicopter`) reaches `veafDcsSpawner.addGroup`, and
`test_veafDcsSpawner.lua:472` pins that a `HELICOPTER` group is submitted as such. That is by construction,
not seen in game in v6. So the gap is only the **marker** path, with no editor group behind it. The other
routes are a late-activated editor group, or a `-cap` template (whether `-cap` accepts a helicopter template
is not verified).

## Direction (David, 2026-10-02)

**A helicopter goes through the ground spawn, not the air one**: a unit or a group of `veaf-units.yaml`,
spawned by `_spawn unit` / `_spawn group` through `veafSpawn.doSpawnGroup` and `veafSpawn.spawnUnit` — the
path `-arty` takes — and **not** a `veafSpawn-` template cloned by `veafAircraftSpawn` as `-cap` is. So no
template in the mission, and no role from `veafAircraftSpawn.roles` (which only knows `cap` and
`zone_defense`).

What that path has today, and what it lacks for a helicopter:

| Piece | Today | Needed |
|---|---|---|
| Refusal in `spawnUnit` (`veafSpawnAircraft.lua:74`) | every `unit.air` | lifted for helicopters, kept for airplanes |
| Category submitted to DCS | `AIRPLANE` / `PLANE`, hard-coded | `HELICOPTER`, from the unit's DCS category (`"Helicopter"`) |
| Units and groups in `veaf-units.yaml` | none of the 26 helicopter types | the aliases and groups to ship |
| Altitude, speed, route | ground height as `alt`, `0`, no route — `veafDcsSpawner.addGroup` then marks the altitude `RADIO`, so the ground height above sea level becomes a height **above the ground** | a helicopter that stays landed where the marker is |

## Open questions

1. **How does DCS keep a scripted helicopter on the ground?** Not measured. The candidates are a single
   waypoint of type `TakeOffGround` (cold) or `TakeOffGroundHot` (rotors running) at the spawn point, or
   `uncontrolled = true`. Each needs a reading in game: does it stay put, does it take off, does it fall.
   The measurement mission is built — `DCS-SESSION-TODO.md` **R23**, five variants side by side.
   **Answered 2026-10-02 (R23)**: only `uncontrolled = true` with a `TakeOffGround` point keeps it on the
   ground. A cold `TakeOffGround` alone starts at T+80 s and takes off at T+278 s; `TakeOffGroundHot` takes
   off at T+11 s; no route at all hovers. And today's `_spawn group` is **refused** by DCS
   (`Invalid Unit Module: "Mi-8MT"`) — the hard-coded `AIRPLANE` category, measured.
2. **What does it do?** Sit there as a target (the `-arty` analogy), or take off once it exists. Sitting
   still is the smallest useful case and needs no route beyond the first point.
3. **Armed or not?** A unit of `veaf-units.yaml` carries no payload, so a spawned Mi-24 has empty pylons.
   Fine for a target or a transport; a gunship would need a payload field in the catalogue.
4. **Which aliases?** The helicopters to ship, per side.

## Design (validated by David, 2026-10-02)

David, 2026-10-02: *"il faut qu'on puisse donner du travail à ces hélicos, sinon ils ne servent que de
cible"* — patrol, transport, attack, and a static one circling its point.

### What the code and the catalogue already give

- **Armed or not is a loadout, not a type.** DCS files Mi-8MT, Mi-24P and UH-1H as *both* `Attack
  helicopters` and `Transport helicopters` (`dcsUnits.lua`), so the type cannot decide. What decides is
  whether the helicopter carries weapons — and the shipped `dynamic-slot-templates.yaml` already holds a
  loadout for AH-64D, Ka-50, Mi-24P, Mi-8MT, SA342M and UH-1H.
- **The marker already has the words for a route**: `dest` (repeatable, an itinerary, named points) and
  `patrol` (loop back), both read by `veafSpawnParser.lua` for convoys.
- **Getting off the ground is measured** (R23): spawned on its point with one `TakeOffGroundHot` waypoint
  it is airborne in 11 s; with `TakeOffGround` + `uncontrolled` it stays put.

### The jobs

| `task` | Armed helicopter | Unarmed helicopter |
|---|---|---|
| *(none)* | landed, engine off, `uncontrolled` — a target (R23 variant E) | same |
| `orbit` | circles its point (`Orbit`, `Circle`), weapons free on what comes in range | circles its point, weapons hold |
| `patrol` | circuit around its point or along its `dest` points, engaging ground units and helicopters in a radius (`EngageTargetsInZone`) | shuttles base ↔ `dest`, landing at each end for a few minutes and going round again — the resupply run |
| `transport` | flies to `dest` and lands there, returning fire only | same |
| `attack` | flies to `dest` and engages ground units and helicopters in a radius there, then orbits | refused: nothing to attack with |
| `escort` *(proposed addition)* | follows a ground group named by `dest` and covers it (`GroundEscort`) — pairs with VEAF convoys | refused |

Defaults, all overridable on the marker: altitude 150 m above the ground, speed 40 m/s, engagement
radius 3 km, 5 minutes on the ground at each end of a shuttle. **None of the DCS tasks above is measured
on a scripted helicopter yet** — each role needs its own in-game reading, the way R23 read the ground.

### How it fits together

- **The catalogue** (`veaf-units.yaml`): an alias names a type and, optionally, a loadout taken from the
  shipped dynamic-slot template of that type — `mi24` armed, `mi8` unarmed, `mi8-rockets` armed.
- **The spawn**: the ground path (`_spawn unit` / `_spawn group`), submitted under `HELICOPTER`.
- **The job**: a `task` keyword on the marker, handed to a role that builds the route. Either a role
  table local to the helicopter spawn, or new entries in `veafAircraftSpawn.roles` (`buildRoute` /
  `afterSpawn`), the registry FEAT-AIRCRAFT-ROLES created for the QRA and `-cap` — to decide.

### Tickets, one PR

02 spawn landed (category, `uncontrolled`, the refusal lifted) · 03 catalogue aliases and loadouts ·
04 `orbit` and `transport` · 05 `patrol` · 06 `attack` and `escort` · 07 the in-game readings, one per role.

### Decisions (David, 2026-10-02)

- **a.** Armed or not is decided by the **alias**: an alias names a type and, optionally, the pylons of
  the shipped dynamic-slot template of that type.
- **b.** With no `task`, the helicopter stays landed as a target.
- **c.** `escort` is in, last.
- **d.** The jobs are roles of the `veafAircraftSpawn.roles` registry.
- **e.** One lot, one PR; a checkpoint after ticket 04 for a first in-game reading.

## Tickets

| # | Ticket | Status |
|---|--------|--------|
| 01 | [record the limitation](FEAT-HELICOPTER-SPAWN.md) | ✅ |
| 02 | [spawn a helicopter landed](FEAT-HELICOPTER-SPAWN.md) | ✅ |
| 03 | [catalogue aliases and loadouts](FEAT-HELICOPTER-SPAWN.md) | ✅ |
| 04 | [`orbit` and `transport`](FEAT-HELICOPTER-SPAWN.md) | ✅ |
| 05 | [`patrol`](FEAT-HELICOPTER-SPAWN.md) | ✅ |
| 06 | [`attack` and `escort`](FEAT-HELICOPTER-SPAWN.md) | ✅ |
| 07 | [the in-game readings](FEAT-HELICOPTER-SPAWN.md) | ✅ |

## Definition of done

- [x] The limitation in `known-limitations.yaml` (airplanes only, now).
- [x] #164 answered (2026-10-03), closed by the merge of #1050.
- [ ] A helicopter spawned from a marker in game for each task — R24 for `parked`, `orbit`, `transport`; 05–06 for the rest.

## Former index entry

The row this lot had in `.backlog/README.md` until the index was split into short summaries (CHORE-BACKLOG-INDEX-SPLIT, 2026-10-03), kept verbatim.

**helicopters spawned from a marker, with a job.** #164 was never done: `_spawn unit` refused every aircraft and `_spawn group` filed a helicopter as an airplane, which DCS refuses (measured, R23). The ground path now lands it as a target, or gives it a job from the `veafAircraftSpawn` roles — `orbit`, `transport`, `patrol`, `attack`, `escort` — armed or not by its alias's loadout

## Tickets, in full

## 01 — Record the limitation

Status: ✅ done — recorded (now `no-airplane-spawn-from-a-marker`, helicopters being fixed by this lot); the reply to #164 is drafted for David

Lot: [FEAT-HELICOPTER-SPAWN](FEAT-HELICOPTER-SPAWN.md)

##164 is not done (see the PRD). Until it is, an agent building a mission through the MCP must learn
that no aircraft can be spawned from a marker.

### Done when

- `known-limitations.yaml` carries a `kind: tool`, `area: runtime` entry saying so, with the working routes.
- The MCP action `describe_known_limitations` returns it (`docs/agents/dcs-runtime-traps.md` renders
  only `kind: dcs` entries, so it does not change).
- A reply to #164 is drafted for David to post, correcting the 2026-08-18 comment.

## 02 — Spawn a helicopter landed

Status: ✅ done

Lot: [FEAT-HELICOPTER-SPAWN](FEAT-HELICOPTER-SPAWN.md)

`_spawn unit, name <helicopter>` and `_spawn group, name <group of helicopters>` put the helicopter on the
ground at the marker, engine off, and it stays there (R23, variant E).

### What changes

- `veafUnits` marks a helicopter unit (`helicopter = true`, from the DCS category) and a group made of
  them; a helicopter is never placed on water.
- `spawnUnit` stops refusing helicopters (airplanes stay refused). Neither path applies the marker's
  `alt` to the spawn point of a helicopter: on a helicopter it is the job's altitude.
- Both paths hand the group to `veafAircraftSpawn.spawnHelicopterGroup`, which submits it under
  `HELICOPTER` with the route of its role. With no `task`, the role is `parked`: one `TakeOffGround`
  point and `uncontrolled = true`.
- A `dest` does not turn a helicopter group into a convoy.

### Done when

- Tests fail on the old code: the category submitted, the refusal, the `uncontrolled` flag, the point
  type, the altitude left alone.

## 03 — Catalogue aliases and loadouts

Status: ✅ done

Lot: [FEAT-HELICOPTER-SPAWN](FEAT-HELICOPTER-SPAWN.md)

### What changes

- `veaf-units.yaml` unit aliases may carry `pylons` (station → `{CLSID}`), copied from the shipped
  `dynamic-slot-templates.yaml`. An alias with pylons is **armed**.
- The spawn-data emitter renders those pylons, and a `veafUnits.AircraftPayloads` table — fuel, chaff and
  flare per helicopter type, from `dcsUnits.yaml` (`M_fuel_max`, `passivCounterm`). The runtime has no
  fuel data of its own, and an aircraft created without fuel falls (`aircraft_payload.py`).
- Shipped aliases: `mi8` (Mi-8MT), `mi26` (Mi-26), `uh1` (UH-1H), `ch47` (CH-47Fbl1) unarmed; `mi24`
  (Mi-24P), `ka50` (Ka-50_3), `ah64` (AH-64D_BLK_II), `gazelle` (SA342M) armed, with their template's pylons.

### Done when

- The emitter tests cover the pylons and the payload table; a test pins that every shipped helicopter
  alias gets a fuel load above zero.

## 04 — `orbit` and `transport`

Status: ✅ done — read in game 2026-10-02 (R24–R28): orbit holds 1.5–2 km out; transport lands 30 m from an open-ground point, hovers at a forest edge

Lot: [FEAT-HELICOPTER-SPAWN](FEAT-HELICOPTER-SPAWN.md)

A `task` keyword on the marker names the job; unknown words are refused with a message.

- `orbit`: takes off from the marker (`TakeOffGroundHot`, airborne in 11 s per R23) and circles it
  (`Orbit`, `Circle`) at `alt` above the ground (default 150 m) and `speed` (default 40 m/s). Armed:
  weapons free; unarmed: weapons hold.
- `transport`: takes off, flies to `dest` at that altitude and lands there (`Land`). Returns fire only.
  Refused without a `dest`.

### Done when

- Tests on the route each role builds, the options it sets, and the refusals.
- **Checkpoint**: David's in-game reading before 05.

## 05 — `patrol`

Status: ✅ done — read in game 2026-10-02 (R29–R31): the armed loop holds and engages a ground unit in its zone; the shuttle lands 16 m from `dest`, waits, and lands back home

Lot: [FEAT-HELICOPTER-SPAWN](FEAT-HELICOPTER-SPAWN.md)

- Armed: a circuit around the marker, or along its `dest` points, engaging ground units and
  helicopters within a radius (`EngageTargetsInZone`, default 3 km).
- Unarmed: a shuttle marker ↔ `dest`, landing a few minutes at each end (default 5), for ever.

## 06 — `attack` and `escort`

Status: ✅ done — read in game 2026-10-02: `attack` destroyed its tank (R31, R32), `escort` stayed within 3 km of a driving group, undamaged (R33)

Lot: [FEAT-HELICOPTER-SPAWN](FEAT-HELICOPTER-SPAWN.md)

- `attack` (armed only): flies to `dest`, engages ground units and helicopters within a radius there,
  then orbits.
- `escort` (armed only): follows the ground group named by `dest` and covers it (`GroundEscort`).
- Both refused for an unarmed helicopter, with a message.

## 07 — The in-game readings

Status: ✅ done — R23 to R33 in `DCS-SESSION-TODO.md`, 2026-10-02; three DCS behaviours recorded in `known-limitations.yaml` (`scripted-helicopter-leaves-the-ground`, `helicopter-land-waypoint-goes-to-the-nearest-airfield`, `helicopter-hovers-at-a-forest-edge`)

Lot: [FEAT-HELICOPTER-SPAWN](FEAT-HELICOPTER-SPAWN.md)

None of the DCS tasks the roles use is measured on a scripted helicopter. Each role gets a reading in
`DCS-SESSION-TODO.md`, with the outcomes that confirm and the ones that refute it — the landed spawn
and tickets 04's two roles at the checkpoint, 05 and 06 afterwards.
