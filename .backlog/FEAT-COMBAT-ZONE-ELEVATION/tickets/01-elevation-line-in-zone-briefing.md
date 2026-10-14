# 01 — An elevation line in the zone's position block

Status: ⬜ ready
Type: feature
Files: `src/scripts/veaf/veafCombatZone.lua` (`VeafCombatZone:getInformation`), `src/scripts/veaf/veafI18n.lua`, `test/lua/test_veafCombatZone.lua`, the combat zone doc page (FR + EN) if it lists the briefing's lines

## What to do

In the `isShowZonePositionInfo()` block of `getInformation()`, after `report.from_bullseye`, add a `report.elevation` line: the terrain height at the zone centre, `land.getHeight({ x = center.x, y = center.z })`, in feet and metres, rounded to the unit.
Read the height from the terrain rather than from `zoneCenter.y`: the centre may have been built from a trigger zone whose `y` is not the ground (see `docs/agents/dcs-coordinates.md` — the 2D `y` of `land.getHeight` is the vec3's `z`).

Format, aligned with the other position lines:

- FR: `ÉLÉVATION        : %d ft / %d m.\n`
- EN: `ELEVATION        : %d ft / %d m.\n`

## Choices made by default

- **The centre only**, not the highest point inside the zone's radius: it is what the other position lines describe, and a sampled maximum would cost a grid of `land.getHeight` calls on every briefing for a value nobody asked for. Reopen if a pilot needs a minimum safe altitude over the zone.
- **Only with position info on**: a zone that hides its coordinates should not give its height either.

## Done when

- Test on the mocks: `land.getHeight` mocked at 412 m → the briefing contains `1352 ft / 412 m`; position info off → no elevation line.
- `poetry run test-lua`, `stylua --check src/scripts/veaf/ test/lua/` and luacheck pass.
