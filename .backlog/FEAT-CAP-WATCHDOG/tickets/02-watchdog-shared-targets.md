# 02 — the watchdog spreads its CAP over several targets

Status: 🧑 waiting-human — done on the mocks, waits on R42 in `DCS-SESSION-TODO.md`
Type: feature
Issue: [#187](https://github.com/VEAF/VEAF-Mission-Creation-Tools/issues/187)

## Need

`veafSpawn.startCapWatchdog` pushes its `EngageUnit` tasks on the **group** controller, so a four-ship CAP facing two bandits sends all four after the same one.

## To find out first

Whether per-unit controllers in a group accept their own `EngageUnit` in DCS, or whether the group controller overrides them — a measurement in game, not a reading.
Do it after `FIX-IN-GAME-SESSION-2026-10-03` ticket 04, which may change how the tasks are pushed.

David chose on 2026-10-04 to code it first and settle it in game afterwards.

## Acceptance

- With several targets of comparable priority, the CAP's aircraft are given different ones.
- With one target, behaviour unchanged.

## Done

- `veafSpawn.spreadCapTargets` goes round the targets, most important first: two aircraft and two targets, one each; four and two, two each; two and three, the two most important. One target or one aircraft: no spread.
- The watchdog sets each aircraft's target on the aircraft's **own** controller (`setTask`), only when it changes; an aircraft with nothing left of its own is `resetTask` and follows the group again. A group rebuild sets the spread again on top of it. Out of its zone, every aircraft is reset.
- From the review of the diff: only aircraft in the air **and** in the zone get a target of their own; any other one of the group (landed, strayed out) is reset. What was given is remembered by unit id, so a group respawned under the same names is given its targets again.
- The group keeps its tasks exactly as before, so a DCS that ignores unit tasks leaves today's behaviour, not a CAP with no task.
- Tests: the spread itself, a two-ship going for both bandits, one bandit leaving the aircraft alone, an unchanged spread not set again, a reset when down to one bandit and out of the zone, a rebuild setting it again — each proven red under a sabotage of the code.

## To see in game

R42 item 1 — whether DCS lets the unit's task win, and what `resetTask` does to an aircraft.
