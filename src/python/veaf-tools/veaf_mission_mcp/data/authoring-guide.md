# Authoring VEAF missions through `veaf-mission-mcp`

You edit a Mission Maker's DCS mission through the `veaf-mission-mcp` server. This guide is the
**reasoning** half; the server provides the **actions**. The user gives *intent* ("a combat zone
with two armor groups"); **you** derive the concrete unit types, group names and config — do not
ask the user for mechanical details you can decide correctly yourself.

## A user who asks for a new mission {#new-mission}
<!-- when: always: the user asks for a new mission, whatever its size. -->

"Create a mission" is enough: the user does not have to name a prompt. Every new mission, however small, starts
with this question — which kind do they want? — then load its prompt with `describe_mission_prompt` and follow it
from its first section:

- `objective` — a mission a group plays once, in one session: a package, one or more objectives, a threat,
  a way home, and its briefing;
- `open-training` — a VEAF training mission on a whole map: airfields, support, air defence, graded
  training zones, combat zones, QRA;
- `persistent-campaign` — one mission that runs on a server for weeks: zones that change hands, a front
  that moves on its own, enemy air, credits, a save (`campaign.yaml`, `mode: persistent`).

Pass `lang: fr` to a user who writes in French. The mission takes the user's language too —
`mission.language`, its briefing, its maps and its README — unless they ask for another. **Whatever a human reads
keeps its language's accents, also inside a tool call** (a briefing, a zone's title and briefing, a note); only
identifiers — the mission name, trigger-zone and group names, callsigns — are ASCII. Measured twice, on two free
models' runs: accented French in the reasoning, then unaccented in the JavaScript passed to `execute`. An objective mission's briefing — the PPTX, its maps and
the DCS briefing pictures — is one action, `build_mission_briefing`, once the mission is built. A few steps
are still scripts (the Open Training's `README.md`, a look at the PPTX's pages): without a shell, read `describe_known_limitations`
entry `mission-prompt-scripts-need-a-shell` and say what you could not produce. A user who wants no more than what they described (a test mission with one SAM zone) gets no prompt, but still
the section `after-scaffold`. Only a change to an existing mission skips both.

## Right after `scaffold_mission` — every new mission {#after-scaffold}
<!-- when: always, right after scaffold_mission, before placing anything. -->

The scaffold is a generic skeleton, not a mission for this request. Left as it is, it ships a channel plan, a
date, example waypoints and aircraft that have nothing to do with what the user asked: a test mission built on
6.30.0 (2026-10-19) kept every one of them until the user asked about each in turn. Before placing anything:
call **`adapt_scaffold`** once, with what the request says. Do not read or rewrite these files yourself: `src/presets.yaml` alone is 48 000 characters, more than a small model's context can spare.

1. `src/presets.yaml` — a channel plan for modern two-radio aircraft, every theatre's airfields listed. Pass `airfields`, the ones the mission uses (channel 1 first): they go on the second radio, and the other theatres' lists go. Flight, tanker and AWACS channels stay. The build drops, per aircraft, the channels its radios cannot tune and lists them in `presets-validation-report.md`: an `ℹ️` entry (a warbird losing the UHF channels, an L-39 the ones above 390 MHz) needs no action — the channels in range are kept. Never set a type to `none` to quiet the report: `none` removes all its presets, the working ones too. Pick a flight's channel **inside the band of its aircraft's preset radio**: the UH-1H's only preset radio is its UHF (225–399.975 MHz), so a VHF channel such as 123.5 MHz is dropped for it, with the ranges that are valid in the message — give a Huey flight a UHF channel (two runs ended on 250.700), and say so in the briefing.
2. `src/versions.yaml` and the blank mission — pass `date` (consistent with `era`), `start_time` and `position` (where the mission flies, `{x, y}`): the variant is named after the time unless you pass `variant`.
3. `src/waypoints.yaml` — example points that point at nothing. Pass `waypoints`, the mission's route; without them every player flight gets the BULLSEYE only.
4. `src/dynamic-slot-templates.yaml` — the shipped catalogue covers both coalitions and every era. Pass `dynamic_slot_coalitions`, the coalitions that get dynamic slots; the other eras' aircraft stay, a warbird included: a player who wants one in a modern mission may take it (David, 2026-10-20).
5. `mission.yaml` — pass `mission_name` and `era`; and `skynet: true` for a mission with a SAM or an EWR zone: without it there is no integrated air defence at all, the EWR feeds no battery, and each SAM is left to the plain DCS AI (`describe_module SKYNET`; then `describe_known_limitations`, area `air-defence`).

For a change `adapt_scaffold` does not cover, `read_mission_file` and `edit_mission_file` reach these files.

Tell the user the lines `adapt_scaffold` returned.

## A simple mission, call by call {#recipe}
<!-- when: always: the calls that take an empty folder to a built mission, each with its parameters, so you need no describe_action for them. -->

These calls build a simple mission; their parameters are here, so call them directly, without `describe_action`.
Replace the example values with the user's; read a section of the index only when the request needs more than this (a QRA, a FARP, support aircraft, a briefing).

