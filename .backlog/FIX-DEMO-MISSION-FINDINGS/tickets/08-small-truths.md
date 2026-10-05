# 08 — Small truths

Status: ⬜ ready
Type: doc + i18n
Files: `doc/mission-maker/scripts/veafSpawn*.md`, `src/defaults/mission-folder/src/waypoints.yaml` (template comment), `src/scripts/veaf/veafCarrierOperations.lua` (l. ~864) + `veafI18n.lua`

| Where | What is false or missing | Fix |
|---|---|---|
| veafSpawn docs | `_spawn unit, name T-80, hdg 270` matches no DCS type (`veafUnits.findDcsUnit` compares to type and display name: `T-80UD`, `T-80B`…) | use `T-80UD` |
| `waypoints.yaml` template | the build adds a BULLSEYE waypoint to every plan (« N waypoints bullseye ajoutés »); the comment explains why the example is no longer called BULLSEYE, not that one is added — a maker who declares one gets two | say it in the comment |
| carrier ops menu | « Start carrier air operations for 45 minutes » is not translated in a `language: fr` mission | add the key to `veafI18n.lua` |
