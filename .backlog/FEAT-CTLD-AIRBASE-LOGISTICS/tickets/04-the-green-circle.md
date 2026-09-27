---
Status: 🔄 in-progress
---

# 04 — One green transparent circle per active airfield, on the F10 map

**Blocked by:** 02 — the circle is drawn on activation and erased on deactivation, and those
transitions are what 02 builds. Nothing to wait for in 03: class-B zones are drawn by the same edges.

## What it delivers

A pilot opens the F10 map and sees exactly the logistic airfields his coalition holds, as green
transparent circles, appearing and disappearing with the status. The map is how he finds the zone, which
is why nothing is spawned into the simulation to mark it.

## Where

- `VeafCircleOnMap` (`veaf.lua:5208`), whose `draw()` (`:5239-5251`) erases first, then calls
  `trigger.action.circleToAll` (`:5248`) and records the id in `dcsMarkerIds`; `erase()` is inherited
  from `VeafDrawingOnMap` (`:5196-5205`) and calls `trigger.action.removeMark` per recorded id.
- The fluent precedent: `veafSkynetIadsHelper.lua:4362` — `:setCenter(centre):setRadius(range)
  :setColor("red"):setLineType("solid"):setFillColor("transparent")`.
- Colours in `VeafDrawingOnMap.COLORS` (`veaf.lua:5039`), line styles in `LINE_TYPE` (`:5029`); the
  setters accept names (`:5113`, `:5124`, `:5135`).
- Alpha precedent: `veafGeo.drawTriggerZone`'s defaults (`veafGeo.lua:400-409`) — colour
  `{1,1,1,0.5}`, fill `{1,1,1,0.15}`, `lineType = 2`.

## Do

- Add a **named** translucent green to `COLORS`. The existing `["green"] = {0,1,0,1}` is fully opaque
  and `["transparent"] = {0,0,0,0}` is nothing, so neither can express "green, see-through". The
  table's own comment states the rule: colours are *"Named here rather than passed as raw RGBA at the
  call site, because a colour nobody can name is a colour the next caller re-invents slightly
  differently"* — and `["pink"] = {1,0,0,0.3}` is already a translucent red, so an alpha around **0.15**
  (matching `veafGeo`) is in family.
- Draw with `:setCenter(point):setRadius(<the 250 m setting>):setColor("green"):setFillColor(<the new
  name>):setLineType("solid")`, and `:setCoalition(<the holder>)`: `circleToAll`'s first argument is
  *"Coalition that can see the circle"*, so a per-side drawing is what keeps green meaning *ours*. With
  every zone drawn for everyone, a blue pilot could not tell a blue logistic point from a red one.
- `:setName()` to the zone name, so the trace lines say which airfield is being drawn.
- Hook the transitions from 02 and 03: draw on activation, `erase()` on deactivation. Keep **one circle
  object per airfield** beside its state, created once and reused; `draw()` already erases before
  redrawing, so re-activation cannot double up.
- Erase on module re-initialisation, and never leave a circle whose zone is gone: a leaked markup is a
  circle on the map with nothing behind it, and a pilot who lands inside it gets
  *"Aucune logistique à portée"* — the exact symptom this lot exists to remove.
- **No hatching, and do not fake it.** `LINE_TYPE` offers `none, solid, dashed, dotted, dotdash,
  longdash, twodashes`, and the DCS schema describes `circleToAll`'s `lineType` as *"Line style for the
  circle **outline**"* — it styles the border, never the interior. Stripes drawn with `lineToAll` and
  clipped by hand are not a hatch and cost more than the distinction is worth; the distinction comes
  from colour and fill alpha.

## Watch out

- `dcs_mocks.lua:193-196` are `removeMark = function(id) end` and `circleToAll = function(...) end`:
  both **discard their arguments**, so a test can assert nothing about what was drawn today. Record
  them the way `addGroup` / `addStaticObject` do, and clear the records in `dcs_mocks.reset()`.
- `VeafDrawingOnMap:erase()` **never clears `dcsMarkerIds`** (`:5196-5205`), so a second `erase()` on
  the same object re-issues `removeMark` for ids already removed — harmless to DCS, but it makes "erase
  was called once" the wrong assertion. Assert on the **recorded markup** (a circle exists after
  activation, none after deactivation) rather than on call counts, and do not "fix" `erase()` in this
  ticket: four modules share that base class.
- One circle per **airfield**, not per zone: an airfield changing hands must not leave two circles at
  the same point, one per coalition, since both are 250 m around the same stand.
- Coverage floor and stylua, as in 01.

## Done when

- In flight: one green transparent circle per active logistic airfield, visible only to the coalition
  that holds it, appearing on activation, gone on deactivation, and none left over after a
  re-initialisation or a change of hands.
- Lua tests assert against the recording mocks: the centre is the stand 01 chose, the radius is the
  setting, the coalition is the holder's, the fill is the new named colour, a deactivation leaves no
  circle drawn, and a change of hands leaves exactly one.
