------------------------------------------------------------------
-- VEAF opposition level for DCS World
-- By Zip (2026)
--
-- Features:
-- ---------
-- * One number the mission carries: how many player aircraft the air opposition is sized for, in the
--   same unit as a QRA's `enemy_count` tiers (FEAT-OPPOSITION-SCALES-WITH-PLAYERS).
-- * Set at generation (`opposition: level:` in mission.yaml), changed in flight by a mission master
--   (`_opposition 6` marker, or the radio menu), or followed automatically — the players connected, or
--   the players airborne, re-read on a beat.
-- * Follows with a hysteresis: a rise is taken at once (a player who joins must be served), a drop only
--   once the count has stayed lower for `lowerAfter` seconds (a disconnect, or a crash and respawn,
--   changes nothing).
-- * What reads it: a QRA set to scale with the opposition (`scale_with_opposition`), and the
--   "scale auto" entry of the combat missions' radio menu.
--
-- See the documentation : https://veaf.github.io/documentation/
------------------------------------------------------------------

veafOpposition = {}

-------------------------------------------------------------------------------------------------------------------------------------------------------------
-- Global settings. Stores the script constants
-------------------------------------------------------------------------------------------------------------------------------------------------------------

--- Identifier. All output in DCS.log will start with this.
veafOpposition.Id = "OPPOSITION"

-- trace level, specific to this module (uncomment for debugging)
--veafOpposition.LogLevel = "trace"

veaf.loggers.new(veafOpposition.Id, veafOpposition.LogLevel)

veafOpposition.FOLLOW_OFF = "off"
veafOpposition.FOLLOW_PLAYERS = "players"
veafOpposition.FOLLOW_AIRBORNE = "airborne"

--- How often the followed count is re-read, in seconds.
veafOpposition.SecondsBetweenChecks = 60

--- How long a lower count must hold before the level drops, in seconds.
veafOpposition.DEFAULT_lowerAfter = 300

veafOpposition.MarkerKeyphrase = "_opposition"

veafOpposition.RadioMenuName = "menu.opposition.root"

-------------------------------------------------------------------------------------------------------------------------------------------------------------
-- State
-------------------------------------------------------------------------------------------------------------------------------------------------------------

--- nil until a mission declares an `opposition:` block: the QRAs then scale on their zone alone.
veafOpposition.enabled = false
veafOpposition.level = nil
veafOpposition.follow = veafOpposition.FOLLOW_OFF
veafOpposition.lowerAfter = veafOpposition.DEFAULT_lowerAfter
veafOpposition.playersCoalition = coalition.side.BLUE
--- when the followed count first went below the level, nil while it is not below
veafOpposition.lowerSince = nil
veafOpposition.rootPath = nil
veafOpposition.scheduled = false

-------------------------------------------------------------------------------------------------------------------------------------------------------------
-- Level
-------------------------------------------------------------------------------------------------------------------------------------------------------------

--- Whether the mission declared an opposition level at all.
---@return boolean
function veafOpposition.isEnabled()
  return veafOpposition.enabled
end

--- The number of player aircraft the opposition is sized for, nil when the mission sets none.
---@return number|nil
function veafOpposition.getLevel()
  return veafOpposition.level
end

local function _followName(mode)
  if mode == veafOpposition.FOLLOW_PLAYERS then
    return veaf.t("opposition.follow.players")
  elseif mode == veafOpposition.FOLLOW_AIRBORNE then
    return veaf.t("opposition.follow.airborne")
  end
  return veaf.t("opposition.follow.off")
end

--- Tell everybody what the opposition is sized for now.
function veafOpposition.announce()
  if veafOpposition.level then
    trigger.action.outText(veaf.t("opposition.level", veafOpposition.level, _followName(veafOpposition.follow)), 15)
  else
    trigger.action.outText(veaf.t("opposition.no_level"), 15)
  end
end

