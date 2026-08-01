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

## Both open questions answered — 2026-08-01, in game, through the bridge

**`a_out_picture_u` is reachable: yes.** Along with `a_out_picture_stop`, `getValueResourceByKey` and
the whole `a_*` family — 114 of them. And ED's own source settles the duration question without a
probe: `me_trigrules.lua` documents `seconds = 0` as "show until `a_out_picture_stop`" (DCSCORE-2754).

**`Unit:getDrawArgumentValue` reports a cockpit switch position: NO.** This one is negative and it
costs the lot its automatic validation. MAIN PWR was moved through OFF → BATT → MAIN PWR between
reads and argument 510 stayed at `0` throughout — as did `c_player_unit_argument_in_range`, the
documented fallback, which is therefore no fallback at all. `getDrawArgumentValue` works (52 non-zero
arguments on a 0-800 sweep: gear, control surfaces, lights) but reads the **external** model;
`list_cockpit_params()` returns 562 entries, 78 of them live, and not one is a control position.

The signal was already in this ticket's own notes: `MAKE_CHECKLIST_ITEM` and `update_checklist` are
not exposed **because they run in the module's cockpit environment**, which is exactly where the
switch state lives. The consequence was not drawn at the time.

Full measurements in
[DCS cockpit + picture API](../../../docs/exploration/DCS-COCKPIT-ASSISTANCE-API.md), section 3.

**A probing note for next time:** the bridge's `/api/exec` runs in a **sandbox** — 96 globals, zero
`a_` function. The real mission environment (288 globals, 114 `a_`) is reached with
`net.dostring_in("mission", …)`. A first probe here concluded "the functions do not exist"; it was
looking at the sandbox.

## Originally left open, for ticket 02 to settle first thing

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
