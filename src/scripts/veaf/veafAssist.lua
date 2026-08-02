------------------------------------------------------------------
-- VEAF guided-assistance script for DCS World
--
-- Features:
-- ---------
-- * Walks a pilot through a checklist: boxes the cockpit control the current
--   step needs, ticks the line as soon as that control reaches the right
--   position — or as soon as the pilot confirms it — and moves on.
-- * The checklists are data (registered by veafAssist.registerChecklist, which
--   the build emits from YAML); this module knows nothing about any aircraft.
-- * Two output channels with distinct roles: the generated image is the
--   persistent dashboard, short texts carry the events.
--
-- See the documentation : https://veaf.github.io/documentation/
------------------------------------------------------------------

veafAssist = {}

-------------------------------------------------------------------------------------------------------------------------------------------------------------
-- Global settings. Stores the script constants
-------------------------------------------------------------------------------------------------------------------------------------------------------------

--- Identifier. All output in DCS.log will start with this.
veafAssist.Id = "ASSIST"

--- Version.
veafAssist.Version = "1.0.0"

-- trace level, specific to this module
--veafAssist.LogLevel = "trace"

veaf.loggers.new(veafAssist.Id, veafAssist.LogLevel)

--- Delay between two evaluations of the running sessions, in seconds.
veafAssist.DELAY_BETWEEN_CHECKS = 2

--- How long the event texts stay on screen, in seconds.
veafAssist.MESSAGE_TIME = 10

--- First cockpit-highlight id handed out. Each assisted unit gets its own: a
--- single shared id would make two cockpits fight over the same box.
veafAssist.FIRST_HIGHLIGHT_ID = 100

