--- Unit tests for veafTime.lua
---
--- Run:  lua test/lua/test_veafTime.lua
---
--- Covers:
---   - determineSeason for both hemispheres (all 12 months)
---   - toStringDate / toStringTime / toStringDateTime formatting
---   - getMissionDateTime (basic, rollovers, leap year)
---   - getMissionAbsTime (same day, next day, round-trip)
---   - toZulu / toLocal (offset arithmetic, day-boundary crossing)
---   - getTimezone (theatre-based lookup, no vec3)
---   - absTimeToStringDate / absTimeToStringTime wrappers

local _base = debug.getinfo(1, "S").source:match("^@(.+)[\\/]") or "."
luaunit = dofile(_base .. "/luaunit.lua")
dofile(_base .. "/dcs_mocks.lua")
local src = _base .. "/../../src/scripts/veaf"
dofile(src .. "/veaf.lua")
dofile(src .. "/veafTime.lua")

-- ============================================================================
-- Test suite
-- ============================================================================
TestVeafTime = {}

--- Restore a known-good date and theatre before every test.
function TestVeafTime:setUp()
  dcs_mocks.reset()
  env.mission.date = { Day = 1, Month = 1, Year = 2024 }
  env.mission.theatre = "Caucasus"
end

-- -----------------------------------------------------------------------
-- determineSeason — Northern Hemisphere (lat 48 N)
-- -----------------------------------------------------------------------
function TestVeafTime:test_determineSeason_N_dec()
  luaunit.assertEquals(veafTime.determineSeason(12, 48), "winter")
end
function TestVeafTime:test_determineSeason_N_jan()
  luaunit.assertEquals(veafTime.determineSeason(1, 48), "winter")
end
function TestVeafTime:test_determineSeason_N_feb()
  luaunit.assertEquals(veafTime.determineSeason(2, 48), "winter")
end
function TestVeafTime:test_determineSeason_N_mar()
  luaunit.assertEquals(veafTime.determineSeason(3, 48), "spring")
end
function TestVeafTime:test_determineSeason_N_apr()
  luaunit.assertEquals(veafTime.determineSeason(4, 48), "spring")
end
function TestVeafTime:test_determineSeason_N_may()
  luaunit.assertEquals(veafTime.determineSeason(5, 48), "spring")
end
function TestVeafTime:test_determineSeason_N_jun()
  luaunit.assertEquals(veafTime.determineSeason(6, 48), "summer")
end
function TestVeafTime:test_determineSeason_N_jul()
  luaunit.assertEquals(veafTime.determineSeason(7, 48), "summer")
end
function TestVeafTime:test_determineSeason_N_aug()
  luaunit.assertEquals(veafTime.determineSeason(8, 48), "summer")
end
function TestVeafTime:test_determineSeason_N_sep()
  luaunit.assertEquals(veafTime.determineSeason(9, 48), "autumn")
end
function TestVeafTime:test_determineSeason_N_oct()
  luaunit.assertEquals(veafTime.determineSeason(10, 48), "autumn")
end
function TestVeafTime:test_determineSeason_N_nov()
  luaunit.assertEquals(veafTime.determineSeason(11, 48), "autumn")
end

-- nil latitude is treated as Northern (>= 0 branch)
function TestVeafTime:test_determineSeason_nil_lat_summer()
  luaunit.assertEquals(veafTime.determineSeason(6, nil), "summer")
end

-- Equator (lat == 0) is treated as Northern
function TestVeafTime:test_determineSeason_equator_summer()
  luaunit.assertEquals(veafTime.determineSeason(6, 0), "summer")
end
function TestVeafTime:test_determineSeason_equator_winter()
  luaunit.assertEquals(veafTime.determineSeason(1, 0), "winter")
end

-- -----------------------------------------------------------------------
-- determineSeason — Southern Hemisphere (lat -34 S)
-- -----------------------------------------------------------------------
function TestVeafTime:test_determineSeason_S_dec()
  luaunit.assertEquals(veafTime.determineSeason(12, -34), "summer")
