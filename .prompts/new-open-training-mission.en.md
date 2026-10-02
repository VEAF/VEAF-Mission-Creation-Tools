# Prompt — build a VEAF Open Training mission on a DCS map

> Paste as is at the start of a new Claude Code session, in an **empty folder** that will be the
> mission folder.

---

You are going to build **from scratch** a **VEAF Open Training** mission for DCS World, with the
VEAF Mission Creation Tools v6 (`veaf-tools`) and the `veaf-mission-mcp` MCP server (Claude plugin
`veaf-mission-editor`).

An Open Training runs on the VEAF servers, open to all: airbases where anyone takes an aircraft
(dynamic slots), support (tankers, AWACS), graded training ranges, real combat zones spread over the
theatre, CAPs and QRAs, a credible air defense, and weather in several variants. The pilots do not
know the mission: everything they read must be right.

## 0. First of all

1. **Load the `veaf-mission-editor:veaf-mission-authoring` skill** and follow it: it is the source of
   truth for the VEAF conventions (reserved names, `#command`, `#veafInterpreter`, zones, QRA).
2. Call `capabilities` and `list_catalog`: note the `veaf-tools` version and the available actions.
   Read the **known limitations** (`describe_known_limitations`) and take them into account.
3. **Whatever is missing or does not work in the tools, you report it.** A missing action, a wrong
   result, a doc that says something other than the behaviour: work around it cleanly to move on, and
   write it down in a **"Feedback for VMCT"** block of your final report (what, where, how you saw it,
   what you did instead). That is how the tools get better.
4. Answer in English, concisely. Ask your questions **one at a time**, with choices and your
   recommendation.

## 1. The questions to ask (and only those)

One at a time:

1. **The map** (a theatre `scaffold_mission` supports).
2. **The era**: modern, Cold War (give a year) or WW2. It decides the equipment, the active airbases
   and the mission date. Suggest the one that fits the map.
3. **The starting template** of `scaffold_mission`. Present it like this:
   - `minimal` — the infrastructure and the core (radio menu, spawn, shortcuts, interpreter,
     security). For a very simple mission or a test bench.
   - `standard` — the core, plus CTLD and CSAR, tanker moves, weather, named points, CAS and
     transport missions; combat zones and QRA are there as **commented examples**, which
     `create_combat_zone` and `create_qra` turn on at their first call. **Recommended**: it is the
     base of an Open Training; add what is missing (assets, CAP missions, Skynet, AIEN).
   - `full` — everything, including Skynet, AIEN, assets, CAP missions, sanctuaries, air waves, TUM,
     with the advanced configuration as commented examples. Heavier to read.
   (Check these contents in the generated `mission.yaml`: they may have changed.)
4. **An existing mission to draw on?** If so, section 3.
5. **Escorts** for the tankers and the AWACS, only for those orbiting close to the front (see 4.4).

Everything else, you decide with the rules below, and you announce it.

## 2. Method

- **Nothing from memory.** Unit types → `list_unit_types`; aliases → `list_shortcuts`; places →
  `geocode` (show the point found); coordinates → `resolve_coordinates`. A number in a briefing is
  **computed**; a weapon envelope is written only if it is sourced.
- **Do not trust an alias's description**: check what it really spawns (composition, era of the
  equipment) before choosing it.
- **Work in the folder** (`src/mission/` + `mission.yaml`, the durable world), not in a `.miz`.
- **Read back what each action writes**, at least once per kind of action and category (aircraft,
  vehicle, static, ship): a valid file can produce units that do not work.
- If you must change `src/mission/mission` without a dedicated action: a script that loads the Lua
  table, changes it and writes it back — never a text replacement — and note it in "Feedback for
  VMCT".
- **Check, then claim**: "it's ready" is said only after section 8.
- **Stop before any commit / push** and ask for the go.

## 3. Drawing on an existing mission (if question 1.4 = yes)

We **draw on it, we do not copy it.** It was made with other tools, often by accretion; the new
mission follows the rules of this prompt.

- **Read it entirely**: groups **and unit names** (a group that looks inert often carries a
  `#veafInterpreter["…"]` that spawns a whole battery), zones, triggers, drawings, coalitions of all
  the airfields, slots, bullseye, date, briefing, configuration, presets, weather variants.
- Keep **its intentions**: which bases, which support, which defenses, which zones, what spirit. Take
  over what is intended and good; fix what is inconsistent (and prove it); leave out what serves
  nothing; **report what you do not understand** instead of deleting or copying it.
