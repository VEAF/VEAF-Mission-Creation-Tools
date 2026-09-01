--- Unit tests for veafMissionDb.lua — the mission-side services VEAF needs at runtime.
---
--- Run:  lua test/lua/test_veafMissionDb.lua
---
--- Covers:
---   - Unit ids are unique, increasing, and start above everything else that allocates them
---   - The editor snapshot: units and groups by name and by id, the fields their readers need,
---     the bullseye, the country tables, and a mission with nothing in it
---   - The player roster: editor slots, DCS dynamic slots, and the empty-string player name trap
---   - The spawned-name registry, including the MiST tables it still has to clear

-- ---------------------------------------------------------------------------
-- Bootstrap: load the test framework, DCS mocks, and modules under test.
-- ---------------------------------------------------------------------------
local _base = debug.getinfo(1, "S").source:match("^@(.+)[\\/]") or "."
luaunit = dofile(_base .. "/luaunit.lua") -- exported as global for test methods
dofile(_base .. "/dcs_mocks.lua")
dofile(_base .. "/../../src/scripts/veaf/veaf.lua")
dofile(_base .. "/../../src/scripts/veaf/veafScheduler.lua")
dofile(_base .. "/../../src/scripts/veaf/veafMath.lua")
dofile(_base .. "/../../src/scripts/veaf/veafGeo.lua")
dofile(_base .. "/../../src/scripts/veaf/veafMissionDb.lua")

--- A mission holding one blue two-ship of planes and one red vehicle, in the shape `env.mission`
--- uses: coalition -> country -> category -> group -> units. Unit positions are mission-table vec2s,
--- `y` being the easting.
local function buildTestMission()
  env.mission.coalition = {
    blue = {
      bullseye = { x = 1000, y = 2000 },
      country = {
        [1] = {
          id = 2,
          name = "usa",
          plane = {
            group = {
              [1] = {
                name = "Chevy",
                groupId = 10,
                units = {
                  [1] = {
                    name = "Chevy11",
                    unitId = 101,
                    type = "F-16C_50",
                    x = 100,
                    y = 200,
                    alt = 3000,
                    skill = "Client",
                  },
                  [2] = {
                    name = "Chevy12",
                    unitId = 102,
                    type = "F-16C_50",
                    x = 150,
                    y = 250,
                    alt = 3000,
                    skill = "High",
                  },
                },
              },
            },
          },
        },
      },
    },
    red = {
      bullseye = { x = -500, y = -600 },
      country = {
        [1] = {
          id = 0,
          name = "russia",
          vehicle = {
            group = {
              [1] = {
                name = "Convoy",
                groupId = 20,
                units = { [1] = { name = "Convoy-1", unitId = 201, type = "BTR-80", x = 5000, y = 6000 } },
              },
            },
          },
        },
      },
    },
  }
  veafMissionDb.buildSnapshot()
end

-- ---------------------------------------------------------------------------
-- Unit ids
-- ---------------------------------------------------------------------------

TestVeafMissionDb = {}

function TestVeafMissionDb:setUp()
  dcs_mocks.reset()
  veafMissionDb.lastUnitId = veafMissionDb.FIRST_UNIT_ID - 1
end

function TestVeafMissionDb:test_idsAreUniqueAndIncreasing()
  local first = veaf.getNextUnitId()
  local second = veaf.getNextUnitId()
  local third = veaf.getNextUnitId()
  luaunit.assertEquals(second, first + 1)
  luaunit.assertEquals(third, second + 1)
end

function TestVeafMissionDb:test_theFirstIdIsTheConfiguredBase()
  luaunit.assertEquals(veaf.getNextUnitId(), veafMissionDb.FIRST_UNIT_ID)
end

--- DCS reserves 6900–30000, and MiST — still injected alongside us for the rest of this campaign —
--- allocates from 30000 upwards once it passes 6900. Our ids have to start clear of both.
function TestVeafMissionDb:test_idsStartClearOfTheReservedBandAndOfMist()
  luaunit.assertTrue(veafMissionDb.FIRST_UNIT_ID > 30000)
  luaunit.assertTrue(veaf.getNextUnitId() > 30000)
