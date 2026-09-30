# FIX-DYNSLOT-WIRING — the injection→warehouse chain wires templates to nothing

Status: ✅ done · archived 2026-09-28

Opened 2026-09-22, from a mission maker (Tripack) reporting that the F-14B(U) is not offered in
dynamic slots on a build with `dynamic_slot_templates: true`. His own case is not settled — it needs
his mission folder — but measuring the chain to answer him surfaced four defects that are real
regardless, and that share the same failure shape: **one aircraft type is silently missing while the
others work**.

## Measured

### 1. The injector never reallocates ids

`AircraftGroupsInjectorWorker._prepare_injected_group` copies the catalogue's `groupId` and `unitId`
verbatim. There is no renumbering anywhere in `src/python/` (`grep` for renumber / next_group_id /
max_group_id / allocate_group_id: nothing). The shipped catalogues sit in a low band while a real
mission occupies the whole range:

| catalogue | groups | `groupId` range | `unitId` range |
|---|---|---|---|
| `dynamic-slot-templates.yaml` | 128 | 145–544 | 18–629 |
| `spawnables.yaml` | 51 | 47–152 | 47–208 |

Collisions measured after injecting the dynamic-slot catalogue:

| target mission | groups | max `groupId` | duplicate `groupId` | duplicate `unitId` |
|---|---|---|---|---|
| `test/veaf-tools/aircrafts-injector/test-import.miz` | 225 → 353 | 3829 | **6** | **11** |
| `VEAF_OpenTraining_Caucasus_v6_20260715.miz` | 301 | 3897 | **4** / 128 | **9** / 128 |
| a mission built from `prepare --theatre Caucasus` | 51 → 179 | — | 0 | 0 |

The two shipped catalogues also collide **with each other** on 4 `unitId`, on every mission that
injects both.

And the ids are one space shared by **every** category. The first version of the fix scanned
`plane` and `helicopter` only, the two the injector writes into; the review measured what that
left behind — **8 `groupId` and 5 `unitId`** still colliding, with vehicles and statics, the same
figures on `test-import.miz` and on Open Training Caucasus. The scan now enumerates
`GROUP_CATEGORIES` rather than naming categories by hand.

A blank mission shows nothing, which is why no test caught this: the defect needs a populated
mission. When the duplicate lands on a template, `linkDynTempl: <id>` designates two groups, only one
of which is a `dynSpawnTemplate` — and that type alone stops being offered.

### 2. Ship and FARP warehouses are never touched

`apply_warehouses` iterates `warehouses.airports` only. DCS keeps a second section,
`warehouses.warehouses`, for ships and FARPs — and dynamic slots work there too. On the fully built
`test-import.miz`:

| section | entries | `linkDynTempl` | pointing at a group that does not exist |
|---|---|---|---|
| `airports` | 21 | 832 | **0** |
| `warehouses` (ships, FARPs) | 41 | 69 | **69** |

Nine of those 41 carry stock. Nothing in the pipeline stocks them, links them, or cleans their dead
links. For a carrier-based airframe this is the whole answer on its own.

### 3. The extraction copies the source mission's coordinates (#984)

`AircraftGroupsExtractorWorker._clean_group_data` removes `radio` and `Radio` and nothing else, so
`x`/`y` come out as they were in the source mission — group level, unit level and every route
point. The proof is in our own shipped file: `veafSpawn-MQ9 - AFAC - JTAC - DRONE` sits at
x = −250 000, y = −360 000. The 128 dynamic-slot templates are at (0,0) only because the
2026-09-21 graft normalized them by hand.

### 4. Nothing counts what the wiring achieved

Every number above was obtained by writing a script. The build says `Warehouses : 13 aéroports
configurés, 832 liens de modèle` and stops there — it never reports a `linkDynTempl` that points at
nothing, and it never notices the opposite case either. On a mission built straight from
`prepare --theatre Caucasus --template standard`, the build injects **128 templates** and then prints
`Warehouses : 0 aéroports configurés, 0 liens de modèle`: a blank mission has all 21 airfields
NEUTRAL, so not one dynamic slot is playable and nothing says so.

## Scope