- **A converted mission (`convert-v5`) is not the source**: read the original v5 (the `backup_v5/`
  folder the conversion leaves behind, or the v5 repository), then compare it with the converted
  one. A conversion loses content without a word (whole scripted missions), and the converted folder
  may carry hand edits made since: report every difference, in either direction.
- **Inventory the reusable resources**: kneeboard (approach charts, frequency plan), sounds
  (beacons, messages), pictures. They show only in the files.
- Hand back a **kept / adapted / left out / unknown** table, with the reason for each line.

## 4. Design — rules and quantities

The quantities depend on the **size of the map and of the front**. Before placing anything, measure
and announce: the length of the front (nm), the depth of each side, the number of usable airfields on
each side. The orders of magnitude below are starting points; adjust them to these measures and say
why.

### 4.1 Front and airfields

- **Draw the front of the era**: which countries / regions are blue, red, neutral (historical reality
  or the map's usual scenario). One sentence before starting.
- **Blue bases with dynamic slots** (often 8 to 12). In this order:
  1. **real military bases of the era**; the main one becomes the "home base" (ICAO weather, rear
     tanker);
  2. spread **in depth**: a few forward bases, the rest in the rear;
  3. an **enclave** if history offers one.
- **Red bases**: every airfield on the red side is coloured red. **A few have dynamic slots** (number
  depending on the front, often 2 to 4, spread as for blue): players fly red, for player-versus-player
  air combat. No combat zone on the red side, but **blue QRAs and CAPs** (4.8, 4.9) to oppose them.
- **Neutral**: the rest. Never a neutral airfield with slots.
- **If red is playable, write the player-versus-player rule**: where it is allowed, where it is not,
  and say it in the briefing. Two tools, to offer the user:
  - a dedicated **arena**, away from the theatre: air-start slots for both sides, by missile type
    (Fox 1, Fox 3), with an AWACS for each side;
  - a **sanctuary zone** (`SANCTUARY` module, `sanctuary_zones`) protecting one side's rear: an
    intruder is warned then destroyed, and `protect_from_missiles` destroys the missiles fired at
    the defenders. The polygon is drawn by late-activation units (`polygon_units`), never activated.
- **FARPs**: a good practice to generalise — a blue FARP near the front and near every zone meant
  for helicopters (rearming, CTLD, CSAR). If the MCP cannot place one, report it. A FARP is complete
  with an **ammo dump** next to it (`FARP Ammo Dump Coating` static): CTLD takes it as a logistic
  point (`manage_logistics`, on by default), and troop pickup at FARPs is open
  (`troopPickupAtFARP` in `ctld-config.yaml`).
- `set_airbase_coalition` for every airfield, with `dynamic_spawn: false` on those that must offer no
  slots. `src/warehouses.yaml`: unlimited fuel and weapons, hot start allowed.
  `src/dynamic-slot-templates.yaml`: templates for the coalitions that have slots.

### 4.2 Identity and security

- **Name**: `VEAF_OpenTraining_<Map>_ICAO_<code>`, `<code>` = the home base's airfield **if it has a
  live METAR station** (check
  `https://tgftp.nws.noaa.gov/data/observations/metar/stations/<ICAO>.TXT`, today's day in
  `DDHHMMZ`); otherwise the nearest large airfield of the theatre that has one.
- `mission.era`, the **mission date** and the `base_date` of `versions.yaml` consistent with the era.
- **Language**: `mission.language: fr` and briefing in French — the VEAF servers' language — unless
  told otherwise.
- `silence_atc_on_all_airbases: true`.
- **Security on by default**: the mission runs on the VEAF servers. No `security.disabled: true` in
  the base configuration. Ask the user whether password hashes are needed, or whether the server's
  pilot levels are enough. **Never a password in clear**, not even in a comment next to its hash:
  the sources get published.
- **No required mod**: the mission's `requiredModules` table stays empty unless explicitly asked.
  A single mod in it locks out of the server every player who does not have it. It fills up
  silently when a mod unit is placed, or when an existing mission is taken over.
- **Two uses, two configurations** in `mission.yaml`:
  - **default** = server: security on, `info` logs, all the weather variants;
  - **`LOCAL_TEST` profile** (`veaf-tools mission build --profile LOCAL_TEST`): security off,
    `debug` logs, readable group names (`hide_names_from_spawned_groups: false`), no weather variants
    (`pipeline.weather: false`), and whatever makes a local test faster.
- **Mission date and time**: `set_mission_date`.
- **Bullseye** (`set_bullseye`): a **landmark the pilots can name**, at the centre of the front, the
  same for both sides.
- **Briefing** (`set_briefing`: title, situation, blue and red tasks): the context in two sentences,
  the bases, the support (frequencies, TACAN, altitudes), the zones by F10 menu, the QRAs, the useful
  VEAF commands.

### 4.3 Air support

- **Tankers: at least 2** (one boom, one basket), **more if the front is long**: one pair per sector
  of the front, each sector covering its combat zones. **Separate** tracks, **different altitudes**.
  `add_air_group` (air start), then `edit_route` `add_task`: race-track `orbit` at the point's
  altitude, `tanker`, `activate_beacon` (TACAN Y), `set_unlimited_fuel`.
- **AWACS: at least 1**, more if the front is longer than one covers while staying back (check the
  distance from its orbit to the farthest zones). Tasks `awacs`, `eplrs`, `set_unlimited_fuel`,
  `orbit`.
- **Red side**, if it has slots: at least one red tanker and one red AWACS, same rules.
- **One name everywhere**: group name = callsign (tanker families Texaco 1 / Arco 2 / Shell 3; AWACS
  Overlord 1 / Magic 2 / Wizard 3…) = preset label = `ASSETS` text. Same frequency everywhere. Declare
  them in `modules.ASSETS`.
- **Laser-designating drones** (option): a drone in orbit with the FAC task, declared in
  `modules.ASSETS` with its laser code and frequency (`jtac`, `freq`, `mod`), so the pilots find them
  in the menu. If the MCP cannot give the FAC task, report it.
- **Friendly carrier group** (option, if the map has sea and the players fly carrier aircraft):
  `add_carrier_group` places the carrier with its TACAN, ICLS and Link 4, the recovery tanker and the
  rescue helicopter the `CARRIER` module looks for, and the ship's warehouse; deck slots are
  `add_air_group` with `start: deck-cold` or `deck-hot` and `carrier` = the carrier unit it returned.
  Put TACAN, ICLS and Link 4 in the `ASSETS` text and switch the `CARRIER` module on.
  **Always two carriers, the Stennis and the Roosevelt** (one `add_carrier_group` each, with distinct
  TACAN, ICLS, Link 4 and frequencies): David's decision of 2026-10-02, for every generated mission
  that has a carrier group.

### 4.4 Escorts

- Orbit **far from the front** (out of reach of an enemy CAP or QRA): **escort** (a fighter flight
  with the `escort` task towards the escorted group).
- Orbit **close to the front**: **ask the user** (question 1.5). An escort protects the asset, but it
  also shoots down the targets players spawn next to it.

### 4.5 Air defense of the bases and the rear

- **Every base with slots** (blue and red): **short range and medium range**.
- **A few long-range batteries**, placed with judgement to cover the key areas without closing the
  whole sky (SA-10, SA-11, Patriot… **depending on the era and the side**; read in `list_shortcuts`
  which alias really places long range — an alias's name is not enough).
- **No permanent defense covers an enemy base that has slots.** "Permanent" counts the
  `#veafInterpreter` batteries **and** the combat zones activated at start (`active_at_start`).
  Measure the distance from every medium- and long-range battery to every enemy base with slots, and
  compare it with the weapon's range — sourced or measured in DCS; otherwise, give the distance as an
  open point. A pilot taking off under an SA-10 is not training.
- **Early-warning radars (EWR) behind the lines**, on both sides.
- Placed permanently through `#veafInterpreter["-<alias>, country <country>, hdg <heading>"]`.
  **Carrier = a unit of the class spawned** (the alias's launcher), so the editor shows the range
  ring. **Unique unit names**: a suffix after the tag (`… #<base>-01`).

### 4.6 Training ranges — 3 families of 3 levels

Each family = **3 zones nested on the same circle** (easy ⊂ medium ⊂ hard): names that do not
overlap (`combatZone_<Place>_Easy`, `…_Medium`, `…_Hard`), each zone holds **only its own additions**,
and each level includes the one below (the `includes:` key of `combat_zones[]`).

1. **Helicopters**: near a blue base, or near a **FARP** placed next to it. Easy = inert statics;
   medium = light AAA; hard = realistic short-range defense.
2. **Attack aircraft**: may be farther, as long as it stays **more than 75 nm from the front** and
   within reach of no real defense. Same progression, with more armor.
3. **SEAD / DEAD**: **far from everything** (bases, tanker tracks, other zones), so the crews train
   in peace. Easy = one medium-range battery alone; medium = medium + short range; hard = long,
   medium, short range and EWR, networked by Skynet.

**Grade the difficulty with `defense N`.** The group spawn commands (`_spawn samgroup`, `armorgroup`,
`combatgroup`, `transportgroup`, `convoy`…) accept `defense 0` to `5`, which picks an increasingly
strong standard air-defense group (AAA at 0, IR then radar short-range SAMs further up). So you can
write the same carrier at each level with an increasing value:
`#command="_spawn samgroup, defense 1"` / `… defense 3` / `… defense 5`. The levels follow
`mission.era`. Two precautions:
- the roll **adds randomness** (one level more or less now and then);
- **check each level's composition** for the mission's era (`list_shortcuts`) before relying on it;
  if it does not fit, use explicit aliases.

**Vary a site from one activation to the next** with the draw tags, on unit names: every element
carrying the same `#spawngroup="<name>"` forms a set, `#spawncount=` says how many of them are sure to
come up, `#spawnchance=` the chance of each. Example: four SA-15s placed,
`#spawngroup="SA15" #spawncount=2` → two of them, never the same ones. A returning pilot does not
find the site they learnt. Applies to the real zones too (4.7).

Statics are the only way to have a **truly inert** target (a live armoured vehicle fires its machine
gun at helicopters; no tag sets a unit to weapons hold). `training: true`, one radio menu per family.

**As an option, a non-combat helicopter zone**: navigation or search for a downed crew, with radio
beacons along the route (sounds played in a loop, FM frequencies given in the briefing) and a
distress signal on the site. `training: true`, `completable: false`. The sounds must exist in the
mission: `add_sound` embeds each one, then on each beacon unit's first point `edit_route` `add_task`
`set_frequency` (FM) followed by `transmit_message` (the sound, `loop`, a `subtitle`).

### 4.7 Real combat zones — at least 6 more than the training zones

With 9 training zones: **at least 15 real zones**, more if the front is long. Vary the kinds:

| Kind | Indicative number |
|---|---|
| Front — armor, artillery | 2-3 |
| SEAD — isolated radar or SAM sites | 2 |
| **Moving** convoys | 2-3 |
| Deep strike — headquarters, surface-to-surface missiles, depots, bridges, logistics | 3-4 |
| Enemy airbase (OCA) | 1-2 |
| Antiship (if the map has sea) | 1-2 |

Rules:
- **Real places, plausible for the era** (training grounds, bases, headquarters, road axes), looked
  up for this very map (`geocode`), spread along the whole front and in depth.
- **Era defense consistent with the target** (a large armored unit has its divisional defense, an
  airbase its base defense, a convoy its own AAA), through the aliases, carriers of the class spawned,
  unique unit names.
- **Targets**: statics for buildings, bunkers, aircraft on the ground; native groups for what lives;
  convoys = **one native group** with a road route (points 2+ "On Road"), its air defense in the same
  group.
- **Range of the active zones' SAMs**: none may reach a friendly base, a tanker track or a training
  zone. A zone activated at start is a permanent defense: the rule of 4.5 applies to it.
- Radio menus by kind, `training: false`.
- **Each zone's briefing**: what, where (**bullseye bearing/range computed** from the x/y: x is north,
  y is east, bearing = atan2(Δy, Δx)), what to destroy, what defense (no unsourced figure), which
  tanker is near and how far.

### 4.8 QRA — red, and blue if red is playable

- **Cover some places, not all**: a QRA everywhere makes the theatre unplayable. Protect the sensitive
  areas (a large base near the front, a strategic target), leave workable corridors, and say in the
  briefings which ones are covered.
- **Circle inside the defending side's territory** (it triggers on its distance, not on a border).
- **Graded response** (`groups_by_enemy_count`): few intruders → a light pair; more → more.
- **Several variants per level, drawn at random**: each level lists several groups (fighters of
  different threats) and `random_pick: 1` sends one of them. The pilots do not know what takes off.
- **Delay and helicopters, decided and written**: `delay_before_activating` (the reaction time
  between the first intruder's entry and the take-off) and `react_on_helicopters` (a QRA that reacts
  to helicopters closes the area to helicopter missions). Say both in the briefing.
- `create_qra`, era interceptors with a **loadout** (in each group: `pylons`, or `loadout_from` a
  `veafSpawn-*` group of the same type), `airport_link` on the base.
- If red has slots: **blue QRAs** on a few blue bases, same rules.

### 4.9 On-demand CAPs

- **Red: 2 to 4**, of different threats (IR fighter, medium Fox 1, high and fast interceptor, maybe a
  bomber to intercept), race-track **inside the red territory**, turns included.
- **Blue** if red has slots, same logic.
- `create_cap_mission` with a `route` (the second point gives the race-track) and a loadout (`pylons`
  or `loadout_from`), and a menu name that says type, sector, altitude.

### 4.10 Radio, weather, waypoints

- **`src/presets.yaml` to rewrite for the map** (the template is not made for it): UHF = Guard,
  bases, AWACS, flights, tankers; VHF = Guard + flights; FM 30-59; a red plan if red flies. **Base
  channels carry the frequencies DCS gives the airfield**, even with ATC silenced: they are what the
  pilot reads on the F10 view, and an invented series misleads them. Never type an airfield frequency:
  `describe_airfield_channels` lists the mission's bases with their DCS frequencies, propose them to
  the user (a radio holds about twenty channels), then `set_airfield_channels` writes the chosen ones
  into the `bases` collection; then place them in the `channel_lists`.
- **`src/versions.yaml` to rewrite**: position = home base, timezone, era `base_date`; variants night
  / dawn / morning / day / evening × real (`airport_icao`) / clear (`clearsky`) / scattered / rain.
- **`src/waypoints.yaml`**: remove the template's examples; one plan per category and per playable
  side, with the bullseye.

### 4.11 Modules

`COMBATZONE`, `QRA`, `COMBATMISSION` (CAP, scripted missions), `ASSETS`, `MOVE`, `CTLD`, `CSAR`,
`AIEN`, `STTS`, and **`SKYNET` with the spotter network** (`spotter_network: true`, F10 view off:
`spotter_view: "off"`, neither drawn nor offered on the radio menu). Depending on the options kept:
`SANCTUARY` (4.1), `CARRIER` (4.3). A sound named in the CSAR / CTLD settings must exist in the mission.

### 4.12 Scripted missions (option, 1 to 3)

Scenarios started from the radio menu, beyond the CAPs (`COMBATMISSION` module). Examples that
worked:
- **defend a base**: an attack wave (SEAD then bombers) towards a friendly base, failed if named
  buildings of the base are destroyed;
- **timed bomber wave**: a formation to shoot down within a set time;
- **intercept an escorted VIP transport** between two enemy bases;
- **protect a support aircraft** (ELINT, transport) along its route.

`combat_missions:` in `mission.yaml` carries only the elements and their groups: **no objectives**
(time limit, buildings to protect, loss rate), **no pilot skill**. A mission that needs them is
written in Lua (`VeafCombatMission`) in `src/scripts/mission-script.lua`, and you note it in
"Feedback for VMCT".

### 4.13 Briefing map and F10 drawings

A pilot discovering the mission must see the theatre at a glance, then be able to read the detail of
the area they fly to. **A theatre map and zoomed maps, two uses**: `docs/carte.jpg` at the top of the
README and the zooms in `docs/cartes/`, linked right below it; the same pictures in the mission's
briefing, the theatre map first.

- **Generated from the mission's data, never drawn by hand**: a script reads `src/mission/`,
  `mission.yaml` and the files of `src/`, converts x/y to lat/lon (`resolve_coordinates`, or
  `veaf_libs.coordinates`), and redraws it at every change.
- **What it shows**: the bases with slots (side colour), the FARPs, the tankers' and AWACS'
  race-tracks, the on-demand CAPs, the QRA circles at their real radius, the combat zones **numbered
  as in the briefing**, the training zones (one letter per family), the sanctuaries, the front line
  (said to be approximate), the carrier, the bullseye. What falls outside the frame (a distant arena)
  is shown by an arrow on the edge. Plus a legend, a scale in nautical miles and the mission's title.
- **The zooms**: fewer than ten, one per area of the theatre (a group of bases, a sector of the front,
  the approaches to a capital, the arena). DCS's briefing panel **fits every picture to its own
  size**: the theatre map becomes unreadable there, the zoom is what gets read. Every zoom has **a
  title** naming the area and what it holds ("Front nord : Lübtheen, Ludwigslust, Parchim"). It is
  declared by the **list of the objects to frame**: the frame follows, radii included (a whole QRA
  circle), with a margin, never typed coordinates. The tiles come from the OpenStreetMap zoom level
  nearest the output resolution, so place names stay legible. What it adds: the **name of every
  combat zone next to its number**, the extent of the rescue area, the arena's circle, the name of the
  lines crossing the frame (front, sanctuary), a round scale read at the centre. A zoom does not
  repeat the legend.
- **Basemap**: OpenStreetMap tiles will do, provided their usage policy is followed. A `User-Agent`
  identifying the tool by its URL, **never any personal data** (no e-mail). The tiles cached locally,
  so they are not downloaded again at every render. The "© OpenStreetMap contributors" credit on the
  picture.
- **DCS briefing pictures**: the same maps as JPEGs about 1600 px wide (count about 0.5 MB per picture
  in the `.miz`). They are copied into `src/mission/l10n/DEFAULT/`, declared in `mapResource`, and
  listed, theatre map first, in **`pictureFileNameB` and `pictureFileNameN` only; `pictureFileNameR`
  stays empty**. When DCS does not know the player's side (a `Client` slot, a dynamic slot, a
  spectator), it shows the red list then the blue one: a picture in both is shown twice
  (`describe_known_limitations`, `briefing-pictures-red-then-blue`). The price: a red pilot DCS does
  identify may get no map (in multiplayer, to be confirmed); pay it only if the red classic slots do not need one (the
  arena), and say so. The script that draws the maps **writes those lists and `mapResource`
  itself**, and removes the pictures it no longer draws: the mission always lists what was drawn. If
  the MCP has no action for it, note it in "Feedback for VMCT".
- **F10 drawings** (`add_map_drawing`, so they survive the build): the front line, the sanctuaries,
  the support race-tracks and the zone labels, each on the **layer of the side that must see it**
  (`Blue`, `Red`, or `Common` for what both share).
- **Look at every picture** before handing it over, zooms included: no label may overlap another,
  every zone number must match the briefing's, and a dashed line must stay dashed on small circles.

## 5. Build order

1. `scaffold_mission` in the empty folder.
2. Measure of the front and a figured plan (bases, support, zones, QRA, CAP), **presented to the
   user** before building.
3. `mission.yaml`: identity, security and profiles, modules.
4. Airfields and FARPs (4.1), support (4.3-4.4), air defense (4.5).
5. Training zones (4.6), real zones (4.7), QRA (4.8), CAP (4.9), scripted missions (4.12).
6. Radio, weather, waypoints (4.10); date, bullseye, briefing; briefing map and F10 drawings (4.13).
7. `validate_mission`, `build_mission` (and the `LOCAL_TEST` profile), then section 8.
8. `README.md` + `readme.fr.md`: content, building, files, known limitations.

A short progress note after each step: what is done, not what you are about to do.

## 6. What you hand back at the end

- A summary by heading (bases, support, defense, zones, QRA, CAP, weather).
- The kept / adapted / left out / unknown table if a mission was drawn on.
- **What you checked, and what you could not check** (everything that needs DCS).
- The **"Feedback for VMCT"** block.
- **Numbered open points**, with your recommendation for each.

## 7. What belongs to the user

Commit, push, publishing; deleting an "unknown" element of a mission drawn on; changing the era or
the sides; running DCS.

## 8. Checks before saying "it's ready"

- **Read the whole build log**, not just the exit code: presets injected into how many aircraft,
  waypoints into how many groups, warehouse links, number of variants, warnings. Any zero is suspect.
- **Open the built `.miz`** (a zip; `mission` and `warehouses` are Lua tables) and check:
  - **unique** group and unit names;
  - dynamic slots on the intended bases only;
  - the tankers' and AWACS' tasks;
  - the structure of aircraft (altitude > 0, fuel, loadout), statics (`category`), ships;
  - the convoys' routes;
  - zones, QRAs and CAPs in `veaf-config.lua`;
  - every name in `modules.ASSETS` (and its `linked` escort) names a group that exists: a name with
    no group gives an empty menu, with no error;
  - every `#veafInterpreter` carrier is of the type of the launcher its alias spawns (otherwise the
    editor shows the range ring of another weapon);
  - no permanent defense within reach of an enemy base with slots (4.5): the table of distances;
  - `requiredModules` empty (4.2);
  - two weather variants **different in the fields DCS reads** (`clouds.preset`,
    `season.temperature`, `wind.atGround`), and a dawn time consistent with sunrise;
  - the `LOCAL_TEST` profile built without security, the default configuration with it;
  - the briefing pictures present in the `.miz`, listed in `pictureFileNameB` and
    `pictureFileNameN`, `pictureFileNameR` empty (4.13).
- **Reread your briefings**: every range, bearing, altitude and place name recomputed or sourced.
- List what remains to check in DCS (statics placed on the airfields, convoys following their roads,
  zone nesting, the look of the sky).
