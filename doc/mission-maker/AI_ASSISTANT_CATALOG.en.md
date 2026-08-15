# AI mission-editing assistant — action catalogue

> **Audience**: Mission Makers driving their mission's editing with an AI (Claude) wired to the
> `veaf-mission-mcp` MCP server.
>
> 🇫🇷 [`AI_ASSISTANT_CATALOG.md`](AI_ASSISTANT_CATALOG.md)
>
> 📓 Technical doc (developers/integrators): [`developer/mission-editing-mcp.en.md`](../developer/mission-editing-mcp.en.md).

This page lists **everything you can ask the AI** to do today, in plain language. You don't need
to know the technical action names: you phrase your request, the AI picks the action.

> 🌱 **Living doc** — this catalogue grows with every new capability added to the MCP. The
> "frequency" column is an **estimate** of usage, to be adjusted with field feedback.

## Two editing levels (keep this in mind)

The AI can act in two places, and it changes what "survives":

- **The recipe (the source `mission.yaml`)** — the config file the VEAF tooling *builds* your
  mission from. Editing the recipe is **durable**: the next rebuild starts from the updated
  config. Prefer this level for anything configuration-related.
- **The built mission (the `.miz`)** — direct edits to the final mission file, **without a
  rebuild**. Fast and handy for a one-off tweak, but a rebuild from the recipe will **overwrite**
  those edits.

> 🛟 **Safety net**: before *every* change, the AI takes a **timestamped backup** of the file
> concerned. Nothing is overwritten without a copy.

## Frequency legend

| Icon | Estimated frequency |
|------|---------------------|
| 🔥 | Very frequent (every editing session) |
| ⭐ | Frequent |
| ◽ | Occasional |
| 🔧 | Advanced / rare |

## Complete index

