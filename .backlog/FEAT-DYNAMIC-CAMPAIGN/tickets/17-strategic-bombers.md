# 17 — Strategic bombers: an escorted red raid, a blue raid bought

Status: 🧑 waiting-human — built and tested outside DCS in #1282 (2026-11-16); the in-game check of the test mission is David's

PRD row "Strategic bombers"; analysis note 03 §12.

## What

- **Red raid**: every `bombers.seconds` (3600 s), the enemy side sends a bomber flight with an escort, paid from its resources (ticket 12), at the players' zone with the most to hit — a factory first, else the zone with the most garrison units. It starts in the air over the enemy airfield zone nearest the target that is at least `bombers.min_distance` (80 km) from it, so that the players have time to intercept without the raid crossing the whole map; the escort is the side's CAP aircraft, following the bomber.
- The players hear of it at once ("bombers inbound to …") and the task board posts an **intercept** task (`tasks.rewards.intercept`, 400) done when the bombers are shot down, withdrawn when the raid ends.
- **Blue raid**: a shop item, `bomber` (1200 credits), on an enemy zone: the players' bomber flight, with an escort, from their airfield zone chosen the same way; it bombs the zone's buildings and garrison and goes home.
- The bombers are declared like the other aircraft: `dynamic.air.<side>.bomber`, type and loadout; defaults Tu-22M3 `FAB-250*33` (red) and B-1B `Mk-82*84` (blue), one aircraft each — loadouts read from the shipped DCS ones.

## Done when

Lua tests: the raid's target, origin and timing; nothing sent when the side cannot pay or has no airfield far enough; the intercept task posted and closed; the shop item.
In game: the bomber flies to the target and drops; the escort follows it.

## Checked in game

2026-11-16, test mission `Dynamic Test`, red starting with 1500 points: the red raid left Senaki for Ozurgeti at about 15 min, and the intercept task was posted. Still to see: the drop, and the escort following its bomber.

The red stock of 300 the test campaign first had could never pay the first raid (CAP, helicopter and the strike leaving at the same beat leave ~200, the raid needs 160 above the reserve of 100): with the default values, a side affords raids only with factories standing — a point for the server tuning (ticket 10).

## Combined raid (David, 2026-11-16, after the first raid in game)

The first raid in game flew into the blue SAM umbrella over Ozurgeti: the Tu-22M3, locked, turned away south-east and jettisoned its bombs, which never armed, and was shot down on its way home; two red MiG-29 of the CAP were shot down by the same SAMs.

