--- FEAT-RADIO-MENU-ORDER ticket 02 — the CAS menu stays, its entries stay.
---
--- The CAS mission used to add its entries when a mission started, delete them when it ended, and
--- swap the smoke and flare labels after each request. Every removal frees a DCS menu id that has to
--- be parked (FIX-RADIO-MENU-ID-RECYCLING), and the removals named their entries by English titles, so
--- in a French mission none of them happened (measured 2026-11-10: the entries piled up). The menu is
--- now built once, and each entry answers when it cannot act.
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
dofile(src .. "/veafSecurity.lua")
dofile(src .. "/veafRadio.lua")
dofile(src .. "/veafI18n.lua")
dofile(src .. "/dcsUnits.lua")
dofile(src .. "/veafUnits.lua")
dofile(src .. "/veafCasMission.lua")

TestVeafCasMissionMenu = {}

local MENU_API = {
  "addSubMenu",
  "addSubMenuForCoalition",
  "addCommand",
  "addCommandForCoalition",
  "addCommandForGroup",
  "removeItem",
  "removeItemForCoalition",
  "removeItemForGroup",
}

function TestVeafCasMissionMenu:setUp()
  self._origMissionCommands = {}
  self.calls = {}
  local this = self
  for _, name in ipairs(MENU_API) do
    self._origMissionCommands[name] = missionCommands[name]
    missionCommands[name] = function(...)
      local args = { ... }
      table.insert(this.calls, { kind = name, args = args })
      return { kind = name, title = name:find("For") and args[2] or args[1] }
    end
  end
  self._orig = {
    language = veaf.config.language,
    outText = trigger.action.outText,
    outTextForGroup = veaf.outTextForGroup,
    spawnSmoke = veafSpawn and veafSpawn.spawnSmoke,
    spawnIlluminationFlare = veafSpawn and veafSpawn.spawnIlluminationFlare,
    getAveragePosition = veaf.getAveragePosition,
    scheduleFunction = veaf.scheduleFunction,
    skipHelpMenus = veafRadio.skipHelpMenus,
  }
  veaf.config.language = "fr"
  self.messages = {}
  trigger.action.outText = function(text)
    table.insert(this.messages, text)
  end
  veaf.outTextForGroup = function(_, text)
    table.insert(this.messages, text)
  end
  veafSpawn = veafSpawn or {}
  self.smokes, self.flares = 0, 0
  veafSpawn.spawnSmoke = function()
    this.smokes = this.smokes + 1
  end
  veafSpawn.spawnIlluminationFlare = function()
    this.flares = this.flares + 1
  end
  veaf.getAveragePosition = function()
    return { x = 0, y = 0, z = 0 }
  end
  self.scheduled = {}
  veaf.scheduleFunction = function(f)
    table.insert(this.scheduled, f)
    return #this.scheduled
  end
  veafRadio.skipHelpMenus = false
  veafRadio.humanGroups = {}
  veafRadio.humanUnits = {}
  veafRadio.radioMenu.subMenus = {}
  veafRadio.radioMenu.commands = {}
  veafRadio._builder = veafRadio.RadioMenuBuilder:new(veafRadio.radioMenu)
  veafCasMission.groupAliveCheckTaskID = "none"
  veafCasMission.buildRadioMenu()
  veafRadio._builder:rebuild()
  self.calls = {}
end

function TestVeafCasMissionMenu:tearDown()
  for name, value in pairs(self._origMissionCommands) do
    missionCommands[name] = value
  end
  veaf.config.language = self._orig.language
  trigger.action.outText = self._orig.outText
  veaf.outTextForGroup = self._orig.outTextForGroup
  veafSpawn.spawnSmoke = self._orig.spawnSmoke
  veafSpawn.spawnIlluminationFlare = self._orig.spawnIlluminationFlare
  veaf.getAveragePosition = self._orig.getAveragePosition
  veaf.scheduleFunction = self._orig.scheduleFunction
  veafRadio.skipHelpMenus = self._orig.skipHelpMenus
  veafCasMission.groupAliveCheckTaskID = "none"
end

--- The titles of the entries a menu node holds, commands then sub-menus, sorted.
local function titlesOf(menu)
  local titles = {}
  for _, command in ipairs(menu.commands) do
    table.insert(titles, command.title)
  end
  for _, subMenu in ipairs(menu.subMenus) do
    table.insert(titles, "[" .. subMenu.title .. "]")
  end
  table.sort(titles)
  return titles
end

--- The command under `menu` titled after the i18n key.
local function command(menu, key)
  for _, candidate in ipairs(menu.commands) do
    if candidate.title == veaf.t(key) then
      return candidate
    end
  end
  return nil
end

--- What a mission start leaves running, without spawning one: the watchdog is the mission's mark.
local function startMission()
  veafCasMission.groupAliveCheckTaskID = 42
end