| # | Action (in plain language) | Theme | Level | Freq. |
|---|-----------------------------|-------|-------|-------|
| 1 | [List the groups and zones already present](#list-groups-and-zones) | Mission state | Built mission | 🔥 |
| 2 | [Inspect the units, their loadouts and their routes](#inspect-units) | Mission state | Built mission | 🔥 |
| 3 | [List VEAF modules and their settings](#list-veaf-modules) | Mission state | Recipe | 🔥 |
| 4 | [Add a ground / vehicle group](#add-a-group) | Order of battle | Built mission | ⭐ |
| 5 | [Change an existing aircraft or vehicle](#change-a-unit) | Order of battle | Built mission | ⭐ |
| 6 | [Move, rename or reconfigure a group](#change-a-group) | Order of battle | Built mission | ⭐ |
| 7 | [Change a flight's route and what it does there](#change-a-route) | Order of battle | Built mission | ⭐ |
| 8 | [Enable / disable / configure a module (recipe)](#configure-a-module-recipe) | Modules & settings | Recipe | ⭐ |
| 9 | [Enable / disable a module (built mission)](#enable-a-module-built) | Modules & settings | Built mission | ⭐ |
| 10 | [Change the log level](#log-level) | Modules & settings | Recipe + built | ◽ |
| 11 | [Enable / disable password security](#password-security) | Modules & settings | Recipe + built | ◽ |
| 12 | [Set a specific VEAF parameter](#veaf-parameter) | Modules & settings | Recipe + built | ◽ |
| 13 | [Add a circular trigger zone](#add-a-zone) | Zones & triggers | Built mission | ◽ |
| 14 | [Change a zone (move, resize, polygon)](#change-a-zone) | Zones & triggers | Built mission | ◽ |
| 15 | [Add a startup script to the mission](#startup-script) | Zones & triggers | Built mission | ◽ |
| 16 | [Draw on the F10 map](#draw-on-the-f10-map) | Zones & triggers | Built mission | ◽ |
| 17 | [Search-and-replace text in scripts](#search-replace) | Advanced edits | Built mission | 🔧 |
| 18 | [List DCS unit types](#list-dcs-units) | Domain knowledge | — | ⭐ |
| 19 | [List VEAF aliases / shortcuts](#list-veaf-aliases) | Domain knowledge | — | ⭐ |
| 20 | [Explain the naming conventions](#naming-conventions) | Domain knowledge | — | ◽ |
| 21 | [Look up a VEAF module](#describe-module) | Domain knowledge | — | ◽ |
| 22 | [Check a group name](#check-group-name) | Domain knowledge | — | ◽ |
| 23 | [Create a full combat zone (one pass)](#create-combat-zone) | 🏗️ Composites | Recipe (folder) | 🔥 |
| 24 | [Create a full QRA (one pass)](#create-qra) | 🏗️ Composites | Recipe (folder) | 🔥 |
| 25 | [Create an on-demand CAP mission (one pass)](#create-cap) | 🏗️ Composites | Recipe (folder) | ⭐ |
| 26 | [Create a mission folder from scratch](#create-mission-folder) | 🏗️ Getting started | Folder | ⭐ |
| 27 | [Read the map (orientation)](#read-the-map) | 🗺️ Map & coordinates | — | ⭐ |
| 28 | [Convert coordinates (x/y ↔ lat/lon)](#convert-coordinates) | 🗺️ Map & coordinates | — | ◽ |
| 29 | [Place by real place name (geocoding)](#geocode) | 🗺️ Map & coordinates | — | ⭐ |
| 30 | [Validate a mission before build](#validate-mission) | 🏁 Validate & build | Folder | ⭐ |
| 31 | [Build the playable .miz](#build-mission) | 🏁 Validate & build | Folder | 🔥 |
| 32 | [Colour a base and enable its dynamic slots](#colour-base) | 🛫 Bases & airfields | Recipe (folder) | 🔥 |

---

## 🧠 Domain knowledge (the AI knows DCS + VEAF)

*The AI leans on these to pick the right unit types, name groups correctly and configure modules
— so you don't have to know the technical details. They read from VEAF's canonical
(generated / vendored) data, so they're always current. You can also query them directly.*

### List DCS unit types {#list-dcs-units}

*Knowledge · ⭐* — DCS unit types (filter by category or name), from the `update-dcs-data`
generated database.

> 💬 *"Which Russian fighters are available?"* · *"Show me the DCS SAMs."*

### List VEAF aliases / shortcuts {#list-veaf-aliases}

*Knowledge · ⭐* — The VEAF alias vocabulary (`shilka`, `sa8`, …) for spawning units and composite
groups (SAM sites, convoys).

> 💬 *"What's the alias for a Shilka?"* · *"List the ready-made SAM groups."*

### Explain the naming conventions {#naming-conventions}

*Knowledge · ◽* — The reserved naming patterns (combat zone, `veafSpawn-`, `#command`,
interpreter…) the AI must respect so it doesn't break a mission.

> 💬 *"Why does my group vanish at start?"* (the AI checks the conventions)

### Look up a VEAF module {#describe-module}

*Knowledge · ◽* — Confirms a module exists, points to its doc page, and says whether it's enabled
in a given mission.

> 💬 *"How is the QRA module configured?"*

### Check a group name {#check-group-name}

*Knowledge · ◽* — Checks that a group name doesn't fall into a reserved pattern
(`veafSpawn-`/`OnDemand-` prefixes, `#command`/interpreter markers, QRA syntax…) and, against a
given mission, warns about the **combat-zone capture trap**. The AI uses it before adding a group
and relays any warning to you.

> 💬 *"Could this group name cause a problem?"*

---

## 🏗️ Getting started — a mission from scratch

*Before anything else: start from an **empty folder** and get a ready-to-use VEAF mission folder.
The AI downloads the VEAF tools from GitHub, installs them into the folder, and lays down the
default files for the chosen template.*

### Create a mission folder from scratch {#create-mission-folder}

*Folder · ⭐* — In one call, on an **empty folder**: the AI fetches the latest VEAF tools (updater +
`veaf-tools`) from the GitHub release, installs them, then prepares the folder with the chosen
template. This is **step 0** before adding combat zones, QRAs, etc. The AI **asks which template**
first:

- `minimal` — infrastructure + core modules;
- `standard` — the everyday set (recommended);
- `full` — everything, advanced config as commented examples.

You can also name the **theatre** (Caucasus, …): the AI then generates a blank mission for that map
directly, ready for combat zones / QRAs — **with no DCS round-trip**.

> 💬 *"Create a new VEAF mission on Caucasus in this folder."* (the AI asks for the template +
> theatre, then installs and generates everything)

## 🗺️ Map & coordinates

*Orient and convert without launching DCS. DCS theatres are the real world projected: the AI can
convert between DCS local coordinates (x/y) and lat/long.*

### Read the map {#read-the-map}

*Orientation · ⭐* — The AI reads the **theatre**, per-coalition **bullseyes**, and existing
zones/groups as reference points, to place things relative to known anchors.

> 💬 *"Which theatre is this? Show me the bullseyes and existing zones."*

### Convert coordinates {#convert-coordinates}

*Conversion · ◽* — Converts a position between **DCS x/y** and **lat/long** for the mission's
theatre (the AI reads the theatre; you supply nothing else).

> 💬 *"What's x=-291000 y=617000 in lat/long?"*

### Place by real place name {#geocode}

*Geocoding · ⭐* — DCS theatres are the real world: the AI resolves a **place name** ("Batumi",
"Kobuleti airport"), optionally offset ("10 km north of X"), to DCS coordinates. Via OpenStreetMap
by default (free); Google Maps if a key is configured. **Approximate result** (DCS terrain
approximates reality): the AI always shows the resolved point for you to confirm. **Named** places
work; vague terrain ("the woods") does not.

> 💬 *"Put a SAM 15 km south-east of Batumi airport."* (the AI geocodes, offsets, then places)

## 🏁 Validate & build

*The last step: from recipe to a playable `.miz`, without leaving the assistant.*

### Validate a mission {#validate-mission}

*Folder · ⭐* — Checks the folder before build (config, modules, references) and lists errors and
warnings. Do this before building.

> 💬 *"Check my mission is OK before building it."*

### Build the playable .miz {#build-mission}

*Folder · 🔥* — Builds the folder into a `.miz` ready to play in DCS (runs `veaf-tools mission build`). The
payoff: empty folder → content → **playable mission**.

> 💬 *"Build the mission."*

## 🏗️ Composites — create a full feature (one pass)

*The core goal: from a single request, the AI lays down a whole VEAF feature across **both worlds**
(source `src/mission` + `mission.yaml`) of a **mission folder**. Durable: a later `veaf-tools mission build`
produces the `.miz`.*

### Create a full combat zone {#create-combat-zone}

*Recipe (folder) · 🔥* — In one call: the trigger zone, the groups placed inside it (auto-named so
the zone captures them) **and** the `COMBATZONE` block in `mission.yaml`. You describe, the AI
assembles. The AI can also make the zone **spawn predefined VEAF groups** on activation (SAM sites,
convoys…) instead of hard-placing units.

> 💬 *"Create a “North” combat zone with two enemy armor groups."*

### Create a full QRA {#create-qra}

*Recipe (folder) · 🔥* — In one call: the protected zone, the **Late-Activation** interceptors (on
the right coalition) **and** the `QRA` definition in `mission.yaml` (referencing the groups by
exact name). You name the aircraft, the AI picks the type and assembles.

> 💬 *"Create a red QRA in Mirage 2000s over the North zone."*

### Create an on-demand CAP mission {#create-cap}

*Recipe (folder) · ⭐* — In one call: the `OnDemand-<name>` **Late-Activation** template group
**and** the `cap_missions` entry in `mission.yaml`.

> 💬 *"Create an on-demand CAP “Escort” with two F-15s."*

## 🛫 Bases & airfields

### Colour a base and enable its dynamic slots {#colour-base}

*Recipe (folder) · 🔥* — Assign an airfield to a coalition (blue / red / neutral). A base's colour
is **not** changed by placing a unit nearby: just say "Mezzeh is blue" and the assistant colours the
airfield **durably**, then **enables its Dynamic Spawn slots**, filling its warehouse with the
coalition's dynamic aircraft at build time.

> 💬 *"Make Mezzeh blue."*

---

## 🔥 Mission state

*The AI looks at what exists before acting — just like you open the DCS editor outliner before
adding something.*

### List the groups and zones {#list-groups-and-zones}

*Built mission · 🔥* — The AI lists the groups (name, coalition, country, category) and trigger
zones (name, position, radius) present in the mission.

> 💬 *"What groups are in my mission?"*
> 💬 *"List the trigger zones for me."*

### Inspect the units, their loadouts and their routes {#inspect-units}

*Built mission · 🔥* — A deeper level of detail than the group list. For every aircraft or vehicle the AI
gives you its **type**, its **AI skill**, its **livery**, its **callsign**, its side number, position,
heading, fuel — and its **loadout, pylon by pylon**. Per group: its task, its radio frequency, whether
it is hidden, whether it starts engines-off or late-activated, and its **full route** with the tasks
at each waypoint.

This is what to read **before asking for a change**: to alter a loadout the AI first has to see the
one that is there, and on which stations.

> 💬 *"What is Colt flight carrying, and on which pylons?"*
> 💬 *"Show me Enfield's route and what it is meant to do at each waypoint."*

> ⚠️ **On a big mission, say what you are after.** An adopted mission (a Foothold, say) holds hundreds
> of groups — megabytes of detail — so ask for one flight by name ("Colt" is enough), a coalition or a
> category. Say so if you do not care about the routes; it shortens the answer a lot.

### List VEAF modules {#list-veaf-modules}

*Recipe · 🔥* — The AI reads the source config and tells you which VEAF modules are enabled,
disabled, or configured (with their settings).

> 💬 *"What's enabled in my mission?"*
> 💬 *"Is CTLD active?"* (its settings live in `ctld-config.yaml`)

---

## ⭐ Order of battle

### Add a group {#add-a-group}

*Built mission · ⭐* — The AI inserts a ground / vehicle group: the units (you say what and how
many), a position, and optionally a route (with a looping patrol). Adding twice creates two
groups — like two placements in the editor. The AI **names the group correctly itself** from your
intent: attached to a combat zone (zone-name prefix), **Late Activation** for a QRA, or a spawn
template (`veafSpawn-`).

> 💬 *"Add a section of 3 T-72s patrolling around this point."*
> 💬 *"Put two armor groups in the North combat zone."*
> 💬 *"Place Su-27 interceptors in Late Activation for the QRA."*

### Create a player slot {#add-a-player-slot}

*Built mission · ⭐* — The AI creates a **flyable slot**: the one thing needed before anybody can fly
a mission built from scratch. You give the aircraft, a position, and the start type — **airborne**
(altitude, speed, heading) or **on the ground** cold/hot (there you supply the parking spot). A ground
start with no spot is **refused** rather than guessed: parking spots are data captured in DCS, not
invented. The AI writes the right start waypoint pair for you and sets the group radio.

> 💬 *"Add an A-10C slot on parking 43 at Kobuleti, cold start."*
> 💬 *"Put an F-16 slot airborne at 15,000 ft over the zone."*

One thing to know: a slot is **Client** skill (playable in single-player too) and is **never** a
dynamic-spawn template — that setting, left on, is exactly what makes a slot sit in the file but not
appear in the slot list.

### Put a flight on the ramp {#add-a-flight}

*Built mission · ⭐* — The AI places a **flight** (one or more aircraft) on the parking stands of an
airfield you **name** — it picks the free stands itself, so you never need their numbers. It takes the
stands nearest the runway, skips the ones already taken, and **refuses** if a requested stand is
occupied (telling you which group holds it) or the airfield has no real aircraft stand. Start cold or
hot on the ramp, from the runway, or airborne.

> 💬 *"Put a two-ship of F-16s on the ramp at Kobuleti."*
> 💬 *"Add four Su-25s at Batumi parking, engines hot."*
> 💬 *"Scramble a flight of F-15s from Incirlik's runway."*

Aircraft are **AI by default** — handy for traffic or targets. An AI flight does **not** appear in the
"Choice of role" screen (which lists only playable slots): to spawn into it and fly it, ask explicitly
for **player slots**. The airfield must have been **captured** first (parking data); otherwise the AI
tells you rather than guessing.

### Change an existing aircraft or vehicle {#change-a-unit}

*Built mission · ⭐* — Change what is **already** in the mission, unit by unit: its **loadout**
(pylon by pylon), its **AI level**, its **livery**, its **heading**, its **callsign** and its
**onboard number**. You give the heading in degrees, the AI converts it. Only the settings you ask
for change, and the AI tells you what was there before.

> 💬 *"Give Colt flight an air-to-ground loadout."*
> 💬 *"Take the bombs off pylon 4 of Colt 1-1-1."*
> 💬 *"Set this MiG to Excellent and point it at 270."*
> 💬 *"Rename this flight's callsign to Colt 2-3."*

Three things worth knowing, because each one saves a surprise:

- **The AI has to look first** ([inspect the units](#inspect-units)): it addresses the unit by its
  **exact** name, so an edit can never land on the wrong group.
- **A livery and a weapon cannot be checked** by the tool: DCS shows the default skin, or drops a
  weapon the airframe cannot carry, **without saying so**. The AI will remind you; verify it in the
  editor.
- **Turning an AI unit into a player slot is refused** (and the reverse too): that is not a skill
  level but a multiplayer slot, which would appear in — or vanish from — the list of available
  places.

### Move, rename or reconfigure a group {#change-a-group}

*Built mission · ⭐* — Act on a **whole** group: **move** it, **rename** it, change its **radio
frequency**, put it in **Late Activation**, **hide** it or leave it with **engines off**.

> 💬 *"Move that SAM battery 5 km east."*
> 💬 *"Rename this group to the VEAF convention."*
> 💬 *"Put this flight in Late Activation, engines off."*
> 💬 *"Set this flight's frequency to 305 AM."*

The move is the part that needed the most care, and here is why:

- **A group is not a point.** It is units in a formation, plus possibly a route. The tool moves
  **every unit, every waypoint and the group's anchor** by the same vector: otherwise the formation
  shears, or the route detaches from the units — and neither shows until somebody flies it.
- **A bearing and a distance are computed on the globe**, with the same machinery as placing by a
  real-world place name, not by adding metres to a coordinate.
- ⚠️ **The terrain at the destination cannot be checked** at build time: a ground group can end up in
  the water or on a slope with nothing to say so. That is also why *runtime* placement (a VEAF spawn)
  is the thing that knows how to avoid villages and forests. Verify it in the editor.

Two useful refusals: **renaming onto a name already taken** is blocked (two groups sharing a name
make every later edit ambiguous), and so is **a name that triggers a reserved VEAF convention** — for
instance prefixing a group with a combat zone's name, which makes it *vanish at mission start*. If
that is exactly your intent, the AI can go through by saying so explicitly. Finally, **the frequency
is checked against what the aircraft can actually tune**: out of range, the DCS editor would refuse to
save the mission.

### Change a flight's route and what it does there {#change-a-route}

*Built mission · ⭐* — Add, insert, remove or reorder a **waypoint**, change its altitude, speed, name
or type — and above all give it a **task**: orbit, attack a group, bomb a point, engage the targets in
a zone, land, set a frequency, or loop the route back on itself.

> 💬 *"Add a waypoint after the third, at 20,000 feet."*
> 💬 *"Have this tanker orbit a race-track at 20,000 feet, 300 knots."*
> 💬 *"Put an attack task on that group at waypoint 3."*
> 💬 *"Loop the patrol from the last waypoint back to the second."*

Three things worth knowing:

- **You speak feet and knots**, the tool converts (the mission file itself is in metres and metres per
  second). Answers give you both.
- **Tasks are a closed list**, each with its parameters checked. That is deliberate: a made-up task is
  accepted by the file, **ignored by DCS**, and you only find out in flight when the aircraft does
  nothing. If a task you need is missing, it can be added — on request, never at random.
- **DCS refuses to save a mission whose route has no waypoint with a locked time.** Removing or
  reordering can take out the only locked one: the tool re-locks one and tells you.

### Change a zone: move it, resize it, fit it to the terrain {#change-a-zone}

*Built mission · ◽* — A VEAF combat zone **is** a trigger zone. Until now, adjusting one meant deleting
it and building it again; now it moves, resizes, gets renamed, changes shape, can **follow a carrier**,
or go away.

> 💬 *"Shift the combat zone 3 km north."*
> 💬 *"Have this zone follow the ridge line rather than a circle."*
> 💬 *"Make the QRA zone bigger."*
> 💬 *"Attach this zone to the Stennis."*

- **A polygon zone follows the terrain**: you give three points or more. The VEAF runtime handles any
  polygon — but the DCS editor only **draws** 4-point quads, so beyond that the tool warns you and it
  needs one check in the editor.
- **Moving a polygon zone carries its shape** (otherwise the zone would cover terrain nobody chose).
- ⚠️ **Renaming a zone does not update what references it**: the combat zone's `mission.yaml` entry and
  its groups' name prefix need doing by hand. The tool reminds you.

### Draw on the F10 map {#draw-on-the-f10-map}

*Built mission · ◽* — A coordination line, an ingress corridor, a no-fly box, a label. **The reason to
do it here rather than in the editor**: a drawing made by hand is **lost** the moment the mission is
rebuilt from its folder, while one the AI places is part of the recipe.

> 💬 *"Draw the FSCL and label the ingress corridor on the F10 map."*
> 💬 *"Draw a no-fly box around Maykop."*
> 💬 *"Move that label 5 km south."*

- **The layer decides who sees the drawing** — red, blue, neutral, common, or the author's own — and it
  is never a default: a drawing on the wrong layer is invisible to those who need it and visible to
  those who should not see it.
- **Six shapes are available**: the line (two points or more, closed to outline an area), the
  rectangle, the text label, the circle (a radius), the oval (two axes and an angle), and the free-form
  filled polygon (three points or more). The arrow and the icon are still **refused** with a reason —
  an arrow's outline needs an in-game check, and an icon needs a file name from DCS's own icon set that
  nothing here lists — rather than a guess the editor would silently drop.

---

## ⭐ Modules & settings

### Enable / disable / configure a module — recipe {#configure-a-module-recipe}

*Recipe · ⭐* — The AI edits the source config: it enables or disables a module (simple toggle),
or sets a full settings block (e.g. a combat zone with its zones, messages…). **Durable**:
survives a rebuild. Your comments in the file are preserved.

> 💬 *"Enable CTLD in my mission."*
> 💬 *"Add a combat zone “Alpha” with these settings…"*

### Enable / disable a module — built mission {#enable-a-module-built}

*Built mission · ⭐* — Toggles a module's activation directly in the already-built mission,
without a rebuild. Handy for a quick test (⚠️ overwritten on the next rebuild from the recipe).

> 💬 *"Quickly disable the SPAWN module in the .miz to test."*

### Change the log level {#log-level}

*Recipe + built · ◽* — Sets the VEAF logging level (error / warning / info / debug / trace). On
the **recipe** (durable) or the **built mission** (fast, overwritten on rebuild).

> 💬 *"Put the VEAF logs in debug (in the recipe)."*

### Enable / disable password security {#password-security}

*Recipe + built · ◽* — Enables or disables the VEAF security flag (the password required for
protected commands). On the **recipe** it also handles the **password hashes** (JTF / Mission
Master) — which the built mission does not.

> 💬 *"Turn off password security on this test mission."*

### Set a specific VEAF parameter {#veaf-parameter}

*Recipe + built · ◽* — Sets a given VEAF configuration parameter to a value (recipe: the
`settings:` block → `veaf.config.<key>`; built: directly in `veaf-config.lua`).

> 💬 *"Set such-and-such VEAF parameter to this value."*

---

## ◽ Zones & triggers

### Add a circular trigger zone {#add-a-zone}

*Built mission · ◽* — Inserts a named **circular** trigger zone (centre, radius). This is the
zone a VEAF combat zone references — combined with adding groups, it lets you lay down a full
combat zone.

> 💬 *"Create a “North” trigger zone of 3 km here."*

### Add a startup script to the mission {#startup-script}

*Built mission · ◽* — Adds a "mission start" trigger that runs a script — useful to outfit a
**vanilla or CTLD** mission with scripting without the DCS editor's Triggers tab (inline Lua, or
a `.lua` file embedded / loaded from disk).

> 💬 *"Run this bit of Lua at mission start."*
> 💬 *"Embed and load this .lua script at launch."*

---

## 🔧 Advanced edits

### Search-and-replace text in scripts {#search-replace}

*Built mission · 🔧* — Text or regular-expression replacement across the mission's embedded Lua
files (restricted to scripts, never the raw tables or binaries). A troubleshooting tool — handle
with care.

> 💬 *"Replace “debug” with “info” in the veaf-* scripts."*

---

## What's next?

The roadmap aims to let the AI build **complete** VEAF features **in a single pass**, across both
worlds (the `.miz` and the `mission.yaml` recipe):

- 🧠 **The AI gains a "domain brain"** — access to DCS unit types, VEAF aliases/shortcuts, naming
  conventions and each module's config. It names and configures things **itself** (you give the
  intent, not the details).
- ⭐ **Context-aware group creation** — *"create a CZ with two armor groups"* or *"a QRA in
  Mirage 2000s"*: the AI picks the types, names the groups per the conventions, handles Late
  Activation, etc.
- 🔁 **Target symmetry** — every setting applicable to both the recipe and the built mission will
  work on both.
- 🏗️ **One-shot actions** — `create_combat_zone`, `create_qra`, `create_cap_mission`: zone +
  groups + config in a single call.

This page grows with each new capability. For the technical detail, see the
[developer doc](../developer/mission-editing-mcp.en.md).
