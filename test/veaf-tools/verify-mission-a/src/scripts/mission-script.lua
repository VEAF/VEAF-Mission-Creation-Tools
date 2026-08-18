-- mission-script.lua
-- Mission-specific Lua code that cannot be generated from mission.yaml.
--
-- This file is loaded AFTER veaf-config.lua (which is generated automatically
-- from mission.yaml by the veaf-tools build command).
--
-- Put here:
--   - Custom shortcuts / aliases  (VeafAlias:new():...)
--   - Custom Lua helper functions
--   - Third-party script setup (CTLD, CSAR, …) that requires Lua code
--
-- Do NOT put here:
--   - Module initialization calls  → use mission.yaml (modules:)
--   - Mission identity             → use mission.yaml (mission:)
--   - QRA definitions              → use mission.yaml (modules.QRA)
--   - Combat/CAP missions          → use mission.yaml (combat_missions: / cap_missions:)
--   - Assets lists                 → use mission.yaml (modules.ASSETS.assets)


-- ─────────────────────────────────────────────────────────────────────────────
-- #290 PROBE — is ALARM_STATE why a combat-zone convoy never moves?
--
-- Hypothesis (2026-08-17): veafCombatZone:activate() calls veaf.readyForCombat()
-- on every group it spawns, which applies veaf.defaultAlarmState = 2 (RED).
-- A DCS ground group in alarm state RED holds position and deploys -- correct for
-- a SAM battery, the opposite of what a convoy should do. Reading the code got us
-- here; only the game can settle it.
--
-- What this does: every 5 s, force ALARM_STATE back to 0 (AUTO) on any group whose
-- name contains "ConvoyBlue". Keyed on the substring because the spawned group is
-- renamed by veaf.getNameForSpawnedGroup, so its final name is not known here.
--
-- HOW TO READ THE RESULT
--   * the convoy starts moving after the probe fires  -> hypothesis CONFIRMED,
--     the fix belongs in how the zone chooses an alarm state per group
--   * the convoy still does not move                  -> hypothesis WRONG, and the
--     cause is elsewhere; say so on issue #290 rather than leaving it open
--
-- Delete this block once #290 is settled: it is a probe, not a feature.
-- ─────────────────────────────────────────────────────────────────────────────
-- Fires ONCE per group, never on a loop. The first version rescheduled itself every 5 s, and
-- re-applying setOption on a moving ground group looks like it interrupts the task in progress:
-- the lead truck set off, then stopped. That was the probe's own artefact, not the defect under
-- test -- a measuring instrument that changes what it measures.
local veafProbe290Done = {}

local function veafProbe290()
  for _, group in pairs(coalition.getGroups(coalition.side.BLUE, Group.Category.GROUND) or {}) do
    local name = group:getName() or ""
    if name:find("ConvoyBlue", 1, true) and not veafProbe290Done[name] then
      local cont = group:getController()
      if cont then
        veafProbe290Done[name] = true
        cont:setOption(AI.Option.Ground.id.ALARM_STATE, 0)
        trigger.action.outText("PROBE #290: ALARM_STATE -> AUTO on " .. name .. " (once)", 15)
      end
    end
  end
  -- Keep LOOKING for the group (it only exists once the zone is activated), but touch each one once.
  timer.scheduleFunction(veafProbe290, nil, timer.getTime() + 5)
end
timer.scheduleFunction(veafProbe290, nil, timer.getTime() + 10)