end
function TestVeafTime:test_determineSeason_S_jan()
  luaunit.assertEquals(veafTime.determineSeason(1, -34), "summer")
end
function TestVeafTime:test_determineSeason_S_feb()
  luaunit.assertEquals(veafTime.determineSeason(2, -34), "summer")
end
function TestVeafTime:test_determineSeason_S_mar()
  luaunit.assertEquals(veafTime.determineSeason(3, -34), "autumn")
end
function TestVeafTime:test_determineSeason_S_apr()
  luaunit.assertEquals(veafTime.determineSeason(4, -34), "autumn")
end
function TestVeafTime:test_determineSeason_S_may()
  luaunit.assertEquals(veafTime.determineSeason(5, -34), "autumn")
end
function TestVeafTime:test_determineSeason_S_jun()
  luaunit.assertEquals(veafTime.determineSeason(6, -34), "winter")
end
function TestVeafTime:test_determineSeason_S_jul()
  luaunit.assertEquals(veafTime.determineSeason(7, -34), "winter")
end
function TestVeafTime:test_determineSeason_S_aug()
  luaunit.assertEquals(veafTime.determineSeason(8, -34), "winter")
end
function TestVeafTime:test_determineSeason_S_sep()
  luaunit.assertEquals(veafTime.determineSeason(9, -34), "spring")
end
function TestVeafTime:test_determineSeason_S_oct()
  luaunit.assertEquals(veafTime.determineSeason(10, -34), "spring")
end
function TestVeafTime:test_determineSeason_S_nov()
  luaunit.assertEquals(veafTime.determineSeason(11, -34), "spring")
end

-- -----------------------------------------------------------------------
-- toStringDate
-- -----------------------------------------------------------------------
function TestVeafTime:test_toStringDate_pads_single_digit_day_month()
  luaunit.assertEquals(veafTime.toStringDate({ year = 2024, month = 3, day = 5, yday = 65, hour = 0, min = 0, sec = 0 }), "05/03/2024")
end

function TestVeafTime:test_toStringDate_new_year_day()
  luaunit.assertEquals(veafTime.toStringDate({ year = 2000, month = 1, day = 1, yday = 1, hour = 0, min = 0, sec = 0 }), "01/01/2000")
end

function TestVeafTime:test_toStringDate_year_end()
  luaunit.assertEquals(veafTime.toStringDate({ year = 2023, month = 12, day = 31, yday = 365, hour = 0, min = 0, sec = 0 }), "31/12/2023")
end

function TestVeafTime:test_toStringDate_double_digit_day_month()
  luaunit.assertEquals(veafTime.toStringDate({ year = 2024, month = 11, day = 15, yday = 320, hour = 0, min = 0, sec = 0 }), "15/11/2024")
end

-- -----------------------------------------------------------------------
-- toStringTime
-- -----------------------------------------------------------------------
function TestVeafTime:test_toStringTime_with_seconds()
  luaunit.assertEquals(veafTime.toStringTime({ hour = 9, min = 5, sec = 7 }, true), "09:05:07")
end

function TestVeafTime:test_toStringTime_without_seconds()
  luaunit.assertEquals(veafTime.toStringTime({ hour = 9, min = 5, sec = 7 }, false), "09:05")
end

function TestVeafTime:test_toStringTime_nil_defaults_to_with_seconds()
  luaunit.assertEquals(veafTime.toStringTime({ hour = 14, min = 30, sec = 0 }), "14:30:00")
end

function TestVeafTime:test_toStringTime_midnight()
  luaunit.assertEquals(veafTime.toStringTime({ hour = 0, min = 0, sec = 0 }, true), "00:00:00")
end

function TestVeafTime:test_toStringTime_just_before_midnight()
  luaunit.assertEquals(veafTime.toStringTime({ hour = 23, min = 59, sec = 59 }, true), "23:59:59")
end

-- -----------------------------------------------------------------------
-- toStringDateTime
-- -----------------------------------------------------------------------
function TestVeafTime:test_toStringDateTime_with_seconds()
  local dt = { year = 2024, month = 3, day = 15, yday = 75, hour = 10, min = 30, sec = 45 }
  luaunit.assertEquals(veafTime.toStringDateTime(dt, true), "15/03/2024 10:30:45")
