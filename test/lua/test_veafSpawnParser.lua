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

os.exit(luaunit.LuaUnit.run())
