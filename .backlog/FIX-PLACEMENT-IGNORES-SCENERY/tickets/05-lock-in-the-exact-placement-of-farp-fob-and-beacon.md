# 05 — Lock in the exact placement of the FARP, the FOB and the beacon

Status: ⬜ ready
Type: test

No behaviour change. This ticket writes down and asserts a decision, so a future lot cannot "improve" it
by accident.

## The decision

David, 2026-08-27: **the FARP, the FOB and the CTLD beacon are placed exactly where the user asked.** No
intelligent relocation, no scenery-driven jitter. The user pointed at a spot; that is the spot.

This is the deliberate counterpart to tickets 01 to 04. Those add scenery awareness to things the tooling
*chooses* to place — a combat group inside a radius, an escort on a bearing. A FARP is not chosen by the
tooling; it is placed by a person who is looking at the map.

## Why it needs asserting rather than just documenting

The current behaviour is already correct, by a single line repeated in each of the three functions:

```lua
local radius = radius or 0
```

With `radius == 0`, `mist.getRandPointInCircle(spot, 0)` returns the point unchanged. So exactness is not
enforced by an intent expressed in the code — it is a **side effect of a default**. Nothing says "this
must not move", and nothing fails if someone changes the default or routes these three through
`veaf.findSpawnPoint` while wiring up its siblings.

That is exactly what happened in the other direction: `veafSpawnGround.lua:594` and
`veafCombatZone.lua:1466` were *missed* when `findSpawnPoint` was wired in, because nothing marked them
as needing it. This ticket puts the opposite marker on the three that must **not** get it.

## Call sites

| Site | What |
|---|---|
| [`veafSpawnGround.lua:47`](../../../src/scripts/veaf/veafSpawnGround.lua) | `veafSpawn.spawnFarp` |
| [`veafSpawnGround.lua:146`](../../../src/scripts/veaf/veafSpawnGround.lua) | `veafSpawn.spawnFob` |
| [`veafSpawnGround.lua:258`](../../../src/scripts/veaf/veafSpawnGround.lua) | the CTLD beacon |

Note the distinction this ticket must not blur: the **FARP itself** is exact; its **escort** is not, and
is the subject of tickets 03 and 04. Both statements are true at once and the comment must say so, or the
next reader will take one for the other.

## What this ticket does

- a comment at each of the three sites stating the rule and naming David's arbitration, in the style of
  the existing `veafSpawnGround.lua:716` marker (*"Deliberately NOT using veaf.findSpawnPoint here…"*),
  which is the precedent for exactly this kind of note
- a Lua test per site asserting the returned position **equals** the requested one when no radius is
  given
- one test asserting that a caller-supplied non-zero radius still jitters, since that is the user asking
  for it — the rule is "exactly where the user asked", not "never move"

## Definition of done

- [ ] The three sites carry a comment stating the rule, its author and its date, and distinguishing the
      FARP from its escort
- [ ] A test per site: no radius given → the exact requested position
- [ ] A test: a non-zero radius still jitters
- [ ] `stylua --check` and `luacheck` clean
