------------------------------------------------------------------
-- VEAF combat log for DCS World
-- By Zip (2026)
--
-- Features:
-- ---------
-- * Writes every shot, hit and kill of the mission to a file, one JSON object per line, for a debrief
--   that knows who fired what at whom (FEAT-COMBAT-LOG). The Tacview of 2026-10-29 had to guess: an ACMI
--   names no shooter, records no destruction, and showed none of the AH-64s' gun.
-- * Reads the DCS events S_EVENT_SHOT, S_EVENT_HIT, S_EVENT_KILL, S_EVENT_SHOOTING_START and
--   S_EVENT_SHOOTING_END (guns), with the shooter, its player, the weapon and the target. A gun burst is
--   counted in rounds, from the unit's shells at the start and at the end of the burst.
-- * The file is `veaf-combat-log-<date>-<time>.jsonl` in `VEAF_EXPORT_DIR` when it is set, else in the
--   DCS write folder (`Saved Games\DCS...`), as `veaf.exportAsJson` does. `veaf-tools combat-log` turns
--   it into a recap per pilot.
-- * Each line also says what DCS handed over (`weapon_object`, `weapon_name`), so the file itself measures
--   what DCS gives for a gun's shells (DCS-SESSION-TODO.md, R54).
--
-- See the documentation : https://veaf.github.io/documentation/
------------------------------------------------------------------

veafCombatLog = {}

-------------------------------------------------------------------------------------------------------------------------------------------------------------
-- Global settings. Stores the script constants
-------------------------------------------------------------------------------------------------------------------------------------------------------------

--- Identifier. All output in DCS.log will start with this.
veafCombatLog.Id = "COMBATLOG"

-- trace level, specific to this module (uncomment for debugging)
--veafCombatLog.LogLevel = "trace"

veaf.loggers.new(veafCombatLog.Id, veafCombatLog.LogLevel)

--- The events written, by DCS id, under the name each line carries.
veafCombatLog.EVENTS = {
  [world.event.S_EVENT_SHOT] = "shot",
  [world.event.S_EVENT_HIT] = "hit",
  [world.event.S_EVENT_KILL] = "kill",
  [world.event.S_EVENT_SHOOTING_START] = "shooting_start",
  [world.event.S_EVENT_SHOOTING_END] = "shooting_end",
}

--- Where the file goes, ending with a separator; nil asks `VEAF_EXPORT_DIR`, then the DCS write folder.
veafCombatLog.Directory = nil

--- How often the file is flushed, in seconds. Not at every line: a gun run raises one hit per shell, and a
--- synchronous flush each time runs on the simulation's thread. A crash loses at most this much.
veafCombatLog.SecondsBetweenFlushes = 10

-------------------------------------------------------------------------------------------------------------------------------------------------------------
-- State
-------------------------------------------------------------------------------------------------------------------------------------------------------------

--- The open file, nil when nothing can be written (a sanitized scripting environment).
veafCombatLog.file = nil
veafCombatLog.path = nil
--- The shells a unit carried when its burst started, by unit name.
veafCombatLog.burstShells = {}

-------------------------------------------------------------------------------------------------------------------------------------------------------------
-- Reading an event
-------------------------------------------------------------------------------------------------------------------------------------------------------------

--- Ask a DCS object something, nil when it cannot answer: a dead unit raises on most questions.
local function ask(object, method, ...)
  if type(object) ~= "table" or object[method] == nil then
    return nil
  end
  local ok, value = pcall(object[method], object, ...)
  if ok then
    return value
  end
  return nil
end

--- What a line says of an object — a unit, a static, a weapon, a piece of scenery. Every field may be
--- missing: some shells' initiators are nameless (`known-limitations`, a-convoy-drives-through-an-ambush).
--- @param object table|nil the DCS object
--- @return table|nil the description, nil without an object
function veafCombatLog.describe(object)
  if object == nil then
    return nil
  end
  local described = {
    name = ask(object, "getName"),
    type = ask(object, "getTypeName"),
    coalition = ask(object, "getCoalition"),
    player = ask(object, "getPlayerName"),
  }
  local group = ask(object, "getGroup")
  if group then
    described.group = ask(group, "getName")
  end
  return described
end

--- The shells a unit carries, summed over its ammunition of category `Weapon.Category.SHELL`.
--- @return number|nil nil when the unit answers nothing
function veafCombatLog.shells(unit)
  local ammo = ask(unit, "getAmmo")
  if ammo == nil then
    return nil
  end
  local total = 0
  for _, entry in pairs(ammo) do
    local desc = entry.desc or {}
    if desc.category == Weapon.Category.SHELL then
      total = total + (entry.count or 0)
    end
  end
  return total
end

