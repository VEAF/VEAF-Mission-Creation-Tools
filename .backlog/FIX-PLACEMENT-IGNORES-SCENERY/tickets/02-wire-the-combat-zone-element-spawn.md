# 02 — Wire the combat zone element spawn through findSpawnPoint

Status: ⬜ ready
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

Route the draw through `veaf.findSpawnPoint`, keep the resulting shape identical to what the code below
line 1470 expects, and handle a `nil` return by reporting and skipping that element rather than placing
it on a rejected point.

`getSpawnRadius() == 0` already bypasses the block entirely, so exact placement is untouched by
construction — but assert it, since this is the property missions depend on.

## Definition of done

- [ ] The draw goes through `veaf.findSpawnPoint`; the vec3 handed to the spawn below is the same shape
      as today, with the convention named in a comment
- [ ] A `nil` return reports and skips the element; nothing is placed on a rejected point
- [ ] The vertical-coordinate decision (`position.y` versus ground height) is made explicitly and its
      reason recorded
- [ ] Lua tests: a zero radius bypasses the search and returns the exact point, a non-zero radius on
      clear ground behaves as before, an unplaceable element is skipped with a report, and the resulting
      vec3's `x`/`y`/`z` are asserted individually — not compared as a whole table
- [ ] `stylua --check` and `luacheck` clean
