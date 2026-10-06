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

--- The lowest an aircraft given a role appears and patrols, in metres above the ground under its spawn
--- point: about 500 ft. DCS does not lift a too-low aircraft by itself — measured 2026-10-03, a MiG-21
--- spawned 15 m above the ground hit the trees within a second (FIX-AIR-SPAWN-ALTITUDE-GUARD).
veafAircraftSpawn.MINIMUM_CLEARANCE_METRES = 150

--- The altitude an aircraft may appear or patrol at above this point: the one asked, or the clearance
--- floor when the one asked is under it.
---
--- @param point table a runtime vec3 (easting in `z`) or a mission-table point (easting in `y`)
--- @param altitude number metres, sea level
--- @return number
function veafAircraftSpawn.flooredAltitude(point, altitude)
  local floor = land.getHeight({ x = point.x, y = point.z or point.y }) + veafAircraftSpawn.MINIMUM_CLEARANCE_METRES
  if altitude < floor then
    veaf.loggers
      .get(veafAircraftSpawn.Id)
      :info("altitude %s m is too close to the ground, raised to %s m", veaf.p(math.floor(altitude)), veaf.p(math.floor(floor)))
    return floor
  end
  return altitude
end

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

--- The route each group's role gave it, by group name: what the CAP watchdog hands back once it has
--- nothing left to engage (`resumePatrol`).
veafAircraftSpawn.groupRoutes = {}

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

