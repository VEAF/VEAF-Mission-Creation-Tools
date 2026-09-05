------------------------------------------------------------------
-- VEAF combat zone functions for DCS World
-- By zip (2019-20)
--
-- Features:
-- ---------
-- * Zones can be defined in the mission editor that are then managed by this script.
-- * For each zone, a specific radio sub-menu is created, allowing common actions on all specific zone (get coordinates, enemy presence, weather, pop smoke and flares, read a briefing, stop and start dynamic activity on the zone, etc.)
--
-- See the documentation : https://veaf.github.io/documentation/
------------------------------------------------------------------

veafCombatZone = {}

-------------------------------------------------------------------------------------------------------------------------------------------------------------
-- Global settings. Stores the script constants
-------------------------------------------------------------------------------------------------------------------------------------------------------------

--- Identifier. All output in DCS.log will start with this.
veafCombatZone.Id = "COMBATZONE"

-- trace level, specific to this module
--veafCombatZone.LogLevel = "trace"

veaf.loggers.new(veafCombatZone.Id, veafCombatZone.LogLevel)

--- Number of seconds between each check of the zone watchdog function
veafCombatZone.SecondsBetweenWatchdogChecks = 60

--- Number of seconds between each smoke request on the zones
veafCombatZone.SecondsBetweenSmokeRequests = 180

--- Number of seconds between each flare request on the zones
veafCombatZone.SecondsBetweenFlareRequests = 120

veafCombatZone.DefaultSpawnRadiusForUnits = 50

veafCombatZone.DefaultSpawnRadiusForStatics = 0

-- Alarm states, as AI.Option.Ground.val.ALARM_STATE: 0 AUTO, 1 GREEN, 2 RED.
veafCombatZone.ALARM_STATE_AUTO = 0
veafCombatZone.ALARM_STATE_GREEN = 1
veafCombatZone.ALARM_STATE_RED = 2

-- Alarm state a spawned group gets unless its unit name carries `#alarm=`, **chosen by the nature of
-- the group** rather than fixed for all of them. The two defaults below are both right, for opposite
-- groups, which is why one global value could not serve:
--
--  * A group with a route to drive wants AUTO. On RED a DCS ground group holds position, so the global
--    RED this module used to apply immobilised every convoy a zone spawned (#290, open since April
--    2025).
--  * A group that stays put wants RED, so it fights on sight. On AUTO a SAM battery keeps its radar
--    down — which is what the global AUTO of PR #762 cost: fixing the convoys made every air defence
--    inside a combat zone go quiet.
--
-- PR #762's own PRD named this trade ("right for a SAM battery, wrong for a convoy") and picked a single
-- default anyway, leaving `#alarm=N` as the escape hatch. An escape hatch every mission maker has to
-- apply to every existing battery is a regression, not an option — hence choosing per group.
veafCombatZone.DefaultAlarmStateMobile = veafCombatZone.ALARM_STATE_AUTO
veafCombatZone.DefaultAlarmStateStatic = veafCombatZone.ALARM_STATE_RED

-- Kept as the value an unreadable `#alarm=` tag falls back to, and as what a caller gets when the
-- group's nature cannot be determined: RED is the safer of the two, since a group that fights when it
-- should have driven is visible, while one that stays silent when it should have fired is not.
veafCombatZone.DefaultAlarmState = veafCombatZone.ALARM_STATE_RED

-- Pattern matching the `#alarm=` tag in a unit name. A module constant rather than an inline literal
-- so the tests exercise the same pattern the parser uses.
veafCombatZone.ALARM_TAG_PATTERN = "#alarm%s*=%s*(%d+)"

