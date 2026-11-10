--- An alias runs its command at the level the reached handler declares (FIX-ALIAS-SKIPS-HANDLER-LEVEL).
---
--- `VeafAlias:execute` calls each module's `executeCommand` directly, so the level `veafCommands` enforces
--- for `_move` and `_radio` (trusted member) was skipped: `-send` reached the whole server for any player.
--- The handlers here are the modules' own registrations, made by their `initialize()`, so the level under
--- test is the one the module declares, not a copy of it.
---
--- Run:  lua test/lua/test_veafShortcuts_handlerLevel.lua

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
dofile(src .. "/veafI18n.lua")
dofile(src .. "/veafSecurity.lua")
dofile(src .. "/veafEventHandler.lua")
dofile(src .. "/veafMarkers.lua")
dofile(src .. "/veafCommands.lua")
dofile(src .. "/veafSpawn.lua")
dofile(src .. "/veafRadio.lua")
dofile(src .. "/veafMove.lua")
dofile(src .. "/veafShortcuts.lua")

-- The rest of the alias chain, which these tests never reach.
local function answersNothing()
  return false
end
for _, name in ipairs({ "veafNamedPoints", "veafCasMission", "veafGroundAI" }) do
  _G[name] = _G[name] or {}
  _G[name].executeCommand = _G[name].executeCommand or answersNothing
end

local POSITION = { x = 0, y = 0, z = 0 }
local MARK_ID = 77
local AUTHOR = "Pilot 1"

-- The pilot levels, by name, as `veafRemote.getRemoteUser` would resolve them.
local UNKNOWN = nil
local KNOWN_PILOT = veafSecurity.LEVEL_KNOWN_PILOT
local SENIOR_PILOT = veafSecurity.LEVEL_SENIOR_PILOT

TestAliasHandlerLevel = {}

function TestAliasHandlerLevel:setUp()
  dcs_mocks.reset()
  self.saved = {
    getMarkPanels = world.getMarkPanels,
    veafRemote = veafRemote,
    securityDisabled = veaf.SecurityDisabled,
    moveExecute = veafMove.executeCommand,
    radioExecute = veafRadio.executeCommand,
    spawnExecute = veafSpawn.executeCommand,
    moveMenu = veafMove.buildRadioMenu,
    moveTankers = veafMove.Tankers,
    radioRefresh = veafRadio.refreshRadioMenu,
    handlers = veafCommands.commandHandlers,
  }
  veaf.SecurityDisabled = nil
  world.getMarkPanels = function()
    return { { idx = MARK_ID, author = AUTHOR } }
  end
  self.level = UNKNOWN
  veafRemote = {
    getRemoteUser = function(name)
      if name == AUTHOR and self.level then
        return { level = self.level }
      end
      return nil
    end,
  }

  -- The modules' own registrations, nothing else: the level under test is theirs.
  veafCommands.commandHandlers = {}
  veafMove.Tankers = { "a tanker" } -- skips the search for tankers in the mission
  veafMove.buildRadioMenu = function() end
  veafRadio.refreshRadioMenu = function() end
  veafMove.initialize()
  veafRadio.initialize(true, true)

  -- What reached each module.
  self.reached = {}
  veafMove.executeCommand = function(_, command)
    if command:lower():find(veafMove.Keyphrase, 1, true) then
      table.insert(self.reached, command)
      return true
    end
    return false
  end
  veafRadio.executeCommand = function(_, command)
    if command:lower():find(veafRadio.Keyphrase, 1, true) then
      table.insert(self.reached, command)
      return true
    end
    return false
  end
  veafSpawn.executeCommand = function(_, command)
    if command:lower():find(veafSpawn.SpawnKeyphrase, 1, true) then
      table.insert(self.reached, command)
      return true
    end
    return false
  end

  veafShortcuts.aliases = {}
  veafShortcuts.buildDefaultList()
end

function TestAliasHandlerLevel:tearDown()
  world.getMarkPanels = self.saved.getMarkPanels
  veafRemote = self.saved.veafRemote
  veaf.SecurityDisabled = self.saved.securityDisabled
  veafMove.executeCommand = self.saved.moveExecute
  veafRadio.executeCommand = self.saved.radioExecute
  veafSpawn.executeCommand = self.saved.spawnExecute
  veafMove.buildRadioMenu = self.saved.moveMenu
  veafMove.Tankers = self.saved.moveTankers
  veafRadio.refreshRadioMenu = self.saved.radioRefresh
  veafCommands.commandHandlers = self.saved.handlers
end

--- A marker dropped by the pilot, whose level is `level`.
function TestAliasHandlerLevel:marker(level, text)
  self.level = level
  self.reached = {}
  veafShortcuts.executeCommand(POSITION, text, coalition.side.RED, MARK_ID, false)
  return #self.reached
end

-- -----------------------------------------------------------------------
-- The mechanism: the reached handler's declared level (ticket 01, PRD Q1)
-- -----------------------------------------------------------------------

function TestAliasHandlerLevel:test_the_radio_handler_declares_trusted_member()
  -- The premise of every `-send` / `-play` test below: read from the registration, not assumed.
  luaunit.assertEquals(veafShortcuts.securityLevelFor(veafShortcuts.GetAlias("-send")), "SENIOR_PILOT")
end

function TestAliasHandlerLevel:test_send_is_refused_to_an_unknown_player()
  luaunit.assertEquals(self:marker(UNKNOWN, '-send "hello"'), 0)
end

function TestAliasHandlerLevel:test_send_is_refused_to_a_veaf_pilot()
  luaunit.assertEquals(self:marker(KNOWN_PILOT, '-send "hello"'), 0)
