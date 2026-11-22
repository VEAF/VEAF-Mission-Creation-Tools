--- Tests for veafSupport.lua: the AWACS and tankers held out of the enemy's air defence, in a mission with no
--- campaign (FEAT-DYNAMIC-CAMPAIGN ticket 20, David 2026-11-17).
local _base = debug.getinfo(1, "S").source:match("^@(.+)[\\/]") or "."
luaunit = dofile(_base .. "/luaunit.lua")
dofile(_base .. "/dcs_mocks.lua")
local src = _base .. "/../../src/scripts/veaf"
dofile(src .. "/veaf.lua")
dofile(src .. "/veafI18n.lua")
dofile(src .. "/veafScheduler.lua")
dofile(src .. "/veafSupport.lua")

local BLUE, RED = coalition.side.BLUE, coalition.side.RED

TestVeafSupport = {}

--- A red SAM unit at `x` (km north of the origin) whose missile reaches `reach` metres.
local function sam(x, reach)
  return {
    isExist = function()
      return true
    end,
    isActive = function()
      return true
    end,
    getPoint = function()
      return { x = x * 1000, y = 0, z = 0 }
    end,
    getAmmo = function()
      return { { count = 4, desc = { category = Weapon.Category.MISSILE, rangeMaxAltMax = reach } } }
    end,
  }
end

function TestVeafSupport:setUp()
  dcs_mocks.reset()
  self.moves, self.marks, self.removed = {}, {}, {}
  self.groupId = 1
  self.sams = {}
  self.awacs = false -- a tanker unless a test says otherwise: the rule every asset shares
  local this = self
  self.saved = {
    move = veafMove,
    group = Group.getByName,
    groups = coalition.getGroups,
    ref = coalition.getMainRefPoint,
    line = trigger.action.lineToAll,
    text = trigger.action.textToAll,
    remove = trigger.action.removeMark,
    data = veaf.getGroupData,
  }
  -- the Mission Editor's orbit: 100 km south of the origin, its leg 30 km east
  veafMove = {
    _getTankerRouteData = function()
      return { point2 = { x = -100000, y = 0 }, point3 = { x = -100000, y = 30000 } }
    end,
    moveTanker = function(point, name, _, _, heading)
      table.insert(this.moves, { x = point.x, z = point.z, name = name, heading = heading })
      return true
    end,
  }
  Group.getByName = function(name)
    if name ~= "AWACS Magic" then
      return nil
    end
    return {
      isExist = function()
        return true
      end,
      getCoalition = function()
        return BLUE
      end,
      getID = function()
        return this.groupId
      end,
      getUnits = function()
        return {
          {
            hasAttribute = function(_, attribute)
              return attribute == "AWACS" and this.awacs
            end,
          },
        }
      end,
    }
  end
  coalition.getGroups = function(side)
    if side ~= RED then
      return {}
    end
    local groups = {}
    for _, unit in ipairs(this.sams) do
      table.insert(groups, {
        getUnits = function()
          return { unit }
        end,
        getName = function()
          return "red SAM"
        end,
      })
    end
    return groups
  end
  coalition.getMainRefPoint = function()
    return { x = 0, y = 0, z = 0 }
  end
  trigger.action.lineToAll = function(side, id, from, to)
    table.insert(this.marks, { side = side, id = id, from = from, to = to })
  end
  trigger.action.textToAll = function(side, id, point, _, _, _, _, text)
    table.insert(this.marks, { side = side, id = id, point = point, text = text })
  end
  trigger.action.removeMark = function(id)
    table.insert(this.removed, id)
  end
  veaf.getGroupData = function()
    return { frequency = 282.2 }
  end
  veafSupport.configure({ assets = { "AWACS Magic" } })
  veafSupport.threatSource, veafSupport.frontLimit, veafSupport.tell = nil, nil, nil
  veafSupport.state = {}
end

function TestVeafSupport:tearDown()
  veafMove, Group.getByName, coalition.getGroups = self.saved.move, self.saved.group, self.saved.groups
  coalition.getMainRefPoint = self.saved.ref
  trigger.action.lineToAll, trigger.action.textToAll = self.saved.line, self.saved.text
  trigger.action.removeMark, veaf.getGroupData = self.saved.remove, self.saved.data