--- Set the level, and say so to everybody when it changes.
---@param level number a count of player aircraft; rounded down, never below 0
---@param silent boolean|nil true to change it without a message
---@return boolean whether the level changed
function veafOpposition.setLevel(level, silent)
  level = tonumber(level)
  if not level then
    return false
  end
  level = math.max(0, math.floor(level))
  veafOpposition.lowerSince = nil
  if level == veafOpposition.level then
    return false
  end
  veaf.loggers.get(veafOpposition.Id):info("opposition level %s -> %s", veaf.p(veafOpposition.level), level)
  veafOpposition.level = level
  if not silent then
    veafOpposition.announce()
  end
  return true
end

-------------------------------------------------------------------------------------------------------------------------------------------------------------
-- Following the players
-------------------------------------------------------------------------------------------------------------------------------------------------------------

--- The players of the counted coalition, all of them or only the airborne ones.
---@param airborneOnly boolean
---@return number
function veafOpposition.countPlayers(airborneOnly)
  local count = 0
  for _, unit in pairs(coalition.getPlayers(veafOpposition.playersCoalition) or {}) do
    if unit and unit:isExist() and (not airborneOnly or unit:inAir()) then
      count = count + 1
    end
  end
  return count
end

--- The count the level follows, nil when it follows nothing.
---@return number|nil
function veafOpposition.measure()
  if veafOpposition.follow == veafOpposition.FOLLOW_PLAYERS then
    return veafOpposition.countPlayers(false)
  elseif veafOpposition.follow == veafOpposition.FOLLOW_AIRBORNE then
    return veafOpposition.countPlayers(true)
  end
  return nil
end

--- Move the level towards a fresh count: up at once, down once the count has been lower for `lowerAfter`.
---@param count number the count just measured
---@param now number the mission time of the measure
---@return boolean whether the level changed
function veafOpposition.follows(count, now)
  local level = veafOpposition.level
  if level == nil or count > level then
    return veafOpposition.setLevel(count)
  end
  if count == level then
    veafOpposition.lowerSince = nil
    return false
  end
  if not veafOpposition.lowerSince then
    veafOpposition.lowerSince = now
    return false
  end
  if now - veafOpposition.lowerSince >= veafOpposition.lowerAfter then
    return veafOpposition.setLevel(count)
  end
  return false
end

--- One beat: re-read the count when the level follows one, and reschedule.
function veafOpposition.check()
  veafOpposition.scheduled = false
  if veafOpposition.follow == veafOpposition.FOLLOW_OFF then
    return
  end
  local count = veafOpposition.measure()
  if count then
    veafOpposition.follows(count, timer.getTime())
  end
  veafOpposition.scheduled = true
  veaf.scheduleFunction(veafOpposition.check, {}, timer.getTime() + veafOpposition.SecondsBetweenChecks)
end

--- Follow the players connected, the players airborne, or nothing (the level then stays where it is).
---@param mode string FOLLOW_OFF, FOLLOW_PLAYERS or FOLLOW_AIRBORNE
---@return boolean whether the mode is one of them
function veafOpposition.setFollow(mode)
  if mode ~= veafOpposition.FOLLOW_OFF and mode ~= veafOpposition.FOLLOW_PLAYERS and mode ~= veafOpposition.FOLLOW_AIRBORNE then
    return false
  end
  veafOpposition.follow = mode
  veafOpposition.lowerSince = nil
  if mode ~= veafOpposition.FOLLOW_OFF then
    -- a fresh count right away rather than after a whole beat, through the hysteresis all the same:
    -- a server still empty when the mission starts must not undo the level it was generated with
    local count = veafOpposition.measure()
    if count then
      veafOpposition.follows(count, timer.getTime())
    end
    if not veafOpposition.scheduled then
      veafOpposition.scheduled = true
      veaf.scheduleFunction(veafOpposition.check, {}, timer.getTime() + veafOpposition.SecondsBetweenChecks)
    end
  end
  return true
end

-------------------------------------------------------------------------------------------------------------------------------------------------------------
-- Commands: the marker and the radio menu
-------------------------------------------------------------------------------------------------------------------------------------------------------------

