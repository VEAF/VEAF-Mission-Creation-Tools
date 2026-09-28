# FIX-WAVE-OFFSET-AXES — `[latDelta,lonDelta]` moves east and south, not north and east

Status: ✅ done — **option (a) chosen by David, 2026-09-01**: the code is wrong, the axes are corrected and the migration is announced · archived 2026-09-28

Found on 2026-09-01 while fixing
[`FIX-AIRWAVES-COMMAND-EASTING`](../FIX-AIRWAVES-COMMAND-EASTING/PRD.md), on the line above the one
that lot fixes. **Deliberately not fixed there**: that lot restores a missing coordinate, while this
one changes where every existing mission with a non-zero offset puts its groups. Folding the two
together would make a regression indistinguishable from the fix, and this one needs David's call
before anything moves.

## What the code does

Both modules, both branches — `veafAirWaves.lua:1011` and its twin `veafQraCore.lua:993`, and again
in each file's DCS-group branch twenty lines below:

```lua
local position = { x = zoneCenter.x - lonDelta, y = zoneCenter.y, z = zoneCenter.z + latDelta }
```

`zoneCenter.x` is the **northing** and `zoneCenter.z` the **easting** — the file sets them that way
from a trigger zone, `zoneCenter.x = triggerZone.x` and `zoneCenter.z = triggerZone.y`, which is the
mission-table convention in `docs/agents/dcs-coordinates.md`. So:

| The value named | is applied to | which moves the spawn |
|---|---|---|
| `latDelta` — the **first** bracket number | `z`, the easting, **added** | **east** |
| `lonDelta` — the **second** bracket number | `x`, the northing, **subtracted** | **south** |

The names say latitude and longitude. `AirWaveZone:setRespawnDefaultOffset(defaultOffsetLatitude,
defaultOffsetLongitude)` says so in its own signature and its `@param` tags. A latitude delta belongs
on the northing and a longitude delta on the easting, and neither is where it lands — plus the
northing is subtracted, so a positive "latitude" offset moves *away* from the pole.

The swap is consistent across all four sites, so it is one decision made once and copied, not a slip.

## The documentation is wrong too, and not in a way that reveals the intent

`doc/mission-maker/scripts/veafAirWaves.en.md:274-275` and `veafAirWaves.md:273-274`:

```lua
"[0,5000]-spawn su-27, country russia",           -- 5 km north of zone centre
"[-3000,0]-spawn su-25, alt 100, country russia", -- 3 km south, low level
```

Measured against the code: `[0,5000]` is 5 km **south**, and `[-3000,0]` is 3 km **west**. The first
comment is wrong under *either* reading — the value it annotates is the longitude one, so even taking
the names at face value it should read "east". Whoever wrote it was not describing observed behaviour.

This is why the doc is left alone until the code question is settled: correcting the comments to match
today's behaviour would document the bug, and correcting them to match the names would document
something that does not happen.

## The decision this lot needs before it starts

Two ways out, and they are not equivalent for existing missions:

- **a — the code is wrong.** Put `latDelta` on the northing and `lonDelta` on the easting, both added.
  The names, the signature and the documentation all become true. **But every mission using a non-zero
  offset moves**, by up to twice the offset, in a direction the mission maker may have tuned by eye
  against what the game actually did. Someone who compensated for the swap gets their compensation
  applied twice.
- **b — the names are wrong.** Rename to what the numbers do — `eastDelta` and `southDelta`, or
  `[east,south]` — and fix the documentation to match. Nothing moves; the interface stops lying. But it
  bakes in an axis order (east first) that reads backwards to anyone used to lat/lon, and the setter is
  public API.

**Recommendation: a, with the migration said out loud** — a public interface whose two parameters both
mean something other than their names is a trap that will keep costing, and the offset is a
convenience feature rather than something a mission is built around. But this is David's to decide,
because it is his missions that move.

Worth knowing before deciding: `respawn_default_offset` defaults to `[0, 0]` in the shipped
`mission.yaml`, and `latDelta`/`lonDelta` default to 0 in both modules, so a mission that never sets
an offset is unaffected either way.

## Scope

| # | Ticket | Type | Status |
|---|--------|------|--------|
| 01 | [Put each delta on the axis its name names](FIX-WAVE-OFFSET-AXES.md) | fix | ✅ |
| 02 | [Say what moves, in both languages](FIX-WAVE-OFFSET-AXES.md) | docs | ✅ |

## What was delivered

All four call sites now read `x = zoneCenter.x + latDelta, z = zoneCenter.z + lonDelta`.

Two layers of test, because the four sites are not equally reachable:

- **Behaviour**, in Lua: five cases on `veafAirWaves` and three on `veafQraCore`, driving each axis on
  its own with distinct non-zero values and asserting the **delta** from the zone centre rather than
  the absolute field — a test written against the field would pass just as well if a later edit
  swapped the two names again. `respawnRadius` is set to zero so the scatter cannot blur the offset.
- **Source**, in Python (`test/python/test_wave_offset_axes.py`): refuses the wrong pairing anywhere
  in either module. This layer exists because the **DCS-group branch only reaches its offset when DCS
  fails to return a group's units** — a degraded path that is awkward to drive and easy to leave
  behind, which is exactly how a swap survives in half the call sites. A second assertion checks that
  each module still carries four such assignments, so renaming the fields cannot leave the first one
  green because it found nothing to look at.

## Proof each check can fail