1. `scaffold_mission` `{"target_folder": "<empty folder>", "template": "standard", "theatre": "Caucasus"}`.
2. A place by its name: `geocode` `{"theatre": "Caucasus", "query": "Beslan"}` gives its `x` and `y`.
3. `adapt_scaffold` `{"mission_path": "<folder>", "mission_name": "Beslan-Strike", "era": "MODERN", "language": "fr", "date": "2024-06-10", "start_time": "08:00", "position": {"x": -158841, "y": 842000}, "airfields": ["Beslan", "Mozdok"], "dynamic_slot_coalitions": ["blue"], "skynet": false}` — `skynet: true` when the mission has a SAM or an EWR zone; `language` is the user's.
4. Player slots: `set_airbase_coalition` `{"mission_path": "<folder>", "name": "Mozdok", "coalition": "blue"}` for each airfield the players take off from — an airfield of no side offers no dynamic slot.
5. `create_combat_zone` `{"mission_path": "<folder>", "zone_name": "CZ-Beslan", "position": {"x": -158841, "y": 842000}, "radius": 6000, "coalition": "red", "country_id": 0, "country_name": "Russia", "groups": [{"name": "armor-1", "command": "-armor", "units": [{"type": "T-72B"}]}, {"name": "sam-1", "command": "-sa8", "units": [{"type": "T-72B"}]}]}` — each group is a VEAF alias (`command`) with one carrier unit; `list_shortcuts` `{"name_contains": "sa"}` lists the aliases.
6. `validate_mission` `{"mission_path": "<folder>"}`: fix every error it reports.
7. `build_mission` `{"mission_path": "<folder>"}`, then `inspect_built_mission` `{"mission_path": "<folder>"}`: read the counters and question any zero.

Then tell the user in a few lines what you built: the `.miz`, the zone and its groups, and what you could not check.

## Always ground yourself in the oracle — never from memory {#oracle}
<!-- when: before your first placement: which read-only actions give the VEAF and DCS facts (units, aliases, modules, limitations). -->

**Before anything else, call `describe_known_limitations`.** It returns, for the installed
veaf-tools version, what the tools cannot do yet (with how to do without) and the DCS behaviours
that raise no error and are wrong anyway — a late-activated group visible to scripts, `start_time`
not delaying an air spawn, a SAM without early-warning radar permanently lit… Take them into account
throughout; this guide deliberately does not repeat them, since a trap copied here would go stale.
With no argument it returns a **short listing** (the ids, grouped by area; each id reads as a phrase): the whole text is too
long for one result. `area` (`spawning`, `air-defence`, `players`, `radio`, `ground-ai`, `scripting`, `mcp`, `pipeline`, `runtime`), `kind` and `theatre` narrow that listing and keep it short.
Read in full, with `id` or `ids`, only the entries your mission actually meets: everything you read stays in your context to the end of the session and is sent again with every turn.

Before naming a group, picking a unit type, or configuring a module, call the read-only oracle
actions. They read VEAF's canonical, always-current data — your training memory of DCS types or
VEAF conventions may be stale or wrong.

- `list_unit_types` — real DCS unit type ids (filter by category / name), with the weapon and sensor
  ranges DCS gives them (`threat_range_m`, `detection_range_m`).
- `list_payloads` — the loadouts DCS offers an AI aircraft type, by name: what `payload` takes in
  `add_air_group`, `create_qra` and `create_cap_mission`. The module aircraft (P-51D, Fw 190, F-16C…)
  and the WW2 bombers (Ju-88A4, B-17G) are in; a type with none (a transport, the Spitfire) takes
  `pylons` or `loadout_from`. A WW2 fighter needs neither: it fights with its guns.
- `list_shortcuts` — VEAF spawn aliases. Three families: `units` (`shilka`, `sa8`), `groups`
  (composite SAM/convoy groups), and `commands` — the `#command` shortcuts (`-samVLR`, `-samLR`,
  `-armor`, random convoys, …), each with its `randomParameters`: the range of every parameter it
  draws on each use (`-samLR` and `-samSR` run the same command and differ only by their `defense`
  range). **This is the authoritative source for the `-<alias>` you put in a combat-zone
  `#command`** — never guess an alias from memory (there is no `-lrsam`). Each entry carries an `era`:
  `follows_era` (`-aaa`, `-samLR`, `-armor`, `-infantry`, `-transport`, `-convoy`: the units change
  with `mission.era`), `ww2`, `post_ww2` (fixed modern equipment — `-ewr`, `-arty`, `-sa6` — wrong in
  a WW2 mission), `era_free` or `unknown`; pass `era` (`WW2`…) to list only what fits the mission.
- `describe_naming_conventions` — the reserved naming patterns (section `naming`).
- `describe_module` — is a module real? its doc page? enabled in this mission?

For an action's exact parameters, call `describe_action(name)` **just before you use it**, one action at a time — not every action you might need up front: ten described in one batch are ten schemas carried to the end of the session.

