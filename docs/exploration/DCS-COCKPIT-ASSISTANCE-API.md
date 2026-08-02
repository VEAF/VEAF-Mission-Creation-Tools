# DCS cockpit + picture API — facts collected while building guided checklists

Collected against DCS 2.9 on 2026-08-01 (install at `C:\jeux\DCS World`), while building the
`veafAssist` module (`.backlog/FEAT-ASSIST-CHECKLISTS/`). Sibling note to
[DCS hook environment boundaries](DCS-HOOK-ENVIRONMENT-BOUNDARIES.md): same habit, keep the **facts**
in the repo so the next person does not re-measure them.

Read this before writing anything that boxes a cockpit control, reads a switch position, or puts a
picture on a pilot's screen.

## 1. There are THREE Lua environments, and what you need is rarely in yours

This is the fact everything else here depends on, and getting it wrong produced a module that
silently refused to start.

| Environment | Holds | Reached from |
|---|---|---|
| **Mission scripts** — where a `DO SCRIPT FILE` script and every VEAF module run | `veaf`, `Unit`, `trigger`, `coalition`, `net` — and **no `a_*` function at all** | the script itself |
| **Triggers** — where the Mission Editor's actions execute | all **114** `a_*` functions, `getValueResourceByKey`, `list_cockpit_params` — and **no `veaf`, no `net`** | `net.dostring_in("mission", <code>)` |
| **Export** — Export.lua's own | `GetDevice`, `LoGetAircraftDrawArgumentValue`, `LoGetSelfData` — the only place a **control's position** is readable (section 3) | `net.dostring_in("export", <code>)` |

`net.dostring_in` also answers for `server`, `gui` and `config`; `cockpit` is not a valid name.
Note the naming trap: the **trigger** environment is reached with `"mission"`, not the mission
scripts' own — which is why the table above is worth keeping.

Measured on 2026-08-01: from a mission script `type(a_cockpit_highlight)` is `"nil"`, while
`net.dostring_in("mission", 'return type(a_cockpit_highlight)')` returns `"function"`. The two
namespaces are disjoint — the trigger side has 288 globals and cannot see `veaf` either.

A script therefore calls a cockpit primitive by **formatting a chunk and sending it across**:

```lua
net.dostring_in("mission", string.format("a_cockpit_highlight(%d, %q)", id, element))
```

Which is exactly what `TheUniversalMission` does for its own picture output — the pattern was in this
tree the whole time.

**This requires `net`**, which a stock `MissionScripting.lua` sanitises away. Anything built on the
bridge needs the same de-sanitisation STTS and dcs-bridge ask for, and should detect its absence at
start-up rather than fail later.

**A warning about probing:** dcs-bridge's `/api/exec` runs in a **third**, sandboxed environment — 96
globals, no `a_*`. A probe concluding "the function does not exist" may only be describing that
sandbox. Cross-check with `net.dostring_in` before believing it; this note's first draft did not, and
said the opposite of the truth.

Verified in game, F-16C cold on the ramp (through the bridge):

```lua
a_cockpit_highlight(100, 'PTR-ELEC-TMB-MPWR-510')   --> ok=true, box appears on the MAIN PWR switch
a_cockpit_remove_highlight(100)                     --> ok=true, box clears
```

**Two arguments are enough** for `a_cockpit_highlight(id, element_name)`. The trigger action's third
field (`size_of_box`) and its aircraft-module selector are not needed at the Lua call site.

`update_checklist` and `MAKE_CHECKLIST_ITEM` (from
`Scripts\Aircrafts\_Common\Cockpit\Macro_handler.lua`) are in **neither** environment — they live in
the aircraft module's own cockpit environment, and their logic has to be reimplemented, not called.

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

Two more things about `size`, both learned the hard way:

