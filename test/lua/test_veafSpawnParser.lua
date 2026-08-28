--- Characterization tests for veafSpawn.markTextAnalysis (veafSpawnParser.lua).
---
--- These lock the CURRENT behaviour of the spawn-command text parser before any
--- de-duplication refactor (SPAWN-REFACTOR-001). They assert only DETERMINISTIC
--- fields — several group/convoy defaults use math.random and are intentionally
--- left unasserted (a per-keyword `size N` makes size deterministic, so those are
--- checked). Captured against the live parser, not hand-guessed.
local _base = debug.getinfo(1, "S").source:match("^@(.+)[\\/]") or "."
luaunit = dofile(_base .. "/luaunit.lua")
dofile(_base .. "/dcs_mocks.lua")
local src = _base .. "/../../src/scripts/veaf"
dofile(src .. "/veaf.lua")
dofile(src .. "/veafScheduler.lua")
dofile(src .. "/veafSpawn.lua")

local function analyse(text)
  return veafSpawn.markTextAnalysis(text)
end

-- ---------------------------------------------------------------------------
-- Rejected inputs (return nil)
-- ---------------------------------------------------------------------------
TestParserRejects = {}

function TestParserRejects:test_keyphrase_alone()
  luaunit.assertNil(analyse("_spawn"))
end

function TestParserRejects:test_unknown_subcommand()
  luaunit.assertNil(analyse("_spawn wibble"))
end

function TestParserRejects:test_typo_subcommand()
  -- "unti" is not "unit"; nothing else matches -> nil
  luaunit.assertNil(analyse("_spawn unti, name X"))
end

function TestParserRejects:test_unit_without_name()
  luaunit.assertNil(analyse("_spawn unit"))
end

function TestParserRejects:test_group_without_name()
  luaunit.assertNil(analyse("_spawn group"))
end

function TestParserRejects:test_name_keyword_with_empty_value()
  -- "name" with no value leaves name="" -> group still rejected
  luaunit.assertNil(analyse("_spawn group, name"))
end

function TestParserRejects:test_mm_flagon_without_name()
  luaunit.assertNil(analyse("_mm flagon"))
end

function TestParserRejects:test_mm_run_without_name()
  luaunit.assertNil(analyse("_mm run"))
end

function TestParserRejects:test_empty_string()
  luaunit.assertNil(analyse(""))
end

-- ---------------------------------------------------------------------------
-- Command flags + defaults
-- ---------------------------------------------------------------------------
TestParserCommands = {}

function TestParserCommands:test_unit()
  local r = analyse("_spawn unit, name F-16C")
  luaunit.assertTrue(r.unit)
  luaunit.assertEquals(r.name, "F-16C")
  luaunit.assertEquals(r.spacing, 5)
  luaunit.assertFalse(r.forceStatic)
  luaunit.assertFalse(r.immortal)
end

function TestParserCommands:test_group()
  local r = analyse("_spawn group, name MyGroup")
  luaunit.assertTrue(r.group)
  luaunit.assertEquals(r.name, "MyGroup")
end

function TestParserCommands:test_smoke_default_color_red()
  local r = analyse("_spawn smoke")
  luaunit.assertTrue(r.smoke)
  luaunit.assertEquals(r.smokeColor, trigger.smokeColor.RED)
end

function TestParserCommands:test_flare()
  luaunit.assertTrue(analyse("_spawn flare").flare)
end

function TestParserCommands:test_signal()
  luaunit.assertTrue(analyse("_spawn signal").signal)
end

function TestParserCommands:test_cargo_defaults()
  local r = analyse("_spawn cargo")
  luaunit.assertTrue(r.cargo)
  luaunit.assertEquals(r.cargoType, "container_cargo")
  luaunit.assertEquals(r.cargoWeightBias, 2)
  luaunit.assertFalse(r.cargoSmoke)
end

function TestParserCommands:test_logistic()
  luaunit.assertTrue(analyse("_spawn logistic").logistic)
end

