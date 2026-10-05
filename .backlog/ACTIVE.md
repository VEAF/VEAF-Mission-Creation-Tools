# Active lots

[Back to the backlog](README.md)

Work started and not finished: in progress, waiting for a human, or deliberately paused.

## 🔄 In progress

*None.*

## 🧑 Waiting for a human

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

### [FEAT-CAP-WATCHDOG](FEAT-CAP-WATCHDOG/PRD.md) · 🧑

A CAP weighs its targets' aspect, does not chase a cold one more than 40 km away, and gives each aircraft its own target (#187). The removal handle (#178) and cruise missiles were dropped. Done on the mocks; waits on R42 in `DCS-SESSION-TODO.md` — does DCS honour a task on one aircraft's controller.

### [FEAT-AWACS-ESCORT-COMMANDS](FEAT-AWACS-ESCORT-COMMANDS/PRD.md) · 🧑

`-awacs` (an AWACS from its type, in Skynet, datalink on, optional escort) and `-escort` (fighters escorting the airplane next to the marker, or the pilot's own from F10). Done on the mocks; waits on R41 in `DCS-SESSION-TODO.md` — does the escort defend.

### [FEAT-SUPPORT-ASK-ESCALATE](FEAT-SUPPORT-ASK-ESCALATE/PRD.md) · 🧑

`@bot bug` / `@bot suggest` in an `/ask` thread opens `/bug` or `/suggest` pre-filled from the thread record, through the usual draft and confirmation; the answer's *Report a bug* button carries the whole thread too. Done on the fakes; waits on a check in the real Discord once the bot is redeployed.

### [FIX-COMBATZONE-DEAD-UNIT-HAS-NO-GROUP](FIX-COMBATZONE-DEAD-UNIT-HAS-NO-GROUP/PRD.md) · 🧑

A combat zone's info panel and its completion disagreed: the panel was blind to static targets (fixed) and spawned vehicles now start warm — the scripts were seen asking for it in game on 2026-10-03. Ticket 02's thermal look is left.

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

### [REFACTOR-SPAWN-AIR-TEMPLATES](REFACTOR-SPAWN-AIR-TEMPLATES/PRD.md) · ⏸

How an air template is chosen for a spawn has no clear model (#284). Its one visible symptom (#240) is fixed; resume when a lot is already in this code.
