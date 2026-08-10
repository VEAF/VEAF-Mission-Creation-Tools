------------------------------------------------------------------
-- VEAF spawn text parser for DCS World
-- Extracted from veafSpawnCore.lua — parse spawn command text into options tables.
--
-- See the documentation : https://veaf.github.io/documentation/
------------------------------------------------------------------

-------------------------------------------------------------------------------------------------------------------------------------------------------------
-- Analyse the mark text and extract keywords.
-------------------------------------------------------------------------------------------------------------------------------------------------------------

-- Parameter rules: the data-driven replacement for the long if/elseif chain that
-- used to parse mark-text keywords. Each rule lists the key(s) it handles and an
-- `apply(options, val)` mutator; an optional `when(options)` predicate gates
-- context-specific rules (e.g. "name" sets cargoType only for a cargo command).
-- Rules are applied in order and ALL matching rules run, exactly reproducing the
-- original chained-`if` semantics. The recognized-key set (for typo hints,
-- UXPILOT-003) is derived from these rules, so there is a single source of truth.

--- Apply a numeric marker parameter, **keeping the existing default when it is unusable**.
---
--- VMR-025: this used to assign whatever `getRandomizableNumeric` returned, including nil. A
--- player writing `multiplier banana` therefore set `options.multiplier = nil`, and the spawn
--- died downstream on `for i = 1, options.multiplier do` — a runtime error from a typo. A
--- *valueless* keyword was worse: the conversion itself raised, because it reaches
--- `string.find(val, "%-")` after `tonumber` returns nil.
---
--- Fixed here rather than on `multiplier`, since every numeric spawn keyword shares this.
local function _num(field)
  return function(options, val)
    if val == nil then
      return
    end
    local _converted = veaf.getRandomizableNumeric(val)
    if _converted ~= nil then
      options[field] = _converted
    end
  end
end

local function _str(field)
  return function(options, val)
    options[field] = val
  end
end

local function _flag(field)
  return function(options)
    options[field] = true
  end
end

local function _numNonNegative(field)
  return function(options, val)
    local nVal = veaf.getRandomizableNumeric(val)
    if nVal >= 0 then
      options[field] = nVal
    end
  end
end

