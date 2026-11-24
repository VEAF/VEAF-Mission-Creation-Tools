# FEAT-COMBAT-ZONE-ELEVATION — the zone's ground elevation in a combat zone's briefing

Status: ✅ done · archived 2026-11-24

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
| [01](FEAT-COMBAT-ZONE-ELEVATION.md) | An elevation line in the zone's position block | ✅ |

## Definition of done

- The briefing of an active zone with position info on shows `ELEVATION : <ft> ft / <m> m`, FR and EN, under the position lines.
- A Lua test on the mocks drives `getInformation()` and asserts the line and its value from a mocked `land.getHeight`; a zone with position info off shows no such line.
- `CHANGELOG.md` entry at the end of `[Unreleased]`; the combat zone documentation page (FR and EN) mentions the line if it lists the briefing's content.
- Demo mission: no step of its own — the line shows in the existing combat zone step.

## Tickets, in full

## 01 — An elevation line in the zone's position block

Status: ✅ done
Type: feature
Files: `src/scripts/veaf/veafCombatZone.lua` (`VeafCombatZone:getInformation`), `src/scripts/veaf/veafI18n.lua`, `test/lua/test_veafCombatZone.lua`, the combat zone doc page (FR + EN) if it lists the briefing's lines

### What to do

In the `isShowZonePositionInfo()` block of `getInformation()`, after `report.from_bullseye`, add a `report.elevation` line: the terrain height at the zone centre, `land.getHeight({ x = center.x, y = center.z })`, in feet and metres, rounded to the unit.
Read the height from the terrain rather than from `zoneCenter.y`: the centre may have been built from a trigger zone whose `y` is not the ground (see `docs/agents/dcs-coordinates.md` — the 2D `y` of `land.getHeight` is the vec3's `z`).

Format, aligned with the other position lines:

- FR: `ÉLÉVATION        : %d ft / %d m.\n`
- EN: `ELEVATION        : %d ft / %d m.\n`

### Choices made by default

- **The centre only**, not the highest point inside the zone's radius: it is what the other position lines describe, and a sampled maximum would cost a grid of `land.getHeight` calls on every briefing for a value nobody asked for. Reopen if a pilot needs a minimum safe altitude over the zone.
- **Only with position info on**: a zone that hides its coordinates should not give its height either.

### Done when

- Test on the mocks: `land.getHeight` mocked at 412 m → the briefing contains `1352 ft / 412 m`; position info off → no elevation line.
- `poetry run test-lua`, `stylua --check src/scripts/veaf/ test/lua/` and luacheck pass.
