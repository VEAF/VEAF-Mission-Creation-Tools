# Prompt — build a VEAF objective mission, played in one session

> Paste as is at the start of a new Claude Code session, in an **empty folder** that will become the
> mission folder.

---

You are going to design, then build **from scratch**, a VEAF **objective mission** for DCS World,
with the VEAF Mission Creation Tools v6 (`veaf-tools`) and the `veaf-mission-mcp` MCP server (Claude
plugin `veaf-mission-editor`).

This is **not** an Open Training. An objective mission is played **once**, in **one session**, by a
group of pilots who take off together: a scenario, one or more objectives, a departure, a threat, a
way home. It is disposable: no weather variants, no on-demand zones, no theatre-wide infrastructure.
What matters is that the scenario holds together, that it fits in the session, and that **everything
the pilots read in the briefing is true**.

The work has **two phases**, and the line between them is strict:

1. **The scenario** (section 2): you propose, the user discusses, asks for as many other scenarios as
   they want, asks questions, asks for a pre-briefing. **No file is written.**
2. **The build** (sections 4 to 7): only after an **explicit approval** of one scenario. You build the
   mission and the briefing file.

## 0. Before anything

1. **Load the `veaf-mission-editor:veaf-mission-authoring` skill** and follow it: it is the source of
   truth for VEAF conventions (reserved names, `#command`, `#veafInterpreter`, zones, QRA).
2. Call `capabilities` and `list_catalog`: note the `veaf-tools` version and the available actions.
   Read the **known limitations** (`describe_known_limitations`) and take them into account from the
   scenario on: do not propose what the tools or DCS cannot do.
3. **What is missing or broken in the tools, you report.** A missing action, a wrong result, a doc
   that says something other than the behaviour: work around it cleanly to keep going, and record it
   in a **"Feedback for VMCT"** block of your final report (what, where, how you saw it, what you did
   instead). That is how the tools get better.
4. Answer in English, concisely, but write the mission and its briefing in French — the VEAF servers'
   language — unless told otherwise. Ask your questions **one at a time**, with options and your
   recommendation.
5. **Reading without a mission folder.** In phase 1 the folder is empty, and `geocode` as well as
   `resolve_coordinates` require a `mission_path` (they take no theatre). Point them, read-only, at an
   existing mission on the same theatre (an Open Training, for example); create nothing for it.

## 1. The opening questions (and only those)

One at a time. The user may answer "whatever" or "surprise me" to any of them: you then choose, and
say so.

1. **The map** (a theatre `scaffold_mission` supports).
2. **The aircraft flown and the number of pilots**: which types, how many of each, fixed-wing and/or
   helicopters. That decides the possible objectives, the departure bases and the distances. Ask also
   for **the slot mode**: named slots (one group per ATO flight, section 4.3) or **dynamic slots** on
   the departure bases (free placement). With dynamic slots, ask for the order of magnitude of the
   audience (types, number of pilots): it sizes the threat and the parking spots.
3. **The session length**: the flight time available, briefing excluded. Recommendation: 2 h; it is
   the budget the whole flight profile must fit in.
4. **The kind of mission**, if they have a preference: deep strike, close air support, SEAD / DEAD,
   anti-ship, escort, intercept, air assault / CSAR, or a mix. And the **era** if it does not follow
   from the aircraft.

Everything else — place, objectives, threat, time, weather, support — **you** propose, in the
scenario.