- It is a **percentage capped at 100** (ED's default is 100), so a picture can be shrunk and **never
  enlarged**. Whatever legibility is wanted in game has to be rendered into the image.
- **DCS caches an embedded resource by name.** Rebuild a mission with the same picture file name and
  the old bitmap keeps being displayed until DCS is fully restarted — reloading the mission is not
  enough. The symptom is vicious: only the states you had already displayed are stale, so you see one
  wrong image among correct ones and look for the bug in the generator. Give a regenerated resource a
  new name (a content hash) if you want to be safe.

## 3. A cockpit switch position cannot be read from the mission environment — but the export one reads it

**Measured in game**, F-16C on the ramp, David moving MAIN PWR through OFF → BATT → MAIN PWR
between reads. The answer took two sessions and reversed itself, so both halves are kept: what fails,
then what works.

Three independent mechanisms, all reachable from the mission environment, all blind to the cockpit:

| Mechanism | Result across three switch positions |
|---|---|
| `Unit:getDrawArgumentValue(510)` | `0`, `0`, `0` |
| `c_player_unit_argument_in_range(510, …)` | matches `[-0.1, 0.1]` only, in every position |
| `list_cockpit_params()` — 562 entries | no switch at all: no MAIN PWR, BATT, JFS, MASTER, SWITCH |

`getDrawArgumentValue` is **not** broken: a sweep of arguments 0-800 on the same unit returns **52
non-zero values** — gear down, control surfaces, lights. Those are the **external model's** draw
arguments. The cockpit is a separate model and its arguments do not reach the mission environment.

`list_cockpit_params()` is the same story one level up: of its 562 entries, **78 carry a non-zero
value**, and every one of them is *aircraft state* — `BASE_SENSOR_RADALT`, `BASE_SENSOR_IAS`,
`BASE_SENSOR_HEADING`, `BASE_SENSOR_FUEL_TOTAL`, `BASE_SENSOR_*_GEAR_DOWN`, `BASE_SENSOR_CANOPY_POS`,
`BASE_SENSOR_FLAPS_RETRACTED`, the atmosphere, the accelerations, the HMD. Not one control position.
`BASE_SENSOR_LEFT_THROTTLE_POS` exists in the list and stayed at `0` while the throttle was moved —
the F-16C simply does not publish it.

**Why ED's own checklists can do it and we cannot.** `MAKE_CHECKLIST_ITEM` and `update_checklist`
live in `Scripts\Aircrafts\_Common\Cockpit\Macro_handler.lua` and run **inside the module's cockpit
environment**, where the switch state is local. They are not exposed to the mission environment —
which was already noted in the ticket 01 spike, without the consequence being drawn.

**But there is a fourth mechanism, in a different environment.** `net.dostring_in` takes an
environment name, and `"mission"` is only one of them — `export`, `server`, `gui` and `config` answer
too (`cockpit` does not). **`export` is Export.lua's environment**, and it holds `GetDevice`,
`LoGetAircraftDrawArgumentValue`, `list_cockpit_params` and `LoGetSelfData`. Measured 2026-08-02,
same aircraft, same switch:

| MAIN PWR position | `LoGetAircraftDrawArgumentValue(510)` | `GetDevice(0):get_argument_value(510)` |
|---|---|---|
| OFF | `0` | **`-1.000`** |
| BATT | `0` | **`0.000`** |
| MAIN PWR | `0` | **`1.000`** |

`GetDevice(0):get_argument_value(arg)` reads the **cockpit** — the mechanism DCS-BIOS and SRS use —
and the values match the `arg_lim = {-1, 1}` of the switch's `default_3_position_tumb` prototype
exactly. `LoGetAircraftDrawArgumentValue` does not: like `Unit:getDrawArgumentValue`, it reads the
external model.

**The catch, and it is a real one: `Export.lua` runs on the pilot's machine.** From a mission script
on a dedicated server this very likely reaches nothing. Untested — it needs a real server — so
anything built on it should degrade to "never validates" rather than assume.

**What this leaves.** Validating a step by *the position of a control* works, through `export`, with
that reservation. Validating it by *the effect a control produces* works everywhere: altitude, speed,
heading, gear, canopy, flaps and fuel are readable and live from the mission environment itself.

## 4. A spring-loaded switch cannot be detected by its animation argument

Section 3 makes a switch readable through `export`. This is the second, independent reason a given
switch may still be unreadable, and it holds in **every** environment: a spring-loaded switch has no
position to read, because it is already back where it started.

The trailing number of a cockpit element name **is** its animation argument
(`PTR-ELEC-TMB-MPWR-510` → argument `510`). `clickabledata.lua` builds each element from a prototype
in `clickable_defs.lua`, and the prototype tells you what that argument does:

| Prototype | `arg_lim` | What the argument does |
|---|---|---|
| `default_3_position_tumb` | `{-1, 1}` | rests at −1 / 0 / +1 |
| `default_2_position_tumb` | `{0, 1}` | rests at 0 or 1 |
| `default_button` (`button_prototype`) | `{0, 1}` | rests at 0 or 1 |
| `springloaded_3_pos_tumb` | `{-1,0}` / `{0,1}` | **returns to 0 when released** |

A spring-loaded switch — the F-16C's JFS switch, for instance — is back at 0 by the time anything
polls it, so no argument window can catch that the pilot threw it. Those steps need a different
signal, or a pilot confirmation.

## 5. The command value is not necessarily the animation argument

`Macro_sequencies.lua` gives, for each step of ED's own autostart, the `value` of the **command**
sent to the device. On a simple tumbler that value and the animation argument coincide — for the
F-16C MAIN PWR switch, `MainPwrSw` takes `-1.0` / `0.0` / `1.0` and argument `510` reads the same.
That is a property of the prototype, not a rule: reading the argument in the cockpit, in every
position, stays the only way to know a window.

## 6. `Macro_sequencies.lua` is the real source for a start-up procedure

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

## 7. Not every name in a cockpit is an element you can box

`clickabledata.lua` names the **clickable** elements. Gauges and warning lights are not clickable and
have no entry there, so there is nothing to pass `a_cockpit_highlight`. A step about a gauge either
boxes the nearest clickable control on the same panel, or boxes nothing.
