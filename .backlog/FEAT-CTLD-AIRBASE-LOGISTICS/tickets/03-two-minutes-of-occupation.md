---
Status: 🔄 in-progress
---

# 03 — Class B: two continuous minutes of ground occupation

**Blocked by:** 02 — it reuses the tick, the state table and the activate/deactivate pair. Nothing to
wait for in 04: the map circle is drawn by the same transitions.

## What it delivers

Troops landed on a red or neutral airfield make it a logistic point **two minutes later**, and it stops
being one the moment the last of them withdraws or dies. Red is mirrored: red troops holding a field
that was blue do the same for their side. Both transitions are announced.

## Where

- The probe pattern `veafGrass.isSpotOccupied` already established (`veafGrass.lua:267-300`): a
  `world.VolumeType.SPHERE` volume, `world.searchObjects` called **once per category** under `pcall`,
  the answer decided in the callback.
- The tick and the state table from 02; `activateLogisticZone` / `deactivateLogisticZone`
  (`CTLD_zone.lua:1296`, `:1310`).

## Do

- Class B is a registered airfield whose snapshot (01) was **not** the coalition that holds it now,
  plus every airfield 02 moved out of class A. It is the only class that costs a spatial query: class A
  is decided by `getCoalition()` alone.
- Probe a sphere of **2000 m** around the zone's own point, `Object.Category.UNIT` only, and count an
  object as holding the field when all of these hold:
  - `object:isExist()`;
  - `object:getCoalition()` is the coalition in question — the test happens **in the callback**, since
    `searchObjects` does not filter on coalition;
  - `object:getCategoryEx() == Unit.Category.GROUND_UNIT` (`= 2` in the vendored schema,
    `dcs-world-api-schema.json:7268`). **Not `getCategory()`**: that returns an `Object.Category`, and
    `dcs_mocks.lua:611-613` records the trap by name — it looks like it answers "airplane or ground
    unit?" and does not.
- Never add `Object.Category.STATIC` to the loop. A FARP or an FOB built in flight near a captured
  field is a static, and counting statics would let one installation's logistics qualify the airfield
  beside it — and would let a maker's own crate hold a zone open. Never `SCENERY` either: scenery has no
  coalition, so a "no enemy here" test over it is meaningless.
- Two **continuous** minutes: a tick that finds nobody returns the field to "not yet" and clears the
  clock, rather than pausing it. At 30 s that is four consecutive ticks — assert it that way, with an
  injected clock, never by sleeping.
- The losing side keeps its zone only while it holds the field: an airfield is a logistic point for one
  coalition at a time, so the transition activates for the new holder and deactivates for the old one.
  Announce both, as 02 does.
- An unusable probe leaves the zone **as it was** and logs it. `isSpotOccupied` fails *open* —
  *"treating the spot as clear"* (`veafGrass.lua:281-298`) — and inheriting that direction here would
  make a logistic point flicker out on a DCS quirk, for a reason nobody can see in the mission.
- `searchObjects` matches an object's **position**, not its footprint (`veafGrass.lua:261`), so a
  unit straddling the 2000 m boundary counts by its centre. Accepted; write it into the documentation
  rather than trying to compensate for it.

## Watch out

- `dcs_mocks.lua:298` is `searchObjects = function(category, volume, fn) end` — it **never calls the
  callback**, so a test written against it today asserts nothing about occupation. Extend it to walk an
  injectable object list, call `fn` per object and record the `{category, volume}` it was given, in the
  style the file already argues for: *"what a spawner hands DCS **is** the behaviour under test, and
  asserting against a no-op stub asserts nothing"* (`:394-396`). `world.VolumeType.SPHERE` already
  exists (`:292`).
- Categories are queried **separately**: one call per `Object.Category`, not one call with a list. A
  loop over a single category keeps the cost visible, which is the point of restricting this to class B.
- The probe runs for class-B airfields and for active class-B zones being checked for a withdrawal —
  not for the whole theatre, and not for class A. On a typical mission that is a handful of airfields.
  If the log shows it running for sixty, the filter is wrong.
- A transport that lands on a captured field is an aircraft: it must **not** start the clock on the zone
  it landed to use. That falls out of `GROUND_UNIT`, and it is worth an explicit test because it is the
  case a pilot will actually hit.
- Coverage floor and stylua, as in 01.

## Done when

- In flight: blue ground troops on a red airfield make it a logistic point two minutes later, announced
  to both sides; destroying the last of them removes it, announced; a lone blue aircraft parked on the
  same field never starts the clock; red troops on a blue field behave identically for red.
- Lua tests assert, against the extended `searchObjects` mock: activation after four consecutive
  positive ticks and not after three; the clock cleared by one empty tick; an aircraft ignored; a static
  ignored; scenery never queried; the probe queried for class B only; a raising `searchObjects` leaving
  the zone as it was.