**These oracle actions plus this guide are the authoritative source for VEAF-framework facts** —
naming conventions, spawn aliases, marker/`#command`/`#veafInterpreter` formats, module config.
**For those specifically**, don't consult other tools/agents or read the VEAF framework's Lua
source (a mission maker's machine has neither): if a fact seems missing, re-query the oracle
(`describe_naming_conventions`, `describe_action`, `list_shortcuts`) or state the gap plainly rather
than sourcing it elsewhere or guessing. This scoping is **only** about VEAF-framework knowledge —
keep using your other tools normally for everything else (geocoding, reading/writing files,
building, etc.).

**Every read of a mission goes through an action — never through a shell.**
Never unzip, grep or parse a `.miz`, a mission file or the tools' own data files in a shell or a script of your own: `describe_mission`, `describe_map`, `read_mission_file` and `inspect_built_mission` read them, and the reference data has its own actions (`list_airfields`, `list_countries`, `list_unit_types`…).
When no action answers a question, tell the user what you could not check instead of improvising a parser: a guess built from raw tables reads as a fact and is often wrong.

## The two editing worlds {#two-worlds}
<!-- when: always: the recipe (mission.yaml, src/) and the built .miz. -->

- **Recipe** — the source `mission.yaml`. Durable: survives a rebuild. Prefer it for configuration.
- **Built mission** — the `.miz`. Direct, no rebuild, but overwritten on the next build from the recipe.

Every write is backed up first. State which world you are editing when you report back.

## Reserved naming conventions (the traps) {#naming}
<!-- when: before naming a group, a unit or a zone yourself. -->

Prefer to express intent and let `add_group` name the group for you (`for_combat_zone`,
`late_activation`, `as_spawn_template`) — it applies these rules and returns `warnings`. To check a
name yourself, call `validate_group_name` (or `describe_naming_conventions` for the full list).
The dangerous ones:

- **Combat-zone membership** — a group whose name *starts with a combat-zone trigger-zone name*
  and sits inside that zone is captured and despawned at start. This is how you *attach* groups to
  a zone — and how you accidentally destroy an unrelated group. The prefix is compared **ignoring
  case** (`veafCombatZone.findUnitsInCombatZone`): `CombatZone_Alpha-sam` belongs to
  `combatZone_Alpha`, so a case difference neither protects a group nor detaches it.
- `veafSpawn-<name>` → auto-registered as a spawnable-aircraft template.
- `OnDemand-<name>` → CAP-mission template (late activation).
- `#veafInterpreter["<cmd>"]` in a name → the unit is destroyed and the command runs at start.
- Unit-name markers `#command=`, `#spawngroup=`, `#spawnradius=`, `#spawncount=`, `#spawnchance=`,
  `#spawndelay=`, `#alarm=` → tune combat-zone spawn behaviour.
- QRA deploy entries starting with `[` or `-` are read as commands, not group names.

## Prefer VEAF aliases over literal units {#aliases}
<!-- when: before placing ground units, a SAM, AAA, infantry or a convoy. -->

When a `list_shortcuts` alias covers what's asked (a SAM, AAA, infantry, armor, artillery, a
convoy…), **use the alias, not hand-placed literal DCS units** — whether as a `#command` fake-unit
(combat-zone content) or a `#veafInterpreter` carrier (permanent asset). `list_shortcuts` gives each
command a `category` (SAM / AAA / infantry / armor / artillery / naval / transport / …), so look
there first to find the right alias. Fall back to literal units only when **no alias fits** — a
specific airframe/type or an exact placement the alias can't express. Example: asked for a
long-range SAM, place a `#veafInterpreter["-samVLR"]` carrier, **not** a literal Patriot battery.
`-samVLR` draws a real long-range battery for the mission's era; `-samLR`, despite its name, is a
**medium**-range group (defense level 4–5: Roland/Hawk, Osa/Tor). The `defense` level of `-sam`,
`-samSR`, `-samLR`, `-aaa` and of the section escorts is rolled ±1 and follows `mission.era`.

## Combat zone vs QRA — two different group models {#combat-zone-vs-qra}
<!-- when: before a combat zone, a QRA, targets, difficulty levels or moving targets. -->

**Combat zone** — groups are found by **geometry** (inside the trigger zone), coalition is
ignored **for capture** (VEAF despawns then respawns any group inside, whatever its side), and
membership also keys off the **zone-name prefix**. So: create the trigger zone, then create groups
named `<ZoneName>-...` placed inside it. To have the zone spawn VEAF assets rather than hand-placed
units, use a fake unit carrying `#command="-<alias> ..."` (an alias from `list_shortcuts`) — set it
as that unit's **`name`** (the `units` entry takes an optional `name`; the runtime reads
`#command`/`#spawn*` off the unit name). **Prefer this `#command` fake-unit** for combat-zone
content over hand-placing literal units.
With `create_combat_zone`, give the group `"command": "-armor"` and one unit: the tool names that unit `#command="-armor" <group name>` itself, so you never type the marker's quotes.

**A group belongs to one zone only, in practice.** At start a zone **destroys** the groups it
captured, and zones look at live units — so a second zone whose name is also a prefix of that group
finds nothing. Do not try to share groups between zones through overlapping names.

**Difficulty levels on the same targets** (easy ⊂ medium ⊂ hard — the usual shape of a training
range): three zones on the **same circle** with **non-overlapping names** (`…_Easy`, `…_Medium`,
`…_Hard`), each holding only its own additions, then have each level include the one below with the
`includes: [<lower level>]` key of `combat_zones[]` — transitive, so `hard` includes `medium` only
and gets `easy` too; the build refuses an unknown zone or a cycle (see `describe_module COMBATZONE`).
Play **one level at a time**: two active levels each spawn their own copy of the shared targets.

