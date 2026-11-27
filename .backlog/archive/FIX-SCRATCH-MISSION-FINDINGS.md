# FIX-SCRATCH-MISSION-FINDINGS — what building one mission from scratch with 6.24.0 found

Status: ✅ done — reopened on 2026-09-24 (#999). Tickets 01–14 merged: #992 (01–05, 09), #993 (06, 08), #994 (07), #995 (10), #996 (11–13), #998 (14). Tickets 15–22 (second GermanyCW-v6 rebuild, 2026-09-24) merged in #1000; 17 checked in DCS on 2026-10-03 (the fixed template engages). ✅ done 2026-10-04: the rebuild with the fixed tools was done on 2026-09-25 in the GermanyCW-v6 repository — its `docs/journal-v6.md` records the five workarounds removed and the rebuild validated (weather differing per variant, dawn at 05:23, presets on 62 of 102 templates). · archived 2026-11-24

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
| [01](FIX-SCRATCH-MISSION-FINDINGS.md) | Weather variants never change the weather DCS reads | Caucasus v6: `dawn-broken` and `dawn-overcast-rain` both fly Preset2 / 2500 m / 20 °C / calm; only a `weather.atmosphere` table DCS ignores differs. Same code since 21f3f386 (2025-11-25) |
| [02](FIX-SCRATCH-MISSION-FINDINGS.md) | Solar times computed in UTC, the timezone is ignored | Ramstein 1980-06-01 `sunrise-15*60` → 03:13 (sunrise 03:28 UTC, 05:28 local) |
| [03](FIX-SCRATCH-MISSION-FINDINGS.md) | Real-weather fetch fails in the packaged exe | `FileNotFoundError … _MEI…/avwx/data/files/stations.json` |
| [04](FIX-SCRATCH-MISSION-FINDINGS.md) | Presets step runs before aircraft injection | 64 dynamic-slot templates from YAML, 0 with a `Radio` table; log « injectés dans 0 aéronefs » |
| [05](FIX-SCRATCH-MISSION-FINDINGS.md) | No automatic BULLSEYE on a flight plan without waypoints | 0 of 64 blue templates, log says « sans plan de vol » |
| [06](FIX-SCRATCH-MISSION-FINDINGS.md) | `create_qra` / `create_cap_mission` build aircraft with the ground-vehicle builder — and statics and ships too | alt 0, "Off Road", 5.55 m/s, "Ground Nothing", no payload, no fuel; statics without `category` |
| [07](FIX-SCRATCH-MISSION-FINDINGS.md) | Actions the agent had to replace with hand-written Lua | Tanker/AWACS/TACAN tasks, mission date, bullseye, briefing, `describe_units` on a folder |
| [08](FIX-SCRATCH-MISSION-FINDINGS.md) | MCP side effects: backups inside `src/mission/`, needless rewrites, false alarm, garbled build output | 45–51 backup copies in one session |
| [09](FIX-SCRATCH-MISSION-FINDINGS.md) | Three small places where the tool says something false or nothing | `clearsky` undocumented, « QRA (0) », silent missing CSAR sound |
| [10](FIX-SCRATCH-MISSION-FINDINGS.md) | Nested combat zones (difficulty levels) cannot be expressed cleanly | only via Lua in `mission-script.lua`; prefix nesting defeated by destroy-at-init; borrowed `#command` keeps its origin `czName` |
| [11](FIX-SCRATCH-MISSION-FINDINGS.md) | The authoring skill does not say what building a mission taught | drafted in `plugin/skills/veaf-mission-authoring/SKILL.md`, to review |
| [12](FIX-SCRATCH-MISSION-FINDINGS.md) | The `defense` levels and the SAM aliases do not say what they do | `list_shortcuts` hides `defense` ranges; `-samLR` places Roland/Hawk, no long range; levels ignore the era (M6 Linebacker in 1980) |
| [13](FIX-SCRATCH-MISSION-FINDINGS.md) | The MCP exposes the known limitations, always up to date | new read-only `describe_known_limitations`, one versioned data file, lot rule |
| [14](FIX-SCRATCH-MISSION-FINDINGS.md) | A reusable prompt to build an Open Training mission on any map | `.prompts/new-open-training-mission.fr.md` + `.en.md`, pointed to from the mission-maker doc |
| [15](FIX-SCRATCH-MISSION-FINDINGS.md) | The build turns dynamic slots on at every airfield of a side, over `dynamic_spawn: false` | default `warehouses.yaml`: 61 airfields / 3 111 links, against 12 / 612 with an `airports:` list; `dynamicSpawn = True` unconditional |
| [16](FIX-SCRATCH-MISSION-FINDINGS.md) | Ships placed 20 m apart | 4 ships over 100 m long at x = -16437 … -16377 |
| [17](FIX-SCRATCH-MISSION-FINDINGS.md) | `create_cap_mission` makes a CAP with no engage task | `Orbit` alone on point 1; `add_task` appends after an endless orbit |
| [18](FIX-SCRATCH-MISSION-FINDINGS.md) | `create_combat_zone` takes no route for its groups | a convoy needs an empty zone + `add_group … for_combat_zone` |
| [19](FIX-SCRATCH-MISSION-FINDINGS.md) | More actions replaced with scripts on the Lua table | FARP, base weather, unit rename/move, build profile, airfield list, batch coordinates; a misnamed parameter fails with no message |
| [20](FIX-SCRATCH-MISSION-FINDINGS.md) | `validate_mission` sees no player slot in a mission made of dynamic slots | two warnings on 12 bases / 102 injected types |
| [21](FIX-SCRATCH-MISSION-FINDINGS.md) | Two docs that do not describe the code | `cap_missions[].default` is `secured`, `activated` is `radioMenuEnabled`; `standard` writes COMBATZONE / QRA commented |
| [22](FIX-SCRATCH-MISSION-FINDINGS.md) | `radio_menu: true` on a QRA hands Start / Stop to every player, unsecured | `veafRadio.command("Arrêter QRA Berlin", ...)` with no level |

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

## Former index entry

The row this lot had in `.backlog/README.md` until the index was split into short summaries (CHORE-BACKLOG-INDEX-SPLIT, 2026-10-03), kept verbatim.

**what building one mission from an empty folder with 6.24.0 found.** Open Training Germany CW rebuilt from scratch on 2026-09-23 through `prepare` and the MCP actions. Nine defects, measured on that build and on the shipped Caucasus v6: the weather variants never touch the fields DCS reads (a `weather.atmosphere` table DCS ignores, since the feature's first commit); solar times computed in UTC; the exe cannot fetch real weather (avwx data not bundled); presets run before the YAML-injected dynamic-slot templates exist (0 of 64 — templates placed in the source mission are fine); no BULLSEYE on an empty flight plan; `create_qra` / `create_cap_mission` build aircraft with the ground-vehicle builder; five actions missing (flight tasks, date, bullseye, briefing, `describe_units` on a folder); backups written inside `src/mission/`; three small untruths; the `defense` levels and SAM aliases do not say what they place (`-samLR` has no long range, levels ignore the era); and a `describe_known_limitations` MCP action fed by one versioned data file. Plus nested combat zones (difficulty levels) that only Lua can express, and the authoring skill taught what the build taught (drafted). PR 1 (build pipeline, 01–05 and 09) merged, PR 2 (MCP, 06 and 08) merged, PR 3 (authoring actions, 07) merged (#994), PR 4 (nested combat zones, 10) merged (#995), PR 5 (skill, defense levels, known limitations: 11–13) merged (#996), the Open Training prompt (14) merged (#998). **Reopened on 2026-09-24** with tickets 15–22 from a second GermanyCW-v6 rebuild (MODERN, MCP on develop): the build turns dynamic slots on at every airfield of a side over `dynamic_spawn: false` (61 airfields / 3 111 links instead of 12 / 612); ships placed 20 m apart; a CAP with no engage task; no route for combat-zone groups; more missing actions (FARP, base weather, unit rename/move, build profile, airfield list) and a misnamed parameter failing with no message; `validate_mission` blind to dynamic slots; `cap_missions[].default`/`activated` documented as what they are not; an unsecured QRA radio menu. That rebuild used 6.24.0 and carries workarounds, so it does not validate the lot. PR 6 (15–22) merged (#1000); found on the way that since mcp 2.x every action failure reached the agent as a bare `Error executing tool run_action`. Left: the GermanyCW-v6 rebuild with the fixed tools, and ticket 17's check in DCS

## Tickets, in full

## 01 — Weather variants never change the weather DCS reads

Status: ✅ done
Type: fix
Files: `src/python/veaf-tools/weather_injector/weather/dcs_weather_converter.py`,
`weather_injector/weather_injector_worker.py` (`_set_mission_weather`, clearsky block), tests

### What happens

`DCSWeatherConverter` (~l. 97-120) builds

```python
{"atmosphere": {"temperature_celsius", "wind": {"speed_mps", "direction_degrees"},
                "visibility_meters", "clouds": {"type", "base_altitude_meters", "density"}},
 "fog": {"enabled", "density", "thickness_meters"}}
```

and `_set_mission_weather` does `current.update(weather)`. The mission gains two keys DCS does not
know, and the fields DCS **does** read keep the base mission's values: `clouds.preset / base /
thickness / density / iprecptns`, `season.temperature`, `wind.atGround / at2000 / at8000`, `qnh`,
`visibility.distance`, `enable_fog`, `fog.visibility / thickness`.

Unchanged since the feature's first commit, 21f3f386 (2025-11-25) — `git log -S'"atmosphere"'`.

### Measured

Caucasus v6 (`VEAF-Open-Training-Mission-Caucasus/missions`, built 2026-07-15):

| variant | DCS fields | `atmosphere` |
|---|---|---|
| dawn-broken | Preset2, base 2500, 20 °C, wind 0, qnh 760 | 23.2 °C, base 3400 |
| dawn-overcast-rain | Preset2, base 2500, 20 °C, wind 0, qnh 760 | 16.4 °C, base 2900 |

GermanyCW-v6: all 17 variants Preset1 / base 0 / 20 °C / calm (the synthetic blank mission's values).

David remembers testing weather early in v6 and seeing it work. Worth finding out what was tested:
the **time** does change per variant (`start_time` is written directly), which may be what was seen.

### What ships

- A converter that writes the DCS schema. Coverage → `clouds.preset` needs care: DCS presets
  (`Preset1..27`, `RainyPreset1..3`) are what DCS renders since 2.7; `density` is ignored when a
  preset is set. Pick presets per METAR coverage (FEW/SCT/BKN/OVC) and base.
- **Precipitation**: a METAR `RA` / `SHRA` / `TS` must reach DCS (`RainyPreset*`, `iprecptns`), else a
  "rain" variant is dry. The `weather:` object has no precipitation field — add one, or document that
  rain needs a METAR.
- `qnh` from the METAR (DCS stores mmHg), wind at ground and aloft, temperature in `season`.
- `clearsky` applied to the DCS fields.
- Stop writing `atmosphere` / top-level `fog` into the mission.

### Done when

- A test builds two variants from different METARs and asserts different values **in the DCS
  fields**, not in the converter's intermediate dict
- GermanyCW-v6 rebuilt: `day-scattered`, `day-overcast-rain`, `day-real` differ in `clouds.preset`,
  `season.temperature`, `wind.atGround`
- One variant opened in DCS shows the expected sky (David, a glance)

### Outcome (PR 1)

- The converter writes the DCS fields (`season`, `wind.atGround/at2000/at8000`, `visibility`,
  `clouds.preset/base`, `qnh`, `enable_fog`/`fog`, `atmosphere_type = 0`); `atmosphere` is dropped.
  Presets are chosen deterministically from the coverage, inside the base range DCS accepts
  (`presetAltMin`/`presetAltMax` of `Config/Effects/clouds.lua`); v5 picked them at random.
- Precipitation: METAR `RA`/`DZ`/`TS`... → `RainyPreset1`; `weather.precipitation` added. Snow left
  out: no DCS preset renders it, unchecked below zero.
- Found on the way: **the live fetch had never worked**. It read `metar.temperature`,
  `metar.clouds[i][0]`... — the avwx `Metar` has none of these (values live under `.data`), so every
  fetch died on AttributeError and fell back; the test's fake carried the invented API. The fetch now
  parses the published text with the same parser as a written METAR.
- `convert-v5`: DCS wind is stored "to", `weather.wind_direction` is "from" → converted; Preset19–27
  and RainyPreset* were unmapped and read as scattered.
- Bench (GermanyCW-v6 copy, fixed exe): day-real Preset13 / 9 °C / calm / 766.8 mmHg, day-scattered
  Preset5 / 23.2 °C / 4.5 m/s, day-overcast-rain RainyPreset1 / 16 °C / 763.6 mmHg / 6 km.
- Checked in DCS by David on 2026-09-24 (`day-overcast-rain`): ok.

## 02 — Solar times are computed in UTC; the timezone is ignored

Status: ✅ done
Type: fix
Files: `src/python/veaf-tools/weather_injector/utils/solar_calculator.py`, tests

### What happens

```python
loc = LocationInfo(latitude=..., longitude=..., timezone=position.timezone)
times = sun(loc.observer, date=target_date)
```

`astral.sun.sun()` returns **UTC** unless given `tzinfo`. `position.timezone` goes into `LocationInfo`
and is never used again, so every `sunrise…` / `sunset…` expression lands in UTC.

### Measured

- GermanyCW-v6, Ramstein, `Europe/Berlin`, 1980-06-01: `sunrise-15*60` → `start_time` 03:13.
  Sunrise that day: 03:28 UTC (NOAA formula) = 05:28 CEST (West Germany had summer time from
  6 April 1980).
- Caucasus v6, `Asia/Tbilisi`, 2022-06-29: dawn variants at 01:28.

### Check first

That DCS reads `mission.start_time` as the theatre's **local** time. One-glance check for David: open
Caucasus v6 `dawn-broken` (01:28) — middle of the night? If yes, every solar variant of every v6
mission is 2 to 4 hours early.

Then which local time: DCS theatres use a fixed offset, which may differ from the IANA zone with its
historical DST. The right conversion may be "UTC + the theatre's DCS offset" rather than
`tzinfo=position.timezone`.

### Checked (2026-09-24, David in DCS)

- **DCS reads `start_time` as theatre local time.** Caucasus v6 `dawn-broken` (`start_time` 5301 =
  01:28, 2022-06-29): pitch dark. The ticket is confirmed.
- **The offset is a fixed per-theatre value, not the IANA zone.** DCS's own table is in the
  encrypted `terrain.cfg.lua`, but the repo already carries one on the Lua side:
  `veafTime.getTimezone()` (`src/scripts/veaf/veafTime.lua`), Caucasus +4, PersianGulf +4, Syria +3,
  Sinai +2, Marianas +10, Nevada −8 ("DST not modeled in DCS"). Unsourced, but consistent with the
  Caucasus observation.
- **GermanyCW is +2.** A copy of the GermanyCW-v6 build set to 04:58 on 1980-06-01 at Ramstein
  (sunrise 03:28 UTC, NOAA formula): dawn glow, sun not up, so 02:58 UTC. +1 would have put the sun
  30 min above the horizon. Measured in June only: whether DCS keeps +2 in winter is not known.
- **Second defect found on the way:** the mission's theatre name is `GermanyCW`, and it is missing
  from both `veaf.theatreName` and `veafTime.getTimezone()`, so the runtime computes GermanyCW sun
  times with offset 0.

Fix direction: astral in UTC + the theatre's fixed offset, from a Python table that a test keeps in
step with the Lua one; add `GermanyCW` = +2 on both sides.

### Done when

- A test pins sunrise for a known place and date to the right local time
- GermanyCW-v6 `dawn-real` starts just before sunrise, checked in DCS

### Outcome (PR 1)

- `SolarCalculator` takes the theatre's fixed offset; `theatre_offsets.py` mirrors
  `veafTime.getTimezone()`, a test keeps the two equal; `GermanyCW` = +2 added on both sides (and to
  `veaf.theatreName`). A theatre not in the table falls back to `position.timezone`, with a warning.
- Bench: dawn variants at 05:13 (sunrise 05:28 local − 15 min), were 03:13.
- Checked in DCS by David on 2026-09-24 (`dawn-real`): ok.

## 03 — Real-weather fetch fails in the packaged exe

Status: ✅ done
Type: fix
Files: the PyInstaller spec / `veaf_build` exe build, possibly `dcs_weather_converter._fetch_live_metar`

### What happens

Every `airport_icao:` variant, in the 6.24.0 exe:

```
Échec de la récupération du METAR en direct pour ETAR : FileNotFoundError: [Errno 2]
No such file or directory: '...\Temp\_MEI000076702\avwx\data\files\stations.json'.
Utilisation des valeurs par défaut.
```

avwx's package data is not collected into the bundle. The build carries on with defaults and exits
0, so 11 of GermanyCW's 17 variants silently carry no real weather. The station is alive:
`tgftp.nws.noaa.gov/.../ETAR.TXT` answered on 2026-09-23.

Printed once only — later variants fail without a line — so the log understates it.

### Done when

- The exe fetches ETAR (collect avwx's data files: `--collect-data avwx` or the spec equivalent)
- A release smoke step runs one `airport_icao` fetch from the built exe
- A failed fetch is reported per variant, and the build summary says how many variants fell back

### Outcome (PR 1)

- `--collect-data avwx` in the exe build; the `exe-smoke` CI job checks `stations.json` is in the
  archive (network-free) — measured: 0 match on the 6.24.0 exe, 1 on the new one.
- The rebuilt exe fetched ETAR live (`BKN065 09/07 A3019` → Preset13, 1981 m, 9 °C, 766.8 mmHg).
- Each variant that falls back is named, and the weather step ends with a count.

## 04 — The presets step runs before the aircraft it should fill exist

Status: ✅ done
Type: fix
Files: `src/python/veaf-tools/veaf_tools/commands/build.py`, tests

### What happens

`build.py` runs presets (~l. 295) **before** `spawnable_aircrafts` and `dynamic_slot_templates`
(~l. 314). `FIX-WAYPOINTS-STEP-TOO-EARLY` moved the waypoints step for exactly this reason (comment
~l. 342) and left presets where it was.

### Measured

GermanyCW-v6: « Traitement de 7 groupes d'aéronefs — Préréglages injectés dans 0 aéronefs », then 64
templates injected from `dynamic-slot-templates.yaml`. In the built mission: 64 templates, **0** with
a `Radio` table. A pilot taking one of those dynamic slots has no presets.

### What it is not

Not every mission. Where the templates are placed in the **source** mission they exist when presets
run and get them: VEAF-Demo-Mission 2 of 2 templates with `Radio`, Caucasus v6 62 of 76. David's
recollection that "our v6 test missions have presets on dynamic slots" is right for those. The
defect is on the `prepare` path, where the templates come from YAML — the default for a new folder.

### Done when

- Presets run after both aircraft-injection steps, guarded by a source-order test bounded on both
  sides like the waypoints one
- GermanyCW-v6 rebuilt: 64 of 64 blue templates carry the plan's channels
- Kneeboards generated for the injected types too

### Outcome (PR 1)

- Presets run after both aircraft-injection steps, source-order test bounded on both sides.
- Bench: blue templates with a `Radio` table **0/64 → 44/64**. The 20 others are types no preset of
  GermanyCW's `presets.yaml` covers: the FC3 aircraft (no programmable presets, same on Caucasus),
  `Mi-8MT` (`none` by choice), and Ka-50, SA342, Yak-52, MiG-15, A-4E-C, Bronco, T-45 — on Caucasus
  these carry the editor's own tables, not injected ones. A presets-plan coverage question, not this
  ticket's order defect.

## 05 — No automatic BULLSEYE on a flight plan without waypoints

Status: ✅ done
Type: fix (or doc — decide in the plan)
Files: `src/python/veaf-tools/waypoints_injector/waypoints_injector_worker.py`, GUIDE, tests

### What happens

`if flight_plan and flight_plan.waypoints:` — a plan that is found but declares no waypoint falls
into the `else` branch: no BULLSEYE, and it is counted and logged as « sans plan de vol », which is
false.

A plan with `waypoints: {}` is the natural way to ask for "just the bullseye" — the shipped Caucasus
v6 has exactly that, and so did GermanyCW-v6 until the workaround. GUIDE #automatic-bullseye:
« chaque plan de vol reçoit en plus un waypoint BULLSEYE ».

### Measured

GermanyCW-v6 with two empty blue plans: 0 of 64 blue templates injected, « 128 groupes sans plan ».
With a declared BULLSEYE waypoint: 64 injected, 64 without a plan (the red templates, correctly).

### Options

a. inject the bullseye on an empty plan — reco: it is what the file and the GUIDE say
b. keep the rule, fix the log (« plan sans waypoint ») and the GUIDE

**Decided 2026-09-24 (David): option a.** A plan found with no waypoint still gets the BULLSEYE; the
log tells "no flight plan" apart from "plan without waypoints". Tests cover the three cases: no
plan, empty plan, plan with waypoints.

### Done when

- The chosen behaviour is tested, and the log count names the real reason

### Outcome (PR 1)

- Option a. Bench with `waypoints: {}` plans (the workaround removed): 64 BULLSEYE waypoints added.

## 06 — `create_qra` and `create_cap_mission` build aircraft with the ground-vehicle builder

Status: ✅ done
Type: fix
Files: `src/python/veaf-tools/veaf_mission_mcp/composites.py`, `add_air_group.py`, tests

### What happens

Both composites call `add_group.insert_group_into_content(..., category="plane")`. That builder is the
ground one: `task = "Ground Nothing"` (add_group.py ~188), `playerCanDrive` / `coldAtStart` (~224),
first point `action = "Off Road"` (~246). In a plane group it gives:

```
task=Ground Nothing   route[1]: alt=0, action=Off Road, speed=5.5555   units: no payload, no fuel
```

When the QRA scrambles or the CAP is activated, the aircraft appear at ground level, at 20 km/h,
empty. Same class as `FIX-MCP-AUTHORING-GAPS` ticket 04 (a valid file, aircraft that cannot fly),
one call away from where that lot fixed it.

Found on GermanyCW-v6 (`QRA_Stendal-MiG21/23`, `OnDemand-CAP-MiG23-Border-South`); worked around with
`remove_group` + `add_air_group` + `set_group_properties(late_activation)` + pylons.

### Same builder, two more categories

Found the next day on the same mission: `create_combat_zone(category="static")` and
`(category="ship")` — and `add_group` with those categories, same builder — write the ground-vehicle
shape too.

- **static**: a vehicle group under `country.static` (`task = "Ground Nothing"`, "Off Road" route,
  `playerCanDrive`, `skill`), and the units have **no `category`** (`Armor`, `Unarmed`, `Planes`,
  `Fortifications`…), no `dead`, no `canCargo`. A static's unit name should also be the group name
  (the combat-zone prefix rule reads the static's own name).
- **ship**: `task = "Ground Nothing"`, first point `action = "Off Road"`, `playerCanDrive`.

GermanyCW-v6 has 23 statics (combat-zone targets, including parked MiGs) and 2 ship groups that were
converted by a Lua patch. Statics are the only way to make a truly inert training target — a live
T-55 fires its AA machine gun at helicopters, and no zone tag sets ROE to weapon hold.

### What ships

- Both composites build through `add_air_group`'s builder (air start at the given position,
  altitude and speed parameters, full fuel), late activation set
- `add_air_group` gains `late_activation` (today it takes a second call)
- The composites accept a loadout, or a template to copy it from: an unarmed interceptor is the next
  silent failure. The `veafSpawn-*` groups of `spawnables.yaml` are a sourced place to take CLSIDs from
- A CAP needs a route: accept a second point / race-track, else the template orbits nowhere

### Done when

- A test per composite asserts a plane group with alt > 0, a Turning Point, fuel, and no ground keys

### Outcome (PR 2)

- `insert_air_group_into_content` (in `add_air_group.py`) is the composites' builder: air start,
  fuel from the units database, one aircraft type per group (a mixed flight is refused),
  `late_activation`, `pylons`, and a race-track orbit towards a second CAP point.
- Loadout: `pylons`, or `loadout_from` a group found in the mission, then the folder's
  `spawnables.yaml` / `dynamic-slot-templates.yaml`, then the shipped ones.
- Statics: the editor's shape, measured over 583 static groups of the missions under `test/`; the
  unit `category` from `dcsUnits.yaml`, mapped with the table measured over 401 missions under
  `D:\dev\_VEAF` (`Plane`→`Planes`, `Fortification`→`Fortifications`…). One object per static; an
  unknown type is written without a category and reported. Ships: the shape of 53 ship groups, no
  task, Turning Points, 127.5 MHz AM (102 of 117 ship units).

## 07 — Actions the agent had to replace with hand-written Lua

Status: ✅ done
Type: feat
Files: `src/python/veaf-tools/veaf_mission_mcp/` (new actions), the `actions.py` catalogue,
`doc/mission-maker/AI_ASSISTANT_CATALOG*.md`, tests

`FIX-MCP-AUTHORING-GAPS` put it plainly: an action that does not exist is an invitation to corrupt the
mission file. On GermanyCW-v6 the agent patched `src/mission/mission` through a Lua serializer for:

1. **Flight tasks and commands.** `edit_route` has a closed set (orbit, land, attack_group, bombing,
   engage_targets_in_zone, set_frequency, switch_waypoint). Missing for a support flight: `Tanker` and
   `AWACS` (enroute tasks), `ActivateBeacon` (TACAN channel / mode / callsign / bearing, needs the unit
   id), `EPLRS`, `SetUnlimitedFuel`, `Escort` (needs the escorted group id — why GermanyCW dropped its
   tanker escorts). Without them a "tanker" made by `add_air_group` does not refuel anyone.
2. **Mission date and start time.** The synthetic blank mission is dated 2016; a Cold War mission
   wants 1980.
3. **Bullseye per coalition.** `describe_map` reads them, nothing writes them.
4. **Briefing texts**: `sortie`, `descriptionText`, `descriptionBlueTask/RedTask/NeutralsTask`, the
   l10n dictionary handled (`FEAT-BRIEFING-METAR` found the prose lives there in editor-saved missions).
5. **`describe_units` on a folder.** Refused with `[Errno 13] Permission denied` on the directory,
   while every write action accepts a folder: the agent cannot read back what it just wrote.

### Done when

- Each action exists, validates its parameters (TACAN channel 1–126, X/Y…), is in the catalogue and
  the AI catalogue doc, and has a test
- GermanyCW-v6's tankers, AWACS, date, bullseye and briefing can be recreated with actions alone

### Outcome (PR 3)

1. `edit_route` tasks `tanker`, `awacs`, `set_unlimited_fuel`, `eplrs`, `activate_beacon`, `escort`,
   shapes read out of 401 missions under `D:\dev\_VEAF` (Tanker 855, AWACS 560, ActivateBeacon 874,
   EPLRS 12 772, SetUnlimitedFuel 1 390, Escort 599). TACAN frequency rule derived from every beacon:
   961 + channel MHz for X 1-63 / Y 64-126, 1087 + channel for X 64-126 / Y 1-63; system 3 on a ship,
   4 (X) / 5 (Y) airborne.
2. `set_mission_date` (date, start time on the theatre's clock).
3. `set_bullseye`.
4. `set_briefing`; `write_mission_folder` now writes `l10n/DEFAULT/dictionary` back (only when it
   changes), which a folder edit of dictionary-held prose needed.
5. `describe_units` reads through `open_mission`, so a folder works; a missing target is now a
   `ValueError` like every write action's.
- Bench: on a copy of GermanyCW-v6, a KC-135 tanker with TACAN 30Y and unlimited fuel, an E-3A AWACS,
  two F-15C escorting it with EPLRS, the 1980-06-01 09:30 date, the blue bullseye and a briefing, all
  through the actions; the build keeps them (`Tanker`, `ActivateBeacon` in the `.miz`).

## 08 — MCP side effects: backups in the source, needless rewrites, a false alarm, garbled output

Status: ✅ done
Type: fix
Files: `mission_tools/miz_backup.py`, `veaf_mission_mcp/mission_folder.py`, `airbase.py`,
`remove_group.py`, `build_tools.py`, tests

1. **Backups inside `src/mission/`.** `backup_before_write` drops `mission.<timestamp>` next to the
   file — 45 to 51 copies in one GermanyCW session — plus `mission.<ts>.yaml` at the folder root. They
   sit in the directory the build packs and the mission maker commits. Move them out of the source
   (a gitignored `.veaf-backups/`, or a temp area) and cap their number.
2. **`set_airbase_coalition` rewrites `mission`** and backs it up although it only changes
   `warehouses`; the only diff is LF → CRLF. It also **forces `dynamicSpawn = true`**, including on a
   red base the maker wants no slot on — GermanyCW had to reset 40 red bases by script. Make it a
   parameter.
3. **`remove_group` false alarm**: "Combat zone 'QRA_Stendal' captures groups by name prefix" for a
   trigger zone that is a QRA zone. Only the zones listed in `modules.COMBATZONE.combat_zones` capture.
4. **`build_mission` output** is returned truncated to its last lines and decoded as cp1252
   (« CrÃ©Ã© »). The warnings the maker needs (METAR failure, « 0 aéronefs ») were cut off; the agent
   had to rerun the build by hand to see them. Return the full log, or its warnings, as UTF-8.

### Done when

- Each point tested; a session of 50 actions leaves `src/` with only what the maker wrote

### Outcome (PR 2)

1. Backups of a file inside a mission folder go to `<folder>/.veaf-backups/` (a `.gitignore` of `*`
   inside), 20 kept per file; a `.miz` outside any folder keeps its sibling backup.
2. `write_mission_folder` rewrites a file only when its content changes, in LF, and backs up only
   what it rewrites — `set_airbase_coalition` no longer touches `mission`. `dynamic_spawn` parameter.
3. `remove_group` reports a capturing zone only when `modules.COMBATZONE.combat_zones` declares it
   (a `.miz`, with no `mission.yaml`, keeps the old rule).
4. `build_mission` returns `log`, the whole output, decoded as UTF-8. Measured: the exe writes UTF-8
   whatever the environment; the cp1252 decoding on the MCP side made the mojibake.

## 09 — Three small places where the tool says something false, or nothing

Status: ✅ done
Type: fix + doc
Files: `doc/PIPELINE_REFERENCE*.md`, the build's module summary, the build's sound check

1. **`clearsky` is undocumented.** `versions[].clearsky` is read
   (`weather_injector/models/configuration.py:26,60`), caps to FEW / < 15 kt / CAVOK, and is emitted
   by `convert-v5` — absent from the `versions[]` field table.
2. **« QRA (0) »** in the build's module summary, for a mission with one definition using
   `groups_by_enemy_count` (the generated `veaf-config.lua` is right). The count seems to read
   `simple_groups` only.
3. **A missing CSAR sound builds without a word.** `modules.CSAR.settings.radioSound:
   csar-beacon.ogg` (carried over from a v5 mission that shipped the file) while the file is not in
   the mission: the beacon is mute. The build already warns for a missing *required* sound; extend it
   to a sound named in the CSAR / CTLD settings.

### Done when

- Doc row added, summary count right, a test for the sound warning

### Outcome (PR 1)

1. `clearsky` row added to the `versions[]` table (FR/EN).
2. « QRA (0) »: the build normalises `mission.yaml` first, which moves `modules.QRA.definitions` into a
   separate `qra` section; the summary read the moved-from place. Its test fed the raw file. Fixed and
   tested on the normalised dict; bench now reads QRA (1).
3. Sounds named in the CTLD/CSAR settings join the required-sound check.

## 10 — Nested combat zones (difficulty levels) cannot be expressed cleanly

Status: ✅ done (#995)
Type: fix + feat
Files: `src/scripts/veaf/veafCombatZone.lua`, `veaf_libs/lua_config_generator.py`, `doc/mission-maker/scripts/veafCombatZone.md`, tests

### The need

A training range in progressive levels on the same targets — easy (inert), medium (light AAA),
hard (realistic SHORAD) — where activating a level also spawns everything of the levels below.
David asked for exactly that on GermanyCW-v6 (Baumholder, next to Ramstein, like Kobuleti on Caucasus).

### What stands in the way today

1. **Not expressible in `mission.yaml`.** The only mechanism is the Lua builder
   `VeafCombatZone:addZoneElementsFromZoneNamed(otherZone)`; GermanyCW-v6 calls it from
   `mission-script.lua`, after `veaf-config.lua` has created the zones.
2. **Nesting by overlapping name prefixes cannot work**, although the prefix rule suggests it
   (`zone_Hard`, `zone_Hard_Medium`, `zone_Hard_Medium_Easy`, a group named after the deepest one
   matching all three): at `initialize()` a zone **destroys** the groups it captured
   (`veafCombatZone.lua` ~l. 1404-1420), and `findUnitsInCombatZone` looks at **live** units, so the
   second zone to initialize finds nothing.
3. **A borrowed `#command` element stays bound to its zone of origin**: `buildCommandElement` bakes
   `", czName " .. combatZoneName` into the command (~l. 544). Borrowed by another level, its spawn
   still belongs to the original zone — not cleaned when the borrowing zone deactivates, not counted
   for its completion. GermanyCW-v6 had to use native groups only in its lower levels.

### What ships

- `combat_zones[].includes: [<zone_name>, ...]` in `mission.yaml`, generated as
  `addZoneElementsFromZoneNamed` after all zones exist (order-independent, transitive, cycle-checked)
- a borrowed `#command` element spawns for the **borrowing** zone (resolve `czName` at spawn time
  rather than at element construction)
- doc: the pattern, and why prefix nesting is not it

### Done when

- Tests: a level including another spawns both sets; its deactivation removes both; its completion
  counts both; a `#command` element in a lower level works
- GermanyCW-v6's `mission-script.lua` nesting replaced by `includes:`, the lower levels free to use
  `#command` again

### Outcome (PR 4)

1. **Point 3 was narrower than written.** What deactivation destroys and what completion counts are
   the zone's spawned groups, and since #66 a `#command` group is registered with the zone *running*
   the element (the spawn hook closes over `self`), so a borrowed command already belonged to the
   borrowing zone. The baked `czName` only named the group after its zone of origin — and only when
   `hide_names_from_spawned_groups: false`, since the default hides the zone name anyway. Kept as a
   test (`test_a_borrowed_command_group_belongs_to_the_borrowing_zone`, green before the fix);
   `czName` is now appended at spawn time with the running zone's name.
2. `addZoneElementsFromZoneNamed` skips elements the zone already holds, so borrowing a level that
   has itself borrowed the next one no longer adds them twice. That is what makes the generated
   closure order-independent.
3. `combat_zones[].includes` generated as one `GetZone(z):addZoneElementsFromZoneNamed(i)` per zone
   of the transitive closure, after the last zone is built. Unknown zone, operation, non-list,
   self-inclusion and cycles are build errors.
4. **Two active levels sharing an element: decided, each spawns its own copy**, owned by its zone
   (test `test_two_active_levels_sharing_an_element_each_spawn_their_own`). Levels are played one at
   a time; the doc says so. No exclusion and no reference counting — both would surprise more than
   they help.
5. Doc FR/EN: the `includes` key, the pattern, why prefix nesting is not it.

Left to the GermanyCW-v6 session (the mission is not ours to modify): replace the
`mission-script.lua` block with `includes:` on the medium and hard levels once a build with this
change is available.

## 11 — Teach the authoring skill what building one mission taught

Status: ✅ done (#996)
Type: doc
Files: `plugin/skills/veaf-mission-authoring/SKILL.md`

### Why

David, after the GermanyCW-v6 rebuild: "ajoute des instructions au MCP pour que la prochaine fois
qu'on te demande de construire une mission tu saches déjà tout ça". The skill is what an agent loads
before authoring; what it does not say, the next agent rediscovers the hard way — or does not.

### What was drafted

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

### To do

- Keep the skill consistent with what the lot actually ships: the `includes:` key (ticket 10), the new
  flight-task / date / bullseye / briefing actions (ticket 07) — name them in the skill once they exist
- Check the skill against `describe_naming_conventions` and the AI_ASSISTANT_CATALOG (no contradiction)
- Bump the plugin version with the release so installed plugins pick it up

### Done when

- David has reviewed the text; the skill names only actions and keys that exist in the release

### Outcome (PR 5)

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

## 12 — The `defense` levels and the SAM aliases do not say what they do

Status: ✅ done (#996)
Type: fix + doc (one design decision, see point 2)
Files: `src/scripts/veaf/veafShortcuts.lua`, `src/scripts/veaf/veafCasMission.lua`,
`src/python/veaf-tools/veaf_libs/data/veaf-units.yaml`, `veaf_mission_mcp` (`list_shortcuts`),
the shortcuts doc, tests

Reported by the GermanyCW-v6 session on 2026-09-24; checked against the code the same day.

### The need

David wants a training zone graded with `defense N` on its `#command` carriers. Three defects stop a
mission maker (or an agent) from doing that with confidence.

### What happens

1. **`list_shortcuts` hides the aliases' random parameters.** `-sam`, `-samSR`, `-samLR` and `-aaa`
   all show `_spawn samgroup, skynet true, spacing 1, radius 0`, while `veafShortcuts.lua` adds a
   different `addRandomParameter("defense", …)` to each: `-sam` 1–5 (l. 1243), `-samSR` 2–3
   (l. 766), `-samLR` 4–5 (l. 758), `-aaa` 1–2 (l. 1251). An agent choosing an alias from the oracle
   cannot tell them apart. The same holds for `-armor`, `-infantry`, `-transport`, `-combat`,
   `-convoy`.
2. **`-samLR` is described "Random long range SAM battery" and places short range.**
   `_spawn samgroup, defense 4-5` → `veafCasMission.generateAirDefenseGroup` (l. 719) →
   `generateAirDefenseGroup-<SIDE>-4/5` in `veaf-units.yaml`: blue level 4 is Roland, blue level 5
   Hawk (medium range); red is Dog Ear, Tor, Osa, Strela-10, Tunguska, ZSU-57-2, S-60. No long range
   anywhere (SA-10, SA-11, SA-5, Patriot). Same question for `-samSR` (2–3) and `-aaa` (1–2: red
   level 2 is SA-9 + Shilka, so not only AAA).
3. **The levels ignore the era.** `generateAirDefenseGroup` picks `generateAirDefenseGroup-<SIDE>-<N>`
   without reading `veaf.config.era`, while `generateTransportCompany` (l. 783) and the armor and
   infantry generators read `…_TYPES[side][veaf.config.era]`. In a COLD_WAR mission dated 1980, blue
   level 3 places an M6 Linebacker (in service 1997) and an Avenger (1989); red level 5, per the
   report, a Tor (1986) and a Tunguska (1982).

Also worth writing down for a mission maker grading with `defense N`: the level is rolled — 20 % one
level lower, 20 % one higher, 60 % as asked (l. 725–733), clamped to 0–5. The comment on l. 725 says
"30 % chance to get a +1"; the code gives 20 %.

### To decide

Point 2: correct the descriptions to what the aliases place, or give `-samLR` real long-range
batteries. Point 3: air-defense levels per era, like the transports.

### Done when

- `list_shortcuts` returns each alias's random parameters and their ranges; the shortcuts doc shows
  them
- Each SAM alias's description matches what it places, or places what it says
- An air-defense level picks era-appropriate units, tested per era
- The ±1 roll is documented, and the l. 725 comment matches the code

### Decisions (David, 2026-09-24)

- Point 2: `-samLR` was never long range — since its first commit (bb8a3545, 2020-03-11) it ran
  `defense 5`, and the defense scale is the CAS escort scale (level 5 = Hawk / Tor). David: keep
  `-samLR` as it is (description corrected to "medium range"), add a `-samVLR` for real long-range
  batteries — agreed with its per-era table and the existing Patriot template (2026-09-24).
- Point 3: era per level, COLD_WAR = types in service around 1980 (the armor tables' reference);
  SA-10 excluded from COLD_WAR.

### Outcome (PR 5)

1. `list_shortcuts` returns `randomParameters` (`{name: {min, max}}`) for each `#command` alias,
   parsed from `:addRandomParameter` by `veaf_shortcuts_scanner`.
2. Air-defense groups: `generateAirDefenseGroup` looks up `generateAirDefenseGroup-<SIDE>-<ERA>-<N>`
   first, then the generic level. 16 variants in `veaf-units.yaml`: COLD_WAR blue 1–3 and red 5,
   WW2 flak for every level of both sides. Swept per (side, era, level) in
   `test_air_defense_eras.py`.
3. Escorts (`_addDefenseForGroups`): `ESCORT_TYPES_REPLACED_BY_ERA[COLD_WAR]` swaps the post-1980
   types; swept over every level, both sides, vehicles and manpads. **Found on the way:** the escorts
   were skipped on `veaf.config.ww2`, which a v6 mission never sets (only v5 `missionConfig.lua`
   did), so WW2 sections got modern escorts; now also skipped on `era: WW2`.
4. The ±1 roll documented (veafCasMission doc, FR/EN), the "30 %" comment fixed in both places it
   appeared, and the false "Difficulty reference" table (level 5 = SA-6/SA-11, never placed)
   replaced by what the escort really places.
5. `-samVLR` → `_spawn longrangesam` → `veafCasMission.generateLongRangeAirDefenseGroup`, drawing
   from `LONG_RANGE_AIR_DEFENSE_GROUPS[side][era]`: MODERN SA-10 / SA-5 (red), Patriot (blue);
   COLD_WAR SA-2 / SA-5 (red), Hawk (blue); WW2 the heaviest flak level. The Patriot template has
   been in `veaf-units.yaml` since 2019 (faa1d19e) — a first grep missed it and a duplicate was
   briefly written, then removed; the 159 Patriot groups measured in the `.miz` under
   `D:\dev\_VEAF` confirm its core (STR, ECS, EPP, CP, AMG, 4+ launchers). The era swap also
   applies to the point defense these templates carry (the Hawk's Avenger).

## 13 — The MCP exposes the known limitations, always up to date

Status: ✅ done (#996)
Type: feat
Files: `src/python/veaf-tools/veaf_libs/data/known-limitations.yaml` (new), `veaf_mission_mcp`
(new action + `actions.py` catalogue), `doc/mission-maker/AI_ASSISTANT_CATALOG*.md`,
`plugin/skills/veaf-mission-authoring/SKILL.md`, `CLAUDE.md` (lot rule), tests

Asked by David on 2026-09-24, through the GermanyCW-v6 session.

### The need

The tools' traps must not live in prompts or skills, where they go stale. They belong **in the MCP,
always reachable, matching the installed version**. The "build an Open Training" mission prompt will
open with: "Read the known limitations (`describe_known_limitations`) and take them into account".

### What ships

- A read-only MCP action `describe_known_limitations` returning, for the running `veaf-tools`
  version, each known limitation: an id, the area (pipeline, MCP action, runtime), the observable
  symptom, the recommended workaround, and the version that fixed it when there is one. A fixed
  limitation is no longer returned.
- **One source**: a versioned data file in the repository (YAML, next to the other `veaf_libs/data/`
  files), read by the action, the doc and the skill — no list copied by hand into three places. It
  must ship in the executable (`_veaf_tools_extra_data`).
- A lot rule, in CLAUDE.md or the Definition of Done: a lot that finds a limitation without fixing it
  adds it to the file; a lot that fixes one marks it fixed.
- First content: whatever this lot leaves unfixed at delivery (ideally nothing), plus what is real and
  out of scope — e.g. no parking data outside Caucasus / Persian Gulf / Syria, so no runway or ramp
  start through the MCP there.
- The `veaf-mission-authoring` skill (ticket 11) points to the action instead of listing traps.

### Widened 2026-09-24: DCS behaviours too

`docs/agents/dcs-runtime-traps.md` holds the DCS behaviours that raise no error and are wrong anyway
(the mission clock on the theatre's fixed offset, a late-activated group answering `isExist()`,
`start_time` not delaying an air spawn, a SAM with no EWR permanently lit…). It lives in the
repository only: neither the exe nor the plugin ships it, so an agent working without a checkout
never sees it (checked 2026-09-24: the MCP code only cites it in two docstrings).

David agreed to put them in the same place:

- The data file carries **two kinds** of entry, told apart by a field: a limitation of the tools
  (fixed one day, then no longer returned) and a behaviour of DCS (never "fixed", always returned).
  DCS entries keep what the page records: the measured value, the date, what it broke.
- `describe_known_limitations` returns both.
- The entries of `dcs-runtime-traps.md` that matter to someone authoring a mission move into the
  file; the page becomes a pointer to it, or is generated from it — one source, not two.
- The lot rule covers both: a surprising DCS behaviour, measured, goes into the file.

Done when also: a test checks a DCS entry is returned whatever the version, and the page no longer
carries a copy of what the file says.

### Done when

- The action is in the catalogue and in AI_ASSISTANT_CATALOG (FR/EN)
- A test loads the file and checks every entry has its fields, and one that a fixed entry is not
  returned
- The skill cites the action

### Outcome (PR 5)

- Decision (David, 2026-09-24): the YAML is the only source; the MCP reads it from the exe, the
  `.md` is a generated view for readers of the repository, never shipped.
- `veaf_libs/data/known-limitations.yaml`: 9 `dcs` entries moved from the page (the ones that
  concern building a mission), 1 `tool` entry (no parking data outside Caucasus / Persian Gulf /
  Syria). The four script-development traps (Skynet activation, `net.load_mission`, scenery deaths,
  deferred `Group:destroy`) stay hand-written at the end of the page.
- `veaf_libs/known_limitations.py`: load, validate (fields, kind, dcs needs `measured` and cannot be
  `fixed_in`, unique ids), filter by version (an unreadable version hides nothing), render the page
  block; `python -m veaf_libs.known_limitations` regenerates it. A test fails when the page drifts or
  repeats an entry outside the generated block.
- MCP action `describe_known_limitations(kind?)`, bundled in the exe (`_veaf_tools_extra_data`),
  documented in AI_ASSISTANT_CATALOG and mission-editing-mcp (FR/EN).
- Lot rule: CLAUDE.md §9 item 8.

## 14 — A reusable prompt to build an Open Training mission on any map

Status: ✅ done (#998)
Type: doc
Files: `.prompts/new-open-training-mission.fr.md` and `.en.md` (new), `doc/mission-maker/AI_ASSISTANT_INSTALL*.md`

### Why

David, after the GermanyCW-v6 rebuild: a prompt that lets a new session — another PC, another Claude
user — build a VEAF Open Training on any map, saying how bases are chosen and how many combat zones,
QRA and CAP to make. Written and refined with him on 2026-09-24, then asked for in a `prompts` folder
of VMCT; `.prompts/` already holds the release-notes prompt, so it goes there rather than into a
second folder.

### What it is

The design rules, not an example to copy (David: the model would copy examples blindly): scaled on
the measured size of the front; blue and red bases, a few red ones with slots and blue QRA / CAP in
front of them; support, escorts, short + medium range on every slotted base plus a few long-range
batteries and EWRs behind the lines; three families of three nested training levels (helicopters,
attack, SEAD/DEAD) graded with `defense N`; at least six real zones more than training ones; QRA
covering some places, not all; security on by default with a `LOCAL_TEST` profile; French unless
told otherwise; a « Retours pour VMCT » block for every tool gap met.

It names only what this lot ships (`includes:`, `describe_known_limitations`, `set_mission_date`,
`set_bullseye`, `set_briefing`, the `edit_route` flight tasks, `dynamic_spawn`, `loadout_from`) and
lists no tool trap: those live in `describe_known_limitations`.

### Done when

- David has reviewed the text
- An English version, the same rules (the mission itself stays French by default)
- The mission-maker doc points to both (FR and EN)

## 15 — The build turns dynamic slots on at every airfield of a side, over `dynamic_spawn: false`

Status: ✅ done (#1000)
Type: fix
Files: `src/python/veaf-tools/warehouses_injector/warehouses_injector_worker.py`, tests,
`doc/PIPELINE_REFERENCE*.md` (the `warehouses.yaml` section)

### Origin

GermanyCW-v6 rebuild of 2026-09-24 (MODERN, 6.24.0 for the build, MCP on develop). The red bases
were set with `set_airbase_coalition(..., dynamic_spawn=false)` — an enemy base that should offer no
slot, which is what that parameter was added for.

### Measured

With the default `src/warehouses.yaml` (no `airports:` list, as `src/defaults/mission-folder/src/warehouses.yaml`
ships it), the built `.miz` has **61 airfields configured and 3 111 template links**; the 49 red bases
set with `dynamic_spawn=false` come out with dynamic slots. With an explicit `airports:` list per side
(the workaround the mission carries): **12 airfields and 612 links**. Figures measured by the
GermanyCW-v6 session on its `.miz`.

### Cause

- `_apply_to_warehouse` writes `warehouse["dynamicSpawn"] = True` unconditionally
  (`warehouses_injector_worker.py:382`).
- Without an `airports:` list, the targets are **every** airport of the coalition
  (`warehouses_injector_worker.py:513-517`, "absent -> ALL airports of this coalition" in the module
  docstring, l. 13), whatever `dynamicSpawn` the source mission carries.
- `set_airbase_coalition` writes `dynamicSpawn = dynamic_spawn` (`veaf_mission_mcp/airbase.py:99`), so
  the MCP action and the build contradict each other, and the build wins without a word.

### What it is not

Not a problem for a mission that lists its airports: the explicit list is honoured. The defect is the
default path, the one `prepare` lays down.

### Done when

- A base whose source warehouse says `dynamicSpawn = false` stays without slots when no `airports:`
  list names it; an explicit `airports:` entry still turns it on (decide and document which one wins
  when both say something)
- Test: a mission with one blue base `dynamicSpawn = false` and one `true`, default config — only the
  second gets links
- GermanyCW-v6 rebuilt without its `airports:` lists: the red bases set `dynamic_spawn=false` carry no
  link

### Outcome

Decided with David (2026-09-24, option a): the record lives in `warehouses.yaml`, not in the
warehouses table, because `dynamicSpawn = false` is the editor's default there, not a choice — 12
local missions carry blue or red bases at `false` that were never meant to stay closed.

1. `set_airbase_coalition(dynamic_spawn=false)` writes the base under `<side>.exclude_airports` in
   `src/warehouses.yaml` (comments preserved), `true` removes it from every side; nothing is written
   when the file is absent (the step does not run) or the side is not declared in it (declaring it
   would open every one of its bases). The result says whether it was recorded.
2. The build reads `exclude_airports` (names or ids): an excluded base never gets slots, listed or
   not, with a warning when it is both listed and excluded; an unknown entry is reported.
3. Doc: `PIPELINE_REFERENCE` schema (FR/EN), the default `warehouses.yaml`, the MCP doc.

Left to the GermanyCW-v6 rebuild (PRD Definition of Done): drop the `airports:` lists and measure
the red bases stay at their 0 links.

## 16 — Ships placed 20 m apart

Status: ✅ done (#1000)
Type: fix
Files: `src/python/veaf-tools/veaf_mission_mcp/add_group.py`, tests

### Origin

GermanyCW-v6 rebuild of 2026-09-24: a naval combat zone off Rostock (cargo ships, a tanker, frigates)
made with `create_combat_zone` in category `ship`.

### Measured

`combatZone_Rostock-navires`: 4 ships at x = -16437, -16417, -16397, -16377 — 20 m apart, in a line,
for hulls over 100 m long. They collide as they spawn. Fixed in the mission by hand, through a script
on the Lua table (600 m, staggered).

### Cause

`_build_units` offsets each unit by `len(built) * _UNIT_SPACING_METERS` on `x`
(`add_group.py:374`), with `_UNIT_SPACING_METERS = 20` (`add_group.py:22`). `_build_ship_group` uses
the same builder (`add_group.py:332`), so `add_group` and `create_combat_zone` (which goes through
`insert_group_into_content`, `composites.py:77`) both line ships up at vehicle spacing.

### What it is not

Not a vehicle problem: 20 m is a sensible spacing for a ground column. The fix belongs to the ship
path only.

### Done when

- Ships get a spacing that fits their size (per type if the data is at hand, a safe fixed value
  otherwise), through `add_group` and `create_combat_zone` alike
- Test: a four-ship group has no two units closer than the chosen spacing; vehicles keep 20 m

### Outcome

Ships are placed 600 m apart (`_SHIP_SPACING_METERS`), vehicles keep 20 m. Measured first: over the
89 multi-ship groups of the missions under `D:\dev\_VEAF`, the nearest-neighbour distance has a
median of 1 283 m and a 10th percentile of 277 m; 600 m clears a 300 m hull and is what fixed the
Rostock convoy by hand. Per-type sizes were not at hand (no hull length in `dcsUnits.yaml`).

## 17 — `create_cap_mission` makes a CAP with no engage task

Status: ✅ done — checked in DCS 2026-10-03
Type: fix
Files: `src/python/veaf-tools/veaf_mission_mcp/add_air_group.py`, `composites.py`, `edit_route.py`,
tests, `doc/mission-maker/AI_ASSISTANT_CATALOG*.md`

### Origin

GermanyCW-v6 rebuild of 2026-09-24: on-demand CAPs made with `create_cap_mission`, read back with
`describe_units`.

### Measured

Waypoint 1 of the template carries a single `Orbit` task — no `EngageTargets`. Choosing the CAP task
in the DCS Mission Editor adds "Engage Targets" on its own. To get it, the session had to run
`edit_route clear_tasks`, then `engage_targets_in_zone`, then `orbit`, to put the engagement **before**
the endless orbit.

### Cause

- `insert_air_group_into_content` with a `route` writes `{"tasks": {1: orbit}}` on the first point and
  nothing else (`add_air_group.py:281-284`); `create_cap_mission` passes `task="CAP"`
  (`composites.py:309`) but that only sets the group's main task. Without a `route`, there is no task
  at all ("without, it orbits nowhere", `composites.py:277-278`).
- `edit_route add_task` **appends** (`edit_route.py:423-427`, `number = len(tasks) + 1`): an
  engagement added after an orbit with no stop condition comes after a task that never ends.

### What it is not

Not verified in game yet: that a CAP without `EngageTargets` does not engage, and that a task placed
after an endless orbit is never read, are expected from the editor's own task order, not measured.
Measure both before and after the fix (see `docs/agents/dcs-runtime-traps.md`, and add the result
through `known-limitations.yaml`).

### Done when

- A CAP template from `create_cap_mission` carries an engage task placed before its orbit, like the
  editor's CAP task
- `edit_route add_task` can insert at a position (or document that it appends, and how to order tasks)
- Test: the built template's first point has the engage task numbered before the orbit
- Checked in DCS: the template engages an intruder in its zone

### Outcome

1. `create_cap_mission` writes the editor's own `EngageTargets` task (`key = "CAP"`, `targetTypes =
   {"Air"}`, `auto = true`) on the first point, numbered **before** the orbit. Shape measured on the
   3 691 CAP groups of the missions under `D:\dev\_VEAF`: 1 139 of their 1 147 `EngageTargets` are
   exactly this, always numbered 1. `create_qra` (task `Intercept`) is untouched.
2. `edit_route add_task` takes `task_position` (1-based) and renumbers the others; appends when
   omitted, as before.

**Waiting on David**: check in DCS that a CAP template built by `create_cap_mission` engages an
intruder in its zone. The editor's task order says it should; nothing has measured it.

### Checked in DCS (2026-10-03, session c)

A template made by the fixed `create_cap_mission` (`OnDemand-TEST-T17 CAP`, MiG-29S pair, tasks
`1:EngageTargets, 2:Orbit`) on GermanyCW, beside two copies differing only in their first waypoint's
task list. Each pair had its own immortal C-130 orbiting 12 km off, which its lead detected
(`getDetectedTargets`):

| Pair | Tasks | Missiles fired at its intruder |
|---|---|---|
| A, spawned by `veafCombatMission.ActivateMission` | `EngageTargets` then `Orbit` | 4 (first R-77 74 s after activation) |
| B | `Orbit` alone — the shape before the fix | 0 in four minutes, at 8.5 km |
| C | `Orbit` then `EngageTargets` — what an `add_task` append made | 0 in four minutes, at 8.5 km |

Both premises of this ticket are now measured rather than expected: a CAP without the task does not
engage, and a task after an endless orbit is never read — so `task_position` was needed too. Recorded
in `known-limitations.yaml` (`cap-engages-only-through-an-engage-task-before-its-orbit`).

Found on the way: an on-demand CAP is registered per variant, `<name>/<skill>/<size>`
(`TEST-T17 CAP/good/2`); `ActivateMission` with the bare name raises `attempt to index local
'mission'` instead of saying the name is unknown.

## 18 — `create_combat_zone` takes no route for its groups

Status: ✅ done (#1000)
Type: feat
Files: `src/python/veaf-tools/veaf_mission_mcp/composites.py`, `actions.py`, tests,
`doc/mission-maker/AI_ASSISTANT_CATALOG*.md`

### Origin

GermanyCW-v6 rebuild of 2026-09-24: a moving convoy in a combat zone (a native group with "On Road"
waypoints).

### Measured

The session had to create the zone with no group, then the convoy with `add_group` (which takes a
`route`) and `for_combat_zone`. Two calls and a naming convention to get right by hand, where one
composite call was meant to do it.

### Cause

`create_combat_zone` documents its groups as `[{"name", "units": [{"type","count"}], "position"?}]`
(`composites.py:50`) and calls `insert_group_into_content` with `name`, `position` and `units` only
(`composites.py:77-86`) — no `route`, no `patrol`, although `insert_group_into_content` accepts both
(`add_group.py:186-193`).

### Done when

- A group of `create_combat_zone` accepts `route` (and `patrol`) with the same shape as `add_group`
- Test: a zone with a routed group gets its waypoints; a group without keeps today's behaviour

### Outcome

`create_combat_zone` groups take `route` and `patrol`, with `add_group`'s shape, passed straight to
`insert_group_into_content`; a group without a route keeps today's single point.

## 19 — More actions the agent had to replace with scripts on the Lua table

Status: ✅ done (#1000)
Type: feat + fix
Files: `src/python/veaf-tools/veaf_mission_mcp/` (actions, `catalog.py`, `server.py`), tests,
`doc/mission-maker/AI_ASSISTANT_CATALOG*.md`

### Origin

GermanyCW-v6 rebuild of 2026-09-24. Ticket 07 closed the first list; building the mission again with
the MCP on develop found the next one. Same rule as `FIX-MCP-AUTHORING-GAPS`: an action that does not
exist is an invitation to patch the mission file by hand.

### Measured, and where it stands in develop

1. **A complete FARP** (helipad, frequency, warehouse entry). `add_group` in category `static` places
   the object alone. Worked around with `#veafInterpreter["-farp <name>"]`.
2. **The base mission's weather.** The blank mission has `clouds.preset = "Preset1"` with `base = 0`.
   No action writes `weather` (the action list in `actions.py` has none; `set_mission_setting` writes
   `mission.yaml` `settings.<key>`, not the mission table).
3. **Renaming or moving a single unit.** `set_unit_properties` takes skill, livery, heading, callsign,
   onboard number and pylons — no name, no position; `set_group_properties` moves and renames the
   group only ("Unit names are never renamed with the group").
4. **`build_mission` takes no profile.** Its schema is `folder_path` only (`actions.py`,
   `build_mission`), so `LOCAL_TEST` cannot be built through the MCP.
5. **No action lists a theatre's airfields** (names, ids, positions). The session read
   `veaf_build/dcs_data/airbase_dumps/GermanyCW.json` directly.
6. **`resolve_coordinates` takes one position per call** (`position` is a single object).
7. **A misnamed parameter fails with no message.** Reproduced on develop the same day:
   `run_action("describe_map", {"miz_path": ...})` → `Error executing tool run_action`, nothing else.
   `Catalog.run_action` forwards `params` to the handler as-is (`catalog.py:61-78`), never checks them
   against `parameters_schema`; the handler's `p["mission_path"]` raises a bare `KeyError`. The trap is
   made likelier by the names themselves: the path is `mission_path` (`describe_map`,
   `resolve_coordinates`), `miz_path` (`set_unit_properties`, `set_group_properties`), `folder_path`
   (`build_mission`, `set_airbase_coalition`) or `target` (`add_group`) depending on the action.

### Done when

- Points 1-6: each an action (or a parameter of an existing one), validated, in the catalogue and the
  AI catalogue doc, tested
- Point 7: `run_action` validates `params` against the action's schema and answers with the missing
  or unknown parameter's name; test with a misnamed parameter

### Outcome

1. `add_farp`: the heliport static in the editor's shape (`shape_name` per type, measured on 372
   heliports), its frequency and callsign, and the `warehouses.warehouses[<unitId>]` entry stocked
   like the editor's default. `warehouses.yaml`'s `farps:` then configures it at build.
2. `set_weather`: the base mission's weather through the converter the weather variants use, same
   vocabulary as `versions[].weather`, a METAR accepted; drops the `atmosphere` table of ticket 01.
3. `set_unit_properties` takes `new_name` (refused on a duplicate: DCS unit names are unique across
   the mission) and `position`; an aircraft gets a warning that its route places it.
4. `build_mission` takes `profile` → `--profile`.
5. `list_airfields`: name, id, lat/lon and x/y. The positions were only in `veaf_build`'s runtime
   dumps, not shipped: `update-dcs-data --airdromes` now writes `airdrome-positions.yaml` beside
   `airdromes.yaml`, bundled in the exe (810 airbases, 14 theatres).
6. `resolve_coordinates` takes `positions` (a list), one read of the mission.
7. **Wider than the ticket.** Since the move to `mcp` 2.x (1216ba58, 2026-08-10) the SDK hands the
   client only `Error executing tool run_action` for any exception but its own `ToolError` — so
   *every* refusal an action words for the agent arrived as that one line, not only a misnamed
   parameter. `run_action` now re-raises as `ToolError` with the type and message (tested through
   `mcp.call_tool`), and `Catalog.run_action` checks the parameters against the action's schema,
   naming the missing and the unknown ones with the expected ones. Every one of the 43 handlers reads
   only keys its schema declares (checked by reading their source), so refusing unknown keys is safe.

## 20 — `validate_mission` says there is no player slot in a mission made of dynamic slots

Status: ✅ done (#1000)
Type: fix
Files: `src/python/veaf-tools/veaf_libs/mission_validator.py`, tests

### Origin

GermanyCW-v6 rebuild of 2026-09-24: `validate_mission` on the folder.

### Measured

Two warnings: « Aucune place joueur dans la mission » and « presets.yaml est configuré mais la mission
n'a aucun aéronef joueur », on a mission whose build offers dynamic slots at 12 bases with 102 types
injected.

### Cause

Both checks count `Client` / `Player` units only, through `_aircraft_counts`:
`_check_has_player_slot` (`mission_validator.py:268-283`) and `_check_presets_waypoints`
(`mission_validator.py:491-501`). Neither looks at `warehouses.yaml` / the warehouses' `dynamicSpawn`,
nor at the dynamic-slot templates the build injects. The prepare path — the one the MCP recommends —
has no `Client` unit by construction, so the warning fires on every such mission.

### What it is not

Not wrong for a mission with neither static slots nor dynamic slots: that one still deserves the
warning.

### Done when

- A mission with at least one base offering dynamic slots (as the build will configure them) and a
  template or template file raises neither warning
- Tests: static slots only, dynamic slots only, neither — the warning only in the third case

### Outcome

`validate` counts a dynamic slot when the build will open one: a template to spawn from (the mission's
own `dynSpawnTemplate` groups, or the catalogue the build injects unless `dynamic_slot_templates` is
off) and a blue or red base whose warehouse says `dynamicSpawn = true`, or whose side `warehouses.yaml`
declares (the step then opens it). Measured on GermanyCW-v6: 2 warnings before, 0 after; the `no
player slot` message now says it looked for dynamic slots too.

## 21 — Two docs that do not describe the code

Status: ✅ done (#1000)
Type: doc (+ a naming decision, point 1)
Files: `doc/mission-maker/scripts/veafCombatMission*.md`, `.prompts/new-open-training-mission*.md`,
possibly `veaf_libs/mission_template.py`

### Origin

GermanyCW-v6 rebuild of 2026-09-24.

### Measured

1. **`cap_missions[]`: `default` and `activated` mean something else.** The doc says `default` =
   "Démarrer comme mission active par défaut" and `activated` = "Activer immédiatement au démarrage"
   (`veafCombatMission.md:103-104,130-131`, same in `.en.md`). The generator passes them as the 4th
   and 5th arguments of `addCapMission` (`lua_config_generator.py:759-761`), whose signature is
   `(missionName, missionDescription, missionBriefing, secured, radioMenuEnabled, …)`
   (`veafCombatMission.lua:1444-1452`): `default` is **`secured`**, `activated` is
   **`radioMenuEnabled`**. A maker setting `activated: false` to keep a CAP dormant removes its menu.
2. **The `standard` template does not turn on COMBATZONE and QRA.** They are in the tier
   (`mission_template.py:205-206`), but as `CONFIG` modules, which are emitted **commented** by design
   (`mission_template.py:11-13`). The Open Training prompt announces "`standard` — le cœur, plus zones
   de combat, QRA, …" (`.prompts/new-open-training-mission.fr.md:40`, same in `.en.md`). In practice
   `create_combat_zone` re-enables `modules.COMBATZONE` when it writes a zone
   (`composites.py`, `_append_combat_zone`), so the gap is the description, not a broken mission.

### What it is not

The third point reported — `veafCasMission.md`'s "Référence de difficulté" announcing SA-6 / SA-11 at
level 5 — is **already fixed** on develop by ticket 12 (#996): the table now shows what the escort
places, and a `MODERN` per-level table follows it. Not reopened.

### To decide

Point 1: correct the doc to what the keys do, or rename the keys (`secured`, `radio_menu`) with the
old names read as aliases — the names are what misleads.

### Done when

- `cap_missions[]` keys documented (FR/EN) as what they do, or renamed per the decision, with a test
  of the generated `addCapMission` arguments
- The prompt (FR/EN) says what `standard` really writes — or the template writes what the prompt says

### Outcome

Decided: the keys keep their names (a rename would break every `mission.yaml` that has them); the doc
says what they do. `default` = `secured` (Activate / Deactivate reserved to authorised pilots),
`activated` = `radioMenuEnabled` (the CAP shows in the F10 menu); neither starts the CAP, which is
created inactive (`veafCombatMission.lua:509`). `test_cap_missions_arguments.py` pins the generated
`addCapMission` arguments so the doc and the code cannot drift apart again. The Open Training prompt
(FR/EN) says `standard` writes COMBATZONE and QRA as commented examples that `create_combat_zone` /
`create_qra` turn on.

## 22 — `radio_menu: true` on a QRA hands Start / Stop to every player, unsecured

Status: ✅ done (#1000)
Type: fix + doc
Files: `src/python/veaf-tools/veaf_libs/lua_config_generator.py`,
`doc/mission-maker/scripts/veafQraManager*.md`, the AirWaves doc, tests

### Origin

GermanyCW-v6 rebuild of 2026-09-24: red QRAs with `radio_menu: true`.

### Measured

In the generated `veaf-config.lua`: `veafRadio.command("Arrêter QRA Berlin", ...)` with no security
level. On a public server a blue player can stop the red QRA they are about to fly over.

### Cause

`_emit_module_radio_menu` (`lua_config_generator.py:1399-1425`) builds a user menu whose commands are
emitted as plain `veafRadio.command(label, call)` (`lua_config_generator.py:1368`). The only knob is
`radio_menu_restrict_to_group` (l. 749), which hides the menu from everyone but one group — no
security level. AirWaves use the same path (`lua_config_generator.py:871-878`).

The doc presents the menu as "un contrôle F10 pour le Mission Master" (`veafQraManager.md:109`) and
does not say that without `radio_menu_restrict_to_group` every player gets it.

### Done when

- At minimum: the QRA and AirWaves docs (FR/EN) warn that the menu is open to all players unless
  restricted to a group
- Better: a secured option for the generated commands (decide whether it becomes the default), tested
  on the generated Lua

### Outcome

Decided with David (2026-09-24, option a): opt-in, nothing changes for existing missions.

1. Doc (QRA, AirWaves, FR/EN): the generated menu is open to every player unless restricted to a
   group, and any player taking that group's slot sees it.
2. `radio_menu_secured: true` on a QRA definition or an AirWaves zone emits the Start / Stop / Reset
   commands as `veafRadio.securedCommand`, a new node type of `createUserMenu` that goes through
   `veafRadio._proxyMethod` — the same check as the builder's `+` commands. A secured command needs
   the identity of a group (`_proxyMethod` refuses a click without one, REVIEW-SECURITY-LAYER), so it
   requires `radio_menu_restrict_to_group` and the build refuses otherwise. Mechanism 2 gets the same
   `secured: true` per command (`veafRadio` doc).