--- a_out_picture_u display settings. Duration 0 keeps the picture up until
--- a_out_picture_stop (ED's own behaviour, DCSCORE-2754) — the whole persistent
--- checklist design rests on it.
veafAssist.PICTURE_DURATION = 0
veafAssist.PICTURE_CLEAR_VIEW = true
veafAssist.PICTURE_START_DELAY = 0
veafAssist.PICTURE_HORIZONTAL_ALIGN = "2" -- right
veafAssist.PICTURE_VERTICAL_ALIGN = "1" -- top
veafAssist.PICTURE_SIZE = 100
veafAssist.PICTURE_SIZE_UNITS = "0"

-------------------------------------------------------------------------------------------------------------------------------------------------------------
-- Do not change anything below unless you know what you are doing!
-------------------------------------------------------------------------------------------------------------------------------------------------------------

--- Registered checklists, by id.
veafAssist.checklists = {}

--- Registered checks, by name. A check is fn(unit, step, session) -> boolean.
veafAssist.checks = {}

--- Running sessions, by unit name.
veafAssist.sessions = {}

--- Next cockpit-highlight id to hand out.
veafAssist.nextHighlightId = veafAssist.FIRST_HIGHLIGHT_ID

--- Whether the native cockpit functions were found at initialisation.
veafAssist.available = false

veafAssist.initialized = false

-------------------------------------------------------------------------------------------------------------------------------------------------------------
-- Checklist and check registration
-------------------------------------------------------------------------------------------------------------------------------------------------------------

--- Declare a checklist. Called by the generated veaf-config.lua.
--- @param definition table — { id, title, aircraft, menu, images, steps }
function veafAssist.registerChecklist(definition)
  if not definition or not definition.id then
    veaf.loggers.get(veafAssist.Id):error("registerChecklist called without an id")
    return
  end
  -- Each step carries its own index: a check receives the step, not its position,
  -- and needs the index to look up per-step session state (a pilot confirmation).
  for index, step in ipairs(definition.steps or {}) do
    step.index = index
  end
  veafAssist.checklists[definition.id] = definition
  veaf.loggers
    .get(veafAssist.Id)
    :debug(string.format("registered checklist %s (%d steps)", tostring(definition.id), #(definition.steps or {})))
end

--- Register a named check.
--- @param name string   — the `check.type` a step declares
--- @param fn   function — fn(unit, step, session) -> boolean
function veafAssist.registerCheck(name, fn)
  veafAssist.checks[name] = fn
end

--- Cockpit parameters read this tick, so a checklist with several param steps parses
--- the engine's 19 KB dump once instead of once per step. Invalidated every loop.
veafAssist.paramCache = nil

--- Parse `list_cockpit_params()` into a name -> number table.
--- The dump is one `NAME:value` per line; a name may itself contain colons
--- (`ExternalFM:HumanInfo:AoA`), so the split is on the LAST colon.
local function readCockpitParams()
  if veafAssist.paramCache then
    return veafAssist.paramCache
  end
  -- list_cockpit_params lives in the trigger environment, like the a_* functions.
  local dump = veafAssist.inTriggerEnv("return list_cockpit_params()")
  if type(dump) ~= "string" then
    return nil
  end
  local params = {}
  for line in dump:gmatch("[^\r\n]+") do
    local name, value = line:match("^(.*):([^:]*)$")
    if name and tonumber(value) then
      params[name] = tonumber(value)
    end
  end
  veafAssist.paramCache = params
  return params
end

--- Read a live cockpit parameter and compare it against the step's window.
---
--- This reads what the aircraft *is*, not where its switches are: a control's position
--- cannot be read from the mission environment at all (measured in game — see
--- docs/exploration/DCS-COCKPIT-ASSISTANCE-API.md section 3). Altitude, speed, heading,
--- gear, canopy, flaps and fuel are published and live; switch positions are not.
veafAssist.registerCheck("cockpit_param", function(_, step)
  local check = step.check
  if not (check and check.param) then
    return false
  end
  local params = readCockpitParams()
  if not params then
    return false
  end
  local value = params[check.param]
  if type(value) ~= "number" then
    return false
  end
  return value >= check.min and value <= check.max
end)

--- Satisfied by a pilot confirmation recorded for that step.
veafAssist.registerCheck("confirm", function(_, step, session)
  return session ~= nil and session.confirmed[step.index] == true
end)

-------------------------------------------------------------------------------------------------------------------------------------------------------------
-- Cockpit primitives
-------------------------------------------------------------------------------------------------------------------------------------------------------------

--- Run a chunk of Lua in the TRIGGER environment and return what it returned.
---
--- The cockpit and picture primitives (a_cockpit_highlight, a_out_picture_u, …) do NOT
--- live in the environment VEAF scripts run in. Measured in game: from a mission script
--- `a_cockpit_highlight` is nil, while `net.dostring_in("mission", …)` reaches an
--- environment holding all 114 `a_*` functions — and, symmetrically, no `veaf` and no
--- `net`. The two are separate namespaces and this is the only bridge between them. It
--- is the same call TheUniversalMission makes for its own picture output.
---
--- **This requires `net`**, which a stock `MissionScripting.lua` sanitises away. The
--- module detects that at initialisation and disables itself rather than failing later.
local function inTriggerEnv(code)
  if type(net) ~= "table" or type(net.dostring_in) ~= "function" then
    return nil
  end
  local ok, result = pcall(net.dostring_in, "mission", code)
  if not ok then
    veaf.loggers.get(veafAssist.Id):warn(string.format("trigger-environment call failed: %s", tostring(result)))
    return nil
  end
  return result
end

veafAssist.inTriggerEnv = inTriggerEnv

--- Whether the primitives this module needs are reachable.
--- Checked once at initialisation rather than on every tick.
function veafAssist.nativeFunctionsAvailable()
  local probe = inTriggerEnv(
    'return type(a_cockpit_highlight) .. "/" .. type(a_cockpit_remove_highlight) .. "/" '
      .. '.. type(a_out_picture_u) .. "/" .. type(a_out_picture_stop) .. "/" .. type(getValueResourceByKey)'
  )
  return probe == "function/function/function/function/function"
end

--- Box a cockpit element, replacing whatever this session was boxing.
local function highlightElement(session, element)
  if session.highlighted == element then
    return
  end
  if session.highlighted then
    inTriggerEnv(string.format("a_cockpit_remove_highlight(%d)", session.highlightId))
  end
  session.highlighted = element
  if element then
    inTriggerEnv(string.format("a_cockpit_highlight(%d, %q)", session.highlightId, element))
  end
end

--- Show the picture of a progress state, unless the pilot hid it.
local function showPicture(session, unit, state)
  local images = session.checklist.images
  if not (images and session.pictureVisible) then
    return
  end
  local resource = images[state + 1]
  if not resource or session.pictureState == state then
    return
  end
  session.pictureState = state
  inTriggerEnv(
    string.format(
      "a_out_picture_u(%d, getValueResourceByKey(%q), %d, %s, %d, %q, %q, %d, %q)",
      unit:getID(),
      resource,
      veafAssist.PICTURE_DURATION,
      tostring(veafAssist.PICTURE_CLEAR_VIEW),
      veafAssist.PICTURE_START_DELAY,
      veafAssist.PICTURE_HORIZONTAL_ALIGN,
      veafAssist.PICTURE_VERTICAL_ALIGN,
      veafAssist.PICTURE_SIZE,
      veafAssist.PICTURE_SIZE_UNITS
    )
  )
end

--- Take the picture down and forget which state was shown.
local function hidePicture(session)
  if session.pictureState ~= nil then
    inTriggerEnv("a_out_picture_stop()")
    session.pictureState = nil
  end
end

-------------------------------------------------------------------------------------------------------------------------------------------------------------
-- Session mechanics
-------------------------------------------------------------------------------------------------------------------------------------------------------------

--- Run the check a step declares. An unknown check type never passes.
local function stepIsSatisfied(unit, step, session)
  local check = step.check
  if not check or not check.type then
    return false
  end
  local fn = veafAssist.checks[check.type]
  if not fn then
    veaf.loggers.get(veafAssist.Id):warn(string.format("unknown check type: %s", tostring(check.type)))
    return false
  end
  local ok, result = pcall(fn, unit, step, session)
  if not ok then
    veaf.loggers.get(veafAssist.Id):warn(string.format("check %s failed: %s", tostring(check.type), tostring(result)))
    return false
  end
  return result == true
end

--- Index of the first step still to do, or nil when the checklist is complete.
local function currentStepIndex(session)
  for index = 1, #session.checklist.steps do
    if not session.done[index] then
      return index
    end
  end
  return nil
end

--- Tick every step already satisfied when the session opens.
--- Free, since the checks read real state, and it makes the assistance usable by
--- a pilot who started half-way. Only done here: once a session is running, a
--- step is evaluated when it is the current one and stays ticked afterwards, so
--- a sequence that walks a switch through several positions (OFF → BATT → MAIN
--- PWR) does not un-tick the step it already passed.
local function tickAlreadySatisfiedSteps(unit, session)
  for index, step in ipairs(session.checklist.steps) do
    if stepIsSatisfied(unit, step, session) then
      session.done[index] = true
    end
  end
end

--- Send one of the module's short event texts to the assisted pilot.
local function tell(session, key, ...)
  veaf.outTextForUnit(session.unitName, veaf.t(key, ...), veafAssist.MESSAGE_TIME)
end

--- Label of a step, resolved through the runtime catalog at send time.
local function stepLabel(session, index)
  local step = session.checklist.steps[index]
  return step and veaf.t(step.label) or ""
end

--- Ask the radio menu to re-evaluate which entries this pilot should see.
--- The refresh is debounced by veafRadio, so calling it on every transition is cheap.
local function refreshMenu()
  if veafRadio and veafAssist.rootPath then
    veafRadio.refreshRadioMenu()
  end
end

--- End a session, clearing everything it owns.
local function closeSession(session)
  highlightElement(session, nil)
  hidePicture(session)
  veafAssist.sessions[session.unitName] = nil
  refreshMenu()
end

--- Advance a session to its current step, re-boxing and repainting as needed.
local function refreshSession(unit, session)
  local index = currentStepIndex(session)
  if index == nil then
    tell(session, "assist.completed", veaf.t(session.checklist.title))
    closeSession(session)
    return
  end
  if index == session.displayedIndex then
    return
  end
  session.displayedIndex = index
  -- The step changed, so "Confirm this step" may have just become relevant, or stopped
  -- being so.
  refreshMenu()
  -- Re-issue the highlight only when the target step changes: ED's own
  -- update_checklist guards on exactly this, and re-boxing every tick is
  -- wasteful and visually unstable.
  highlightElement(session, session.checklist.steps[index].element)
  showPicture(session, unit, index - 1)
end

--- Evaluate one running session.
local function updateSession(unitName, session)
  local unit = Unit.getByName(unitName)
  if not unit or (unit.isExist and not unit:isExist()) then
    -- The pilot left the slot or died: drop the session quietly, no error spam.
    veafAssist.sessions[unitName] = nil
    return
  end
  local index = currentStepIndex(session)
  if index and stepIsSatisfied(unit, session.checklist.steps[index], session) then
    session.done[index] = true
    tell(session, "assist.step_validated", stepLabel(session, index))
  end
  refreshSession(unit, session)
end

--- Main loop: evaluate every running session, then reschedule.
function veafAssist.loop()
  -- One snapshot of the cockpit parameters per tick, shared by every session and every
  -- step: the engine's dump is ~19 KB of text and parsing it per step would not scale.
  veafAssist.paramCache = nil
  for unitName, session in pairs(veafAssist.sessions) do
    updateSession(unitName, session)
  end
  veafAssist.paramCache = nil
  mist.scheduleFunction(veafAssist.loop, {}, timer.getTime() + veafAssist.DELAY_BETWEEN_CHECKS)
end

-------------------------------------------------------------------------------------------------------------------------------------------------------------
-- Public API
-------------------------------------------------------------------------------------------------------------------------------------------------------------

--- Checklists applicable to an aircraft type.
--- @param typeName string — the DCS type name
--- @return table — the matching checklist definitions
function veafAssist.checklistsForType(typeName)
  local result = {}
  for _, checklist in pairs(veafAssist.checklists) do
    for _, aircraft in ipairs(checklist.aircraft or {}) do
      if aircraft == typeName then
        table.insert(result, checklist)
        break
      end
    end
  end
  return result
end

--- Begin a checklist session for a pilot.
--- Starting one while another is already running for that pilot replaces it,
--- clearing the previous highlight and picture first.
--- @param unitName    string — the player's unit name
--- @param checklistId string — the checklist to walk
--- @return boolean — whether the session started
function veafAssist.start(unitName, checklistId)
  if not veafAssist.available then
    veaf.loggers.get(veafAssist.Id):warn("cannot start: the cockpit functions are not available")
    return false
  end
  local checklist = veafAssist.checklists[checklistId]
  if not checklist then
    veaf.loggers.get(veafAssist.Id):warn(string.format("unknown checklist: %s", tostring(checklistId)))
    return false
  end
  local unit = Unit.getByName(unitName)
  if not unit then
    return false
  end

  local running = veafAssist.sessions[unitName]
  if running then
    closeSession(running)
  end

  local session = {
    unitName = unitName,
    checklist = checklist,
    highlightId = veafAssist.nextHighlightId,
    done = {},
    confirmed = {},
    highlighted = nil,
    displayedIndex = nil,
    pictureVisible = true,
    pictureState = nil,
  }
  veafAssist.nextHighlightId = veafAssist.nextHighlightId + 1
  veafAssist.sessions[unitName] = session

  tickAlreadySatisfiedSteps(unit, session)
  tell(session, "assist.started", veaf.t(checklist.title))
  refreshSession(unit, session)
  refreshMenu()
  return true
end

--- Record the pilot's confirmation of the current step.
--- @param unitName string — the player's unit name
function veafAssist.confirmStep(unitName)
  local session = veafAssist.sessions[unitName]
  if not session then
    return false
  end
  local index = currentStepIndex(session)
  if not index then
    return false
  end
  session.confirmed[index] = true
  local unit = Unit.getByName(unitName)
  if unit then
    updateSession(unitName, session)
  end
  return true
end

--- Skip the current step.
--- A mis-measured argument window would otherwise strand the whole checklist
--- with no recourse; a skipped step is treated as passed from then on.
--- @param unitName string — the player's unit name
function veafAssist.skipStep(unitName)
  local session = veafAssist.sessions[unitName]
  if not session then
    return false
  end
  local index = currentStepIndex(session)
  if not index then
    return false
  end
  session.done[index] = true
  tell(session, "assist.step_skipped", stepLabel(session, index))
  local unit = Unit.getByName(unitName)
  if unit then
    refreshSession(unit, session)
  end
  return true
end

--- Hide or show the checklist picture.
--- @param unitName string — the player's unit name
function veafAssist.togglePicture(unitName)
  local session = veafAssist.sessions[unitName]
  if not session then
    return false
  end
  session.pictureVisible = not session.pictureVisible
  if session.pictureVisible then
    local unit = Unit.getByName(unitName)
    local state = (session.displayedIndex or 1) - 1
    if unit then
      showPicture(session, unit, state)
    end
  else
    hidePicture(session)
  end
  return session.pictureVisible
end

--- End a pilot's session, clearing the highlight and the picture.
--- @param unitName string — the player's unit name
function veafAssist.stop(unitName)
  local session = veafAssist.sessions[unitName]
  if not session then
    return false
  end
  closeSession(session)
  return true
end

-------------------------------------------------------------------------------------------------------------------------------------------------------------
-- Radio menu
--
-- One `Assistance` submenu, whose entries are per player group: a global entry would let
-- one pilot put a highlight in someone else's cockpit. Which entries a pilot actually
-- sees is decided by a `groupFilter` on each command rather than by rebuilding the tree,
-- so the menu follows the session state without the module ever removing what it added —
-- leftovers stack one duplicate per join, the bug FEAT-COMBATZONE-MENU-COALITION fixed.
-------------------------------------------------------------------------------------------------------------------------------------------------------------

--- The DCS type a player unit flies, or nil when the unit is gone.
local function typeOfUnit(unitName)
  local unit = Unit.getByName(unitName)
  if not (unit and unit.getTypeName) then
    return nil
  end
  local ok, typeName = pcall(unit.getTypeName, unit)
  return ok and typeName or nil
end

--- Whether a pilot can be offered a given checklist: nothing running, right aircraft.
function veafAssist.canStart(unitName, checklistId)
  if veafAssist.sessions[unitName] then
    return false
  end
  local checklist = veafAssist.checklists[checklistId]
  if not checklist then
    return false
  end
  local typeName = typeOfUnit(unitName)
  for _, aircraft in ipairs(checklist.aircraft or {}) do
    if aircraft == typeName then
      return true
    end
  end
  return false
end

--- Whether a pilot has a session running.
function veafAssist.isAssisted(unitName)
  return veafAssist.sessions[unitName] ~= nil
end

--- Whether the pilot's current step is one they have to confirm themselves.
--- An inert "Confirm" on an automatic step invites a press and a puzzled pilot.
function veafAssist.currentStepNeedsConfirmation(unitName)
  local session = veafAssist.sessions[unitName]
  if not session then
    return false
  end
  local index = currentStepIndex(session)
  local step = index and session.checklist.steps[index]
  return step ~= nil and step.check ~= nil and step.check.type == "confirm"
end

--- Menu label of a checklist: the `menu` slot, resolved through the catalog.
--- An unknown key comes back unchanged, so a mission maker's own slot still reads.
local function menuLabel(checklist)
  return veaf.t("assist.menu." .. tostring(checklist.menu))
end

--- Radio entry point: start. Carries the checklist id, so the builder hands over
--- { checklistId, unitName }.
function veafAssist.radioStart(parameters)
  local checklistId, unitName = veaf.safeUnpack(parameters)
  veafAssist.start(unitName, checklistId)
end

--- The contextual entries carry no parameter, so the builder hands over the unit name.
function veafAssist.radioConfirm(unitName)
  veafAssist.confirmStep(unitName)
end

function veafAssist.radioSkip(unitName)
  veafAssist.skipStep(unitName)
end

function veafAssist.radioTogglePicture(unitName)
  veafAssist.togglePicture(unitName)
end

function veafAssist.radioStop(unitName)
  veafAssist.stop(unitName)
end

--- Build the `Assistance` submenu. Nothing at all when the mission activates no
--- checklist: an empty menu is worse than no menu.
function veafAssist.buildRadioMenu()
  if not veafRadio or next(veafAssist.checklists) == nil then
    return
  end

  veafAssist.rootPath = veafRadio.addSubMenu(veaf.t("assist.menu.root"))

  -- Sorted by id so the menu order does not depend on table iteration order.
  local ids = {}
  for id in pairs(veafAssist.checklists) do
    table.insert(ids, id)
  end
  table.sort(ids)
  for _, id in ipairs(ids) do
    local checklist = veafAssist.checklists[id]
    local command =
      veafRadio.addCommandToSubmenu(menuLabel(checklist), veafAssist.rootPath, veafAssist.radioStart, id, veafRadio.USAGE_ForGroup)
    command.groupFilter = function(unitName)
      return veafAssist.canStart(unitName, id)
    end
  end

  -- The two entries a pilot presses over and over while walking a checklist sit at the
  -- TOP level, not inside `Assistance`: burying "confirm" one level down costs an extra
  -- keystroke on every single step, which adds up fast on a six-step procedure. They are
  -- only visible during a session, so they clutter nobody's menu the rest of the time —
  -- and their labels name the module, since they appear among unrelated entries.
  -- sortKey, not the label: "confirm" has to come before "skip", and in French the
  -- labels sort the other way round ("passer" before "valider"). The shared prefix keeps
  -- the pair together wherever "Assistance" lands among the other top-level entries.
  local topLevel = {
    {
      key = "assist.menu.confirm",
      sortKey = "Assistance 1",
      method = veafAssist.radioConfirm,
      filter = veafAssist.currentStepNeedsConfirmation,
    },
    {
      key = "assist.menu.skip",
      sortKey = "Assistance 2",
      method = veafAssist.radioSkip,
      filter = veafAssist.isAssisted,
    },
  }
  for _, entry in ipairs(topLevel) do
    local command = veafRadio.addCommandToSubmenu(veaf.t(entry.key), nil, entry.method, nil, veafRadio.USAGE_ForGroup)
    command.groupFilter = entry.filter
    command.sortKey = entry.sortKey
  end

  -- The occasional ones stay in the submenu.
  local contextual = {
    { key = "assist.menu.toggle_picture", method = veafAssist.radioTogglePicture, filter = veafAssist.isAssisted },
    { key = "assist.menu.stop", method = veafAssist.radioStop, filter = veafAssist.isAssisted },
  }
  for _, entry in ipairs(contextual) do
    local command = veafRadio.addCommandToSubmenu(veaf.t(entry.key), veafAssist.rootPath, entry.method, nil, veafRadio.USAGE_ForGroup)
    command.groupFilter = entry.filter
  end

  veafRadio.refreshRadioMenu()
end

-------------------------------------------------------------------------------------------------------------------------------------------------------------
-- initialisation
-------------------------------------------------------------------------------------------------------------------------------------------------------------

function veafAssist.initialize()
  veafAssist.available = veafAssist.nativeFunctionsAvailable()
  if not veafAssist.available then
    -- Detected once, here: throwing on every tick would flood the log and the
    -- module would still do nothing useful.
    if type(net) ~= "table" or type(net.dostring_in) ~= "function" then
      veaf.loggers.get(veafAssist.Id):warn(
        "guided checklists are disabled: net.dostring_in is not available. The cockpit primitives live in the "
          .. "trigger environment and this is the only bridge to it, so this mission's DCS needs a "
          .. "MissionScripting.lua with the sanitisation removed (the same tweak STTS and dcs-bridge require)."
      )
    else
      veaf.loggers.get(veafAssist.Id):warn(
        "guided checklists are disabled: the cockpit primitives (a_cockpit_highlight / a_out_picture_u) were not "
          .. "found in the trigger environment."
      )
    end
    return
  end

  veafAssist.buildRadioMenu()
  mist.scheduleFunction(veafAssist.loop, {}, timer.getTime() + veafAssist.DELAY_BETWEEN_CHECKS)

  veafAssist.initialized = true
  veaf.loggers.get(veafAssist.Id):info("Guided assistance has been initialized")
end

veaf.loggers.get(veafAssist.Id):info(veaf.loggers.get(veafAssist.Id):getVersionInfo())

veaf.registerModule(veafAssist.Id, veafAssist.initialize, { enable = true }, 145)
