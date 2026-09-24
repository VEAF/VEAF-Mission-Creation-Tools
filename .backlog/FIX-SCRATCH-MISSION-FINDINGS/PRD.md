# FIX-SCRATCH-MISSION-FINDINGS — what building one mission from scratch with 6.24.0 found

Status: 🔄 in-progress — reopened on 2026-09-24. Tickets 01–14 merged: #992 (01–05, 09), #993 (06, 08), #994 (07), #995 (10), #996 (11–13), #998 (14). Tickets 15–22 added from the second GermanyCW-v6 rebuild (2026-09-24, MODERN, MCP on develop), still to do. The rebuild with the fixed tools is still owed — see the Definition of Done.

## Origin

On 2026-09-23 an agent rebuilt the Open Training Germany Cold War mission **from an empty folder**
with `veaf-tools` 6.24.0 and the `veaf-mission-mcp` actions:
`scaffold_mission(standard, GermanyCW)` → 52 airbase coalitions → tankers, AWACS, QRA, CAPs,
combat zones → `validate` → `build`. The folder is
`D:\dev\_VEAF\VEAF-Open-Training-Mission-GermanyCW-v6` and is the test bench for this lot: every
figure below was measured on its build, or on the already-shipped
`VEAF-Open-Training-Mission-Caucasus` v6 build when it says so.

The scaffold path matters. Most of these defects are invisible in the missions converted from v5,
because those carry what the pipeline fails to produce (dynamic-slot templates placed in the
editor, weather set in the editor). A mission started with `prepare` has nothing of its own, so the
pipeline's gaps are all that is left — which is exactly the path the MCP recommends.

## The findings

| # | Defect | Measured |
|---|--------|----------|
| [01](tickets/01-weather-variants-never-reach-dcs.md) | Weather variants never change the weather DCS reads | Caucasus v6: `dawn-broken` and `dawn-overcast-rain` both fly Preset2 / 2500 m / 20 °C / calm; only a `weather.atmosphere` table DCS ignores differs. Same code since 21f3f386 (2025-11-25) |
| [02](tickets/02-solar-times-in-utc.md) | Solar times computed in UTC, the timezone is ignored | Ramstein 1980-06-01 `sunrise-15*60` → 03:13 (sunrise 03:28 UTC, 05:28 local) |
| [03](tickets/03-avwx-data-missing-from-exe.md) | Real-weather fetch fails in the packaged exe | `FileNotFoundError … _MEI…/avwx/data/files/stations.json` |
| [04](tickets/04-presets-step-too-early.md) | Presets step runs before aircraft injection | 64 dynamic-slot templates from YAML, 0 with a `Radio` table; log « injectés dans 0 aéronefs » |
| [05](tickets/05-bullseye-skipped-on-empty-plan.md) | No automatic BULLSEYE on a flight plan without waypoints | 0 of 64 blue templates, log says « sans plan de vol » |
| [06](tickets/06-composites-build-aircraft-as-vehicles.md) | `create_qra` / `create_cap_mission` build aircraft with the ground-vehicle builder — and statics and ships too | alt 0, "Off Road", 5.55 m/s, "Ground Nothing", no payload, no fuel; statics without `category` |
| [07](tickets/07-missing-authoring-actions.md) | Actions the agent had to replace with hand-written Lua | Tanker/AWACS/TACAN tasks, mission date, bullseye, briefing, `describe_units` on a folder |
| [08](tickets/08-mcp-side-effects-and-noise.md) | MCP side effects: backups inside `src/mission/`, needless rewrites, false alarm, garbled build output | 45–51 backup copies in one session |
| [09](tickets/09-small-truths.md) | Three small places where the tool says something false or nothing | `clearsky` undocumented, « QRA (0) », silent missing CSAR sound |
| [10](tickets/10-nested-combat-zones.md) | Nested combat zones (difficulty levels) cannot be expressed cleanly | only via Lua in `mission-script.lua`; prefix nesting defeated by destroy-at-init; borrowed `#command` keeps its origin `czName` |
| [11](tickets/11-teach-the-authoring-skill.md) | The authoring skill does not say what building a mission taught | drafted in `plugin/skills/veaf-mission-authoring/SKILL.md`, to review |
| [12](tickets/12-defense-levels-and-sam-aliases.md) | The `defense` levels and the SAM aliases do not say what they do | `list_shortcuts` hides `defense` ranges; `-samLR` places Roland/Hawk, no long range; levels ignore the era (M6 Linebacker in 1980) |
| [13](tickets/13-mcp-known-limitations.md) | The MCP exposes the known limitations, always up to date | new read-only `describe_known_limitations`, one versioned data file, lot rule |
| [14](tickets/14-open-training-prompt.md) | A reusable prompt to build an Open Training mission on any map | `.prompts/new-open-training-mission.fr.md` + `.en.md`, pointed to from the mission-maker doc |
| [15](tickets/15-build-forces-dynamic-spawn-on.md) | The build turns dynamic slots on at every airfield of a side, over `dynamic_spawn: false` | default `warehouses.yaml`: 61 airfields / 3 111 links, against 12 / 612 with an `airports:` list; `dynamicSpawn = True` unconditional |
| [16](tickets/16-ships-spaced-20-metres.md) | Ships placed 20 m apart | 4 ships over 100 m long at x = -16437 … -16377 |
| [17](tickets/17-cap-without-engage-task.md) | `create_cap_mission` makes a CAP with no engage task | `Orbit` alone on point 1; `add_task` appends after an endless orbit |
| [18](tickets/18-combat-zone-groups-have-no-route.md) | `create_combat_zone` takes no route for its groups | a convoy needs an empty zone + `add_group … for_combat_zone` |
| [19](tickets/19-more-missing-authoring-actions.md) | More actions replaced with scripts on the Lua table | FARP, base weather, unit rename/move, build profile, airfield list, batch coordinates; a misnamed parameter fails with no message |
| [20](tickets/20-validate-ignores-dynamic-slots.md) | `validate_mission` sees no player slot in a mission made of dynamic slots | two warnings on 12 bases / 102 injected types |
| [21](tickets/21-docs-that-do-not-describe-the-code.md) | Two docs that do not describe the code | `cap_missions[].default` is `secured`, `activated` is `radioMenuEnabled`; `standard` writes COMBATZONE / QRA commented |
| [22](tickets/22-qra-radio-menu-not-secured.md) | `radio_menu: true` on a QRA hands Start / Stop to every player, unsecured | `veafRadio.command("Arrêter QRA Berlin", ...)` with no level |