end

function TestVeafTime:test_toStringDateTime_without_seconds()
  local dt = { year = 2024, month = 3, day = 15, yday = 75, hour = 10, min = 30, sec = 45 }
  luaunit.assertEquals(veafTime.toStringDateTime(dt, false), "15/03/2024 10:30")
end

-- -----------------------------------------------------------------------
-- getMissionDateTime
-- -----------------------------------------------------------------------
function TestVeafTime:test_getMissionDateTime_midnight_returns_start_date()
  local dt = veafTime.getMissionDateTime(0)
  luaunit.assertEquals(dt.day, 1)
  luaunit.assertEquals(dt.month, 1)
  luaunit.assertEquals(dt.year, 2024)
  luaunit.assertEquals(dt.hour, 0)
  luaunit.assertEquals(dt.min, 0)
  luaunit.assertEquals(dt.sec, 0)
end

function TestVeafTime:test_getMissionDateTime_noon()
  -- 12 * 3600 = 43200
  local dt = veafTime.getMissionDateTime(43200)
  luaunit.assertEquals(dt.hour, 12)
  luaunit.assertEquals(dt.min, 0)
  luaunit.assertEquals(dt.sec, 0)
  luaunit.assertEquals(dt.day, 1)
end

function TestVeafTime:test_getMissionDateTime_specific_hms()
  -- 10:30:45 = 10*3600 + 30*60 + 45 = 37845
  local dt = veafTime.getMissionDateTime(37845)
  luaunit.assertEquals(dt.hour, 10)
  luaunit.assertEquals(dt.min, 30)
  luaunit.assertEquals(dt.sec, 45)
end

function TestVeafTime:test_getMissionDateTime_day_rollover()
  -- 25 hours = 90000 s → day 2, hour 1
  local dt = veafTime.getMissionDateTime(90000)
  luaunit.assertEquals(dt.day, 2)
  luaunit.assertEquals(dt.hour, 1)
end

function TestVeafTime:test_getMissionDateTime_month_rollover()
  -- Jan 31 + exactly 1 day → Feb 1
  env.mission.date = { Day = 31, Month = 1, Year = 2024 }
  local dt = veafTime.getMissionDateTime(86400)
  luaunit.assertEquals(dt.day, 1)
  luaunit.assertEquals(dt.month, 2)
  luaunit.assertEquals(dt.year, 2024)
end

function TestVeafTime:test_getMissionDateTime_year_rollover()
  -- Dec 31 2023 + 1 day → Jan 1 2024
  env.mission.date = { Day = 31, Month = 12, Year = 2023 }
  local dt = veafTime.getMissionDateTime(86400)
  luaunit.assertEquals(dt.day, 1)
  luaunit.assertEquals(dt.month, 1)
  luaunit.assertEquals(dt.year, 2024)
end

function TestVeafTime:test_getMissionDateTime_leap_year_feb28_plus1()
  -- 2024 is a leap year: Feb 28 + 1 day = Feb 29
  env.mission.date = { Day = 28, Month = 2, Year = 2024 }
  local dt = veafTime.getMissionDateTime(86400)
  luaunit.assertEquals(dt.day, 29)
  luaunit.assertEquals(dt.month, 2)
end

function TestVeafTime:test_getMissionDateTime_non_leap_year_feb28_plus1()
  -- 2023 is NOT a leap year: Feb 28 + 1 day = Mar 1
  env.mission.date = { Day = 28, Month = 2, Year = 2023 }
  local dt = veafTime.getMissionDateTime(86400)
  luaunit.assertEquals(dt.day, 1)
  luaunit.assertEquals(dt.month, 3)
  luaunit.assertEquals(dt.year, 2023)
end

function TestVeafTime:test_getMissionDateTime_yday_march1_leap()
  -- 2024: Jan(31) + Feb(29) + 1 = day 61
  env.mission.date = { Day = 1, Month = 3, Year = 2024 }
  local dt = veafTime.getMissionDateTime(0)
  luaunit.assertEquals(dt.yday, 61)
