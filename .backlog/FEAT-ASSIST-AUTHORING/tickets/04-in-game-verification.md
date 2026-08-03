# 04 — verify a resolved checklist in game

**Status:** 🔄 in-progress — the reading is proven in game (2026-08-03); the assisted and automatic *modes* are not built yet.

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

## What the first session established (2026-08-03)

Done by hand through the bridge, in a F-14B(U) cockpit, before any of the tooling below exists:

| Argument | Control | Position | Read | Inferred from bindings |
|---|---|---|---|---|
| 629 | Hydraulic Transfer Pump | NORMAL | `0` | 0.0 ✅ |
| 629 | Hydraulic Transfer Pump | SHUTOFF | `1` | 1.0 ✅ |
| 2102 | Engine Crank | Right | `-1` | −1.0 ✅ |
| 2102 | Engine Crank | Left | `1` | +1.0 ✅ |

**Four for four.** This is the first confirmation of the binding-derived values on a *third-party*
aircraft, and on one whose hints name no positions at all — the bindings were the only possible
source, so there was nothing to cross-check them against until now.

Two things also proved themselves in passing:

- `a_cockpit_highlight(id, element)` through `net.dostring_in("mission", …)` boxed `PNT_629` in a
  live cockpit on request. David could not find the control; boxing it answered the question
  instantly. **That is the assisted mode, minus the loop** — the hard part already works.
- The `export` read works on a Heatblur module, not just on ED's.

## Definition of done

- [x] Values verified by reading the argument with the control in the wanted position — done on the
      F-14B(U) rather than the F-16C, whose MAIN PWR was already measured on 2026-08-02.
- [ ] Assisted mode as a command: name a step, box the control, wait for the pilot, record the value.
- [ ] Automatic mode via `a_cockpit_perform_clickable_action`, behind an explicit opt-in.
- [ ] `verified: true` written back so a later run does not redo it.
- [ ] Assisted mode documented for an instructor, automatic mode as the developer path.
