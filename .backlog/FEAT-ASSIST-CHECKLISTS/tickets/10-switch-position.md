# 10 — read a cockpit switch after all, through the export environment

Status: ✅ done — 2026-08-02, not yet flown. Opened after David asked whether a server hook or one of TUM's
tricks could get past the "a control's position cannot be read" wall. One of them can.

## What was measured

`net.dostring_in` takes an environment name, and `"mission"` is one of several. Probed in game on
2026-08-02, F-16C on the ramp:

```
mission=alive  export=alive  server=alive  gui=alive  config=alive  cockpit=nil

export holds: GetDevice, LoGetAircraftDrawArgumentValue, list_cockpit_params, LoGetSelfData
```

And the reading itself, with the MAIN PWR switch moved between calls:

| Position | `LoGetAircraftDrawArgumentValue(510)` | `GetDevice(0):get_argument_value(510)` |
|---|---|---|
| OFF | `0` | **`-1.000`** |
| BATT | `0` | **`0.000`** |
| MAIN PWR | `0` | **`1.000`** |

`GetDevice(0):get_argument_value()` reads the **cockpit**; everything tried before it read the
external model. This is the mechanism DCS-BIOS and SRS use, and it is reachable from a mission
script through the same `net.dostring_in` bridge the module already relies on — a second environment
away, not a second architecture.

The windows derived from `clickable_defs.lua` in ticket 06 were **right all along**: `arg_lim =
{-1, 1}` on a `default_3_position_tumb`, and the switch reads exactly −1 / 0 / +1. They were simply
unreadable from where we were looking.

## What this adds

A `switch` check beside `cockpit_param`, and the `argument:` field ticket 08 made a build error
becomes legitimate again:

```yaml
  - label: assist.f16c.main_pwr_on
    element: PTR-ELEC-TMB-MPWR-510
    argument: 510
    equals: 1.0
    tolerance: 0.05
```

`equals` / `tolerance` / `range` already exist and keep their meaning; only what they apply to is new.
A step still declares exactly one validation mode — `argument`, `param`, `check`, or the pilot.

## The multiplayer restriction, stated up front

`Export.lua` runs on the **pilot's** machine. A mission script on a **dedicated server** very likely
cannot reach a client's export environment, which would make this check silently never fire there.
Untestable solo; it has to be tried on the VEAF server before anyone builds a squadron mission on it.

Until that is known, the documentation says so plainly, and the engine degrades the way it already
does elsewhere: if the export environment does not answer, the step never self-validates and the
pilot still has "skip". No error storm, no stuck checklist.

## Runtime

`veafAssist.inExportEnv(code)`, sibling of `inTriggerEnv`, and a `switch` check reading through it.
One read per argument per tick, cached for the tick like the parameter dump — a checklist watching
three switches must not make three round trips per step evaluation.

Availability is detected once at initialisation, next to the cockpit primitives: `GetDevice` present
in `export` or not. Absent means `switch` steps never pass, and that is logged once.

## Tests

Lua: the mocks grow an **export** environment distinct from the trigger one (they are already
distinct from the mission's, which is the whole point) with a settable `GetDevice(0)`; a `switch`
step passes when the argument enters its window and not before; a missing export environment never
passes and does not throw; the read is cached per tick.

Python: `argument:` parses again and emits `{type = "switch", argument = N, min, max}`; the three
validation modes stay mutually exclusive; the F-16C checklist gets its two MAIN PWR steps back as
automatic ones.

## Definition of done

- Two of the six F-16C steps validate themselves in game.
- Documentation in both languages: the three validation modes, and the multiplayer caveat.
- The exploration note records `GetDevice(0):get_argument_value` and the environment list, and its
  section 3 is corrected — it currently says a switch position cannot be read at all, which was true
  of every mechanism tried at the time and is no longer true.
