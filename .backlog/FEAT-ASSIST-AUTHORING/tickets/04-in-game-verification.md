# 04 — verify a resolved checklist in game

Status: ✅ done — 4 of 4 steps confirmed in a live F-14B(U) on 2026-08-03, after the first run found three defects.

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
- [x] Assisted mode as a command: `veaf-tools verify-checklist <file> --write`. It boxes each
      measurable step's control, **waits for the value to change and settle** rather than for a
      keypress — nobody holds a keyboard in a cockpit — reads it, and compares.
- [x] `verified: true` written back so a later run does not redo it.
- [x] Assisted mode documented for an instructor.
- [x] **One real run**, and it earned its keep: the first attempt confirmed **1 step of 4** and
      exposed three defects no unit test could have found.
      1. Everything the command said went to a console the pilot cannot see, at full screen in a
         cockpit. Instructions and outcomes now go through `trigger.action.outText` — measured on the
         bridge, `a_out_text_delay` in the trigger environment does *not* reach the screen.
      2. It prompted with the step's label — "Lancer le moteur droit" — which names neither the
         control nor the position. It now shows the instructor's own `control` text.
      3. Told to move a switch back and forth, it took the first half of the trip for the answer and
         announced the checklist had the wrong value. It now waits for the **wanted** value, and
         confirms a control already in position instead of waiting for a move that will not come.
      Second run: **4 of 4**, each step announced in game, boxed, awaited and confirmed.
- [ ] ~~Automatic mode via `a_cockpit_perform_clickable_action`~~ — **dropped, with a reason**. It
      needs the numeric device and command ids, and those are not in a module's readable files:
      searching the A-10C's entire `Cockpit/Scripts` tree for the ids its own autostart uses returns
      the autostart and nothing else. Reopen this only if a way to resolve those ids turns up.