-- Every tag a mission maker can embed in a unit or group name, as a table rather than seven inline
-- literals: anything working on "all the tags" cannot then silently miss one.
-- Names are lowercased before matching, so a quoted value comes back lowercased too — long-standing
-- behaviour that `#command` aliases and `#spawngroup` names rely on.
-- The four count/distance tags read `100-300` as well as `200`, and the value is converted by
-- `veaf.getRandomizableNumeric` where the tag is applied — the same function marker commands use, so a
-- range means the same thing in both places (#25).
--
-- Before this, the pattern was `(%d+)`: `#spawnradius=100-300` matched **`100`** and the `-300` was
-- never seen, so a mission maker who wrote a range silently got its lower bound.
--
-- `alarmState` keeps its own pattern and takes no range: it is an enumeration (0 AUTO, 1 GREEN, 2 RED),
-- and a range over an enumeration is a mistake rather than a random value. `spawnGroup` and `command`
-- are strings, and their values legitimately contain dashes.
veafCombatZone.TAG_PATTERNS = {
  spawnRadius = "#spawnradius%s*=%s*([%d%-]+)",
  spawnChance = "#spawnchance%s*=%s*([%d%-]+)",
  spawnCount = "#spawncount%s*=%s*([%d%-]+)",
  spawnGroup = '#spawngroup%s*=%s*"([^"]+)"',
  spawnDelay = "#spawndelay%s*=%s*([%d%-]+)",
  command = '#command%s*=%s*"([^"]+)"',
  alarmState = veafCombatZone.ALARM_TAG_PATTERN,
}

-- The tags that describe the *group*, and are therefore collected from every name carrying one.
-- `command` is absent on purpose: it turns one object into a one-shot trigger, so merging it would
-- silently drop the second command of a group carrying two.
veafCombatZone.MERGED_TAGS = { "spawnRadius", "spawnChance", "spawnCount", "spawnGroup", "spawnDelay", "alarmState" }

-- Coalition a zone considers hostile unless told otherwise: red, i.e. blue players
-- clearing a red zone. Set per zone with VeafCombatZone:setEnemyCoalition().
veafCombatZone.DEFAULT_ENEMY_COALITION = 1

-- Sentinel for setRadioMenuCoalition("all"): show the zone's F10 menu to everyone, as it was
-- before the menu became side-scoped. Distinct from nil, which means "not set".
veafCombatZone.RADIO_MENU_FOR_ALL = "all"

veafCombatZone.RadioMenuName = "menu.combatzone.root"

-- Combat zones specific radio menu name
veafCombatZone.CombatZoneRadioMenuName = nil

-- Combat operations specific radio menu name
veafCombatZone.OperationRadioMenuName = nil

-- Event messages are i18n catalog keys (see veafI18n.lua), resolved through
-- veaf.t() at send time so they localize to the mission language.
veafCombatZone.EventMessages = {
  CombatZoneComplete = "combatzone.complete",
  PopSmokeRequest = "combatzone.smoke_requested",
  UseFlareRequest = "combatzone.flare_requested",
  CombatOperationComplete = "combatzone.operation_complete",
}

-------------------------------------------------------------------------------------------------------------------------------------------------------------
-- Do not change anything below unless you know what you are doing!
-------------------------------------------------------------------------------------------------------------------------------------------------------------

--- Radio menus paths
veafCombatZone.rootPath = nil

--- Combat Zones radio menus paths
veafCombatZone.combatZoneRootPath = nil
--- Operation radio menus paths
veafCombatZone.operationRootPath = nil

-- Zones list (table of VeafCombatZone objects)
veafCombatZone.zonesList = {}

-- Zones dictionary (map of VeafCombatZone objects by zone name)
veafCombatZone.zonesDict = {}

-- Radio groups dictionary (map of radio menu paths by radio group name)
veafCombatZone.radioGroupsDict = {}
-------------------------------------------------------------------------------------------------------------------------------------------------------------
-- Utils
-------------------------------------------------------------------------------------------------------------------------------------------------------------

local messageSeparator = "\n=====================================================\n"

--- Read the tags embedded in one unit or group name.
--- @param name unit or group name as typed in the mission editor; nil is tolerated
--- @return table mapping tag key (see veafCombatZone.TAG_PATTERNS) to its raw string value; empty
---         when the name carries no tag at all
function veafCombatZone.parseTags(name)
  local tags = {}
  if not name then
    return tags
  end
  local lowered = name:lower()
  for key, pattern in pairs(veafCombatZone.TAG_PATTERNS) do
    local _, _, value = lowered:find(pattern)
    if value then
      tags[key] = value
    end
  end
  return tags
end

--- Collect a group's tags from its own name and from the names of all its units.
---
--- Sources are read in a fixed order — the group name first, then the unit names in **alphabetical**
--- order — and the first value found for a tag wins; a later source stating a different value is
--- ignored with a warning. Alphabetical rather than the order the units were met in: that order is
--- `veaf.getUnitsInTriggerZone` followed by `pairs()`, so tie-breaking on it would be the coin toss this
--- replaces, and it is not something a mission maker can see in the mission editor.
---
--- `#command` is not merged — it is a one-shot trigger attached to an object, not a setting of the
--- group — so it comes back separately, keyed by the name that carried it. That second return value is
--- what keeps every name parsed exactly once: the caller never has to read a name's tags again.
---
--- @param groupName name of the group; a static object is its own group
--- @param unitNames names of the group's units, in any order
--- @return table of tag key to raw string value, `command` excluded (see veafCombatZone.MERGED_TAGS)
--- @return table mapping a source name to the `#command` it carries, empty when none does
function veafCombatZone.collectTags(groupName, unitNames)
  local sources = {}
  if groupName then
    table.insert(sources, groupName)
  end
  local sortedUnitNames = {}
  for _, unitName in pairs(unitNames or {}) do
    if unitName ~= groupName then -- a static object's unit name *is* its group name; read it once
      table.insert(sortedUnitNames, unitName)
    end
  end
  table.sort(sortedUnitNames)
  for _, unitName in ipairs(sortedUnitNames) do
    table.insert(sources, unitName)
  end

  local tags = {}
  local statedBy = {}
  local commandsBySource = {}
  local sawAlarmTag = false
  for _, source in ipairs(sources) do
    local parsed = veafCombatZone.parseTags(source)
    sawAlarmTag = sawAlarmTag or source:lower():find("#alarm", 1, true) ~= nil
    if parsed.command then
      commandsBySource[source] = parsed.command
    end
    for _, key in ipairs(veafCombatZone.MERGED_TAGS) do
      local value = parsed[key]
      if value then
        if tags[key] == nil then
          tags[key] = value
          statedBy[key] = source
        elseif tags[key] ~= value then
          veaf.loggers.get(veafCombatZone.Id):warn(
            "group [%s]: [%s] sets %s to [%s] while [%s] already set it to [%s]; keeping [%s]",
            veaf.p(groupName),
            veaf.p(source),
            key,
            veaf.p(value),
            veaf.p(statedBy[key]),
            veaf.p(tags[key]),
            veaf.p(tags[key])
          )
        end
      end
    end
  end

  if not tags.alarmState and sawAlarmTag then
    -- the tag is there but no source produced a number out of it (`#alarm=`, `#alarm=x`, `#alarm=-1`):
    -- without this the group silently keeps the default and the typo is invisible
    veaf.loggers
      .get(veafCombatZone.Id)
      :warn("group [%s] carries an unreadable #alarm tag; expected #alarm=0, #alarm=1 or #alarm=2", veaf.p(groupName))
  end
  return tags, commandsBySource
end

--- The group an object found in a trigger zone belongs to.
--- @param unit DCS unit, static object or cargo
--- @return string group name, and true when the object is a static (which is its own group)
function veafCombatZone.getGroupNameOfUnit(unit)
  local objectCategory = Object.getCategory(unit)
  if objectCategory == 3 or objectCategory == 6 then -- 3 is static objects, 6 is cargo (a kind of static object)
    return unit:getName(), true
  end
  return unit:getGroup():getName(), false
end

-------------------------------------------------------------------------------------------------------------------------------------------------------------
-- VeafCombatZoneElement object
-------------------------------------------------------------------------------------------------------------------------------------------------------------
VeafCombatZoneElement = {}

function VeafCombatZoneElement:new(objectToCopy)
  local objectToCreate = objectToCopy or {} -- create object if user does not provide one
  setmetatable(objectToCreate, self)
  self.__index = self

  -- init the new object

  -- name
  objectToCreate.name = nil
  -- position on the map
  objectToCreate.position = nil
  -- if true, this is a simple dcs static
  objectToCreate.dcsStatic = false
  -- if true, this is a simple dcs group
  objectToCreate.dcsGroup = false
  -- if true, this is a VEAF command
  objectToCreate.veafCommand = nil
  --  coalition (0 = neutral, 1 = red, 2 = blue)
  objectToCreate.coalition = nil
  -- route, only for veaf commands (groups already have theirs)
  objectToCreate.route = nil
  -- spawn radius in meters (randomness introduced in the respawn mechanism)
  objectToCreate.spawnRadius = 0
  -- spawn chance in percent (xx chances in 100 that the unit is spawned - or the command run)
  objectToCreate.spawnChance = 100
  -- grouping elements (spawnGroup) so that a certain number (spawnCount) is guaranteed to spawn, by running the spawn random chance computation as often as necessary
  objectToCreate.spawnGroup = nil
  -- How many of a spawn group's elements are *guaranteed* to spawn, set with the `#spawncount=` tag,
  -- by running the spawn random chance computation as often as necessary.
  -- **nil means "not stated"**, and that is what tells `activate()` it has nothing to guarantee: the
  -- retries and the forced last draw are the promise a written `#spawncount` makes ("2 of these 4,
  -- granted"), so they must not fire for a count nobody asked for. Defaulting it to 1 here is exactly
  -- what made `#spawnchance` unable to deny a spawn: a lone element — the common case, since an
  -- element with no `#spawngroup` forms its own group — got nine random draws and then a forced one.
  -- The count still reads as 1 where it is used, so the cap itself is unchanged.
  objectToCreate.spawnCount = nil
  -- Alarm state applied to the spawned group (0 AUTO, 1 GREEN, 2 RED), set with the `#alarm=` tag.
  -- **nil means "not stated"**, which is what lets the state be chosen by the group's nature at spawn
  -- time. Defaulting it here would make a deliberate `#alarm=0` indistinguishable from silence.
  objectToCreate.alarmState = nil

  return objectToCreate
end

---
--- setters and getters
---

function VeafCombatZoneElement:setName(value)
  self.name = value
  return self
end

function VeafCombatZoneElement:getName()
  return self.name
end

function VeafCombatZoneElement:setPosition(value)
  self.position = value
  return self
end

function VeafCombatZoneElement:getPosition()
  return self.position
end

function VeafCombatZoneElement:setDcsStatic(value)
  self.dcsStatic = value
  return self
end

function VeafCombatZoneElement:isDcsStatic()
  return self.dcsStatic
end

function VeafCombatZoneElement:setDcsGroup(value)
  self.dcsGroup = value
  return self
end

function VeafCombatZoneElement:isDcsGroup()
  return self.dcsGroup
end

function VeafCombatZoneElement:setVeafCommand(value)
  self.veafCommand = value
  return self
end

function VeafCombatZoneElement:getVeafCommand()
  return self.veafCommand
end

function VeafCombatZoneElement:setRoute(value)
  self.route = value
  return self
end

function VeafCombatZoneElement:getRoute()
  return self.route
end

function VeafCombatZoneElement:setCoalition(value)
  self.coalition = value
  return self
end

function VeafCombatZoneElement:getCoalition()
  return self.coalition
end

function VeafCombatZoneElement:setSpawnRadius(value)
  self.spawnRadius = tonumber(value)
  return self
end

function VeafCombatZoneElement:getSpawnRadius()
  return self.spawnRadius
end

function VeafCombatZoneElement:setSpawnChance(value)
  self.spawnChance = tonumber(value)
  return self
end

function VeafCombatZoneElement:getSpawnChance()
  return self.spawnChance
end

function VeafCombatZoneElement:setSpawnGroup(value)
  self.spawnGroup = value
  return self
end

function VeafCombatZoneElement:getSpawnGroup()
  return self.spawnGroup
end

function VeafCombatZoneElement:setSpawnDelay(value)
  if type(value) ~= "number" then
    value = tonumber(value)
  end
  self.spawnDelay = value
  return self
end

function VeafCombatZoneElement:getSpawnDelay()
  return self.spawnDelay
end

function VeafCombatZoneElement:setSpawnCount(value)
  self.spawnCount = tonumber(value)
  return self
end

function VeafCombatZoneElement:getSpawnCount()
  return self.spawnCount
end

function VeafCombatZoneElement:setAlarmState(value)
  local alarmState = tonumber(value)
  -- an out-of-range or unparsable tag falls back to the default rather than reaching setOption -- and
  -- says so, because a silent fallback makes a typo indistinguishable from a deliberate AUTO
  if alarmState ~= 0 and alarmState ~= 1 and alarmState ~= 2 then
    veaf.loggers.get(veafCombatZone.Id):warn(
      "#alarm=%s is not one of 0 (AUTO), 1 (GREEN), 2 (RED); falling back to %s",
      veaf.p(value),
      veaf.p(veafCombatZone.DefaultAlarmState)
    )
    alarmState = veafCombatZone.DefaultAlarmState
  end
  self.alarmState = alarmState
  return self
end

function VeafCombatZoneElement:getAlarmState()
  return self.alarmState
end

--- Has this group somewhere to drive to?
--- More than one waypoint means it is meant to move, and "meant to move" is the whole reason AUTO
--- exists here (#290). A zone element only carries a route of its own when it is a `#command` fake
--- unit, so a native group's route is read from the mission, the same way the parser reads it.
--- Anything unreadable answers false: a group that fights when it should have driven is a visible
--- mistake, one that stays silent when it should have fired is not.
function VeafCombatZoneElement:isMobile()
  local route = self:getRoute()
  if not route then
    local name = self:getName()
    if not name then
      return false
    end
    -- The guard on MiST being loaded went with the port — `veaf.getGroupRoute` ships in the bundle, so
    -- it cannot be absent. The pcall stays: this runs while a zone is activating, and a route reader
    -- that raises would take the whole spawn down with it. Answering "not mobile" is the safe end of
    -- that trade, as the docstring above says.
    local ok, found = pcall(veaf.getGroupRoute, name)
    route = ok and found or nil
  end
  if type(route) ~= "table" then
    return false
  end
  local waypoints = 0
  for _ in pairs(route) do
    waypoints = waypoints + 1
  end
  return waypoints > 1
end

--- The alarm state to apply to this element's group when it spawns.
--- An explicit `#alarm=` tag wins; otherwise the group's nature decides — see the two
--- DefaultAlarmState* constants for why one global value could not serve both.
function VeafCombatZoneElement:resolveAlarmState()
  local stated = self:getAlarmState()
  if stated ~= nil then
    return stated
  end
  if self:isMobile() then
    return veafCombatZone.DefaultAlarmStateMobile
  end
  return veafCombatZone.DefaultAlarmStateStatic
end

---
--- other methods
---

--- Apply a group's collected tags to one of its zone elements.
--- Only the tags actually stated are applied, so an element keeps its own defaults otherwise.
--- Convert a numeric tag's raw text, which may be a range, into the number the element stores.
---
--- Goes through `veaf.getRandomizableNumeric` so `100-300` means in a tag what it means in a marker
--- command. Not optional plumbing: the setters convert with `tonumber`, which returns **nil** on
--- "100-300", and a nil `spawnRadius` raises where `spawnElement` compares it — a range reaching a
--- setter unconverted is a crash, not a wrong number.
---
--- The draw happens **here**, when tags are read, which is once per mission at `initialize`. Every
--- activation of the zone then uses the same value. Redrawing on each activation would be a different
--- feature, and a surprising one for a dispersion radius.
local function numericTag(value)
  if value == nil then
    return nil
  end
  return veaf.getRandomizableNumeric(value)
end

local function applyCollectedTags(element, tags)
  if tags.spawnRadius then
    element:setSpawnRadius(numericTag(tags.spawnRadius))
  end
  if tags.spawnChance then
    element:setSpawnChance(numericTag(tags.spawnChance))
  end
  if tags.spawnCount then
    element:setSpawnCount(numericTag(tags.spawnCount))
  end
  if tags.spawnGroup then
    element:setSpawnGroup(tags.spawnGroup)
  end
  if tags.spawnDelay then
    element:setSpawnDelay(numericTag(tags.spawnDelay))
  end
  if tags.alarmState then
    element:setAlarmState(tags.alarmState)
  end
end

--- Build the zone element of a `#command` object: a one-shot trigger running a VEAF command at the
--- object's position. The zone name is appended to the command so the interpreter can attribute what
--- it spawns back to the zone.
--- @param unit the object carrying the command
--- @param group the group it belongs to, as built by VeafCombatZone:initialize
--- @param tags the group's collected tags
--- @param command the raw command read out of the name
--- @param combatZoneName name of the combat zone, appended to the command
--- @return VeafCombatZoneElement
function veafCombatZone.buildCommandElement(unit, group, tags, command, combatZoneName)
  local element = VeafCombatZoneElement:new()
  element:setCoalition(unit:getCoalition())
  element:setPosition(unit:getPosition().p)
  element:setName(group.name)
  applyCollectedTags(element, tags)
  -- no dispersion default here, deliberately: the command runs *at this position*, so scattering it
  -- would move whatever the command spawns. `#spawnradius=` still applies if the mission maker wrote one.
  element:setVeafCommand(command .. ", czName " .. combatZoneName)
  element:setRoute(veaf.getGroupRoute(group.name))
  if not element:getSpawnGroup() then
    element:setSpawnGroup(group.name) -- default the spawn group to the group name
  end
  return element
end

--- The position a group is anchored on: its **unit 1**, not the first unit the zone happened to meet.
---
--- The two are not interchangeable, and that is the whole point. `mist.teleportToPoint` computes the
--- displacement as `newCoord - newGroupData.units[1]` (mist.lua:4470) — the *mission table's* unit 1 —
--- then applies it to every unit of the group. Hand it the position of any other unit and the
--- displacement silently carries the spacing between the two, translating the whole group by it.
---
--- The zone does meet units in editor order (`veaf.getUnitsNamesOfCoalition` and
--- `veaf.getUnitsInTriggerZone` both walk indexed loops), so this only bites when unit 1 is **filtered out**:
--- a group straddling the trigger zone's edge with its first unit outside. Then unit 2 arrives as "the
--- first one", and a convoy comes up a truck-length down the road from where it was drawn — with
--- `#spawnradius=0` written and no dispersion asked for.
---
--- Falls back on the unit it was handed when DCS cannot produce unit 1, since an element with no
--- position spawns nothing at all, which is worse than spawning thirty metres off.
---
--- @param unit the unit the caller had, used as the fallback
--- @param group the group, as built by VeafCombatZone:initialize
--- @return table a runtime vec3
function veafCombatZone.referencePositionOf(unit, group)
  if not group.isStatic then
    local dcsGroup = Group.getByName(group.name)
    local firstUnit = dcsGroup and dcsGroup:getUnit(1)
    if firstUnit then
      return firstUnit:getPosition().p
    end
    veaf.loggers
      .get(veafCombatZone.Id)
      :warn("group [%s] gave no unit 1; anchoring on [%s] instead", veaf.p(group.name), veaf.p(unit:getName()))
  end
  return unit:getPosition().p
end

--- Build the zone element of a group the zone spawns itself.
---
--- The dispersion default is decided from whether `#spawnradius=` was **written**, not from the value
--- the element happens to hold. Asking the element (`if not element:getSpawnRadius()`) is what killed
--- the default for three years: an element starts at 0, and `not 0` is false in Lua. Reading the tag's
--- presence is exact, and it leaves `#spawnradius=0` meaning "no dispersion" instead of being
--- indistinguishable from silence.
---
--- @param unit the group's first unit, which gives the element its position and coalition
--- @param group the group, as built by VeafCombatZone:initialize
--- @param tags the group's collected tags
--- @return VeafCombatZoneElement
function veafCombatZone.buildGroupElement(unit, group, tags)
  local element = VeafCombatZoneElement:new()
  element:setCoalition(unit:getCoalition())
  element:setPosition(veafCombatZone.referencePositionOf(unit, group))
  element:setName(group.name)
  applyCollectedTags(element, tags)
  if group.isStatic then
    element:setDcsStatic(true)
  else
    element:setDcsGroup(true)
  end
  if not tags.spawnRadius then
    local default = group.isStatic and veafCombatZone.DefaultSpawnRadiusForStatics or veafCombatZone.DefaultSpawnRadiusForUnits
    element:setSpawnRadius(default)
  end
  if not element:getSpawnGroup() then
    element:setSpawnGroup(group.name) -- default the spawn group to the group name
  end
  return element
end

-------------------------------------------------------------------------------------------------------------------------------------------------------------
-- VeafCombatZone object
-------------------------------------------------------------------------------------------------------------------------------------------------------------

VeafCombatZone = {}

function VeafCombatZone:new(objectToCopy)
  local objectToCreate = objectToCopy or {} -- create object if user does not provide one
  setmetatable(objectToCreate, self)
  self.__index = self

  -- init the new object

  -- zone name (human-friendly)
  objectToCreate.friendlyName = nil
  -- technical zone name (in the mission editor)
  objectToCreate.missionEditorZoneName = nil
  -- mission briefing
  objectToCreate.briefing = nil
  -- list of defined objectives
  objectToCreate.objectives = {}
  -- list of the elements defined in the zone
  objectToCreate.elements = {}
  objectToCreate.elementGroups = {}
  -- the trigger zone object
  objectToCreate.triggerZone = nil
  -- the zone center
  objectToCreate.zoneCenter = nil
  -- zone is active
  objectToCreate.active = false
  -- zone is a training zone
  objectToCreate.training = false
  -- display the remaining units
  objectToCreate.showUnitsList = true
  -- display the zone coordinates and weather
  objectToCreate.showZonePositionInfo = true
  -- zone is completable (i.e. disable it when all ennemies are dead)
  objectToCreate.completable = true
  -- rename the units of a respawned group sequentially (Group-1, Group-2, …). Useful on a finished
  -- map, in the way while debugging a `.miz`: the original unit name is gone (#289). Default true,
  -- which is what every mission built before 6.15.16 got.
  objectToCreate.renameUnitsSequentially = true
  -- set when the trigger zone's shape could not be read, so the zone is *unusable* rather than empty.
  -- A zone that cannot say what it holds must not announce that everything in it is dead.
  objectToCreate.unreadableTriggerZone = false
  -- coalition whose units must be destroyed for the zone to complete (1 = red, 2 = blue).
  -- Defaults to red: the players are blue and the zone holds the red opposition.
  objectToCreate.enemyCoalition = veafCombatZone.DEFAULT_ENEMY_COALITION
  -- coalition the F10 menu is restricted to; nil = derive it from enemyCoalition
  objectToCreate.radioMenuCoalition = nil
  -- DCS groups that have been spawned (for cleaning up later)
  objectToCreate.spawnedGroups = {}
  objectToCreate.delayedSpawners = {}
  -- Whether we want the combat zone to be added to populate the radio menu
  objectToCreate.enableRadioMenu = true
  -- Whether we want the combat zone to be cleaned when it is over
  objectToCreate.enableJunkCleanup = true
  -- whether the zone can be activated/deactivated by user via radio menu. If false, the zone won't be added to radio menu until activated
  objectToCreate.enableUserActivation = true
  -- whether we want to allow ground marking of the zone
  objectToCreate.enableSmokeAndFlare = true
  -- list of chained combat zones; this is are list of combat zones, that are activated randomly
  objectToCreate.chainedCombatZones = nil
  -- delay (in seconds) between the end of this combat zone and the start of the other; can be a randomizable numeric (e.g. "[1-5]")
  objectToCreate.chainedCombatZonesDelay = nil
  --- Radio menus
  objectToCreate.radioGroupName = nil
  objectToCreate.radioMenuPrefix = nil
  objectToCreate.radioParentPath = nil
  objectToCreate.radioMarkersPath = nil
  objectToCreate.radioTargetInfoPath = nil
  objectToCreate.radioRootPath = nil
  -- the watchdog function checks for zone objectives completion
  objectToCreate.watchdogFunctionId = nil
  -- "pop smoke" command reset function id
  objectToCreate.smokeResetFunctionId = nil
  -- "pop flare" command reset function id
  objectToCreate.flareResetFunctionId = nil
  -- function to call when combat zone is over. The function is passed self combat zone
  objectToCreate.onCompletedHook = nil

  return objectToCreate
end

---
--- setters and getters
---
function VeafCombatZone:setOnCompletedHook(onCompletedFunction)
  self.onCompletedHook = onCompletedFunction
  return self
end

function VeafCombatZone:disableRadioMenu()
  self.enableRadioMenu = false
  return self
end

function VeafCombatZone:disableJunkCleanup()
  self.enableJunkCleanup = false
  return self
end

-- make sure users cannot activate the zone (it won't be in the radio menu unless it's already active)
function VeafCombatZone:disableUserActivation()
  self.enableUserActivation = false
  return self
end

-- make sure users can activate the zone (it will be in the radio menu even if inactive - that's the default)
function VeafCombatZone:enableUserActivation()
  self.enableUserActivation = true
  return self
end

function VeafCombatZone:setEnableUserActivation(value)
  self.enableUserActivation = value
  return self
end

function VeafCombatZone:setEnableSmokeAndFlare(value)
  self.enableSmokeAndFlare = value
  return self
end

function VeafCombatZone:getRadioMenuName(asActive)
  local active = ""
  if asActive then
    active = "* "
  end
  local prefix = ""
  if self:getRadioMenuPrefix() then
    prefix = self:getRadioMenuPrefix() .. " "
  end
  return prefix .. active .. self:getFriendlyName()
end
function VeafCombatZone:setFriendlyName(value)
  self.friendlyName = value
  return self
end

function VeafCombatZone:getFriendlyName()
  return self.friendlyName
end

function VeafCombatZone:getRadioMenuPrefix()
  return self.radioMenuPrefix
end

function VeafCombatZone:setRadioMenuPrefix(value)
  self.radioMenuPrefix = value
  return self
end

function VeafCombatZone:setBriefing(value)
  self.briefing = value
  return self
end

function VeafCombatZone:getBriefing()
  return self.briefing
end

function VeafCombatZone:setMissionEditorZoneName(value)
  self.missionEditorZoneName = value
  return self
end

function VeafCombatZone:getMissionEditorZoneName()
  return self.missionEditorZoneName
end

function VeafCombatZone:isActive()
  return self.active
end

function VeafCombatZone:setActive(value)
  self.active = value
  return self
end

function VeafCombatZone:isTraining()
  return self.training
end

function VeafCombatZone:setTraining(value)
  self.training = value
  if value then
    self.showUnitsList = true
    self.showZonePositionInfo = true
  end
  return self
end

function VeafCombatZone:isShowUnitsList()
  return self.showUnitsList
end

function VeafCombatZone:setShowUnitsList(value)
  self.showUnitsList = value
  return self
end

function VeafCombatZone:isShowZonePositionInfo()
  return self.showZonePositionInfo
end

function VeafCombatZone:setShowZonePositionInfo(value)
  self.showZonePositionInfo = value
  return self
end

--- Can this zone complete on its own?
--- A zone whose trigger zone could not be read answers **no**, whatever the mission asked for: it does
--- not know what it holds, so it cannot honestly report that all of it is dead — which is the worst
--- symptom FIX-COMBATZONE-ZONE-TYPE-SILENT was about. It gates both the watchdog and the check itself.
function VeafCombatZone:isCompletable()
  return self.completable and not self.unreadableTriggerZone
end

function VeafCombatZone:hasUnreadableTriggerZone()
  return self.unreadableTriggerZone
end

function VeafCombatZone:setCompletable(value)
  self.completable = value
  return self
end

function VeafCombatZone:isRenameUnitsSequentially()
  return self.renameUnitsSequentially
end

--- Whether a respawned group's units are renamed sequentially.
--- Sharko's #289: renaming is useful once a map is finished and gets in the way while debugging a
--- `.miz`, since the original unit name is gone. Set it to false to keep the names.
function VeafCombatZone:setRenameUnitsSequentially(value)
  self.renameUnitsSequentially = value
  return self
end

-- set which coalition the zone treats as hostile: its units are the ones that must be
-- destroyed for the zone to complete, and the ones the F10 report calls "enemies".
-- Accepts a DCS side number (coalition.side.BLUE) or a "red"/"blue" string, because this is
-- called both from hand-written Lua and from the config generated out of mission.yaml.
function VeafCombatZone:setEnemyCoalition(value)
  local side = value
  if type(side) == "string" then
    local name = side:lower()
    side = (name == "red" and 1) or (name == "blue" and 2) or nil
  end
  -- Only RED and BLUE can be hostile. NEUTRAL (0) and any other side would leave the zone in
  -- a silently inconsistent state: getFriendlyCoalition() would still answer, the report's
  -- tally lookup would find nothing, and completion would fall back to counting reds.
  if side ~= 1 and side ~= 2 then
    veaf.loggers.get(veafCombatZone.Id):error(
      string.format(
        "VeafCombatZone[%s]:setEnemyCoalition() : [%s] is not RED or BLUE, keeping [%d]",
        veaf.p(self.missionEditorZoneName),
        veaf.p(value),
        self:getEnemyCoalition()
      )
    )
    return self
  end
  self.enemyCoalition = side
  return self
end

function VeafCombatZone:getEnemyCoalition()
  return self.enemyCoalition or veafCombatZone.DEFAULT_ENEMY_COALITION
end

-- the other side of getEnemyCoalition(): whoever the zone is played by
function VeafCombatZone:getFriendlyCoalition()
  if self:getEnemyCoalition() == 2 then
    return 1
  end
  return 2
end

-- restrict (or not) the zone's F10 menu to one coalition. The menu is not read-only — it is
-- how a zone is activated — so by default it goes to the side playing the zone. Accepts a side
-- number, "red"/"blue", or "all" to show it to everyone as it was before
-- FEAT-COMBATZONE-MENU-COALITION.
function VeafCombatZone:setRadioMenuCoalition(value)
  local side = value
  if type(side) == "string" then
    local name = side:lower()
    if name == "all" then
      self.radioMenuCoalition = veafCombatZone.RADIO_MENU_FOR_ALL
      return self
    end
    side = (name == "red" and 1) or (name == "blue" and 2) or nil
  end
  if side ~= 1 and side ~= 2 then
    veaf.loggers.get(veafCombatZone.Id):error(
      string.format(
        "VeafCombatZone[%s]:setRadioMenuCoalition() : [%s] is not RED, BLUE or ALL, keeping the default",
        veaf.p(self.missionEditorZoneName),
        veaf.p(value)
      )
    )
    return self
  end
  self.radioMenuCoalition = side
  return self
end

-- the coalition the zone's F10 menu is shown to, or nil for everyone
function VeafCombatZone:getRadioMenuCoalition()
  if self.radioMenuCoalition == veafCombatZone.RADIO_MENU_FOR_ALL then
    return nil
  end
  return self.radioMenuCoalition or self:getFriendlyCoalition()
end

function VeafCombatZone:getTriggerZone()
  return self.triggerZone
end

function VeafCombatZone:getCenter()
  return self.zoneCenter
end

function VeafCombatZone:setRadioParentPath(value)
  self.radioParentPath = value
  return self
end

function VeafCombatZone:getRadioParentPath()
  return self.radioParentPath
end

function VeafCombatZone:setRadioGroupName(value)
  self.radioGroupName = value
  return self
end

function VeafCombatZone:getRadioGroupName()
  return self.radioGroupName
end

function VeafCombatZone:addSpawnedGroup(groupOrName)
  local groupName = groupOrName
  if type(groupName) ~= "string" then
    groupName = tostring(groupName)
  end
  veaf.loggers
    .get(veafCombatZone.Id)
    :trace(string.format("VeafCombatZone[%s]:addSpawnedGroup(%s)", veaf.p(self.missionEditorZoneName), veaf.p(groupName)))
  if not self.spawnedGroups then
    self.spawnedGroups = {}
  end
  table.insert(self.spawnedGroups, groupName)
  return self
end

function VeafCombatZone:getSpawnedGroups()
  veaf.loggers.get(veafCombatZone.Id):trace(string.format("VeafCombatZone[%s]:getSpawnedGroups()", veaf.p(self.missionEditorZoneName)))
  veaf.loggers.get(veafCombatZone.Id):trace(veaf.serialize("self.spawnedGroups", self.spawnedGroups))
  return self.spawnedGroups
end

function VeafCombatZone:clearSpawnedGroups()
  self.spawnedGroups = {}
  return self
end

function VeafCombatZone:addDelayedSpawner(id)
  veaf.loggers.get(veafCombatZone.Id):trace("VeafCombatZone[%s]:addDelayedSpawner(%s)", veaf.lp(self.missionEditorZoneName), veaf.lp(id))
  if not self.delayedSpawners then
    self.delayedSpawners = {}
  end
  table.insert(self.delayedSpawners, id)
  return self
end

function VeafCombatZone:getDelayedSpawners()
  veaf.loggers.get(veafCombatZone.Id):trace("VeafCombatZone[%s]:getDelayedSpawners()", veaf.lp(self.missionEditorZoneName))
  veaf.loggers.get(veafCombatZone.Id):trace("self.delayedSpawners=%s", self.delayedSpawners)
  return self.delayedSpawners
end

function VeafCombatZone:clearDelayedSpawners()
  self.delayedSpawners = {}
  return self
end

--- Fold one element's stated `#spawncount` into the spawn group it joins.
---
--- A spawn group is a **set** of elements, and its count belongs to the set, not to whichever element
--- happened to create it. Reading it from that first element alone meant `#spawncount=2` written on
--- the second unit of a `#spawngroup` was dropped without a word — and since FIX-COMBATZONE-SPAWNCHANCE
--- an absent count is `nil`, which is what tells `activate()` there is nothing to guarantee, so losing
--- one changes how many groups come up, not merely the bookkeeping.
---
--- **The highest stated count wins.** Two reasons, in this order:
--- * the defect being fixed *is* order-dependence, and "the last one written" would only move it — the
---   order elements are added in is editor order, which the mission maker never chose;
--- * a `#spawncount` is a guarantee ("2 of these 4, granted"), so the larger of two promises is the one
---   that keeps both.
---
--- A group with no count stated anywhere keeps `nil`, and two elements stating the same number are not
--- a conflict — only a real disagreement is reported.
local function mergeSpawnCountInto(elementGroup, element, zoneName)
  local stated = element:getSpawnCount()
  if stated == nil then
    return
  end
  local current = elementGroup.spawnCount
  if current == nil or current == stated then
    elementGroup.spawnCount = stated
    return
  end
  local kept = math.max(current, stated)
  veaf.loggers
    .get(veafCombatZone.Id)
    :info(veaf.t("combatzone.spawncount_conflict", veaf.p(zoneName), veaf.p(elementGroup.spawnGroup), current, stated, kept))
  elementGroup.spawnCount = kept
end

function VeafCombatZone:addZoneElement(element)
  veaf.loggers
    .get(veafCombatZone.Id)
    :trace(string.format("VeafCombatZone[%s]:addZoneElement(%s)", veaf.p(self.missionEditorZoneName), veaf.p(element:getName())))
  if not self.elements then
    self.elements = {}
  end
  if not self.elementGroups then
    self.elementGroups = {}
  end
  table.insert(self.elements, element)
  if not self.elementGroups[element:getSpawnGroup()] then
    local newGroup = {}
    newGroup.spawnGroup = element:getSpawnGroup()
    newGroup.spawnCount = nil -- stays nil until an element states one; see mergeSpawnCountInto
    newGroup.elements = {}
    self.elementGroups[element:getSpawnGroup()] = newGroup
  end
  local elementGroup = self.elementGroups[element:getSpawnGroup()]
  table.insert(elementGroup.elements, element)
  mergeSpawnCountInto(elementGroup, element, self:getMissionEditorZoneName())
  return self
end

function VeafCombatZone:addZoneElementsFromZoneNamed(zoneName)
  veaf.loggers
    .get(veafCombatZone.Id)
    :trace(string.format("VeafCombatZone[%s]:addZoneElementsFromZoneNamed(%s)", veaf.p(self.missionEditorZoneName), veaf.p(zoneName)))
  if not zoneName then
    return self
  end
  local zone = veafCombatZone.GetZone(zoneName)
  if not zone then
    return self
  end
  local elements = zone:getZoneElements()
  if not elements then
    return self
  end
  for _, element in pairs(elements) do
    self:addZoneElement(element)
  end
  return self
end

function VeafCombatZone:getZoneElements()
  veaf.loggers.get(veafCombatZone.Id):trace(string.format("VeafCombatZone[%s]:getZoneElement()", veaf.p(self.missionEditorZoneName)))
  veaf.loggers.get(veafCombatZone.Id):trace(veaf.serialize("self.elements", self.elements))
  return self.elements
end

function VeafCombatZone:getZoneElementsGroups()
  veaf.loggers.get(veafCombatZone.Id):trace(string.format("VeafCombatZone[%s]:getZoneElementsGroups()", veaf.p(self.missionEditorZoneName)))
  return self.elementGroups
end

-- get the list of chained combat zones; this is are list of combat zones, that are activated randomly
function VeafCombatZone:getChainedCombatZones()
  if not self.chainedCombatZones then
    veaf.loggers
      .get(veafCombatZone.Id)
      :trace(string.format("VeafCombatZone[%s]:getChainedCombatZones() - Initializing", veaf.p(self.missionEditorZoneName)))
    self.chainedCombatZones = {}
  end
  veaf.loggers.get(veafCombatZone.Id):trace(
    string.format("VeafCombatZone[%s]:getChainedCombatZones() = %s", veaf.p(self.missionEditorZoneName), veaf.p(self.chainedCombatZones))
  )
  return self.chainedCombatZones
end

-- add a chained combat zone (by name); the zone does not have to exist at the time the function is called
function VeafCombatZone:addChainedCombatZone(combatZoneName)
  veaf.loggers
    .get(veafCombatZone.Id)
    :trace(string.format("VeafCombatZone[%s]:addChainedCombatZone([%s])", veaf.p(self.missionEditorZoneName), veaf.p(combatZoneName)))
  table.insert(self:getChainedCombatZones(), combatZoneName)
  return self
end

-- get the next chained combat zone; if the list is more than 1 zone long, get one at random
function VeafCombatZone:getNextChainedCombatZone()
  local nextZoneName = veaf.randomlyChooseFrom(self:getChainedCombatZones())
  veaf.loggers
    .get(veafCombatZone.Id)
    :trace(string.format("VeafCombatZone[%s]:getNextChainedCombatZone() = [%s]", veaf.p(self.missionEditorZoneName), veaf.p(nextZoneName)))
  return nextZoneName
end

-- get the delay (in seconds) between the end of this combat zone and the start of the other; if the set value was a randomizable numeric, randomize it
function VeafCombatZone:getChainedCombatZonesDelay()
  return veaf.getRandomizableNumeric(self.chainedCombatZonesDelay or 0)
end

-- set the delay (in seconds) between the end of this combat zone and the start of the other; can be a randomizable numeric (e.g. "1-5")
function VeafCombatZone:setChainedCombatZonesDelay(value)
  veaf.loggers
    .get(veafCombatZone.Id)
    :trace(string.format("VeafCombatZone[%s]:setChainedCombatZonesDelay([%s])", veaf.p(self.missionEditorZoneName), veaf.p(value)))
  if not value then
    value = 0
  end
  self.chainedCombatZonesDelay = value
  return self
end

---
--- other methods
---
function VeafCombatZone:scheduleWatchdogFunction()
  veaf.loggers
    .get(veafCombatZone.Id)
    :trace(string.format("VeafCombatZone[%s]:scheduleWatchdogFunction()", veaf.p(self.missionEditorZoneName)))
  if self:isCompletable() then
    self.watchdogFunctionId = veaf.scheduleFunction(
      veafCombatZone.CompletionCheck,
      { self.missionEditorZoneName },
      timer.getTime() + veafCombatZone.SecondsBetweenWatchdogChecks
    )
  end
  return self
end

function VeafCombatZone:unscheduleWatchdogFunction()
  veaf.loggers
    .get(veafCombatZone.Id)
    :trace(string.format("VeafCombatZone[%s]:unscheduleWatchdogFunction()", veaf.p(self.missionEditorZoneName)))
  if self.watchdogFunctionId then
    veaf.removeFunction(self.watchdogFunctionId)
  end
  self.watchdogFunctionId = nil
  return self
end

function VeafCombatZone:addObjective(value)
  table.insert(self.objectives, value)
  return self
end

function VeafCombatZone:addDefaultObjectives()
  -- TODO
  return self
end

function VeafCombatZone:initialize()
  veaf.loggers.get(veafCombatZone.Id):debug(string.format("VeafCombatZone[%s]:initialize()", veaf.p(self.missionEditorZoneName)))

  -- check parameters
  if not self.missionEditorZoneName then
    return self
  else
    self.triggerZone = veaf.getTriggerZone(self.missionEditorZoneName)
    if not self.triggerZone then
      local message = string.format("Trigger zone [%s] does not exist in the mission !", veaf.p(self.missionEditorZoneName))
      veaf.loggers.get(veafCombatZone.Id):error(message)
      trigger.action.outText(veaf.t("combatzone.zone_not_in_mission", veaf.p(self.missionEditorZoneName)), 5)
      return self
    end
  end
  if not self.friendlyName then
    self:setFriendlyName(self.missionEditorZoneName)
  end
  if #self.objectives == 0 then
    self:addDefaultObjectives()
  end

  -- find the trigger zone center
  self.zoneCenter = veaf.zoneToVec3(self.missionEditorZoneName)
  if not self.zoneCenter then
    local message = string.format("Trigger zone [%s] does not exist in the mission !", veaf.p(self.missionEditorZoneName))
    veaf.loggers.get(veafCombatZone.Id):error(message)
    trigger.action.outText(veaf.t("combatzone.zone_not_in_mission", veaf.p(self.missionEditorZoneName)), 5)
    return self
  end
  veaf.loggers.get(veafCombatZone.Id):trace(string.format("zone center = [%s]", veaf.vecToString(self.zoneCenter)))

  -- find units in the trigger zone
  local units, excludedGroupNames
  units, _, excludedGroupNames = veaf.safeUnpack(self:findUnitsInCombatZone())

  -- and say what the prefix rule turned down, once, before anything else happens: this is the only
  -- moment the zone knows what it saw and did not take
  self:reportGroupsExcludedByName(excludedGroupNames)

  -- Group what was found, keeping the order the units were met in. The element's **coalition** comes
  -- from the first of those units, as it always has — every unit of a group shares it. Its
  -- **position** does not: see veafCombatZone.referencePositionOf, which anchors on the group's unit 1
  -- whether or not the zone could see it.
  local groupsByName = {}
  local groupOrder = {}
  for _, unit in pairs(units) do
    local groupName, isStatic = veafCombatZone.getGroupNameOfUnit(unit)
    local group = groupsByName[groupName]
    if not group then
      group = { name = groupName, isStatic = isStatic, units = {}, unitNames = {} }
      groupsByName[groupName] = group
      table.insert(groupOrder, groupName)
    end
    table.insert(group.units, unit)
    table.insert(group.unitNames, unit:getName())
  end

  -- Build the zone elements, one per group plus one per `#command` object. A group's tags are
  -- collected from every name that carries one, so a tag on the second truck of a convoy counts as
  -- much as one on the first — which is what FIX-COMBATZONE-TAGS-FIRST-UNIT-ONLY was about.
  for _, groupName in ipairs(groupOrder) do
    local group = groupsByName[groupName]
    local tags, commandsBySource = veafCombatZone.collectTags(groupName, group.unitNames)
    veaf.loggers.get(veafCombatZone.Id):trace("processing group [%s] (%s units)", veaf.p(groupName), veaf.p(#group.units))

    local groupCommand = commandsBySource[groupName]
    if groupCommand then
      -- the command is on the group's own name, so the group is one trigger and not one per unit
      self:addZoneElement(veafCombatZone.buildCommandElement(group.units[1], group, tags, groupCommand, self:getMissionEditorZoneName()))
    else
      local plainUnits = {}
      for _, unit in ipairs(group.units) do
        local unitCommand = commandsBySource[unit:getName()]
        if unitCommand then
          -- it's a fake unit transporting a VEAF command
          self:addZoneElement(veafCombatZone.buildCommandElement(unit, group, tags, unitCommand, self:getMissionEditorZoneName()))
        else
          table.insert(plainUnits, unit)
        end
      end
      if #plainUnits > 0 then
        -- it's a group or a static unit
        self:addZoneElement(veafCombatZone.buildGroupElement(plainUnits[1], group, tags))
      end
    end
  end

  -- deactivate the zone
  veaf.loggers.get(veafCombatZone.Id):trace("desactivate the zone")
  self:desactivate()

  -- remove all units in the trigger zone (we want it CLEAN !)
  local _, groupNames = veaf.safeUnpack(self:findUnitsInCombatZone())
  if groupNames then
    for _, groupName in pairs(groupNames) do
      veaf.loggers.get(veafCombatZone.Id):trace(string.format("destroying group [%s]", groupName))
      ---@type Group|StaticObject|nil
      local group = Group.getByName(groupName)
      if not group then
        group = StaticObject.getByName(groupName)
      end
      if group then
        group:destroy()
      end
    end
  end
  return self
end

function VeafCombatZone:getInformation(unitName)
  veaf.loggers.get(veafCombatZone.Id):trace(string.format("VeafCombatZone[%s]:getInformation()", veaf.p(self.missionEditorZoneName)))
  local message = veaf.t("combatzone.header", self:getFriendlyName())
  if self:getBriefing() then
    message = message .. veaf.t("report.briefing_label")
    message = message .. self:getBriefing()
    message = message .. "\n\n"
  end
  if self:isActive() then
    -- generate information dispatch
    local nbShipsR = 0
    local nbVehiclesR = 0
    local nbInfantryR = 0
    local nbStaticsR = 0
    local nbShipsB = 0
    local nbVehiclesB = 0
    local nbInfantryB = 0
    local nbStaticsB = 0
    local unitsByTypeR = {}
    local unitsByTypeB = {}
    -- FEAT-GROUP-COMBAT-INEFFECTIVE: groups that still exist but can no longer fight. The first adopter
    -- of `veaf.isGroupCombatEffective`, chosen because it *adds* information and removes none — no
    -- mission behaviour changes, unlike adopting it in completionCheck (see the lot's PRD).
    local outOfActionGroups = {}

    for _, groupName in pairs(self:getSpawnedGroups()) do
      local group = Group.getByName(groupName)
      if group then
        -- A group with nothing left is **destroyed**, not "out of action", and the predicate answers
        -- false for both — so the living-unit check is what tells them apart. Naming a wiped-out group
        -- here would be noise on every report for the rest of the mission.
        if #group:getUnits() > 0 and not veaf.isGroupCombatEffective(group) then
          table.insert(outOfActionGroups, groupName)
        end
        for _, u in pairs(group:getUnits()) do
          local coa = u:getCoalition()
          if Object.getCategory(u) == 3 then
            if coa == 1 then
              nbStaticsR = nbStaticsR + 1
            elseif coa == 2 then
              nbStaticsB = nbStaticsB + 1
            end
          else
            local typeName = u:getTypeName()
            if typeName then
              local unit = veafUnits.findUnit(typeName)
              if unit then
                if coa == 1 then
                  if not unitsByTypeR[typeName] then
                    unitsByTypeR[typeName] = 0
                  end
                  unitsByTypeR[typeName] = unitsByTypeR[typeName] + 1
                  if unit.vehicle then
                    nbVehiclesR = nbVehiclesR + 1
                  elseif unit.naval then
                    nbShipsR = nbShipsR + 1
                  else
                    nbInfantryR = nbInfantryR + 1
                  end
                elseif coa == 2 then
                  if not unitsByTypeB[typeName] then
                    unitsByTypeB[typeName] = 0
                  end
                  unitsByTypeB[typeName] = unitsByTypeB[typeName] + 1
                  if unit.vehicle then
                    nbVehiclesB = nbVehiclesB + 1
                  elseif unit.naval then
                    nbShipsB = nbShipsB + 1
                  else
                    nbInfantryB = nbInfantryB + 1
                  end
                end
              end
            end
          end
        end
      end
    end

    -- The tallies above are per real coalition; which one reads as "friends" and which as
    -- "enemies" depends on the side the zone is played from (setEnemyCoalition).
    local tallies = {
      [1] = {
        ships = nbShipsR,
        statics = nbStaticsR,
        vehicles = nbVehiclesR,
        infantry = nbInfantryR,
        byType = unitsByTypeR,
      },
      [2] = {
        ships = nbShipsB,
        statics = nbStaticsB,
        vehicles = nbVehiclesB,
        infantry = nbInfantryB,
        byType = unitsByTypeB,
      },
    }

    local function appendTally(side, messageKey)
      local tally = tallies[side]
      if not tally then
        return
      end
      if tally.ships + tally.statics + tally.vehicles + tally.infantry > 0 and self:isShowUnitsList() then
        local msgs = {}
        if tally.ships > 0 then
          table.insert(msgs, veaf.t("report.count_ships", tally.ships))
        end
        if tally.statics > 0 then
          table.insert(msgs, veaf.t("report.count_structures", tally.statics))
        end
        if tally.vehicles > 0 then
          table.insert(msgs, veaf.t("report.count_vehicles", tally.vehicles))
        end
        if tally.infantry > 0 then
          table.insert(msgs, veaf.t("report.count_soldiers", tally.infantry))
        end
        message = message .. veaf.t(messageKey, table.concat(msgs, ","))
        if self:isTraining() then
          local firstUnit = true
          for name, count in pairs(tally.byType) do
            local separator = ", "
            if firstUnit then
              separator = ""
              firstUnit = false
            end
            message = message .. string.format("%s%d %s", separator, count, name)
          end
          message = message .. "\n"
        end
      end
    end

    appendTally(self:getFriendlyCoalition(), "combatzone.friends")
    appendTally(self:getEnemyCoalition(), "combatzone.enemies")
    if #outOfActionGroups > 0 and self:isShowUnitsList() then
      table.sort(outOfActionGroups) -- a stable order: `getSpawnedGroups` is not one a player can predict
      message = message .. veaf.t("combatzone.out_of_action", table.concat(outOfActionGroups, ", "))
    end
    message = message .. "\n"

    if self:isShowZonePositionInfo() then
      -- add coordinates and position from bullseye
      local zoneCenter = self:getCenter()
      local lat, lon = coord.LOtoLL(zoneCenter)
      local mgrsString = veaf.toStringMGRS(coord.LLtoMGRS(lat, lon), 3)
      local bullseyeData = veaf.getBullseye("blue") -- default to blue
      if unitName then
        local requestingUnit = Unit.getByName(unitName)
        if requestingUnit and requestingUnit:getCoalition() == coalition.side.RED then
          bullseyeData = veaf.getBullseye("red")
        end
      end
      local bullseye = veaf.makeVec3(bullseyeData, 0)
      local vec = { x = zoneCenter.x - bullseye.x, y = zoneCenter.y - bullseye.y, z = zoneCenter.z - bullseye.z }
      local dir = veaf.round(math.deg(veaf.getDir(vec, bullseye)), 0)
      local dist = veaf.get2DDist(zoneCenter, bullseye)
      local distMetric = veaf.round(dist / 1000, 0)
      local distImperial = veaf.round(veaf.metersToNM(dist), 0)
      local fromBullseye = veaf.t("report.bullseye_value", dir, distMetric, distImperial)

      message = message .. veaf.t("report.latlon_decimal", veaf.toStringLL(lat, lon, 2))
      message = message .. veaf.t("report.latlon_dms", veaf.toStringLL(lat, lon, 0, true))
      message = message .. veaf.t("report.mgrs", mgrsString)
      message = message .. veaf.t("report.from_bullseye", fromBullseye)
      message = message .. "\n"

      -- get altitude, qfe and wind information
      message = message
        .. veaf.t("report.weather_header")
        .. veafWeatherData.getWeatherString(zoneCenter, nil, veafWeatherUnitSystem.Systems.Full)
    end
  else
    message = message .. veaf.t("combatzone.not_active")
  end

  return message
end

--- Destroy one group (or static) this zone spawned.
-- Extracted from desactivate() because the deferred-command hook needs the same operation: a group
-- that appears *after* its zone was deactivated has to be destroyed rather than registered, which is
-- what the deactivation would have done to it had it existed in time.
function VeafCombatZone:destroySpawnedGroup(groupName)
  veaf.loggers.get(veafCombatZone.Id):trace(string.format("trying to destroy group [%s]", groupName))
  ---@type Group|StaticObject|nil
  local group = Group.getByName(groupName)
  if not group then
    group = StaticObject.getByName(groupName)
    if group then
      veaf.loggers.get(veafCombatZone.Id):trace(string.format("found static [%s]", group:getName()))
    else
      veaf.loggers.get(veafCombatZone.Id):info(string.format("cannot find static [%s]", groupName))
    end
  end
  if group then
    veaf.loggers.get(veafCombatZone.Id):trace(string.format("destroying group [%s]", group:getName()))
    group:destroy()
  end
end

--- The surfaces a zone element's naval category may stand on, or nil to keep
--- `veaf.findSpawnPoint`'s own land-only default unchanged for anything else.
-- Read from `veafDcsSpawner.TERRAIN_BY_CATEGORY`, the same table the terrain check downstream
-- already uses, so "what can this thing stand on" has one source instead of two that can disagree.
local function surfacesForZoneElement(zoneElement)
  local record = veaf.getGroupRecord(zoneElement:getName())
  local category = record and record.category
  if category and string.lower(category) == "ship" then
    return veafDcsSpawner.TERRAIN_BY_CATEGORY.ship
  end
  return nil
end

function VeafCombatZone:spawnElement(zoneElement, now)
  veaf.loggers
    .get(veafCombatZone.Id)
    :debug("VeafCombatZone[%s]:spawnElement([%s], [%s])", veaf.lp(self:getFriendlyName()), veaf.lp(zoneElement:getName()), veaf.lp(now))
  veaf.loggers.get(veafCombatZone.Id):trace("zoneElement=%s", zoneElement)
  if not now and zoneElement:getSpawnDelay() and type(zoneElement:getSpawnDelay()) == "number" then
    -- self-schedule
    veaf.loggers
      .get(veafCombatZone.Id)
      :trace("scheduling spawn of zoneElement=%s in %s seconds", zoneElement:getName(), zoneElement:getSpawnDelay())
    local id =
      veaf.scheduleFunction(VeafCombatZone.spawnElement, { self, zoneElement, true }, timer.getTime() + zoneElement:getSpawnDelay())
    self:addDelayedSpawner(id)
  else
    -- spawn now
    veaf.loggers.get(veafCombatZone.Id):trace("spawning zoneElement=%s now", zoneElement:getName())
    local position = zoneElement:getPosition()
    if zoneElement:getSpawnRadius() > 0 then
      veaf.loggers.get(veafCombatZone.Id):trace(string.format("position=[%s]", veaf.vecToString(position)))
      veaf.loggers.get(veafCombatZone.Id):trace(string.format("spawnRadius=[%s]", zoneElement:getSpawnRadius()))
      -- The draw used to be used unvalidated, so a dispersed element could be placed in a
      -- building, a forest or the sea in silence — `veaf.placePointOnLand` only writes the
      -- terrain height. `veaf.findSpawnPoint` validates the point and prefers one clear of
      -- scenery. It returns a **vec3**, so the easting reads as `z`; this call site used to read
      -- MiST's vec2 `y` for it, which is the confusion docs/agents/dcs-coordinates.md warns about.
      --
      -- On failure the element keeps its **declared** position instead of being skipped: a zone
      -- element is editor content, and the mission maker who declared it is not in the room when
      -- the mission loads, so a partially built zone would be worse than an imperfect one.
      -- Refusing is for what a command spawns (David, 2026-08-27), and per ADR 0018 the scenery
      -- criterion is quality-only, never correctness.
      local found = veaf.findSpawnPoint(position, zoneElement:getSpawnRadius(), nil, surfacesForZoneElement(zoneElement))
      if found then
        veaf.loggers.get(veafCombatZone.Id):trace(string.format("found=[%s]", veaf.vecToString(found)))
        position = { x = found.x, y = position.y, z = found.z }
      else
        veaf.loggers.get(veafCombatZone.Id):info(
          string.format(
            "spawnElement: no acceptable spawn point within %sm of [%s], keeping its declared position",
            tostring(zoneElement:getSpawnRadius()),
            tostring(zoneElement:getName())
          )
        )
      end
    end
    if zoneElement:isDcsStatic() or zoneElement:isDcsGroup() then
      veaf.loggers
        .get(veafCombatZone.Id)
        :trace(string.format("respawning group [%s] at position [%s]", zoneElement:getName(), veaf.vecToString(position)))
      local newGroupName = veaf.getNameForSpawnedGroup(zoneElement:getCoalition(), zoneElement:getName(), self:getMissionEditorZoneName())
      -- The group's first waypoint follows the group. MiST translates a route by the teleport delta
      -- only when asked (mist.lua:4561), and nothing here asked, so a scattered group came up beside
      -- a waypoint 1 still at its editor position and drove back to it before starting its leg.
      --
      -- `offsetWP1`, not `offsetRoute`: the delta is a *local, random* displacement around the drawn
      -- position, so translating the whole route by it would move waypoints the mission maker placed
      -- on roads, bridges and passes, and would draw a different track on every activation. Waypoint 1
      -- is not a design choice — it is where the group starts — so it is the one that must move.
      --
      -- Unconditional, including when spawnRadius is 0: the delta is *not* only the dispersion. MiST
      -- measures it against the mission table's unit 1, while the element's position comes from the
      -- first unit the zone happened to meet (see buildGroupElement), so a group whose units were not
      -- met in editor order carries a delta of its own intra-group spacing.
      local newGroup = VeafGroupSpawn:new()
        :forGroup(zoneElement:getName())
        :named(newGroupName)
        :at(position)
        :withRoute(zoneElement:getRoute())
        :renamingUnitsSequentially(self:isRenameUnitsSequentially())
        :offsettingFirstWaypoint()
        :respawn()
      if type(newGroup) == "table" then
        veaf.loggers
          .get(veafCombatZone.Id)
          :trace(string.format("[%s]:activate() - VeafGroupSpawn([%s])", self:getMissionEditorZoneName(), zoneElement:getName()))
        self:addSpawnedGroup(newGroup.name)
        -- resolveAlarmState, not getAlarmState: the state is decided here, from the group's nature,
        -- unless its unit name stated one. A single default served the convoys of #290 and silenced
        -- every SAM battery in a combat zone (PR #762).
        veaf.readyForCombat(newGroup.name, zoneElement:resolveAlarmState())
      else
        veaf.loggers
          .get(veafCombatZone.Id)
          :trace(string.format("[%s]:activate() - VeafGroupSpawn([%s]) failed", self:getMissionEditorZoneName(), zoneElement:getName()))
      end
    elseif zoneElement:getVeafCommand() then
      veaf.loggers
        .get(veafCombatZone.Id)
        :trace(string.format("executing command [%s] at position [%s]", zoneElement:getVeafCommand(), veaf.vecToString(position)))
      -- #66: registering a hook instead of iterating the table after the call. A command carrying a
      -- delay (`-samsr!30`, or a `delay` option, or repeats) returns *before* it spawns anything, so
      -- the table this used to read was still empty and the group ended up registered nowhere — which
      -- meant desactivate() could not destroy it and the SAM outlived its zone. The hook fires whether
      -- the group appears now or in thirty seconds.
      local spawnedGroups = {}
      veaf.registerSpawnedGroupsHook(spawnedGroups, function(newGroup)
        -- The zone may have been deactivated while the command was waiting out its delay. Nothing can
        -- unschedule that deferred spawn — desactivate() only knows about its own `#spawndelay`
        -- schedules — so the group is destroyed here instead of being registered with a zone that is
        -- no longer running.
        if not self:isActive() then
          veaf.loggers
            .get(veafCombatZone.Id)
            :debug(string.format("[%s] spawned [%s] after its zone was deactivated, destroying it", zoneElement:getName(), newGroup))
          self:destroySpawnedGroup(newGroup)
          return
        end
        veaf.loggers.get(veafCombatZone.Id):trace(string.format("[%s].addSpawnedGroup", zoneElement:getName()))
        self:addSpawnedGroup(newGroup)
        veaf.loggers.get(veafCombatZone.Id):trace(string.format("newGroup = [%s]", newGroup))
        local route = zoneElement:getRoute()
        veaf.loggers.get(veafCombatZone.Id):trace(string.format("got route"))
        veaf.goRoute(newGroup, route)
        veaf.loggers.get(veafCombatZone.Id):trace(string.format("sent group on its way"))
      end)
      veafInterpreter.execute(zoneElement:getVeafCommand(), position, zoneElement:getCoalition(), nil, spawnedGroups)
    end
  end
end

-- activate the zone
function VeafCombatZone:activate()
  veaf.loggers.get(veafCombatZone.Id):trace(string.format("VeafCombatZone[%s]:activate()", self:getMissionEditorZoneName()))
  self:setActive(true)

  for _, zoneElementGroup in pairs(self:getZoneElementsGroups()) do
    veaf.loggers.get(veafCombatZone.Id):trace(string.format("processing spawnGroup [%s]", zoneElementGroup.spawnGroup))
    -- A `#spawncount` the mission maker wrote is a promise of a number — "2 of these 4, granted" — and
    -- the retries below, forcing the draw on the last one, are what keeps it. Left unstated it is nil,
    -- there is nothing to guarantee, and a single pass gives each element exactly one draw against its
    -- own `#spawnchance`. That is what makes the percentage mean what it says: ten tries at 50 % spawn
    -- 999 times in 1000, so retrying denied the chance just as surely as forcing it did.
    -- The count still reads as 1, so a `#spawngroup` with no `#spawncount` goes on capping at one.
    local statedSpawnCount = zoneElementGroup.spawnCount
    local spawnCount = statedSpawnCount or 1
    veaf.loggers.get(veafCombatZone.Id):trace(string.format("spawnCount = [%d] (stated = %s)", spawnCount, veaf.p(statedSpawnCount)))
    local tries = statedSpawnCount and 10 or 1
    local alreadySpawnedElements = {}
    local shuffledIndexes = {}
    for i = 1, #zoneElementGroup.elements do
      local zoneElement = zoneElementGroup.elements[i]
      alreadySpawnedElements[zoneElement:getName()] = false
      table.insert(shuffledIndexes, i)
    end
    veaf.shuffle(shuffledIndexes)
    while spawnCount > 0 and tries > 0 do
      veaf.loggers.get(veafCombatZone.Id):trace(string.format("tries = [%d]", tries))
      tries = tries - 1

      for i = 1, #shuffledIndexes do
        local zoneElement = zoneElementGroup.elements[shuffledIndexes[i]]
        veaf.loggers.get(veafCombatZone.Id):trace(string.format("processing element [%s]", veaf.p(zoneElement)))
        if spawnCount > 0 then
          if not alreadySpawnedElements[zoneElement:getName()] then
            veaf.loggers.get(veafCombatZone.Id):trace(string.format("processing element [%s]", zoneElement:getName()))
            local spawnChance = zoneElement:getSpawnChance()
            -- `math.random(1, 100) <= chance` is what makes the percentage exact at both ends: 0 never
            -- spawns and 100 always does. The draw used to start at 0 and compare with `<=`, so
            -- `#spawnchance=0` still had one draw in 101 — and `#spawnchance=1` had two.
            local chance = math.random(1, 100)
            -- The forced draw belongs to a stated `#spawncount` only: it is how the guarantee is met
            -- when the draws would not have met it. An element at 0 % is still never spawned, because a
            -- refusal written in full is the clearer of the two intentions when both are written.
            local forced = statedSpawnCount ~= nil and tries == 1
            local hit = spawnChance > 0 and (forced or chance <= spawnChance)
            veaf.loggers.get(veafCombatZone.Id):trace(string.format("chance = [%d], forced = [%s]", chance, tostring(forced)))
            veaf.loggers.get(veafCombatZone.Id):trace(string.format("spawnChance = [%d]", spawnChance))
            if hit then
              veaf.loggers.get(veafCombatZone.Id):trace(string.format("chance hit (%d <= %d)", chance, spawnChance))
              spawnCount = spawnCount - 1
              alreadySpawnedElements[zoneElement:getName()] = true
              self:spawnElement(zoneElement)
            else
              veaf.loggers.get(veafCombatZone.Id):trace(string.format("chance missed (%d > %d)", chance, spawnChance))
            end
          else
            veaf.loggers.get(veafCombatZone.Id):trace(string.format("already spawned [%s]", zoneElement:getName()))
          end
        end
      end
    end
  end

  -- start the completion watchdog
  self:scheduleWatchdogFunction()

  -- refresh the radio menu
  self:updateRadioMenu()

  return self
end

-- activate the next chained zone (if any)
function VeafCombatZone:activateNextChainedZone()
  local nextZoneName = self:getNextChainedCombatZone()
  local nextZone = veafCombatZone.GetZone(nextZoneName)
  if not nextZone then
    return self
  end
  local delay = self:getChainedCombatZonesDelay()
  veaf.loggers
    .get(veafCombatZone.Id)
    :trace(string.format("activating the next chained zone ([%s]) in %s seconds)", veaf.p(nextZoneName), veaf.p(delay)))
  veaf.scheduleFunction(VeafCombatZone.activate, { nextZone }, timer.getTime() + delay)
  return self
end

-- desactivate the zone
function VeafCombatZone:desactivate()
  veaf.loggers.get(veafCombatZone.Id):debug(string.format("VeafCombatZone[%s]:desactivate()", veaf.p(self.missionEditorZoneName)))
  self:setActive(false)
  self:unscheduleWatchdogFunction()

  for _, delayedSpawner in pairs(self:getDelayedSpawners()) do
    veaf.loggers.get(veafCombatZone.Id):trace("unscheduling delayed spawner %s", delayedSpawner)
    veaf.removeFunction(delayedSpawner)
  end
  self:clearDelayedSpawners()

  for _, groupName in pairs(self:getSpawnedGroups()) do
    self:destroySpawnedGroup(groupName)
  end
  self:clearSpawnedGroups()

  if self.enableJunkCleanup then
    -- remove the junk that the battle left behind
    veaf.loggers.get(veafCombatZone.Id):trace("removing the junk that the battle left behind")
    local zone = veaf.getTriggerZone(self.missionEditorZoneName)
    local volS = {
      id = world.VolumeType.SPHERE,
      params = { point = veaf.placePointOnLand(zone), radius = zone.radius },
    }
    veaf.loggers.get(veafCombatZone.Id):trace(string.format("volS=%s", veaf.p(volS)))
    local n = world.removeJunk(volS)
    veaf.loggers.get(veafCombatZone.Id):trace(string.format("world.removeJunk() returned %s", veaf.p(n)))
  end

  -- refresh the radio menu
  self:updateRadioMenu()

  return self
end

-- check if there are still units in zone
function VeafCombatZone:completionCheck()
  veaf.loggers.get(veafCombatZone.Id):debug(string.format("VeafCombatZone[%s]:completionCheck()", veaf.p(self.missionEditorZoneName)))
  if not self:isCompletable() then
    return
  end
  local nbUnitsR = 0
  local nbUnitsB = 0

  for _, groupName in pairs(self:getSpawnedGroups()) do
    local group = Group.getByName(groupName)
    if group then
      for _, unit in pairs(group:getUnits()) do
        local coa = unit:getCoalition()
        if coa == 1 then
          nbUnitsR = nbUnitsR + 1
        elseif coa == 2 then
          nbUnitsB = nbUnitsB + 1
        end
      end
    else
      local static = StaticObject.getByName(groupName)
      if static then
        local coa = static:getCoalition()
        if coa == 1 then
          nbUnitsR = nbUnitsR + 1
        elseif coa == 2 then
          nbUnitsB = nbUnitsB + 1
        end
      end
    end
  end

  veaf.loggers.get(veafCombatZone.Id):trace(string.format("nbUnitsB=%d", nbUnitsB))
  veaf.loggers.get(veafCombatZone.Id):trace(string.format("nbUnitsR=%d", nbUnitsR))

  -- completion is decided on the hostile side only, which is red unless the zone says
  -- otherwise (setEnemyCoalition) — a red-side zone is cleared when its blue units are gone.
  local nbEnemyUnits = nbUnitsR
  if self:getEnemyCoalition() == 2 then
    nbEnemyUnits = nbUnitsB
  end

  if nbEnemyUnits == 0 then
    -- everyone is dead, let's end this mess
    if veafCombatZone.EventMessages.CombatZoneComplete then
      local message = veaf.t(veafCombatZone.EventMessages.CombatZoneComplete, self:getFriendlyName())
      trigger.action.outText(message, 15)
    end
    -- call the onCompleted hook
    if self.onCompletedHook then
      self.onCompletedHook(self)
    end
    -- desactivate the zone
    self:desactivate()
    -- activate the next chained zone if needed
    self:activateNextChainedZone()
  else
    -- reschedule
    self:scheduleWatchdogFunction()
  end
end

-- pop a smoke marker over the zone
function VeafCombatZone:popSmoke()
  veaf.loggers.get(veafCombatZone.Id):trace(string.format("VeafCombatZone[%s]:popSmoke()", veaf.p(self.missionEditorZoneName)))
  veaf.loggers.get(veafCombatZone.Id):trace(string.format("self:getCenter()=%s", veaf.vecToString(self:getCenter())))
  local smokePoint = self:getCenter()
  if self:isTraining() then
    -- compute the barycenter of all remaining units
    local totalPosition = { x = 0, y = 0, z = 0 }
    local units, _ = veaf.safeUnpack(self:findUnitsInCombatZone())
    for count = 1, #units do
      if units[count] then
        totalPosition = veaf.vecAdd(totalPosition, Unit.getPosition(units[count]).p)
      end
    end
    if #units > 0 then
      smokePoint = veaf.vecScalarMult(totalPosition, 1 / #units)
    end
  end
  veaf.loggers.get(veafCombatZone.Id):trace(string.format("smokePoint=%s", veaf.vecToString(smokePoint)))
  veafSpawn.spawnSmoke(smokePoint, trigger.smokeColor.Red)
  self.smokeResetFunctionId = veaf.scheduleFunction(
    veafCombatZone.SmokeReset,
    { self.missionEditorZoneName },
    timer.getTime() + veafCombatZone.SecondsBetweenSmokeRequests
  )
  trigger.action.outText(veaf.t(veafCombatZone.EventMessages.PopSmokeRequest, self:getFriendlyName()), 5)
  self:updateRadioMenu()

  return self
end

-- pop an illumination  flare over a zone
function VeafCombatZone:popFlare()
  veaf.loggers.get(veafCombatZone.Id):trace(string.format("VeafCombatZone[%s]:popFlare()", veaf.p(self.missionEditorZoneName)))
  veaf.loggers.get(veafCombatZone.Id):trace(string.format("self:getCenter()=%s", veaf.vecToString(self:getCenter())))

  veafSpawn.spawnIlluminationFlare(self:getCenter())
  self.flareResetFunctionId = veaf.scheduleFunction(
    veafCombatZone.FlareReset,
    { self.missionEditorZoneName },
    timer.getTime() + veafCombatZone.SecondsBetweenFlareRequests
  )
  trigger.action.outText(veaf.t(veafCombatZone.EventMessages.UseFlareRequest, self:getFriendlyName()), 5)
  self:updateRadioMenu()

  return self
end

-- updates the radio menu according to the zone state
function VeafCombatZone:updateRadioMenu(inBatch)
  veaf.loggers
    .get(veafCombatZone.Id)
    :debug(string.format("VeafCombatZone[%s]:updateRadioMenu(%s)", veaf.p(self.missionEditorZoneName), tostring(inBatch)))
  veaf.loggers.get(veafCombatZone.Id):debug("radioGroupName=%s", self.radioGroupName)

  -- do not update the radio menu if not yet initialized or if we don't want to
  if not self.radioParentPath or not self.enableRadioMenu then
    return self
  end

  local shouldAddSubMenu = self.enableUserActivation or self.active
  veaf.loggers.get(veafCombatZone.Id):debug(
    "User activation enabled : %s, Zone active: %s, shouldAddSubMenu: %s",
    veaf.lp(self.enableUserActivation),
    veaf.lp(self.active),
    veaf.lp(shouldAddSubMenu)
  )

  -- reset the radio menu
  if self.radioRootPath then
    veaf.loggers.get(veafCombatZone.Id):debug("Remove the radio submenu %s", veaf.lp(self:getRadioMenuName()))
    veafRadio.delSubmenu(self:getRadioMenuName(), self.radioParentPath)
    veafRadio.delSubmenu(self:getRadioMenuName(true), self.radioParentPath)
    self.radioRootPath = nil
  end
  if shouldAddSubMenu then
    veaf.loggers.get(veafCombatZone.Id):debug("add the radio submenu")
    self.radioRootPath = veafRadio.addSubMenu(self:getRadioMenuName(self:isActive()), self.radioParentPath, self:getRadioMenuCoalition())
  end

  if shouldAddSubMenu then
    -- populate the radio menu
    veaf.loggers.get(veafCombatZone.Id):debug("populate the radio menu")
    -- global commands
    veafRadio.addCommandToSubmenu(
      veaf.t("menu.combatzone.get_info"),
      self.radioRootPath,
      veafCombatZone.GetInformationOnZone,
      self.missionEditorZoneName,
      veafRadio.USAGE_ForGroup
    )
    if self:isActive() then
      -- zone is active, set up accordingly (desactivate zone, get information, pop smoke, etc.)
      veaf.loggers.get(veafCombatZone.Id):debug("zone is active")
      if self.enableUserActivation then
        if self:isTraining() then
          veafRadio.addCommandToSubmenu(
            veaf.t("menu.combatzone.deactivate"),
            self.radioRootPath,
            veafCombatZone.DesactivateZone,
            self.missionEditorZoneName,
            veafRadio.USAGE_ForAll
          )
        else
          veafRadio.addSecuredCommandToSubmenu(
            veaf.t("menu.combatzone.deactivate"),
            self.radioRootPath,
            veafCombatZone.DesactivateZone,
            self.missionEditorZoneName,
            veafRadio.USAGE_ForAll
          )
        end
      end
      if self.enableSmokeAndFlare then
        if self.smokeResetFunctionId then
          veafRadio.addCommandToSubmenu(
            veaf.t("menu.combatzone.smoke_unavailable"),
            self.radioRootPath,
            veaf.emptyFunction,
            nil,
            veafRadio.USAGE_ForAll
          )
        else
          veafRadio.addCommandToSubmenu(
            veaf.t("menu.combatzone.request_smoke"),
            self.radioRootPath,
            veafCombatZone.SmokeZone,
            self.missionEditorZoneName,
            veafRadio.USAGE_ForAll
          )
        end
        if self.flareResetFunctionId then
          veafRadio.addCommandToSubmenu(
            veaf.t("menu.combatzone.flare_unavailable"),
            self.radioRootPath,
            veaf.emptyFunction,
            nil,
            veafRadio.USAGE_ForAll
          )
        else
          veafRadio.addCommandToSubmenu(
            veaf.t("menu.combatzone.request_flare"),
            self.radioRootPath,
            veafCombatZone.LightUpZone,
            self.missionEditorZoneName,
            veafRadio.USAGE_ForAll
          )
        end
      end
    else
      -- zone is not active, set up accordingly (activate zone)
      veaf.loggers.get(veafCombatZone.Id):debug("zone is not active")
      if self.enableUserActivation then
        if self:isTraining() then
          veafRadio.addCommandToSubmenu(
            veaf.t("menu.combatzone.activate"),
            self.radioRootPath,
            veafCombatZone.ActivateZone,
            self.missionEditorZoneName,
            veafRadio.USAGE_ForAll
          )
        else
          veafRadio.addSecuredCommandToSubmenu(
            veaf.t("menu.combatzone.activate"),
            self.radioRootPath,
            veafCombatZone.ActivateZone,
            self.missionEditorZoneName,
            veafRadio.USAGE_ForAll
          )
        end
      end
    end
  end

  if not inBatch then
    veafRadio.refreshRadioMenu()
  end
  return self
end

---
--- lists all units and statics (and their groups names) in a combat zone that also match the combat zone name
---
--- Returns `{ keptUnits, keptGroupNames, excludedGroupNames }`. The third slot is what the zone found
--- inside its trigger zone and left behind because the prefix rule turned it down — reported once by
--- `initialize`, see `VeafCombatZone:reportGroupsExcludedByName`.
---
function VeafCombatZone:findUnitsInCombatZone()
  local unitsNames = veaf.getUnitsNamesOfCoalition(true, nil) -- include statics, all coalitions
  local units = {}
  local resultUnits = {}
  local groupNames = {}
  local alreadyAddedGroups = {}
  local excludedGroupNames = {}
  local alreadyExcludedGroups = {}
  local triggerZone = self:getTriggerZone()
  local upperTriggerzoneName = self:getMissionEditorZoneName():upper()

  if not triggerZone then
    return self
  end

  veaf.loggers.get(veafCombatZone.Id):trace("#unitsNames=%s", veaf.lp(#unitsNames))

  veaf.loggers.get(veafCombatZone.Id):trace("triggerZone.type=%s", veaf.lp(triggerZone.type))
  -- nil means the zone's shape could not be read, and the error is already in the log; an empty list
  -- means it really holds nobody. The difference is not cosmetic: an unusable zone is marked so that it
  -- never completes, instead of quietly reporting that everything in it is dead.
  units = veaf.getUnitsInTriggerZone(self:getMissionEditorZoneName(), unitsNames, veafCombatZone.Id)
  if not units then
    self.unreadableTriggerZone = true
    return { {}, {}, {} }
  end

  veaf.loggers.get(veafCombatZone.Id):trace("#units=%s", veaf.lp(#units))

  for _, unit in pairs(units) do
    local groupName = veafCombatZone.getGroupNameOfUnit(unit)
    veaf.loggers.get(veafCombatZone.Id):trace("processing unit [%s] of group [%s]", veaf.p(unit:getName()), veaf.p(groupName))
    if string.sub(groupName:upper(), 1, string.len(upperTriggerzoneName)) == upperTriggerzoneName then
      resultUnits[#resultUnits + 1] = unit
      if not alreadyAddedGroups[groupName] then
        alreadyAddedGroups[groupName] = groupName
        groupNames[#groupNames + 1] = groupName
      end
    elseif not alreadyExcludedGroups[groupName] then
      -- collected by **group**, not by unit: a group is what the mission maker would have to rename,
      -- and a zone can hold dozens of units for a handful of groups
      alreadyExcludedGroups[groupName] = groupName
      excludedGroupNames[#excludedGroupNames + 1] = groupName
    end
  end

  veaf.loggers.get(veafCombatZone.Id):trace(string.format("found %d units (%d groups) in zone", #resultUnits, #groupNames))
  return { resultUnits, groupNames, excludedGroupNames }
end

--- Say, once, which groups stood inside the zone and were turned down by the prefix rule.
---
--- The rule itself is deliberate — see the module header and `doc/mission-maker/scripts/veafCombatZone.md`
--- — but until now it applied without a word above `trace`: a mission maker who mistyped a prefix saw the
--- zone activate, saw nothing appear, and found an empty log. One line per zone at `info`, and **nothing
--- at all** when nothing was excluded: a message every mission prints is a message nobody reads.
function VeafCombatZone:reportGroupsExcludedByName(excludedGroupNames)
  if not excludedGroupNames or #excludedGroupNames == 0 then
    return self
  end
  local zoneName = self:getMissionEditorZoneName()
  veaf.loggers.get(veafCombatZone.Id):info(
    veaf.t(
      "combatzone.groups_excluded_by_name",
      veaf.p(zoneName),
      #excludedGroupNames,
      table.concat(excludedGroupNames, ", "),
      veaf.p(zoneName)
    )
  )
  return self
end
-------------------------------------------------------------------------------------------------------------------------------------------------------------
-- VeafCombatOperationTaskingOrder object
-------------------------------------------------------------------------------------------------------------------------------------------------------------

VeafCombatOperationTaskingOrder = {
  -- combat zone of the tasking order
  zone = nil,
  -- what tasking orders needs to be completed before starting this one
  requiredCompleteNames = {},
}
VeafCombatOperationTaskingOrder.__index = VeafCombatOperationTaskingOrder

function VeafCombatOperationTaskingOrder:new(zone)
  local self = setmetatable({}, VeafCombatOperationTaskingOrder)
  self.zone = zone
  self.requiredCompleteNames = {}

  return self
end

function VeafCombatOperationTaskingOrder:setRequiredComplete(requiredCompleteNames)
  self.requiredCompleteNames = requiredCompleteNames
  return self
end

function VeafCombatOperationTaskingOrder:getZone()
  return self.zone
end

-------------------------------------------------------------------------------------------------------------------------------------------------------------
-- VeafCombatOperation object
-------------------------------------------------------------------------------------------------------------------------------------------------------------

VeafCombatOperation = VeafCombatZone:new()

function VeafCombatOperation:new(objectToCopy)
  local objectToCreate = objectToCopy or {} -- create object if user does not provide one
  setmetatable(objectToCreate, self)
  self.__index = self

  -- init the new object

  -- operation name (human-friendly)
  objectToCreate.friendlyName = nil
  -- technical operation name (named missionEditorZoneName not to break all zone stuffs)
  objectToCreate.missionEditorZoneName = nil
  -- mission briefing
  objectToCreate.briefing = nil
  -- operation is active
  objectToCreate.active = false
  -- list of zones used as tasking order
  objectToCreate.taskingOrderList = {}
  -- dictionnary of zones used as tasking order
  objectToCreate.taskingOrderDict = {}
  -- combat zone that we want to be completed before continuing operation
  objectToCreate.primaryTaskingOrders = {}
  -- the watchdog function checks for zone objectives completion
  objectToCreate.watchdogFunctionId = nil
  -- function to call when combat zone is over. The function is passed self combat zone
  objectToCreate.onCompletedHook = nil
  -- how many tasks were complete so far
  objectToCreate.currentCompletedTaskingOrderCount = 0

  return objectToCreate
end

---
--- setters and getters
---
function VeafCombatOperation:setOnCompletedHook(onCompletedFunction)
  self.onCompletedHook = onCompletedFunction
  return self
end

function VeafCombatOperation:getRadioMenuName()
  return self:getFriendlyName()
end

function VeafCombatOperation:getInformation()
  veaf.loggers.get(veafCombatZone.Id):trace(string.format("VeafCombatOperation[%s]:getInformation()", veaf.p(self.missionEditorZoneName)))
  local message = "OPERATION " .. self:getFriendlyName() .. " \n\n"
  if self:getBriefing() then
    message = message .. messageSeparator
    message = message .. self:getBriefing()
    message = message .. "\n\n"
  end

  if self:isActive() then
    message = message .. messageSeparator .. "Air Tasking Orders: \n"
    for _, primaryTaskingOrder in pairs(self.primaryTaskingOrders) do
      if primaryTaskingOrder.zone:isActive() then
        message = message .. primaryTaskingOrder:getZone():getFriendlyName() .. "\n"
      end
    end
  else
    -- `veaf.t`, not `string.format`: EventMessages.CombatOperationComplete is a translation KEY, not a
    -- sentence. Formatting it printed `combatzone.operation_complete` to the player and threw the
    -- operation's name away — the key has no `%s`, so string.format returned it unchanged and discarded
    -- the argument. Seen in game on the demo mission, 2026-08-25. The same constant is used correctly in
    -- the event message forty lines below, which is why only the briefing was broken.
    message = message .. veaf.t(veafCombatZone.EventMessages.CombatOperationComplete, self:getFriendlyName())
  end

  return message
end

function VeafCombatOperation:addTaskingOrder(zone, requiredComplete)
  -- add requiredComplete in log
  veaf.loggers.get(veafCombatZone.Id):trace(
    string.format("VeafCombatOperation[%s]:addTaskingOrder(%s)", veaf.p(self.missionEditorZoneName), veaf.p(zone.missionEditorZoneName))
  )
  veaf.loggers
    .get(veafCombatZone.Id)
    :trace(string.format("Adding combat zone %s to operation %s", zone.missionEditorZoneName, veaf.p(self.missionEditorZoneName)))
  veaf.loggers.get(veafCombatZone.Id):trace(string.format("Tasks required before activation: %s", veaf.p(requiredComplete)))

  for _, mandatoryZoneName in pairs(requiredComplete or {}) do
    if not self.taskingOrderDict[mandatoryZoneName] then
      veaf.loggers
        .get(veafCombatZone.Id)
        :error(string.format("Cannot add mandatory zone %s as it is not in known zones", veaf.p(mandatoryZoneName)))
      return self
    end
  end

  veaf.loggers.get(veafCombatZone.Id):trace("remove task order from combat zone radio menu")
  zone:disableRadioMenu()

  -- adds tasking order to the zone lists to make it accessible
  veafCombatZone.AddZone(zone)

  local newTaskingOrder = VeafCombatOperationTaskingOrder:new(zone):setRequiredComplete(requiredComplete or {})

  table.insert(self.taskingOrderList, newTaskingOrder)
  self.taskingOrderDict[zone.missionEditorZoneName] = newTaskingOrder

  return self
end

-------------------
--- Other methods
-------------------
function VeafCombatOperation:scheduleWatchdogFunction()
  veaf.loggers
    .get(veafCombatZone.Id)
    :trace(string.format("VeafCombatOperation[%s]:scheduleWatchdogFunction()", veaf.p(self.missionEditorZoneName)))
  self.watchdogFunctionId = veaf.scheduleFunction(
    veafCombatZone.CompletionCheck,
    { self.missionEditorZoneName },
    timer.getTime() + veafCombatZone.SecondsBetweenWatchdogChecks
  )
  return self
end

function VeafCombatOperation:unscheduleWatchdogFunction()
  veaf.loggers
    .get(veafCombatZone.Id)
    :trace(string.format("VeafCombatOperation[%s]:unscheduleWatchdogFunction()", veaf.p(self.missionEditorZoneName)))
  if self.watchdogFunctionId then
    veaf.removeFunction(self.watchdogFunctionId)
  end
  self.watchdogFunctionId = nil
  return self
end

function VeafCombatOperation:updatePrimaryTasks()
  veaf.loggers
    .get(veafCombatZone.Id)
    :trace(string.format("VeafCombatOperation[%s]:updatePrimaryTasks()", veaf.p(self.missionEditorZoneName)))

  veaf.loggers.get(veafCombatZone.Id):trace("Clear primary tasks")
  self.primaryTaskingOrders = {}

  veaf.loggers.get(veafCombatZone.Id):trace("Look for next tasks")
  local newPrimaryTasks = {}
  for _, candidateTaskingOrder in pairs(self.taskingOrderDict) do
    -- filter tasks that are not completed yet
    if candidateTaskingOrder:getZone():isActive() then
      local requirementFulfilled = true
      for _, requiredCombatZoneName in pairs(candidateTaskingOrder.requiredCompleteNames) do
        local requiredCombatZone = veafCombatZone.GetZone(requiredCombatZoneName)

        -- `GetZone` answers nil for a name it does not know -- a prerequisite misspelled in
        -- mission.yaml -- and it has already said so, loudly, on screen and in the log. Dereferencing
        -- it anyway took the whole operation down; a `need-check-nil` was silencing the linter that
        -- pointed at this exact line.
        --
        -- A zone that does not exist cannot be active, so it cannot block: the requirement is skipped
        -- rather than treated as unfulfilled, which would deadlock the operation for good on a typo.
        if not requiredCombatZone then
          veaf.loggers.get(veafCombatZone.Id):warn(
            string.format(
              "updatePrimaryTasks: unknown required zone [%s] ; it cannot block, so it is ignored",
              veaf.p(requiredCombatZoneName)
            )
          )
        elseif requiredCombatZone:isActive() then
          -- if any of required tasking order is active, then tasking order is not eligible
          requirementFulfilled = false
          break
        end
      end

      if requirementFulfilled then
        table.insert(newPrimaryTasks, candidateTaskingOrder)
      end
    end
  end

  -- No task left, operation complete !
  if veaf.length(newPrimaryTasks) == 0 then
    veaf.loggers.get(veafCombatZone.Id):trace("No tasks left")
    self:desactivate()

    if veafCombatZone.EventMessages.CombatOperationComplete then
      trigger.action.outText(veaf.t(veafCombatZone.EventMessages.CombatOperationComplete, self.friendlyName), 10)
    end
    return self
  end

  veaf.loggers.get(veafCombatZone.Id):trace("Setting new primary tasks")
  self.primaryTaskingOrders = newPrimaryTasks
end

-- checks if primary tasks are completed to unlock next
function VeafCombatOperation:completionCheck()
  veaf.loggers.get(veafCombatZone.Id):trace(string.format("VeafCombatOperation[%s]:completionCheck()", veaf.p(self.missionEditorZoneName)))

  local completedTaskingOrderCount = 0
  -- if any of primary tasks is still active, then check is done
  for _, primaryTask in pairs(self.primaryTaskingOrders) do
    if not primaryTask:getZone():isActive() then
      veaf.loggers.get(veafCombatZone.Id):trace(string.format("Primary task %s is completed", primaryTask:getZone():getFriendlyName()))
      completedTaskingOrderCount = completedTaskingOrderCount + 1
    end
  end

  veaf.loggers.get(veafCombatZone.Id):trace(
    string.format(
      "%s completed out of %s, previous was %s",
      completedTaskingOrderCount,
      #self.primaryTaskingOrders,
      self.currentCompletedTaskingOrderCount
    )
  )
  if completedTaskingOrderCount == #self.primaryTaskingOrders then
    veaf.loggers.get(veafCombatZone.Id):trace("Primary tasks complete")
    self:updatePrimaryTasks()
    self:updateRadioMenu()
    completedTaskingOrderCount = 0
    if not self:isActive() then
      return self
    end
  end

  veaf.loggers.get(veafCombatZone.Id):trace("Still got work to do.")

  if completedTaskingOrderCount ~= self.currentCompletedTaskingOrderCount then
    veaf.loggers.get(veafCombatZone.Id):trace("New tasking order completed. Update radio.")
    self:updatePrimaryTasks()
    self:updateRadioMenu()
  end
  self.currentCompletedTaskingOrderCount = completedTaskingOrderCount

  -- reschedule
  self:scheduleWatchdogFunction()

  return self
end

function VeafCombatOperation:initialize()
  veaf.loggers.get(veafCombatZone.Id):debug(string.format("VeafCombatOperation[%s]:initialize()", veaf.p(self.missionEditorZoneName)))

  -- check parameters
  if not self.missionEditorZoneName then
    return self
  end
  if not self.friendlyName then
    self:setFriendlyName(self.missionEditorZoneName)
  end

  -- initializes  member combat zones and sets starting primary tasks
  for _, taskingOrder in pairs(self.taskingOrderDict) do
    taskingOrder:getZone():initialize()
  end

  -- deactivate the zone
  veaf.loggers.get(veafCombatZone.Id):trace("desactivate the operation")
  self:desactivate()

  return self
end

-- activate the operation
function VeafCombatOperation:activate()
  veaf.loggers.get(veafCombatZone.Id):trace(string.format("VeafCombatOperation[%s]:activate()", veaf.p(self.missionEditorZoneName)))
  self:setActive(true)

  local primaryTasks = {}
  -- activates member combat zones and sets starting primary tasks
  veaf.loggers.get(veafCombatZone.Id):trace("activate the operation's zones")
  for _, taskingOrder in pairs(self.taskingOrderDict) do
    taskingOrder:getZone():activate()

    -- selects combat zones with no requiredComplete combat zones
    if veaf.length(taskingOrder.requiredCompleteNames) == 0 then
      table.insert(primaryTasks, taskingOrder)
    end
  end

  veaf.loggers.get(veafCombatZone.Id):trace("set primary task")
  self.primaryTaskingOrders = primaryTasks

  -- schedule the watchdog function
  self:scheduleWatchdogFunction()

  -- refresh the radio menu
  self:updateRadioMenu()

  return self
end

-- desactivate the operation
function VeafCombatOperation:desactivate()
  veaf.loggers.get(veafCombatZone.Id):debug(string.format("VeafCombatOperation[%s]:desactivate()", veaf.p(self.missionEditorZoneName)))
  self:setActive(false)

  -- unscheduel watchdog function
  self:unscheduleWatchdogFunction()

  -- refresh the radio menu
  self:updateRadioMenu()

  return self
end

-- updates the radio menu according to the zone state
function VeafCombatOperation:updateRadioMenu(inBatch)
  veaf.loggers
    .get(veafCombatZone.Id)
    :debug(string.format("VeafCombatOperation[%s]:updateRadioMenu(%s)", veaf.p(self.missionEditorZoneName), veaf.p(inBatch)))

  -- do not update the radio menu if not yet initialized
  if not veafCombatZone.rootPath then
    return self
  end

  local menuToFill = veafCombatZone.rootPath
  if veafCombatZone.operationRootPath then
    menuToFill = veafCombatZone.operationRootPath
  end

  -- reset the radio menu
  if self.radioRootPath then
    veaf.loggers.get(veafCombatZone.Id):trace("reset the radio submenu")
    veafRadio.clearSubmenu(self.radioRootPath)
  else
    veaf.loggers.get(veafCombatZone.Id):trace("add the radio submenu")
    self.radioRootPath = veafRadio.addSubMenu(self:getRadioMenuName(), menuToFill)
  end

  -- populate the radio menu
  veaf.loggers.get(veafCombatZone.Id):trace("populate the radio menu")
  -- global commands
  veafRadio.addCommandToSubmenu(
    veaf.t("menu.combatzone.get_info"),
    self.radioRootPath,
    veafCombatZone.GetInformationOnZone,
    self.missionEditorZoneName,
    veafRadio.USAGE_ForGroup
  )
  for _, taskingOrder in pairs(self.primaryTaskingOrders) do
    if taskingOrder.zone:isActive() then
      veaf.loggers
        .get(veafCombatZone.Id)
        :trace(string.format("Add briefing for %s, %s", taskingOrder.zone:getFriendlyName(), taskingOrder.zone:getMissionEditorZoneName()))
      veafRadio.addCommandToSubmenu(
        veaf.t("menu.combatzone.briefing", taskingOrder.zone:getFriendlyName()),
        self.radioRootPath,
        veafCombatZone.GetInformationOnZone,
        taskingOrder.zone:getMissionEditorZoneName(),
        veafRadio.USAGE_ForGroup
      )
    else
      veaf.loggers.get(veafCombatZone.Id):trace(
        string.format(
          "Skip briefing for %s, %s as it is not active",
          taskingOrder.zone:getFriendlyName(),
          taskingOrder.zone:getMissionEditorZoneName()
        )
      )
    end
  end

  if self:isActive() then
    -- zone is active, set up accordingly (desactivate zone, get information, pop smoke, etc.)
    veaf.loggers.get(veafCombatZone.Id):trace("zone is active")

    -- veafRadio.addSecuredCommandToSubmenu(veaf.t("menu.combatzone.deactivate"), self.radioRootPath, veafCombatZone.DesactivateZone, self.missionEditorZoneName, veafRadio.USAGE_ForAll)

    -- if self.smokeResetFunctionId then
    --     veafRadio.addCommandToSubmenu(veaf.t("menu.combatzone.smoke_unavailable"), self.radioRootPath, veaf.emptyFunction, nil, veafRadio.USAGE_ForAll)
    -- else
    --     veafRadio.addCommandToSubmenu(veaf.t("menu.combatzone.request_smoke"), self.radioRootPath, veafCombatZone.SmokeZone, self.missionEditorZoneName, veafRadio.USAGE_ForAll)
    -- end
    -- if self.flareResetFunctionId then
    --     veafRadio.addCommandToSubmenu(veaf.t("menu.combatzone.flare_unavailable"), self.radioRootPath, veaf.emptyFunction, nil, veafRadio.USAGE_ForAll)
    -- else
    --     veafRadio.addCommandToSubmenu(veaf.t("menu.combatzone.request_flare"), self.radioRootPath, veafCombatZone.LightUpZone, self.missionEditorZoneName, veafRadio.USAGE_ForAll)
    -- end
  else
    -- zone is not active, set up accordingly (activate zone)
    veaf.loggers.get(veafCombatZone.Id):trace("zone is not active")

    -- veafRadio.addSecuredCommandToSubmenu(veaf.t("menu.combatzone.activate"), self.radioRootPath, veafCombatZone.ActivateZone, self.missionEditorZoneName, veafRadio.USAGE_ForAll)
  end

  if not inBatch then
    veafRadio.refreshRadioMenu()
  end
  return self
end

-------------------------------------------------------------------------------------------------------------------------------------------------------------
-- global functions
-------------------------------------------------------------------------------------------------------------------------------------------------------------

--------------------------------------------------------------------------------------------------------------
--- GLOBAL INTERFACE, working for both zones and operations
--------------------------------------------------------------------------------------------------------------

function veafCombatZone.GetZone(zoneName)
  veaf.loggers.get(veafCombatZone.Id):trace(string.format("veafCombatZone.GetZone([%s])", veaf.p(zoneName)))
  veaf.loggers.get(veafCombatZone.Id):trace(string.format("Searching for zone with name [%s]", veaf.p(zoneName)))
  if zoneName then
    local zone = veafCombatZone.zonesDict[zoneName:lower()]
    if not zone then
      local message = string.format("VeafCombatZone [%s] was not found !", zoneName)
      veaf.loggers.get(veafCombatZone.Id):error(message)
      trigger.action.outText(veaf.t("combatzone.zone_not_found", zoneName), 5)
    end
    return zone
  else
    return nil
  end
end

-- add a zone
function veafCombatZone.AddZone(zone)
  veaf.loggers
    .get(veafCombatZone.Id)
    :debug(string.format("veafCombatZone.AddZone([%s])", veaf.p(veaf.ifnns(zone, "missionEditorZoneName"))))
  if zone then
    zone:initialize()
    table.insert(veafCombatZone.zonesList, zone)
    veafCombatZone.zonesDict[zone.missionEditorZoneName:lower()] = zone
    return zone
  else
    return nil
  end
end

-- activate a zone by number
function veafCombatZone.ActivateZoneNumber(number, silent)
  veaf.loggers.get(veafCombatZone.Id):debug(string.format("veafCombatZone.ActivateZoneNumber([%s])", veaf.p(number)))
  local zone = veafCombatZone.zonesList[number]
  if zone then
    veafCombatZone.ActivateZone(zone:getMissionEditorZoneName(), silent)
  end
end

-- activate a zone
function veafCombatZone.ActivateZone(zoneName, silent)
  veaf.loggers.get(veafCombatZone.Id):debug(string.format("veafCombatZone.ActivateZone([%s])", veaf.p(zoneName)))
  local zone = veafCombatZone.GetZone(zoneName)
  if zone then
    if zone:isActive() then
      if not silent then
        trigger.action.outText(veaf.t("entity.is_already_active", "VeafCombatZone " .. zone:getFriendlyName()), 10)
      end
      return
    end
    veaf.scheduleFunction(zone.activate, { zone }, timer.getTime() + 1)
    if not silent then
      trigger.action.outText(veaf.t("entity.activated", "VeafCombatZone " .. zone:getFriendlyName()), 10)
      veaf.scheduleFunction(veafCombatZone.GetInformationOnZone, { { zoneName } }, timer.getTime() + 2)
    end
    return zone
  else
    return nil
  end
end

-- desactivate a zone by number
function veafCombatZone.DesactivateZoneNumber(number, silent)
  veaf.loggers.get(veafCombatZone.Id):debug(string.format("veafCombatZone.DesactivateZoneNumber([%s])", veaf.p(number)))
  local zone = veafCombatZone.zonesList[number]
  if zone then
    veafCombatZone.DesactivateZone(zone:getMissionEditorZoneName(), silent)
  end
end

-- desactivate a zone by name
function veafCombatZone.DesactivateZone(zoneName, silent)
  veaf.loggers.get(veafCombatZone.Id):debug(string.format("veafCombatZone.DesactivateZone([%s])", veaf.p(zoneName)))
  local zone = veafCombatZone.GetZone(zoneName)
  if zone then
    if not (zone:isActive()) then
      if not silent then
        trigger.action.outText(veaf.t("entity.is_not_active", "VeafCombatZone " .. zone:getFriendlyName()), 10)
      end
      return
    end
    zone:desactivate()
    if not silent then
      trigger.action.outText(veaf.t("entity.deactivated", "VeafCombatZone " .. zone:getFriendlyName()), 10)
    end
    return zone
  else
    return nil
  end
end

-- print information about a zone
function veafCombatZone.GetInformationOnZone(parameters)
  veaf.loggers.get(veafCombatZone.Id):trace(string.format("veafCombatZone.GetInformationOnZone([%s])", veaf.p(parameters)))
  local zoneName, unitName = veaf.safeUnpack(parameters)
  local zone = veafCombatZone.GetZone(zoneName)
  if zone then
    local text = zone:getInformation(unitName)
    if unitName then
      veaf.outTextForGroup(unitName, text, 30)
    else
      trigger.action.outText(text, 30)
    end
    return zone
  else
    return nil
  end
end

-- pop a smoke over a zone
function veafCombatZone.SmokeZone(zoneName)
  veaf.loggers.get(veafCombatZone.Id):trace(string.format("veafCombatZone.SmokeZone([%s])", veaf.p(zoneName)))
  local zone = veafCombatZone.GetZone(zoneName)
  if zone then
    zone:popSmoke()
    return zone
  else
    return nil
  end
end

-- pop an illumination  flare over a zone
function veafCombatZone.LightUpZone(zoneName)
  veaf.loggers.get(veafCombatZone.Id):trace(string.format("veafCombatZone.LightUpZone([%s])", veaf.p(zoneName)))
  local zone = veafCombatZone.GetZone(zoneName)
  if zone then
    zone:popFlare()
    return zone
  else
    return nil
  end
end

-- reset the "pop smoke" menus
function veafCombatZone.SmokeReset(zoneName)
  veaf.loggers.get(veafCombatZone.Id):trace(string.format("veafCombatZone.SmokeReset([%s])", veaf.p(zoneName)))
  local zone = veafCombatZone.GetZone(zoneName)
  if zone then
    zone.smokeResetFunctionId = nil
    zone:updateRadioMenu()
    return zone
  else
    return nil
  end
end

-- reset the "pop flare" menus
function veafCombatZone.FlareReset(zoneName)
  veaf.loggers.get(veafCombatZone.Id):trace(string.format("veafCombatZone.FlareReset([%s])", veaf.p(zoneName)))
  local zone = veafCombatZone.GetZone(zoneName)
  if zone then
    zone.flareResetFunctionId = nil
    zone:updateRadioMenu()
    return zone
  else
    return nil
  end
end

-- call the completion watchdog methods
function veafCombatZone.CompletionCheck(zoneName)
  veaf.loggers.get(veafCombatZone.Id):trace(string.format("veafCombatZone.CompletionCheck([%s])", veaf.p(zoneName)))
  local zone = veafCombatZone.GetZone(zoneName)
  if zone then
    zone:completionCheck()
    return zone
  else
    return nil
  end
end

--------------------------------------------------------------------------------------------------------------
--- END OF GLOBAL INTERFACE
--------------------------------------------------------------------------------------------------------------

-------------------------------------------------------------------------------------------------------------------------------------------------------------
-- Radio menu and help
-------------------------------------------------------------------------------------------------------------------------------------------------------------

--- Build the initial radio menu
function veafCombatZone.buildRadioMenu()
  veaf.loggers.get(veafCombatZone.Id):debug("buildRadioMenu()")

  -- don't create an empty menu
  if veaf.length(veafCombatZone.zonesDict) == 0 then
    return
  end

  veafCombatZone.rootPath = veafRadio.addMenu(veaf.t(veafCombatZone.RadioMenuName))
  veafCombatZone.combatZoneRootPath = veafCombatZone.rootPath

  if not veafRadio.skipHelpMenus then
    veafRadio.addCommandToSubmenu(veaf.t("menu.common.help"), veafCombatZone.rootPath, veafCombatZone.help, nil, veafRadio.USAGE_ForGroup)
  end

  if veafCombatZone.CombatZoneRadioMenuName then
    veafCombatZone.combatZoneRootPath = veafRadio.addSubMenu(veafCombatZone.CombatZoneRadioMenuName, veafCombatZone.rootPath)
  end

  if veafCombatZone.OperationRadioMenuName then
    veafCombatZone.operationRootPath = veafRadio.addSubMenu(veafCombatZone.OperationRadioMenuName, veafCombatZone.rootPath)
  end

  -- sort the zones alphabetically
  local names = {}
  local sortedZones = {}
  for _, zone in pairs(veafCombatZone.zonesDict) do
    table.insert(sortedZones, { name = zone:getMissionEditorZoneName(), sort = zone:getFriendlyName() })
  end
  local function compare(a, b)
    if not a then
      a = {}
    end
    if not a["sort"] then
      a["sort"] = 0
    end
    if not b then
      b = {}
    end
    if not b["sort"] then
      b["sort"] = 0
    end
    return a["sort"] < b["sort"]
  end
  table.sort(sortedZones, compare)
  for i = 1, #sortedZones do
    table.insert(names, sortedZones[i].name)
  end

  veaf.loggers.get(veafCombatZone.Id):trace("veafCombatZone.buildRadioMenu() - dumping names")
  for i = 1, #names do
    veaf.loggers.get(veafCombatZone.Id):trace("veafCombatZone.buildRadioMenu().names -> " .. names[i])
  end

  for _, zoneName in pairs(names) do
    local zone = veafCombatZone.GetZone(zoneName)
    if zone then
      if zone:getRadioGroupName() then
        local radioGroup = veafCombatZone.radioGroupsDict[zone:getRadioGroupName()]
        if not radioGroup then
          -- create the radio group menu
          radioGroup = veafRadio.addSubMenu(zone:getRadioGroupName(), veafCombatZone.combatZoneRootPath)
          veaf.loggers.get(veafCombatZone.Id):debug("created radio group %s", zone:getRadioGroupName())
          veafCombatZone.radioGroupsDict[zone:getRadioGroupName()] = radioGroup
        end
        zone:setRadioParentPath(radioGroup)
      else
        zone:setRadioParentPath(veafCombatZone.combatZoneRootPath)
      end
      zone:updateRadioMenu(true)
    end
  end

  veafRadio.refreshRadioMenu()
end

function veafCombatZone.help(unitName)
  local text = veaf.t("combatzone.help")
  veaf.outTextForGroup(unitName, text, 30)
end

-------------------------------------------------------------------------------------------------------------------------------------------------------------
-- initialisation
-------------------------------------------------------------------------------------------------------------------------------------------------------------
function veafCombatZone.initialize()
  veaf.loggers.get(veafCombatZone.Id):info("Initializing module")
  veafCombatZone.buildRadioMenu()
end

veaf.loggers.get(veafCombatZone.Id):info(veaf.loggers.get(veafCombatZone.Id):getVersionInfo())

veaf.registerModule(veafCombatZone.Id, veafCombatZone.initialize, { enable = true }, 110)