**The ATO names its flights with the VEAF standard callsigns.** Their frequency is in the tools'
catalogue (`presets_injector/freq_alias.py`, and the template's `presets.yaml`); their aircraft is
not. The known ones:

| Callsign | Aircraft |
|---|---|
| Archer | A-10C |
| Arctic | F/A-18C |
| Ninja | F-16C |
| Pinder | Mirage 2000 |
| Bengal | F-15 (E for a strike) |
| Blade | helicopters |

For another callsign of the catalogue (Astro, Nickel, Nitro, Gordon…), ask for the type: do not
guess it.

## 2. Phase 1 — propose a scenario

### 2.1 What a scenario must be

- **Plausible**: **real** places on the map (`geocode`, `list_airfields`, `describe_map` — show what
  you found), targets that make sense in that place and era, a period threat consistent with what it
  protects (`list_shortcuts`, `list_unit_types`; **read what an alias actually places**, not its
  description).
- **Playable in the session**: measure the distances (base → objective → home, refuelling included)
  and **compute** the flight time at the cruise speed of the slowest type in the package. The total,
  time on target included, fits in the length from question 1.3, with a margin. That speed is an
  **estimate**: say so.
- **Buildable with the tools**: everything the scenario promises must be buildable (section 4).
  Whatever depends on a setting you have not checked is "to be checked", not "planned".
- **Bases that can take the audience.** Count each departure base's parking spots in
  `veaf_libs/data/parking/<theatre>.json` (each spot's `t` field: from memory of the DCS
  `Airbase.getParking` API, 68 hardened shelter, 72 airplane, 104 open air, 40 helicopter, 16 runway —
  to be confirmed) and compare them with the number of pilots. A base too small refuses dynamic slots
  silently on the player's side ("Can't create dynamic group, no suitable parking was found" in the
  server log): measured on Syria, At Tanf has only **2 helipads** and H4 about 13 airplane spots.
  Plan a FARP (`add_farp`) for the helicopters or a second base for the jets.
- **A convoy on a real road.** Put its start and its points **on** the road, checked on the basemap: a
  convoy placed beside it first drives off to find the nearest road. Its travel time (length ÷
  speed) must fit in the session.
- **A site to defend, populated.** If what is at stake is a friendly site (a garrison, a town), put
  friendly units there: enough to make one want to defend it, **too few for it to hold alone** against
  the attacker (no tank against tanks, for example). And the attacker's route must **reach the
  contact**, not stop out of range.
- **Readable at a glance**: a pitch that tells in two sentences.

Read-only actions (`geocode`, `list_airfields`, `describe_map`, `list_shortcuts`, `list_unit_types`,
`resolve_coordinates`, `terrain_elevation`, `describe_known_limitations`) are allowed in phase 1.
**No action that writes**: no `scaffold_mission`, no file, no folder.

### 2.2 The scenario sheet

Each proposal carries a **number** (Scenario 1, 2, 3…) so the user can come back to it or combine two
("number 2, but with the departure from 1"). It fits **on one screen**, as formatted text, with no
picture:

```
### Scenario N — <title>

> <pitch: the context and what is at stake, in two sentences>

| | |
|---|---|
| Map, era | … |
| Date, time | … (day / night, and why) |
| Weather | … in one line |
| Departure | airbase or carrier, kind of start |
| Package | who flies what (from question 1.2) |
| Support | tankers, AWACS / GCI, or none |

**Objectives**
1. <primary objective> — <place>, <what to destroy / do>
2. … (secondary objectives flagged as such)

**Threat**: ground (broad families, no unsourced range figure); air (none, QRA, CAP).

**Profile**: <route in one line> — ≈ <distance> nm out, ≈ <duration> flight time in total (estimate
at <speed> kt).

**What makes it interesting**: <the difficulty, the tactical choice, what the group will have to do>

**To be checked**: <what depends on the tools or DCS and you could not confirm> (omitted if nothing)
```

End with one line: "Another scenario, details, the pre-briefing, or do we approve?"

### 2.3 Iterating

- **A new scenario is genuinely different** — another objective, another place or another profile —
  unless the user asks for a variant ("the same, shorter").
- **Questions** about a scenario get a direct answer, sourced when it is a fact (measured distance,
  checked unit type). An answer that changes the scenario makes it a new version: "Scenario 2b".
- There is **no limit** on the number of scenarios. Do not push towards approval.

### 2.4 The pre-briefing, on request