veafSpawn.ParameterRules = {
  { keys = { "unitname" }, apply = _str("unitName") },
  { keys = { "name" }, apply = _str("name") },
  { keys = { "czname" }, apply = _str("czName") },
  {
    keys = { "destination", "dest" },
    apply = function(options, val)
      options.destination = val
      options.AlarmState = 0 -- leave on auto: some units won't move at alarm state red
      options.spacing = 1 -- compress the convoy so it isn't extremely long at departure
      options.radius = 1 -- spawn exactly on the marker (avoid spawning in trees etc.)
    end,
  },
  { keys = { "isconvoy" }, apply = _flag("convoy") },
  { keys = { "patrol" }, apply = _flag("patrol") },
  { keys = { "offroad" }, apply = _flag("offroad") },
  {
    keys = { "skynet" },
    apply = function(options, val)
      options.skynet = val:lower()
      if options.skynet == "" or options.skynet == "true" then
        options.skynet = true
      elseif options.skynet == "false" then
        options.skynet = false
      end
    end,
  },
  { keys = { "ewr" }, apply = _flag("forceEwr") },
  {
    keys = { "pointdefense" },
    apply = function(options, val)
      options.pointDefense = true
      if val ~= "" then
        options.pointDefense = tostring(val)
      end
    end,
  },
  {
    -- to be placed after skynet: SAMs in the skynet network work better at alarm
    -- state red, so AlarmState defaults to 2 (red) when skynet is enabled.
    keys = { "alarm" },
    apply = function(options, val)
      if (val == "0" or val == "2" or val == "1") and not options.skynet then
        options.AlarmState = tonumber(val)
      end
    end,
  },
  { keys = { "radius" }, apply = _num("radius") },
  { keys = { "spacing" }, apply = _num("spacing") },
  { keys = { "multiplier" }, apply = _num("multiplier") },
  { keys = { "alt" }, apply = _num("altitude") },
  { keys = { "altdelta" }, apply = _num("altitudedelta") },
  { keys = { "speed" }, apply = _num("speed") },
  { keys = { "capradius" }, apply = _num("capradius") },
  { keys = { "shells" }, apply = _num("shells") },
  { keys = { "hdg", "heading" }, apply = _num("heading") },
  {
    keys = { "country" },
    apply = function(options, val)
      options.country = val:upper()
    end,
  },
  {
    keys = { "side" },
    apply = function(options, val)
      if val:upper() == "BLUE" then
        options.side = veafCasMission.SIDE_BLUE
      else
        options.side = veafCasMission.SIDE_RED
      end
    end,
  },
  { keys = { "password" }, apply = _str("password") },
  { keys = { "power" }, apply = _num("power") },
  {
    -- VMR-102: an undialable code keeps the command's default (1688 for afac/jtac), the same
    -- way `_num` keeps a default it cannot parse. Installing the code but not the frequency
    -- would have left the JTAC lasing on something no aircraft can enter, and silently.
    keys = { "laser" },
    apply = function(options, val)
      local nVal = veaf.getRandomizableNumeric(val)
      local frequency = veafSpawn.convertLaserToFreq(nVal)
      if frequency then
        options.freq = frequency
        options.laserCode = nVal
      end
    end,
  },
  { keys = { "freq" }, apply = _str("freq") },
  { keys = { "mod" }, apply = _str("mod") },
  { keys = { "band" }, apply = _str("tacanBand") },
  { keys = { "code" }, apply = _str("tacanCode") },
  { keys = { "channel" }, apply = _num("tacanChannel") },
  { keys = { "arrow" }, apply = _flag("drawArrow") },
  { keys = { "fill" }, apply = _str("drawFillColor") },
  {
    keys = { "color" },
    apply = function(options, val)
      options.drawColor = val
      if val:lower() == "red" then
        options.smokeColor = trigger.smokeColor.RED
      elseif val:lower() == "green" then
        options.smokeColor = trigger.smokeColor.GREEN
      elseif val:lower() == "orange" then
        options.smokeColor = trigger.smokeColor.ORANGE
      elseif val:lower() == "blue" then
        options.smokeColor = trigger.smokeColor.BLUE
      elseif val:lower() == "white" then
        options.smokeColor = trigger.smokeColor.WHITE
      end
    end,
  },
  { keys = { "skill" }, apply = _str("skill") },
  { keys = { "dist", "distance" }, apply = _num("distance") },
  {
    keys = { "name" },
    when = function(options)
      return options.cargo
    end,
    apply = _str("cargoType"),
  },
  {
    keys = { "weight" },
    when = function(options)
      return options.cargo
    end,
    apply = function(options, val)
      local nVal = veaf.getRandomizableNumeric(val)
      if nVal >= 0 and nVal <= veafSpawn.cargoWeightBiasRange then
        options.cargoWeightBias = nVal
      elseif nVal > veafSpawn.cargoWeightBiasRange then
        options.cargoWeightBias = veafSpawn.cargoWeightBiasRange
      elseif nVal < 0 then
        options.cargoWeightBias = 0
      end
    end,
  },
  { keys = { "type" }, apply = _str("type") },
  {
    keys = { "nofarpmarkers" },
    when = function(options)
      return options.farp
    end,
    apply = _flag("noFarpMarkers"),
  },
  {
    keys = { "smoke" },
    when = function(options)
      return options.cargo
    end,
    apply = _flag("cargoSmoke"),
  },
  { keys = { "size" }, apply = _num("size") },
  { keys = { "defense" }, apply = _numNonNegative("defense") },
  { keys = { "armor" }, apply = _numNonNegative("armor") },
  { keys = { "repeat" }, apply = _num("repeatCount") },
  { keys = { "delay" }, apply = _num("repeatDelay") },
  { keys = { "static" }, apply = _flag("forceStatic") },
  { keys = { "immortal" }, apply = _flag("immortal") },
  {
    keys = { "delayed" },
    apply = function(options, val)
      local nVal = veaf.getRandomizableNumeric(val)
      if nVal >= 0 then
        options.delayedStart = nVal
      else
        options.delayedStart = veafSpawn.MIN_REPEAT_DELAY
      end
    end,
  },
  { keys = { "showmfd" }, apply = _flag("showMFD") },
  { keys = { "disperse" }, apply = _numNonNegative("disperse") },
}

