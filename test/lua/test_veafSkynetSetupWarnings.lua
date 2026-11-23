--- Tests for Skynet's set-up warnings and where they go (FIX-BFR-PORT-FINDINGS ticket 01, #1296).
---
--- Skynet's own logger starts with `debugOutput.warnings = true` and prints a warning with
--- `trigger.action.outText`, to every player: a red site's name reached the blue players' screens.
--- `veafSkynet.applySetupWarningsSettings` sets that flag from `SKYNET.setup_warnings_on_screen`
--- (off by default) and sends every warning to `dcs.log` whatever the key.
---
--- The logger is the vendored artefact's own, not a mock: the guarantee is about what that
--- artefact prints.
local _base = debug.getinfo(1, "S").source:match("^@(.+)[\\/]") or "."
luaunit = dofile(_base .. "/luaunit.lua")
dofile(_base .. "/dcs_mocks.lua")
local src = _base .. "/../../src/scripts/veaf"
dofile(src .. "/veaf.lua")
dofile(src .. "/veafScheduler.lua")
dofile(src .. "/veafMath.lua")
dofile(src .. "/veafGeo.lua")
dofile(src .. "/veafMissionDb.lua")
dofile(src .. "/veafDcsSpawner.lua")
dofile(src .. "/veafEventHandler.lua")
dofile(_base .. "/../../src/scripts/community/skynet-iads-compiled.lua")
dofile(src .. "/veafSkynetIadsHelper.lua")

TestVeafSkynetSetupWarnings = {}

function TestVeafSkynetSetupWarnings:setUp()
  dcs_mocks.reset()
  self.savedFlag = veafSkynet.SetupWarningsOnScreen
end

function TestVeafSkynetSetupWarnings:tearDown()
  veafSkynet.SetupWarningsOnScreen = self.savedFlag
end

--- An IADS stand-in carrying Skynet's real logger, the only part the settings touch.
local function iadsWithRealLogger()
  local iads = {}
  iads.logger = SkynetIADSLogger:create(iads)
  return iads
end

function TestVeafSkynetSetupWarnings:test_default_is_off()
  luaunit.assertFalse(veafSkynet.SetupWarningsOnScreen)
end

function TestVeafSkynetSetupWarnings:test_off_keeps_a_warning_off_the_screen_and_in_the_log()
  veafSkynet.SetupWarningsOnScreen = false
  local iads = iadsWithRealLogger()
  veafSkynet.applySetupWarningsSettings(iads)

  iads.logger:printOutput("group SAM-RED-07 does not exist", true)

  luaunit.assertEquals(#dcs_mocks.messagesContaining("SAM-RED-07"), 0)
  luaunit.assertTrue(#dcs_mocks.findLog("SAM%-RED%-07") > 0)
end

function TestVeafSkynetSetupWarnings:test_on_shows_a_warning_and_still_logs_it()
  veafSkynet.SetupWarningsOnScreen = true
  local iads = iadsWithRealLogger()
  veafSkynet.applySetupWarningsSettings(iads)

  iads.logger:printOutput("group SAM-RED-07 does not exist", true)

  luaunit.assertEquals(#dcs_mocks.messagesContaining("SAM-RED-07"), 1)
  luaunit.assertTrue(#dcs_mocks.findLog("SAM%-RED%-07") > 0)
end

function TestVeafSkynetSetupWarnings:test_a_status_output_is_left_alone()
  -- Not a warning: Skynet's debug outputs (IADSStatus, contacts…) keep their own switches.
  veafSkynet.SetupWarningsOnScreen = false
  local iads = iadsWithRealLogger()
  veafSkynet.applySetupWarningsSettings(iads)

  iads.logger:printOutput("IADS status line")

  luaunit.assertEquals(#dcs_mocks.messagesContaining("IADS status line"), 1)
end

function TestVeafSkynetSetupWarnings:test_an_iads_without_logger_is_tolerated()
  local ok = pcall(veafSkynet.applySetupWarningsSettings, {})
  luaunit.assertTrue(ok)
end

os.exit(luaunit.LuaUnit.run())