| # | ticket | |
|---|---|---|
| 01 | [Reallocate colliding ids at injection](FIX-DYNSLOT-WIRING.md) | |
| 02 | [Wire the ship and FARP warehouses](FIX-DYNSLOT-WIRING.md) | |
| 03 | [Report what the wiring actually achieved](FIX-DYNSLOT-WIRING.md) | |
| 04 | [The extraction normalizes positions (#984)](FIX-DYNSLOT-WIRING.md) | |

Ticket 04 was drafted in lot 2 and pulled here on David's call: *"on va corriger l'extraction,
l'injection, et tester dans une mission"* puts extraction and injection in one movement, and both
ends need to be exercised by the same build.

## Out of scope

How a catalogue **reaches** a mission folder — the stale copy that nothing refreshes and `prepare`
laying down a 351 KB duplicate. That is [`FEAT-DEFAULTS-CATALOGUE-FLOW`](FEAT-DEFAULTS-CATALOGUE-FLOW.md),
sequenced after this one. Split on purpose rather than by taste: Sourcery stops reviewing past
~150 000 diff characters, and lot 2 carries a new command plus its two documentation pages.

## Definition of done

- No duplicate `groupId` or `unitId` in a mission after injection, measured on the built `.miz` read
  back from disk — not on the in-memory structure, which is how the first measurement in this
  investigation managed to be wrong.
- `linkDynTempl` on ships and FARPs resolves to a real template, or is removed.
- The build reports both failure shapes: a link that points at nothing, and templates injected with
  no airfield to offer them from.
- An extracted catalogue carries no position from the mission it came from.

## Verified

End to end through the CLI, on a mission folder whose `src/mission` is the 225-group
`test-import.miz`, reading the built `.miz` back from disk:

```
!17 identifiant(s) déjà utilisés par la mission cible ont été réattribués   (spawnables)
!19 identifiant(s) déjà utilisés par la mission cible ont été réattribués   (dynamic-slot templates)
Warehouses : 13 aéroports configurés, 40 navires/FARP, 1537 liens de modèle.
```

388 aircraft groups and 755 groups all categories taken together, **0** duplicate `groupId`,
**0** duplicate `unitId`, 128 templates, 1537 links and
**0** of them dangling — against 6/11 duplicates and 69 dangling links before. Five objects stock
planes, which is exactly the five aircraft carriers; the other 35 ships and FARPs stock
helicopters only.

---

## Tickets, in full

## 01 — Reallocate colliding ids at injection

Status: ✅ done

### Problem

`AircraftGroupsInjectorWorker` writes the catalogue's `groupId` and `unitId` into the target mission
unchanged. The catalogues live in a low id band (145–544 and 47–152); a real mission occupies the
whole range up to ~3900. Measured: 6 duplicate `groupId` and 11 duplicate `unitId` on
`test-import.miz`, 4 and 9 on the Open Training Caucasus mission, and 4 `unitId` shared between the
two shipped catalogues on any mission that injects both.

A duplicate `groupId` on a template makes `linkDynTempl` ambiguous, and that aircraft type alone
stops being offered.

### Decision

Reallocate **only on collision** (option b, chosen by David on 2026-09-22), not systematically.

Reallocating every injected id would be simpler to reason about but would change all 128 template
ids on every build, so the `.miz` would differ wholesale from one build to the next, and in
`mode: replace` the ids would creep upward indefinitely.

The delicate part is `mode: replace`: the group being replaced must **not** count itself as taken,
or it reallocates itself on every build.

### Work

- Before the injection loop, index the ids the target mission already uses, and their maxima —
  across **every** group category, enumerated from `GROUP_CATEGORIES`. DCS shares one id space:
  scanning only `plane` and `helicopter` left 8 `groupId` and 5 `unitId` colliding with vehicles
  and statics, measured on two real missions.
- Per injected group: keep its id if free; otherwise allocate `max + 1` and bump the counter, so two
  injected groups cannot collide with each other either.
- Same for each `unitId`.
- In `mode: replace`, exclude the group being replaced from the taken set.
- Log how many ids were reallocated (detail level, not a warning: this is normal operation).

### Tests

The one that proves the bug is fixed is not about id uniqueness, it is about the link surviving:
after injection **and** `apply_warehouses`, every stocked type's `linkDynTempl` must designate
exactly one group, and that group must be a `dynSpawnTemplate` of the right type. It fails today.

Around it:

- ids are unique after injection, asserted on a mission whose own ids cover the catalogue's band;
- a catalogue id that is free stays unchanged (minimal diff);
- `mode: replace` run twice does not move the ids the second time;
- injecting `spawnables.yaml` then `dynamic-slot-templates.yaml` leaves no duplicate — the 4 shared
  `unitId` are the regression case.

Assert on the mission read back, not on the constant or the in-memory structure.

---

## 02 — Wire the ship and FARP warehouses

Status: ✅ done

### Problem

`apply_warehouses` iterates `warehouses.airports` and nothing else. DCS keeps ships and FARPs in a
second section, `warehouses.warehouses`, and dynamic slots work there — the worker's own docstring
says so.

Measured on the fully built `test-import.miz`: `airports` ends with 832 links and **0** pointing at
a missing group; `warehouses` keeps its 69 links, **all 69** pointing at a group that does not
exist. Nine of its 41 entries carry stock. Nothing in the pipeline stocks them, links them, or
cleans the dead links a previous build left behind.

For a carrier-based airframe — the F-14 being exactly that — this is a complete explanation on its
own, independent of every other defect in this lot.

### Open question, to settle before writing

`warehouses.yaml` only has an `airports:` key today, and an airport is designated by name (resolved
through the theatre) or by numeric id. A ship or a FARP has neither: the section is keyed by the
**unit id** of the carrying object, which is not something a mission maker reads off the Mission
Editor.

To look at before proposing: what the Mission Editor exposes as a handle, and whether the carrying
group/unit **name** can be resolved to that id from the mission table (it can be, for groups the
mission owns — the unit id is in `units[].unitId`). If it can, the config key should be the name.

Proposal to confirm with David once measured:

```yaml
blue:
  defaults: { fuel: unlimited, weapons: unlimited }
  ships:            # optional; absent -> every ship/FARP of this coalition
    CVN-75: {}
```

Falling back to the numeric unit id, as `airports:` already allows, for anything that cannot be
named.

### Work

- Extend `apply_warehouses` to the second section, reusing `_apply_to_airport` where the shape is
  identical (`dynamicSpawn`, `allowHotStart`, fuel/munitions, stock, `linkDynTempl`).
- Resolve a ship/FARP by carrying-unit name, else by id.
- Do **not** apply the parking filter there: `parkable_kinds` is keyed by airfield id and means
  nothing for a ship. A carrier parks planes and helicopters; a FARP parks helicopters. Establish
  which by measuring rather than assuming, and write down what was measured.
- Clean a `linkDynTempl` that points at nothing, the same way the airport path already ends up doing
  by overwriting.

### Tests

- A mission with a carrier and a FARP: both get `dynamicSpawn`, stock and a link that resolves.
- A coalition not declared leaves its ships untouched.
- A pre-existing dead link on a ship is gone after the step.
- Naming a ship by its unit name and by its numeric id reach the same entry.

---

## 03 — Report what the wiring actually achieved

Status: ✅ done

### Problem

Every defect in this lot was found by writing a throwaway script. The build prints
`Warehouses : 13 aéroports configurés, 832 liens de modèle` — a count of what it *wrote*, never a
check of whether it *works*. Two failure shapes pass through silently:

1. **A link that points at nothing.** `linkDynTempl: 3853` where no group carries that id. The
   Mission Editor renders it as `Group template: None` and the mission maker has no reason to read
   it as a defect. Measured: 69 such links survive a full build today, all in the ship/FARP section.

2. **Templates with nowhere to be offered from.** A mission built straight from
   `prepare --theatre Caucasus --template standard` injects **128 templates** and then prints
   `Warehouses : 0 aéroports configurés, 0 liens de modèle`. Every one of the 21 airfields is
   NEUTRAL, so no dynamic slot is playable. The build says nothing; the maker gets 128 groups in his
   mission and no way to use them.

Both are cheap to detect at the exact moment the pipeline already holds the data.

### Work

After the warehouses step, walk both warehouse sections and the mission's groups once:

- count `linkDynTempl` values that resolve to no group, or to a group that is not a
  `dynSpawnTemplate`, and **warn** with the count and the first few types;
- when templates were injected and the step configured zero airfields, **warn** saying why (no
  airbase belongs to a coalition) and what to do about it.

A warning, not an error: a mission may legitimately be built in an intermediate state.

### Tests

A check that cannot fail is not a check. Prove each one fires **and** stays quiet:

- a mission with a dead link → the warning fires, with the right count;
- the same mission after the fix of ticket 01/02 → silent;
- templates injected and no coalition airfield → the second warning fires;
- one coalition airfield → silent.

---

## 04 — The extraction normalizes positions (#984)

Status: ✅ done

Closes [#984](https://github.com/VEAF/VEAF-Mission-Creation-Tools/issues/984), reported on Discord
by The Reaper and filed by the support bot on 2026-09-22.

### Problem

`AircraftGroupsExtractorWorker._clean_group_data` removes `radio` and `Radio` and nothing else
(`PROPERTIES_TO_EXCLUDE`, line 1041). `x` and `y` survive, at group and unit level, so an extracted
catalogue carries the coordinates of the mission it came from — and those coordinates mean nothing
in another mission, let alone on another theatre.

The proof is in our own shipped file: `veafSpawn-MQ9 - AFAC - JTAC - DRONE` sits at x = −250 000,
y = −360 000. The 128 dynamic-slot templates are at (0,0) only because yesterday's graft normalized
them by hand.

### Decision

Normalize to **(0,0)**, group and unit level.

The issue asks for two different things: its title says "mettre les coordonnées à 0", its body says
"templates injectés au centre de la map". (0,0) is what the shipped catalogue already does, and on
Caucasus it is a real point on the map — north-west, 241 km west of the westernmost airfield,
measured against the bundled parking data. The map centre would need theatre bounds, which this
repository does not hold; it ships airfield positions and nothing that delimits a theatre.

A template is never spawned where it stands — it is late-activated, hidden, and referenced by name —
so the position is a placeholder. What matters is that it is the **same** placeholder everywhere and
carries nothing from the source mission.

Answer in the issue why not the map centre, so the reporter gets the reasoning rather than a silent
partial fix.

### Work

- Zero `x`/`y` on the extracted group and on each of its units.
- Leave `alt`, `heading`/`psi`, speeds and the route alone — only the position is mission-specific
  in a way that travels badly. Route points already carry their own `x`/`y`: zero those too, and say
  in the code why (a route point inherited from another mission is the same defect one level down).

### Tests

- Extract from a mission whose groups sit at real coordinates → every `x`/`y` in the output is 0.
- The rest of the group is byte-identical to what the extractor produces today.
- Round-trip: extracting the shipped catalogue back out changes nothing (it is already at 0).

---