--- All parameter keys the mark-text parser recognizes, derived from ParameterRules
--- (single source of truth) and used to flag typos and suggest the nearest match
--- (UXPILOT-003). Each rule also gets a precomputed `_keyset` for O(1) matching.
veafSpawn._knownParameterKeySet = {}
veafSpawn.KnownParameterKeys = {}
for _, _rule in ipairs(veafSpawn.ParameterRules) do
  _rule._keyset = {}
  for _, _k in ipairs(_rule.keys) do
    _rule._keyset[_k] = true
    if not veafSpawn._knownParameterKeySet[_k] then
      veafSpawn._knownParameterKeySet[_k] = true
      table.insert(veafSpawn.KnownParameterKeys, _k)
    end
  end
end

--- Convert a DCS laser code to the JTAC radio frequency that carries it.
---
--- Returns nil for anything that is not a dialable code. VMR-102: the range check alone
--- (1111..1688) accepted codes such as 1201, 1210 or 1119, because DCS laser codes are
--- octal-like — each of the three digits after the leading 1 must be 1..8. Those produced a
--- plausible frequency, so a JTAC advertised a code no aircraft can enter.
function veafSpawn.convertLaserToFreq(laser)
  veaf.loggers.get(veafSpawn.Id):trace(string.format("convertLaserToFreq(laser=%s)", tostring(laser)))
  local laser = tonumber(laser)
  if laser and laser >= 1111 and laser <= 1688 and laser % 1 == 0 then
    local laserB = math.floor((laser - 1000) / 100)
    local laserCD = laser - 1000 - laserB * 100
    -- Only C and D are checked: the 1111..1688 range already pins B to 1..6.
    local laserC = math.floor(laserCD / 10)
    local laserD = laserCD % 10
    if laserC < 1 or laserC > 8 or laserD < 1 or laserD > 8 then
      veaf.loggers.get(veafSpawn.Id):info(string.format("laser code %s is not dialable: digits must each be 1..8", tostring(laser)))
      return nil
    end
    local frequency = tostring(30 + laserB + laserCD * 0.05)
    veaf.loggers.get(veafSpawn.Id):trace(string.format("laserB=%s", tostring(laserB)))
    veaf.loggers.get(veafSpawn.Id):trace(string.format("laserCD=%s", tostring(laserCD)))
    veaf.loggers.get(veafSpawn.Id):trace(string.format("frequency=%s", tostring(frequency)))
    return frequency
  else
    return nil
  end
end

