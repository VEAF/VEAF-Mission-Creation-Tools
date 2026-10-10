# 01 — A group not airborne yet is taking off, not landed

Status: 🧑 waiting-human

- `deploy` records when it scrambled (`deployedAt`) and which groups have been airborne since (`groupsSeenAirborne`).
- `check`, on an `ACTIVE` QRA: a group never seen airborne and within `veafQraManager.TAKEOFF_TIMEOUT` (600 s) of the scramble counts as in the air; past it, as landed — the reset of a stuck QRA, unchanged.
- Lua tests in `test_veafQraManager.lua` (`TestVeafQraGroundStart`): the first failed before the fix exactly as in game (`READY` at the first tick).
- Left: R47 item 3 in game, and the measured minutes from the scramble to wheels up written into the QRA page.
