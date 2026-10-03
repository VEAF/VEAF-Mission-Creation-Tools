# 02 — the watchdog spreads its CAP over several targets

Status: ⬜ ready
Type: feature
Issue: [#187](https://github.com/VEAF/VEAF-Mission-Creation-Tools/issues/187)

## Need

`veafSpawn.startCapWatchdog` pushes its `EngageUnit` tasks on the **group** controller, so a four-ship
CAP facing two bandits sends all four after the same one.

## To find out first

Whether per-unit controllers in a group accept their own `EngageUnit` in DCS, or whether the group
controller overrides them — a measurement in game, not a reading. Do it after
`FIX-IN-GAME-SESSION-2026-10-03` ticket 04, which may change how the tasks are pushed.

## Acceptance

- With several targets of comparable priority, the CAP's aircraft are given different ones.
- With one target, behaviour unchanged.