**Inert targets** (a level that must not shoot back): use **statics** (`category: static`). A live
armoured vehicle has an AA machine gun and fires at helicopters, and no zone tag sets weapons hold
(`#alarm=` sets the alarm state, which is not a rule of engagement). A static's own name is what the
prefix rule reads.

**Moving targets (convoys)**: a **native** vehicle group with a road route (`add_group` `route:`,
points after the first are *On Road*), its start inside the zone; the zone keeps a native group's
route when it respawns it. Put the convoy's air defense (Shilka, SA-13…) **in the same group** so it
follows the column.

**Coalition rule:** a `#command` fake-unit spawns in **its own coalition** — a blue fake-unit →
a blue SAM (`-sam` is not inherently red; what it draws at random is the level, never the side). So for a blue SAM
site, make the fake-unit **blue** — don't fall back to literal units just for a colour. (The
"coalition is ignored" above only governs which real groups the zone *captures* by geometry.)

**Each side on its own side of the front:** in a zone that holds both sides, each side's armor stands on its own side of the line and its air defense behind it — the short range with its armor, the medium range in depth, never between the two lines nor beyond the opposing units.
Lay the markers where each belongs on the ground, not in a pattern around the zone centre: a red SA-8 laid 2.5 km south of the centre of the Caucasus OT's `combatZone_Beslan` stood about 1 km from the blue Abrams.

**Which side must die:** a zone completes when the **hostile** coalition's units are gone, and
that side is **red** unless you say otherwise. If the units to destroy are blue — a zone played
from the red side — set `enemy_coalition: BLUE` on the `combat_zones[]` entry; otherwise the zone
holds no red unit, the watchdog sees zero enemies on its first pass (~1 min) and completes
immediately. The F10 report's friends/enemies labels follow the same setting.

**Who gets the F10 menu:** it follows from the above — the side playing the zone (the opposite of
`enemy_coalition`) is the one offered the menu, and the menu is how a zone is *activated*, not just
read. Nothing to set for that. Add `radio_menu_coalition: ALL` only when both sides must be able to
trigger the zone (an umpire in a red slot activating a blue zone), or name a side explicitly when it
is not the one playing the zone.

**Permanent asset vs combat-zone asset — two spawn markers, don't confuse them:**
- `#veafInterpreter["<alias …>"]` on a unit's **`name`** → spawned **at mission start** and
  **permanent** (the carrier unit is destroyed). Use it — **in preference to a literal unit** — for
  always-there assets, e.g. a fixed SAM site: a **blue** unit named `#veafInterpreter["-samVLR"]` →
  a blue long-range SAM at that spot on start. Same alias vocabulary as `list_shortcuts`; same
  coalition rule (follows the carrier).
- `#command="-<alias> …"` on a fake-unit **inside a combat-zone** → spawned when the **zone is
  activated** (dynamic), and despawned/respawned with the zone.
- Both take the alias from `list_shortcuts` and spawn in the carrier's coalition. Pick
  `#veafInterpreter` for a standing site, `#command` for zone-driven content.
- `add_group` sizes the clear ground it looks for from **both** markers' command (a `-sa11` carrier needs the whole site's room, not one vehicle's), and keeps other groups off that ground.
- **The carrier's unit type is not indifferent**: pick a unit of the **class the alias spawns** — a
  Rapier launcher for `-rapier`, a `Kub 2P25 ln` for `-sa6`, a `ZSU-23-4 Shilka` for `-shilka`, a
  tank for `-armor` (`list_unit_types`). The editor then draws the right threat ring and the map reads
  like what will spawn. A soldier or a truck as carrier hides a SAM site from whoever edits the mission.
- **Unit names must be unique in the whole mission** (DCS requirement), and two carriers of the same
  alias would collide. The tag is read from its quoted part only, so append a suffix after it:
  `#command="-sa6" FuldaGap-sa6`, `#veafInterpreter["-rapier, hdg 90"] #ramstein-01`.
- **Alias options can be appended inside the tag**: `#veafInterpreter["-rapier, country germany,
  hdg 135"]` — country, heading and the other options of the underlying VEAF command.
  **The country must be one of the countries of a coalition of the mission** (a Third Reich red side
  is `country thirdreich`, not `germany`): a country of no coalition spawns neutral, with no Skynet
  network. `validate_mission` warns about it.
- **Reading an existing mission, read its UNIT names before judging a group.** A group that looks
  inert in the editor — a lone radar, a lone soldier — is often a carrier whose unit name spawns a
  full battery. Dump unit names (`describe_units`) before calling anything useless or deleting it.
- To place either **durably**, add the carrier unit with `add_group` **targeting the mission
  folder** (it writes `src/mission/`, so it survives a rebuild) — not a `.miz` (that's the built
  world, overwritten on the next build). `add_group`'s result has `durable: true` for a folder.

**QRA** — interceptor groups are referenced **by exact name**, coalition **matters**, and they
**must be Late Activation** (VEAF scrambles them). So: create the trigger zone, create the
late-activation interceptor group with a coherent name, set its coalition, and list that exact
name in the QRA definition. Task it `CAP` or `Intercept` and give it **a single waypoint and no
task** (`create_qra` does): when it scrambles, the QRA module sends it to patrol the zone and engage
what enters it. A route you write yourself is flown as written only if it carries an
`EngageTargets` (`Air`) task — without one it is replaced, and the build warns about it.