function TestParserCommands:test_bomb_defaults()
  local r = analyse("_spawn bomb")
  luaunit.assertTrue(r.bomb)
  luaunit.assertEquals(r.power, 100)
  luaunit.assertEquals(r.shells, 1)
end

function TestParserCommands:test_cap()
  local r = analyse("_spawn cap")
  luaunit.assertTrue(r.cap)
  luaunit.assertNil(r.speed)
  luaunit.assertNil(r.capradius)
end

function TestParserCommands:test_farp()
  local r = analyse("_spawn farp")
  luaunit.assertTrue(r.farp)
  luaunit.assertFalse(r.noFarpMarkers)
end

function TestParserCommands:test_fob()
  luaunit.assertTrue(analyse("_spawn fob").fob)
end

function TestParserCommands:test_convoy_default_size_is_ten()
  local r = analyse("_spawn convoy")
  luaunit.assertTrue(r.convoy)
  luaunit.assertEquals(r.size, 10)
end

function TestParserCommands:test_destroy()
  luaunit.assertTrue(analyse("_destroy").destroy)
end

function TestParserCommands:test_teleport()
  luaunit.assertTrue(analyse("_teleport").teleport)
end

function TestParserCommands:test_drawing_add()
  luaunit.assertTrue(analyse("_drawing add").addDrawing)
end

function TestParserCommands:test_drawing_erase()
  luaunit.assertTrue(analyse("_drawing erase").eraseDrawing)
end

function TestParserCommands:test_drawing_square()
  luaunit.assertTrue(analyse("_drawing square").drawSquare)
end

function TestParserCommands:test_drawing_circle()
  luaunit.assertTrue(analyse("_drawing circle").drawCircle)
end

function TestParserCommands:test_mm_getflag_no_name_required()
  -- getflag (unlike flagon/flagoff/run) does NOT require a name
  local r = analyse("_mm getflag, name f1")
  luaunit.assertTrue(r.mmGetFlag)
  luaunit.assertEquals(r.name, "f1")
end

-- ---------------------------------------------------------------------------
-- Air-role defaults (afac / jtac / tacan)
-- ---------------------------------------------------------------------------
TestParserAirRoles = {}

function TestParserAirRoles:test_afac_defaults()
  local r = analyse("_spawn afac")
  luaunit.assertTrue(r.afac)
  luaunit.assertEquals(r.name, "mq-9")
  luaunit.assertEquals(r.country, "USA")
  luaunit.assertEquals(r.laserCode, 1688)
  luaunit.assertEquals(r.mod, "fm")
  luaunit.assertEquals(r.freq, veafSpawn.convertLaserToFreq(1688))
end

function TestParserAirRoles:test_jtac_defaults()
  local r = analyse("_spawn jtac")
  luaunit.assertEquals(r.role, "jtac")
  luaunit.assertTrue(r.unit)
  luaunit.assertEquals(r.name, "LUV HMMWV Jeep")
  luaunit.assertEquals(r.unitName, "JTAC1")
  luaunit.assertEquals(r.country, "USA")
  luaunit.assertEquals(r.laserCode, 1688)
end

function TestParserAirRoles:test_tacan_defaults()
  local r = analyse("_spawn tacan")
  luaunit.assertEquals(r.role, "tacan")
  luaunit.assertTrue(r.unit)
  luaunit.assertEquals(r.name, "TACAN_beacon")
  luaunit.assertEquals(r.unitName, "TACAN TCN")
end

-- ---------------------------------------------------------------------------
-- Parameter parsing
-- ---------------------------------------------------------------------------
TestParserParams = {}

function TestParserParams:test_side_blue_is_two()
  luaunit.assertEquals(analyse("_spawn unit, name F-16C, side blue").side, 2)
end

function TestParserParams:test_country_and_heading_and_alt()
  local r = analyse("_spawn unit, name F-16C, country USA, heading 270, alt 5000")
  luaunit.assertEquals(r.country, "USA")
  luaunit.assertEquals(r.heading, 270)
  luaunit.assertEquals(r.altitude, 5000)
end

