-- mission-script.lua — spotter-network demonstration
--
-- Loaded after veaf-config.lua, which the build generates from mission.yaml.
--
-- One job: keep the SAM sites **dark and parentless** at start, so the only thing that can light one
-- up is a relayed report, and so the wave is visible as it travels down the corridor.

-------------------------------------------------------------------------------------------------
-- Why this is needed at all, and why it is not a hack
--
-- A Skynet SAM site is built with `isAutonomous = true` and an autonomous behaviour of
-- `AUTONOMOUS_STATE_DCS_AI` (skynet-iads-compiled.lua:3014). A site is autonomous exactly when no
-- valid parent radar covers it — so with **no EWR in the mission**, every battery hands itself to the
-- DCS AI and sits permanently lit. Nothing to watch, and no wave.
--
-- The obvious fix is to add an EWR. It does not work here, and that is measured rather than assumed:
-- only `55G6 EWR` and `1L13 EWR` carry the DCS `EWR` attribute, and both see far enough to spot the
-- intruder themselves — so they would light every battery at once, which is precisely the
-- demonstration this mission exists to give.
--
-- So: no EWR, `coverage_refresh_interval_s: 0` in mission.yaml, and one reset here. The interval
-- matters — `SkynetIADS:updateAutonomousStateIfChanged` corrects a site whose autonomy disagrees with
-- `hasValidParentRadar()`, and with no parent that check would put every battery straight back to
-- autonomous on the next sweep. With the sweep off, nothing re-evaluates it.
-------------------------------------------------------------------------------------------------

local DEMO_NETWORK = "red iads"

--- Put every SAM site of the network back to "covered": not autonomous, and dark.
--
-- @return number how many sites were reset
local function makeSitesWaitForOrders()
  local iads = veafSkynet and veafSkynet.getIADS and veafSkynet.getIADS(DEMO_NETWORK)
  if not iads or not iads.getSAMSites then
    return 0
  end
  local sites = iads:getSAMSites()
  for i = 1, #sites do
    -- `resetAutonomousState()` sets isAutonomous = false and calls goDark().
    pcall(sites[i].resetAutonomousState, sites[i])
  end
  return #sites
end

--- Say what the network looks like, so a demonstration that does not work says why.
local function reportState(when)
  local iads = veafSkynet and veafSkynet.getIADS and veafSkynet.getIADS(DEMO_NETWORK)
  if not iads or not iads.getSAMSites then
    env.info("SPOTTER DEMO [" .. when .. "]: no red iads network — the VEAF Skynet helper did not build one")
    return
  end
  local sites = iads:getSAMSites()
  local lines = {}
  for i = 1, #sites do
    local site = sites[i]
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
  env.info("SPOTTER DEMO [" .. when .. "]: " .. table.concat(lines, " "))
end

-- **Polled, not timed.** The reset has to land *after* `veafSkynet.delayedActivate`, because
-- activating an IADS rebuilds its radar coverage and puts every site back to its "correct" autonomous
-- state — with no parent radar, that means autonomous and lit. A reset scheduled before it is simply
-- overwritten: tried at 10 s on 2026-09-21, every battery was `LIVE/auto` again by t=64 s.
--
-- Moving it to 40 s worked, and was a magic number: nothing says the activation lands before 40 s,
-- and it left forty seconds of a map covered in lit sites — the very thing this mission exists to
-- avoid showing. So instead of guessing when the activation finishes, this checks every two seconds
-- and corrects whatever it finds, for the first minute. The window where a site is wrongly lit is
-- therefore at most two seconds, whenever the activation happens to land.
--
-- Bounded to a minute on purpose: after that the mission is running and a site going autonomous is
-- something to watch, not something to paper over.
local RESET_POLL_SECONDS = 2
local RESET_POLL_UNTIL = 60

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
      env.info(string.format("SPOTTER DEMO: %d SAM site(s) set to wait for orders at %.0f s", corrected, timer.getTime()))
      reportState("after reset")
    end
  end
  if timer.getTime() < RESET_POLL_UNTIL then
    return now + RESET_POLL_SECONDS
  end
  reportState("settled")
  return nil
end, nil, timer.getTime() + RESET_POLL_SECONDS)

-------------------------------------------------------------------------------------------------
-- The intruder, created from nothing at 90 s
--
-- It is **not** in the mission table, and the two mechanisms that look like they would delay it both
-- failed, measured on 2026-09-21:
--
--   * `start_time = 90` on an aircraft group does not delay its spawn at all — the group was
--     airborne at t = 9 s;
--   * `lateActivation = true` hides it from the map but **not from the scripting API**:
--     `coalition.getGroups` returned it, `isExist()` and `inAir()` both answered true, and the
--     spotter network held a contact on it thirty seconds before its activation. David saw a spotter
--     reporting an aircraft DCS had not spawned. (That one was a product defect too, and
--     `veafSkynet.listHostileAircraft` now tests `isActive()`.)
--
-- Building the group here is the only delay that is real: before this runs, the aircraft does not
-- exist in any sense.
-------------------------------------------------------------------------------------------------

local CORRIDOR_Y = 405386
local INTRUDER_START_X, INTRUDER_END_X = -15000, -70000
-- 150 m/s (≈290 kts) and an altitude that changes, and both numbers are measured rather than chosen.
--
-- The first run flew straight and level at a ground speed of **804.88 kts**, and Skynet identified it
-- as a **HARM**: its heuristic is `groundSpeed > 800 kts and #simpleAltitudeProfile <= 2`
-- (`SkynetIADSHARMDetection.HARM_THRESHOLD_SPEED_KTS = 800`), which is exactly the signature of an
-- anti-radiation missile — fast, dead level, going straight at the radar. That is Skynet working
-- correctly on a badly chosen intruder, and it actively fights the demonstration: a site that
-- identifies a HARM goes into evasion and shuts down.
--
-- Slowing it down clears the speed test; the varying altitude clears the profile test as well, so the
-- classification cannot come back if DCS lets the aircraft accelerate past its waypoint speed again.
local INTRUDER_ALT, INTRUDER_SPEED = 3000, 150
local INTRUDER_MID_ALT = 2000

--- One waypoint of the intruder's run down the corridor.
--
-- Mission-table shape: `x` is the northing and `y` the easting, because `coalition.addGroup` takes a
-- mission-editor group table and not a runtime vec3. See docs/agents/dcs-coordinates.md.
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
    -- Three legs rather than two: the middle one dips, which is what gives the altitude profile more
    -- than the two samples Skynet's HARM test allows.
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
        -- **Pointing the way it is going**, in radians, 0 being north. Spawned at heading 0 with a
        -- route running south, it flies away from the corridor, turns round and arrives about a
        -- minute late — long enough for a measurement window to close on "nobody sees it" while the
        -- feature is working. Found on the dense mission, 2026-09-21, and the same here.
        heading = math.pi,
        payload = { chaff = 0, flare = 0, fuel = 6103, gun = 100, pylons = {} },
        callsign = { [1] = 1, [2] = 1, [3] = 1, name = "Enfield11" },
      },
    },
  }
  local ok, err = pcall(coalition.addGroup, country.id.USA, Group.Category.AIRPLANE, groupData)
  if ok then
    env.info("SPOTTER DEMO: the intruder is in, heading south down the corridor")
  else
    env.info("SPOTTER DEMO: the intruder could not be created: " .. tostring(err))
  end
  return nil
end, nil, timer.getTime() + 90)
