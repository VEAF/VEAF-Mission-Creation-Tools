--- Every vendored community script must survive being loaded — FIX-CTLD-RC9-LOAD-GATE.
--
-- Why this file exists. CTLD `2.0.0-rc8` shipped in VEAF Tools 6.22.0 and **did not load**: it
-- raised inside its own main chunk (issue #957). The mission booted, was playable, and had no F10
-- radio menu at all — not CTLD's, and not VEAF's either, because `_emit_trig_action_string` emits
-- the whole loading trigger as one concatenated Lua chunk with CTLD ahead of the VEAF framework, so
-- one raise takes everything after it down.
--
-- Nothing here could see that. `CHORE-VENDORED-DRIFT-618` verified the incoming rc8 with
-- `assert(loadfile(...))` — that **parses** a file, it does not run it, and the failure was in the
-- running. The Lua suite had no equivalent of `test_csar_init.lua` for CTLD, whose own header says
-- it best: every other suite loads VEAF first, which is why two CSAR defects "could not be seen
-- from the tests — one of them shipped and broke every mission until it was found in game".
--
-- So: load each vendored community script the way a mission does, with nothing but the DCS mocks,
-- and fail if the main chunk raises. Each script gets its own test rather than one loop, so a
-- failure names the culprit in the report instead of stopping the sweep at the first one.
local _base = debug.getinfo(1, "S").source:match("^@(.+)[\\/]") or "."
luaunit = dofile(_base .. "/luaunit.lua")
dofile(_base .. "/dcs_mocks.lua") -- sets the `dcs_mocks` global, like every other suite here

local _community = _base .. "/../../src/scripts/community/"

--- Load one community script and return (ok, error-with-traceback).
-- `xpcall` rather than `pcall`: without the traceback a failure reads as one line naming a file of
-- twenty thousand, which is precisely the report we got from the field and had to reproduce by hand.
local function loadScript(name)
  return xpcall(function()
    return dofile(_community .. name)
  end, function(e)
    return tostring(e) .. "\n" .. debug.traceback("", 2)
  end)
end

TestCommunityScriptsLoad = {}

-- ---------------------------------------------------------------------------
-- The opt-out scripts: on unless a mission says otherwise, so every one of these
-- is loaded by a default build and every one of them can break a mission.
-- ---------------------------------------------------------------------------

function TestCommunityScriptsLoad:test_ctld_loads()
  -- The regression that motivated this file. rc8 raises here with
  -- "CTLD configuration is not loaded" from its own scene self-registration.
  local ok, err = loadScript("CTLD.lua")
  luaunit.assertTrue(ok, "CTLD.lua must load without raising:\n" .. tostring(err))
end

function TestCommunityScriptsLoad:test_csar_loads()
  local ok, err = loadScript("CSAR.lua")
  luaunit.assertTrue(ok, "CSAR.lua must load without raising:\n" .. tostring(err))
end

function TestCommunityScriptsLoad:test_aien_loads()
  local ok, err = loadScript("AIEN.lua")
  luaunit.assertTrue(ok, "AIEN.lua must load without raising:\n" .. tostring(err))
end

function TestCommunityScriptsLoad:test_skynet_loads()
  local ok, err = loadScript("skynet-iads-compiled.lua")
  luaunit.assertTrue(ok, "skynet-iads-compiled.lua must load without raising:\n" .. tostring(err))
end

function TestCommunityScriptsLoad:test_stts_loads()
  local ok, err = loadScript("DCS-SimpleTextToSpeech.lua")
  luaunit.assertTrue(ok, "DCS-SimpleTextToSpeech.lua must load without raising:\n" .. tostring(err))
end

-- ---------------------------------------------------------------------------
-- The opt-in scripts.
-- ---------------------------------------------------------------------------

function TestCommunityScriptsLoad:test_mist_loads()
  -- Opt-in since DROP-MIST, but the builder turns it back on by itself when a mission script
  -- mentions `mist.`, so it still reaches real missions.
  local ok, err = loadScript("mist.lua")
  luaunit.assertTrue(ok, "mist.lua must load without raising:\n" .. tostring(err))
end

-- TheUniversalMission.lua is deliberately **not** covered, and that is a reasoned exclusion rather
-- than an oversight — a reader has to be able to tell "not covered" from "covered and green".
--
-- Measured, not assumed: loading it against the mocks alone raises at
--   TheUniversalMission.lua:29967 'getTerritoryCenter' <- 29777 'create' <- 31486 <- main chunk
-- because TUM auto-initializes on load and `initialize()` requires BLUFOR/REDFOR territory zones
-- each owning an airbase. That contract is exactly why TUM is opt-in here (see
-- `get_optin_community_script_ids`) and `TUM: false` in the shipped mission.yaml — no mission runs
-- it without having declared those zones.
--
-- Covering it means building a territory-zone fixture (zones + airbases + a player faction), which
-- is real work and its own lot. Until then TUM is guarded only by the pin test and the drift watch.

-- ---------------------------------------------------------------------------
-- A test that cannot fail proves nothing: check the mocks are actually in place, so that a future
-- `dcs_mocks.lua` returning early could not turn this whole file green by loading nothing.
-- ---------------------------------------------------------------------------

function TestCommunityScriptsLoad:test_the_dcs_mocks_are_present()
  luaunit.assertNotNil(dcs_mocks, "dcs_mocks.lua must have defined its global")
  luaunit.assertNotNil(env, "the DCS `env` global must exist before any script loads")
  luaunit.assertNotNil(timer, "the DCS `timer` global must exist before any script loads")
  luaunit.assertNotNil(coalition, "the DCS `coalition` global must exist before any script loads")
end

-- ---------------------------------------------------------------------------
-- Run
-- ---------------------------------------------------------------------------
local runner = luaunit.LuaUnit.new()
runner:setOutputType("text")
os.exit(runner:runSuite())