end

function TestVeafMissionDb:test_athousandIdsAreAllDistinct()
  local seen = {}
  for _ = 1, 1000 do
    local id = veaf.getNextUnitId()
    luaunit.assertNil(seen[id])
    seen[id] = true
  end
end

-- ---------------------------------------------------------------------------
-- The editor snapshot
-- ---------------------------------------------------------------------------

TestVeafMissionDbSnapshot = {}

function TestVeafMissionDbSnapshot:setUp()
  dcs_mocks.reset()
  self._savedMission = env.mission.coalition
  buildTestMission()
end

function TestVeafMissionDbSnapshot:tearDown()
  env.mission.coalition = self._savedMission
  veafMissionDb.buildSnapshot()
end

function TestVeafMissionDbSnapshot:test_everyUnitIsIndexedByName()
  luaunit.assertNotNil(veaf.getUnitRecord("Chevy11"))
  luaunit.assertNotNil(veaf.getUnitRecord("Chevy12"))
  luaunit.assertNotNil(veaf.getUnitRecord("Convoy-1"))
  luaunit.assertNil(veaf.getUnitRecord("no such unit"))
end

--- The fields `veafInterpreter` documents as the ones it reads: x, y, alt, coalitionId, groupName —
--- plus the type `veafGrass` and `veafMove` filter on and the category `veafAirWaves` wants.
function TestVeafMissionDbSnapshot:test_aUnitRecordCarriesWhatItsReadersNeed()
  local record = veaf.getUnitRecord("Chevy11")
  luaunit.assertEquals(record.unitName, "Chevy11")
  luaunit.assertEquals(record.groupName, "Chevy")
  luaunit.assertEquals(record.groupId, 10)
  luaunit.assertEquals(record.type, "F-16C_50")
  luaunit.assertEquals(record.x, 100)
  luaunit.assertEquals(record.y, 200)
  luaunit.assertEquals(record.alt, 3000)
  luaunit.assertEquals(record.coalition, "blue")
  luaunit.assertEquals(record.coalitionId, coalition.side.BLUE)
  luaunit.assertEquals(record.category, "plane")
  luaunit.assertEquals(record.country, "usa")
end

function TestVeafMissionDbSnapshot:test_aRedUnitCarriesTheRedCoalition()
  local record = veaf.getUnitRecord("Convoy-1")
  luaunit.assertEquals(record.coalition, "red")
  luaunit.assertEquals(record.coalitionId, coalition.side.RED)
  luaunit.assertEquals(record.category, "vehicle")
end

function TestVeafMissionDbSnapshot:test_groupsAreIndexedByNameAndById()
  luaunit.assertEquals(veaf.getGroupRecord("Chevy").groupId, 10)
  luaunit.assertEquals(veaf.getGroupRecordById(10).groupName, "Chevy")
  luaunit.assertEquals(veaf.getGroupRecordById(20).groupName, "Convoy")
  luaunit.assertNil(veaf.getGroupRecord("no such group"))
  luaunit.assertNil(veaf.getGroupRecordById(999))
end