end

function TestVeafTime:test_getMissionDateTime_yday_march1_nonleap()
  -- 2023: Jan(31) + Feb(28) + 1 = day 60
  env.mission.date = { Day = 1, Month = 3, Year = 2023 }
  local dt = veafTime.getMissionDateTime(0)
  luaunit.assertEquals(dt.yday, 60)
end

-- -----------------------------------------------------------------------
-- getMissionAbsTime
-- -----------------------------------------------------------------------
function TestVeafTime:test_getMissionAbsTime_same_day()
  -- Mission starts Jan 1 2024; 10:30:45 on the same day
  env.mission.date = { Day = 1, Month = 1, Year = 2024 }
  local abs = veafTime.getMissionAbsTime({ year = 2024, month = 1, day = 1, hour = 10, min = 30, sec = 45 })
  luaunit.assertEquals(abs, 37845) -- 10*3600+30*60+45
end

function TestVeafTime:test_getMissionAbsTime_next_day()
  env.mission.date = { Day = 1, Month = 1, Year = 2024 }
  local abs = veafTime.getMissionAbsTime({ year = 2024, month = 1, day = 2, hour = 0, min = 0, sec = 0 })
  luaunit.assertEquals(abs, 86400)
end

function TestVeafTime:test_getMissionAbsTime_round_trip()
  -- absTime → dateTime → absTime must be identity
  env.mission.date = { Day = 5, Month = 6, Year = 2024 }
  local originalAbs = 37845
  local dt = veafTime.getMissionDateTime(originalAbs)
  local abs = veafTime.getMissionAbsTime(dt)
  luaunit.assertEquals(abs, originalAbs)
end

function TestVeafTime:test_getMissionAbsTime_round_trip_midnight()
  env.mission.date = { Day = 1, Month = 1, Year = 2024 }
  local dt = veafTime.getMissionDateTime(0)
  local abs = veafTime.getMissionAbsTime(dt)
  luaunit.assertEquals(abs, 0)
end

-- -----------------------------------------------------------------------
-- toZulu / toLocal
-- -----------------------------------------------------------------------
function TestVeafTime:test_toZulu_subtracts_positive_offset()
  -- 14:00 local at UTC+4 → 10:00 UTC
  local loc = { year = 2024, month = 6, day = 15, yday = 167, hour = 14, min = 0, sec = 0 }
  local z = veafTime.toZulu(loc, 4)
  luaunit.assertEquals(z.hour, 10)
  luaunit.assertEquals(z.min, 0)
  luaunit.assertEquals(z.day, 15)
end

function TestVeafTime:test_toZulu_day_boundary_backward()
  -- 02:00 local at UTC+4 → 22:00 of the previous day UTC
  local loc = { year = 2024, month = 6, day = 15, yday = 167, hour = 2, min = 0, sec = 0 }
  local z = veafTime.toZulu(loc, 4)
  luaunit.assertEquals(z.hour, 22)
  luaunit.assertEquals(z.day, 14)
end

function TestVeafTime:test_toZulu_negative_offset_day_boundary_forward()
  -- 22:00 local at UTC-8 → 06:00 of the next day UTC
  local loc = { year = 2024, month = 6, day = 15, yday = 167, hour = 22, min = 0, sec = 0 }
  local z = veafTime.toZulu(loc, -8)
  luaunit.assertEquals(z.hour, 6)
  luaunit.assertEquals(z.day, 16)
end

function TestVeafTime:test_toZulu_preserves_minutes()
  -- 08:45 local at UTC+4 → 04:45 UTC
  local loc = { year = 2024, month = 1, day = 1, yday = 1, hour = 8, min = 45, sec = 0 }
  local z = veafTime.toZulu(loc, 4)
  luaunit.assertEquals(z.hour, 4)
  luaunit.assertEquals(z.min, 45)
end

