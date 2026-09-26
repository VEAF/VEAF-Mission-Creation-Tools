---
name: veaf-mission-authoring
description: How to author VEAF DCS missions correctly through the veaf-mission-mcp server — the reserved naming conventions, the combat-zone vs QRA group models, when to use VEAF aliases / #command vs literal units, and always consulting the oracle actions for unit types and module schemas rather than relying on memory. Use whenever editing or generating a VEAF mission via the veaf-mission-mcp MCP server.
---

# Authoring VEAF missions through `veaf-mission-mcp`

You edit a Mission Maker's DCS mission through the `veaf-mission-mcp` server. This skill is the
**reasoning** half; the server provides the **actions**. The user gives *intent* ("a combat zone
with two armor groups"); **you** derive the concrete unit types, group names and config — do not
ask the user for mechanical details you can decide correctly yourself.

## Always ground yourself in the oracle — never from memory

**Before anything else, call `describe_known_limitations`.** It returns, for the installed
veaf-tools version, what the tools cannot do yet (with how to do without) and the DCS behaviours
that raise no error and are wrong anyway — a late-activated group visible to scripts, `start_time`
not delaying an air spawn, a SAM without early-warning radar permanently lit… Take them into account
throughout; this skill deliberately does not repeat them, since a trap copied here would go stale.

Before naming a group, picking a unit type, or configuring a module, call the read-only oracle
actions. They read VEAF's canonical, always-current data — your training memory of DCS types or
VEAF conventions may be stale or wrong.

- `list_unit_types` — real DCS unit type ids (filter by category / name).
- `list_shortcuts` — VEAF spawn aliases. Three families: `units` (`shilka`, `sa8`), `groups`
  (composite SAM/convoy groups), and `commands` — the `#command` shortcuts (`-samVLR`, `-samLR`,
  `-armor`, random convoys, …), each with its `randomParameters`: the range of every parameter it
  draws on each use (`-samLR` and `-samSR` run the same command and differ only by their `defense`
  range). **This is the authoritative source for the `-<alias>` you put in a combat-zone
  `#command`** — never guess an alias from memory (there is no `-lrsam`).
- `describe_naming_conventions` — the reserved naming patterns (below).
- `describe_module` — is a module real? its doc page? enabled in this mission?

For an action's exact parameters, call `describe_action(name)`.

**These oracle actions plus this skill are the authoritative source for VEAF-framework facts** —
naming conventions, spawn aliases, marker/`#command`/`#veafInterpreter` formats, module config.
**For those specifically**, don't consult other tools/agents or read the VEAF framework's Lua
source (a mission maker's machine has neither): if a fact seems missing, re-query the oracle
(`describe_naming_conventions`, `describe_action`, `list_shortcuts`) or state the gap plainly rather
than sourcing it elsewhere or guessing. This scoping is **only** about VEAF-framework knowledge —
keep using your other tools normally for everything else (geocoding, reading/writing files,
building, etc.).

## The two editing worlds

- **Recipe** — the source `mission.yaml`. Durable: survives a rebuild. Prefer it for configuration.
- **Built mission** — the `.miz`. Direct, no rebuild, but overwritten on the next build from the recipe.

Every write is backed up first. State which world you are editing when you report back.

## Reserved naming conventions (the traps)

Prefer to express intent and let `add_group` name the group for you (`for_combat_zone`,
`late_activation`, `as_spawn_template`) — it applies these rules and returns `warnings`. To check a
name yourself, call `validate_group_name` (or `describe_naming_conventions` for the full list).
The dangerous ones:

- **Combat-zone membership** — a group whose name *starts with a combat-zone trigger-zone name*
  and sits inside that zone is captured and despawned at start. This is how you *attach* groups to
  a zone — and how you accidentally destroy an unrelated group.
- `veafSpawn-<name>` → auto-registered as a spawnable-aircraft template.
- `OnDemand-<name>` → CAP-mission template (late activation).
- `#veafInterpreter["<cmd>"]` in a name → the unit is destroyed and the command runs at start.
- Unit-name markers `#command=`, `#spawngroup=`, `#spawnradius=`, `#spawncount=`, `#spawnchance=`,
  `#spawndelay=`, `#alarm=` → tune combat-zone spawn behaviour.
- QRA deploy entries starting with `[` or `-` are read as commands, not group names.

## Prefer VEAF aliases over literal units

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

## Combat zone vs QRA — two different group models

**Combat zone** — groups are found by **geometry** (inside the trigger zone), coalition is
ignored **for capture** (VEAF despawns then respawns any group inside, whatever its side), and
membership also keys off the **zone-name prefix**. So: create the trigger zone, then create groups
named `<ZoneName>-...` placed inside it. To have the zone spawn VEAF assets rather than hand-placed
units, use a fake unit carrying `#command="-<alias> ..."` (an alias from `list_shortcuts`) — set it
as that unit's **`name`** (the `units` entry takes an optional `name`; the runtime reads
`#command`/`#spawn*` off the unit name). **Prefer this `#command` fake-unit** for combat-zone
content over hand-placing literal units.

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
- **The carrier's unit type is not indifferent**: pick a unit of the **class the alias spawns** — a
  Rapier launcher for `-rapier`, a `Kub 2P25 ln` for `-sa6`, a `ZSU-23-4 Shilka` for `-shilka`, a
  tank for `-armor` (`list_unit_types`). The editor then draws the right threat ring and the map reads
  like what will spawn. A soldier or a truck as carrier hides a SAM site from whoever edits the mission.
- **Unit names must be unique in the whole mission** (DCS requirement), and two carriers of the same
  alias would collide. The tag is read from its quoted part only, so append a suffix after it:
  `#command="-sa6" FuldaGap-sa6`, `#veafInterpreter["-rapier, hdg 90"] #ramstein-01`.
- **Alias options can be appended inside the tag**: `#veafInterpreter["-rapier, country germany,
  hdg 135"]` — country, heading and the other options of the underlying VEAF command.
- **Reading an existing mission, read its UNIT names before judging a group.** A group that looks
  inert in the editor — a lone radar, a lone soldier — is often a carrier whose unit name spawns a
  full battery. Dump unit names (`describe_units`) before calling anything useless or deleting it.
- To place either **durably**, add the carrier unit with `add_group` **targeting the mission
  folder** (it writes `src/mission/`, so it survives a rebuild) — not a `.miz` (that's the built
  world, overwritten on the next build). `add_group`'s result has `durable: true` for a folder.

**QRA** — interceptor groups are referenced **by exact name**, coalition **matters**, and they
**must be Late Activation** (VEAF scrambles them). So: create the trigger zone, create the
late-activation interceptor group with a coherent name, set its coalition, and list that exact
name in the QRA definition.

## Airbases — coalition & dynamic slots

An airfield's coalition is **not** set by placing a unit near it — it lives in the mission's
warehouses table. When the user says "make Mezzeh blue", call **`set_airbase_coalition`** (name +
coalition) on the mission folder. It colours the airfield durably and turns on its **Dynamic Spawn
slots** at the same time; the build then stocks the base's warehouse with that coalition's dynamic
templates. So a base the user assigns becomes both the right colour **and** playable (dynamic slots)
without extra steps.

## Worked examples

- *"Create a CZ with two enemy armor groups."* → Create trigger zone (e.g. `CZ-North`). Add two
  groups named `CZ-North-armor-1` / `CZ-North-armor-2` inside it — as fake-unit groups carrying
  `#command="-armor ..."` (alias from `list_shortcuts`, **preferred**), or, only if no alias fits,
  concrete armor unit types from `list_unit_types`. Add the `COMBATZONE` block referencing `CZ-North`.
- *"Create a QRA with Mirage 2000s."* → Resolve the Mirage 2000 type via `list_unit_types`. Create
  a Late-Activation group (coherent name, correct coalition), a trigger zone, and a `QRA`
  definition referencing the group name verbatim. The user did not give names — you did.

## Step 0 — scaffold the folder when there's nothing yet

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
only if the user will supply their own `.miz`. Once the folder exists, use the composites below to
fill it.

## Prefer composites for whole features

When the user asks for a **whole feature** ("create a combat zone / a QRA / a CAP mission"), reach
for the one-pass composite (`create_combat_zone` / `create_qra` / `create_cap_mission`) on a
**mission folder** — it edits both worlds (source `src/mission/` + `mission.yaml`) durably in one
call. Drop to the primitives (`add_trigger_zone`, `add_group`, `set_mission_module`) only for
partial or one-off edits, or when there's no folder (a lone `.miz`).

## Coordinates and the map

Placement actions take DCS local `x/y`. To orient, call `describe_map` (theatre, bullseyes,
existing zones/groups as anchors). If the user gives a **lat/long**, use `resolve_coordinates` to get
the `x/y` for the mission's theatre, then place. Real place names ("near Batumi", "north of
Kobuleti") resolve through the geocoder (`geocode` action) when available — always surface the
resolved point so the user can sanity-check it (DCS terrain approximates the real world).

## Building a complete mission — the checklist

Learned rebuilding the Open Training Germany Cold War from an empty folder. Each item is a thing
that was wrong at least once.

**Adapt what the scaffold ships — it is not written for your theatre.** The default
`src/presets.yaml` carries a Caucasus channel plan (Batumi, carriers…), `src/versions.yaml` a Syria
position and timezone, `src/waypoints.yaml` example points that point at nothing and are injected into
every slot. Rewrite the three for the mission's theatre; keep in `dynamic-slot-templates.yaml` only
the coalitions that actually get dynamic slots.

**Identity.**
- `mission.name` ending in `_ICAO_<code>`: an airfield **of the theatre** whose METAR station is
  alive — check it (`https://tgftp.nws.noaa.gov/data/observations/metar/stations/<ICAO>.TXT`, the
  day in `DDHHMMZ` must be today). It is how the server's RealWeather finds the weather.
- `mission.era`, the mission **date** (`set_mission_date`, start time on the theatre's clock), and
  `versions.yaml` `base_date` consistent with each other (a Cold War mission is not dated 2016, the
  blank mission's default).
- A **bullseye on a landmark** pilots can name (`set_bullseye`), the same for both sides unless the
  scenario says otherwise. The blank mission's bullseyes are arbitrary.
- A briefing (`set_briefing`: `sortie`, situation, blue task) that lists bases, support frequencies,
  zones and rules.

**Airbases.** Colour every airfield of each side (`set_airbase_coalition`), not a sample: the
front line must read on the map. Decide which bases offer slots; a neutral base with dynamic slots,
or a red base with slots nobody asked for, is an inconsistency.

**Support aircraft.**
- A tanker needs its tasks, which a plain `add_air_group` does not give: `edit_route` `add_task`
  with `tanker`, `activate_beacon` (its TACAN) and `set_unlimited_fuel`; an AWACS `awacs` and
  `eplrs`; an escort `escort`, naming the escorted group.
- **Tracks must not overlap** at the same altitude (two tankers on one race-track in opposite
  directions is a mid-air collision); orbit altitude = waypoint altitude.
- One name per asset **everywhere**: group name, callsign family (Texaco = 1, Arco = 2, Shell = 3;
  AWACS Overlord = 1, Magic = 2…), radio frequency, preset label and `ASSETS` information text must
  agree. Cross-check them once written.
- Interceptors and CAP templates: **a loadout** (the `veafSpawn-*` groups of `src/spawnables.yaml`
  are a sourced place to copy CLSIDs from), late activation, and the start the theatre allows
  (`describe_known_limitations` says where a runway or ramp start is not available).

**Combat content.**
- A **training range close to a blue base** (Kobuleti next to Batumi on Caucasus): three nested
  levels through `includes:` — inert statics, light AAA, realistic short-range defense.
- **Real zones** beyond it — at least six more than the training ones, of different kinds: front-line
  armor, SEAD site, moving convoys, deep strike (HQ, SCUD, airbase OCA), antiship when there is sea.
  Pick real places of the era (`geocode`), and air defense of the era (`list_shortcuts` categories).
- **Mind what a zone's SAM covers when active**: a battery whose range reaches a friendly base, a
  tanker track or a training range spoils them. Keep medium/long-range SAMs off the training range.
- A **QRA zone** triggers on its circle, not on a border: size it to the airspace it defends.

**Numbers in briefings are measured, never estimated.** Compute distances and bullseye bearings from
the mission's `x/y` (`x` is north, `y` east: bearing = atan2(Δy, Δx)); state a weapon envelope only
if you can source it, else describe the threat without a figure. A player flies on what you wrote.

**Referenced files exist.** A sound named in `CSAR` / `CTLD` settings must be in the mission (the
build embeds only its defaults).

## Finish: validate, then build

When the mission is authored, close the loop without leaving the tools: run `validate_mission` on
the folder first (fix any error it reports), then `build_mission` to produce the playable `.miz`.
Surface build errors to the user rather than claiming success. This completes the empty-folder →
scaffold → edit → validate → build → play flow.

**A build that exits 0 is not a mission that works.** Read the build's counters — presets injected
into how many aircraft, waypoints into how many groups, warehouse template links, weather variants —
and question any zero. Then open the built `.miz` and check what the mission is about: the weather of
two variants differs, the dynamic slots carry presets and a BULLSEYE, the tanker has its tasks, the
combat-zone carriers and statics are what you meant. Say what you checked, and what you could not
(anything that needs DCS running).

## Report back clearly

Tell the user which world you edited, the names/types you chose and why, and surface any
convention warning the actions returned so they can veto before you proceed with irreversible or
large changes.