--- One line of the log for an event, nil for an event the module does not write.
function veafCombatLog.record(event)
  local kind = veafCombatLog.EVENTS[event.id]
  if not kind then
    return nil
  end
  local weapon = event.weapon
  local line = {
    t = event.time,
    event = kind,
    shooter = veafCombatLog.describe(event.initiator),
    target = veafCombatLog.describe(event.target),
    weapon = ask(weapon, "getTypeName") or event.weapon_name,
    -- what DCS handed over, so the file measures it: a gun's shells may come with no Weapon object
    weapon_object = weapon ~= nil,
    weapon_name = event.weapon_name,
  }
  if kind == "shot" then
    -- S_EVENT_SHOT carries no target; the weapon knows the one it was launched at, when it is guided
    line.target = veafCombatLog.describe(ask(weapon, "getTarget"))
  end
  local unitName = line.shooter and line.shooter.name
  if unitName and kind == "shooting_start" then
    veafCombatLog.burstShells[unitName] = veafCombatLog.shells(event.initiator)
  elseif unitName and kind == "shooting_end" then
    local before = veafCombatLog.burstShells[unitName]
    local after = veafCombatLog.shells(event.initiator)
    if before and after then
      line.rounds = before - after
    end
    veafCombatLog.burstShells[unitName] = nil
  end
  return line
end

-------------------------------------------------------------------------------------------------------------------------------------------------------------
-- Writing
-------------------------------------------------------------------------------------------------------------------------------------------------------------

--- A standard library the mission scripting environment may have removed, or the server's copy of it.
local function library(name)
  if _G[name] then
    return _G[name]
  end
  if SERVER_CONFIG and SERVER_CONFIG.getModule then
    return SERVER_CONFIG.getModule(name)
  end
  return nil
end

--- The folder the file goes into, ending with a separator; nil when nothing says where.
function veafCombatLog.directory()
  if veafCombatLog.Directory then
    return veafCombatLog.Directory
  end
  local l_os = library("os")
  local exportDir = l_os and l_os.getenv("VEAF_EXPORT_DIR")
  if exportDir then
    return exportDir .. "\\"
  end
  local l_lfs = library("lfs")
  return l_lfs and l_lfs.writedir() or nil
end

function veafCombatLog.write(line)
  if not veafCombatLog.file then
    return
  end
  veafCombatLog.file:write(veaf.json.stringify(line) .. "\n")
end

--- The flush beat; stops once the file is closed.
function veafCombatLog.flush()
  if not veafCombatLog.file then
    return nil
  end
  veafCombatLog.file:flush()
  return timer.getTime() + veafCombatLog.SecondsBetweenFlushes
end

function veafCombatLog.close()
  if veafCombatLog.file then
    veafCombatLog.file:close()
    veafCombatLog.file = nil
  end
end

veafCombatLog.eventHandler = {}

function veafCombatLog.eventHandler:onEvent(event)
  if event == nil then
    return
  end
  if event.id == world.event.S_EVENT_MISSION_END then
    veafCombatLog.close()
    return
  end
  local ok, line = pcall(veafCombatLog.record, event)
  if not ok then
    veaf.loggers.get(veafCombatLog.Id):error("cannot read event %s: %s", veaf.p(event.id), veaf.p(line))
    return
  end
  if line then
    veafCombatLog.write(line)
  end
end

--- Opens the file and starts listening. Says once, and writes nothing, when the scripting environment cannot
--- write files: DCS's default MissionScripting.lua removes `io` and `lfs`.
function veafCombatLog.initialize()
  veaf.loggers.get(veafCombatLog.Id):info("Initializing module")
  if veafCombatLog.file then
    return
  end
  local l_io, l_os = library("io"), library("os")
  local directory = veafCombatLog.directory()
  if not (l_io and l_os and directory) then
    veaf.loggers.get(veafCombatLog.Id):warn("no io/os/lfs in this scripting environment: the combat log is not written")
    return
  end
  veafCombatLog.path = directory .. "veaf-combat-log-" .. l_os.date("%Y%m%d-%H%M%S") .. ".jsonl"
  veafCombatLog.file = l_io.open(veafCombatLog.path, "a")
  if not veafCombatLog.file then
    veaf.loggers.get(veafCombatLog.Id):warn("cannot open %s: the combat log is not written", veafCombatLog.path)
    return
  end
  local mission = env.mission or {}
  veafCombatLog.write({
    t = timer.getTime(),
    event = "start",
    theatre = mission.theatre,
    date = mission.date,
    start_time = mission.start_time,
    real_time = l_os.date("%Y-%m-%d %H:%M:%S"),
  })
  world.addEventHandler(veafCombatLog.eventHandler)
  timer.scheduleFunction(veafCombatLog.flush, nil, timer.getTime() + veafCombatLog.SecondsBetweenFlushes)
  veaf.loggers.get(veafCombatLog.Id):info("writing %s", veafCombatLog.path)
end

veaf.registerModule(veafCombatLog.Id, veafCombatLog.initialize, { enable = true }, 235)
