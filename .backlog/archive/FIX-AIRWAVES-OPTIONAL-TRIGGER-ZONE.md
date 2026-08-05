# Lot FIX-AIRWAVES-OPTIONAL-TRIGGER-ZONE — trigger zone optional when center/radius are configured

Status: ✅ done

**Goal**: An `AIRWAVES` zone can be defined either by a Mission-Editor trigger zone (`trigger_zone_name`) **or** by explicit `zone_center_coordinates` + `zone_radius` (the runtime comment: *"radius … when not using a zone"*). `convert-v5` faithfully extracts all three keys when the v5 mission carried them, so a zone may end up with both a center/radius **and** a `trigger_zone_name` pointing at a trigger zone that no longer exists in the `.miz`. The generator emits the chain in order `setZoneCenterFromCoordinates → setTriggerZone → setZoneRadius`; at runtime `setTriggerZone()` ([veafAirWaves.lua](../../src/scripts/veaf/veafAirWaves.lua)) can't find the trigger zone and logs an **ERROR** — but the `if triggerZone` branch is false, so the previously-set center is untouched and the zone still works. The ERROR is cosmetic-but-alarming (David, VEAF-Demo-Mission, "Airwaves-1").

**Fix**: In `AirWaveZone:setTriggerZone`, when the trigger zone is absent **but a `zoneCenter` is already configured**, downgrade the `:error()` to a `:warn()` and keep the existing center/radius (the trigger zone is optional). Keep the `:error()` only when no center is configured (a genuine misconfiguration). **DCS runtime validation required** (runtime Lua change) — David tests in-game before merge.

**Workaround (immediate, for an already-migrated mission.yaml)**: remove the `trigger_zone_name:` line from the airwave zone — the zone keeps working via center/radius and the ERROR disappears.

**Branch**: `fix/airwaves-optional-trigger-zone` → PR → `develop`

| # | Ticket | Files | Type | Status |
|---|--------|-------|------|--------|
| FIX-AIRWAVES-OPTIONAL-TRIGGER-ZONE-001 | `setTriggerZone`: warn instead of error when the trigger zone is missing but a center is already set; preserve center/radius. luaunit tests (existing trigger zone → center/radius set; missing + center set → preserved, warn; missing + no center → center nil). DCS runtime validation by David. | `src/scripts/veaf/veafAirWaves.lua`, `test/lua/test_veafAirWaves.lua` | fix | ✅ (#508) |