## Airbases — coalition & dynamic slots {#airbases}
<!-- when: making an airfield blue or red, dynamic slots. -->

An airfield's coalition is **not** set by placing a unit near it — it lives in the mission's
warehouses table. When the user says "make Mezzeh blue", call **`set_airbase_coalition`** (name +
coalition) on the mission folder. It colours the airfield durably and turns on its **Dynamic Spawn
slots** at the same time; the build then stocks the base's warehouse with that coalition's dynamic
templates. So a base the user assigns becomes both the right colour **and** playable (dynamic slots)
without extra steps.

## Worked examples {#examples}
<!-- when: two worked examples: a combat zone with armor, a QRA. -->

- *"Create a CZ with two enemy armor groups."* → Create trigger zone (e.g. `CZ-North`). Add two
  groups named `CZ-North-armor-1` / `CZ-North-armor-2` inside it — as fake-unit groups carrying
  `#command="-armor ..."` (alias from `list_shortcuts`, **preferred**), or, only if no alias fits,
  concrete armor unit types from `list_unit_types`. Add the `COMBATZONE` block referencing `CZ-North`.
- *"Create a QRA with Mirage 2000s."* → Resolve the Mirage 2000 type via `list_unit_types`. Create
  a Late-Activation group (coherent name, correct coalition), a trigger zone, and a `QRA`
  definition referencing the group name verbatim. The user did not give names — you did.

## Step 0 — scaffold the folder when there's nothing yet {#scaffold}
<!-- when: an empty folder: which template and theatre to ask for. -->

If the user wants a mission but has only an **empty folder** (no `mission.yaml`, no `src/mission/`),
start with `scaffold_mission` — it downloads the VEAF tools from GitHub, installs them into the
folder, and runs `prepare`. **Ask which template first** and pass it as the `template` parameter —
never guess it:

- `minimal` — infrastructure + core modules;
- `standard` — the everyday set (a good default);
- `full` — everything, advanced config as commented examples.

(`custom` is not available through the MCP.) Also **ask which theatre** (map) the mission is on and
pass it as `theatre`: `scaffold_mission` then lays down a synthetic blank mission for that map in
`src/mission/`, so the folder is ready for the composites with no DCS round-trip. Omit `theatre`
only if the user will supply their own `.miz`. Once the folder exists, call `adapt_scaffold` (section
`after-scaffold`), then fill it with the composites (section `composites`).

## Prefer composites for whole features {#composites}
<!-- when: a whole feature in one call: a combat zone, a QRA, a CAP mission, a combat operation. -->

When the user asks for a **whole feature** ("create a combat zone / a QRA / a CAP mission"), reach
for the one-pass composite (`create_combat_zone` / `create_qra` / `create_cap_mission`) on a
**mission folder** — it edits both worlds (source `src/mission/` + `mission.yaml`) durably in one
call. Drop to the primitives (`add_trigger_zone`, `add_group`, `set_mission_module`) only for
partial or one-off edits, or when there's no folder (a lone `.miz`).

A **combat operation** (zones grouped under one menu; activating it spawns **all** its zones at once, `dependencies` only orders which task is listed as the current objective) is `add_combat_operation`, called **after** its zones exist: it writes `mission.yaml` only, and refuses a task naming a zone the mission does not declare.
Do not write `type: operation` by hand.
**A zone of an operation has no "Deactivate" command of its own**: the F10 menu offers it on the operation only, so the Mission Maker can switch off the whole operation or nothing.
Keep outside the operation (its own entry, `active_at_start: true`) any zone the Mission Maker may want to switch off alone — a SAM battery nobody will SEAD, a secondary objective when few pilots turn up: it keeps its command, and the operation ends without it (measured on "Marteau du Golan", 2026-10-28).

## FARPs — the pad must be flat and clear {#farps}
<!-- when: placing a FARP. -->

Place a FARP with **`add_farp`**, never `add_group` in `static` (that places the object alone, which serves nobody). It checks the pad, and its warnings are for the user, not noise:

- where the clear-ground catalogue covers the place, a pad in trees or buildings is **moved** with its ammunition dump onto the nearest clear ground within 1 km, and the result's `position` says where; pass `keep_position: true` when the user drew the spot themselves (it then only warns);
- where the elevation grid covers it, a pad with more than 3 m of height difference over 40 m around it is warned as **on a slope** — a helicopter cannot use it;
- where neither covers it (MarianaIslands, any theatre not swept on this workstation), the warning says the trees and slope were **not checked** and gives the command `veaf-tools dcs farp-spot <theatre> --at x,y`. Relay it: it needs DCS, and lists the flat, clear spots near the point. Do not claim the pad is usable when it was not checked.
- the result's `surface_check` says that no file sees a lake or a river (the grid knows the sea only): relay it and the `farp-spot` command, a pad has stood in a lake with 79 m on the grid;
- a frequency that is an airfield tower's of the theatre (same band) is warned with the airfield's name: pick another one.

On a jungle map the clear spot can be more than a kilometre from where the FARP is wanted. **Do not try to clear the trees by trigger**: DCS's « SCENERY REMOVE OBJECTS ZONE » removed none on MarianaIslands or Caucasus (known limitation `scenery-remove-objects-zone-leaves-the-forest`). Move the FARP to clear ground instead, and say how far it went.
A spot `farp-spot` leaves out is not necessarily wooded (`disposition-small-query-blocks-open-grass`): when it finds nothing near enough, ask the user to look in game before giving up on a place.

