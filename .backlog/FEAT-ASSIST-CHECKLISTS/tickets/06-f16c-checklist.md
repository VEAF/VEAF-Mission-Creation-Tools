# 06 — F-16C cold-start checklist, six steps

Status: 🧑 waiting-human — the checklist is written, loads and renders. It is **pilot-confirmed
throughout**: the in-game probe of 2026-08-01 showed a cockpit control's position cannot be read at all,
so the three automatic steps became confirm steps. What remains is a pilot's review of the slice.

The first checklist, and the lot's only content. Six steps, hand-written, shipped in the VMCT catalogue as
`checklists/f16c-cold-start.yaml`.

## The elements, read from the module

Verified in `<DCS>\Mods\aircraft\F-16C\Cockpit\Scripts\clickabledata.lua` on 2026-08-01. The trailing
number in each element name **is** the animation argument.

| Element | Label as ED writes it | Arg |
|---|---|---|
| `PTR-ELEC-TMB-MPWR-510` | MAIN PWR Switch, MAIN PWR/BATT/OFF | 510 |
| `PTR-FUELCP-TMB-ENGFEED-556` | ENGINE FEED Knob, OFF/NORM/AFT/FWD | 556 |
| `PTR-ENGSTART-TMB-JETFUEL-447` | JFS Switch, START 1/OFF/START 2 | 447 |
| `PTR-THRTL-RLS-757` | Throttle, OFF/IDLE | 757 |
| `PTR-ENGSTART-TMB-ENGCNT-449` | ENG CONT Switch, PRI/SEC | 449 |
| `PTR-EPU-TMB-EPUTMB-528` | EPU Switch, ON/NORM/OFF | 528 |

## What must be measured, not guessed

**The window per step.** A 3-position switch may run 0 / 0.5 / 1 or -1 / 0 / 1; the 4-position ENGINE FEED
knob steps by 0.1. Sit in the cockpit and read each argument with `env=mission` through the bridge:

```lua
return tostring(Unit.getByName('<slot>'):getDrawArgumentValue(510))
```

Record the value **for every position of every switch**, not just the target one, and pick an `equals` +
`tolerance` narrow enough to reject the neighbouring position. Write the measured table into this ticket —
it is reference data the follow-up generator lot will want.

## The order comes from ED, not from us

`<DCS>\Mods\aircraft\F-16C\Cockpit\Scripts\Macro_sequencies.lua` holds ED's own autostart sequence:
**106 labelled steps** in `start_sequence_full`, each one carrying the label, the device, the command and
the target value.

```lua
push_start_command(dt, {message = _("- MAIN PWR SWITCH - OFF"), message_timeout = dt_mto})
push_start_command(dt, {device = devices.ELEC_INTERFACE, action = elec_commands.MainPwrSw, value = -1.0})
```

**Take the order and the labels from there.** An earlier draft of this ticket proposed a six-step order
written from the switch labels alone; it was wrong. ED's sequence opens with the ejection safety lever and
the canopy jettison handle, then sets MAIN PWR to **OFF** — an initial-configuration phase the draft had
ignored entirely, and the draft's first step ("MAIN PWR → MAIN PWR") contradicted it.

Two things that phase also reveals: guarded switches (FUEL MASTER, ENG CONT) take **three commands** —
open the guard, throw the switch, close the guard — so one step per switch is not always the right
granularity; and the file carries named verification conditions (`JFS RUN LIGHT MUST BE ON`,
`THROTTLE MUST BE AT IDLE`, `ENGINE RPM FAILURE`) which are exactly the `check_routine` of ED's
`MAKE_CHECKLIST_ITEM`.

For the prototype, pick **a coherent contiguous slice** of that sequence — the engine-start phase proper
rather than the full cockpit check — and keep ED's wording for the labels. Make at least one step a
`confirm` one (a "must be on / must be at" condition is a natural fit), so the prototype exercises both
validation modes and not only the automatic one.

A pilot review is still required — a slice can be coherent in the file and wrong in isolation — but it is
now a review of ED's sequence rather than of my guesswork.

**Careful with `value`:** it is the value of the *command* sent to the device, not the animation argument
our checks read. They often coincide on a switch, but that is not guaranteed, which is why the
measurement below stays mandatory.

## i18n

Labels are catalog keys (`assist.f16c.*`) with FR + EN entries, per
[ADR 0006](../../../docs/adr/0006-lua-runtime-i18n.md). ED's English labels are a fine basis for wording;
do not paste localised strings out of DCS files.

Check the exact DCS type name for the `aircraft` list against the unit catalogue rather than assuming
`F-16C_50`.

## Definition of done

- Six steps, each with a measured window, loading and running through the engine.
- FR + EN catalog entries.
- The order reviewed by an F-16C pilot, and **who reviewed it recorded in this ticket**.
- The measured argument table recorded here.