When the user asks for it, you write **in the conversation** (no file) the scenario's briefing,
following the VEAF template in section 3. Same headings, same order, in Markdown: headings, tables for
the ATO and the frequency plan, bullet lists. **No picture**: the "Tactical situation" heading becomes
a description of the geography, one element per line, with its bearing and range from the bullseye.

Target **coordinates** and **frequencies** in it are **provisional** (computed from `geocode`) and
marked as such: the real ones come from the built mission (section 6).

### 2.5 Approval

Phase 2 starts only on an **explicit approval** of an identified scenario: "I approve 3", "go for
2b". A question, a "not bad" or a requested pre-briefing are not approval. When approving, ask only
what is still missing:

- the **briefing format**: in practice, VEAF shares it as **Google Slides in a Google Drive**. The
  script generates a PPTX, which Drive converts to Slides on import; if a Google Drive connector is
  available, offer to upload it there, converted, into the folder the user names (that is publishing:
  ask for their agreement). A PDF on top if a frozen file is to be handed out;
- the **pilots' names** for the ATO, if they have them (otherwise the cells stay empty, as in the
  template).

## 3. The VEAF briefing template

This is the format of VEAF mission briefings (reference: *Deep Strike Palmyra*). One page per
heading, 16:9, white background, **bold title top left**, text aligned left — **never justified**: in
the template, a justified line spreads "Départ : USS Truman, Case 1, Beyrouth" across the whole width
and becomes unreadable.

1. **Cover** — the mission title, very large, on the left; on the right, the table of contents
   (General situation, ATO, Tactical situation, Flight plan), linked to the pages.
2. **General situation** — headings in bold, each followed by its text:
   - **Context**: the why, in two or three sentences, and the idea of the route;
   - **Mission**: three to five bullets in the infinitive (infiltrate, destroy, exfiltrate…);
   - **Bullseye**: where it is (a point the pilots can name, or a waypoint);
   - **Departure**: airbase or carrier, kind of start (Case I, cold start…);
   - **Threat**: the air-defence families (AAA, SA-8, SA-15…);
   - **Weather**: clouds, visibility, wind (direction and strength), turbulence, moon at night;
   - **Time**: the mission time.
3. **ATO** — under the heading **PACKAGE**, one box per flight: callsign (in blue), flight name,
   aircraft type; the base in italics below; four lines numbered 1 to 4 for the pilots; a loadout
   column ("Armement libre" or the imposed loadout). On the right, the **support assets** (callsign in
   burgundy, role, type: tankers, AWACS) and **control** (GCI / ATC).
4. **Tactical situation** — the overview map: departure, route, named points (START, INGRESS,
   EGRESS), objectives, known threats with their circle.
5. **Tactical situation WPn** — one page per objective, an ever tighter zoom on the target: the site,
   its buildings, its close defences.
6. **Mission flow** — **Primary objectives** (list), **Air opposition** (what is known, what may take
   off and when), **Air defences** (and how the route avoids them), **Other information** (suggested
   attack mode, refuelling on the way home, divert field).
7. **Flight plan** — one waypoint per line with its role: `W1 : Hold`, `W2 : Insertion TBA`, …,
   `W6 : IP`, `W7 (Bullseye) : Target …`, `W8 : Egress Point`.
8. **Frequency plan** — UHF then VHF: `<name> Ch. <n> : <frequency> MHz`, Guard first.
9. **Target coordinates** — the format stated first ("Lat Long seconds, precise"), then one line per
   target: `<name> : N34°33'37.31" E38°18'48.77" <altitude> ft`.

The briefing is written in French, like the mission: the headings above are the template's French
ones (*Situation générale*, *Déroulement mission*, *Plan de vol*, *Plan de fréquences*, *Coordonnées
cibles*…).

## 4. Phase 2 — designing the mission

Before building, give **the plan as a list** (folder, template, slots, objectives, threats, support,
route) and start without waiting for another approval. **If a point of the approved scenario cannot
be built as is, stop and say so** before departing from it: the user approved a scenario, not an
approximation of it.

### 4.1 Method

