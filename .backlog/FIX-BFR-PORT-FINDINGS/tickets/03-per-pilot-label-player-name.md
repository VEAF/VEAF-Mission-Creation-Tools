# 03 — The per-pilot label falls back to the player's name

Status: ⬜ ready

Issue: [#1304](https://github.com/VEAF/VEAF-Mission-Creation-Tools/issues/1304).

Without the VEAF server hook, `veafRemote` knows no unit, and a per-pilot submenu carries the DCS callsign cached at birth instead of the player's name.
The existing `getPlayerName()` fallback (`veafRadio.lua:145-148`) never runs: it is called on `event.initiator`, a data table with no methods.

- At render, when `veafRemote` does not know the unit, read `Unit.getByName(unitName):getPlayerName()` (guarded: unit gone, or no player → keep the callsign).
- Remove the dead fallback.
- The hook's name, when present, still wins.

Tests: a human unit unknown to `veafRemote` with a player name in the mocks → the label is the player's name; the unit gone → the callsign, no error; a unit known to `veafRemote` → the hook's name.

Done when: the tests pass.