| Sabotage | Result |
|---|---|
| the original formula restored in `veafAirWaves` | 5 Lua tests red |
| the original formula restored in `veafQraCore` only | 3 Lua tests red, the `veafAirWaves` ones staying green |
| the QRA DCS-group branch alone reverted | **all 45 Lua suites green**, the source test red at `veafQraCore.lua:1026` |

That third row is the reason the source layer is there.

## One thing the measurement settled

The documented example `[-3000,0]` was annotated *"3 km south"* — which is what it does **only** under
the corrected reading. So whoever wrote that line meant latitude first, and the companion example
annotated *"5 km north"* was simply written with its two numbers the wrong way round. Read together,
the two examples say the intent was never in doubt: the code was the thing that was wrong.

## What the mission maker sees

Both `veafAirWaves` pages carry a `Behaviour change` admonition under the `{#spawn-offset}` anchor,
in both languages, saying which offsets move and why an offset tuned by eye against the old behaviour
has to be rewritten. The two `veafQraManager` pages point at it from their builder table. No version
number is written by hand — the changelog entry carries the migration notice.

---

## Tickets, in full

## 01 — Put each delta on the axis its name names

Status: ✅ done

Type: fix · Files: `src/scripts/veaf/veafAirWaves.lua`, `src/scripts/veaf/veafQraCore.lua`,
`test/lua/test_veafAirWaves.lua`, `test/lua/test_veafQraManager.lua`,
`test/python/test_wave_offset_axes.py`

### The defect

Four sites — the VEAF command branch and the DCS group branch of each module — read:

```lua
local position = { x = zoneCenter.x - lonDelta, y = zoneCenter.y, z = zoneCenter.z + latDelta }
```

`x` is the northing and `z` the easting, so `latDelta` moved the spawn **east** and `lonDelta` moved
it **south**. Both parameters of the public `setRespawnDefaultOffset(defaultOffsetLatitude,
defaultOffsetLongitude)` meant something other than their names, `@param` tags included, and the
northing was subtracted on top — a positive latitude offset moved *away* from the pole.

### What was done

All four sites now read `x = zoneCenter.x + latDelta, z = zoneCenter.z + lonDelta`, with the old form
and the reason quoted in a comment at the command branch of each module so the next reader does not
have to find this ticket.

Tests in two layers:

1. **Lua, behaviour.** Five cases on `veafAirWaves`, three on `veafQraCore`. Each drives one axis at a
   time with a distinct non-zero value and asserts the **delta from the zone centre**, not the
   absolute field: an assertion on `position.x` would survive a future rename of the two locals,
   while an assertion on the delta only survives if the *axes* are right. `respawnRadius` is zeroed so
   the scatter cannot blur the measurement, and one case covers the public setter rather than the
   bracket prefix, because they feed the same two fields.
2. **Python, source.** `test_wave_offset_axes.py` refuses a delta paired with the wrong axis, or
   subtracted, anywhere in either module — plus an assertion that four such assignments still exist,
   so a rename cannot leave the check green on a file it no longer understands.

### Why the second layer

The DCS-group branch only reaches its offset **when DCS fails to return a group's units**. Driving
that from a unit test means faking a group record with no units and intercepting the spawn chain; it
is the path least likely to be exercised, and therefore the one where half a repair survives.

Measured: reverting that fourth site alone leaves **all 45 Lua suites green** and turns the source
test red, naming `veafQraCore.lua:1026` and the reason. Without this layer the repair could have
shipped half-done, green.

### Proof it can fail

| Sabotage | Result |
|---|---|
| original formula restored in `veafAirWaves` | 5 Lua tests red |
| original formula restored in `veafQraCore` only | 3 Lua tests red, `veafAirWaves` staying green |
| QRA DCS-group branch alone reverted | Lua all green, source test red at `veafQraCore.lua:1026` |

---

## 02 — Say what moves, in both languages

Status: ✅ done

Type: docs · Files: `doc/mission-maker/scripts/veafAirWaves.md`/`.en.md`,
`doc/mission-maker/scripts/veafQraManager.md`/`.en.md`, `CHANGELOG.md`

### The defect

Both examples under *VEAF commands as groups* were wrong:

```lua
"[0,5000]-spawn su-27, country russia",           -- 5 km north of zone centre
"[-3000,0]-spawn su-25, alt 100, country russia", -- 3 km south, low level
```

Against the old code, `[0,5000]` was 5 km **south** and `[-3000,0]` was 3 km **west**. And `[0,5000]`
was wrong under *either* reading — the number it annotates is the longitude one, so even taking the
names at face value it should have said "east". Nobody was describing observed behaviour.

Beyond the examples, nothing on the page said which bracket number was which axis, or which sign went
which way. That is the information a mission maker actually needs.

### What was done

- The two examples rewritten so their numbers match their annotations, and a sentence added stating
  the order plainly: first number north–south, second east–west, both positive towards north and
  east.
- A `Behaviour change` admonition on both pages: which offsets move, and that an offset tuned by eye
  against the old behaviour has to be rewritten the way it reads. **No version number written by
  hand** — that is the changelog's job, and the repository rule.
- An explicit `{#spawn-offset}` anchor on the section, identical in both languages, with the two
  `veafQraManager` builder tables pointing at it: the QRA setter has the same two parameters and had
  the same defect, so a reader landing there needs the same explanation.
- `CHANGELOG.md` entry stating the migration.

### What the examples settled

`[-3000,0]` annotated *"3 km south"* is correct **only** under the corrected reading. So the author of
that line meant latitude first, and its companion was simply written with its numbers reversed. That
is what made option (a) — the code is wrong — the honest reading rather than a preference.

### Gate

`poetry run docs-check` clean, including the new cross-page anchor.

---