## Coordinates and the map {#coordinates}
<!-- when: positions: x/y, lat/long, real place names. -->

Placement actions take DCS local `x/y`. To orient, call `describe_map` (theatre, bullseyes,
existing zones/groups as anchors, each with its `x/y` — and each group its number of `units`); do not read the mission table by hand for a position.
If the user gives a **lat/long**, use `resolve_coordinates` to get
the `x/y` for the mission's theatre, then place. Real place names ("near Batumi", "north of
Kobuleti") resolve through the geocoder (`geocode` action) when available — always surface the
resolved point so the user can sanity-check it (DCS terrain approximates the real world).

## Building a complete mission — the checklist {#checklist}
<!-- when: a complete mission (an Open Training, an objective mission, a campaign mission): identity, airbases, support aircraft, combat content, every rule learnt the hard way. -->

Learned rebuilding the Open Training Germany Cold War from an empty folder. Each item is a thing
that was wrong at least once.

**Adapt what the scaffold ships** — done right after `scaffold_mission` with `adapt_scaffold` (section `after-scaffold`).

**Identity.**
- `mission.name` ending in `_ICAO_<code>`: an airfield **of the theatre** whose METAR station is
  alive — check it (`https://tgftp.nws.noaa.gov/data/observations/metar/stations/<ICAO>.TXT`, the
  day in `DDHHMMZ` must be today). It is how the server's RealWeather finds the weather.
  **Not a campaign mission**: `campaign_next` names it `Campaign_<campaign>_Mission_<NN>_<title>_NoMizedit`
  so that the server leaves the date, time and weather the campaign fixed — never add `ICAO_` to it.