## What was written

[`veaf_libs/data/checklists/f16c-cold-start.yaml`](../../../src/python/veaf-tools/veaf_libs/data/checklists/f16c-cold-start.yaml),
six steps, plus FR + EN entries under `assist.f16c.*` in
[`veafI18n.lua`](../../../src/scripts/veaf/veafI18n.lua). It loads through `load_checklists()` and renders
to seven images.

**The slice** is ED's own `start_sequence_full`, lines 259–285 of `Macro_sequencies.lua`: the *Before
Starting Engine* / *Starting Engine* phase, in ED's order and with ED's wording. Not the six switches an
earlier draft picked, and not the 106-step whole.

| # | ED's label | Element | Mode |
|---|---|---|---|
| 1 | `- MAIN PWR SWITCH - BATT` | `PTR-ELEC-TMB-MPWR-510` | confirm |
| 2 | `- MAIN PWR SWITCH - MAIN PWR` | `PTR-ELEC-TMB-MPWR-510` | confirm |
| 3 | `- JFS SWITCH - START 2` | `PTR-ENGSTART-TMB-JETFUEL-447` | confirm |
| 4 | `- JFS RUN LIGHT - CHECK` | `PTR-ENGSTART-TMB-JETFUEL-447` | confirm |
| 5 | `- THROTTLE - IDLE (20% RPM MINIMUM)` | `PTR-THRTL-RLS-757` | confirm |
| 6 | `- ENGINE AT IDLE - CHECK` | — | confirm |

**Every step is pilot-confirmed**, and steps 1, 2 and 5 were automatic until the in-game probe of
2026-08-01 showed that a cockpit control's position cannot be read from the mission environment at
all — see [the exploration note](../../../docs/exploration/DCS-COCKPIT-ASSISTANCE-API.md) section 3.
Nothing in an engine start has a readable *effect* to fall back on either: the aircraft publishes no
switch state, and its RPM only becomes meaningful once the engine runs, which is the last step. So
this checklist boxes the control, shows the progress and lets the pilot tick — which is what the
assistance is worth here.

**Why the JFS switch is not an argument step.** `clickabledata.lua:118` builds it with
`springloaded_3_pos_tumb`: the switch is spring-loaded and its animation argument returns to 0 the instant
it is released — ED's own sequence sets `JfsSwStart2` to `-1.0` then straight back to `0.0`. Reading
argument 447 could therefore never catch it. It is boxed anyway, so the pilot sees where to look.

**Step 6 boxes nothing.** The engine RPM gauge is not a clickable element, so it has no name to box, and
the format allows a confirm step with no element. Note in passing that the PRD's example element
`PTR-HYDCP-IND-3018` **does not exist** anywhere in the F-16C module — it was an illustration, not a
reference; nothing in this checklist uses it.

## The windows: moot, and here is why

The measurement this ticket demanded was attempted on 2026-08-01 and returned the finding that
removed the need for it. Kept below because the element/argument mapping is still correct reference
data — it is what a future in-cockpit bridge would use — and because the reasoning that produced it
is sound even though its conclusion is now unreachable.

## The windows were derived, not measured

Every element and argument above is read from
`<DCS>\Mods\aircraft\F-16C\Cockpit\Scripts\clickabledata.lua` (verified 2026-08-01). The **windows** are
derived from the switch prototypes in `clickable_defs.lua`, which is one inference away from a
measurement:

| Element | Prototype | `arg_lim` | Derived positions |
|---|---|---|---|
| `PTR-ELEC-TMB-MPWR-510` | `default_3_position_tumb` (`clickable_defs.lua:96`) | `{-1, 1}` | −1 OFF · 0 BATT · +1 MAIN PWR |
| `PTR-ENGSTART-TMB-JETFUEL-447` | `springloaded_3_pos_tumb` (`:256`) | `{-1,0}` / `{0,1}` | rests at 0 |
| `PTR-THRTL-RLS-757` | `default_button` → `button_prototype` (`:27`) | `{0, 1}` | 0 OFF · 1 IDLE |

The MAIN PWR mapping is corroborated by ED's sequence, which sends `MainPwrSw` `-1.0` for OFF (line 101),
`0.0` for BATT (line 266) and `1.0` for MAIN PWR (line 271) — command value and animation argument agree
*on this switch*. That agreement is exactly what the ticket warns is not guaranteed in general, so the
measurement stays mandatory:

```lua
-- with the player sitting in the F-16C, through the bridge with env=mission,
-- once per position of each switch:
return tostring(Unit.getByName('<slot>'):getDrawArgumentValue(510))
```

**One thing left:** a **pilot review of the slice.** It is coherent in ED's file; whether it is
coherent *in isolation* — starting an engine without the cockpit configuration that precedes it in
the full sequence — is a question for someone who flies the jet. Reviewer: _not yet reviewed_.
