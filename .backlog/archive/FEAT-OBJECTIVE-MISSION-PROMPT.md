# FEAT-OBJECTIVE-MISSION-PROMPT — a prompt for an objective mission, played once in one session

Status: ✅ done · archived 2026-11-24

Asked by David on 2026-10-01. The Open Training prompt (`.prompts/new-open-training-mission.*.md`)
builds a theatre that runs for months; nothing covers a mission a group flies once: a package, one or
more objectives, a threat, a way home. The new prompt proposes a scenario first — as many as the user
wants, questions answered, a pre-briefing shown in the conversation on request — and writes nothing
until one is explicitly approved; it then builds the mission and a PPTX and/or PDF briefing following
the VEAF template (*Deep Strike Palmyra*).

Writing it found two gaps in the tools, closed in the same lot (David, 2026-10-01: "une seule PR pour
le prompt et le lot 2"):

- **No end-of-mission message.** Each zone announces its own completion, nothing announces "all
  objectives done". Combat **operations** already do ("Operation … is over"), but one could not be
  active at start from `mission.yaml` — the generator skipped `active_at_start` on operations, with no
  reason recorded (`fb99d706`) — and the completion hook given to an operation was stored and never
  called.
- **A map object cannot be an objective.** A zone only counts what it spawned; a bridge or a building
  of the map is spawned by nobody. The destroyed-scenery register (`veafMissionDb`, measured in game
  2026-08-28) already records them for the Combat Missions' *prevent destruction* objective; a zone
  had no way to use it, and the ids it needs exist only inside DCS.

Left out, on purpose: the mirror "destroy these map objects" objective for Combat Missions (David did
not take it up — the zone covers the need), and the ground-elevation table (its own lot,
[FEAT-TERRAIN-ELEVATION](FEAT-TERRAIN-ELEVATION.md)).

To measure in DCS before closing: that `world.searchObjects` over `Object.Category.SCENERY` returns the
map objects with the ids the register records, and that a zone holding only a `scenery_targets`
completes when the object is destroyed.

## Tickets

| # | Ticket | Status |
|---|--------|--------|
| 01 | [write the prompt (FR + EN) and point to it from the mission-maker doc](FEAT-OBJECTIVE-MISSION-PROMPT.md) | ✅ |
| 02 | [`active_at_start` on a combat operation](FEAT-OBJECTIVE-MISSION-PROMPT.md) | ✅ |
| 03 | [call the completion hook of an operation](FEAT-OBJECTIVE-MISSION-PROMPT.md) | ✅ |
| 04 | [`scenery_targets`: map objects a zone must see destroyed](FEAT-OBJECTIVE-MISSION-PROMPT.md) | ✅ |
| 05 | [`dcs scenery-objects` + `offer_scenery_lookup`: find a map object's id](FEAT-OBJECTIVE-MISSION-PROMPT.md) | ✅ |

## Former index entry

The row this lot had in `.backlog/README.md` until the index was split into short summaries (CHORE-BACKLOG-INDEX-SPLIT, 2026-10-03), kept verbatim.

**a prompt for an objective mission, played once in one session.** David, 2026-10-01. Proposes numbered scenarios (as many as wanted, pre-briefing in the conversation on request), writes nothing until one is approved, then builds the mission and a PPTX/PDF briefing in the VEAF template (*Deep Strike Palmyra*). Same lot closes the two gaps writing it found: an operation can be `active_at_start` (its "Operation … is over" is the end-of-mission message) and its completion hook is called; `scenery_targets` lets a zone count map objects, whose ids `dcs scenery-objects` / `offer_scenery_lookup` find. Waiting on an in-game check of the scenery part

## Tickets, in full

## 01 — write the prompt (FR + EN) and point to it from the mission-maker doc

Status: ✅ done

Files: `.prompts/new-objective-mission.fr.md`, `.prompts/new-objective-mission.en.md`,
`doc/mission-maker/AI_ASSISTANT_INSTALL.md` / `.en.md`, `CHANGELOG.md`.

### Done when

- Two phases with a strict line between them: numbered scenario sheets (one screen each, distances
  measured, flight time computed against the session length), questions answered, a pre-briefing in
  the conversation on request, **no write action** before an explicit approval of an identified
  scenario.
- The VEAF briefing template described page by page from *Deep Strike Palmyra* (cover, general
  situation, ATO, tactical situation + one zoom per objective, mission flow, flight plan, frequency
  plan, target coordinates).
- Build rules reusing what the Open Training prompt learnt where it applies (nothing from memory,
  carriers of the generated class, airfield channels from DCS, map generated from the mission's data,
  pictures on the blue and neutral lists only, opaque F10 labels), and the objective-mission specifics:
  one group per ATO flight, no dynamic slots, objectives as combat zones active at start,
  `chained_zones` for phases, route ↔ threat distances measured, a single weather.
- The briefing file generated from the **built** mission (coordinates, frequencies, flight plan,
  callsigns read back), not from the scenario.
- Gaps found while writing it: no action gives the ground elevation (stated in the prompt as a
  "Feedback for VMCT" item, lot FEAT-TERRAIN-ELEVATION); no end-of-mission message and no map object as
  an objective (closed by tickets 02-05, which the prompt then uses: objectives grouped in an operation
  active at start, `scenery_targets` found with `offer_scenery_lookup`).

## 02 — `active_at_start` on a combat operation

Status: ✅ done

Files: `veaf_libs/lua_config_generator.py`, `test/python/veaf_libs/test_lua_config_generator.py`,
`doc/mission-maker/scripts/veafCombatZone*.md`.

The generator emitted `veafCombatZone.ActivateZone(name, true)` for every `active_at_start` entry
**except** operations, since the key was introduced (`fb99d706`, no reason given). `ActivateZone` finds
an operation like any zone (`AddZone` registers it), so the exclusion only made the key silently
ignored on one.

### Done when

- An operation flagged `active_at_start` is activated after `initialize()`, like a zone.
- The operation's table in the combat zone page lists the key, and says that activating an operation
  activates all its zones at once (recorded in `known-limitations.yaml`,
  `operation-spawns-all-its-zones-at-once`).

## 03 — call the completion hook of an operation

Status: ✅ done

Files: `src/scripts/veaf/veafCombatZone.lua`, `test/lua/test_veafCombatZone.lua`.

`VeafCombatOperation:setOnCompletedHook` stored the function, and nothing called it: the operation
replaces the zone's `completionCheck`, which is where a zone calls its own hook, and
`updatePrimaryTasks` ended the operation (message, `desactivate`) without it.

### Done when

- `updatePrimaryTasks`, when no task is left, calls the hook with the operation, after the message.
- A luaunit test drives an operation with no task left and sees the hook called.

## 04 — `scenery_targets`: map objects a zone must see destroyed

Status: ✅ done — checked in game 2026-10-01 (after FIX-OBJECTIVE-COMPLETION subscribed the register)

Files: `veaf_libs/lua_config_generator.py`, `src/scripts/veaf/veafCombatZone.lua`,
`src/scripts/veaf/veafMissionDb.lua`, their tests, `doc/mission-maker/scripts/veafCombatZone*.md`.

### Done when

- `combat_zones[].scenery_targets: [<id>, …]` emits one `:addSceneryTarget(<id>)` per id, before
  `:initialize()`. A value that is not a positive integer (a string, a float, `true`, zero, a negative)
  stops the build: it would be a target that can never die.
- `VeafCombatZone:completionCheck` counts each target not yet in the destroyed-scenery register as an
  enemy, whichever side plays the zone. `veaf.isSceneryDestroyed(id)` is the façade.
- The F10 report counts the map objects left; a zone that `includes` another borrows its targets; the
  key on an operation stops the build; a zone with targets is documented as not replayable (the
  register keeps every destruction since the start).
- Tests: generator (setters emitted, bad values refused, refused on an operation); Lua (a standing
  target keeps the zone active, a destroyed one completes it, every target is needed, a non-id is
  ignored, an id is kept once, `includes` borrows, the report counts); the façade answers by id.

### To check in DCS

A zone holding only `scenery_targets: [<id of a bridge>]`, active at start: destroy the bridge, the zone
announces its completion within one watchdog period.

## 05 — `dcs scenery-objects` + `offer_scenery_lookup`: find a map object's id

Status: ✅ done — checked in game 2026-10-01: 63 objects around Kutaisi, id 89434905 the same in the register

Files: `veaf_libs/scenery_lookup.py` (new), `veaf_tools/commands/clear_ground.py`,
`veaf_tools/command_tree.py`, `veaf_tools/app.py`, `veaf_mission_mcp/actions.py`, the locales,
`doc/CLI_REFERENCE*.md`, `doc/mission-maker/GUIDE*.md`, `doc/developer/mission-editing-mcp*.md`.

The ids `scenery_targets` takes exist only inside DCS. The command reuses the `clear-ground-check`
session (dcs-serve, empty survey mission, instructions, waiting) and runs `world.searchObjects` over
`Object.Category.SCENERY` around each `--around x,y[,radius]` point; the MCP action, like
`offer_clear_ground_check`, launches nothing and returns the command.

### Done when

- One line per object: point, id (`getName`, the number the register keys on), type, position,
  distance to the point; sorted by point then distance; `--report` writes them as JSON.
- Mission `y` is sent as DCS `z`; a malformed point or a non-positive radius stops the command; an
  answer that is not the expected format raises instead of becoming an empty list.
- The command is machine-only (not in the TUI wizard), listed under `dcs`.

### To check in DCS

On Syria, around a known bridge: the command lists it, and the id it gives is the one the
destroyed-scenery register records when the bridge is destroyed (ticket 04's check, same object).
