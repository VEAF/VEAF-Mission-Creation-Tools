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

### [FEAT-ASSIST-FOLLOWUP](FEAT-ASSIST-FOLLOWUP/PRD.md) · 🧑

What `FEAT-ASSIST-CHECKLISTS` left open: content-hashed resource names (DCS caches images by name), two pilots at once, and a pilot's review of the F-16C slice. Kept for after a release.

### [FEAT-CTLD-AIRBASE-LOGISTICS](FEAT-CTLD-AIRBASE-LOGISTICS/PRD.md) · 🧑

Airfields become CTLD logistic zones (#1007): blue-from-start fields keep them, captured ones after two minutes of ground presence, marked by a green circle. Ramstein measured in game 2026-10-03: the C-130 parks 997 m from the 250 m circle; GermanyCW-v6 raises its radius, one re-read left.

### [FIX-COMBATMISSION-UNKNOWN-NAME](FIX-COMBATMISSION-UNKNOWN-NAME/PRD.md) · 🧑

Activating or deactivating a combat mission by a name the registry does not know — the bare name of an on-demand CAP — raised a Lua error instead of reporting it on screen. Fixed; the in-game look (R39) is left.

### [FIX-COMBATZONE-DEAD-UNIT-HAS-NO-GROUP](FIX-COMBATZONE-DEAD-UNIT-HAS-NO-GROUP/PRD.md) · 🧑

A combat zone's info panel and its completion disagreed: the panel was blind to static targets (fixed) and spawned vehicles now start warm — the scripts were seen asking for it in game on 2026-10-03. Ticket 02's thermal look is left.

### [FIX-COMBATZONE-RENAME-OPTION](FIX-COMBATZONE-RENAME-OPTION/PRD.md) · 🧑

A combat zone always renames its units (`renameUnitsSequentially` hard-coded), which hides the editor names while debugging (#289). To become a zone-level `combat_zones:` key.

### [FIX-OPEN-TRAINING-SYRIA-FINDINGS](FIX-OPEN-TRAINING-SYRIA-FINDINGS/PRD.md) · 🧑

What building the Syria Open Training v6 through the MCP found: callsigns, loadouts, QRA simple groups, FARP ammo, FAC task, METAR and more — 17 of 18 tickets done; 18 (JTAC codes) waits on VEAF/CTLD.

### [FIX-RELAY-RENDERS-MARKDOWN](FIX-RELAY-RENDERS-MARKDOWN/PRD.md) · 🧑

Comments relayed from GitHub to Discord showed their markup in a code block. Now a block quote with formatting applied, long comments split; one reading left in a real thread.

### [FIX-SCRATCH-MISSION-FINDINGS](FIX-SCRATCH-MISSION-FINDINGS/PRD.md) · 🧑

What building Open Training Germany CW from an empty folder found (weather, solar times, presets, MCP actions, defense levels…). Tickets 01–22 merged, 17 seen engaging in DCS; left: the rebuild with the fixed tools.

### [FIX-SECU-VERB-AND-LOG-NOISE](FIX-SECU-VERB-AND-LOG-NOISE/PRD.md) · 🧑

A private1 session where a level-99 pilot could not activate a zone, plus traceback-raising chat commands and log noise. Merged in #1032 and deployed; ticket 01's in-game check is left.

### [FIX-SKYNET-HELPER-AND-VENDORING](FIX-SKYNET-HELPER-AND-VENDORING/PRD.md) · 🧑

The VMCT half of The Reaper's report: dead actAsEW blocks removed, what a network SAM sees documented, Skynet 3.5.0 vendored, drift watch repaired. Only ticket 03's in-game reading is owed.

### [FIX-TRIPACK-FIELD-REPORTS](FIX-TRIPACK-FIELD-REPORTS/PRD.md) · 🧑

Three defects from one 6.19.0 flight: Skynet dead and silent, naval groups dragged onto land, a QRA that scrambles and never engages. All landed (#917, #918, #921); R12 and R13 are the in-game readings.

## ⏸ Paused

### [FEAT-ASSIST-AUTHORING](FEAT-ASSIST-AUTHORING/PRD.md) · ⏸

Guided checklists written by an instructor (`control: bouton power sur main pwr`) instead of element ids, through a deterministic matcher. Delivered in #651; ticket 05 (another aircraft) paused by David.

### [FEAT-BRIEFING-MAP](FEAT-BRIEFING-MAP/PRD.md) · ⏸

The briefing map drawn by the tools rather than by each mission's own script. Paused 2026-09-30: only missions built from the Open Training prompt need it.

### [REFACTOR-SPAWN-AIR-TEMPLATES](REFACTOR-SPAWN-AIR-TEMPLATES/PRD.md) · ⏸

How an air template is chosen for a spawn has no clear model (#284). Its one visible symptom (#240) is fixed; resume when a lot is already in this code.