function TestVeafCasMissionMenu:_assertNoMenuChange()
  self.calls = {}
  veafRadio._builder:rebuild()
  luaunit.assertEquals(self.calls, {})
end

function TestVeafCasMissionMenu:test_the_menu_is_whole_from_the_start_with_no_mission()
  local root = veafCasMission.rootPath
  luaunit.assertEquals(root.title, "MISSION CAS")
  luaunit.assertEquals(root.rootRank, veafRadio.rootRank("menu.casmission.root"))
  luaunit.assertEquals(
    titlesOf(root),
    titlesOf({
      commands = {
        { title = veaf.t("menu.common.help") },
        { title = veaf.t("menu.casmission.info") },
        { title = veaf.t("menu.casmission.skip") },
      },
      subMenus = { { title = veaf.t("menu.casmission.markers") } },
    })
  )
  luaunit.assertEquals(
    titlesOf(veafCasMission.targetMarkersPath),
    { veaf.t("menu.casmission.request_smoke"), veaf.t("menu.casmission.request_flare") }
  )
end

function TestVeafCasMissionMenu:test_with_no_mission_every_entry_says_how_to_start_one()
  local root = veafCasMission.rootPath
  local markers = veafCasMission.targetMarkersPath
  command(root, "menu.casmission.info").method("pilot")
  command(root, "menu.casmission.skip").method()
  command(markers, "menu.casmission.request_smoke").method()
  command(markers, "menu.casmission.request_flare").method()
  luaunit.assertEquals(self.messages, {
    veaf.t("cas.no_mission"),
    veaf.t("cas.no_mission"),
    veaf.t("cas.no_mission"),
    veaf.t("cas.no_mission"),
  })
  luaunit.assertEquals(self.smokes + self.flares, 0)
  luaunit.assertStrContains(veaf.t("cas.no_mission"), "-cas")
end

function TestVeafCasMissionMenu:test_a_second_smoke_request_answers_instead_of_smoking()
  startMission()
  local smoke = command(veafCasMission.targetMarkersPath, "menu.casmission.request_smoke")
  smoke.method()
  smoke.method()
  luaunit.assertEquals(self.smokes, 1)
  luaunit.assertEquals(self.messages, { veaf.t("cas.smoke_requested"), veaf.t("cas.smoke_already_requested") })
  -- the reset makes it available again
  veafCasMission.smokeReset()
  smoke.method()
  luaunit.assertEquals(self.smokes, 2)
end

function TestVeafCasMissionMenu:test_a_second_flare_request_answers_instead_of_firing()
  startMission()
  local flare = command(veafCasMission.targetMarkersPath, "menu.casmission.request_flare")
  flare.method()
  flare.method()
  luaunit.assertEquals(self.flares, 1)
  luaunit.assertEquals(self.messages, { veaf.t("cas.illum_requested"), veaf.t("cas.illum_already_requested") })
  veafCasMission.flareReset()
  flare.method()
  luaunit.assertEquals(self.flares, 2)
end

function TestVeafCasMissionMenu:test_a_whole_mission_adds_and_removes_no_menu_entry()
  startMission()
  self:_assertNoMenuChange()
  local markers = veafCasMission.targetMarkersPath
  command(markers, "menu.casmission.request_smoke").method()
  self:_assertNoMenuChange()
  command(markers, "menu.casmission.request_flare").method()
  self:_assertNoMenuChange()
  veafCasMission.smokeReset()
  veafCasMission.flareReset()
  self:_assertNoMenuChange()
  veafCasMission.cleanupAfterMission()
  self:_assertNoMenuChange()
  luaunit.assertEquals(veafCasMission.groupAliveCheckTaskID, "none")
end

function TestVeafCasMissionMenu:test_the_end_of_a_mission_makes_the_markers_available_again()
  startMission()
  command(veafCasMission.targetMarkersPath, "menu.casmission.request_smoke").method()
  veafCasMission.cleanupAfterMission()
  startMission()
  self.messages = {}
  command(veafCasMission.targetMarkersPath, "menu.casmission.request_smoke").method()
  luaunit.assertEquals(self.messages, { veaf.t("cas.smoke_requested") })
end

function TestVeafCasMissionMenu:test_the_menu_is_the_same_in_english()
  veaf.config.language = "en"
  veafRadio.radioMenu.subMenus = {}
  veafRadio.radioMenu.commands = {}
  veafCasMission.buildRadioMenu()
  luaunit.assertEquals(veafCasMission.rootPath.title, "CAS MISSION")
  startMission()
  command(veafCasMission.targetMarkersPath, "menu.casmission.request_smoke").method()
  veafCasMission.cleanupAfterMission()
  luaunit.assertEquals(#veafCasMission.rootPath.commands, 3)
  luaunit.assertEquals(#veafCasMission.targetMarkersPath.commands, 2)
end

os.exit(luaunit.LuaUnit.run())
