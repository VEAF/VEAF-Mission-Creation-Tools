# FIX-SCRATCH-MISSION-FINDINGS — what building one mission from scratch with 6.24.0 found

Status: 🧑 waiting-human — all 13 tickets merged: #992 (01–05, 09), #993 (06, 08), #994 (07), #995 (10), #996 (11–13). Left from the Definition of Done: rebuild GermanyCW-v6 with a release carrying them (the mission's own session: drop its workarounds, replace the `mission-script.lua` nesting with `includes:`), then mark ✅.

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
- CLAUDE.md quality-gate obligations (mypy exclusions of touched workers, coverage floor).
- `.backlog/README.md` row updated, docs touched in the same lot (PIPELINE_REFERENCE, GUIDE,
  AI_ASSISTANT_CATALOG for new actions).
