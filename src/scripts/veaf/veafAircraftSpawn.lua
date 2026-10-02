------------------------------------------------------------------
-- VEAF aircraft spawn for DCS World
-- By zip (2026)
--
-- Features:
-- ---------
-- * Spawn an aircraft group with a role: the route it flies, the options it flies with, and what
--   watches over it once it is in the air
-- * Give a role to a group that is already flying
-- * Tell whether a group's own route already makes it engage aircraft
--
-- One way to do this for the whole framework (FEAT-AIRCRAFT-ROLES). Before it, `-cap` built its
-- route by hand, a QRA or an air wave cloned whatever the editor held, and a QRA group placed with a
-- single waypoint and no task reached the end of its route the moment it appeared and landed.
------------------------------------------------------------------

veafAircraftSpawn = {}

--- Identifier. All output in the log will start with this.
veafAircraftSpawn.Id = "AIRSPAWN"

-- trace level, specific to this module
--veafAircraftSpawn.LogLevel = "trace"

veaf.loggers.new(veafAircraftSpawn.Id, veafAircraftSpawn.LogLevel)

local NM = 1852

--- Length of a patrol leg, when the role is not told otherwise. The CAP's own default.
veafAircraftSpawn.DEFAULT_LEG_LENGTH = 20 * NM

--- Mach number a `zone_defense` patrol flies at when its template says nothing. The CAP's patrol speed.
veafAircraftSpawn.DEFAULT_PATROL_MACH = 0.63

--- Altitude a `zone_defense` patrol climbs to after taking off, in metres: the CAP's default 27 000 ft.
--- A take-off point says nothing about where the flight should patrol.
veafAircraftSpawn.DEFAULT_PATROL_ALTITUDE = 27000 * 0.3048

--- Editor group tasks a QRA or an air wave may give the `zone_defense` role to. Anything else — a
--- bomber wave, an assault helicopter, an escort — flies the route its mission maker wrote, even one
--- that engages no aircraft (David, 2026-10-02).
veafAircraftSpawn.ZONE_DEFENSE_TASKS = { CAP = true, Intercept = true }

--- Target types that make an engagement task an **air** engagement.
---
--- The DCS attribute names an `EngageTargets` or `EngageTargetsInZone` task can carry in
--- `targetTypes` for aircraft — the generic `Air`, `Planes` and `Helicopters`, and the finer ones the
--- CAP watchdog already ranks targets by. The build mirrors this list
--- (`mission_builder/aircraft_roles.py`), and a test compares the two.
veafAircraftSpawn.AIR_TARGET_TYPES = {
  "Air",
  "Planes",
  "Helicopters",
  "Fighters",
  "Multirole fighters",
  "Bombers",
  "Strategic bombers",
  "Battle airplanes",
  "Battleplanes",
  "AWACS",
  "Tankers",
  "Transports",
  "UAVs",
  "Attack helicopters",
  "Transport helicopters",
}

--- Engagement tasks whose `targetTypes` are read by `routeEngagesAir`.
veafAircraftSpawn.ENGAGE_TASK_IDS = { EngageTargets = true, EngageTargetsInZone = true }

