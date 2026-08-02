# 04 — verify a resolved checklist in game

**Status:** ⬜ ready — depends on 03. Needs DCS running with the bridge.

A resolved value is a hypothesis until the argument has been read with the control in the wanted
position. [Ticket 10](../../FEAT-ASSIST-CHECKLISTS/tickets/10-switch-position.md) made that reading
possible: `GetDevice(0):get_argument_value(arg)` through the **export** environment.

This is also what closes ticket 03's ambiguous-value refusal: rather than asking the instructor to
guess which end of `MAIN PWR/BATT/OFF` is +1, throw the switch and look.

## Two modes

**Assisted** — the tool names a step, the pilot puts the control where the step says, confirms, and
the tool records the value it read. Works for every control, needs a human in the seat.

**Automatic** — `a_cockpit_perform_clickable_action(device, command, value)` throws the control and
the tool reads the resulting argument. The step data already carries `device` and `command`, carried
since the first ticket "for a future demonstration mode" — this is it. No human needed, but only for
controls that can be commanded that way.

Either way the result is written back as `equals` + `tolerance`, with a `verified: true` marker so a
later run does not redo it.

## Careful

- **Never drive the pilot's aircraft without saying so.** Automatic mode moves real switches in a
  real cockpit: it announces each action and needs an explicit opt-in flag.
- Reading through `export` makes this a **local** procedure — the aircraft must be flown on the
  machine running the tool.
- A value that comes back different from the resolver's guess is the interesting case. Report it
  loudly: it means the hint order ran the other way.

## Definition of done

- The F-16C's two MAIN PWR steps verified this way, confirming the measured −1 / 0 / +1.
- Assisted mode documented for an instructor, automatic mode as the developer path.