function TestVeafMissionDbSnapshot:test_aGroupCarriesItsUnits()
  luaunit.assertEquals(#veaf.getGroupRecord("Chevy").units, 2)
end

--- A record exists for a unit that has not spawned and for one already destroyed — the whole reason
--- an index is needed rather than `Unit.getByName`, which answers a live object or nothing.
function TestVeafMissionDbSnapshot:test_aRecordSurvivesTheUnitBeingAbsentFromTheWorld()
  luaunit.assertNil(Unit.getByName("Chevy11"))
  luaunit.assertNotNil(veaf.getUnitRecord("Chevy11"))
end

function TestVeafMissionDbSnapshot:test_theBullseyeComesStraightFromTheMission()
  luaunit.assertEquals(veaf.getBullseye("blue"), { x = 1000, y = 2000 })
  luaunit.assertEquals(veaf.getBullseye("red"), { x = -500, y = -600 })
  luaunit.assertNil(veaf.getBullseye("neutral"))
end

function TestVeafMissionDbSnapshot:test_countriesAreIndexedByCoalition()
  local countries = veaf.getCountriesByCoalitionFromMission()
  luaunit.assertEquals(countries.blue.usa.countryId, 2)
  luaunit.assertEquals(countries.red.russia.countryId, 0)
end

function TestVeafMissionDbSnapshot:test_aMissionWithNoCoalitionsIsNotAnError()
  env.mission.coalition = nil
  veafMissionDb.buildSnapshot()
  luaunit.assertNil(next(veafMissionDb.unitsByName))
end

-- ---------------------------------------------------------------------------
-- The player roster
-- ---------------------------------------------------------------------------

TestVeafMissionDbRoster = {}

function TestVeafMissionDbRoster:setUp()
  dcs_mocks.reset()
  self._savedMission = env.mission.coalition
  buildTestMission()
  veafMissionDb.initialize()
end

function TestVeafMissionDbRoster:tearDown()
  env.mission.coalition = self._savedMission
  veafMissionDb.buildSnapshot()
end

--- Skill `Client` marks a playable slot; `High` is an AI wingman in the same group.
function TestVeafMissionDbRoster:test_onlyPlayableSlotsAreInTheRoster()
  luaunit.assertTrue(veaf.isHumanUnit("Chevy11"))
  luaunit.assertFalse(veaf.isHumanUnit("Chevy12"))
  luaunit.assertFalse(veaf.isHumanUnit("Convoy-1"))
end

function TestVeafMissionDbRoster:test_anUnknownUnitIsNotHuman()
  luaunit.assertFalse(veaf.isHumanUnit("nobody"))
end

--- A dynamic-slot player is human the moment he is in the seat, which is when the event handlers that
--- call this run — before anything has asked for the full roster. So the name is checked against DCS
--- rather than only against the roster.
function TestVeafMissionDbRoster:test_aDynamicSlotPlayerIsHumanBeforeAnySweep()
  dcs_mocks.addUnit("JustArrived", {
    getPlayerName = function()
      return "David"
    end,
  })
  luaunit.assertNil(veafMissionDb.humansByName["JustArrived"])
  luaunit.assertTrue(veaf.isHumanUnit("JustArrived"))
end

function TestVeafMissionDbRoster:test_anAiUnitIsNotHumanOnThatPathEither()
  dcs_mocks.addUnit("AI-3", {
    getPlayerName = function()
      return ""
    end,
  })
  luaunit.assertFalse(veaf.isHumanUnit("AI-3"))
end

--- DCS dynamic slots create player units that were never in env.mission. A roster built from the
--- editor alone loses them — which is why `veafAirWaves` used to sweep coalition.getGroups by hand.
function TestVeafMissionDbRoster:test_aDynamicSlotPlayerJoinsTheRoster()
  dcs_mocks.addUnit("Dynamic11", {
    getPlayerName = function()
      return "David"
    end,
  })
  dcs_mocks.addGroup("DynamicGroup", {
    getUnits = function()
      return { Unit.getByName("Dynamic11") }
    end,
  })
  luaunit.assertNil(veafMissionDb.humansByName["Dynamic11"]) -- not in the roster before the sweep

  local roster = veaf.getAllHumanRecords()
  luaunit.assertNotNil(roster["Dynamic11"])
  luaunit.assertTrue(roster["Dynamic11"].dynamicSlot)
  luaunit.assertTrue(veaf.isHumanUnit("Dynamic11"))
end

--- The guard that matters: in Lua `""` is truthy, so `if unit:getPlayerName() then` would count every
--- AI aircraft as a player. DCS is not documented on which of nil or "" it answers for an AI unit,
--- so the roster accepts neither.
function TestVeafMissionDbRoster:test_anAiUnitWhosePlayerNameIsAnEmptyStringIsNotAPlayer()
  dcs_mocks.addUnit("AI-1", {
    getPlayerName = function()
      return ""
    end,
  })
  dcs_mocks.addGroup("AiGroup", {
    getUnits = function()
      return { Unit.getByName("AI-1") }
    end,
  })
  veaf.getAllHumanRecords()
  luaunit.assertFalse(veaf.isHumanUnit("AI-1"))
end

function TestVeafMissionDbRoster:test_anAiUnitWhosePlayerNameIsNilIsNotAPlayer()
  dcs_mocks.addUnit("AI-2", {
    getPlayerName = function()
      return nil
    end,
  })
  dcs_mocks.addGroup("AiGroup2", {
    getUnits = function()
      return { Unit.getByName("AI-2") }
    end,
  })
  veaf.getAllHumanRecords()
  luaunit.assertFalse(veaf.isHumanUnit("AI-2"))
end

--- No polling loop: the sweep runs when someone asks who is flying, because that is the moment the
--- answer has to be current. Asking twice must not duplicate anyone.
function TestVeafMissionDbRoster:test_theSweepIsIdempotent()
  dcs_mocks.addUnit("Dynamic21", {
    getPlayerName = function()
      return "David"
    end,
  })
  dcs_mocks.addGroup("DynamicGroup2", {
    getUnits = function()
      return { Unit.getByName("Dynamic21") }
    end,
  })
  veaf.getAllHumanRecords()
  local first = veaf.length(veaf.getAllHumanRecords())
  local second = veaf.length(veaf.getAllHumanRecords())
  luaunit.assertEquals(second, first)
end

-- ---------------------------------------------------------------------------
-- The spawned-name registry
-- ---------------------------------------------------------------------------

TestVeafMissionDbNames = {}

function TestVeafMissionDbNames:setUp()
  dcs_mocks.reset()
  self._savedMission = env.mission.coalition
  buildTestMission()
end

function TestVeafMissionDbNames:tearDown()
  env.mission.coalition = self._savedMission
  veafMissionDb.buildSnapshot()
end

function TestVeafMissionDbNames:test_aTakenNameIsTaken()
  luaunit.assertFalse(veaf.isNameTaken("AFAC Axeman 1"))
  veaf.takeSpawnedName("AFAC Axeman 1")
  luaunit.assertTrue(veaf.isNameTaken("AFAC Axeman 1"))
end

--- The editor's own names count as taken too: a spawn must not collide with a pre-placed group.
function TestVeafMissionDbNames:test_theEditorsNamesAreTakenAsWell()
  luaunit.assertTrue(veaf.isNameTaken("Chevy"))
  luaunit.assertTrue(veaf.isNameTaken("Chevy11"))
end

function TestVeafMissionDbNames:test_releasingGivesTheNameBack()
  veaf.takeSpawnedName("AFAC Axeman 1")
  luaunit.assertTrue(veaf.releaseSpawnedName("AFAC Axeman 1"))
  luaunit.assertFalse(veaf.isNameTaken("AFAC Axeman 1"))
end

function TestVeafMissionDbNames:test_releasingAnUnknownNameAnswersFalse()
  luaunit.assertFalse(veaf.releaseSpawnedName("never taken"))
  luaunit.assertFalse(veaf.releaseSpawnedName(nil))
end

--- Releasing a name must not consult MiST any more. Ticket 07 replaced `mist.teleportToPoint`, so
--- `isNameTaken` reads this module's tables and nothing else — the point being that the name really
--- does come back when MiST is not loaded at all, which is the state the mission is heading for.
function TestVeafMissionDbNames:test_releasingWorksWithNoMistLoaded()
  local savedMist = mist
  mist = nil

  veaf.takeSpawnedName("AFAC Axeman 1")
  local released = veaf.releaseSpawnedName("AFAC Axeman 1")
  local stillTaken = veaf.isNameTaken("AFAC Axeman 1")

  mist = savedMist
  luaunit.assertTrue(released)
  luaunit.assertFalse(stillTaken, "the callsign is free again, without MiST having been asked")
end

-- ---------------------------------------------------------------------------
-- Run
-- ---------------------------------------------------------------------------
os.exit(luaunit.LuaUnit.run())