end

function TestAliasHandlerLevel:test_send_runs_for_a_trusted_member()
  luaunit.assertEquals(self:marker(SENIOR_PILOT, '-send "hello"'), 1)
end

function TestAliasHandlerLevel:test_play_is_refused_to_a_veaf_pilot_and_runs_for_a_trusted_member()
  luaunit.assertEquals(self:marker(KNOWN_PILOT, "-play sound.ogg"), 0)
  luaunit.assertEquals(self:marker(SENIOR_PILOT, "-play sound.ogg"), 1)
end

function TestAliasHandlerLevel:test_the_refusal_says_which_tier_is_missing()
  self:marker(KNOWN_PILOT, '-send "hello"')
  luaunit.assertTrue(#dcs_mocks.messagesContaining("L1") >= 1)
end

function TestAliasHandlerLevel:test_security_disabled_lets_everyone_through()
  veaf.SecurityDisabled = true
  luaunit.assertEquals(self:marker(UNKNOWN, '-send "hello"'), 1)
end

function TestAliasHandlerLevel:test_a_script_is_never_checked()
  -- bypassSecurity from veafCommands.execute: a mission maker's text, no player behind it.
  self.level = UNKNOWN
  veafShortcuts.executeCommand(POSITION, '-send "hello"', coalition.side.RED, nil, true)
  luaunit.assertEquals(#self.reached, 1)
end

function TestAliasHandlerLevel:test_a_bypassing_alias_still_runs_for_everyone()
  -- `-smoke` declares bypassSecurity: no handler level applies to it.
  luaunit.assertEquals(self:marker(UNKNOWN, "-smoke"), 1)
end

function TestAliasHandlerLevel:test_a_spawn_alias_is_not_checked_here()
  -- veafSpawn checks per command, itself; its registration is SECURITY_HANDLED, so nothing applies here.
  luaunit.assertNil(veafShortcuts.securityLevelFor(veafShortcuts.GetAlias("-sa2")))
  luaunit.assertEquals(self:marker(UNKNOWN, "-sa2"), 1)
end

function TestAliasHandlerLevel:test_the_player_text_cannot_choose_the_handler()
  -- The level comes from the alias's own command, which the mission maker wrote: a keyphrase
  -- typed after a spawn alias does not lend it another handler's level.
  luaunit.assertEquals(self:marker(UNKNOWN, "-sa2, _radio"), 1)
end

--- A marker with a delay (`!N`): the dispatcher removes the marker as soon as the alias is accepted, so
--- by the time the alias runs its author can no longer be read from the map. The level is checked when the
--- marker is dropped.
function TestAliasHandlerLevel:delayedMarker(level, text)
  self.level = level
  self.reached = {}
  veafShortcuts.executeCommand(POSITION, text, coalition.side.RED, MARK_ID, false)
  world.getMarkPanels = function()
    return {}
  end
  dcs_mocks.runScheduled(timer.getTime() + 3600)
  return #self.reached
end

function TestAliasHandlerLevel:test_a_delayed_alias_runs_for_the_level_it_needs()
  luaunit.assertEquals(self:delayedMarker(SENIOR_PILOT, '-send!30 "hello"'), 1)
end

function TestAliasHandlerLevel:test_a_delayed_alias_is_refused_below_its_level()
  luaunit.assertEquals(self:delayedMarker(KNOWN_PILOT, '-send!30 "hello"'), 0)
end

function TestAliasHandlerLevel:test_an_unknown_declared_level_is_refused()
  local alias = VeafAlias:new():setName("-broken"):setVeafCommand("_move tankermission"):setSecurityLevel("NOPE")
  veafShortcuts.AddAlias(alias)
  luaunit.assertEquals(self:marker(SENIOR_PILOT, "-broken"), 0)
end

-- -----------------------------------------------------------------------
-- The levels decided for the six aliases (ticket 02, PRD Q2 / Q3)
-- -----------------------------------------------------------------------

local TANKER_ALIASES = { "-tankerlow", "-tankerhigh", "-tankerhere", "-afachere" }

function TestAliasHandlerLevel:test_the_move_aliases_declare_veaf_pilot_themselves()
  for _, name in ipairs(TANKER_ALIASES) do
    luaunit.assertEquals(veafShortcuts.GetAlias(name).securityLevel, "KNOWN_PILOT", name)
  end
end

function TestAliasHandlerLevel:test_the_move_aliases_run_for_a_veaf_pilot()
  for _, name in ipairs(TANKER_ALIASES) do
    luaunit.assertEquals(self:marker(KNOWN_PILOT, name .. " Texaco"), 1, name)
  end
end

function TestAliasHandlerLevel:test_the_move_aliases_are_refused_to_an_unknown_player()
  for _, name in ipairs(TANKER_ALIASES) do
    luaunit.assertEquals(self:marker(UNKNOWN, name .. " Texaco"), 0, name)
  end
end

function TestAliasHandlerLevel:test_tanker_follows_tankerhere()
  -- `-tanker` is an alias of `-tankerhere`: the level is checked where the command is.
  luaunit.assertEquals(self:marker(UNKNOWN, "-tanker Texaco"), 0)
  luaunit.assertEquals(self:marker(KNOWN_PILOT, "-tanker Texaco"), 1)
end

function TestAliasHandlerLevel:test_raw_move_marker_stays_trusted_member()
  -- The decision is on the aliases only: `_move` typed by hand keeps the module's level.
  luaunit.assertEquals(veafShortcuts.securityLevelFor(VeafAlias:new():setVeafCommand("_move tankermission")), "SENIOR_PILOT")
end

os.exit(luaunit.LuaUnit.run())