--- Apply one `_opposition` argument: a number fixes the level, a follow mode follows, nothing says it.
---@param argument string|nil
---@return boolean whether the argument was understood
function veafOpposition.command(argument)
  argument = argument and argument:lower() or ""
  if argument == "" then
    veafOpposition.announce()
    return true
  end
  local level = tonumber(argument)
  if level then
    veafOpposition.setFollow(veafOpposition.FOLLOW_OFF)
    if not veafOpposition.setLevel(level) then
      veafOpposition.announce()
    end
    return true
  end
  if veafOpposition.setFollow(argument) then
    veafOpposition.announce()
    return true
  end
  trigger.action.outText(veaf.t("opposition.usage"), 15)
  return false
end

--- The `_opposition [n|players|airborne|off]` marker.
function veafOpposition.handleMarker(_, event)
  local text = event and event.text
  if type(text) ~= "string" then
    return false
  end
  local argument = text:lower():match("^%s*" .. veafOpposition.MarkerKeyphrase .. "%s*(%S*)")
  if argument == nil then
    return false
  end
  veafOpposition.command(argument)
  return true
end

function veafOpposition.radioChangeLevel(delta)
  veafOpposition.setFollow(veafOpposition.FOLLOW_OFF)
  veafOpposition.setLevel((veafOpposition.level or 0) + delta)
end

function veafOpposition.radioFollow(mode)
  veafOpposition.setFollow(mode)
  veafOpposition.announce()
end

function veafOpposition.buildRadioMenu()
  veafOpposition.rootPath = veafRadio.addMenu(veaf.t(veafOpposition.RadioMenuName))
  veafRadio.addCommandToSubmenu(
    veaf.t("menu.opposition.show"),
    veafOpposition.rootPath,
    veafOpposition.announce,
    nil,
    veafRadio.USAGE_ForAll
  )
  veafRadio.addSecuredCommandToSubmenu(
    veaf.t("menu.opposition.raise"),
    veafOpposition.rootPath,
    veafOpposition.radioChangeLevel,
    1,
    veafRadio.USAGE_ForAll
  )
  veafRadio.addSecuredCommandToSubmenu(
    veaf.t("menu.opposition.lower"),
    veafOpposition.rootPath,
    veafOpposition.radioChangeLevel,
    -1,
    veafRadio.USAGE_ForAll
  )
  for _, mode in ipairs({ veafOpposition.FOLLOW_PLAYERS, veafOpposition.FOLLOW_AIRBORNE, veafOpposition.FOLLOW_OFF }) do
    veafRadio.addSecuredCommandToSubmenu(
      veaf.t("menu.opposition.follow", _followName(mode)),
      veafOpposition.rootPath,
      veafOpposition.radioFollow,
      mode,
      veafRadio.USAGE_ForAll
    )
  end
  veafRadio.refreshRadioMenu()
end

-------------------------------------------------------------------------------------------------------------------------------------------------------------
-- Initialization
-------------------------------------------------------------------------------------------------------------------------------------------------------------

--- Take the mission's `opposition:` block. Called before the modules initialize, so a combat mission
--- building its radio menu knows there is a level to offer.
---@param config table { level = number|nil, follow = string|nil, lowerAfter = number|nil, playersCoalition = number|nil }
function veafOpposition.configure(config)
  config = config or {}
  veafOpposition.enabled = true
  veafOpposition.level = nil
  veafOpposition.lowerSince = nil
  if config.level ~= nil then
    veafOpposition.setLevel(config.level, true)
  end
  veafOpposition.follow = config.follow or veafOpposition.FOLLOW_OFF
  veafOpposition.lowerAfter = config.lowerAfter or veafOpposition.DEFAULT_lowerAfter
  veafOpposition.playersCoalition = config.playersCoalition or coalition.side.BLUE
end

--- The marker, the radio menu, and the beat when the level follows a count.
function veafOpposition.initialize()
  veaf.loggers.get(veafOpposition.Id):info("Initializing module")
  veafCommands.registerCommandHandler(
    veafOpposition.handleMarker,
    veafCommands.PRIORITY_RADIO,
    "SENIOR_PILOT",
    veafOpposition.MarkerKeyphrase
  )
  veafOpposition.buildRadioMenu()
  if veafOpposition.follow ~= veafOpposition.FOLLOW_OFF then
    veafOpposition.setFollow(veafOpposition.follow)
  end
end
