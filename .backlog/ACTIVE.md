# Active lots

[Back to the backlog](README.md)

Work started and not finished: in progress, waiting for a human, or deliberately paused.

## 🔄 In progress

### [FEAT-AI-ZERO-SETUP](FEAT-AI-ZERO-SETUP/PRD.md) · 🔄

Installing veaf-tools is all an AI needs: `veaf-tools ai-setup` declares the MCP server in Claude Desktop, Claude Code and Gemini CLI, the server updates itself, the authoring guide and the two mission prompts ship in the executable, and the plugin is removed. Asked by David on 2026-10-20 after a demo in a clean sandbox behaved unlike his PC; found on the way: the plugin's binary had been stuck on 6.22.1 since September.

## 🧑 Waiting for a human

### [FEAT-FORCED-MISSION-OPTIONS](FEAT-FORCED-MISSION-OPTIONS/PRD.md) · 🧑

The mission options a mission maker sets by hand in the editor — labels, F10 view, external views… — from `mission.forced_options` in `mission.yaml`, the F10 view per role, an MCP action, and the carrier deck lights following VEAF air operations. From the `dcs-re` study of the editor's Lua (2026-10-19), with a page of editor tips. Done on the tests; left: what DCS applies in game, and three editor actions (`DCS-SESSION-TODO.md` R52).

### [FEAT-OPPOSITION-ZERO-AIRCRAFT](FEAT-OPPOSITION-ZERO-AIRCRAFT/PRD.md) · 🧑

An opposition level that sends no aircraft: *Opposition → Niveau → 0 avion* (or `_opposition 0`) keeps the QRA that scale with the opposition on the ground until the level is raised; a level followed down to 0 stays a count. Asked by David after *Kolkhida* mission 2. Done on the mocks; left: seeing Senaki's QRA stay down in game (`DCS-SESSION-TODO.md` R51).

### [FIX-SANCTUARY-WEAPON-TARGET-NO-ISEXIST](FIX-SANCTUARY-WEAPON-TARGET-NO-ISEXIST/PRD.md) · 🧑

12 `attempt to call method 'isExist' (a nil value)` in the Privé 1 log of the Sinai Open Training (2026-10-12): `weapon:getTarget()` returned an object with no `isExist`. The sanctuary now ignores such a target and logs its category once per mission. Measured: a Maverick on a unit gets a complete `Unit`. Left: the scenery and static cases, which need a pilot (`DCS-SESSION-TODO.md` R50).

### [FIX-OPEN-TRAINING-CAUCASUS-FINDINGS](FIX-OPEN-TRAINING-CAUCASUS-FINDINGS/PRD.md) · 🧑

What recompiling the Caucasus Open Training v6 in 6.29.0 found, each fixed by hand in the mission: no game master slot nor vehicle control in any v6 scaffold, a CTLD catalogue upgrade seen only in game, no dashed line on the F10 map, and (found on GermanyCW-v6) a committed presets report that names the machine. Plus (found on Syria-v6) a presets channel dropped without a word. Five tickets, one PR; ticket 03 waits for a look in DCS (R49).

### [FIX-FARP-PLACEMENT](FIX-FARP-PLACEMENT/PRD.md) · 🧑