end

function TestVeafSupport:test_with_no_threat_it_stays_on_its_orbit_and_marks_it_for_its_side()
  veafSupport.follow("AWACS Magic", 0)
  luaunit.assertEquals(#self.moves, 0)
  luaunit.assertEquals(#self.marks, 2)
  luaunit.assertEquals(self.marks[1].side, BLUE)
  luaunit.assertEquals({ self.marks[1].from.x, self.marks[1].to.z }, { -100000, 30000 })
  luaunit.assertEquals(self.marks[2].text, "AWACS Magic 282.20")
end

function TestVeafSupport:test_a_sam_seen_in_the_mission_makes_it_retreat_at_once_and_well_out()
  -- a SAM 50 km north of the orbit reaching 80 km: the orbit is inside it
  self.sams = { sam(-50, 80000) }
  veafSupport.follow("AWACS Magic", 0)
  luaunit.assertEquals(#self.moves, 1)
  -- out of 80 km + the retreat margin of 50 km: 130 km south of the SAM
  luaunit.assertEquals(self.moves[1].x, -50000 - 130000)
  luaunit.assertEquals(#dcs_mocks.messagesContaining("AWACS Magic"), 1)
  -- its marks follow: the old ones removed, the new ones at the new orbit
  luaunit.assertEquals(#self.removed, 2)
  luaunit.assertEquals(self.marks[#self.marks].point.x, -180000)
end

function TestVeafSupport:test_short_range_missiles_are_no_threat_in_a_mission_alone()
  self.sams = { sam(-90, 8000) }
  veafSupport.follow("AWACS Magic", 0)
  luaunit.assertEquals(#self.moves, 0)
end

function TestVeafSupport:test_it_comes_back_only_after_a_long_calm()
  self.sams = { sam(-50, 80000) }
  veafSupport.follow("AWACS Magic", 0)
  self.sams = {}
  veafSupport.follow("AWACS Magic", 60)
  veafSupport.follow("AWACS Magic", 1800)
  luaunit.assertEquals(#self.moves, 1, "30 minutes since the SAM died, not since it was seen gone")
  veafSupport.follow("AWACS Magic", 1860)
  luaunit.assertEquals(#self.moves, 2)
  luaunit.assertEquals({ self.moves[2].x, self.moves[2].z }, { -100000, 0 }, "back on its orbit, never beyond")
end

function TestVeafSupport:test_a_sam_that_comes_and_goes_every_few_minutes_does_not_make_it_shuttle()
  local now = 0
  for cycle = 1, 20 do
    self.sams = cycle % 2 == 1 and { sam(-50, 80000) } or {}
    veafSupport.follow("AWACS Magic", now)
    now = now + 300
  end
  luaunit.assertEquals(#self.moves, 1, "one retreat, then it holds")
end

-- A respawn keeps the Mission Editor's group id (VeafGroupSpawn:respawn, measured in game: 44 both times): the
-- signal is the birth of its units (review of PR #1293, 2026-11-17)
local function birth(groupName)
  return {
    dcsInitiator = {
      getGroup = function()
        return {
          getName = function()
            return groupName
          end,
        }
      end,
    },
  }
end

function TestVeafSupport:test_a_respawned_asset_is_weighed_again_from_its_orbit()
  self.sams = { sam(-50, 80000) }
  veafSupport.follow("AWACS Magic", 0)
  luaunit.assertEquals(#self.moves, 1, "out of the SAM's reach")
  -- respawned, same id: back on its Mission Editor orbit, under the SAM
  veafSupport.onBirth(birth("AWACS Magic"))
  veafSupport.follow("AWACS Magic", 60)
  luaunit.assertEquals(#self.moves, 2, "weighed again from its orbit, and out again")
  veafSupport.follow("AWACS Magic", 120)
  luaunit.assertEquals(#self.moves, 2, "once")
end

function TestVeafSupport:test_another_group_s_birth_changes_nothing()
  self.sams = { sam(-50, 80000) }
  veafSupport.follow("AWACS Magic", 0)
  veafSupport.onBirth(birth("Somebody else"))
  veafSupport.onBirth({})
  veafSupport.follow("AWACS Magic", 60)
  luaunit.assertEquals(#self.moves, 1)
end

function TestVeafSupport:test_a_campaign_gives_its_threats_its_front_and_its_voice()
  local told = {}
  veafSupport.threatSource = function()
    return { { center = { x = 0, z = 0 }, reach = 20000, name = "Senaki" } }
  end
  veafSupport.frontLimit = function()
    return 50000 -- our front zone stands 50 km from Senaki
  end
  veafSupport.tell = function(side, text)
    table.insert(told, { side = side, text = text })
  end
  -- out of reach at its orbit; the front allows it 50 km from Senaki, 50 km closer: after the calm, it advances
  veafSupport.follow("AWACS Magic", 0)
  veafSupport.follow("AWACS Magic", 1800)
  luaunit.assertEquals(#self.moves, 1)
  luaunit.assertEquals(self.moves[1].x, -50000)
  luaunit.assertEquals(#told, 1)
  luaunit.assertEquals(told[1].side, BLUE)
end

-- 2026-11-22: a red zone with MANPADS alone (reach 4 km) let the AWACS hold some 35 km from it; its radar sees about
-- 100 NM, it has no need to be that close (David). The tankers stay handy near the front.
local function manpadsZone()
  veafSupport.threatSource = function()
    return { { center = { x = -50000, z = 0 }, reach = 4000, name = "Jisr al-Shughur" } }
  end
end

function TestVeafSupport:test_an_awacs_holds_awacs_standoff_from_every_enemy_zone_whatever_its_reach()
  self.awacs = true
  manpadsZone()
  veafSupport.follow("AWACS Magic", 0)
  luaunit.assertEquals(#self.moves, 1, "its Mission Editor orbit is 50 km from the zone: out at once")
  luaunit.assertEquals(self.moves[1].x, -50000 - 100000, "100 km from the zone's centre, the default standoff")
  veafSupport.follow("AWACS Magic", 1800)
  veafSupport.follow("AWACS Magic", 3600)
  luaunit.assertEquals(#self.moves, 1, "and it holds there")
end

function TestVeafSupport:test_a_tanker_holds_where_it_did()
  manpadsZone()
  veafSupport.follow("AWACS Magic", 0)
  veafSupport.follow("AWACS Magic", 1800)
  luaunit.assertEquals(#self.moves, 0, "50 km from a 4 km reach, beyond the 30 km margin: it stays on its orbit")
end

function TestVeafSupport:test_the_standoff_is_a_setting()
  self.awacs = true
  manpadsZone()
  veafSupport.configure({ assets = { "AWACS Magic" }, awacs_standoff = 70000 })
  veafSupport.follow("AWACS Magic", 0)
  luaunit.assertEquals(self.moves[1].x, -50000 - 70000)
end

function TestVeafSupport:test_an_awacs_never_advances_inside_its_standoff()
  self.awacs = true
  -- the campaign case where a tanker advanced to the front, 50 km from Senaki: the AWACS, 100 km out, stays
  veafSupport.threatSource = function()
    return { { center = { x = 0, z = 0 }, reach = 20000, name = "Senaki" } }
  end
  veafSupport.frontLimit = function()
    return 50000
  end
  veafSupport.follow("AWACS Magic", 0)
  veafSupport.follow("AWACS Magic", 1800)
  veafSupport.follow("AWACS Magic", 3600)
  luaunit.assertEquals(#self.moves, 0)
end

function TestVeafSupport:test_a_move_logs_the_orbit_from_the_bullseye_and_its_distance_to_the_threat()
  self.awacs = true
  manpadsZone()
  veafSupport.follow("AWACS Magic", 0)
  -- the bullseye is the origin: the orbit 150 km south is on 180, 81 NM
  luaunit.assertEquals(#dcs_mocks.findLog("orbit now 180/81 NM from the bullseye, 100 km from %[Jisr al%-Shughur%]"), 1)
end

os.exit(luaunit.LuaUnit.run())