- **Nothing from memory.** Unit types → `list_unit_types`; aliases → `list_shortcuts`; places →
  `geocode`; coordinates → `resolve_coordinates`. A briefing figure is **computed**; a weapon envelope
  is written only if it is sourced.
- **Work in the folder** (`src/mission/` + `mission.yaml`), not in a `.miz`.
- **Re-read what each action writes**, at least once per action type and per category (aircraft,
  vehicle, static, ship): a valid file can produce units that do not work.
- If you must change `src/mission/mission` without a dedicated action: a script that loads the Lua
  table, changes it and writes it back — never a text replacement — and you note it in "Feedback for
  VMCT".
- **Stop before any commit / push** and ask for the go-ahead.

### 4.2 Identity

- **Template** for `scaffold_mission`: `minimal` for a mission with no helicopter or logistics;
  `standard` if the scenario uses CTLD, CSAR or transport missions. You choose and you say so. Turn
  off the template's modules the scenario does not use.
- **Name**: `VEAF_<Map>_<Title>` (title in PascalCase without accents, e.g.
  `VEAF_Syria_DeepStrikePalmyra`).
- `mission.era`, **date** and **time** (`set_mission_date`) consistent with the scenario. If the
  scenario says "full moon" or "moonless night", **pick the date from a sourced ephemeris**, not from
  memory.
- **Weather**: one, the scenario's (`set_weather`). No variants: `pipeline.weather: false` (and then
  remove `src/versions.yaml`, which the build reports as orphaned), or a `src/versions.yaml` with a
  single version. A visibility **≥ 9,000 m is written as 80 km** (the METAR "9999" rule): for haze,
  ask for 8,000 m at most.
- **Language**: `mission.language: fr` and a French briefing, unless told otherwise.
- `silence_atc_on_all_airbases: true`.
- **Security on by default** (the mission runs on the VEAF servers); ask whether password hashes are
  needed. **Never a clear-text password**, not even in a comment. A **`LOCAL_TEST` profile**: security
  off, `debug` logs, readable group names (`hide_names_from_spawned_groups: false`). Both profiles
  write **the same `.miz` name**: rename the first before building the second, or use a build script.
- **Game Master slot** if asked for: `groundControl.roles.instructor` in the mission table (no action
  sets it: a script that loads and writes back the table, to be noted in the VMCT feedback; whether it
  shows without Combined Arms is to be checked in game). A fixed **test slot** (an aircraft airborne
  near the objective) goes only into the `LOCAL_TEST` `.miz` — remove it from the built server `.miz`
  with `remove_group` — or nowhere.
- **No mod required**: `requiredModules` stays empty unless explicitly asked.
- **Bullseye** (`set_bullseye`): the scenario's, the same for both sides.

### 4.3 The player flights

- **One group per ATO flight**, named after its callsign (`ARCHER`, `NINJA`…), **as many slots as the
  ATO box has places** (four by default), skill `Client`, at the **scenario's departure**: cold start
  on a parking spot by default (`add_air_group` or `add_player_slot`, `ground-cold`), the carrier
  deck (`add_air_group`, `start: deck-cold` or `deck-hot`, `carrier` = the unit `add_carrier_group`
  returned), air start only if the scenario says so.
- **Named or dynamic slots, per the answer to question 1.2.**
  - *Named*: the ATO names flights, the mission provides them; `dynamic_spawn: false` on every
    airfield.
  - *Dynamic*: `set_airbase_coalition` opens the departure bases' slots (close the enemy bases' with
    `dynamic_spawn: false`), the ATO keeps the callsigns with empty pilot cells. The shipped catalogue
    offers **every** blue type, warbirds included: say so, and offer to restrict it
    (`content pull-aircraft-groups`) if the era matters. Check the bases' capacity (section 2.1).
- **Loadout**: the scenario's, or a basic loadout fitting the mission if the ATO says "Armement libre"
  (pilots change it on the ground).
