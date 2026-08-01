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
veafAssist.PICTURE_SIZE = 20
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

--- Read an animation argument and compare it against the step's window.
veafAssist.registerCheck("argument", function(unit, step)
  local check = step.check
  if not (unit and check and check.argument) then
    return false
  end
  local ok, value = pcall(unit.getDrawArgumentValue, unit, check.argument)
  if not ok or type(value) ~= "number" then
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

--- Whether the native mission-environment functions this module needs exist.
--- Checked once at initialisation rather than on every tick.
function veafAssist.nativeFunctionsAvailable()
  return type(a_cockpit_highlight) == "function"
    and type(a_cockpit_remove_highlight) == "function"
    and type(a_out_picture_u) == "function"
    and type(a_out_picture_stop) == "function"
end

--- Box a cockpit element, replacing whatever this session was boxing.
local function highlightElement(session, element)
  if session.highlighted == element then
    return
  end
  if session.highlighted then
    a_cockpit_remove_highlight(session.highlightId)
  end
  session.highlighted = element
  if element then
    a_cockpit_highlight(session.highlightId, element)
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
  a_out_picture_u(
    unit:getID(),
    getValueResourceByKey(resource),
    veafAssist.PICTURE_DURATION,
    veafAssist.PICTURE_CLEAR_VIEW,
    veafAssist.PICTURE_START_DELAY,
    veafAssist.PICTURE_HORIZONTAL_ALIGN,
    veafAssist.PICTURE_VERTICAL_ALIGN,
    veafAssist.PICTURE_SIZE,
    veafAssist.PICTURE_SIZE_UNITS
  )
end

--- Take the picture down and forget which state was shown.
local function hidePicture(session)
  if session.pictureState ~= nil then
    a_out_picture_stop()
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

--- End a session, clearing everything it owns.
local function closeSession(session)
  highlightElement(session, nil)
  hidePicture(session)
  veafAssist.sessions[session.unitName] = nil
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
  for unitName, session in pairs(veafAssist.sessions) do
    updateSession(unitName, session)
  end
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
-- initialisation
-------------------------------------------------------------------------------------------------------------------------------------------------------------

function veafAssist.initialize()
  veafAssist.available = veafAssist.nativeFunctionsAvailable()
  if not veafAssist.available then
    -- Detected once, here: throwing on every tick would flood the log and the
    -- module would still do nothing useful.
    veaf.loggers.get(veafAssist.Id):warn(
      "the cockpit functions (a_cockpit_highlight / a_out_picture_u) are not available in this environment; guided checklists are disabled"
    )
    return
  end

  mist.scheduleFunction(veafAssist.loop, {}, timer.getTime() + veafAssist.DELAY_BETWEEN_CHECKS)

  veafAssist.initialized = true
  veaf.loggers.get(veafAssist.Id):info("Guided assistance has been initialized")
end

veaf.loggers.get(veafAssist.Id):info(veaf.loggers.get(veafAssist.Id):getVersionInfo())

veaf.registerModule(veafAssist.Id, veafAssist.initialize, { enable = true }, 145)
