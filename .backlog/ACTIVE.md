# Active lots

[Back to the backlog](README.md)

Work started and not finished: in progress, waiting for a human, or deliberately paused.

## 🔄 In progress

## 🧑 Waiting for a human

### [FIX-CAMPAIGN-THIRD-SERVER-FLIGHT](FIX-CAMPAIGN-THIRD-SERVER-FLIGHT/PRD.md) · 🧑

What the third evening of "Bouclier de l'Oronte" taught (2026-11-19): a captured airfield offers no slot, since only the airbases owned at build time get Dynamic Slots; the sitac should show what Foothold's does. Scope decided by David: slots on every campaign airfield; players, ranking, ejected pilots, task board and support aircraft in the sitac block. Ten tickets, merged in #1321 (2026-11-20) and #1326 (2026-11-22), shipped in 6.39.0. Waits for ticket 08's redraw of the red garrisons in the Oronte save (live server, server empty, David's go: the same redraw as ticket 12 of FIX-CAMPAIGN-SECOND-SERVER-FLIGHT); the other tickets' in-game checks are flight checks.

### [FIX-CAMPAIGN-SIXTH-SERVER-FLIGHT](FIX-CAMPAIGN-SIXTH-SERVER-FLIGHT/PRD.md) · 🧑

What the 22/11 evening on the Campagne server showed: the capture shows the time left, no repair with an enemy convoy within `network.threat_radius`, an assault convoy gives up the enemies it pressed on in vain, a respawned aircraft keeps its callsign, a garrison's infantry holds one position near the centre, Menagh renamed Minakh in the campaign data (done on the server, 2026-11-23). One PR, merged in #1343 (2026-11-23), shipped in 6.39.1. Waits for ticket 05's measure in DCS (respawn `AWACS Magic` through the bridge and read its callsign before and after, expected `Magic11`; David's DCS was not running on 2026-11-23); the other tickets' flight checks are in their files.

### [FIX-RECON-OT-FINDINGS](FIX-RECON-OT-FINDINGS/PRD.md) · 🧑

The recon commands taught by the eight Open Training photo shoots (2026-11-17/18): one combat zone active at a time, DCS's own screenshot with the window in the background, terrain warm-up and positions read at the grab, one shot per combat zone from the kneeboard's objectives, one ring per group with plural category labels, names shown last in `veaf-config.lua`, a guard on a copy without its spawn database, and fourteen unit types of the spawn database called by their DCS ids. Five tickets, done in the code; waits for an Open Training shot end to end in David's DCS.

### [FIX-CAMPAIGN-FIFTH-SERVER-FLIGHT](FIX-CAMPAIGN-FIFTH-SERVER-FLIGHT/PRD.md) · 🧑

What the 22/11 afternoon on the Campagne server showed. Done: red strikes open fire on their targets only (ROE OPEN_FIRE, not weapons free), an AWACS holds `awacs_standoff` (100 km) from every enemy zone, a supply helicopter's timeout comes from its distance. Waiting: the in-game checks, and ticket 02's DCS measure (a Hawk inside the garrison's mixed group), not taken since DCS was not running; the red medium-range batteries turned out to be groups of their own already. PR into `feature/dynamic-campaign`.

### [FIX-SPAWN-GROUP-FIRST-ROUTE](FIX-SPAWN-GROUP-FIRST-ROUTE/PRD.md) · 🧑

A ground group spawned with a destination or a route (`veafSpawnCore`) got it in its creation frame, where DCS drops it; it now gets it 5 s later, as FIX-GROUNDAI-CLOSE-IN-REACHABLE did for the convoys. Its route already drove off road to the nearest road first (`generateVehiclesRoute`), now pinned by a test. Merged in #1331 (2026-11-22), shipped in 6.39.0. Waits for the local check: in a test mission, spawn a group with a destination by marker, away from any road; it leaves within 10 s and reaches the road (David's DCS, through the bridge).

### [FIX-CAMPAIGN-SECOND-SERVER-FLIGHT](FIX-CAMPAIGN-SECOND-SERVER-FLIGHT/PRD.md) · 🧑

What the second evening of "Bouclier de l'Oronte" on the Campagne server taught (2026-11-17): red aircraft that never take off at Taftanaz, a depot that repairs itself forever (decided: a depot has buildings to destroy), deliveries that bring a whole group back, helicopters and convoys that never arrive, freezes when a zone wakes, garrisons on roofs, a heavier air defence, per-pilot credits, the Campaign menu's admin commands last. Thirteen tickets, one PR, merged in #1310 (2026-11-18), shipped in 6.39.0. Waits for ticket 12's redraw of the red garrisons in the Oronte save (live server, server empty, David's go) and its in-game check; the other tickets' in-game checks are flight checks.

### [FEAT-DYNAMIC-CAMPAIGN](FEAT-DYNAMIC-CAMPAIGN/PRD.md) · 🧑

A Foothold-like persistent campaign built on VMCT alone, on the multi-mission campaign's bricks. V1 (#1276, 2026-11-15) and V1.5 (#1282, 2026-11-16) were merged into the integration branch `feature/dynamic-campaign`, with the fixes of each evening flown on the Campagne server since 2026-11-16 (#1293 and the lots after it); the branch went into `develop` on 2026-11-23 (#1336) and shipped in 6.39.0. Tickets 01–09 and 11–20 are done; their in-game checks are flight checks. Waits for ticket 10, the server measurement against Foothold: David's call (the profiler plugin has to be added to `opt_plugins` on the production bot) and the FPS comparison of a Foothold evening and a campaign evening.

### [FEAT-MISSION-WIND-CHECK](FEAT-MISSION-WIND-CHECK/PRD.md) · 🧑

All of the wind, on DCS's static-weather model decoded from `Weather.dll` and checked in game (whitepaper `dcs-wind-model`): the model as a standard-library `veaf_libs` brick tested on the five measured runs and shared with the DCSServerBot fork; the tools set the wind wanted at a reference airfield and compute `atGround` from it, with `at2000` at 2.2 × the ground veered 20° and the METAR's gust gap into `groundTurbulence`, by the measured gust mapping; the deck, the MCP answers, the guide and the prompts describe the simulated wind, with a helicopter rule on 0-600 m; `mission-check` compares the briefing with the model without DCS; the ATIS rounds its speeds and gains a "max wind 0-2000 ft" line. Seven tickets; from *Marteau du Golan* (2026-10-31), where 17 kt set and announced became 36 kt at 1,000 ft. Merged in #1239 (2026-11-04), with its demo step (VEAF/VEAF-Demo-Mission-v6#13, 2026-11-04). Waits for the ATIS max-wind line seen in game: a local check on David's DCS, through the bridge.

### [FIX-MARTEAU-PLAY-FINDINGS](FIX-MARTEAU-PLAY-FINDINGS/PRD.md) · 🧑

Fixes and rules from the evening of 2026-10-29 on Marteau du Golan, merged in #1221: AIEN counter-battery crash, the Opposition menu by default, a false CAP error, target coordinates in DDM + MGRS, four design rules, profiles that edit a combat zone by name, and a budget of recon photos. Waits for its in-game check, R53 of DCS-SESSION-TODO.md.

### [FIX-OPERATION-ZONE-DOUBLE-REGISTRATION](FIX-OPERATION-ZONE-DOUBLE-REGISTRATION/PRD.md) · 🧑

An operation's `addTaskingOrder` registered again a zone the configuration had already added, so `veafCombatZone.zonesList` held it twice and a loop over the list spawned it twice ("Marteau du Golan", 2026-10-28): `AddZone` now registers a name once. Merged in #1209; left: the mission-check inventory listing each member of OpMarteauGolan once, in game.

### [FIX-COWORK-SESSION-FINDINGS](FIX-COWORK-SESSION-FINDINGS/PRD.md) · 🧑

What Trakdah's Claude Cowork session of 2026-10-25 ("Fire at Adler") taught us: five defects (briefing pictures, same-named waypoints, `~`, diversion fields, slots by era), security explained, the briefing in the kneeboard, the opposition's skill, route planning and a `set_route` action, Cowork in the docs. Thirteen tickets, done in the code; waits on two checks in David's DCS (the kneeboard pages, the ground units' skill).

### [FEAT-FORCED-MISSION-OPTIONS](FEAT-FORCED-MISSION-OPTIONS/PRD.md) · 🧑

The mission options a mission maker sets by hand in the editor — labels, F10 view, external views… — from `mission.forced_options` in `mission.yaml`, the F10 view per role, an MCP action, and the carrier deck lights following VEAF air operations. From the `dcs-re` study of the editor's Lua (2026-10-19), with a page of editor tips. Done on the tests; left: what DCS applies in game, and three editor actions (`DCS-SESSION-TODO.md` R52).

### [FEAT-OPPOSITION-ZERO-AIRCRAFT](FEAT-OPPOSITION-ZERO-AIRCRAFT/PRD.md) · 🧑

An opposition level that sends no aircraft: *Opposition → Niveau → 0 avion* (or `_opposition 0`) keeps the QRA that scale with the opposition on the ground until the level is raised; a level followed down to 0 stays a count. Asked by David after *Kolkhida* mission 2. Done on the mocks; left: seeing Senaki's QRA stay down in game (`DCS-SESSION-TODO.md` R51).

### [FIX-OPEN-TRAINING-CAUCASUS-FINDINGS](FIX-OPEN-TRAINING-CAUCASUS-FINDINGS/PRD.md) · 🧑

What recompiling the Caucasus Open Training v6 in 6.29.0 found, each fixed by hand in the mission: no game master slot nor vehicle control in any v6 scaffold, a CTLD catalogue upgrade seen only in game, no dashed line on the F10 map, and (found on GermanyCW-v6) a committed presets report that names the machine. Plus (found on Syria-v6) a presets channel dropped without a word. Five tickets, one PR; ticket 03 waits for a look in DCS (R49).

### [FIX-FARP-PLACEMENT](FIX-FARP-PLACEMENT/PRD.md) · 🧑

A FARP placed in the jungle and on a slope with no warning (Marianas OT v6, seen in game). `add_farp` now checks its pad for trees (moved off them within 1 km, or `keep_position`) and slope (more than 3 m over 40 m) and says what it could not check; `veaf-tools dcs farp-spot` finds a flat, clear spot in DCS (#1125). Clearing the trees by trigger removed nothing in DCS and was taken out (ticket 02, two known limitations). Left: one live `farp-spot` run.

### [FIX-OPEN-TRAINING-MARIANAS-FINDINGS](FIX-OPEN-TRAINING-MARIANAS-FINDINGS/PRD.md) · 🧑

What building the Marianas Open Training v6 through the MCP found: a QRA group with a CAP task that landed, the carrier tanker taking the tankers' callsigns, no `loadout_from` on `add_air_group`, a weaponless J-11A and three mods in the shipped catalogue, read actions that disagreed, no ROE for a ground group, a placement warning that said nothing useful. Tickets 01–06 and 07's code done; left, ticket 07: the MarianaIslands sweeps in DCS.

### [FEAT-RADIO-MENU-WATCH](FEAT-RADIO-MENU-WATCH/PRD.md) · 🧑

Watching the F10 menu in a real multiplayer mission: the parked ids of FIX-RADIO-MENU-ID-RECYCLING pile up for the whole mission, cost nothing measurable in single player up to 50 000 (2026-10-10), but what a server sends its clients is not measured. A `RADIO.menu_stats` option logs the menu's size and changes, to turn on for an OT; the whitepaper on DCS recycling menu ids, FR and EN, ships with it. Merged on `develop` (#1117). Ticket 03 closed by David on 2026-10-29: the menu works on the Open Training missions, the network was not measured. Left, ticket 04: DCS's clear binary shows an 8191-per-node ceiling the parked pool may hit, to settle with an in-game check before any fix.

### [FEAT-OPPOSITION-SCALES-WITH-PLAYERS](FEAT-OPPOSITION-SCALES-WITH-PLAYERS/PRD.md) · 🧑

The air opposition sized to the number of players — an `opposition:` level set at generation, changed in flight (radio menu, `_opposition` marker) or following the players connected or airborne with a hysteresis — driving the QRA tiers and an "Auto scale" combat-mission entry; campaigns write it from `players` / `--players`. The three QRA defects found on Kolkhida mission 1 fixed on the way. With ticket 04, assault convoys sent by the campaign in flight. Merged on `develop` (#1100), the demo step in VEAF-Demo-Mission-v6; R46 in `DCS-SESSION-TODO.md` checks it in game. Ticket 05, after Kolkhida mission 1: the level counts only the players on CAP (`follow: air_to_air`), and the radio menu sets it in one click (#1115).

### [FIX-ASSAULT-CONVOY-FINDINGS](FIX-ASSAULT-CONVOY-FINDINGS/PRD.md) · 🧑

Found on *Kolkhida* mission 1: the red assault convoy fled one infantryman seen just beyond its engagement range, then held forever waiting for an order nobody on red can give; Poti, taken by the blue convoy, drew a 24-unit garrison anyway; and assault convoys carry no armour. Merged on `develop` (#1108); tickets 01, 02 and 04 to be checked in game, ticket 03's measurement to be read at the next capture by a convoy.

### [CHORE-SMS-QUICK-WINS](CHORE-SMS-QUICK-WINS/PRD.md) · 🧑

Three small items from the dcs-sms study: DCS coordinate conventions documented, a `dev_condition` hatch for checklists (both done), and the authoring skill shipped to other agents — waits on a Gemini CLI round trip.

### [DOC-PROMPTS-TWO-CARRIERS](DOC-PROMPTS-TWO-CARRIERS/PRD.md) · 🧑

The Open Training and objective-mission prompts ask for both the Stennis and the Roosevelt, each with its own TACAN, ICLS, Link 4 and frequencies. Prompt text only; waits on a mission built from it.

### [FEAT-AIRFIELD-FREQS-IN-ATIS](FEAT-AIRFIELD-FREQS-IN-ATIS/PRD.md) · 🧑

The ATIS and the welcome brief give the airfield's own tower and TACAN frequencies (and the mission's `bases` channel when it differs), from a reference table loaded with the scripts. Done and tested on the mocks; waits on its in-game check, R40 in `DCS-SESSION-TODO.md`.

### [FEAT-AIRWAVES-QRA-MERGE](FEAT-AIRWAVES-QRA-MERGE/PRD.md) · 🧑

One shared base (`veafReactiveZone`) under QRA and AirWaves, which keep their own state machines; entity links, mobile zones, friendly and support groups, closed zones, QRA logistics in YAML, and #1078. Done and tested on the mocks; waits on its in-game check, R43 in `DCS-SESSION-TODO.md`.

### [FEAT-ASSIST-FOLLOWUP](FEAT-ASSIST-FOLLOWUP/PRD.md) · 🧑

What `FEAT-ASSIST-CHECKLISTS` left open: content-hashed resource names (DCS caches images by name), two pilots at once, and a pilot's review of the F-16C slice. Waits on cockpit time: a second pilot, an F-16C pilot.

### [FEAT-CAMPAIGN-MISSION-BRIEFING](FEAT-CAMPAIGN-MISSION-BRIEFING/PRD.md) · 🧑

Each campaign mission gets its own VEAF mission briefing (ATO, tactical map, a zoom per objective, frequencies), read from the built mission, and a date, a time and a weather fixed by the campaign's progress, one variant, the ground always visible. Waits for David's reading of a generated mission briefing (Kolkhida mission 2).

### [FEAT-CAP-WATCHDOG](FEAT-CAP-WATCHDOG/PRD.md) · 🧑

A CAP weighs its targets' aspect, does not chase a cold one more than 40 km away, and gives each aircraft its own target (#187). The removal handle (#178) and cruise missiles were dropped. Done on the mocks; waits on R42 in `DCS-SESSION-TODO.md` — does DCS honour a task on one aircraft's controller.

### [FEAT-AWACS-ESCORT-COMMANDS](FEAT-AWACS-ESCORT-COMMANDS/PRD.md) · 🧑

`-awacs` (an AWACS from its type, in Skynet, datalink on, optional escort) and `-escort` (fighters escorting the airplane next to the marker, or the pilot's own from F10). Done on the mocks; waits on R41 in `DCS-SESSION-TODO.md` — does the escort defend.

### [FEAT-CAMPAIGN-BRIEFING-DECK](FEAT-CAMPAIGN-BRIEFING-DECK/PRD.md) · 🧑

The campaign's strategic briefing as a PPTX the squadron reads — a military situation brief (situation, intent, objectives, concept, rules of engagement), facts generated from the campaign, prose written by Claude, the enemy kept to uneven intelligence. Prototype kept in the lot.

### [FEAT-CONVOY-UNDER-FIRE](FEAT-CONVOY-UNDER-FIRE/PRD.md) · 🧑

A convoy that watches ahead for the enemy, splits when it sees one — the armed vehicles fight, the others flee at once — calls for CAS with smokes, and falls back behind terrain to a friendly place, instead of driving on while DCS lets it be destroyed. In `veafGroundAI`; DCS's behaviours measured in game first (2026-10-08). Merged on `develop` (#1099), seen working in game with the module hot-loaded; the demo step is in (VEAF-Demo-Mission-v6#2); R45 in `DCS-SESSION-TODO.md` checks the build.

### [FEAT-MULTI-MISSION-CAMPAIGN](FEAT-MULTI-MISSION-CAMPAIGN/PRD.md) · 🧑

A campaign flown mission after mission: each mission writes its state file during the flight, the tools merge it and play the enemy's bookkeeping, and Claude builds the next mission from the result — captured bases, destroyed bridges, depleted stocks and all. Builds the bricks `FEAT-DYNAMIC-CAMPAIGN` will reuse. Merged in #1092; waits for the in-game checks (R44 of `DCS-SESSION-TODO.md`) and the demo mission step.

### [FEAT-SUPPORT-ASK-ESCALATE](FEAT-SUPPORT-ASK-ESCALATE/PRD.md) · 🧑

`@bot bug` / `@bot suggest` in an `/ask` thread opens `/bug` or `/suggest` pre-filled from the thread record, through the usual draft and confirmation; the answer's *Report a bug* button carries the whole thread too. Done on the fakes; waits on a check in the real Discord once the bot is redeployed.

### [FIX-COMBATMISSION-MENU-MISSING](FIX-COMBATMISSION-MENU-MISSING/PRD.md) · 🧑

The generated config called `veafCombatMission.initialize()` before adding the missions, so the MISSIONS radio menu was never built; `initialize()` now comes after them. Done and tested; waits on its in-game check with the v6 demo mission. Ticket 02 fixes the 6.29.0 regression it caused: missions declared in a `mission-script.lua` put their « Activate mission » commands at the VEAF root; they now wait for MISSIONS, rebuilt once after the declarations.

### [FIX-DEMO-MISSION-FINDINGS](FIX-DEMO-MISSION-FINDINGS/PRD.md) · 🧑

What building and flying the v6 demo mission found: a `lua` user-menu action and an end-of-line comment in `ctld-config.yaml` each stopped the whole VEAF config with nothing in `validate` or the build to say so, and one module's init error takes all the others down; plus a build that exits 1 after succeeding, `-cargoships` spawning nothing, operations that cannot be activated from their menu, MCP authoring gaps and three small truths. Implemented; waits for the DCS check of tickets 01, 02, 03 and 05 and for the demo's workarounds to be removed.

### [FIX-DEMO-RECETTE-FINDINGS](FIX-DEMO-RECETTE-FINDINGS/PRD.md) · 🧑

Three defects the demo's first bridge recette found: `_destroy, radius` spares units it has already found, untranslated fog commands, the CAS group name stuck to « Blue CAS Group ». Implemented; waits for the demo's bridge recette (`recette_pont.py sandbox generated`) on a fresh test mission and the FR fog menu seen in DCS.

### [FIX-DUPLICATE-UNIT-NAMES](FIX-DUPLICATE-UNIT-NAMES/PRD.md) · 🧑

Spawned units of the same type in one group shared one name, so DCS could not resolve them and `-menage` spared them; wanted in 6.28.0. Units are now numbered (`<group> - <type> #<n>`); waits for the demo's bridge recette (`recette_pont.py --lang fr sandbox`) on a fresh test mission.

### [FIX-OPEN-TRAINING-SYRIA-FINDINGS](FIX-OPEN-TRAINING-SYRIA-FINDINGS/PRD.md) · 🧑

What building the Syria Open Training v6 through the MCP found: callsigns, loadouts, QRA simple groups, FARP ammo, FAC task, METAR and more — 17 of 18 tickets done; 18 (JTAC codes) waits on VEAF/CTLD.

### [FIX-RELAY-RENDERS-MARKDOWN](FIX-RELAY-RENDERS-MARKDOWN/PRD.md) · 🧑

Comments relayed from GitHub to Discord showed their markup in a code block. Now a block quote with formatting applied, long comments split; one reading left in a real thread.

### [FIX-TRIPACK-FIELD-REPORTS](FIX-TRIPACK-FIELD-REPORTS/PRD.md) · 🧑

Three defects from one 6.19.0 flight: Skynet dead and silent, naval groups dragged onto land, a QRA that scrambles and never engages. All landed (#917, #918, #921); R12 and R13 are the in-game readings.

## ⏸ Paused

### [FEAT-ASSIST-AUTHORING](FEAT-ASSIST-AUTHORING/PRD.md) · ⏸

Guided checklists written by an instructor (`control: bouton power sur main pwr`) instead of element ids, through a deterministic matcher. Delivered in #651; ticket 05 (another aircraft) paused by David.

### [FEAT-BRIEFING-MAP](FEAT-BRIEFING-MAP/PRD.md) · ⏸

The briefing map drawn by the tools rather than by each mission's own script. Paused 2026-09-30: only missions built from the Open Training prompt need it.

### [POC-AUTO-TOWER](POC-AUTO-TOWER/PRD.md) · ⏸

An automatic tower in French on the airfield VHF that frames the human pilots only, triggered by where they are (entry points, circuit, takeoff, landing), with no voice or F10 input. The idea came from reviewing the LivingRadio mod, not kept for our servers. Paused 2026-11-16: noted, not for now.

### [REFACTOR-SPAWN-AIR-TEMPLATES](REFACTOR-SPAWN-AIR-TEMPLATES/PRD.md) · ⏸

How an air template is chosen for a spawn has no clear model (#284). Its one visible symptom (#240) is fixed; resume when a lot is already in this code.