--- Extract keywords from mark text.
-- Command descriptors: the data-driven replacement for the long if/elseif chain
-- that detected the command keyphrase and seeded its default options. `match` is
-- the (lower-cased) substring searched in the mark text; `init(options)` seeds the
-- defaults for that command. The list is ordered and the FIRST match wins, exactly
-- reproducing the original elseif chain.
veafSpawn.CommandDescriptors = {
  {
    match = veafSpawn.SpawnKeyphrase .. " unit",
    init = function(options)
      options.unit = true
      options.forceStatic = false
      options.immortal = false
      options.spacing = 5
    end,
  },
  {
    match = veafSpawn.SpawnKeyphrase .. " afac",
    init = function(options)
      options.afac = true
      options.laserCode = 1688
      options.freq = veafSpawn.convertLaserToFreq(1688)
      options.mod = "fm"
      options.immortal = false
      options.country = "USA" -- default country for the AFAC
      options.name = "mq-9" -- default AFAC spawned
    end,
  },
  {
    match = veafSpawn.SpawnKeyphrase .. " cap",
    init = function(options)
      options.cap = true
      options.speed = nil
      options.capradius = nil
    end,
  },
  {
    match = veafSpawn.SpawnKeyphrase .. " group",
    init = function(options)
      options.group = true
      options.forceStatic = false
      options.immortal = false
      options.spacing = 5
      options.size = math.random(7) + 8
      options.defense = math.random(5)
      options.armor = math.random(5)
      options.skynet = false
      options.forceEwr = false
      options.pointDefense = false
      options.isConvoy = false
      options.patrol = false
      options.offroad = false
    end,
  },
  {
    match = veafSpawn.SpawnKeyphrase .. " farp",
    init = function(options)
      options.farp = true
      options.noFarpMarkers = false
      options.type = nil
    end,
  },
  {
    match = veafSpawn.SpawnKeyphrase .. " fob",
    init = function(options)
      options.fob = true
    end,
  },
  {
    match = veafSpawn.SpawnKeyphrase .. " convoy",
    init = function(options)
      options.convoy = true
      options.size = 10
      options.defense = math.random(5)
      options.armor = math.random(5)
      options.spacing = 5
      options.isConvoy = false
      options.patrol = false
      options.offroad = false
      options.skynet = false
      options.forceEwr = false
      options.pointDefense = false
    end,
  },
  {
    match = veafSpawn.SpawnKeyphrase .. " infantrygroup",
    init = function(options)
      options.infantryGroup = true
      options.size = math.random(7) + 8
      options.defense = math.random(5)
      options.armor = math.random(5)
      options.spacing = 5
      options.skynet = false
      options.forceEwr = false
      options.pointDefense = false
      options.immortal = false
    end,
  },
  {
    match = veafSpawn.SpawnKeyphrase .. " armorgroup",
    init = function(options)
      options.armoredPlatoon = true
      options.size = math.random(7) + 8
      options.defense = math.random(5)
      options.armor = math.random(5)
      options.spacing = 5
      options.skynet = false
      options.forceEwr = false
      options.pointDefense = false
      options.immortal = false
    end,
  },
  {
    match = veafSpawn.SpawnKeyphrase .. " samgroup",
    init = function(options)
      options.airDefenseBattery = true
      options.size = math.random(7) + 8
      options.defense = math.random(5)
      options.armor = math.random(5)
      options.spacing = 5
      options.skynet = false
      options.forceEwr = false
      options.pointDefense = false
      options.immortal = false
    end,
  },
  {
    match = veafSpawn.SpawnKeyphrase .. " transportgroup",
    init = function(options)
      options.transportCompany = true
      options.size = math.random(2, 5)
      options.defense = math.random(5)
      options.armor = math.random(5)
      options.spacing = 5
      options.skynet = false
      options.forceEwr = false
      options.pointDefense = false
      options.immortal = false
    end,
  },
  {
    match = veafSpawn.SpawnKeyphrase .. " combatgroup",
    init = function(options)
      options.fullCombatGroup = true
      options.size = 1
      options.defense = math.random(5)
      options.armor = math.random(5)
      options.spacing = 5
      options.skynet = false
      options.forceEwr = false
      options.pointDefense = false
      options.immortal = false
    end,
  },
  {
    match = veafSpawn.SpawnKeyphrase .. " smoke",
    init = function(options)
      options.smoke = true
      options.smokeColor = trigger.smokeColor.RED
    end,
  },
  {
    match = veafSpawn.SpawnKeyphrase .. " flare",
    init = function(options)
      options.flare = true
      options.smokeColor = trigger.smokeColor.RED
    end,
  },
  {
    match = veafSpawn.SpawnKeyphrase .. " signal",
    init = function(options)
      options.signal = true
      options.smokeColor = trigger.smokeColor.RED
    end,
  },
  {
    match = veafSpawn.SpawnKeyphrase .. " cargo",
    init = function(options)
      options.cargo = true
      options.cargoType = "container_cargo"
      options.cargoWeightBias = 2
      options.cargoSmoke = false
    end,
  },
  {
    match = veafSpawn.SpawnKeyphrase .. " logistic",
    init = function(options)
      options.logistic = true
      options.cargoType = "container_cargo"
      options.cargoWeightBias = 2
      options.cargoSmoke = false
    end,
  },
  {
    match = veafSpawn.SpawnKeyphrase .. " bomb",
    init = function(options)
      options.bomb = true
      options.power = 100
      options.shells = 1
    end,
  },
  {
    match = veafSpawn.SpawnKeyphrase .. " jtac",
    init = function(options)
      options.role = "jtac"
      options.unit = true
      options.laserCode = 1688
      options.freq = veafSpawn.convertLaserToFreq(1688)
      options.mod = "fm"
      options.immortal = false
      options.spacing = 5
      options.country = "USA" -- default country for friendly JTAC
      options.name = "LUV HMMWV Jeep" -- default name for JTAC
      options.unitName = "JTAC1" -- default JTAC name (overwrites previous unit with same name)
    end,
  },
  {
    match = veafSpawn.SpawnKeyphrase .. " tacan",
    init = function(options)
      options.role = "tacan"
      options.unit = true
      options.tacanChannel = nil
      options.tacanBand = nil
      options.immortal = false
      options.spacing = 5
      options.country = "USA" -- default country for friendly tacan
      options.name = "TACAN_beacon" -- default name for tacan
      options.unitName = "TACAN TCN" -- default name (overwrites previous unit with same name)
    end,
  },
  {
    match = veafSpawn.DestroyKeyphrase,
    init = function(options)
      options.destroy = true
    end,
  },
  {
    match = veafSpawn.TeleportKeyphrase,
    init = function(options)
      options.teleport = true
    end,
  },
  {
    match = veafSpawn.DrawingKeyphrase .. " add",
    init = function(options)
      options.addDrawing = true
      options.drawColor = nil
      options.drawFillColor = nil
      options.drawArrow = nil
    end,
  },
  {
    match = veafSpawn.DrawingKeyphrase .. " erase",
    init = function(options)
      options.eraseDrawing = true
    end,
  },
  {
    match = veafSpawn.DrawingKeyphrase .. " square",
    init = function(options)
      options.drawSquare = true
      options.drawColor = nil
      options.drawFillColor = nil
      options.drawArrow = nil
    end,
  },
  {
    match = veafSpawn.DrawingKeyphrase .. " circle",
    init = function(options)
      options.drawCircle = true
      options.drawColor = nil
      options.drawFillColor = nil
      options.drawArrow = nil
    end,
  },
  {
    match = veafSpawn.MissionMasterKeyphrase .. " flagon",
    init = function(options)
      options.mmFlagOn = true
    end,
  },
  {
    match = veafSpawn.MissionMasterKeyphrase .. " flagoff",
    init = function(options)
      options.mmFlagOff = true
    end,
  },
  {
    match = veafSpawn.MissionMasterKeyphrase .. " getflag",
    init = function(options)
      options.mmGetFlag = true
    end,
  },
  {
    match = veafSpawn.MissionMasterKeyphrase .. " run",
    init = function(options)
      options.mmRun = true
    end,
  },
}

