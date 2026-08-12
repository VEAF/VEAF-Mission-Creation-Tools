# `veaf-mission-mcp` — LLM-assisted mission-editing MCP server

> **Audience**: developers evolving the mission-editing MCP server, or wiring an MCP client
> (Claude Code, an agent) to it.
>
> 🇫🇷 [`mission-editing-mcp.md`](mission-editing-mcp.md).
>
> 🎯 Mission-Maker side (plain-language catalogue):
> [`mission-maker/AI_ASSISTANT_CATALOG.en.md`](../mission-maker/AI_ASSISTANT_CATALOG.en.md).

## Why this server

First phase of **NL-MISSION-GEN** (see `ROADMAP.md` §4): let an LLM edit a DCS mission on a
Mission Maker's behalf — and, eventually, generate one end-to-end from a detailed prompt. See
[ADR 0014](https://github.com/VEAF/VEAF-Mission-Creation-Tools/blob/develop/docs/adr/0014-mission-editor-mcp-editor-parity-layer.md) for the architecture decision,
and `CONTEXT.md` (section "LLM-assisted mission editing") for the vocabulary.

Two action families, deliberately kept apart:

- **Editor-parity action** — mutates the mission's raw `.miz` Lua tables directly, exactly the
  way a Mission Maker would by hand in the DCS Mission Editor (add a group, a trigger, a zone).
  Never goes through `mission.yaml`. This is the entire scope of this server in v1.
- **VMCT action** — goes through the existing declarative `mission.yaml` pipeline
  (`inject_presets`, `aircraft_groups`...). As of **wave 4** the server exposes a first brick of
  this family: editing the source `mission.yaml` (see below), alongside the usual CLI/config path.

## Running the server locally

```bash
poetry install
poetry run veaf-mission-mcp   # in dev
# or, from the shipped binary (what the Claude plugin invokes):
veaf-tools mcp
```

Starts an MCP server over `stdio` (the `mcp` SDK's default transport). No configuration: every
action receives the `.miz` path to edit as a parameter. The `veaf-tools mcp` subcommand embeds the
server in the already-shipped `veaf-tools` binary (no separate binary to build) — this is what the
Claude plugin declares in its `.mcp.json`.

## Action catalog (v1)

The server does **not** expose one MCP tool per business action. It exposes a fixed discovery
surface, mirroring the `dcs-bridge` MCP tool (a bridge to a running mission):

| MCP tool | Role |
|----------|------|
| `capabilities()` | Server identity (name, version). |
| `list_catalog()` | List registered actions (`name`, `description`, `parameters_schema`). |
| `describe_action(name)` | Detail one action's parameter JSON Schema. |
| `run_action(name, params)` | Run a registered action. |

Concrete actions are registered by `veaf_mission_mcp.actions.register_default_actions`
(`src/python/veaf-tools/veaf_mission_mcp/actions.py`).

### `describe_mission`

Read-only. Lists the groups (name, coalition, country, category) and trigger zones (name,
position, radius) already present in the `.miz` — so the caller can check current state before
writing, the same way a human would check the editor's outliner before adding something. Reuses
the existing pure-Python parser (`mission_tools.miz_tools.read_miz`) — no new parsing.

```json
{"miz_path": "path/to/mission.miz"}
```

### `describe_units`

Read-only. The level of detail `describe_mission` does not give: each group's **units** (type,
`skill`, livery, callsign, side number, position, heading, altitude, fuel, counters/gun), their
**loadout**, and the group's **route** with the tasks at each waypoint.

Three shape decisions, each for a reason measured on a real mission (Foothold Caucasus 4.4.1, 357
armed units):

- **`pylons` is keyed by pylon number, never positional.** DCS numbers stations and the numbers are
  **not contiguous**: a real FA-18C carries pylons 1, 4, 5, 6 and 9. In that mission 170 of 357
  units have a gapped layout, and the Lua parser hands those back as a `dict` while it flattens the
  contiguous ones into a `list`. A reader treating pylons as an ordered list would therefore be
  right about half the time and silently wrong the rest — which is how a future setter comes to hang
  a weapon on the wrong station.
- **The editor's automatic tasks are flagged and stripped.** A waypoint task is a `ComboTask` mixing
  the task the author added with the options the editor writes by itself (ROE, radar usage,
  formation), all marked `auto = true`: 1093 automatic entries against 189 authored ones in that
  mission. Both are reported — hiding them would misrepresent the mission — but only authored tasks
  carry their `params`.
- **A cap the caller is told about.** The whole mission is 1.9 MB of JSON and a single 62-waypoint
  group is 18 KB. Hence the filters (`group_name` by fragment, `coalition`, `category`), the default
  limit of 50 groups with `truncated`/`matched` in the answer, and `include_route: false`, which
  **omits the key** rather than returning an empty list ("not asked for" is not "this group has no
  route").

Booleans come back as booleans: DCS **omits** a key that is false, and a caller reading `null` cannot
tell "off" from "the reader did not look".

```json
{"miz_path": "path/to/mission.miz", "group_name": "Colt", "include_route": false}
```

### `set_unit_properties`

Write. The **first** action that changes an object the mission already contains: every `set_*`
shipped before it acts on *configuration* (modules, security, logging, an airbase's coalition).
Timestamped backup before the write, like its siblings.

It addresses the unit by **exact** group name and **exact** unit name — not by fragment, unlike
`describe_units`: a fragment makes the edit land on whichever group matched first, which is not
recoverable. A name that misses lists what exists, so a caller can retry without re-reading the
whole mission.

Three shapes were **measured** on real missions rather than inferred, and two contradict the ticket
that asked for them:

- **`skill` has seven values, not four.** `Average`, `Good`, `High`, `Excellent` and `Random` are AI
  levels; `Client` and `Player` are **human slots**. Crossing that line one way adds a place to the
  multiplayer list, the other way removes one — the bug `FIX-TEMPLATE-SLOTS-VISIBLE` was opened for.
  Both directions are therefore refused naming the reason, instead of being honoured as a skill
  setting.
- **An aircraft's callsign is not a plain field.** It is a table
  `{1: family, 2: flight, 3: number, name: "Colt11"}` where `name` is the family's word followed by
  the two indices (`{1:1, 2:1, 3:2}` reads `Enfield12`). Writing `name` alone desynchronises what DCS
  says on the radio from what the editor shows, so the action edits the indices and **rebuilds**
  `name` from the prefix already there. Changing the *family* requires DCS's family→word table, which
  this repository does not ship: that is refused unless the caller supplies the resulting `name`.
- **`heading` is radians** while a mission maker speaks degrees — the trap `resolve_coordinates`
  hides elsewhere. The parameter is named `heading_deg` so the unit cannot be mistaken, and the value
  is normalised onto one turn (−90 is 270).

What the action does **not** validate, for want of the data to do it: a weapon's CLSID against the
airframe carrying it, and a livery against the skins installed. DCS silently drops an impossible
weapon and silently shows the default skin, so both limits are returned as `warnings` rather than
implied by their absence.

`pylons` is keyed **by station number**, never positional, for the reason measured in
`describe_units`. No `pylons` means "leave the loadout alone"; `{}` in `replace` mode means "carry
nothing"; in `merge` mode an empty CLSID empties that station.

```json
{
  "miz_path": "path/to/mission.miz",
  "group_name": "Colt 1-1",
  "unit_name": "Colt 1-1-1",
  "skill": "Excellent",
  "heading_deg": 270,
  "pylons": {"4": ""},
  "pylons_mode": "merge"
}
```

The result carries `changed`, giving each touched field its **previous** value and the new one: a
caller that cannot say what it replaced cannot undo it.

### `set_group_properties`

Write. Acts on the whole group: move, rename, frequency, modulation, and the three booleans
(`lateActivation`, `hidden`, `uncontrolled`). Timestamped backup before the write.

**The move carries the whole design of this module, and it is not "write x and y".** A group is units
**in a formation** plus possibly a **route**. The translation therefore applies to *every* unit,
*every* waypoint **and** the group's own `x`/`y` anchor, by a single vector: otherwise the formation
shears, or the route detaches from the units it belongs to — and neither shows before somebody flies
the mission. The shear test (move the units, leave the waypoints) is written to fail on any
implementation that forgets it, and that was verified by deliberately breaking the translation.

The vector comes from the **geodesic offset** of `FEAT-GEO-PLACEMENT`
([ADR 0015](https://github.com/VEAF/VEAF-Mission-Creation-Tools/blob/develop/docs/adr/0015-coordinate-projection-port.md)), not from adding metres to `x`: a DCS theatre is the
real world projected, so "5 km east" is a lat/lon question. A theatre with no projection makes the
bearing + distance form **refuse**, pointing at `move_to` instead.

`frequency_mhz` is checked against the airframe's `HumanRadio`, reusing the presets injector's
validator rather than re-deriving it: `FIX-PRIMARY-FREQ-HUMANRADIO` established that the DCS editor
**refuses to save** a mission whose primary frequency falls outside that range. **Every** unit type in
the group is checked, not just the first — a mixed group would otherwise pass on its first member and
be refused by the editor because of another.

The rename runs the reserved-convention check (`validate_group_name`) and **refuses by default**: a
group renamed onto a combat zone's trigger-zone name is *despawned at start*, silently. Renaming
*into* a convention is a legitimate intent, hence `acknowledge_conventions` — what matters is that it
be deliberate. **Unit** names never follow: they carry markers of their own (`#command=`,
`#veafInterpreter[...]`) that a cascade would rewrite blind.

What the action **cannot** do, measured rather than overlooked: check the surface at the destination.
There is no terrain data on the Python side — `land.getSurfaceType` is a runtime API and only its
schema ships here — which is exactly why `FEAT-SCENERY-AWARE-SPAWN` solved the problem at runtime. So
a move **warns** that it could not look, instead of validating and lying.

```json
{
  "miz_path": "path/to/mission.miz",
  "group_name": "Red SAM Battery",
  "move_bearing": 90,
  "move_distance_m": 5000,
  "late_activation": true
}
```

### `add_group`

Write. Inserts a ground/vehicle group into the source `.miz`, **in place**, with a systematic
timestamped backup before the write (`mission_tools.miz_backup.backup_before_write`, e.g.
`mission.20260712-143012.miz`). A same-second collision is disambiguated (`-2`, `-3`, ...), never
silently overwritten.

```json
{
  "miz_path": "path/to/mission.miz",
  "coalition": "red",
  "country_id": 0,
  "country_name": "Russia",
  "category": "vehicle",
  "name": "Red Armor Section",
  "position": {"x": 1000.0, "y": 2000.0},
  "units": [{"type": "T-72B", "count": 2}],
  "route": [{"x": 1000.0, "y": 2000.0}, {"x": 1200.0, "y": 2000.0}],
  "patrol": true
}
```

- `units` — the server does **no** unit-catalog curation: concrete DCS types (`T-72B`,
  `BTR-80`...) are the calling LLM's decision, not this action's. Each unit may carry an explicit
  `name` (else auto-named). That is **where** a combat-zone marker goes (the runtime reads them off
  the **unit name**): `#command`, `#spawngroup`, `#spawnradius`, `#spawncount`, `#spawnchance`,
  `#spawndelay`. The classic idiom is a "fake-unit" group whose name is `#command="-armor ..."` (a
  `list_shortcuts` alias): on zone activation it spawns the described group. E.g. `units:
  [{"type": "Soldier M4", "name": "#command=\"-armor, spawnRadius 300\""}]`.
- `route` — optional; defaults to a single stationary point at `position`. With `patrol: true`
  (and at least 2 points), the last point loops back to the first via a `GoToWaypoint` task — a
  classic DCS ground-unit patrol.
- **No deduplication**: calling this twice with the same parameters creates two distinct groups,
  exactly like two clicks in the DCS Mission Editor.
- `groupId`/`unitId`s are always fresh (`mission_tools.group_insertion.max_ids`), even on a
  mission with gaps in its existing id ranges.

**Naming intents (wave 6).** The caller expresses *intent* and `add_group` produces a
convention-correct name itself (`veaf_mission_mcp.group_naming.resolve_group_name`):

- `for_combat_zone: <zone>` — prefix the name with the trigger-zone name (combat-zone membership
  rule), idempotent and case-insensitive;
- `late_activation: true` — set the DCS `lateActivation` flag (QRA interceptors, CAP templates);
- `as_spawn_template: true` — `veafSpawn-` prefix (spawnable-aircraft template).

`add_group` also returns a `warnings` field (see `validate_group_name`): it **still writes**, but
flags any convention collision for the caller to relay.

### `validate_group_name` (wave 6)

Read-only. Checks a proposed name against the reserved patterns (`veafSpawn-`/`OnDemand-`/
`VEAF-placeholder-` prefixes, `#veafInterpreter[...]`/`#command=` markers, QRA deploy syntax, fixed
CAS names) and, with `miz_path`, the **combat-zone capture trap** (name starting with an existing
trigger-zone). `expected_combat_zone` suppresses the warning for the intended zone. Shares the
`veaf_mission_mcp.group_naming` module with `add_group`.

```json
{"name": "combatZone_North-tanks", "miz_path": "path/to/mission.miz"}
```

### `add_trigger_zone` (wave 2)

Write. Inserts a named **circular** trigger zone into `mission.triggers.zones`, with a fresh
`zoneId`, in place and backed up first. This is the zone a VEAF combat zone references: combined
with `add_group`, it lets you lay down a full combat zone (the trigger zone `group_validation`
requires + the groups inside it). No deduplication.

```json
{
  "miz_path": "path/to/mission.miz",
  "name": "combatZone_North",
  "position": {"x": 1000.0, "y": 2000.0},
  "radius": 3000,
  "hidden": false
}
```

### `add_startup_script_trigger` (wave 2)

Write. Adds a **"mission start"** trigger that runs a script — for outfitting a **vanilla or
CTLD** mission with scripting without the DCS editor's Triggers tab. Generalizes
`inject_dcs_bridge_trigger` and the VEAF static/dynamic loading mechanism
([ADR 0004](https://github.com/VEAF/VEAF-Mission-Creation-Tools/blob/develop/docs/adr/0004-dynamic-script-loading.md)). Unlike that helper (which inserts at index 1
and renumbers everything), this **appends** at the next free index — no existing trigger is
renumbered. Three modes:

- **`inline`** — run supplied Lua (`inline_lua`) via `a_do_script`.
- **`file_static`** — embed a `.lua` file (`source_path`) into the `.miz`
  (`l10n/DEFAULT/<name>.lua` + `mapResource` entry) and load it via `a_do_script_file`.
- **`file_dynamic`** — load a `.lua` from a runtime disk path (`runtime_path`) via `loadfile`,
  nothing embedded.

```json
{
  "miz_path": "path/to/mission.miz",
  "mode": "file_static",
  "comment": "load my script",
  "source_path": "C:/scripts/myscript.lua"
}
```

Timestamped backup before the write; no deduplication.

## Editing embedded Lua files (wave 3)

Third action family: edit the **text** of the `.lua` files embedded in the `.miz`
(`l10n/DEFAULT/**/*.lua`), **without a rebuild** — neither the raw `mission.lua` tables
(editor-parity) nor the `mission.yaml` pipeline (VMCT action). Shared brick:
`mission_tools.rewrite_miz_members` copies the archive through verbatim and swaps only the
targeted members (no Lua-table re-serialization). Timestamped backup before each write.

### `replace_in_mission_files` — generic search-replace

Text or regex replacement, **restricted to `l10n/DEFAULT/**/*.lua`** (never `mission`/
`options` or binaries). `files` is a glob matched against each `.lua`'s path relative to
`l10n/DEFAULT/`.

```json
{
  "miz_path": "path/to/mission.miz",
  "search": "debug",
  "replace": "info",
  "files": "veaf-*.lua",
  "regex": false
}
```

Returns `{files_changed, total_replacements}`.

### VMCT settings (`veaf-config.lua`)

Semantic actions editing `l10n/DEFAULT/veaf-config.lua` (the build-generated VEAF config).
Each **replaces the line if present, else inserts** it at the top (before the modules
initialise):

- `set_log_level(level)` → `veaf.ForcedLogLevel = "<level>"` (error/warning/info/debug/trace).
- `set_module_enabled(module_id, enabled)` → `veaf.setConfig("<MOD>", "enable", <bool>)`.
- `set_security_disabled(disabled)` → `veaf.SecurityDisabled = <bool>`.
- `set_veaf_config(key, value)` → `veaf.config.<key> = <Lua scalar>`.

### Airfield coalition

- `set_airbase_coalition(folder_path, name, coalition)` — durably assign a DCS airfield to a
  coalition, in a **mission folder**.

> ⚠️ An airfield's coalition lives in `warehouses.airports[<id>].coalition`, **not** in
> `mission.coalition`. Placing a unit near a base therefore never turns the base itself — this action
> is what does. It resolves the airfield name to an id through the mission's theatre, sets the
> coalition, and **turns on the base's Dynamic Spawn slots** (the build then stocks them). Backed up
> first, like the other editing actions.

> Password **hashes** (`veafSecurity.password_L9[...]` / `password_MM[...]`) — a multi-line
> case — are not covered yet: only the `SecurityDisabled` flag is.

## VMCT actions on `mission.yaml` (wave 4)

The fourth family — the first genuinely **VMCT** one: edit the **declarative source**
`mission.yaml` (what the build consumes to *generate* the `.miz`), rather than patching a built
artifact. Shared brick: `mission_tools.mission_yaml_editor` (`ruamel.yaml` round-trip mode)
which **preserves comments, key order and formatting** — essential for a heavily-commented source
file edited by hand and kept in lockstep with the shipped default. Timestamped backup before
every write.

### `describe_mission_config`

Read-only. Lists the `modules:` block and, per module, its state: `mandatory` (bare key),
`scalar` (boolean `MODULE: true/false`) or `extended` (nested config block such as
`COMBATZONE`/`CTLD`). The VMCT counterpart of `describe_mission`.

```json
{"mission_yaml_path": "path/to/mission.yaml"}
```

### `set_mission_module`

Write. Enable/disable a module or set its extended config block, comments preserved. `value` is
either a boolean (scalar form) or an object (extended block). The key is **replaced if present,
inserted otherwise**. No deduplication.

```json
{
  "mission_yaml_path": "path/to/mission.yaml",
  "module_id": "COMBATZONE",
  "value": {"enabled": true, "combat_zones": [{"type": "zone", "zone_name": "CZ-Alpha"}]}
}
```

> Deliberately **generic** (toggle + mapping setter) — no per-module schema validator: the shape
> of the config block passed stays the caller's (LLM's) responsibility, like unit types for
> `add_group`.

### Recipe / built parity (wave 7)

Every setting editable on the built `veaf-config.lua` (wave 3) gets its **source** `mission.yaml`
counterpart, so both targets are reachable. Separate actions (consistent with `set_mission_module`),
on the `mission_yaml_editor` brick:

| Setting | Recipe (`mission.yaml`) | Built (`veaf-config.lua`) |
|---------|-------------------------|---------------------------|
| Log level | `set_mission_log_level` → `global_log_level` | `set_log_level` |
| Security | `set_mission_security` → `security:` block (**+ password hashes**) | `set_security_disabled` |
| Arbitrary setting | `set_mission_setting` → `settings.<key>` | `set_veaf_config` → `veaf.config.<key>` |
| Module enable | `set_mission_module` (wave 4) | `set_module_enabled` |

## Domain-knowledge oracle (wave 5)

The actions above are the LLM's **hands** (writes) and **eyes** (`describe_*`). Wave 5 gives it a
**brain**: **read-only** actions exposing the DCS + VEAF knowledge needed to author correctly. All
read from the **canonical sources** the build already uses, so they **cannot drift**:

- generated DCS data (`update-dcs-data` → `veaf_libs/data/dcsUnits.yaml`, published on the VEAF
  GitHub);
- VEAF aliases (`veaf_libs/data/veaf-units.yaml`);
- vendored artifacts (`vendored.yaml`, `check-vendored`);
- upstream datamining repos (provenance).

Implementation: `veaf_mission_mcp/oracle.py`. The "prose / how to reason" half lives in the
`veaf-mission-authoring` Claude skill (`plugin/skills/veaf-mission-authoring/SKILL.md`, bundled by
`bfr-claude-plugins`) — the plugin = MCP hands + skill brain.

### `list_unit_types`

Read-only. DCS unit types from the generated database, filterable by `category` and/or
`name_contains`, so the LLM can pick concrete types.

```json
{"category": "Plane", "name_contains": "su-27"}
```

### `list_shortcuts`

Read-only. The VEAF alias vocabulary (`shilka`, `sa8`…) — unit aliases (`_spawn unit <alias>`)
and composite group aliases (`_spawn group <alias>`: SAM sites, convoys). Filterable by
`name_contains`.

### `describe_naming_conventions`

Read-only. The **8 reserved naming patterns** (combat-zone membership, `veafSpawn-`/`OnDemand-`
prefixes, `#veafInterpreter[…]`/`#command=` markers, QRA deploy entries, fixed CAS names…), each
with its rule and the consuming module. Check a proposed name against these before `add_group`.

### `describe_module`

Read-only. A **locator** (not a schema validator): confirms a VEAF module exists (via the
canonical `lua_module_scanner` list), returns its doc page, and — when `mission_yaml_path` is
given — its enabled state. Each module's config keys live in its doc page.

```json
{"module_id": "QRA", "mission_yaml_path": "path/to/mission.yaml"}
```

## Composites — one pass, both worlds (wave 8)

High-level actions that lay down a **complete feature** in one call, on a **mission folder**: they
edit the **durable source** (the exploded `src/mission/` — zones/groups — via `mission_folder`,
**and** `mission.yaml`), without triggering a build (a later `veaf-tools mission build` produces the
`.miz`). They orchestrate the wave-1..7 primitives (`insert_trigger_zone`,
`insert_group_into_content`, the `mission.yaml` editor). Implementation: `veaf_mission_mcp/composites.py`.

### `create_combat_zone`

Trigger zone + groups placed inside (names auto-prefixed with the zone → captured at runtime,
coalition-agnostic) + an appended `modules.COMBATZONE.combat_zones[]` yaml block.

### `create_qra`

Trigger zone + **Late-Activation** interceptors (coalition-significant) + a
`modules.QRA.definitions[]` entry referencing the groups **by exact name** (`simple_groups`).
Coalition is lower-cased for placement, upper-cased in the YAML definition.

### `create_cap_mission`

A **Late-Activation** template group named `OnDemand-<name>` + a `cap_missions[]` entry
(`group_name: <name>`, un-prefixed — the build resolves it to the `OnDemand-` group).

## Scaffolding a mission folder (wave 9)

Every action above assumes a mission folder **already exists**. Wave 9 provides the upstream piece:
create that folder from an **empty** one, driving the real VEAF binaries the way a Mission Maker
would on first install.

### `scaffold_mission`

Write. On an **empty** target folder:

1. Resolve the current OS's updater asset (`veaf-tools-updater.exe` on Windows,
   `veaf-tools-updater-<os>-<arch>` on Unix) and download it from the **stable release-download
   URL** (`…/releases/download/<tag>/<asset>` — no GitHub API, no rate limit).
2. Run the updater in the folder (it fetches and installs the VEAF tools + `published/`).
3. Run `veaf-tools mission prepare --template <tier> --force` in the folder.

```json
{
  "target_folder": "path/to/empty-folder",
  "template": "standard",
  "github_token": "…",
  "tag": "published-latest"
}
```

- **Refuses a non-empty folder** — scaffolding only initializes an empty one.
- `template` — `minimal` / `standard` / `full`. The interactive `custom` tier is **not** supported
  here (its TUI picker has no TTY under a subprocess); the calling LLM must **ask the Mission Maker
  which template** and pass it as a parameter.
- `theatre` — optional; relayed to `prepare --theatre` to lay down a **synthetic blank mission**
  for that DCS map into `src/mission/` (no DCS round-trip). Omitted → `src/mission/` stays empty
  (the maker supplies their own `.miz`).
- `github_token` — optional, relayed to the updater (`--token`) to bypass the API rate limit.
- A non-zero exit from the updater or `prepare`, or a missing `veaf-tools`/`published/` after the
  updater, surfaces as an explicit error.

This is **step 0** of a from-scratch mission, before the wave-8 composites.

## Map & coordinates (wave 10)

Placement actions take **DCS local coordinates** (`x`/`y`, metres in the theatre's own projection);
a Mission Maker thinks in lat/long off a map. Wave 10 gives the LLM map awareness and conversion,
design-time (no running DCS).

Foundation: `veaf_libs.coordinates` — pure-Python Transverse Mercator WGS84 (no `pyproj`), whose
per-theatre constants come from the vendored `data/dcs-maps.yaml` (MIT export of
[VEAF/dcs-maps](https://github.com/VEAF/dcs-maps), see [ADR 0015](https://github.com/VEAF/VEAF-Mission-Creation-Tools/blob/develop/docs/adr/0015-coordinate-projection-port.md))
— **all DCS theatres** (Caucasus, Syria, PersianGulf, Marianas, Normandy, Nevada, SinaiMap,
GermanyCW, Kola, TheChannel, Falklands, Afghanistan, Iraq). Since DCS theatres **are the real world
projected**, this bridges `DCS x/y ↔ real-world lat/lon`.

### `describe_map`

Read-only. From a `.miz` **or** a mission folder: returns the **theatre**, per-coalition
**bullseyes**, and existing zones/groups as **reference points** — so the LLM can orient without DCS.

```json
{"mission_path": "path/to/mission.miz-or-folder"}
```

### `resolve_coordinates`

Utility. Converts a position between `{x, y}` (DCS local) and `{lat, lon}` (decimal degrees) for the
mission's theatre (read from the mission — the caller never supplies projection parameters).

```json
{"mission_path": "…", "position": {"lat": 42.18, "lon": 41.68}}
```

### `geocode`

Read-only (`FEAT-GEO-PLACEMENT` lot). Resolves a **real place name** to DCS coordinates for the
mission's theatre — DCS theatres being the real world projected. **Pluggable** geocoder: OpenStreetMap
Nominatim by default (free, no key; © OpenStreetMap attribution required), Google Maps when
`GOOGLE_MAPS_API_KEY` is set. Optional `bearing`+`distance_km` ("10 km north of X"). Returns
`{found, display_name, latlon, xy, in_theatre_bounds, warnings}` — approximate, confirm visually;
named places work, vague terrain does not.

```json
{"mission_path": "…", "query": "Kobuleti", "bearing": 0, "distance_km": 10}
```

## Build & validate (wave 11)

The earlier actions create, orient and edit a **mission folder**, but nothing produced the playable
`.miz` — the maker still ran `veaf-tools mission build` by hand. Wave 11 makes the server **self-sufficient
end-to-end**: empty folder → scaffold → theatre blank → composites/placement → **validate → build →
playable `.miz`**, without leaving the assistant.

### `validate_mission`

Read-only. Lints a **folder** before build: reuses `veaf_libs.mission_validator` in-process. Returns
`{ok, errors[], warnings[]}` (`ok = false` on any error). Run it before `build_mission`.

```json
{"folder_path": "path/to/mission-folder"}
```

### `build_mission`

Write. Builds the folder into a playable `.miz` by driving **`veaf-tools mission build`** in the folder (the
binary `scaffold_mission` installed, or `veaf-tools` on PATH). The build pipeline lives in the CLI
command and is re-run as-is. A build failure is surfaced (`RuntimeError`).

```json
{"folder_path": "path/to/mission-folder"}
```

## Next waves (out of scope)

- Non-circular (quad/polygon) trigger zones — wave 2 covers circular zones only.
- A generic SI/ALORS trigger editor (arbitrary DCS conditions/actions) — wave 2 is limited to
  startup script-loading / Lua-execution triggers.
- A per-module schema validator for `set_mission_module` (wave 4 stays generic).
- CAS composites (pure runtime, no authoring), non-circular zones, and end-to-end generation from
  a prompt (the NL-MISSION-GEN goal beyond this lot).

See `.backlog/FEAT-MCP-MISSION-EDITOR/PRD.md` for details.