Tickets 01 and 02 are the ones that change what players fly. Ticket 04 is narrower than it first
looked — see its "What it is not" section — and ticket 06 is the one that makes aircraft fall out of
the sky, the same *class* of defect as `FIX-MCP-AUTHORING-GAPS` ticket 04 (valid file, aircraft
that cannot fly), one call away from where that lot fixed it.

## One lot, possibly two PRs

One lot, as David prefers. Tickets 01–05 and 09 live in the build pipeline, 06–08 in
`veaf_mission_mcp`, 10 in the combat-zone runtime and its generator, 11 in the plugin, 12 in the
shortcut/air-defense runtime and `list_shortcuts`, 13 in `veaf_mission_mcp` and its data. If the diff heads past ~150 000 characters (Sourcery's limit, CLAUDE.md), split
along that line — pipeline first, it is what players feel.

## Out of scope

- The GermanyCW mission itself: it keeps its workarounds (explicit BULLSEYE waypoint, Lua-patched
  tanker tasks) until this lot ships, then drops them.
- Parking data for GermanyCW (no runway / ramp start through the MCP there): a capture session in
  DCS, not a code change.

## Definition of Done

- Each ticket's "Done when" met, each fix with a test that failed before it.
- The GermanyCW-v6 folder rebuilt with the fixed tools: the 17 variants differ in the fields DCS
  reads, dawn is at dawn, the dynamic slots carry presets and a BULLSEYE.
- **The 2026-09-24 rebuild does not count.** It was built with 6.24.0, and the mission carries
  workarounds that would hide the fixes: dawn and evening at fixed hours in `src/versions.yaml`,
  group ids renumbered from 1001 and unit ids from 2001, `pipeline.spawnable_aircrafts: false`,
  `airports:` lists in `src/warehouses.yaml`, the training zones nested through
  `addZoneElementsFromZoneNamed` in `src/scripts/mission-script.lua`. The validation rebuilds with the
  tools of develop and removes these workarounds **one at a time**, measuring the `.miz` after each.
- CLAUDE.md quality-gate obligations (mypy exclusions of touched workers, coverage floor).
- `.backlog/README.md` row updated, docs touched in the same lot (PIPELINE_REFERENCE, GUIDE,
  AI_ASSISTANT_CATALOG for new actions).