--- Forget what a group's role left behind, once that group is gone.
---
--- Called by the CAP watchdog when it stops watching a group, and by `forgetGoneGroups` for the roles
--- that have no watchdog. Without it, these tables keep one route per role group for the whole server
--- session. A stale entry is otherwise harmless today: a spawned name is never released
--- (`veafMissionDb.releaseSpawnedName` serves the AFAC alone), so no later group can inherit it
--- (issue #1079). Releasing names would change that.
--- @param groupName string
function veafAircraftSpawn.forgetGroup(groupName)
  veafAircraftSpawn.groupRoles[groupName] = nil
  veafAircraftSpawn.groupOptions[groupName] = nil
  veafAircraftSpawn.groupRoutes[groupName] = nil
end

--- Forget every group DCS no longer knows. Only `cap` and `zone_defense` have a watchdog to say when
--- their group is gone; the other roles are swept here, on the next spawn with a role.
function veafAircraftSpawn.forgetGoneGroups()
  for groupName in pairs(veafAircraftSpawn.groupRoles) do
    if not Group.getByName(groupName) then
      veafAircraftSpawn.forgetGroup(groupName)
    end
  end
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
-- Helicopters: spawned by the ground path, landed at the marker, then given a job
-------------------------------------------------------------------------------------------------------------------------------------------------------------

--- The marker's `task` words, in the order the refusal message lists them; no `task` is `parked`.
--- Each names a role of `veafAircraftSpawn.roles` that carries `helicopter = true`.
veafAircraftSpawn.HELICOPTER_TASKS = { "parked", "orbit", "transport", "patrol", "attack", "escort" }

--- Height above the ground a helicopter flies its job at, when the marker gives no `alt`, in metres.
veafAircraftSpawn.HELICOPTER_ALTITUDE = 150

--- Speed a helicopter flies its job at, when the marker gives no `speed`, in m/s (about 80 kt).
veafAircraftSpawn.HELICOPTER_SPEED = 40

--- How far short of a landing point a helicopter ends its cruise, in metres, to descend on the way in.
--- R24 (2026-10-02): with the cruise point right over the landing point, the Mi-8 overflew it, flew on
--- 1.9 km and came back round.
veafAircraftSpawn.HELICOPTER_APPROACH = 500

--- How far from its destination a helicopter may land to find a clearing, in metres, and how much
--- clear ground that clearing needs around its centre (a Mi-8's rotor is 21 m across). R26
--- (2026-10-02): sent into a forest, the Mi-8 hovered over its edge for minutes, looking for room.
veafAircraftSpawn.HELICOPTER_LZ_SEARCH = 300
veafAircraftSpawn.HELICOPTER_LZ_CLEARANCE = 30

--- Radius an armed helicopter engages ground units and helicopters in, in metres, when the marker
--- gives no `capradius`.
veafAircraftSpawn.HELICOPTER_ENGAGE_RADIUS = 3000

--- How far from its point an armed `patrol` with no `dest` flies its square, in metres.
veafAircraftSpawn.HELICOPTER_PATROL_LEG = 1000

--- How long an unarmed `patrol` stays on the ground at each end of its shuttle, in seconds.
veafAircraftSpawn.HELICOPTER_GROUND_TIME = 300

--- What an armed helicopter engages: the generic DCS attributes for ground units and helicopters.
veafAircraftSpawn.HELICOPTER_TARGET_TYPES = { "Ground Units", "Helicopters" }

--- A ComboTask holding these tasks, numbered as the Mission Editor numbers them.
local function comboTask(tasks)
  local combo = emptyComboTask()
  for index, task in ipairs(tasks or {}) do
    task.number = index
    task.enabled = true
    task.auto = false
    combo.params.tasks[index] = task
  end
  return combo
end

--- The rules of engagement, as a first-waypoint option.
local function roeTask(value)
  return { id = "WrappedAction", params = { action = { id = "Option", params = { name = AI.Option.Air.id.ROE, value = value } } } }
end

--- A helicopter's first waypoint: on the ground, where it was put.
---
--- @param spot table runtime vec3 (`y` the ground height)
--- @param pointType string `TakeOffGround` (cold) or `TakeOffGroundHot` (rotors running)
--- @param tasks table|nil the tasks it carries — the options the job flies with
local function groundPoint(spot, pointType, tasks)
  return {
    ["x"] = spot.x,
    ["y"] = spot.z,
    ["alt"] = spot.y,
    ["alt_type"] = "BARO",
    ["type"] = pointType,
    ["action"] = pointType == "TakeOffGroundHot" and "From Ground Area Hot" or "From Ground Area",
    ["speed"] = 0,
    ["task"] = comboTask(tasks),
  }
end

--- A waypoint in the air, `height` metres above the ground under it.
---
--- The altitude is written above sea level (`BARO`) from the ground height at that point, so that the
--- waypoint and an `Orbit` task on it — whose altitude DCS reads above sea level — say the same thing.
local function airPoint(point, height, speed, tasks)
  return {
    ["x"] = point.x,
    ["y"] = point.z,
    ["alt"] = veaf.getLandHeight(point) + height,
    ["alt_type"] = "BARO",
    ["type"] = "Turning Point",
    ["action"] = "Turning Point",
    ["speed"] = speed,
    ["task"] = comboTask(tasks),
  }
end

--- Where a marker's `dest` points: a named point, or coordinates, as for a convoy.
--- @return table|nil runtime vec3
local function resolveDestination(destination)
  local point = veafNamedPoints.getPoint(destination)
  if not point then
    local lat, lon = veaf.computeLLFromString(destination)
    if lat and lon then
      point = coord.LLtoLO(lat, lon)
    end
  end
  return point
end

--- The height and speed a job flies at: the marker's, else the helicopter defaults.
local function heightAndSpeed(params)
  return params.altitude or veafAircraftSpawn.HELICOPTER_ALTITUDE, params.speed or veafAircraftSpawn.HELICOPTER_SPEED
end

--- Engage ground units and helicopters within `radius` of a point (an en-route task).
local function engageTask(point, radius)
  return {
    id = "EngageTargetsInZone",
    params = {
      point = { x = point.x, y = point.z },
      zoneRadius = radius,
      targetTypes = veaf.deepCopy(veafAircraftSpawn.HELICOPTER_TARGET_TYPES),
      priority = 0,
    },
  }
end

--- Go back to waypoint `to` once waypoint `from` is reached: what makes a route loop for ever.
local function loopTask(from, to)
  return {
    id = "WrappedAction",
    params = { action = { id = "SwitchWaypoint", params = { fromWaypointIndex = from, goToWaypointIndex = to } } },
  }
end

--- The point a landing is made on: the nearest clearing within `HELICOPTER_LZ_SEARCH` of the one
--- asked, when the scenery-aware search finds one — R26: sent into a forest, the Mi-8 hovered at its
--- edge. Else the point asked, around which DCS looks for room by itself.
local function landingPoint(point)
  return veaf.findSpawnPoint(point, veafAircraftSpawn.HELICOPTER_LZ_SEARCH, veafAircraftSpawn.HELICOPTER_LZ_CLEARANCE, nil, true) or point
end

--- The cruise point a landing is handed over from: `HELICOPTER_APPROACH` short of the landing, on
--- the line in from `from` — or the landing point itself when it is closer than that.
local function approachPoint(from, landing)
  local dx, dz = landing.x - from.x, landing.z - from.z
  local length = math.sqrt(dx * dx + dz * dz)
  if length <= veafAircraftSpawn.HELICOPTER_APPROACH then
    return landing
  end
  local back = veafAircraftSpawn.HELICOPTER_APPROACH / length
  return { x = landing.x - dx * back, y = 0, z = landing.z - dz * back }
end

--- A `Land` task. Not a `Land` waypoint: one sent the Mi-8 to the nearest airfield's parking (R24, R25).
--- @param duration number|nil seconds on the ground before going on; nil stays down
local function landTask(point, duration)
  return { id = "Land", params = { point = { x = point.x, y = point.z }, durationFlag = duration ~= nil, duration = duration } }
end

--- The take-off point every job flying from its marker starts on: rotors running, airborne in 11 s (R23).
local function hotStart(context, roe)
  return groundPoint(context.spot, "TakeOffGroundHot", { roeTask(roe) })
end

local function refusal(key, ...)
  return nil, { refusal = key, refusalArgs = { ... } }
end

--- `parked`: on the ground, engine off, waiting — a target.
---
--- `uncontrolled` is what keeps it there. Measured 2026-10-02 (DCS-SESSION-TODO R23): a helicopter
--- with a `TakeOffGround` point alone started its engine at T+80 s and took off at T+278 s, one with no
--- route hovered, and only this one stayed down for the five minutes.
veafAircraftSpawn.roles.parked = {
  helicopter = true,
  buildRoute = function(context)
    return { groundPoint(context.spot, "TakeOffGround") }, { uncontrolled = true }
  end,
}

--- `orbit`: take off from the marker and circle it, weapons free when armed, holding fire when not.
---
--- `TakeOffGroundHot`, because it is airborne in 11 s where a cold start waits minutes (R23). Read in
--- game (R24): it circles 1.5–2 km from its point.
veafAircraftSpawn.roles.orbit = {
  helicopter = true,
  buildRoute = function(context)
    local height, speed = heightAndSpeed(context.params)
    local roe = context.armed and AI.Option.Air.val.ROE.WEAPON_FREE or AI.Option.Air.val.ROE.WEAPON_HOLD
    local over = airPoint(context.spot, height, speed)
    over.task = comboTask({ { id = "Orbit", params = { pattern = "Circle", altitude = over.alt, speed = speed } } })
    return { groundPoint(context.spot, "TakeOffGroundHot", { roeTask(roe) }), over }, { task = context.armed and "CAS" or "Transport" }
  end,
}

--- `transport`: take off, fly to `dest` and land there, only returning fire.
---
--- The cruise ends `HELICOPTER_APPROACH` short of the landing point, on the line in, and that point
--- hands over a `Land` task. Not a `Land` **waypoint**: measured 2026-10-02 (R24, R25), one sent the
--- Mi-8 to Kobuleti's parking whether its point was on the field or 2.85 km away. With the task it
--- landed 30 m from an open-ground point (R28); inside a forest it hovers at the edge (R26, R27).
veafAircraftSpawn.roles.transport = {
  helicopter = true,
  buildRoute = function(context)
    local destination = context.params.destination
    if not destination then
      return refusal("spawn.helicopter_needs_dest", "transport")
    end
    local point = resolveDestination(destination)
    if not point then
      return refusal("spawn.point_not_found", destination)
    end
    local landing = landingPoint(point)
    local height, speed = heightAndSpeed(context.params)
    return {
      hotStart(context, AI.Option.Air.val.ROE.RETURN_FIRE),
      airPoint(approachPoint(context.spot, landing), height, speed, { landTask(landing) }),
    }, { task = "Transport" }
  end,
}

--- `patrol`, armed: a square `HELICOPTER_PATROL_LEG` around the marker — or to and fro between the
--- marker and `dest` — for ever, engaging ground units and helicopters within `radius` of its centre.
--- Unarmed: the resupply run, a shuttle marker ↔ `dest` landing `HELICOPTER_GROUND_TIME` at each end.
---
--- Read in game (R29–R31): the armed loop holds and engages a ground unit in its zone; the shuttle
--- lands 16 m from `dest`, waits, and goes home.
veafAircraftSpawn.roles.patrol = {
  helicopter = true,
  buildRoute = function(context)
    local params = context.params
    local height, speed = heightAndSpeed(params)
    local home = context.spot
    local point = nil
    if params.destination then
      point = resolveDestination(params.destination)
      if not point then
        return refusal("spawn.point_not_found", params.destination)
      end
    end

    if not context.armed then
      if not point then
        return refusal("spawn.helicopter_needs_dest", "patrol")
      end
      local there, back = landingPoint(point), landingPoint(home)
      local route = {
        hotStart(context, AI.Option.Air.val.ROE.RETURN_FIRE),
        airPoint(approachPoint(home, there), height, speed, { landTask(there, veafAircraftSpawn.HELICOPTER_GROUND_TIME) }),
        airPoint(approachPoint(there, back), height, speed, { landTask(back, veafAircraftSpawn.HELICOPTER_GROUND_TIME) }),
      }
      table.insert(route[3].task.params.tasks, loopTask(3, 2))
      return route, { task = "Transport" }
    end

    local radius = params.radius or veafAircraftSpawn.HELICOPTER_ENGAGE_RADIUS
    local route = { hotStart(context, AI.Option.Air.val.ROE.WEAPON_FREE) }
    local centre = home
    if point then
      centre = { x = (home.x + point.x) / 2, y = 0, z = (home.z + point.z) / 2 }
      table.insert(route, airPoint(point, height, speed))
      table.insert(route, airPoint(home, height, speed))
    else
      local leg = veafAircraftSpawn.HELICOPTER_PATROL_LEG
      for corner = 0, 3 do
        local bearing = corner * math.pi / 2
        table.insert(route, airPoint({ x = home.x + math.cos(bearing) * leg, y = 0, z = home.z + math.sin(bearing) * leg }, height, speed))
      end
    end
    table.insert(route[2].task.params.tasks, engageTask(centre, radius))
    table.insert(route[#route].task.params.tasks, loopTask(#route, 2))
    return route, { task = "CAS" }
  end,
}

--- `attack` (armed only): fly to `dest`, engage ground units and helicopters within `radius` of it,
--- and circle there. Read in game (R31, R32): the tank destroyed both times.
veafAircraftSpawn.roles.attack = {
  helicopter = true,
  buildRoute = function(context)
    local params = context.params
    if not context.armed then
      return refusal("spawn.helicopter_needs_weapons", "attack")
    end
    if not params.destination then
      return refusal("spawn.helicopter_needs_dest", "attack")
    end
    local point = resolveDestination(params.destination)
    if not point then
      return refusal("spawn.point_not_found", params.destination)
    end
    local height, speed = heightAndSpeed(params)
    local over = airPoint(point, height, speed)
    over.task = comboTask({
      engageTask(point, params.radius or veafAircraftSpawn.HELICOPTER_ENGAGE_RADIUS),
      { id = "Orbit", params = { pattern = "Circle", altitude = over.alt, speed = speed } },
    })
    return { hotStart(context, AI.Option.Air.val.ROE.WEAPON_FREE), over }, { task = "CAS" }
  end,
}

--- `escort` (armed only): join the ground group `dest` names and cover it (`GroundEscort`), engaging
--- within `radius`. Read in game (R33): it circled a driving group within its 3 km radius. R31 and R32
--- read it kilometres off only because it hit a map object taking off from the runway and went home.
veafAircraftSpawn.roles.escort = {
  helicopter = true,
  buildRoute = function(context)
    local params = context.params
    if not context.armed then
      return refusal("spawn.helicopter_needs_weapons", "escort")
    end
    if not params.destination then
      return refusal("spawn.helicopter_needs_dest", "escort")
    end
    local escorted = Group.getByName(params.destination)
    local leader = escorted and escorted:isExist() and escorted:getUnits()[1]
    if not leader then
      return refusal("spawn.helicopter_escort_no_group", params.destination)
    end
    local height, speed = heightAndSpeed(params)
    local join = airPoint(leader:getPoint(), height, speed, {
      {
        id = "GroundEscort",
        params = {
          groupId = escorted:getID(),
          engagementDistMax = params.radius or veafAircraftSpawn.HELICOPTER_ENGAGE_RADIUS,
          targetTypes = veaf.deepCopy(veafAircraftSpawn.HELICOPTER_TARGET_TYPES),
          lastWptIndexFlag = false,
        },
      },
    })
    return { hotStart(context, AI.Option.Air.val.ROE.WEAPON_FREE), join }, { task = "CAS" }
  end,
}

-------------------------------------------------------------------------------------------------------------------------------------------------------------
-- Support aircraft: the AWACS and the fighters escorting an aircraft (FEAT-AWACS-ESCORT-COMMANDS)
-------------------------------------------------------------------------------------------------------------------------------------------------------------

--- The AWACS types `-awacs` spawns, and what each carries: fuel in kg, chaff and flares.
---
--- Every DCS type carrying the `AWACS` attribute, read from `dcsUnits.yaml` (2026-10-04); a test
--- compares the two. Built from the type rather than from a `veafSpawn-` template: no reference mission
--- holds an AWACS template, so a template-based `-awacs` would have failed everywhere. The fuel is
--- here because nothing at runtime knows it, and an aircraft created with none falls out of the sky.
veafAircraftSpawn.AWACS_TYPES = {
  ["E-3A"] = { fuel = 65000, chaff = 120, flare = 60 },
  ["E-2C"] = { fuel = 5624, chaff = 120, flare = 60 },
  ["A-50"] = { fuel = 70000, chaff = 192, flare = 192 },
  ["KJ-2000"] = { fuel = 70000, chaff = 0, flare = 0 },
}

--- The AWACS type spawned when none is asked, by coalition.
veafAircraftSpawn.DEFAULT_AWACS_TYPE = {
  [coalition.side.NEUTRAL] = "E-3A",
  [coalition.side.RED] = "A-50",
  [coalition.side.BLUE] = "E-3A",
}

--- The AWACS type a command asked for, written as the player wrote it (`e-3a`, `A-50`…).
---
--- @param typeName string|nil the type asked; nil or blank is the coalition's default
--- @param side number the coalition it flies for
--- @return string|nil the DCS type; nil when the type asked is not an AWACS
function veafAircraftSpawn.awacsType(typeName, side)
  if typeName == nil or veaf.isBlank(typeName) then
    return veafAircraftSpawn.DEFAULT_AWACS_TYPE[side] or veafAircraftSpawn.DEFAULT_AWACS_TYPE[coalition.side.BLUE]
  end
  for dcsType, _ in pairs(veafAircraftSpawn.AWACS_TYPES) do
    if dcsType:lower() == typeName:lower() then
      return dcsType
    end
  end
  return nil
end

--- The payload an AWACS of this type carries: its fuel and countermeasures, no weapons.
function veafAircraftSpawn.awacsPayload(dcsType)
  local base = veafAircraftSpawn.AWACS_TYPES[dcsType] or {}
  return { fuel = base.fuel, chaff = base.chaff or 0, flare = base.flare or 0, gun = 100, pylons = {} }
end

--- Turn the datalink on (EPLRS). `veafDcsSpawner.addGroup` writes the group id in once it has one.
local function eplrsTask()
  return { id = "WrappedAction", params = { action = { id = "EPLRS", params = { value = true, groupId = 0 } } } }
end

--- `awacs`: the AWACS task, and a race-track flown for ever between the spawn point and a point
--- `distance` along `heading` — the Mission Editor's own shape, an `Orbit` of pattern `Race-Track` on
--- the first waypoint, flown between it and the next one. Datalink on unless `eplrs` is `false`.
---
--- `params`: `heading` (degrees), `distance` (leg, m), `altitude` (m), `speed` (m/s), `eplrs`.
veafAircraftSpawn.roles.awacs = {
  buildRoute = function(context)
    local params = context.params
    local headingRad = math.rad(params.heading or 0)
    local tasks = { { id = "AWACS", params = {} } }
    if params.eplrs ~= false then
      table.insert(tasks, eplrsTask())
    end
    table.insert(tasks, { id = "Orbit", params = { pattern = "Race-Track", altitude = params.altitude, speed = params.speed } })
    local function point(x, y, pointTasks)
      return {
        ["x"] = x,
        ["y"] = y,
        ["alt"] = params.altitude,
        ["alt_type"] = "BARO",
        ["type"] = "Turning Point",
        ["action"] = "Turning Point",
        ["speed"] = params.speed,
        ["speed_locked"] = true,
        ["task"] = comboTask(pointTasks),
      }
    end
    local spot = context.spot
    return {
      point(spot.x, spot.z, tasks),
      point(spot.x + params.distance * math.cos(headingRad), spot.z + params.distance * math.sin(headingRad), {}),
    }, { task = "AWACS" }
  end,
  afterSpawn = function() end,
}

--- Where an escort flies relative to its charge, in metres: `x` ahead, `y` up, `z` to the right.
--- Behind and to the right; a VEAF choice, not a DCS default.
veafAircraftSpawn.ESCORT_POSITION = { x = -500, y = 0, z = 500 }

--- How far from its charge an escort engages, in metres: the `engagementDistMax` read on the escort
--- tasks of the demo mission, written by the Mission Editor (FIX-ESCORT-RESPAWN-DISTANCE).
veafAircraftSpawn.ESCORT_ENGAGEMENT_DISTANCE = 60000

--- What an escort engages.
veafAircraftSpawn.ESCORT_TARGET_TYPES = { "Air" }

--- `air_escort`: escort the airplane group `escorted` and defend it — the DCS `Escort` task, on the
--- first waypoint, after the template's own options.
---
--- The rules of engagement are set to `OPEN_FIRE` after the template's options: an escort spawned from
--- a template written to hold fire would follow its charge and defend nothing, and an escort that only
--- flies alongside is exactly what this role exists not to be.
---
--- `params`: `escorted` (the group's name, mandatory).
veafAircraftSpawn.roles.air_escort = {
  buildRoute = function(context)
    local escorted = Group.getByName(context.params.escorted or "")
    if not escorted or not escorted:isExist() then
      return refusal("spawn.helicopter_escort_no_group", tostring(context.params.escorted))
    end
    local task = veaf.deepCopy(context.firstWaypointTask) or emptyComboTask()
    local tasks = task.params.tasks
    table.insert(tasks, roeTask(AI.Option.Air.val.ROE.OPEN_FIRE))
    table.insert(tasks, {
      id = "Escort",
      params = {
        groupId = escorted:getID(),
        pos = veaf.deepCopy(veafAircraftSpawn.ESCORT_POSITION),
        lastWptIndexFlag = false,
        engagementDistMax = veafAircraftSpawn.ESCORT_ENGAGEMENT_DISTANCE,
        targetTypes = veaf.deepCopy(veafAircraftSpawn.ESCORT_TARGET_TYPES),
      },
    })
    for index, each in ipairs(tasks) do
      each.number = index
      each.enabled = true
      if each.auto == nil then
        each.auto = false
      end
    end
    return {
      {
        ["x"] = context.spot.x,
        ["y"] = context.spot.z,
        ["alt"] = context.spot.y,
        ["alt_type"] = "BARO",
        ["type"] = "Turning Point",
        ["action"] = "Turning Point",
        ["speed"] = context.templateSpeed or veaf.convertMachSpeed(veafAircraftSpawn.DEFAULT_PATROL_MACH, context.spot.y).TAS_ms,
        ["task"] = task,
      },
    }, {}
  end,
  afterSpawn = function() end,
}

--- Spawn an airplane group built from its type rather than cloned from a template, with a role.
---
--- @param groupData table `{ country, name, units, hidden, hiddenOnMFD, frequency, modulation }`, each
---   unit carrying its position (`x`, `y` the easting, `alt` sea level), type, name, heading and payload
--- @param roleName string a name from `veafAircraftSpawn.roles`
--- @param params table the role's parameters
--- @return string|nil the group's name; nil when the role refused or DCS did not take the group
--- @return table|nil the role's state when it refused: `refusal`, `refusalArgs`
function veafAircraftSpawn.spawnAirplaneGroup(groupData, roleName, params)
  local logger = veaf.loggers.get(veafAircraftSpawn.Id)
  local role = veafAircraftSpawn.roles[roleName]
  if not role or role.helicopter then
    logger:error("unknown airplane role [%s] for %s", veaf.p(roleName), veaf.p(groupData.name))
    return nil
  end
  local leader = groupData.units and groupData.units[1]
  if not leader then
    logger:error("no unit to spawn in %s", veaf.p(groupData.name))
    return nil
  end
  local spot = { x = leader.x, y = leader.alt, z = leader.y }
  local route, state = role.buildRoute({ spot = spot, params = params or {} })
  state = state or {}
  if not route then
    return nil, state
  end

  local group = veaf.deepCopy(groupData)
  group.category = "AIRPLANE"
  group.task = state.task
  group.route = { points = route }
  for _, unit in pairs(group.units) do
    unit.alt_type = "BARO"
    unit.speed = route[1].speed
  end

  local spawned = veaf.addGroup(group)
  if not spawned then
    logger:error("cannot spawn airplane group %s", veaf.p(group.name))
    return nil
  end
  local groupName = spawned.name
  local dcsGroup = Group.getByName(groupName)
  if not dcsGroup then
    logger:warn(string.format("group [%s] was spawned but DCS does not know it; its role cannot be set up", veaf.p(groupName)))
    return nil
  end
  veafAircraftSpawn.forgetGoneGroups()
  veafAircraftSpawn.groupRoles[groupName] = roleName
  veafAircraftSpawn.groupRoutes[groupName] = route
  role.afterSpawn(dcsGroup, groupName, dcsGroup:getCoalition(), state)
  logger:debug("spawned airplane group %s as %s", veaf.p(groupName), veaf.p(roleName))
  return groupName
end

--- Is any unit of this group armed — does its payload carry pylons?
local function isArmed(units)
  for _, unit in pairs(units or {}) do
    local pylons = unit.payload and unit.payload.pylons
    if type(pylons) == "table" and next(pylons) ~= nil then
      return true
    end
  end
  return false
end

--- Spawn a helicopter group the ground path has placed, with the job its marker asked for.
---
--- The group is submitted under `HELICOPTER`: DCS refuses a helicopter submitted as an airplane
--- (`Invalid Unit Module`, R23). Its units sit at the ground height the spawn found for them.
---
--- The job is built from where the **first unit** stands, not from where the group was asked to go:
--- the ground path may move a whole group off scenery after choosing its point (`settleGroup`), and a
--- route starting elsewhere would send it back there.
---
--- @param groupData table `{ country, name, units, hidden, hiddenOnMFD }`, each unit carrying its
---   position (`x`, `y` the easting, `alt` the ground height), type, name, heading and payload
--- @param job table|nil `{ task, destination, altitude, speed, radius }` from the marker; no task is `parked`
--- @param silent boolean|nil true: a refusal is logged, not shown to the players
--- @return string|nil the group's name; nil when the job was refused or DCS did not take the group
function veafAircraftSpawn.spawnHelicopterGroup(groupData, job, silent)
  local logger = veaf.loggers.get(veafAircraftSpawn.Id)
  job = job or {}
  local roleName = job.task and string.lower(job.task) or "parked"
  local role = veafAircraftSpawn.roles[roleName]
  local function refuse(key, ...)
    local message = veaf.t(key, ...)
    logger:info(message)
    if not silent then
      trigger.action.outText(message, 10)
    end
    return nil
  end
  if not role or not role.helicopter then
    return refuse("spawn.helicopter_unknown_task", tostring(job.task), table.concat(veafAircraftSpawn.HELICOPTER_TASKS, ", "))
  end

  local leader = groupData.units and groupData.units[1]
  if not leader then
    -- every unit was refused by the position check: there is no helicopter to give a job to
    logger:info("no helicopter of %s could be placed", veaf.p(groupData.name))
    return nil
  end
  local spot = { x = leader.x, y = leader.alt, z = leader.y }
  local context = { spot = spot, params = job, armed = isArmed(groupData.units) }
  local route, state = role.buildRoute(context)
  state = state or {}
  if not route then
    return refuse(state.refusal or "spawn.helicopter_unknown_task", unpack(state.refusalArgs or { roleName, "" }))
  end

  local group = veaf.deepCopy(groupData)
  group.category = "HELICOPTER"
  group.task = state.task or "Transport"
  group.route = { points = route }
  group.uncontrolled = state.uncontrolled or nil
  for _, unit in pairs(group.units) do
    unit.alt_type = "BARO"
    unit.speed = 0
  end

  local spawned = veaf.addGroup(group)
  if not spawned then
    logger:error("cannot spawn helicopter group %s", veaf.p(group.name))
    return nil
  end
  local groupName = spawned.name
  veafAircraftSpawn.forgetGoneGroups()
  veafAircraftSpawn.groupRoles[groupName] = roleName
  local dcsGroup = Group.getByName(groupName)
  if role.afterSpawn then
    if dcsGroup then
      role.afterSpawn(dcsGroup, groupName, dcsGroup:getCoalition(), state)
    else
      logger:warn(string.format("group [%s] was spawned but DCS does not know it; its role cannot be set up", veaf.p(groupName)))
    end
  end
  logger:debug("spawned helicopter group %s as %s", veaf.p(groupName), veaf.p(roleName))
  return groupName
end

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
    local takeoffPoint = veafAircraftSpawn.takeoffPoint(templateRoute)
    if not takeoffPoint then
      -- An airborne role appears at `spot.y` and a `zone_defense` patrols there too. A QRA whose editor
      -- group answers no unit falls back to a spot at `y = 0`, sea level.
      spot = { x = spot.x, y = veafAircraftSpawn.flooredAltitude(spot, spot.y or 0), z = spot.z }
    end
    local context = {
      spot = spot,
      params = self.roleParams,
      firstWaypointTask = firstWaypointTask,
      templateSpeed = templateSpeedOf(templateRoute),
      takeoffPoint = takeoffPoint,
    }
    route, state = role.buildRoute(context)
    if not route then
      -- a refusal (`air_escort` with nothing to escort): the template's own route would spawn a group
      -- with none of the job it was asked for
      logger:info("%s refused the role %s: %s", veaf.p(self.templateName), veaf.p(self.roleName), veaf.p(state and state.refusal))
      return nil, state
    end
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
  veafAircraftSpawn.forgetGoneGroups()
  veafAircraftSpawn.groupRoles[groupName] = self.roleName
  veafAircraftSpawn.groupOptions[groupName] = firstWaypointTask
  veafAircraftSpawn.groupRoutes[groupName] = route
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
  veafAircraftSpawn.groupRoutes[groupName] = route
  role.afterSpawn(dcsGroup, groupName, dcsGroup:getCoalition(), state)
  logger:debug("%s now flies as %s", veaf.p(groupName), veaf.p(roleName))
  return true
end

--- Hand a group back the patrol its role gave it, from where it is now.
---
--- Setting the route replaces the controller's whole queue, so every task pushed on top of the patrol
--- goes with it. That is the point: the CAP watchdog cannot know which of its `EngageUnit` tasks DCS has
--- already removed (a dead target's task removes itself), so popping a counted number of them took the
--- patrol route out from under the CAP (FIX-IN-GAME-SESSION-2026-10-03 ticket 04).
---
--- The first point becomes the leader's position, a turning point at the leg's altitude and speed: the
--- stored one is the spawn point, a take-off for a QRA, and flying back to it is not patrolling. The
--- other points stay as they are, so the race-track's `SwitchWaypoint` (3 -> 2) still loops.
---
--- @param groupName string
--- @return boolean true when a route was set
function veafAircraftSpawn.resumePatrol(groupName)
  local logger = veaf.loggers.get(veafAircraftSpawn.Id)
  local route = veafAircraftSpawn.groupRoutes[groupName]
  local dcsGroup = Group.getByName(groupName)
  local leader = dcsGroup and dcsGroup:getUnit(1)
  if not (route and route[2] and leader) then
    logger:warn("cannot hand %s back its patrol: no stored route or no leader", veaf.p(groupName))
    return false
  end
  local position = leader:getPoint()
  local points = veaf.deepCopy(route)
  local options = veafAircraftSpawn.groupOptions[groupName]
  points[1] = {
    x = position.x,
    y = position.z,
    alt = route[2].alt,
    alt_type = "BARO",
    speed = route[2].speed,
    type = "Turning Point",
    action = "Turning Point",
    task = options and veaf.deepCopy(options) or emptyComboTask(),
  }
  logger:debug("%s resumes its patrol", veaf.p(groupName))
  return veaf.goRoute(dcsGroup, points)
end

veaf.loggers.get(veafAircraftSpawn.Id):info(veaf.loggers.get(veafAircraftSpawn.Id):getVersionInfo())
