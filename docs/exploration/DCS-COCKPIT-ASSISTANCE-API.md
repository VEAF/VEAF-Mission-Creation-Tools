# DCS cockpit + picture API — facts collected while building guided checklists

Collected against DCS 2.9 on 2026-08-01 (install at `C:\jeux\DCS World`), while building the
`veafAssist` module (`.backlog/FEAT-ASSIST-CHECKLISTS/`). Sibling note to
[DCS hook environment boundaries](DCS-HOOK-ENVIRONMENT-BOUNDARIES.md): same habit, keep the **facts**
in the repo so the next person does not re-measure them.

Read this before writing anything that boxes a cockpit control, reads a switch position, or puts a
picture on a pilot's screen.

## 1. The cockpit trigger actions are plain functions in the mission environment

`a_cockpit_highlight`, `a_cockpit_remove_highlight` and `a_cockpit_perform_clickable_action` appear
in the Mission Editor as **trigger actions**, which is what makes them look unreachable from a
script. They are not: they are native functions the engine exposes to the mission scripting
environment, defined in no file under `<DCS>\Scripts\`.

Verified in game, F-16C cold on the ramp:

```lua
a_cockpit_highlight(100, 'PTR-ELEC-TMB-MPWR-510')   --> ok=true, box appears on the MAIN PWR switch
a_cockpit_remove_highlight(100)                     --> ok=true, box clears
```

**Two arguments are enough** for `a_cockpit_highlight(id, element_name)`. The trigger action's third
field (`size_of_box`) and its aircraft-module selector are not needed at the Lua call site.

`update_checklist` and `MAKE_CHECKLIST_ITEM` (from
`Scripts\Aircrafts\_Common\Cockpit\Macro_handler.lua`) are **not** exposed — they live in the
module's own cockpit environment, and their logic has to be reimplemented rather than called.

## 2. `a_out_picture_u` with `seconds = 0` stays up until you stop it

This is ED's own documented behaviour, not an observation. `MissionEditor\modules\me_trigrules.lua`,
in `out_picture_fields`, on the duration field:

```lua
min = 0, -- если время показа картинки 0, то показываем до вызова a_out_picture_stop DCSCORE-2754
```

("if the picture display time is 0, show until `a_out_picture_stop` is called").

The full signature, in field order, is:

```lua
a_out_picture_u(unitId, file, seconds, clearview, startDelay, horzAlignment, vertAlignment, size, sizeUnits)
```

`file` is **not** a path: it is a resource embedded in the `.miz`, resolved through
`getValueResourceByKey("<key>")`. The key has to sit in the `l10n/DEFAULT/mapResource` archive
member, **not** in the mission table — putting it in the wrong one fails silently and only shows in
game. That trap has its own lot, [FIX-MAPRESOURCE-KEY](../../.backlog/FIX-MAPRESOURCE-KEY/PRD.md).

## 3. A spring-loaded switch cannot be detected by its animation argument

The trailing number of a cockpit element name **is** its animation argument
(`PTR-ELEC-TMB-MPWR-510` → argument `510`), which is what makes
`Unit:getDrawArgumentValue(510)` a usable way to read a switch position.

It does not work for every switch. `clickabledata.lua` builds each element from a prototype in
`clickable_defs.lua`, and the prototype tells you what the argument does:

| Prototype | `arg_lim` | What the argument does |
|---|---|---|
| `default_3_position_tumb` | `{-1, 1}` | rests at −1 / 0 / +1 |
| `default_2_position_tumb` | `{0, 1}` | rests at 0 or 1 |
| `default_button` (`button_prototype`) | `{0, 1}` | rests at 0 or 1 |
| `springloaded_3_pos_tumb` | `{-1,0}` / `{0,1}` | **returns to 0 when released** |

A spring-loaded switch — the F-16C's JFS switch, for instance — is back at 0 by the time anything
polls it, so no argument window can catch that the pilot threw it. Those steps need a different
signal, or a pilot confirmation.

## 4. The command value is not necessarily the animation argument

`Macro_sequencies.lua` gives, for each step of ED's own autostart, the `value` of the **command**
sent to the device. On a simple tumbler that value and the animation argument coincide — for the
F-16C MAIN PWR switch, `MainPwrSw` takes `-1.0` / `0.0` / `1.0` and argument `510` reads the same.
That is a property of the prototype, not a rule: reading the argument in the cockpit, in every
position, stays the only way to know a window.

## 5. `Macro_sequencies.lua` is the real source for a start-up procedure

Each aircraft module that ships an autostart has one, and it holds far more than a switch list: the
F-16C's `start_sequence_full` is **106 labelled steps**, each carrying the pilot-facing label, the
device, the command and the target value, plus named verification conditions
(`JFS RUN LIGHT MUST BE ON`, `THROTTLE MUST BE AT IDLE`).

Writing a start-up order from the switch labels alone produces something plausible and wrong — the
first draft of the F-16C checklist opened on "MAIN PWR → MAIN PWR" when ED's sequence starts by
setting it to **OFF**, after the ejection safety lever and the canopy jettison handle. Take the
order and the wording from the file.

Two things that file also reveals: guarded switches take **three** commands (open the guard, throw
the switch, close the guard), so one step per switch is not always the right granularity; and the
sequence is grouped into phases (*Before Starting Engine*, *Starting Engine*, *After Engine Start*)
that make a coherent slice easy to pick.

## 6. Not every name in a cockpit is an element you can box

`clickabledata.lua` names the **clickable** elements. Gauges and warning lights are not clickable and
have no entry there, so there is nothing to pass `a_cockpit_highlight`. A step about a gauge either
boxes the nearest clickable control on the same panel, or boxes nothing.
