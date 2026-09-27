---
Status: ✅ done
---

# 01 — Register every airdrome as a CTLD logistic zone

**Blocked by:** none. This is the tracer bullet, and on its own it is the answer to #1007.

## What it delivers

A C-130 parked at Ramstein on GermanyCW v6 opens *Request Equipment* and gets a menu instead of
*"Aucune logistique à portée"*. Every airdrome of the theatre is a CTLD logistic zone from mission
start — with no CTLD change, no mission-file surgery and nothing spawned into the simulation.

## Where

- The stub to revive: `veafTransportMission.initializeAllLogisticInCTLD()`,
  `src/scripts/veaf/veafTransportMission.lua:688`. The comment above it (`:676-680`) states that a
  logistic point *is* an `LGZ_` zone declared in `ctld-config.yaml` with *"nothing to run"*; it stops
  being true in this ticket, so it is rewritten **here** rather than deferred to 05.
- The airbase list: `veafAirbases.Airbases`, an array built once from `world.getAirbases()`
  (`veafAirbases.lua:62`), `initialize()` idempotent (`:56-58`) and already run at load (`:449`). Each
  record carries `Name`, `DisplayName`, `Category`, `DcsAirbase`, `Runways` (`:244-250`), and
  `DcsAirbase` is the live handle reaching `getParking()` and `getCoalition()`.
- The registration: `CTLDZoneManager:getInstance():registerFOBAsLogistic(name, point, radius,
  coalitionId)` (`CTLD_zone.lua:1190`).

## Do

- Gate the whole thing on `veaf.isCtldReady()` (`veaf.lua:5766`), the guard every other CTLD
  touchpoint uses, and log once when it answers no.
- Keep only `Category == Airbase.Category.AIRDROME`. Ships and helipads are out: carriers and FARPs
  already have their route (`manage_logistics`, and `veafSpawn.spawnLogistic` → `registerFOBAsLogistic`).
- Place the point from `DcsAirbase:getParking()` — the runtime API `veafGrass.lua:135` already
  iterates. Average the stand positions into a centroid, then take the **real stand nearest that
  centroid**. The centroid is never the point: an average of parking positions is not a parking
  position and can land on a taxiway. `Airbase:getPoint()` is never the point either — it sits near
  the middle of the field, where 250 m covers grass.
- An airfield whose parking list is empty is **skipped, with a warning naming it**. No fallback to
  `getPoint()`: a 250 m circle on the reference point can sit on a runway, and a zone a pilot cannot
  legally use is worse than an airfield honestly missing from the log line.
- Name each zone `AB_<airbase name>`. `registerFOBAsLogistic` uses the name verbatim as its registry
  key and adds neither prefix nor coalition suffix (`:1191-1201`), and CTLD's parsers read only
  **trigger zones** named `LGZ_` / `TRZ_` / `WPZ_` / `AIZ_` (`:734-745`, `:1728-1748`) — so `AB_` is
  free. The equipment menu never displays a zone name, so this is a log-and-registry identifier only.
- Register with the airfield's **own** coalition from `DcsAirbase:getCoalition()`, never `0`:
  `getLogisticZonesAtPoint` serves a `coalition == 0` zone to **both** sides (`:1503-1511`).
- Radius 250 m, read from settings rather than written at the call site (ticket 05 decides where the
  setting lives; until then a module-level local is fine, and 05 moves it).
- Before registering, ask `getLogisticZonesAtPoint(point, coalition)` whether something already covers
  that stand; if it does, skip and log. A maker's hand-placed `LGZ_` zone over Ramstein wins, and the
  alternative is two overlapping zones at one airfield.
- Check the return value: a name that already exists makes CTLD **WARN and return `false`**
  (`:1191-1194`). Log it at our level too, naming the airfield, or the only trace left is a CTLD line
  that does not say who asked.
- Snapshot each airfield's class into the per-airfield state table this lot keeps — A for a field held
  by a coalition from the start, B for the rest — because 02 and 03 read that snapshot and nothing can
  have been captured yet at first evaluation.
- One summary log line: how many airdromes registered, how many skipped and why, and each one's class.

## Watch out

- The class snapshot is taken at **first evaluation**, so a mission script that captures an airfield in
  its opening seconds — a T+0 trigger running before this module initialises — would record the field as
  class B and make it owe two minutes it should not owe. Unlikely (on GermanyCW v6 CTLD is ready at
  17:18:25 and the first FOB registers at 17:18:36) and cheaper to note than to discover in flight. If
  it ever bites, the fix is to snapshot from the `warehouses` table the builder wrote rather than from
  the live coalition.
- The two FOB zones already registered on this mission carry a **leading space** — `' Goettingen'`,
  `' Baumholder'`. Build our names without one, and find where that space comes from while in there: if
  a shared helper produces it, our names inherit it and every exact-name lookup breaks.
- Nothing is spawned to mark the zone and it must stay that way: a spawned crate or flag is a
  **static**, and 03's probe would let the marker be the blue presence keeping its own zone alive.
- The Lua tests have no DCS. `world.getAirbases()` returns `{}` (`dcs_mocks.lua:286`) and
  `Airbase.getByName` returns nil (`:448-453`), so build fake airbase records the way
  `test_veafAirbases.lua:38-42` already does and override the mock per test — that file's own comment
  states the convention. `CTLDZoneManager` is already a **recording** mock (`:1027`, calls land in
  `instance.calls`), but its `registerFOBAsLogistic` returns nothing where the real one returns
  `true`/`false`: give it a controllable return so the collision path is testable at all.
- `getLogisticZonesAtPoint` is **absent** from that mock; add it, recording like the others.
- The gates a PR here meets: `luacheck src/scripts/veaf/`, `stylua --check src/scripts/veaf/ test/lua/`,
  and `poetry run test-lua --cov-fail-under 80.9`.

## Done when

- On GermanyCW v6 a C-130 at Ramstein reads a real *Request Equipment* menu.
- The log gives the number of airdromes registered and each airfield's class.
- Lua tests assert: an AIRDROME registers at 250 m with its own coalition; a SHIP and a HELIPAD do not
  register; the point is a real stand, neither the centroid nor `getPoint()`; an empty parking list
  skips with a warning; a stand already covered registers nothing; `registerFOBAsLogistic` returning
  `false` is logged rather than swallowed; nothing is registered when `veaf.isCtldReady()` is false.
- The comment at `:676-680` describes what the function now does.