--- The roles, by name. A role is a table:
---
--- * `buildRoute(context)` → the list of route points, and a state table handed to `afterSpawn`
--- * `afterSpawn(dcsGroup, groupName, coalition, state)` → what runs once the group exists
---
--- `context` holds `spot` (a runtime vec3, `y` the altitude), `params` (what the caller passed to
--- `withRole`) and `firstWaypointTask` (the template's own options, or nil).
veafAircraftSpawn.roles = {}

--- The role each group spawned or re-tasked here flies, by group name.
veafAircraftSpawn.groupRoles = {}

--- The first-waypoint options each group was spawned with, by group name: a role given in flight
--- replaces the route, and its first waypoint carries them again.
veafAircraftSpawn.groupOptions = {}

-------------------------------------------------------------------------------------------------------------------------------------------------------------
-- Reading a route
-------------------------------------------------------------------------------------------------------------------------------------------------------------

local airTargetTypes = {}
for _, targetType in ipairs(veafAircraftSpawn.AIR_TARGET_TYPES) do
  airTargetTypes[targetType] = true
end

--- The tasks a route point carries, whatever the shape: a `ComboTask` holds them in `params.tasks`.
local function tasksOf(point)
  local task = type(point) == "table" and point.task
  if type(task) ~= "table" then
    return {}
  end
  if task.id == "ComboTask" then
    return (task.params and task.params.tasks) or {}
  end
  return { task }
end

--- Does this route make the group engage aircraft?
---
--- True when one of its points carries an `EngageTargets` or `EngageTargetsInZone` task whose target
--- types include an aircraft type — which is what the Mission Editor adds by itself to a `CAP` or
--- `Intercept` flight, and what a mission maker adds by hand. A disabled task does not count.
---
--- @param points table|nil the route points, as `veaf.getGroupRoute` answers them
--- @return boolean
function veafAircraftSpawn.routeEngagesAir(points)
  if type(points) ~= "table" then
    return false
  end
  for _, point in pairs(points) do
    for _, task in pairs(tasksOf(point)) do
      if type(task) == "table" and veafAircraftSpawn.ENGAGE_TASK_IDS[task.id] and task.enabled ~= false then
        local targetTypes = task.params and task.params.targetTypes
        if type(targetTypes) == "table" then
          for _, targetType in pairs(targetTypes) do
            if airTargetTypes[targetType] then
              return true
            end
          end
        end
      end
    end
  end
  return false
end

--- The options a template's first waypoint carries, to fly the role's route with them.
---
--- A `ComboTask` holding at least one `WrappedAction` — ROE, reaction to threat, radar, ECM… — is
--- copied whole; anything else is not options, and nil comes back. This is the rule `-cap` has always
--- applied to its templates.
---
--- @param points table|nil route points
--- @return table|nil a copy of the first waypoint's task
function veafAircraftSpawn.firstWaypointOptions(points)
  local first = type(points) == "table" and points[1]
  local task = type(first) == "table" and first.task
  if type(task) ~= "table" or task.id ~= "ComboTask" then
    return nil
  end
  for _, wrapped in pairs(tasksOf(first)) do
    if type(wrapped) == "table" and wrapped.id == "WrappedAction" then
      return veaf.deepCopy(task)
    end
  end
  return nil
end

--- The take-off point a route starts from, when it starts on the ground.
---
--- A first waypoint whose type is one of the `TakeOff…` ones — parking, cold or hot, runway, ground
--- — is where DCS puts the flight; a role keeps it as it is and builds its patrol after it.
---
--- @param points table|nil route points
--- @return table|nil a copy of the first waypoint, or nil for an airborne start
function veafAircraftSpawn.takeoffPoint(points)
  local first = type(points) == "table" and points[1]
  if type(first) == "table" and type(first.type) == "string" and veaf.startsWith(first.type, "TakeOff") then
    return veaf.deepCopy(first)
  end
  return nil
end

--- Is this editor group an aircraft group?
--- @param groupName string
--- @return boolean
function veafAircraftSpawn.isAircraftGroup(groupName)
  local record = veaf.getGroupRecord(groupName)
  return record ~= nil and (record.category == "plane" or record.category == "helicopter")
end

--- Should a QRA or an air wave give this group the `zone_defense` role when it clones it?
---
--- Yes for an aircraft group tasked `CAP` or `Intercept` in the editor whose route engages no
--- aircraft: the mission maker left its job to the framework. No for one whose route does — he
--- chose his own setup — and no for any other task, whose route is the mission.
---
--- @param groupName string
--- @return boolean
function veafAircraftSpawn.needsZoneDefense(groupName)
  if not veafAircraftSpawn.isAircraftGroup(groupName) then
    return false
  end
  if not veafAircraftSpawn.ZONE_DEFENSE_TASKS[veaf.getGroupRecord(groupName).task] then
    return false
  end
  return not veafAircraftSpawn.routeEngagesAir(veaf.getGroupRoute(groupName))
end

--- The zone a QRA or an air wave defends, in the shape the roles take: `{ x, y, radius }`, with the
--- **easting in `y`** as in a mission table.
---
--- @param triggerZone table|nil a `veaf.getTriggerZone` record
--- @param zoneCenter table|nil a runtime vec3 (easting in `z`), used when there is no trigger zone
--- @param zoneRadius number|nil metres, with `zoneCenter`
--- @return table|nil nil when no radius is known
function veafAircraftSpawn.zoneToDefend(triggerZone, zoneCenter, zoneRadius)
  if triggerZone and triggerZone.radius and triggerZone.radius > 0 then
    return { x = triggerZone.x, y = triggerZone.y, radius = triggerZone.radius }
  end
  if zoneCenter and zoneRadius and zoneRadius > 0 then
    return { x = zoneCenter.x, y = zoneCenter.z, radius = zoneRadius }
  end
  return nil
end

--- The role a group flies, if it was spawned or re-tasked here.
--- @param groupName string
--- @return string|nil
function veafAircraftSpawn.getRole(groupName)
  return groupName and veafAircraftSpawn.groupRoles[groupName] or nil
end

-------------------------------------------------------------------------------------------------------------------------------------------------------------
-- Routes
-------------------------------------------------------------------------------------------------------------------------------------------------------------

local function emptyComboTask()
  return {
    ["id"] = "ComboTask",
    ["params"] = {
      ["tasks"] = {}, -- end of ["tasks"]
    }, -- end of ["params"]
  }
end

--- A race-track: spawn point, then a leg flown 2 → 3 → 2 for ever.
---
--- `parameters`: `altitude` (m), `speed1`..`speed3` (m/s), `wp1`..`wp3` (mission-table `{ x, y }`),
--- `wp1Options` (the first waypoint's task, or nil). The table is the one `-cap` has always flown.
local function raceTrackRoute(parameters)
  return {
    [1] = {
      ["alt"] = parameters.altitude,
      ["action"] = "Turning Point",
      ["alt_type"] = "BARO",
      ["speed"] = parameters.speed1,
      ["properties"] = {
        ["addopt"] = {}, -- end of ["addopt"]
      }, -- end of ["properties"]
      ["task"] = parameters.wp1Options,
      ["type"] = "Turning Point",
      ["ETA"] = 10000,
      ["ETA_locked"] = false,
      ["y"] = parameters.wp1.y,
      ["x"] = parameters.wp1.x,
      ["formation_template"] = "",
      ["speed_locked"] = true,
    }, -- end of [1]
    [2] = {
      ["alt"] = parameters.altitude,
      ["action"] = "Turning Point",
      ["alt_type"] = "BARO",
      ["speed"] = parameters.speed2,
      ["properties"] = {
        ["addopt"] = {}, -- end of ["addopt"]
      }, -- end of ["properties"]
      -- The patrol waypoint carries no task of its own, and that is a decision, not an omission.
      --
      -- An `EngageTargetsInZone` task used to sit here, commented out, saying nothing about
      -- whether the watchdog was meant to replace it or to complement it. It cannot complement it:
      -- the two mechanisms are incompatible by construction.
      --
      -- * The group is spawned with `PROHIBIT_AA = true` and the watchdog owns that option from
      --   then on. A route task telling the group to engage air targets is inert for exactly as
      --   long as the watchdog is silent, and redundant the moment it speaks.
      -- * `startCapWatchdog` undoes its own tasking through the controller's task queue — the
      --   queue this route task would live in. ED's own description of `resetTask` is "clears
      --   **all** tasks from this controller's task queue"; even the narrower `popTask` used now
      --   pops whatever is on top. A route-level engage task in that queue is something the
      --   watchdog would eventually remove without ever knowing it was there.
      --
      -- So the watchdog is the single mechanism, deliberately: it is the one that can weigh
      -- targets by priority (`FIX-CAP-ENGAGES-PARACHUTES`) and hand the group back its patrol when
      -- there is nothing worth engaging.
      ["task"] = emptyComboTask(),
      ["type"] = "Turning Point",
      ["ETA"] = 20000,
      ["ETA_locked"] = false,
      ["y"] = parameters.wp2.y,
      ["x"] = parameters.wp2.x,
      ["formation_template"] = "",
      ["speed_locked"] = true,
    }, -- end of [2]
    [3] = {
      ["alt"] = parameters.altitude,
      ["action"] = "Turning Point",
      ["alt_type"] = "BARO",
      ["speed"] = parameters.speed3,
      ["properties"] = {
        ["addopt"] = {}, -- end of ["addopt"]
      }, -- end of ["properties"]
      ["task"] = {
        ["id"] = "ComboTask",
        ["params"] = {
          ["tasks"] = {
            [1] = {
              ["enabled"] = true,
              ["auto"] = false,
              ["id"] = "WrappedAction",
              ["number"] = 1,
              ["params"] = {
                ["action"] = {
                  ["id"] = "SwitchWaypoint",
                  ["params"] = {
                    ["goToWaypointIndex"] = 2,
                    ["fromWaypointIndex"] = 3,
                  }, -- end of ["params"]
                }, -- end of ["action"]
              }, -- end of ["params"]
            }, -- end of [1]
          }, -- end of ["tasks"]
        }, -- end of ["params"]
      }, -- end of ["task"]
      ["type"] = "Turning Point",
      ["ETA"] = 30000,
      ["ETA_locked"] = false,
      ["y"] = parameters.wp3.y,
      ["x"] = parameters.wp3.x,
      ["formation_template"] = "",
      ["speed_locked"] = true,
    }, -- end of [3]
  }
end

--- What every fighter role does once the group exists: hold fire on aircraft, and let the CAP
--- watchdog decide what is worth engaging inside `zone`.
---
--- The watchdog reads its zone from `veafSpawn.capWatchdogZones` on every tick, so a group that already
--- has one — a `-cap` a QRA has just re-tasked — is re-aimed rather than given a second.
local function guardTheZone(dcsGroup, groupName, groupCoalition, zone)
  local controller = dcsGroup:getController()
  controller:setOption(AI.Option.Air.id.PROHIBIT_AA, true)
  local watched = veafSpawn.capWatchdogZones[groupName] ~= nil
  veafSpawn.capWatchdogZones[groupName] = zone
  if not watched then
    veaf.loggers.get(veafAircraftSpawn.Id):debug("starting CAP target watchdog for %s", veaf.p(groupName))
    veaf.scheduleFunction(veafSpawn.startCapWatchdog, { groupName, groupCoalition, zone }, timer.getTime() + 1)
  end
end

--- `cap`: the race-track `-cap` flies, along a heading, and the watchdog on the zone between its legs.
---
--- `params`: `heading` (degrees), `distance` (leg, m), `capRadius` (m), `altitude` (m), `speed1`..
--- `speed3` (m/s).
veafAircraftSpawn.roles.cap = {
  buildRoute = function(context)
    local params = context.params
    local headingRad = math.rad(params.heading or 0)
    local parameters = {
      altitude = params.altitude,
      speed1 = params.speed1,
      speed2 = params.speed2,
      speed3 = params.speed3,
      wp1 = { x = context.spot.x, y = context.spot.z },
      wp1Options = context.firstWaypointTask,
    }
    -- second wp at 2500m in the right direction, the last one at the leg's length past it
    parameters.wp2 = { x = parameters.wp1.x + 2500 * math.cos(headingRad), y = parameters.wp1.y + 2500 * math.sin(headingRad) }
    parameters.wp3 = {
      x = parameters.wp2.x + params.distance * math.cos(headingRad),
      y = parameters.wp2.y + params.distance * math.sin(headingRad),
    }
    -- the zone the watchdog guards sits at the middle of the leg
    local zone = { x = (parameters.wp2.x + parameters.wp3.x) / 2, y = (parameters.wp2.y + parameters.wp3.y) / 2, radius = params.capRadius }

    veafSpawn.traceMarkerId = veaf.loggers.get(veafSpawn.Id):marker(veafSpawn.traceMarkerId, "CAP", "wp1", parameters.wp1)
    veafSpawn.traceMarkerId = veaf.loggers.get(veafSpawn.Id):marker(veafSpawn.traceMarkerId, "CAP", "wp2", parameters.wp2)
    veafSpawn.traceMarkerId = veaf.loggers.get(veafSpawn.Id):marker(veafSpawn.traceMarkerId, "CAP", "wp3", parameters.wp3)
    veafSpawn.traceMarkerId =
      veaf.loggers.get(veafSpawn.Id):marker(veafSpawn.traceMarkerId, "CAP", "targetZone", zone, nil, params.capRadius, { 1, 0, 0, 0.15 })

    return raceTrackRoute(parameters), { zone = zone }
  end,
  afterSpawn = function(dcsGroup, groupName, groupCoalition, state)
    guardTheZone(dcsGroup, groupName, groupCoalition, state.zone)
  end,
}

--- `zone_defense`: fly to a zone, patrol across its centre, and engage what the watchdog finds in it.
---
--- The race-track is centred on the zone, along the axis from the spawn point to the centre, so the
--- flight arrives on its leg rather than overflying it; the leg is the CAP's (20 NM) or the zone's
--- diameter, whichever is shorter. Altitude is the spawn point's, speed the one asked for, else the
--- template's first waypoint's, else the CAP's patrol Mach.
---
--- A template that starts on the ground keeps its take-off point as the first waypoint, untouched,
--- and climbs to `DEFAULT_PATROL_ALTITUDE` for the leg; its take-off speed is not a patrol speed.
---
--- `params`: `zone` (`{ x, y, radius }`, easting in `y`, mandatory), `speed` (m/s, optional).
veafAircraftSpawn.roles.zone_defense = {
  buildRoute = function(context)
    local zone = context.params.zone
    local takeoff = context.takeoffPoint
    local wp1 = takeoff and { x = takeoff.x, y = takeoff.y } or { x = context.spot.x, y = context.spot.z }
    local altitude = takeoff and veafAircraftSpawn.DEFAULT_PATROL_ALTITUDE or context.spot.y
    local templateSpeed = not takeoff and context.templateSpeed or nil
    local dx, dy = zone.x - wp1.x, zone.y - wp1.y
    local distance = math.sqrt(dx * dx + dy * dy)
    local ux, uy = 1, 0 -- a spawn on the centre itself patrols north-south
    if distance > 1 then
      ux, uy = dx / distance, dy / distance
    end
    local halfLeg = math.min(veafAircraftSpawn.DEFAULT_LEG_LENGTH, 2 * zone.radius) / 2
    local speed = context.params.speed or templateSpeed or veaf.convertMachSpeed(veafAircraftSpawn.DEFAULT_PATROL_MACH, altitude).TAS_ms
    local parameters = {
      altitude = altitude,
      speed1 = speed,
      speed2 = speed,
      speed3 = speed,
      wp1 = wp1,
      wp2 = { x = zone.x - ux * halfLeg, y = zone.y - uy * halfLeg },
      wp3 = { x = zone.x + ux * halfLeg, y = zone.y + uy * halfLeg },
      wp1Options = context.firstWaypointTask,
    }
    local route = raceTrackRoute(parameters)
    if takeoff then
      route[1] = takeoff
    end
    return route, { zone = { x = zone.x, y = zone.y, radius = zone.radius }, keepsTakeoff = takeoff ~= nil }
  end,
  afterSpawn = function(dcsGroup, groupName, groupCoalition, state)
    guardTheZone(dcsGroup, groupName, groupCoalition, state.zone)
  end,
}

-------------------------------------------------------------------------------------------------------------------------------------------------------------
-- VeafAircraftSpawn: one aircraft group, one role
-------------------------------------------------------------------------------------------------------------------------------------------------------------

---@class VeafAircraftSpawn
VeafAircraftSpawn = {}
VeafAircraftSpawn.__index = VeafAircraftSpawn

--- Start a spawn. Chain the setters, end with `spawn()`.
function VeafAircraftSpawn:new()
  local object = setmetatable({}, VeafAircraftSpawn)
  object.templateName = nil
  object.newGroupName = nil
  object.spot = nil
  object.radius = nil
  object.countryId = nil
  object.skill = nil
  object.hiddenOnMFD = nil
  object.visibleOnMap = false
  object.roleName = nil
  object.roleParams = nil
  object.firstWaypointTask = nil
  return object
end

--- The group to clone: an editor group or a `veafSpawn-` template.
function VeafAircraftSpawn:fromGroup(templateName)
  self.templateName = templateName
  return self
end

--- The new group's name; without one, the spawner makes one up.
function VeafAircraftSpawn:named(newGroupName)
  self.newGroupName = newGroupName
  return self
end

--- Where it appears: a runtime vec3, `y` the altitude. Without one, the template's own position.
function VeafAircraftSpawn:at(spot)
  self.spot = spot
  return self
end

--- Scatter the spawn point within this many metres.
function VeafAircraftSpawn:withRadius(radius)
  self.radius = radius
  return self
end

--- Fly for another country than the template's.
function VeafAircraftSpawn:inCountry(countryId)
  self.countryId = countryId
  return self
end

--- The skill of every unit.
function VeafAircraftSpawn:withSkill(skill)
  self.skill = skill
  return self
end

--- Show the group on the F10 map, and choose whether it shows on MFDs.
function VeafAircraftSpawn:shownOnMap(hiddenOnMFD)
  self.visibleOnMap = true
  self.hiddenOnMFD = hiddenOnMFD
  return self
end

--- Fly with these first-waypoint options instead of the template's.
function VeafAircraftSpawn:withFirstWaypointTask(task)
  self.firstWaypointTask = task
  return self
end

--- The job: a name from `veafAircraftSpawn.roles`, and its parameters.
function VeafAircraftSpawn:withRole(roleName, params)
  self.roleName = roleName
  self.roleParams = params or {}
  return self
end

--- The template's first-waypoint speed, when it has one worth flying.
local function templateSpeedOf(points)
  local first = type(points) == "table" and points[1]
  local speed = type(first) == "table" and first.speed
  if type(speed) == "number" and speed > 0 then
    return speed
  end
  return nil
end

--- The point a template's first unit stands at, as a runtime vec3.
local function templateSpotOf(templateName)
  local record = veaf.getGroupRecord(templateName)
  local unit = record and record.units and record.units[1]
  if not unit then
    return nil
  end
  return { x = unit.x, y = unit.alt or 0, z = unit.y }
end

--- Spawn the group.
---
--- @return string|nil the new group's name; nil when the template, the role or DCS failed, which is
---   logged
function VeafAircraftSpawn:spawn()
  local logger = veaf.loggers.get(veafAircraftSpawn.Id)
  local role = self.roleName and veafAircraftSpawn.roles[self.roleName]
  if self.roleName and not role then
    logger:error("unknown aircraft role [%s] for %s", veaf.p(self.roleName), veaf.p(self.templateName))
    return nil
  end
  local spot = self.spot or templateSpotOf(self.templateName)
  if not spot then
    logger:error("no spawn point for %s", veaf.p(self.templateName))
    return nil
  end

  local templateRoute = veaf.getGroupRoute(self.templateName)
  local route, state, firstWaypointTask = nil, nil, nil
  if role then
    firstWaypointTask = self.firstWaypointTask or veafAircraftSpawn.firstWaypointOptions(templateRoute)
    local context = {
      spot = spot,
      params = self.roleParams,
      firstWaypointTask = firstWaypointTask,
      templateSpeed = templateSpeedOf(templateRoute),
      takeoffPoint = veafAircraftSpawn.takeoffPoint(templateRoute),
    }
    route, state = role.buildRoute(context)
  end
  -- a flight the role leaves on its take-off point starts where the editor put it, at ground level
  local airborneRole = role and not (state and state.keepsTakeoff)

  local spawner = VeafGroupSpawn:new():forGroup(self.templateName):at(spot)
  if self.newGroupName then
    spawner:named(self.newGroupName)
  end
  if self.radius and self.radius > 0 then
    spawner:withRadius(self.radius)
    if airborneRole or not role then
      -- the route starts where the group appears, not where it was asked to
      spawner:offsettingFirstWaypoint()
    end
  end
  spawner:withRoute(route or templateRoute)
  local newGroup = spawner:buildCloneData()
  if not newGroup then
    logger:error("cannot clone group %s", veaf.p(self.templateName))
    return nil
  end
  if self.countryId then
    newGroup.countryId = self.countryId
  end
  if self.visibleOnMap then
    newGroup.hidden = false
    newGroup.hiddenOnMFD = self.hiddenOnMFD
  end
  for _, unit in pairs(newGroup.units or {}) do
    if self.skill then
      unit.skill = self.skill
    end
    if airborneRole then
      unit.alt = spot.y
    end
  end

  local spawnedGroup = veaf.addGroup(newGroup)
  if not spawnedGroup then
    logger:error("cannot spawn group %s", veaf.p(newGroup.name))
    return nil
  end
  local groupName = spawnedGroup.name
  if not role then
    return groupName
  end

  -- The submission is VEAF's; whether DCS took it is DCS's to say, and everything a role does next
  -- needs the DCS object (FIX-SPAWNAIRCRAFT-UNGUARDED-GROUP).
  local dcsGroup = Group.getByName(groupName)
  if not dcsGroup then
    logger:warn(string.format("group [%s] was spawned but DCS does not know it; its role cannot be set up", veaf.p(groupName)))
    return nil
  end
  veafAircraftSpawn.groupRoles[groupName] = self.roleName
  veafAircraftSpawn.groupOptions[groupName] = firstWaypointTask
  role.afterSpawn(dcsGroup, groupName, dcsGroup:getCoalition(), state)
  logger:debug("spawned %s as %s", veaf.p(groupName), veaf.p(self.roleName))
  return groupName
end

--- Clone an editor group for a QRA or an air wave: with the `zone_defense` role when it needs one
--- (`needsZoneDefense`), with its editor route otherwise.
---
--- @param groupName string the editor group
--- @param spot table runtime vec3 where it appears
--- @param radius number|nil scatter, metres
--- @param zone table|nil the zone to defend (`zoneToDefend`); without one, the editor route is kept
--- @return string|nil the new group's name
function veafAircraftSpawn.deployEditorGroup(groupName, spot, radius, zone)
  if zone and veafAircraftSpawn.needsZoneDefense(groupName) then
    veaf.loggers.get(veafAircraftSpawn.Id):debug("%s engages no aircraft by itself: it defends the zone", veaf.p(groupName))
    return VeafAircraftSpawn:new():fromGroup(groupName):at(spot):withRadius(radius):withRole("zone_defense", { zone = zone }):spawn()
  end
  local newGroup = VeafGroupSpawn:new():forGroup(groupName):at(spot):withRadius(radius):withRoute(veaf.getGroupRoute(groupName)):clone()
  return newGroup and newGroup.name or nil
end

--- After a QRA or an air wave ran an aircraft command (`-cap mig29`), send the CAPs it spawned to
--- defend that QRA's or wave's zone instead of the zone their own leg drew.
---
--- @param groupNames table the names the command spawned
--- @param zone table|nil the zone to defend (`zoneToDefend`); nothing happens without one
function veafAircraftSpawn.defendZoneWithCaps(groupNames, zone)
  if not zone then
    return
  end
  for _, groupName in pairs(groupNames or {}) do
    if veafAircraftSpawn.getRole(groupName) == "cap" then
      veafAircraftSpawn.assignRole(groupName, "zone_defense", { zone = zone })
    end
  end
end

--- Give a role to a group that is already flying: a new route from where it is, and what the role
--- runs afterwards. A fighter group keeps its one watchdog, re-aimed at the new zone.
---
--- @param groupName string
--- @param roleName string a name from `veafAircraftSpawn.roles`
--- @param params table the role's parameters
--- @return boolean true when the role was applied
function veafAircraftSpawn.assignRole(groupName, roleName, params)
  local logger = veaf.loggers.get(veafAircraftSpawn.Id)
  local role = veafAircraftSpawn.roles[roleName]
  if not role then
    logger:error("unknown aircraft role [%s] for %s", veaf.p(roleName), veaf.p(groupName))
    return false
  end
  local dcsGroup = Group.getByName(groupName)
  local leader = dcsGroup and dcsGroup:getUnit(1)
  if not leader then
    logger:warn("cannot give the role %s to %s: no such group in the air", veaf.p(roleName), veaf.p(groupName))
    return false
  end
  local spot = leader:getPoint()
  -- the options it was spawned with, unless the caller gives others: the new route replaces the one
  -- that carried them, possibly before DCS ever ran its first waypoint
  local firstWaypointTask = (params and params.firstWaypointTask) or veafAircraftSpawn.groupOptions[groupName]
  local route, state =
    role.buildRoute({ spot = spot, params = params or {}, firstWaypointTask = firstWaypointTask and veaf.deepCopy(firstWaypointTask) })
  veaf.goRoute(dcsGroup, route)
  veafAircraftSpawn.groupRoles[groupName] = roleName
  role.afterSpawn(dcsGroup, groupName, dcsGroup:getCoalition(), state)
  logger:debug("%s now flies as %s", veaf.p(groupName), veaf.p(roleName))
  return true
end

veaf.loggers.get(veafAircraftSpawn.Id):info(veaf.loggers.get(veafAircraftSpawn.Id):getVersionInfo())
