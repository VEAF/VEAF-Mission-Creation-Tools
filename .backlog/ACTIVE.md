# Active lots

[Back to the backlog](README.md)

Work started and not finished: in progress, waiting for a human, or deliberately paused.

## 🔄 In progress

*None.*

## 🧑 Waiting for a human

### [FEAT-OPPOSITION-SCALES-WITH-PLAYERS](FEAT-OPPOSITION-SCALES-WITH-PLAYERS/PRD.md) · 🧑

The air opposition sized to the number of players — an `opposition:` level set at generation, changed in flight (radio menu, `_opposition` marker) or following the players connected or airborne with a hysteresis — driving the QRA tiers and an "Auto scale" combat-mission entry; campaigns write it from `players` / `--players`. The three QRA defects found on Kolkhida mission 1 fixed on the way. With ticket 04, assault convoys sent by the campaign in flight. Merged on `develop` (#1100), the demo step in VEAF-Demo-Mission-v6; R46 in `DCS-SESSION-TODO.md` checks it in game.

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

The generated config called `veafCombatMission.initialize()` before adding the missions, so the MISSIONS radio menu was never built; `initialize()` now comes after them. Done and tested; waits on its in-game check with the v6 demo mission.

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
