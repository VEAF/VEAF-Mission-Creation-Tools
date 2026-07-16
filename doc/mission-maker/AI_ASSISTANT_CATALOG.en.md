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
| 6 | [Change the log level](#log-level) | Modules & settings | Built mission | ◽ |
| 7 | [Enable / disable password security](#password-security) | Modules & settings | Built mission | ◽ |
| 8 | [Set a specific VEAF parameter](#veaf-parameter) | Modules & settings | Built mission | ◽ |
| 9 | [Add a circular trigger zone](#add-a-zone) | Zones & triggers | Built mission | ◽ |
| 10 | [Add a startup script to the mission](#startup-script) | Zones & triggers | Built mission | ◽ |
| 11 | [Search-and-replace text in scripts](#search-replace) | Advanced edits | Built mission | 🔧 |

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
> 💬 *"Is CTLD active? With what settings?"*

---

## ⭐ Order of battle

### Add a group {#add-a-group}

*Built mission · ⭐* — The AI inserts a ground / vehicle group: the units (you say what and how
many), a position, and optionally a route (with a looping patrol). Adding twice creates two
groups — like two placements in the editor.

> 💬 *"Add a section of 3 T-72s patrolling around this point."*
> 💬 *"Place a blue recon group here."*

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

*Built mission · ◽* — Sets the VEAF logging level (error / warning / info / debug / trace).

> 💬 *"Put the VEAF logs in debug."*

### Enable / disable password security {#password-security}

*Built mission · ◽* — Enables or disables the VEAF security flag (the password required for
protected commands).

> 💬 *"Turn off password security on this test mission."*

### Set a specific VEAF parameter {#veaf-parameter}

*Built mission · ◽* — Sets a given VEAF configuration parameter to a value.

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

New actions are coming (non-circular zones, a richer trigger editor, composite actions such as
"build me a full combat zone in one go"…). This page will be updated as they land. For the
technical detail, see the [developer doc](../developer/mission-editing-mcp.en.md).
