# FIX-PLACEMENT-IGNORES-SCENERY — ground units are placed without looking at the scenery, and a crowded FARP gives up silently

Status: ⬜ ready

Origin: found on 2026-08-27 while studying the 20 `mist.getRandPointInCircle` call sites for
[`DROP-MIST`](../DROP-MIST/tickets/06-geometry-and-zone-queries.md) ticket 06. Kept out of that campaign
on purpose — a lot whose job is to remove a dependency must not also move where things spawn, or a
regression becomes indistinguishable from the port going wrong. David arbitrated the FARP question the
same day and asked for this lot to be opened.

## Two problems, one cause

`FEAT-SCENERY-AWARE-SPAWN` (2026-08-05, [ADR 0018](../../docs/adr/0018-undocumented-dcs-api-dependency.md))
built `veaf.findSpawnPoint`: a three-tier search — the undocumented `Disposition` singleton first, which
genuinely avoids buildings and forests; validated random draws second; explicit failure third. It was
wired into *"the four dynamic ground spawners plus the generic `doSpawnGroup`"* —
`veafSpawnGround.lua` 387, 441, 483, 538 and `veafSpawnCore.lua:698`.

**Two ground-placement paths were not among them, and one whole family delegates the scenery criterion
to a tier it never calls.**

### Problem 1 — two spawners never got wired

| Site | What it places |
|---|---|
| [`veafSpawnGround.lua:594`](../../src/scripts/veaf/veafSpawnGround.lua) | a **"Full Combat Group"** — real ground combat units, on a raw `getRandPointInCircle` draw wrapped in `veaf.placePointOnLand` |
| [`veafCombatZone.lua:1466`](../../src/scripts/veaf/veafCombatZone.lua) | **every combat zone element** whose `getSpawnRadius() > 0`, DCS groups and statics included |

Both can drop a group in a building or a forest, silently. `veaf.placePointOnLand` does not save them:
it sets `y` to the ground height and returns — **no land-versus-water test, no building clearance**. Its
name reads like a guarantee it does not give, which is probably why these two paths look finished.

### Problem 2 — the FARP escort searches for clear ground but never looks at the scenery

`FIX-FARP-ESCORT-PLACEMENT` (6.15.33, verified in game 2026-08-24) built
[`veafGrass.findClearBearing`](../../src/scripts/veaf/veafGrass.lua): it walks the requested bearing
first at each of several distances, then alternates sides, and it correctly avoids **units, statics and
the FARP's own 259 m apron**.

It does not avoid scenery, and it says so —
[`veafGrass.lua:258`](../../src/scripts/veaf/veafGrass.lua): *"scenery is **deliberately left** to
`veaf.findSpawnPoint`'s Disposition tier"*. But the FARP layout path never calls `findSpawnPoint`. The
criterion was delegated to a tier that is not on this path, so nothing applies it.

## David's arbitration (2026-08-27)

Three rulings, and the second reverses a written decision:

1. **The FARP, the FOB and the CTLD beacon are placed exactly where the user asked.** No intelligent
   relocation. This **confirms the current code**: all three default to `local radius = radius or 0`, so
   `getRandPointInCircle(spot, 0)` returns the point unchanged. Nothing to fix — but worth locking in, so
   a later lot does not "improve" it.
2. **The FARP's escort must be placed intelligently, or the FARP is refused with a message.**
3. Problems 1 and 2 above are to be fixed.

### Ruling 2 reverses a documented decision, and that must be said out loud

[`veafGrass.lua:332`](../../src/scripts/veaf/veafGrass.lua), the docstring of `findClearBearing`, records
the opposite call:

> *"Falls back to the requested angle at scale 1 when nothing is clear anywhere — **a FARP that refuses
> to exist because it is crowded would be worse than one placed imperfectly** — but says so at info,
> because that fallback is exactly how a group ends up on an apron."*

That fallback is deliberate and it was tuned: `FIX-FARP-ESCORT-PLACEMENT` went through **five rounds of
changes, four of them adjusting how aggressively the placement refuses ground**, and its PRD says
plainly that *"a fix that quietly moved every FARP in every existing mission would have been a worse
outcome than the defect"*.

So ruling 2 is not filling a gap, it is **changing the answer**. The risk is concrete: a mission that
today gets a working-but-imperfect FARP would stop getting a FARP at all. David's call stands — a
decorative escort standing on an apron is the defect this is meant to end — but the lot must make the
refusal *narrow and loud* rather than *broad and silent*, and it must prove the non-regression the way
6.15.33 did.

## Scope

- wire `veafSpawnGround.lua:594` and `veafCombatZone.lua:1466` through `veaf.findSpawnPoint`
- add the scenery criterion to the FARP escort placement
- refuse the FARP, with a translated message, when the escort cannot be placed
- lock in the exact placement of the FARP, FOB and beacon themselves

**Not in scope:** merging the three spawn-point searches. The codebase holds `veaf.findSpawnPoint`,
`veaf.findPointInZone` ([`veaf.lua:1642`](../../src/scripts/veaf/veaf.lua) — draw, `land.getSurfaceType`,
widen the dispersion, up to 1000 tries) and `veafSpawnAircraft.lua:115`'s own 25-try loop, with three
different contracts. That is a real design smell and a separate lot; folding it in here would put a
refactor underneath a behaviour change.

**Also not in scope:** the air spawns (`veafSpawnAircraft.lua:1045`, `veafQraCore.lua:994`/`:1024`,
`veafAirWaves.lua:1067`) and the effects (`veafSpawnEffects.lua` × 6). Scenery clearance is meaningless
in the air, and `findSpawnPoint`'s own comment names the effects family as *"exactly here, the mission
maker means it"*. `veafAirWaves.lua:1037` hands its point to `veafInterpreter.execute`, which may spawn
ground units — noted, but the wave's command decides, so the fix is not local and does not belong here.

## Tickets

| # | Ticket | Risk |
|---|---|---|
| 01 | Wire the Full Combat Group spawn through `findSpawnPoint` | low |
| 02 | Wire the combat zone element spawn through `findSpawnPoint` | medium — touches every zone with a radius |
| 03 | The FARP escort avoids the scenery too | medium |
| 04 | Refuse the FARP when the escort cannot be placed | **high** — reverses a tuned decision |
| 05 | Lock in the exact placement of the FARP, FOB and beacon | low, tests and docs |

Order matters between 03 and 04: adding the scenery criterion (03) makes the search *harder* to satisfy,
so it increases how often 04's refusal would fire. Land 03 first and measure how often nothing is clear
before choosing 04's threshold.

## Definition of done

- [ ] No ground-placement path draws a raw random point where scenery matters
- [ ] A FARP whose escort cannot be placed is refused, with a translated message, and the refusal is
      narrow enough that a FARP in open ground never sees it
- [ ] The non-regression is proven the way 6.15.33 proved it: a FARP far from anything does not move
- [ ] `mypy` exclusions and the coverage ratchet respected per the repository's quality policy
- [ ] `CHANGELOG.md` entry under `[Unreleased]`, appended at the end of the section