function TestParserParams:test_laser_sets_code_and_freq()
  local r = analyse("_spawn unit, name F-16C, laser 1688")
  luaunit.assertEquals(r.laserCode, 1688)
  luaunit.assertEquals(r.freq, veafSpawn.convertLaserToFreq(1688))
end

function TestParserParams:test_explicit_size_and_spacing()
  local r = analyse("_spawn group, name g, size 5, spacing 10")
  luaunit.assertEquals(r.size, 5)
  luaunit.assertEquals(r.spacing, 10)
end

function TestParserParams:test_bomb_power_and_shells()
  local r = analyse("_spawn bomb, power 50, shells 3")
  luaunit.assertEquals(r.power, 50)
  luaunit.assertEquals(r.shells, 3)
end

function TestParserParams:test_cargo_name_sets_cargo_type()
  luaunit.assertEquals(analyse("_spawn cargo, name ammo_cargo").cargoType, "ammo_cargo")
end

function TestParserParams:test_cargo_smoke_flag()
  luaunit.assertTrue(analyse("_spawn cargo, smoke").cargoSmoke)
end

function TestParserParams:test_farp_nofarpmarkers_flag()
  luaunit.assertTrue(analyse("_spawn farp, nofarpmarkers").noFarpMarkers)
end

function TestParserParams:test_color_green_sets_smoke_color()
  local r = analyse("_spawn smoke, color green")
  luaunit.assertEquals(r.smokeColor, trigger.smokeColor.GREEN)
  luaunit.assertEquals(r.drawColor, "green")
end

function TestParserParams:test_static_and_immortal_flags()
  local r = analyse("_spawn unit, name X, static, immortal")
  luaunit.assertTrue(r.forceStatic)
  luaunit.assertTrue(r.immortal)
end

-- ---------------------------------------------------------------------------
-- Unknown-parameter detection (UXPILOT-003)
-- ---------------------------------------------------------------------------
TestParserUnknownParams = {}

function TestParserUnknownParams:test_valid_input_has_no_unknown()
  luaunit.assertNil(analyse("_spawn unit, name F-16C, side blue").unknownParameters)
end

