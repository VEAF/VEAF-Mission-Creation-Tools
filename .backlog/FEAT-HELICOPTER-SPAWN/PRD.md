# FEAT-HELICOPTER-SPAWN — spawn a helicopter group from a marker, without a mission template

Status: ✅ done — merged in #1050 (2026-10-03); every task read in game (R23–R33)

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
| 01 | [record the limitation](tickets/01-record-the-limitation.md) | ✅ |
| 02 | [spawn a helicopter landed](tickets/02-spawn-a-helicopter-group.md) | ✅ |
| 03 | [catalogue aliases and loadouts](tickets/03-catalogue-aliases-and-loadouts.md) | ✅ |
| 04 | [`orbit` and `transport`](tickets/04-orbit-and-transport.md) | ✅ |
| 05 | [`patrol`](tickets/05-patrol.md) | ✅ |
| 06 | [`attack` and `escort`](tickets/06-attack-and-escort.md) | ✅ |
| 07 | [the in-game readings](tickets/07-in-game-readings.md) | ✅ |

## Definition of done

- [x] The limitation in `known-limitations.yaml` (airplanes only, now).
- [x] #164 answered (2026-10-03), closed by the merge of #1050.
- [ ] A helicopter spawned from a marker in game for each task — R24 for `parked`, `orbit`, `transport`; 05–06 for the rest.