- A raid is now a package: a BARCAP on the axis out of the target's air defence reach (`barcapStation`), a SEAD flight ahead at the zone whose air defence covers the target, and the bomber `bombers.package_delay` (180 s) later.
- No escort by default (David: the BARCAP holds the approach, the last leg is the players' interception window); `bombers.escort: true` brings it back.
- The bomber does not react to threats (`REACTION_ON_THREAT` = `NO_REACTION`) nor jettison (`PROHIBIT_JETT`).
- Paid whole or not at all; the shop's raid is the same package, 1300 credits (220 points at 6 credits a point).
- The enemy's CAP circle stops `BARCAP_MARGIN` short of the players' air defence reach, `CAP_MIN_RADIUS` (5 km) at least.

## Take-off and a common hold (David, 2026-11-16, after the second raid in game)

The second raid (Senaki → Ozurgeti, SEAD on Kobuleti's Patriot) came apart: the SEAD, spawned in the air with its missiles reaching 30 km, fired at once; the bomber, spawned 180 s later heading north, went the long way round by the north-west and arrived minutes after the SEAD, the defences resupplied meanwhile, and was shot down; the BARCAP, held out of the target's reach only, lost a MiG-29 to Kobuleti's Patriot.
David: every campaign flight takes off from the ground, the raid too — starting it in the air was a choice of mine, never his.

- The BARCAP, SEAD, bomber and escort take off like every campaign flight.
- The SEAD and the bomber meet at a hold point on the target's axis, the first point out of every enemy air defence by `BARCAP_MARGIN` (over their airfield when none is), and orbit there until their user flag is raised, `HOLD_SECONDS` (1200 s) at most.
- Once both hold, the SEAD's flag is raised, the bomber's `bombers.package_delay` (now 30 s) later; a SEAD lost on the way lets the bomber push alone. The SEAD engages nothing before it leaves the hold.
- The bomber's `Bombing` task takes the axis it comes in on (`direction`), instead of leaving the AI to choose.
- The BARCAP's station is out of every enemy zone's reach (`edgeOfReach`), not only the target's.
- A raid is over when its bomber lands **after having flown**: on the ground at the start, it is not "home".
- Unchanged, decided: the network's 60 s repair of Kobuleti came from the test mission's `hop_seconds: 120`; with the default 600 s a repair takes at least five minutes.

## Holding for real, a carpet, and what the third raid showed (David, 2026-11-16)

The third raid took off and pushed 40 s later: the hold sat over Senaki (no point of the axis out of Kobuleti's Patriot), and "holding" only meant airborne within 15 km of it, so both pushed while climbing; the Tu-22M3, faster, led the SEAD. It then dropped one or two FAB-250 a pass out of its 33 (DCS folds identical log lines, "1 duplicate message(s) skipped", so the log undercounted). The Patriot shot two CAP MiG-29 then fell silent, for a reason the log could not tell. Two replacement CAPs were sent and paid within a second, under the same name.

- Holding = within `HOLD_REACHED` (now 5 km) **and** climbed to the flight's cruise altitude but `HOLD_ALTITUDE_SLACK` (1000 m).
- In a package the bomber flies at the SEAD's speed (`STRIKE_SPEED`).
- `CarpetBombing` (`attackType` Carpet, `carpetLength` `CARPET_LENGTH` = 1000 m, `expend` All) instead of `Bombing`; the point given as `x`/`y`, as the Mission Editor writes it, and as `point`. To be confirmed in game.
- A release logs what the aircraft has left, which also keeps DCS from folding two lines into one.
- `[CAMPAIGN AIRDEF]`, every `debug_status_seconds`: each zone's air defence units and their missiles left, empty launchers included.
- A flight counts as up for `FLIGHT_GRACE` (60 s) after its spawn even when DCS does not answer it by name yet, and a group name is never given twice.
- No enemy CAP where even its `CAP_MIN_RADIUS` circle is under the players' air defence (`capRadius` returns whether it was squeezed).

## Stuck on the taxiway, a sleeping SEAD target, and who wakes a zone (David, 2026-11-16)

Measured in game through dcs-bridge (side session of PR #1289). The raid deadlocked taxiing at Senaki: `takeoffFrom` took the free stands by `Term_Index`, and 2-6 are open stands (104) lined on the strip to the runway; DCS deadlocks there too when it picks the stands itself. Fighters in shelters (68) and the Tu-22M3 alone on the strip all took off. Kobuleti, the SEAD's zone, fell asleep 19 s after the raid was sent: only the bomber's target was kept awake. David asked that AI aircraft and ground units wake zones too, not only players.

- `takeoffFrom` takes shelters (`SHELTER_STAND_TYPE` 68) first, then open stands by `Term_Index`; an aircraft of `LARGE_AIRCRAFT` never takes a shelter (`getParking` gives no stand size). DCS honours the imposed stand (measured).
- `sendRaid` keeps the SEAD's zone awake for `RAID_TIMEOUT` too.
- `wakerPoints`: any aircraft in the air (AI or player, either side) within `wake_radius`, and any ground group that is neither a garrison (`unitIndex`) nor present at the first dormancy pass (`builtGroups`: a vehicle the mission maker parked would keep its zone awake forever; not at initialize, since veafGrass spawns the FARPs' vehicles 2 s later) within `ground_wake_radius` (10 km). The nearest waker of any kind comes first under `max_awake_zones`, a player first at the same distance.
- A late-activated aircraft wakes nothing: DCS answers `isExist()` and `inAir()` true before its activation, so `isActive()` is checked.
- Unchanged, decided: a spectator or game master slot wakes nothing.
- To measure in game: the cost of the pass over every group every beat.

## Waking by the front and by reach, and no take-off under a SAM (David, 2026-11-16)

The next test: with `max_awake_zones: 3` and AI aircraft waking every zone near them, five zones fought for three places and swapped at every pass (27 wakes in 3 minutes); Kobuleti, the SEAD's target, was evicted mid-raid. Kobuleti awake, its Patriot shot the whole raid package down over Senaki within 70 s of the take-off, then a lone SEAD strike too.
David: the front must always be awake, and a zone with an air defence must wake by the reach of that defence. Skynet considered and set aside for waking (it only sees through radars that exist, and a sleeping zone has none); putting woken SAMs into Skynet is a later lot.

- A zone on the front (connected to a zone its owner does not hold) or targeted by a sortie is always awake, outside `max_awake_zones`; only the rear counts against the cap.
- A zone of the rear wakes for its enemies only: an enemy player within `wake_radius`, or within its reach plus `reach_wake_margin` (20 km) when longer; an enemy aircraft in the air within that reach plus margin; an enemy ground group (not garrison, not built) within `ground_wake_radius`.
- The reach is measured from the missiles (`threatRange`) and remembered in `entry.reach`, saved with the zone; `sleep` measures it before the units go.
- Under the cap: a zone nobody wants any more gives its place first; a zone wanted by a player takes the place of one wanted by AI; between players the nearer wins; between AI zones the first keeps its place. A sleep logs its real reason.
- `canTakeOffFrom`: no sortie (CAP, BARCAP, strike, raid, Hunter, shop CAP) takes off from an airfield within an enemy zone's measured or remembered reach; an assumed reach grounds nobody.
- Corrected the same day (David): the front is the line drawn on the map, not the connections. Kobuleti and Ozurgeti, connected only to blue zones, were empty at the start; a zone just behind the line must not be when the enemy goes round. `isFront` is now `frontDistance` <= `front_depth` (40 km), the distance from the zone's centre to the Voronoi edges between zones of different owners (`frontSegments`, the territory's own geometry, cached by owners).
- Next test (David): no raid in 30 minutes. Every red field, Sukhumi 120 km away included, was "under the air defence of [Kobuleti]": `rangeMaxAltMax`, the missile's reach against a high target, is far longer than the range at which the Patriot sees an aircraft climbing out. `coveringEnemy` now cuts the reach to `takeoff_threat_range` (40 km, an estimation calibrated on the Senaki loss at about 38 km). A SEAD takes off all the same (David: it is there to put that defence out, and what it destroys frees the field for the strikes). The `[CAMPAIGN AIRDEF]` line now gives each zone's reach, measured or assumed, to read the real figure.
- Same test (David): the blue assault convoy met the red one by Poti; its unarmed vehicles fell back into the lagoon and drowned. `chooseRallyPoint` never looked at the surface, and the first leg of a fall back is off road, straight. `isDryDrive` samples that leg every 50 m (`DRY_STEP`), end included; a wet candidate is left out, and with water all around the convoy holds. Recorded as a DCS runtime trap.
- David: civil traffic is something VEAF always switches off. `blank_mission.py` now starts a new mission with `forcedOptions` civil traffic off, no birds, no random failures (`DEFAULT_FORCED_OPTIONS`, as the Foothold missions); the test campaign's template and mission 1 set them through `mission.forced_options`.
- First raid 3 min in (test campaign `bombers.seconds: 180`): the Patriot's reach logged at 120 km; the raid took off from Kutaisi (58 km, beyond the 40 km take-off threat range), its hold over Kutaisi (no point of the axis out of 120 + 15 km). The Tu-22M3 and the SEAD circled 10 minutes and never pushed: `HOLD_REACHED` (5 km) is less than the radius of an orbit at 200 m/s (some 7 km, estimated). Back to 15 km, the altitude telling the climb; a `[CAMPAIGN FLIGHT] raid on [..] waits at its hold` line every `HOLD_REPORT_SECONDS` (60 s) gives each flight's distance and altitude.
- Same test: no push was ever logged; the Tu-22M3 left when its orbit ran out. David saw it jettison its bombs arriving on the target, fired at by AAA; the log puts those 33 releases 50 km from its aim, which does not match: a release line now names the nearest zone and its distance, to read on the next test. The no-reaction and no-jettison options, set at the push point only, are now set from the take-off on as well, a defence that does not explain this jettison (the bomber was past its push point). Its SEAD flew over Kobuleti without firing a missile (it had fired its Kh-25MPU in an earlier test, so the missile is not the cause) and was shot down by a Gepard and an Avenger: cause not found yet.
- Fourth test: the hold worked (the SEAD pushed at 17:05:29, the bomber 30 s behind). The Tu-22M3 laid its 33 FAB-250 in one pass, 9.2 to 8.2 km short of the aim at 7000 m (the bombs carry on), and destroyed 25 scenery objects: no factory building, no garrison unit. David: a tighter carpet (100 m, `CARPET_LENGTH`) rather than a precision strike; bigger bombs (FAB-500*33, Mk-84*24 for the B-1B). The SEAD again flew over Kobuleti without a shot, shot down by the Patriot 2 min 25 s after its push; sent straight, in an earlier test, it had fired: its `EngageTargetsInZone` is now given at its take-off, ROE weapon hold, and the push point only sets it weapons free. A hypothesis to read in game.
- Fifth test: the SEAD fired (X_25MP 29 km from its aim, 10 s after its push) and kept the defences busy while the bomber came in: its targets from the take-off, weapons held until the push, was the cause. The bomber released, missed (DCS), then flew on over Kobuleti and was shot down. David: an egress point. After the target the bomber flies `EGRESS_DISTANCE` (20 km) back along its axis of approach before it turns home.
- Review of the lot's last commits: a zone connected to a zone of another side stays on the front however far the line (on a sparse map the line runs farther than `front_depth` from two connected enemies); `isDryDrive` leaves out the first `DRY_START` (150 m) of the drive, which starts from the column's average position, in the water when the column follows a shore.
