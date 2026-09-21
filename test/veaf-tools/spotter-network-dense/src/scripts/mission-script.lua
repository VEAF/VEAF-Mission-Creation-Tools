-- mission-script.lua — the dense spotter-network demonstration
--
-- Loaded after veaf-config.lua, which the build generates from mission.yaml.
--
-- Where the walkthrough mission is the *discriminating* rig — the smallest layout in which a wrong
-- answer is impossible to mistake for a right one — this one is the *legibility* rig. It exists to be
-- looked at: two clusters packed the way a combat zone is packed, a screen of forward observation
-- posts spread over seventy kilometres, three air patrols, and a combat zone that is not there until
-- somebody activates it.
--
-- Geography, anchored on Palmyra (x = -56180, y = 214841). **Mission-table convention**: `x` is the
-- northing and `y` the easting — not the runtime one, see docs/agents/dcs-coordinates.md.
--
--   easting 196000   the observation-post screen, six posts 17 km apart over 95 km of front
--   easting ~211000  Tadmor (7 groups) and Arak (5 groups), each inside 2.5 km
--   easting 212000   Sukhna, the combat zone, absent until activated
--   easting 202-240k the three air patrols
--
-- The 17 km spacing is deliberate and so is the 27 km gap after it: the radio range is 20 km, so the
-- five northern posts form one chain that reaches both clusters, and `OP-Foxtrot-Isolated` is an
-- island. A network drawn without a visible island does not show that the range decides anything.

-------------------------------------------------------------------------------------------------
-- Keeping the batteries dark at start
--
-- Same reasoning as the walkthrough rig, and the same measurement behind it: a Skynet SAM site with
-- no valid parent radar hands itself to the DCS AI and sits permanently lit, so "no EWR" delivers the
-- opposite of a dark map. This mission *does* have an EWR — `Arak-EWR` — but it covers only its own
-- cluster, so the rest would still start lit.
--
-- Polled every two seconds for the first minute rather than scheduled once: the reset has to land
-- *after* `veafSkynet.delayedActivate`, because activating an IADS rebuilds its coverage and puts
-- every site back to its "correct" autonomous state. A fixed delay was both a guess and a stretch of
-- map covered in lit sites.
-------------------------------------------------------------------------------------------------

local DEMO_NETWORK = "red iads"
local RESET_POLL_SECONDS = 2
local RESET_POLL_UNTIL = 60

local function reportState(when)
  local iads = veafSkynet and veafSkynet.getIADS and veafSkynet.getIADS(DEMO_NETWORK)
  if not iads or not iads.getSAMSites then
    env.info("SPOTTER DENSE [" .. when .. "]: no red iads network — the VEAF Skynet helper did not build one")
    return
  end
  local lines = {}
  for _, site in ipairs(iads:getSAMSites()) do
    table.insert(
      lines,
      string.format(
        "%s=%s/%s",
        tostring(site.dcsName),
        site:isActive() and "LIVE" or "dark",
        site:getAutonomousState() and "autonomous" or "networked"
      )
    )
  end
  env.info("SPOTTER DENSE [" .. when .. "]: " .. table.concat(lines, " "))
end

timer.scheduleFunction(function(_, now)
  local iads = veafSkynet and veafSkynet.getIADS and veafSkynet.getIADS(DEMO_NETWORK)
  if iads and iads.getSAMSites then
    local corrected = 0
    for _, site in ipairs(iads:getSAMSites()) do
      if site:getAutonomousState() then
        pcall(site.resetAutonomousState, site)
        corrected = corrected + 1
      end
    end
    if corrected > 0 then
      env.info(string.format("SPOTTER DENSE: %d SAM site(s) set to wait for orders at %.0f s", corrected, timer.getTime()))
    end
  end
  if timer.getTime() < RESET_POLL_UNTIL then
    return now + RESET_POLL_SECONDS
  end
  reportState("settled")
  return nil
end, nil, timer.getTime() + RESET_POLL_SECONDS)

