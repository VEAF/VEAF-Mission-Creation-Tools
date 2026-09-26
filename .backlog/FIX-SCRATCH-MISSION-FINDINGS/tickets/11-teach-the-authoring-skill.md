# 11 — Teach the authoring skill what building one mission taught

Status: ✅ done (#996)
Type: doc
Files: `plugin/skills/veaf-mission-authoring/SKILL.md`

## Why

David, after the GermanyCW-v6 rebuild: "ajoute des instructions au MCP pour que la prochaine fois
qu'on te demande de construire une mission tu saches déjà tout ça". The skill is what an agent loads
before authoring; what it does not say, the next agent rediscovers the hard way — or does not.

## What was drafted

In `SKILL.md`, already written:

- **Combat zones**: a group belongs to one zone in practice (zones destroy what they capture at start);
  difficulty levels as nested zones on one circle through `includes:`; inert targets are statics;
  convoys are native groups with a road route, their air defense in the same group.
- **Carriers**: the carrier's unit type = the class the alias spawns (threat ring in the editor);
  unique unit names with a suffix after the tag; alias options inside the tag; read unit names of an
  existing mission before judging a group (the v5 "lone Rapier radars" were 13 batteries).
- **New section "Building a complete mission — the checklist"**: adapt the scaffold's theatre-agnostic
  defaults, identity (`_ICAO_` with a live METAR, era/date, landmark bullseye, briefing), airbase
  colouring, support aircraft (tasks, non-overlapping tracks, one name everywhere, loadouts, air
  start), combat content (training range near a blue base in three levels, ≥ six more real zones of
  different kinds, SAM coverage vs bases/tankers, QRA circle), measured numbers in briefings,
  referenced sound files.
- **Finish**: a build exiting 0 is not a working mission — read the counters, open the `.miz`.

Deliberately **not** in the skill: workarounds for tickets 01–09 (hand-patched tanker tasks, explicit
BULLSEYE waypoint, static/ship conversion). This lot fixes them; a skill teaching workarounds for
fixed bugs would outlive them.

## To do

- Keep the skill consistent with what the lot actually ships: the `includes:` key (ticket 10), the new
  flight-task / date / bullseye / briefing actions (ticket 07) — name them in the skill once they exist
- Check the skill against `describe_naming_conventions` and the AI_ASSISTANT_CATALOG (no contradiction)
- Bump the plugin version with the release so installed plugins pick it up

## Done when

- David has reviewed the text; the skill names only actions and keys that exist in the release

## Outcome (PR 5)

Checked against the action catalogue (every action the skill names is registered) and against
`describe_naming_conventions` (`#alarm=` added to the markers list). Changes:

- Opens with `describe_known_limitations` and no longer lists tool traps (the air-start-on-an-
  uncaptured-theatre line points to the action instead).
- Names the #994 actions where the checklist used to describe hand-written Lua: `set_mission_date`,
  `set_bullseye`, `set_briefing`, `edit_route` `add_task` with `tanker` / `activate_beacon` /
  `set_unlimited_fuel` / `awacs` / `eplrs` / `escort`.
- `includes:` described as shipped (transitive, build-checked, one level at a time).
- Long range is `-samVLR`; `-samLR` is said to be medium range; `randomParameters` and the ±1 roll
  mentioned.
- Plugin version not bumped (CLAUDE.md §9.5: release only).