function TestVeafTime:test_toZulu_zero_offset_unchanged()
  local loc = { year = 2024, month = 1, day = 1, yday = 1, hour = 12, min = 0, sec = 0 }
  local z = veafTime.toZulu(loc, 0)
  luaunit.assertEquals(z.hour, 12)
  luaunit.assertEquals(z.day, 1)
end

function TestVeafTime:test_toLocal_is_inverse_of_toZulu()
  local original = { year = 2024, month = 6, day = 15, yday = 167, hour = 14, min = 30, sec = 0 }
  local z = veafTime.toZulu(original, 4)
  local loc = veafTime.toLocal(z, 4)
  luaunit.assertEquals(loc.hour, original.hour)
  luaunit.assertEquals(loc.min, original.min)
  luaunit.assertEquals(loc.day, original.day)
end

function TestVeafTime:test_toLocal_adds_positive_offset()
  -- UTC 10:00 → local 14:00 at UTC+4
  local utc = { year = 2024, month = 6, day = 15, yday = 167, hour = 10, min = 0, sec = 0 }
  local loc = veafTime.toLocal(utc, 4)
  luaunit.assertEquals(loc.hour, 14)
  luaunit.assertEquals(loc.min, 0)
end

-- -----------------------------------------------------------------------
-- getTimezone (theatre-based, vec3 = nil)
-- -----------------------------------------------------------------------
function TestVeafTime:test_getTimezone_caucasus()
  env.mission.theatre = "Caucasus"
  luaunit.assertEquals(veafTime.getTimezone(nil), 4)
end

function TestVeafTime:test_getTimezone_nevada()
  env.mission.theatre = "Nevada"
  luaunit.assertEquals(veafTime.getTimezone(nil), -8)
end

function TestVeafTime:test_getTimezone_syria()
  env.mission.theatre = "Syria"
  luaunit.assertEquals(veafTime.getTimezone(nil), 3)
end

function TestVeafTime:test_getTimezone_mariana_islands()
  env.mission.theatre = "MarianaIslands"
  luaunit.assertEquals(veafTime.getTimezone(nil), 10)
end

function TestVeafTime:test_getTimezone_falklands()
  env.mission.theatre = "Falklands"
  luaunit.assertEquals(veafTime.getTimezone(nil), -3)
end

function TestVeafTime:test_getTimezone_normandy()
  env.mission.theatre = "Normandy"
  luaunit.assertEquals(veafTime.getTimezone(nil), 0)
end

function TestVeafTime:test_getTimezone_kola()
  env.mission.theatre = "Kola"
  luaunit.assertEquals(veafTime.getTimezone(nil), 3)
end

function TestVeafTime:test_getTimezone_sinai()
  env.mission.theatre = "SinaiMap"
  luaunit.assertEquals(veafTime.getTimezone(nil), 2)
end

-- -----------------------------------------------------------------------
-- absTimeToStringDate / absTimeToStringTime wrappers
-- -----------------------------------------------------------------------
function TestVeafTime:test_absTimeToStringDate()
  env.mission.date = { Day = 15, Month = 6, Year = 2024 }
  -- absTime = 0 means Mission Day 1
  luaunit.assertEquals(veafTime.absTimeToStringDate(0), "15/06/2024")
end

function TestVeafTime:test_absTimeToStringDate_after_rollover()
  env.mission.date = { Day = 31, Month = 1, Year = 2024 }
  -- 1 full day later → Feb 1 2024
  luaunit.assertEquals(veafTime.absTimeToStringDate(86400), "01/02/2024")
end

function TestVeafTime:test_absTimeToStringTime_with_seconds()
  env.mission.date = { Day = 1, Month = 1, Year = 2024 }
  -- 10:30:45 = 37845 s
  luaunit.assertEquals(veafTime.absTimeToStringTime(37845, true), "10:30:45")
end

function TestVeafTime:test_absTimeToStringTime_without_seconds()
  env.mission.date = { Day = 1, Month = 1, Year = 2024 }
  luaunit.assertEquals(veafTime.absTimeToStringTime(37845, false), "10:30")
end

-- ============================================================================
os.exit(luaunit.LuaUnit.run())
