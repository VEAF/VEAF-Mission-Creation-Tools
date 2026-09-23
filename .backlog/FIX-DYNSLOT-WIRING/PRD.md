# FIX-DYNSLOT-WIRING — the injection→warehouse chain wires templates to nothing

Status: 🔄 in-progress

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
| 01 | [Reallocate colliding ids at injection](tickets/01-reallocate-colliding-ids.md) | |
| 02 | [Wire the ship and FARP warehouses](tickets/02-ship-and-farp-warehouses.md) | |
| 03 | [Report what the wiring actually achieved](tickets/03-report-the-wiring.md) | |
| 04 | [The extraction normalizes positions (#984)](tickets/04-extraction-normalizes-positions.md) | |

Ticket 04 was drafted in lot 2 and pulled here on David's call: *"on va corriger l'extraction,
l'injection, et tester dans une mission"* puts extraction and injection in one movement, and both
ends need to be exercised by the same build.

## Out of scope

How a catalogue **reaches** a mission folder — the stale copy that nothing refreshes and `prepare`
laying down a 351 KB duplicate. That is [`FEAT-DEFAULTS-CATALOGUE-FLOW`](../FEAT-DEFAULTS-CATALOGUE-FLOW/PRD.md),
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