- **Flight plan in the aircraft**: it **is** the briefing's flight plan, in the same order and under
  the same names. In DCS point 0 is the departure: the briefing's `W1` is the point with index 1.
  Check it in the `.miz`. With named slots, it is the group's route (`edit_route`) or
  `src/waypoints.yaml`; with dynamic slots, **only `src/waypoints.yaml`**: the build appends its
  points after the departure of every player template (one plan per category and coalition, one for
  the jets, one for the helicopters), then a BULLSEYE.
- **One point per objective**, the start of a convoy included (`COLONNE`), on the flight's way. When
  the plan changes, renumber everywhere: briefing, maps, F10 labels.
- **Waypoints are on the ground**: `BARO` altitude = DCS ground under the point, read by
  `terrain_elevation` (`points`), so that each steerpoint carries the terrain's coordinates. Declare
  the **BULLSEYE** in `waypoints.yaml`, on the ground too: otherwise the build injects one at 20,000 ft
  (a point declared under that name replaces its own). The flight altitude goes in the briefing, not
  in the points.
- **Low-level profile**, if the scenario has one: `terrain_elevation` with the `route` gives the
  highest ground of each leg; the briefing gives a leg altitude above that maximum. Terrain only — no
  buildings, pylons or trees: keep a margin, and say which. If the theatre has no grid
  (`available: false`), the altitude stays an open point to check in game.

### 4.4 The objectives

- **One objective = one combat zone** (`create_combat_zone`), with its `briefing`. The zone completes
  when its red units and statics are destroyed: that is what says an objective is achieved, and the
  zone announces it itself.
- **The primary objectives are grouped in an operation**: a `type: operation` entry of
  `combat_zones[]`, with one `tasking_orders` item per objective and **`active_at_start: true` on the
  operation only** (not on its zones: the operation activates them). When the last objective falls, it
  tells everyone "Operation … is over": that is the end-of-mission message, without a line of Lua. Its
  F10 menu lists the objectives left. `dependencies` orders the tasks ("the tower after the radar"):
  the next one is only given once the previous is done.
- **An objective that must only exist after another** (reinforcements arriving, a phase 2 revealed by
  phase 1): activating the operation spawns **all** its zones at once, dependencies change nothing
  there. That objective is a `chained_zones` of the zone that triggers it, with `chained_delay` — and it
  does not count towards the operation's end: say so in the briefing.
- **A target that is part of the map** (a bridge, a building of the scenery) is not a unit of the zone:
  it only counts when listed in `scenery_targets` by its DCS id. That id exists only inside DCS:
  `offer_scenery_lookup` gives the command the user runs to get it (it needs DCS), and until they have
  it the objective is an open point — or a static placed instead, if the scenario allows it.
- **Realism first**: on an objective mission, no smoke or on-demand unit list unless the scenario
  plans them (`smoke_and_flare: false`, `show_units_list: false`).
- **Targets**: statics for buildings, depots, tanks, aircraft on the ground (the only **truly inert**
  ones); native groups for what lives; a convoy = one native group with an on-road route (points 2+
  "On Road"), its air defence in the same group. **Unique, meaningful unit names.**
- **A static's unit name starts with the zone's name.** For a static, the zone reads the **unit's**
  name, not the group's: `Tanf-PC-CentreCommandement` (group) holding "Centre de commandement" (unit)
  is **ignored**, and the objective completes without it. The log says so at start-up
  (`reportGroupsExcludedByName`: "… ont été ignorés"). Name the unit `<Zone> Centre de commandement`;
  the briefing keeps the readable name.
- **A SAM-objective battery = one native group, radar + launchers.** Group aliases (`sa11`, `sa6`…)
  also place logistics trucks, which count towards the zone's completion. `add_group` and
  `create_combat_zone` line the units up every 20 m, heading 0: spread the launchers around the radar
  (`set_unit_properties`, position and heading). A zone's static groups join Skynet.
- **A convoy is created with its route** (`create_combat_zone` or `add_group` with `route`, points 2+
  "On Road"). `edit_route` adds a vehicle point as "Turning Point" and cannot write "On Road": to
  change the route, `remove_group` then recreate the group.