function veafSpawn.markTextAnalysis(text)
  veaf.loggers.get(veafSpawn.Id):trace(string.format("veafSpawn.markTextAnalysis(text=%s)", text))

  -- Option parameters extracted from the mark text.
  local options = {}

  -- common fields
  options.czName = nil
  options.name = ""
  options.unitName = nil
  options.country = nil
  options.side = nil
  options.altitude = 0
  options.altitudedelta = 0
  options.heading = 0
  options.multiplier = 1
  options.password = nil
  options.repeatCount = nil
  options.repeatDelay = nil
  options.delayedStart = 0
  options.showMFD = false
  options.AlarmState = 2
  options.disperse = 15
  options.shells = 1
  options.power = 100

  -- Detect the command keyphrase and seed its defaults (data-driven; see
  -- CommandDescriptors). First match wins, as the original elseif chain did.
  local textLower = text:lower()
  local matched = false
  for _, cmd in ipairs(veafSpawn.CommandDescriptors) do
    if textLower:find(cmd.match) then
      cmd.init(options)
      matched = true
      break
    end
  end
  if not matched then
    return nil
  end

  -- keywords are split by ","
  local keywords = veaf.split(text, ",")

  for _, keyphrase in pairs(keywords) do
    -- Split keyphrase by space. First one is the key and second, ... the parameter(s) until the next comma.
    local str = veaf.breakString(veaf.trim(keyphrase), " ")
    local key = str[1]
    local val = str[2] or ""

    -- Flag a parameter key we don't recognize (skip the command keyphrase itself,
    -- e.g. "_spawn") so the caller can hint the pilot about a likely typo.
    local keyLower = key:lower()
    if keyLower ~= "" and keyLower:sub(1, 1) ~= "_" and not veafSpawn._knownParameterKeySet[keyLower] then
      options.unknownParameters = options.unknownParameters or {}
      table.insert(options.unknownParameters, {
        key = key,
        suggestion = veaf.nearestMatch(keyLower, veafSpawn.KnownParameterKeys, 3),
      })
    end

    -- Apply every parameter rule whose key matches (data-driven; see ParameterRules).
    -- ALL matching rules run, in order, reproducing the original chained-if behaviour.
    for _, rule in ipairs(veafSpawn.ParameterRules) do
      if rule._keyset[keyLower] and (not rule.when or rule.when(options)) then
        veaf.loggers.get(veafSpawn.Id):trace(string.format("Keyword %s = %s", keyLower, tostring(val)))
        rule.apply(options, val)
      end
    end
  end

  -- check mandatory parameter "name" for command "group"
  if options.group and (not options.name or options.name == "") then
    return nil
  end

  -- check mandatory parameter "name" for command "unit"
  if options.unit and (not options.name or options.name == "") then
    return nil
  end

  -- check mandatory parameter "name" for all mission master commands
  if (options.mmFlagOff or options.mmFlagOn or options.mmRun) and (not options.name or options.name == "") then
    return nil
  end

  return options
end
