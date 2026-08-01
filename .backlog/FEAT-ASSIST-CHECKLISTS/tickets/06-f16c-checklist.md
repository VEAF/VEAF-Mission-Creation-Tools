# 06 — F-16C cold-start checklist, six steps

**Status:** ⬜ ready — depends on 02 for the format. Can run in parallel with 03 and 04.

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
