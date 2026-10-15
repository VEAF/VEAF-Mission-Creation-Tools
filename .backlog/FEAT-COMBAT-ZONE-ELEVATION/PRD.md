# FEAT-COMBAT-ZONE-ELEVATION — the zone's ground elevation in a combat zone's briefing

Status: ✅ done

## Asked

David, 2026-10-14: add the zone's elevation to the combat zones' briefing.

## What exists

The radio menu's briefing of a combat zone is `VeafCombatZone:getInformation()` (`src/scripts/veaf/veafCombatZone.lua`).
When `isShowZonePositionInfo()` is on, it gives the zone centre as decimal and DMS lat/lon, MGRS and bearing and distance from bullseye, then the weather at the centre (`veafWeatherData.getWeatherString`).
Read on `develop` (ef518756): neither block gives an elevation — the weather string has wind, visibility, clouds, temperature, QNH, QFE and sun times, and no ground altitude.
A pilot attacking the zone has to read the elevation off the F10 map, or work it out from QNH and QFE.

## Tickets

| # | Ticket | Status |
|---|---|---|
| [01](tickets/01-elevation-line-in-zone-briefing.md) | An elevation line in the zone's position block | ✅ |

## Definition of done

- The briefing of an active zone with position info on shows `ELEVATION : <ft> ft / <m> m`, FR and EN, under the position lines.
- A Lua test on the mocks drives `getInformation()` and asserts the line and its value from a mocked `land.getHeight`; a zone with position info off shows no such line.
- `CHANGELOG.md` entry at the end of `[Unreleased]`; the combat zone documentation page (FR and EN) mentions the line if it lists the briefing's content.
- Demo mission: no step of its own — the line shows in the existing combat zone step.