function TestParserUnknownParams:test_unknown_key_is_collected()
  local r = analyse("_spawn unit, name F-16C, wibble 3")
  luaunit.assertIsTable(r.unknownParameters)
  luaunit.assertEquals(#r.unknownParameters, 1)
  luaunit.assertEquals(r.unknownParameters[1].key, "wibble")
end

function TestParserUnknownParams:test_typo_suggests_nearest_key()
  -- "headng" is one edit from "heading"
  local r = analyse("_spawn unit, name F-16C, headng 270")
  luaunit.assertEquals(r.unknownParameters[1].suggestion, "heading")
end

function TestParserUnknownParams:test_command_keyphrase_not_flagged()
  -- the "_spawn" / subtype token must never be reported as an unknown parameter
  local r = analyse("_spawn group, name g")
  luaunit.assertNil(r.unknownParameters)
end

-------------------------------------------------------------------------------------------------
-- SECREV-2 / VMR-025 — a non-numeric numeric parameter must not abort the spawn
--
-- `multiplier` goes through `_num`, which calls `veaf.getRandomizableNumeric`. That returns nil
-- for unusable input, so `options.multiplier` became nil and `for i = 1, options.multiplier do`
-- in veafSpawnCore raised. Worse, a *valueless* keyword reached `string.find(nil, "%-")` inside
-- the conversion and raised there instead.
--
-- Fixed in `_num` rather than on `multiplier`, because every numeric spawn keyword shares it.
-------------------------------------------------------------------------------------------------

TestSpawnParserNumericRobustness = {}

function TestSpawnParserNumericRobustness:test_garbage_multiplier_does_not_crash()
  local ok = pcall(function()
    return veafSpawn.markTextAnalysis("_spawn group, name test, multiplier banana")
  end)
  luaunit.assertTrue(ok, "a non-numeric multiplier must not raise")
end

function TestSpawnParserNumericRobustness:test_garbage_multiplier_keeps_the_default()
  local options = veafSpawn.markTextAnalysis("_spawn group, name test, multiplier banana")
  luaunit.assertNotNil(options)
  luaunit.assertEquals(options.multiplier, 1)
end

function TestSpawnParserNumericRobustness:test_valueless_multiplier_does_not_crash()
  local ok = pcall(function()
    return veafSpawn.markTextAnalysis("_spawn group, name test, multiplier")
  end)
  luaunit.assertTrue(ok, "a valueless multiplier must not raise")
end

function TestSpawnParserNumericRobustness:test_multiplier_is_never_nil()
  -- The crash was downstream: `for i = 1, options.multiplier do` in veafSpawnCore.
  local options = veafSpawn.markTextAnalysis("_spawn group, name test, multiplier banana")
  luaunit.assertNotNil(options.multiplier)
end

function TestSpawnParserNumericRobustness:test_a_valid_multiplier_still_applies()
  local options = veafSpawn.markTextAnalysis("_spawn group, name test, multiplier 3")
  luaunit.assertEquals(options.multiplier, 3)
end

-------------------------------------------------------------------------------------------------
-- SECREV-2 / VMR-102 — a laser code no aircraft can dial must be refused
--
-- DCS laser codes are octal-like: the three digits after the leading 1 are each 1..8. The
-- range check (1111..1688) let 1109, 1119, 1190 and friends through, and they came out as a
-- plausible-looking frequency — so the JTAC lased on a code nobody could enter, and the pilot
-- had no way to tell that from a JTAC that was simply not lasing.
--
-- Handled like every other unusable marker value (VMR-025): keep the default, do not abort.
-------------------------------------------------------------------------------------------------

TestSpawnParserLaserCodes = {}

function TestSpawnParserLaserCodes:test_valid_code_converts()
  luaunit.assertEquals(veafSpawn.convertLaserToFreq(1688), "40.4")
  luaunit.assertEquals(veafSpawn.convertLaserToFreq(1111), "31.55")
end

function TestSpawnParserLaserCodes:test_units_digit_nine_is_refused()
  luaunit.assertNil(veafSpawn.convertLaserToFreq(1119))
end

function TestSpawnParserLaserCodes:test_units_digit_zero_is_refused()
  -- 1210, not 1110: the latter is already below the 1111 floor, so it would pass without
  -- the digit rule and prove nothing.
  luaunit.assertNil(veafSpawn.convertLaserToFreq(1210))
end

function TestSpawnParserLaserCodes:test_tens_digit_zero_is_refused()
  luaunit.assertNil(veafSpawn.convertLaserToFreq(1201))
end

function TestSpawnParserLaserCodes:test_tens_digit_nine_is_refused()
  luaunit.assertNil(veafSpawn.convertLaserToFreq(1191))
end

function TestSpawnParserLaserCodes:test_a_non_integer_code_is_refused()
  luaunit.assertNil(veafSpawn.convertLaserToFreq(1111.5))
end

function TestSpawnParserLaserCodes:test_out_of_range_is_still_refused()
  luaunit.assertNil(veafSpawn.convertLaserToFreq(1110 - 1000))
  luaunit.assertNil(veafSpawn.convertLaserToFreq(1788))
  luaunit.assertNil(veafSpawn.convertLaserToFreq("banana"))
end

function TestSpawnParserLaserCodes:test_every_valid_code_in_range_converts()
  -- The control: the digit rule must not reject codes that are genuinely dialable.
  local rejected = {}
  for b = 1, 6 do
    for c = 1, 8 do
      for d = 1, 8 do
        local code = 1000 + b * 100 + c * 10 + d
        if code <= 1688 and veafSpawn.convertLaserToFreq(code) == nil then
          table.insert(rejected, code)
        end
      end
    end
  end
  luaunit.assertEquals(#rejected, 0, "refused dialable codes: " .. table.concat(rejected, ", "))
end

function TestSpawnParserLaserCodes:test_marker_keeps_the_default_code_when_the_value_is_invalid()
  -- `_spawn afac` defaults to 1688; asking for an impossible code must not install it.
  local r = analyse("_spawn afac, laser 1119")
  luaunit.assertEquals(r.laserCode, 1688)
  luaunit.assertEquals(r.freq, veafSpawn.convertLaserToFreq(1688))
end

function TestSpawnParserLaserCodes:test_marker_still_accepts_a_valid_code()
  local r = analyse("_spawn afac, laser 1311")
  luaunit.assertEquals(r.laserCode, 1311)
  luaunit.assertEquals(r.freq, veafSpawn.convertLaserToFreq(1311))
end

-- ---------------------------------------------------------------------------
-- TestSpawnParserEveryKeywordSurvivesBadInput
--
-- FIX-MARKER-PARAM-CRASHES-2. The previous lot closed six crashes and declared the family
-- closed on the strength of thirteen hand-picked cases. Four more were living here, in the
-- module the refactor plan calls the healthy one: `_numNonNegative` and the inline `delayed`
-- carry the very nil-comparison VMR-025 fixed in `_num`, one function above them.
--
-- So this suite does not list keywords. It reads them from `veafSpawn.ParameterRules`, which
-- means a parameter added tomorrow with an unguarded conversion fails here rather than in a
-- pilot's mission. That is the point: coverage that is enumerated, not asserted.
-- ---------------------------------------------------------------------------
TestSpawnParserEveryKeywordSurvivesBadInput = {}

local function everyDeclaredKey()
  local keys, seen = {}, {}
  for _, rule in ipairs(veafSpawn.ParameterRules) do
    for _, k in ipairs(rule.keys) do
      if not seen[k] then
        seen[k] = true
        table.insert(keys, k)
      end
    end
  end
  return keys
end

-- Runs one marker-text shape over every declared keyword and reports all the failures at once,
-- named, rather than stopping at the first. Adding a new hostile shape is one call.
local function assertNoDeclaredKeywordRaises(shape, description)
  local raised = {}
  for _, key in ipairs(everyDeclaredKey()) do
    local ok, err = pcall(analyse, "_spawn group, name A, " .. shape(key))
    if not ok then
      table.insert(raised, key .. " (" .. tostring(err) .. ")")
    end
  end
  luaunit.assertEquals(#raised, 0, "keywords raising " .. description .. ": " .. table.concat(raised, " | "))
end

-- Guards against the enumeration degenerating, which would make every test below pass while
-- checking nothing. Asserted as the invariant rather than as a magic count: **every declared
-- rule must contribute at least one key**. That cannot go stale when parameters are added or
-- removed, where a hardcoded threshold would.
function TestSpawnParserEveryKeywordSurvivesBadInput:test_the_enumeration_covers_every_declared_rule()
  luaunit.assertTrue(#veafSpawn.ParameterRules > 0, "veafSpawn.ParameterRules is empty")

  local enumerated = {}
  for _, key in ipairs(everyDeclaredKey()) do
    enumerated[key] = true
  end

  local uncovered = {}
  for index, rule in ipairs(veafSpawn.ParameterRules) do
    local covered = false
    for _, key in ipairs(rule.keys) do
      if enumerated[key] then
        covered = true
      end
    end
    if not covered then
      table.insert(uncovered, "rule #" .. index)
    end
  end
  luaunit.assertEquals(#uncovered, 0, "rules the sweep would skip: " .. table.concat(uncovered, ", "))
end

function TestSpawnParserEveryKeywordSurvivesBadInput:test_no_declared_keyword_raises_when_bare()
  assertNoDeclaredKeywordRaises(function(key)
    return key
  end, "with no value")
end

function TestSpawnParserEveryKeywordSurvivesBadInput:test_no_declared_keyword_raises_on_a_non_numeric_value()
  assertNoDeclaredKeywordRaises(function(key)
    return key .. " banana"
  end, "on a non-numeric value")
end

function TestSpawnParserEveryKeywordSurvivesBadInput:test_no_declared_keyword_raises_on_a_negative_value()
  assertNoDeclaredKeywordRaises(function(key)
    return key .. " -1"
  end, "on a negative value")
end

function TestSpawnParserEveryKeywordSurvivesBadInput:test_no_declared_keyword_raises_on_a_huge_value()
  assertNoDeclaredKeywordRaises(function(key)
    return key .. " 999999"
  end, "on an out-of-range value")
end

-- The four that were actually broken, named so a regression reads as itself rather than as a
-- line in the sweep's failure list.
TestSpawnParserNonNegativeKeywords = {}

function TestSpawnParserNonNegativeKeywords:test_bare_defense_keeps_the_default()
  local r = analyse("_spawn group, name A, defense")
  luaunit.assertNotNil(r)
end

function TestSpawnParserNonNegativeKeywords:test_non_numeric_armor_keeps_the_default()
  local r = analyse("_spawn group, name A, armor banana")
  luaunit.assertNotNil(r)
end

function TestSpawnParserNonNegativeKeywords:test_bare_disperse_keeps_the_default()
  local r = analyse("_spawn group, name A, disperse")
  luaunit.assertNotNil(r)
  luaunit.assertEquals(r.disperse, 15)
end

-- An unreadable `delayed` falls into the branch that already handles a negative value, so it
-- means "the minimum" rather than "no delay" — which is what a bare `delayed` asks for.
function TestSpawnParserNonNegativeKeywords:test_bare_delayed_means_the_minimum_delay()
  local r = analyse("_spawn group, name A, delayed")
  luaunit.assertNotNil(r)
  luaunit.assertEquals(r.delayedStart, veafSpawn.MIN_REPEAT_DELAY)
end

function TestSpawnParserNonNegativeKeywords:test_a_readable_delayed_is_honoured()
  local r = analyse("_spawn group, name A, delayed 30")
  luaunit.assertEquals(r.delayedStart, 30)
end

-- ---------------------------------------------------------------------------
-- FEAT-CONVOY-WAYPOINTS ticket 01 — `dest` repeated builds an itinerary
--
-- `veaf.parseMarkerText` walks keyphrases with `ipairs` precisely so that a repeated keyword is
-- ordered rather than arbitrary, so accumulating is enough. `destination` keeps holding the FIRST
-- point: every caller of `spawnConvoy` reads it, and a one-point itinerary must stay byte-identical
-- to what a single `dest` produced before this lot.
-- ---------------------------------------------------------------------------
TestSpawnParserItinerary = {}

function TestSpawnParserItinerary:test_one_dest_still_sets_destination()
  local r = analyse("_spawn convoy, dest KOBULETI")
  luaunit.assertEquals(r.destination, "KOBULETI")
end

function TestSpawnParserItinerary:test_one_dest_is_a_one_point_itinerary()
  local r = analyse("_spawn convoy, dest KOBULETI")
  luaunit.assertEquals(r.itinerary, { "KOBULETI" })
end

function TestSpawnParserItinerary:test_several_dest_accumulate_in_the_order_written()
  local r = analyse("_spawn convoy, dest KOBULETI, dest BATUMI, dest POTI")
  luaunit.assertEquals(r.itinerary, { "KOBULETI", "BATUMI", "POTI" })
end

-- The compatibility promise: whatever the itinerary, `destination` is its first point, because that
-- is the leg the convoy leaves on and what every existing caller passes to spawnConvoy.
function TestSpawnParserItinerary:test_destination_is_the_first_point_not_the_last()
  local r = analyse("_spawn convoy, dest KOBULETI, dest BATUMI")
  luaunit.assertEquals(r.destination, "KOBULETI")
end

-- The side effects `dest` carries (auto alarm state, tight spacing, no dispersion) are what make a
-- convoy leave at all; they must be applied once and not depend on how many points were written.
function TestSpawnParserItinerary:test_the_convoy_side_effects_survive_several_points()
  local r = analyse("_spawn convoy, dest KOBULETI, dest BATUMI")
  luaunit.assertEquals(r.AlarmState, 0)
  luaunit.assertEquals(r.spacing, 1)
  luaunit.assertEquals(r.radius, 1)
end

-- `dest` and its alias `destination` are the same keyword, so mixing them still builds one itinerary.
function TestSpawnParserItinerary:test_the_alias_and_the_full_keyword_accumulate_together()
  local r = analyse("_spawn convoy, destination KOBULETI, dest BATUMI")
  luaunit.assertEquals(r.itinerary, { "KOBULETI", "BATUMI" })
end

-- A convoy with no `dest` has no itinerary rather than an empty one: spawnConvoy already refuses a
-- missing destination, and an empty list would read as "an itinerary that finished".
function TestSpawnParserItinerary:test_no_dest_leaves_no_itinerary()
  local r = analyse("_spawn convoy")
  luaunit.assertNil(r.itinerary)
end

-- ---------------------------------------------------------------------------
-- FEAT-INTERPRETER-PARITY ticket 01 — the randomisable numerics #25 asked for
--
-- #25 asked that `veaf.getRandomizableNumeric` reach interpreter elements. It already does, and this
-- records *why*: an interpreter command is a marker command, `veaf.markerRules.number` converts through
-- that very function, and the spawn parser's numeric keywords all use it. So the feature was delivered
-- by REFACTOR-MARKER-PARSER without the issue being closed.
--
-- Kept as a test rather than a note, because it is the kind of thing a later refactor can quietly
-- remove: swap `_num` for `safeNumber` anywhere here and these fail.
-- ---------------------------------------------------------------------------
TestSpawnParserRandomisableNumerics = {}

function TestSpawnParserRandomisableNumerics:test_a_range_draws_inside_its_bounds()
  for _ = 1, 20 do
    local r = analyse("_spawn group, name x, size 3-8")
    luaunit.assertTrue(r.size >= 3 and r.size <= 8, "size " .. tostring(r.size) .. " out of [3,8]")
  end
end

function TestSpawnParserRandomisableNumerics:test_a_plain_value_is_untouched()
  luaunit.assertEquals(analyse("_spawn group, name x, size 5").size, 5)
end

-- The open-ended form that used to raise inside the converter, reachable from here.
function TestSpawnParserRandomisableNumerics:test_an_open_range_does_not_raise()
  local ok, r = pcall(analyse, "_spawn group, name x, size 100-")
  luaunit.assertTrue(ok, "an open range must not raise out of the parser")
  luaunit.assertEquals(r.size, 100)
end

-- ── FEAT-RADIO-BEACONS — the `_spawn beacon` descriptor ─────────────────────

TestVeafSpawnBeaconCommand = {}

function TestVeafSpawnBeaconCommand:test_the_marker_command_is_recognised()
  local options = analyse("_spawn beacon")
  luaunit.assertNotNil(options)
  luaunit.assertTrue(options.beacon)
end

function TestVeafSpawnBeaconCommand:test_it_defaults_to_the_exact_spot()
  -- A beacon is placed where the marker is, not scattered: its position is the whole point of dropping
  -- it there. Every group-spawning command defaults to a scatter radius; this one must not.
  local options = analyse("_spawn beacon")
  luaunit.assertEquals(options.radius, 0)
end

function TestVeafSpawnBeaconCommand:test_a_name_can_be_given()
  local options = analyse("_spawn beacon, name Alpha")
  luaunit.assertEquals(options.name, "Alpha")
end

function TestVeafSpawnBeaconCommand:test_a_side_can_be_given()
  local options = analyse("_spawn beacon, side red")
  luaunit.assertNotNil(options.side)
end

function TestVeafSpawnBeaconCommand:test_a_handler_is_registered_for_it()
  -- Without this the options parse, the marker is accepted, and nothing happens.
  local found = false
  for _, entry in ipairs(veafSpawn.commandHandlers) do
    if entry.key == "beacon" then
      found = true
    end
  end
  luaunit.assertTrue(found)
end

function TestVeafSpawnBeaconCommand:test_it_does_not_swallow_another_command()
  -- `match` is a lower-cased substring and the first match wins, so a new descriptor can quietly
  -- capture an existing command. Checked rather than assumed.
  luaunit.assertTrue(analyse("_spawn unit, name shilka").unit)
  luaunit.assertTrue(analyse("_spawn fob").fob)
  luaunit.assertNil(analyse("_spawn fob").beacon)
end

os.exit(luaunit.LuaUnit.run())