A FARP placed in the jungle and on a slope with no warning (Marianas OT v6, seen in game). `add_farp` now checks its pad for trees (moved off them within 1 km, or `keep_position`) and slope (more than 3 m over 40 m) and says what it could not check; `veaf-tools dcs farp-spot` finds a flat, clear spot in DCS (#1125). Clearing the trees by trigger removed nothing in DCS and was taken out (ticket 02, two known limitations). Left: one live `farp-spot` run.

### [FIX-OPEN-TRAINING-MARIANAS-FINDINGS](FIX-OPEN-TRAINING-MARIANAS-FINDINGS/PRD.md) · 🧑

What building the Marianas Open Training v6 through the MCP found: a QRA group with a CAP task that landed, the carrier tanker taking the tankers' callsigns, no `loadout_from` on `add_air_group`, a weaponless J-11A and three mods in the shipped catalogue, read actions that disagreed, no ROE for a ground group, a placement warning that said nothing useful. Tickets 01–06 and 07's code done; left, ticket 07: the MarianaIslands sweeps in DCS.

### [FEAT-RADIO-MENU-WATCH](FEAT-RADIO-MENU-WATCH/PRD.md) · 🧑

Watching the F10 menu in a real multiplayer mission: the parked ids of FIX-RADIO-MENU-ID-RECYCLING pile up for the whole mission, cost nothing measurable in single player up to 50 000 (2026-10-10), but what a server sends its clients is not measured. A `RADIO.menu_stats` option logs the menu's size and changes, to turn on for an OT; the whitepaper on DCS recycling menu ids, FR and EN, ships with it. Merged on `develop` (#1117). Left, ticket 03: the three new Open Training missions built with the next VMCT release and the option on, measured on dcs.veaf.org; and ticket 04: DCS's clear binary shows an 8191-per-node ceiling the parked pool may hit, to settle with an in-game check before any fix.

### [FEAT-OPPOSITION-SCALES-WITH-PLAYERS](FEAT-OPPOSITION-SCALES-WITH-PLAYERS/PRD.md) · 🧑

The air opposition sized to the number of players — an `opposition:` level set at generation, changed in flight (radio menu, `_opposition` marker) or following the players connected or airborne with a hysteresis — driving the QRA tiers and an "Auto scale" combat-mission entry; campaigns write it from `players` / `--players`. The three QRA defects found on Kolkhida mission 1 fixed on the way. With ticket 04, assault convoys sent by the campaign in flight. Merged on `develop` (#1100), the demo step in VEAF-Demo-Mission-v6; R46 in `DCS-SESSION-TODO.md` checks it in game. Ticket 05, after Kolkhida mission 1: the level counts only the players on CAP (`follow: air_to_air`), and the radio menu sets it in one click (#1115).

### [FIX-CAMPAIGN-MISSION-1-FINDINGS](FIX-CAMPAIGN-MISSION-1-FINDINGS/PRD.md) · 🧑

What the squadron found flying *Kolkhida* mission 1 on 2026-10-08, with no script error all evening: no radio presets nor right kneeboard on any aircraft, ATC not silenced, garrison units on the runways, CTLD crates and troops unavailable at the blue airfields, objective waypoints in the air, a red convoy smoking itself for blue, and the server's DCSServerBot replacing the campaign's date, time and clear sky with real weather. Decided: a QRA takes off from the ground by default. Ten tickets, one PR: the code is in; left are the CTLD release that takes the unit's country, the server's MizEdit filter, and the in-game checks of R47. Ticket 11, `campaign apply` crashing on a state file already in its mission folder, ships in its own PR.

### [FEAT-CAMPAIGN-OBJECTIVE-WAYPOINTS](FEAT-CAMPAIGN-OBJECTIVE-WAYPOINTS/PRD.md) · 🧑

`campaign next` writes the mission's objectives as waypoints for the players' side (planes at 10 000 ft, helicopters at 500 ft above the ground), and the mission briefing gains a navigation page read from the built mission. To be checked on the next campaign mission.

### [FIX-ASSAULT-CONVOY-FINDINGS](FIX-ASSAULT-CONVOY-FINDINGS/PRD.md) · 🧑

Found on *Kolkhida* mission 1: the red assault convoy fled one infantryman seen just beyond its engagement range, then held forever waiting for an order nobody on red can give; Poti, taken by the blue convoy, drew a 24-unit garrison anyway; and assault convoys carry no armour. Merged on `develop` (#1108); tickets 01, 02 and 04 to be checked in game, ticket 03's measurement to be read at the next capture by a convoy.

### [FEAT-CAMPAIGN-INTEL-DELAY](FEAT-CAMPAIGN-INTEL-DELAY/PRD.md) · 🧑

The other side hears of an assault convoy `rules.intel_seconds` after it left (20 minutes by default), message and map line together; its own side at once. Merged on `develop` (#1106); to be checked in game.

### [FIX-CAMPAIGN-ARROW-ALTITUDE](FIX-CAMPAIGN-ARROW-ALTITUDE/PRD.md) · 🧑

DCS drew each assault-convoy arrow twice on the F10 map, one copy sliding as the map was panned; points on the terrain (#1103) did not change it. The axis becomes a line in the side's colour over the link. Merged on `develop` (#1105); the line to be checked in game.

### [FIX-SPAWN-DATA-LOAD-ORDER](FIX-SPAWN-DATA-LOAD-ORDER/PRD.md) · 🧑

A campaign draws its garrisons while `veaf-config.lua` runs, but the groups database loaded from a last trigger, after it: every garrison came out without its air defence (no SA-10 at Senaki). The spawn data loads with the framework instead, as the last action of its load triggers. Merged on `develop` (#1104); waits for Kolkhida mission 1 tonight: Senaki with its SA-10, no `cannot find group` in `dcs.log`.

### [FIX-BUNDLE-LOCAL-LIMIT](FIX-BUNDLE-LOCAL-LIMIT/PRD.md) · 🧑

The VEAF bundle built from `develop` no longer loads in DCS: concatenated, its modules declare more than the 200 top-level locals a Lua 5.1 chunk accepts. Each module goes into its own `do … end` block, and a test runs the bundle under Lua 5.1. Merged on `develop` (#1102); waits for Kolkhida mission 1 loading in DCS.

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

### [FIX-COMBATZONE-DEAD-UNIT-HAS-NO-GROUP](FIX-COMBATZONE-DEAD-UNIT-HAS-NO-GROUP/PRD.md) · 🧑

A combat zone's info panel and its completion disagreed: the panel was blind to static targets (fixed) and spawned vehicles now start warm — the scripts were seen asking for it in game on 2026-10-03. Ticket 02's thermal look is left.

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

### [FIX-SECU-VERB-AND-LOG-NOISE](FIX-SECU-VERB-AND-LOG-NOISE/PRD.md) · 🧑

A private1 session where a level-99 pilot could not activate a zone, plus traceback-raising chat commands and log noise. Merged in #1032 and deployed; ticket 01's in-game check is left.

### [FIX-TRIPACK-FIELD-REPORTS](FIX-TRIPACK-FIELD-REPORTS/PRD.md) · 🧑

Three defects from one 6.19.0 flight: Skynet dead and silent, naval groups dragged onto land, a QRA that scrambles and never engages. All landed (#917, #918, #921); R12 and R13 are the in-game readings.

## ⏸ Paused

### [FEAT-ASSIST-AUTHORING](FEAT-ASSIST-AUTHORING/PRD.md) · ⏸

Guided checklists written by an instructor (`control: bouton power sur main pwr`) instead of element ids, through a deterministic matcher. Delivered in #651; ticket 05 (another aircraft) paused by David.

### [FEAT-BRIEFING-MAP](FEAT-BRIEFING-MAP/PRD.md) · ⏸

The briefing map drawn by the tools rather than by each mission's own script. Paused 2026-09-30: only missions built from the Open Training prompt need it.

### [FEAT-DYNAMIC-CAMPAIGN](FEAT-DYNAMIC-CAMPAIGN/PRD.md) · ⏸

A Foothold-like persistent campaign built on VMCT alone. Paused 2026-10-06: David wants the multi-mission campaign first, and this lot will be built on the bricks it leaves.

### [REFACTOR-SPAWN-AIR-TEMPLATES](REFACTOR-SPAWN-AIR-TEMPLATES/PRD.md) · ⏸

How an air template is chosen for a spawn has no clear model (#284). Its one visible symptom (#240) is fixed; resume when a lot is already in this code.