-------------------------------------------------------------------------------------------------
-- The intruder
--
-- Built by `coalition.addGroup` rather than placed in the mission table, and that is measured rather
-- than stylistic: `start_time` does not delay an aircraft group at all (a group with `start_time = 90`
-- was airborne at t = 9 s), and `lateActivation` hides a group from the map but **not** from the
-- scripting API. Before this call the aircraft does not exist in any sense.
--
-- **Invisible, not immortal**, and this is the lesson that cost a magazine. A SAM site goes live
-- because it was *told*, not because it can see — so an invisible intruder still lights the network up
-- while no DCS AI will engage it. An immortal one does the opposite: `SamCentre` in the walkthrough
-- emptied all twelve of its missiles into a target that could not die, and a site with no ammunition
-- never goes live again. Weapons hold is not an alternative either: Skynet sets ROE back to free
-- whenever it brings a site live, so a hold set beforehand does not hold.
--
-- 150 m/s with a dip in the middle, because a fast level run is classified as a **HARM** by Skynet
-- (`groundSpeed > 800 kt` and at most two changes of flight path) and sends the sites into evasion.
-------------------------------------------------------------------------------------------------

local CORRIDOR_Y = 190000 -- easting: just west of the observation-post screen at 196000
local INTRUDER_START_X, INTRUDER_END_X = -10000, -125000
local INTRUDER_ALT, INTRUDER_MID_ALT, INTRUDER_SPEED = 3000, 2000, 150
local INTRUDER_AT = 120

local function waypoint(x, alt)
  return {
    type = "Turning Point",
    action = "Turning Point",
    x = x,
    y = CORRIDOR_Y,
    alt = alt or INTRUDER_ALT,
    alt_type = "BARO",
    speed = INTRUDER_SPEED,
    ETA = 0,
    ETA_locked = false,
    speed_locked = true,
    task = { id = "ComboTask", params = { tasks = {} } },
  }
end

timer.scheduleFunction(function()
  local groupData = {
    name = "Intruder",
    task = "Nothing",
    x = INTRUDER_START_X,
    y = CORRIDOR_Y,
    -- Three legs rather than two: the middle one dips, which gives the altitude profile more than the
    -- two samples Skynet's HARM test allows.
    route = {
      points = {
        [1] = waypoint(INTRUDER_START_X, INTRUDER_ALT),
        [2] = waypoint((INTRUDER_START_X + INTRUDER_END_X) / 2, INTRUDER_MID_ALT),
        [3] = waypoint(INTRUDER_END_X, INTRUDER_ALT),
      },
    },
    units = {
      [1] = {
        name = "Intruder-1",
        type = "F-15C",
        skill = "Excellent",
        x = INTRUDER_START_X,
        y = CORRIDOR_Y,
        alt = INTRUDER_ALT,
        alt_type = "BARO",
        speed = INTRUDER_SPEED,
        -- **Pointing the way it is going**, in radians, 0 being north. It spawned at heading 0 while
        -- its route ran south, so it flew away from the screen, turned round, and only reached the
        -- first observation post a minute later than the geometry said. Measured 2026-09-21, and it
        -- made an in-mission recorder report "nobody sees it" for the whole of its window — a false
        -- alarm raised against a feature that was working.
        heading = math.pi,
        payload = { chaff = 0, flare = 0, fuel = 6103, gun = 100, pylons = {} },
        callsign = { [1] = 1, [2] = 1, [3] = 1, name = "Enfield11" },
      },
    },
  }
  local ok, err = pcall(coalition.addGroup, country.id.USA, Group.Category.AIRPLANE, groupData)
  if not ok then
    env.info("SPOTTER DENSE: the intruder could not be created: " .. tostring(err))
    return nil
  end
  env.info("SPOTTER DENSE: the intruder is in, heading south along the screen")

  -- Invisible to the DCS AI, so the demonstration is not cut short by the first missile. Re-applied
  -- twice: the command has to land on a group DCS has finished creating, and one attempt is an
  -- assumption.
  local function hide(tag)
    local dcsGroup = Group.getByName("Intruder")
    if not dcsGroup then
      env.info("SPOTTER DENSE: no intruder to hide [" .. tag .. "]")
      return
    end
    local hidden = pcall(function()
      dcsGroup:getController():setCommand({ id = "SetInvisible", params = { value = true } })
    end)
    env.info("SPOTTER DENSE: intruder invisible [" .. tag .. "]=" .. tostring(hidden))
  end
  hide("now")
  timer.scheduleFunction(function()
    hide("t+5")
    return nil
  end, nil, timer.getTime() + 5)
  return nil
end, nil, timer.getTime() + INTRUDER_AT)
