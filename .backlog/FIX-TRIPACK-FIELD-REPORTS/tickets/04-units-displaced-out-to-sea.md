# 04 — ZU-23s of a combat zone come up kilometres out to sea

Status: 🧑 waiting-human

Type: fix

## The report

Tripack, 2026-09-03: *"le déplacement automatique des unités CZ est un peu buggé"*, with four
screenshots of Abu Musa island.

- **F10 map, in game**: several ZU-23s correctly on the island, and **two standing in open water**
  south-west of it, roughly a kilometre apart from each other and several kilometres from the shore.
- **Mission Editor, same mission** (`Snowfox_20260903.miz`): the zone's groups are on the island —
  `CMBT_ABU_MUSA_AIRPORT - Silkworm`, `- AAA`, `- Artillery`, `- Supply Truck`, `- SA-15`, `- Hawk`.
- Two close-ups of isolated units on spits of land, with his comment: *"étonnant car rien à
  proximité"*.

## What rules out the obvious answer

The scale. This mission's spawn radius is **50 m** — the figure the `findSpawnPoint` failures print
in the same log. Every displacement mechanism read on 2026-09-05 is bounded by it or by the
group's own formation:

- `spawnElement` moves the anchor by at most `spawnRadius`;
- `_drawOrigin` draws inside `self.radius`, which the combat-zone path leaves at 0;
- `_spawn` then translates every unit by that one offset, so intra-group spacing is preserved;
- `disperseOver` is not used by the combat-zone path at all.

None of them produces a kilometre, let alone several. The coordinate helpers were checked as well —
`makeVec3`, `getRandomPointInCircle`, `placePointOnLand` — and none of them swaps or drops an axis
on this path. **So the mechanism is not identified, and this ticket does not pretend otherwise.**

One observation worth keeping: a ground unit is allowed to stand in `SHALLOW_WATER`. That is
deliberate and settled (`veaf.OPEN_WATER` holds `WATER` only, FIX-CSAR-SPAWNS-ON-WATER), and it
would explain a ZU-23 a few metres off a beach. It does not explain one several kilometres out.

## What is needed before this can be worked

1. **Tripack's `Snowfox_20260903.miz`** — asked for on 2026-09-05. Without it the zone's real
   `spawnradius`, the groups' composition and their editor positions are all inference.
2. **A run with the VEAF logs at `debug`**: `VeafCombatZone:spawnElement` traces the declared
   position, the radius and the point found, which turns this from a reading exercise into an
   arithmetic one.
3. If neither arrives: build the mission here — a small island, a combat zone with ZU-23s near the
   shore, several activations — and measure on David's DCS.

Until then the symptom stands unexplained and this ticket stays out of any PR.

## Definition of done

- [ ] The displacement is reproduced, with the numbers that show it
- [ ] Its cause is named
- [ ] Fix, plus a test asserting the **built group's** positions rather than the radius constant
- [ ] `luacheck` + `stylua --check` clean; Lua coverage floor bumped per the ratchet policy