### 4.5 The threat

- **Ground defence**: permanent batteries through `#veafInterpreter["-<alias>, country <country>, hdg
  <heading>"]` — **carrier = a unit of the generated class** (the alias's launcher), so the editor
  shows the range circle; unique unit names (`… #<site>-01`). Or native groups placed where the
  scenario puts them.
- **The scenario's route must really exist.** If it "flies under the coverage" or "between two sites",
  measure the distance from each route segment to each battery and compare it with the weapon's range
  (sourced, or measured in DCS; otherwise the figure stays an open point). Terrain masking:
  `terrain_elevation` with the `route` (the waypoints' altitudes and `alt_type`) and the batteries as
  `observers` tells, leg by leg, how many metres each battery sees within its range. Put that table in
  the defences' briefing. It counts the relief only: a building or a forest that masks in DCS is not in
  it, and actual detection stays to be checked in game. The waypoints being on the ground, compute it
  on an **assumed** altitude profile, and say which.
- **Known ranges**, with their source — neither `dcsUnits.yaml` nor Skynet gives any:

  | System | Engagement | Detection | Source |
  |---|---|---|---|
  | SA-11 (Buk) | ≈ 25 nm | ≈ 45 nm (9S18 radar) | DCS, given by a VEAF mission maker |
  | SA-6 (Kub) | ≈ 24 km | — | measured in game, `describe_known_limitations` |
  | SA-8 (Osa) | ≈ 10 km | — | same |

  For another system, draw nothing without a source: ask, or measure in DCS. On the maps,
  **engagement and detection get two different circles**.
- **The PUSH and the EGRESS are out of every battery's engagement range**, with a margin (3 km at
  least), and the briefing says **where** the route enters each envelope ("5.4 nm before the IP"):
  that is where the strike flights wait for the SEAD.
- **Air opposition**: the scenario's. "They might launch fighters after the strike" = a **QRA**
  (`create_qra`) on the enemy base, circle in red territory, with `delay_before_activating` and
  `react_on_helicopters` decided and written in the briefing; period interceptors with a **loadout**
  (`pylons` or `loadout_from`), `airport_link` on the base. A patrol already airborne = a native group
  in orbit, not an on-demand CAP. `delay_before_activating` counts **from the start of the mission**,
  not from the intrusion: once online, the QRA takes off at the intrusion. Write it that way in the
  briefing ("online from H+15 min").
- **Early-warning radars (EWR)** if the scenario talks about being detected, and **Skynet** if the
  defence must react as a network.

### 4.6 Support, radio, map

- **Support**: only what the scenario cites. Tanker: `add_air_group` (air start), `edit_route`
  `add_task`: `orbit`, `tanker`, `activate_beacon` (TACAN Y), `set_unlimited_fuel`. AWACS: `awacs`,
  `eplrs`, `set_unlimited_fuel`, `orbit`. **One name everywhere**: group name = callsign (Texaco,
  Shell, Overlord…) = preset label = briefing line; declared in `modules.ASSETS`. Re-read the unit's
  DCS radio callsign: `add_air_group` takes it from the name for a tanker, but gave "Overlord" to an
  AWACS named Magic (`set_unit_properties`, family 2 = Magic).
- **Carrier** if the departure is at sea: `add_carrier_group` (TACAN, ICLS, Link 4, recovery tanker,
  rescue helicopter, warehouse), `CARRIER` module. **Always two carriers, the Stennis and the
  Roosevelt** (one `add_carrier_group` each, with distinct TACAN, ICLS, Link 4 and frequencies):
  David's decision of 2026-10-02, for every generated mission that has a carrier group.
- **`src/presets.yaml` = the briefing's frequency plan**, channel by channel: Guard, bases, carrier,
  AWACS, tankers, package frequency. **Base channels carry the frequencies DCS gives the airfield**:
  `describe_airfield_channels` then `set_airfield_channels`, never a hand-typed airfield frequency.
  Rewrite **all** the template's `channel_lists`: on another map, it keeps Caucasus airfields
  (Batumi, Beslan…). Re-read the presets actually injected in the `.miz`, aircraft by aircraft. The
  SA342 Gazelle gets none (only its FM radio takes presets): say in the briefing that its radios are
  set by hand.
- **`src/waypoints.yaml`**: remove the template's examples.
- **Briefing map**: generated from the mission's data by a script (x/y → lat/lon through
  `resolve_coordinates` or `veaf_libs.coordinates`), never hand-drawn. An overview map (departure,
  route and named points, objectives, known threats at their radius, support, bullseye, legend, scale
  in nautical miles) and **one zoom per objective**, framed by the list of objects to show.
  OpenStreetMap tiles with a `User-Agent` that identifies the tool by its URL (**never personal
  data**), tiles cached locally, "© OpenStreetMap contributors" on the image. **Show only what
  intelligence is supposed to know**: a surprise threat the scenario plans is not on the map.
  - **In a desert, the standard OSM basemap is nearly empty**: use OpenTopoMap
    (`tile.opentopomap.org`, hillshade and contour lines, attribution "© OpenStreetMap contributors,
    SRTM | style © OpenTopoMap (CC-BY-SA)").
  - **Frame the zooms wide** (3 to 10 km, so that a road or a relief serves as a landmark) with an
    **inset** detailing the units one by one; a zoom on 300 m has no basemap left.
  - **A very tall overview map is unreadable on a 16:9 page**: add a landscape map of the area of
    operations, and keep the overview as the big picture.
  - **Look at every rendered map**: no label may overlap another, point at the wrong spot, or leave
    the frame.
- **DCS briefing pictures**: the same maps as JPEG about 1600 px wide, copied into
  `src/mission/l10n/DEFAULT/`, declared in `mapResource`, listed overview first in `pictureFileNameB`
  and `pictureFileNameN`; `pictureFileNameR` empty (`describe_known_limitations`,
  `briefing-pictures-red-then-blue`). No action does it: a script that loads and writes back the
  tables (`mission_tools.miz_tools.read_mission_folder` / `write_mission_folder`, and
  `luadata.serialize` for `mapResource`), to be noted in the VMCT feedback.
- **F10 drawings** (`add_map_drawing`) on the `Blue` layer: the route and its named points, the known
  threats with their outline. Each label with an **opaque, light** `fill_color`, otherwise the default
  background (half-transparent black) makes it unreadable.
- **Mission briefing** (`set_briefing`): the same content as the briefing file, as text.

## 5. Build order

1. `scaffold_mission` in the empty folder.
2. `mission.yaml`: identity, security and `LOCAL_TEST` profile, modules.
3. Airfields (`set_airbase_coalition`), carrier, player flights (4.3).
4. Objectives (4.4), threat (4.5), and the site to defend if there is one (2.1).
5. Support, radio, waypoints (4.6); date, weather, bullseye.
6. Briefing map, pictures, F10 drawings, `set_briefing`.
7. `validate_mission`, `build_mission` (and the `LOCAL_TEST` profile), then section 8.
8. The briefing file (section 6).
9. `README.md`: the scenario, how to build, the files, the known limitations.

Brief status after each step: what is done, not what you are about to do.

## 6. The briefing file

- **PPTX (and PDF if asked)** in `docs/` (`docs/briefing.pptx`, `docs/briefing.pdf`), the section 3
  template, page for page; the PPTX is the source of the **Google Slides** version (Drive import).
  Keep fonts Slides knows (Calibri, Cambria, Arial), and look at the converted render if it is
  uploaded.
- **Generated by a script** that reads the built mission, like the map, so it can be regenerated after
  a change. For the PPTX, the presentation skill if available, otherwise `python-pptx`; for the PDF,
  the PPTX export or a direct generation, with the same pages.
- **Figures come from the mission, not from the scenario**: target coordinates read back from the
  placed objects (DMS to the hundredth of a second), frequency plan read back from `presets.yaml`,
  flight plan read back from the group's route or from `src/waypoints.yaml`, callsigns read back from
  the groups. A target's
  altitude is the ground's under the placed object, read by `terrain_elevation` (`points`), in feet;
  with no grid for the theatre, the column stays empty and it is an open point.
- **Re-read every rendered page** (convert it to an image and look at it): nothing overflows, no map
  label overlaps another, every waypoint number matches the route. Without LibreOffice, PowerPoint
  renders through COM (`Presentations.Open` then `Slide.Export` to PNG) — it is the readers' software
  anyway.

## 7. What you hand over at the end

- The scenario as built, in five lines, and **every departure from the approved scenario**.
- The paths of the `.miz`, the briefing and the maps.
- **What you checked, and what you could not check** (everything that needs DCS).
- The **"Feedback for VMCT"** block.
- **Numbered open points**, with your recommendation for each.

What belongs to the user: commit, push, publishing, launching DCS.

## 8. Checks before saying "it's ready"

- **Read the whole build log**, not just the exit code: presets injected into how many aircraft,
  waypoints injected into how many groups, warehouse links, warnings. All zeros is suspicious. Run
  the builds **with standard input closed** (`< /dev/null`, or `stdin=DEVNULL`): a build sat for ten
  minutes waiting for input, without printing anything.
- **Open the produced `.miz`** (a zip; `mission` and `warehouses` are Lua tables) and check:
  - **unique** group and unit names;
  - named slots: one group per ATO flight, the right number of `Client` slots, at the right
    departure, with a loadout, and no dynamic slot; dynamic slots: only on the planned bases, and no
    unexpected fixed slot;
  - each player flight's route = the briefing's flight plan (number of points, order, names);
  - every objective in `veaf-config.lua`, with its units, statics and `addSceneryTarget` calls; the
    operation grouping them, and its `ActivateZone` after `initialize()`;
  - every objective static's **unit** name starts with its zone's name (4.4);
  - the flight plan injected into the dynamic-slot templates, and the altitudes on the ground;
  - the tankers' and the AWACS's tasks;
  - every `modules.ASSETS` name designates a group that exists;
  - every `#veafInterpreter` carrier is of the type of the launcher its alias generates;
  - the route ↔ threats distance table (4.5);
  - `requiredModules` empty;
  - the `LOCAL_TEST` profile built without security, the default configuration with it;
  - the briefing pictures present, listed in `pictureFileNameB` and `pictureFileNameN`,
    `pictureFileNameR` empty.
- **Re-read the briefing, the file and the mission against each other**: every coordinate,
  frequency, callsign, bearing, range and time must be the same everywhere.
- List what remains to be checked in DCS: statics placement on the terrain, masking of the route by
  what the relief does not count (buildings, forests), the defences' reaction, the QRA trigger, each objective's completion (scenery targets
  included) and the operation's end message, and the F10 map drawings
  (they can **only be seen in game**).

## 9. After the upload to the server

The upload belongs to the user; what follows helps them know what actually runs.

- **Put a version number in the `.miz` name** (`…_v3.miz`). DCSServerBot knows a mission by its file
  name: a file uploaded again under the same name is renamed `-01`, and DCSSB keeps its own copies,
  changed by RealWeather and MizEdit, in `Missions/.dcssb/`. With a new name, the list shows which
  version runs.
- **A `.trk` track holds the mission as it was played**: it is a zip, like the `.miz`. Before chasing
  a bug reported in game, open the track and count the groups. The day "the garrison is not there",
  all three sessions had run on the previous upload.
- **A VEAF server's logs are read over SFTP**, with the servers declared in `~/veafmct.yaml`
  (`servers.<machine>.logs.<instance>`), read-only. The DCS log says which file it loads
  (`loading mission from`), DCSSB's what it changed. Look there too for zones ignoring groups
  (`reportGroupsExcludedByName`) and slots refused for lack of space (`no suitable parking`).
