# 01 — prove the cockpit primitives from the mission environment

**Status:** ✅ done — 2026-08-01, in game on David's DCS, F-16C cold on the ramp.

This was the go/no-go gate: the cockpit highlight machinery is an ED **trigger action**, so the question
was whether it is also reachable as a plain function from the mission scripting environment. If it were
not, the tutor would have had to be emitted as trigger rules — the design David rejected for flooding
the mission maker's trigger panel.

## Result

The functions are native (defined in no script under `<DCS>\Scripts\`, so exposed by the engine) and
**present in the mission environment**:

```
highlight=function  remove=function  perform=function
update_checklist=nil  MAKE_ITEM=nil
```

A real call, with the player sitting in an F-16C:

```lua
a_cockpit_highlight(100, 'PTR-ELEC-TMB-MPWR-510')   --> ok=true, box appears on the MAIN PWR switch
a_cockpit_remove_highlight(100)                     --> ok=true, box clears
```

Notes worth keeping:

- **Two arguments are enough** for `a_cockpit_highlight(id, element_name)`. The trigger action's third
  field (`size_of_box`) and its aircraft-module selector are not required at the Lua call site.
- `a_cockpit_perform_clickable_action` is available too, so a demonstration mode is possible later.
- `update_checklist` / `MAKE_CHECKLIST_ITEM` (from `Scripts\Aircrafts\_Common\Cockpit\Macro_handler.lua`)
  are **not** exposed — they live in the module's cockpit environment. Their logic gets reimplemented in
  ticket 02, not copied.
- The spike was driven through [dcs-fiddle-server.lua](../../../src/scripts/other/dcs-fiddle-server.lua)
  with `env=mission`, which is a good pattern for this kind of probe: no mission rebuild, no `.miz`
  editing, immediate answer.

## What this unblocks

The tutor is a runtime module driven by data — see the PRD. No trigger rule is emitted at all.

## Left open, for ticket 02 to settle first thing

**Does `Unit:getDrawArgumentValue(arg)` return cockpit switch state for a player-flown aircraft?** It is
the documented way to read an animation argument
([dcs-world-api.lua:1846](../../../src/python/veaf-tools/veaf_libs/data/dcs-schema/dcs-world-api.lua)),
and the tutor's step check depends on it entirely. Verify with the same `env=mission` probe before
writing the engine: read argument 510 with the MAIN PWR switch in each position, and record the values —
the `[min, max]` window cannot be inferred from `clickabledata.lua` (a 3-position switch may run
0 / 0.5 / 1 or -1 / 0 / 1).

If it turns out not to work, the fallback is the native trigger predicate
`c_player_unit_argument_in_range` — check whether it too is exposed to the mission environment.

## Also left open

**Is `a_out_picture_u` reachable from the mission environment too?** Same family as the cockpit
functions, so very likely, but it has not been checked and the image display of
[ticket 03](03-image-generator.md) depends on it. One `env=mission` probe:
`return type(a_out_picture_u)..' stop='..type(a_out_picture_stop)`. While in there, confirm that a
picture with **duration 0** does stay on screen until `a_out_picture_stop` — that is ED's documented
behaviour (`me_trigrules.lua`, DCSCORE-2754) and the whole persistent-checklist design rests on it.

Whether a highlight is visible to a **second** player in the same mission. Not blocking; it decides
whether the assistance can run on the squadron server or stays single-player.
