# 02 — Wire the combat zone element spawn through findSpawnPoint

Status: ✅ done
Type: fix

Higher blast radius than ticket 01: this path covers **every combat zone element with a non-zero spawn
radius**, in every mission that uses combat zones.

## What exists

[`veafCombatZone.lua:1466`](../../../src/scripts/veaf/veafCombatZone.lua):

```lua
if zoneElement:getSpawnRadius() > 0 then
  local mistP = mist.getRandPointInCircle(position, zoneElement:getSpawnRadius())
  position = { x = mistP.x, y = position.y, z = mistP.y }
end
if zoneElement:isDcsStatic() or zoneElement:isDcsGroup() then
```

A raw draw, applied to DCS groups and statics alike. No land test, no scenery test — and unlike ticket
01's path, not even a `placePointOnLand` afterwards: the original `position.y` is kept.

## The coordinate shape, which must survive unchanged

`position = { x = mistP.x, y = position.y, z = mistP.y }` reads MiST's **vec2** `y` as the horizontal
`z`, and keeps the original vertical `y`. That is correct, and it is exactly the confusion
[`docs/agents/dcs-coordinates.md`](../../../docs/agents/dcs-coordinates.md) warns about: the two shapes
both look like plausible coordinates and swapping them raises no error, only a wrong position.

`veaf.findSpawnPoint` returns a **vec3** (its tier 2 runs the draw through `acceptableGroundPoint`), so
the substitution is not textual. Establish what shape `findSpawnPoint` returns for this caller and
convert deliberately, with the convention named in a comment.

Note the difference from ticket 01: that path replaced the vertical with the ground height, this one
keeps `position.y`. Decide which is right **for a zone element** rather than assuming the sibling's
answer transfers — a static and a group may not want the same thing.

## What this ticket does

Route the draw through `veaf.findSpawnPoint`, and keep the resulting shape identical to what the code
below line 1470 expects.

`getSpawnRadius() == 0` already bypasses the block entirely, so exact placement is untouched by
construction — but assert it, since this is the property missions depend on.

### A `nil` return must fall back, not refuse (David, 2026-08-27)

**This is editor content, so it is never refused** — *"c'est applicable au spawn (`-farp`) mais pas à ce
qui est placé dans l'éditeur de mission (combat zone, farp statiques, etc.)"*. A combat zone element is
declared by a mission maker who is not in the room when the mission loads; skipping it would remove
part of a zone with nobody to read the reason.

So when `findSpawnPoint` returns `nil` — its tier 3, *nothing acceptable anywhere* — this path
**keeps the element's declared position** and spawns there, logging that it could not improve on it.
The scenery criterion is a **quality** improvement here, exactly as
[ADR 0018](../../../docs/adr/0018-undocumented-dcs-api-dependency.md) requires of the `Disposition`
dependency: never correctness, never a reason for something to stop existing.

**Note the deliberate asymmetry with ticket 01.** That path is
`registerCommandHandler("fullCombatGroup", …)` on an `eventPos` — a runtime marker, with a user standing
there — so it aborts and reports. Same search, opposite failure path, because the origin differs. Do not
"harmonise" the two: the difference is the arbitration.

## Definition of done

- [x] The draw goes through `veaf.findSpawnPoint`; the vec3 handed to the spawn below is the same shape
      as today, with the convention named in a comment
- [x] A `nil` return **falls back to the element's declared position** and logs it — the element is never
      skipped and the zone is never partially built
- [x] The vertical-coordinate decision (`position.y` versus ground height) is made explicitly and its
      reason recorded
- [x] Lua tests: a zero radius bypasses the search and returns the exact point, a non-zero radius on
      clear ground behaves as before, an **unplaceable element still spawns at its declared position**,
      and the resulting vec3's `x`/`y`/`z` are asserted individually — not compared as a whole table
- [x] `stylua --check` clean locally; `luacheck` is not installed on this workstation and runs in the CI Lua gate
