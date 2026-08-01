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
| 2 | [List VEAF modules and their settings](#list-veaf-modules) | Mission state | Recipe | 🔥 |
| 3 | [Add a ground / vehicle group](#add-a-group) | Order of battle | Built mission | ⭐ |
| 4 | [Enable / disable / configure a module (recipe)](#configure-a-module-recipe) | Modules & settings | Recipe | ⭐ |
| 5 | [Enable / disable a module (built mission)](#enable-a-module-built) | Modules & settings | Built mission | ⭐ |
| 6 | [Change the log level](#log-level) | Modules & settings | Recipe + built | ◽ |
| 7 | [Enable / disable password security](#password-security) | Modules & settings | Recipe + built | ◽ |
| 8 | [Set a specific VEAF parameter](#veaf-parameter) | Modules & settings | Recipe + built | ◽ |
| 9 | [Add a circular trigger zone](#add-a-zone) | Zones & triggers | Built mission | ◽ |
| 10 | [Add a startup script to the mission](#startup-script) | Zones & triggers | Built mission | ◽ |
| 11 | [Search-and-replace text in scripts](#search-replace) | Advanced edits | Built mission | 🔧 |
| 12 | [List DCS unit types](#list-dcs-units) | Domain knowledge | — | ⭐ |
| 13 | [List VEAF aliases / shortcuts](#list-veaf-aliases) | Domain knowledge | — | ⭐ |
| 14 | [Explain the naming conventions](#naming-conventions) | Domain knowledge | — | ◽ |
| 15 | [Look up a VEAF module](#describe-module) | Domain knowledge | — | ◽ |
| 16 | [Check a group name](#check-group-name) | Domain knowledge | — | ◽ |
| 17 | [Create a full combat zone (one pass)](#create-combat-zone) | 🏗️ Composites | Recipe (folder) | 🔥 |
| 18 | [Create a full QRA (one pass)](#create-qra) | 🏗️ Composites | Recipe (folder) | 🔥 |
| 19 | [Create an on-demand CAP mission (one pass)](#create-cap) | 🏗️ Composites | Recipe (folder) | ⭐ |
| 20 | [Create a mission folder from scratch](#create-mission-folder) | 🏗️ Getting started | Folder | ⭐ |
| 21 | [Read the map (orientation)](#read-the-map) | 🗺️ Map & coordinates | — | ⭐ |
| 22 | [Convert coordinates (x/y ↔ lat/lon)](#convert-coordinates) | 🗺️ Map & coordinates | — | ◽ |
| 23 | [Place by real place name (geocoding)](#geocode) | 🗺️ Map & coordinates | — | ⭐ |
| 24 | [Validate a mission before build](#validate-mission) | 🏁 Validate & build | Folder | ⭐ |
| 25 | [Build the playable .miz](#build-mission) | 🏁 Validate & build | Folder | 🔥 |
| 26 | [Colour a base and enable its dynamic slots](#colour-base) | 🛫 Bases & airfields | Recipe (folder) | 🔥 |

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

*Folder · 🔥* — Builds the folder into a `.miz` ready to play in DCS (runs `veaf-tools build`). The
payoff: empty folder → content → **playable mission**.

> 💬 *"Build the mission."*

## 🏗️ Composites — create a full feature (one pass)

*The core goal: from a single request, the AI lays down a whole VEAF feature across **both worlds**
(source `src/mission` + `mission.yaml`) of a **mission folder**. Durable: a later `veaf-tools build`
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