- `mission.era`, the mission **date** (`set_mission_date`, start time on the theatre's clock), and
  `versions.yaml` `base_date` consistent with each other (a Cold War mission is not dated 2016, the
  blank mission's default).
- A **bullseye on a landmark** pilots can name (`set_bullseye`), the same for both sides unless the
  scenario says otherwise. The blank mission's bullseyes are arbitrary.
- A briefing (`set_briefing`: `sortie`, situation, blue task) that lists bases, support frequencies,
  zones and rules.
  An objective mission's maps and briefing document come from `build_mission_briefing`, which puts the maps in the DCS briefing itself.
  Any other briefing **picture** (a target photo) is `set_briefing_picture`, per side — not the same picture on both sides: a player whose side the briefing does not know sees red then blue, so sees it twice.

**Airbases.** Colour every airfield of each side (`set_airbase_coalition`), not a sample: the
front line must read on the map. Decide which bases offer slots; a neutral base with dynamic slots,
or a red base with slots nobody asked for, is an inconsistency.

**Support aircraft.**
- A **convoy** follows the roads only when its waypoints say so: `edit_route` `set` (or `add`) with `road: true` writes `On Road`; without it the vehicles drive straight across.
- A tanker needs its tasks, which a plain `add_air_group` does not give: `edit_route` `add_task`
  with `tanker`, `activate_beacon` (its TACAN) and `set_unlimited_fuel`; an AWACS `awacs` and
  `eplrs`; an escort `escort`, naming the escorted group.
- **Tracks must not overlap** at the same altitude (two tankers on one race-track in opposite
  directions is a mid-air collision); orbit altitude = waypoint altitude.
- One name per asset **everywhere**: group name, callsign family (Texaco = 1, Arco = 2, Shell = 3;
  AWACS Overlord = 1, Magic = 2…), radio frequency, preset label and `ASSETS` information text must
  agree. Cross-check them once written.
- **Its channel goes into `src/presets.yaml` in the same pass.** An AWACS, a tanker or a carrier you
  place gets its channel in the players' coalition's `channel_lists`, under the name the briefing uses,
  on the UHF list (`primary_1`, AWACS and tankers first, then carriers, then flights);
  the airfields the mission flies from get theirs through `set_airfield_channels`, on the VHF list (`primary_2`) only. The scaffold's plan
  is an Open Training's (Magic 282.2, Arco-1 290.5…): left as it is, every radio and every kneeboard
  agrees with it and not with your mission — what *Kolkhida* mission 1 flew with. The build lists every
  AWACS and tanker no preset carries, in its log and in `presets-validation-report.md`: treat that list
  as an error to fix, not a note.
- Interceptors and CAP templates: **a loadout** (the `veafSpawn-*` groups of `src/spawnables.yaml`
  are a sourced place to copy CLSIDs from), late activation, and the start the theatre allows
  (`describe_known_limitations` says where a runway or ramp start is not available).
  A **QRA takes off from the runway** of its side's field (David, 2026-10-08): `create_qra` does it
  unless a group says `start: air`, which only the user asks for. Nothing of its side may stand on
  that runway.

**A campaign mission** (one `campaign_next` prepared) also follows these, every campaign alike:
- **Three ships at sea for the players' side**: the Stennis (`Stennis`), the Roosevelt (`CVN_71`)
  and the Tarawa (`LHA_Tarawa`), each with `add_carrier_group` and its deck slots — not the Stennis
  alone (David, 2026-10-15, after *Kolkhida* mission 2). Each gets its own tower frequency, TACAN and
  ICLS channel, its channel in `src/presets.yaml`, and its line in the briefing; keep their tracks apart.
- `campaign_next` copies the campaign's `template/`, not the previous mission: what was added to a
  mission by hand (the QRA, the ships, the support tracks) is to be redone, or carried into the template.
- **The template's `src/presets.yaml` is the campaign's frequency plan**, and every mission inherits
  it. Write it once for the campaign's real assets (its AWACS, tankers, ships, airfields), under the
  names the briefing uses, and update the template whenever a mission adds an asset. *Kolkhida* flew
  missions 1 and 2 on the Open Training plan the scaffold ships (Magic 282.2 where the AWACS was
  Overlord on 251): the build said so both times, and the second time it was read as "already the case
  in mission 1". A preset warning carried over from a previous mission is still an error to fix.
- **Place the AWACS and the tankers for this mission's threat**, read from the campaign's state —
  never copied from the previous mission. A long-range SAM alive keeps them far; destroyed or with no
  search radar left, they come closer (David, 2026-10-22: *Kolkhida* mission 3 kept them 135 nm from a
  blind S-300). The briefing says where they are and why they moved.

**A persistent campaign** (`mode: persistent`) also follows these, learnt on its first server evening
(*Bouclier de l'Oronte*, Syria, 2026-11-16), each with what broke without it. `campaign validate` warns
about most of them: a warning there is a defect to fix before the server, not a remark.
- **The radio plan is David's, and the theatre's** (2026-11-17). VHF: channel 1 "Home Base" (each pilot
  sets it to the field he took off from), then the players' side's airfields, with this theatre's
  frequencies, then the VEAF flights on their VHF frequency (a flight on a tanker's UHF still talks on the VHF). UHF: the AWACS, the tankers, one common air-to-ground frequency "Air-Sol", then the VEAF
  flights (Archer, Arctic, Ninja, Pinder, Bengal, Blade…). No carriers unless the mission has them, no
  range of another map, nothing of the Caucasus off the Caucasus. `campaign next` writes this plan when it
  creates the mission folder, from the zones and the support groups of the template: put the AWACS and the
  tankers in the template first. The Syria campaign flew with Batumi, Beslan and Kutaisi on its kneeboards.
- **An AWACS and two tankers in the template, a boom and a basket** (David, 2026-11-17: a KC-135 for the
  F-16 and A-10, a KC-135MPRS or a KC-130 for the F/A-18 and AV-8B; `campaign validate` warns when one is
  missing), each with an orbit (`add_air_group` with an air start, then
  `edit_route`: a second point, the `awacs` or `tanker` task, `set_unlimited_fuel`, a race-track `orbit`),
  their channels in `src/presets.yaml`, declared in `modules.ASSETS`, named in `dynamic.support.assets`
  (the campaign then holds each out of the enemy's air defence and moves it as it changes) and both tankers
  in `dynamic.economy.tanker`, a list (the shop sells each apart). Place their first orbit over your own rear.
  The evening flew with neither, and the shop had no tanker.
- **A zone on an airfield is declared on it** (`at: { airfield: … }`), never at coordinates beside it,
  short strips included: Menagh, 2.3 km from Minakh's airfield, stayed neutral while DCS gave the airfield
  to blue. A depot or a factory of its own (`kind:`) may stand beside one.
- **Long-range SAMs at a few key points only**: `long_range_sam: true` on the zones that deserve one — a
  large rear base, a factory, a depot — two a side at most, 120 km apart (`long_range_sams`). The size
  class no longer draws one. An SA-5's reach measured in game is 240 km: two of them 17 nm apart covered the
  whole front and shot an A-10 down far from any warning.
- **Real defaults, and say what the AI can afford**: the stock (`resources.start`, 1,000), a factory's
  output (180 an hour) and the reserve keep the enemy flying an evening; lowering them grounds it.
- **No fixed weather**: a persistent campaign's mission carries no `_NoMizedit` and `campaign_next` fixes no date,
  time nor weather — the server's MizEdit preset (RealWeather) sets them at each load. Do not set them by hand.
- **The AWACS and the tankers are held by the `SUPPORT` module** (`veafSupport`), which `campaign_next` turns on
  in `mission.yaml` from `dynamic.support`: do not move their orbits by hand.
- **Axes of effort, not objectives**: a persistent campaign has no mission of the day. Write its priorities
  in `briefing.yaml` under `axes:` (a title and a text each), indicative; `campaign_next` turns them, the
  network and the air defences into a theatre dossier (`<operation>_dossier-de-theatre.pptx`) and kneeboard pages (map,
  zone table, radio plan, cheat sheet), in place of the campaign and mission decks.
- **A campaign already running keeps what its save drew**: a garrison change (a long-range SAM taken off,
  a zone moved onto its airfield) shows on the server after a reset of the campaign, or on the zones the
  save does not hold yet. Say so to whoever deploys it.

**Combat content.**
- A **training range close to a blue base** (Kobuleti next to Batumi on Caucasus): three nested
  levels through `includes:` — inert statics, light AAA, realistic short-range defense.
- **Real zones** beyond it — at least six more than the training ones, of different kinds: front-line
  armor, SEAD site, moving convoys, deep strike (HQ, SCUD, airbase OCA), antiship when there is sea.
  Pick real places of the era (`geocode`), and air defense of the era (`list_shortcuts` categories).
- **Mind what a zone's SAM covers when active**: a battery whose range reaches a friendly base, a
  tanker track or a training range spoils them. Keep medium/long-range SAMs off the training range.
- A **QRA zone** triggers on its circle, not on a border: size it to the airspace it defends.

**Rules learnt on *Marteau du Golan* (flown 2026-10-29), each with what broke without it.**
- **SEAD and strike never go to the same flight.** A mission with SAMs and strike targets gives the SAMs to a flight of their own, briefed as such. With no SEAD flight, the Hornets did both, spent the evening on the SAMs, and the Kiswah command post was never hit.
- **Helicopters fly: little turbulence and a moderate wind** — on the wind DCS *simulates*, not on the setting. `set_weather` takes the wind wanted 10 m above a reference airfield and writes the setting that gives it; its answer (`simulated_wind`, and `inspect_built_mission` after the build) gives the wind by layer. The rule: from 0 to 600 m above each helicopter departure, objective and route point, the simulated wind stays at 20 kt or less and no more than 15 kt above the surface wind there — `set_weather`, `inspect_built_mission` and `veaf-tools dcs mission-check` warn otherwise. Turbulence near 0. On 2026-10-29 the real weather made the AH-64s of *Marteau du Golan* almost unflyable; on 2026-10-31, 17 kt set at the ground became 24 kt at the surface and 36 kt at 1,000 ft. Whenever the mission has helicopter slots, set the weather yourself rather than a real-weather feed. Brief the simulated wind, never the setting, and a wind shift aloft with `wind_veer` (30° at most), never an upper wind opposed to the surface one (DCS makes a layer without wind between them).
- **`react_on_helicopters: false` is about take-off, not engagement.** Such a QRA does not scramble for helicopters, but once airborne for a jet it attacks every enemy it sees, helicopters included: two AH-64s were shot down with R-73s over the Beit Jinn pass. Never brief "they do not react to helicopters" without that nuance, and give the helicopters cover — a CAP of their own, or a route out of the QRA's circle.
- **The Mission Maker can switch the big threats off** when the players present are no match for them. A QRA follows the **Opposition** menu (`opposition:` block, `scale_with_opposition: true`, both written by default since FIX-MARTEAU-PLAY-FINDINGS): "0 aircraft" keeps it on the ground; `radio_menu: true` adds its own stop command. A long-range SAM is a zone **outside the operation** with `active_at_start: true`: it has its own "deactivate" command, and the operation ends without it. Say both in the briefing's notes for the Mission Maker.
- **Recon photos: one per objective, two at most** (David, 2026-10-30). A photo of vehicles — tanks, light armour, trucks, 4x4 — shows their zone, never where each vehicle stands, and the briefing gives such a target by its zone's centre: they move. `build_mission_briefing` keeps two photos per objective and the recon render rings no moving vehicle.
- **A target's precise coordinates are DDM and MGRS** (`N33°07.536' E035°49.482'`, `36S YB 12345 67890`), never DD°MM'SS.ss": the cockpits take one or the other. The briefing writes them so; write any you add by hand the same way.

**Numbers in briefings are measured, never estimated.** Compute distances and bullseye bearings from
the mission's `x/y` (`x` is north, `y` east: bearing = atan2(Δy, Δx)); state a weapon envelope only
if you can source it, else describe the threat without a figure. A player flies on what you wrote.

**Referenced files exist.** A sound named in `CSAR` / `CTLD` settings must be in the mission (the
build embeds only its defaults).

## Finish: validate, then build {#finish}
<!-- when: when the mission is authored: validate, build, then check the built mission. -->

When the mission is authored, close the loop without leaving the tools: run `validate_mission` on
the folder first (fix any error it reports), then `build_mission` to produce the playable `.miz`.
Surface build errors to the user rather than claiming success. This completes the empty-folder →
scaffold → edit → validate → build → play flow.

**A build that exits 0 is not a mission that works.** Read the build's counters — presets injected
into how many aircraft, waypoints into how many groups, warehouse template links, weather variants —
and question any zero. Then call `inspect_built_mission` on the folder and check what the mission is about: the weather of two variants differs, the dynamic slots carry presets and a BULLSEYE, the tanker has its tasks and frequency; `describe_units` on the built `.miz`, filtered (`group_name`, `coalition` or `category`, `include_route: false` unless you check a route), shows the combat-zone carriers and statics: unfiltered, it lists every slot template the build injects.
Then run `veaf-tools dcs mission-check` on the built `.miz`: its wind check needs no DCS and fails when the briefing's wind contradicts the simulated one.
Say what you checked, and what you could not (anything that needs DCS running, anything no action reads).

**Training versions.** When the user asks for them ("also build the training versions", a version for one role), or after the briefing of a mission night: `propose_training_plan`, then sort what the briefing states (stays as placed) from what it describes vaguely (moves to `randomize`, drawn again at every launch), show the plan, `set_training_plan`, `build_mission`. It works on a mission folder made by hand as well as on one you built; a bare `.miz` needs converting first.

## Report back clearly {#report-back}
<!-- when: always, when you tell the user what you did. -->

Tell the user which world you edited, the names/types you chose and why, and surface any
convention warning the actions returned so they can veto before you proceed with irreversible or
large changes.
