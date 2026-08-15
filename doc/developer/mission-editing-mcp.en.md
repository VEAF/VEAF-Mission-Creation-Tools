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

### `describe_units` (FEAT-MCP-MUTATION-ACTIONS lot)

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

### `set_unit_properties` (FEAT-MCP-MUTATION-ACTIONS lot)

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
  is normalised onto one turn (−90 is 270). **On an airborne aircraft** (plane/helicopter category, a
  route of 2+ waypoints, an in-air first waypoint) the action **warns**: DCS recomputes the heading
  from the route's first leg on save, so a set heading has a lifetime of one save
  (`FIX-MCP-EDITOR-ROUNDTRIP`, measured 2026-08-15). To point an airborne aircraft, set the route, not
  the heading. The heading is **still written** — the warning informs, it does not refuse; a parked
  aircraft or a ground unit does not trigger it.

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

### `set_group_properties` (FEAT-MCP-MUTATION-ACTIONS lot)

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

### `edit_route` (FEAT-MCP-MUTATION-ACTIONS lot)

Write. Two layers: the **route** (`add`, `insert`, `remove`, `reorder`, `set`) is mostly a list
operation on `route.points`; a waypoint's **tasks** (`add_task`, `clear_tasks`) are what makes a flight
do something.

**The invariant that makes this surgery rather than list editing.** `FIX-WAYPOINTS-ETA-LOCKED`
established that DCS **refuses to save** a mission whose route has no waypoint with a locked time
("Route has no waypoints with locked time!"), and that its own repair is to lock the first. Removing or
reordering can therefore produce a mission the editor rejects, far from the edit that caused it. Every
operation restores the invariant and **says so** when it had to.

**Units.** The mission table holds metres and metres per second; a mission maker speaks feet and knots.
As with `set_unit_properties`' `heading_deg`, the parameters carry their unit in their name
(`altitude_ft`, `speed_kt`) and the result reports both, so a caller never converts back.

**Tasks are a named set with validated signatures, not a free-form table** — a deliberate choice from
the ticket: a generic "write this task table" action is a foot-gun, because an agent produces a
plausible table, DCS ignores it silently, and the mission maker finds out an hour later. The escape
hatch starts **closed**.

Every signature was read out of a real mission, and three are traps:

- **`SetFrequency` takes hertz** (`31000000` for 31 MHz) while a *group's* frequency —
  `set_group_properties` — is in MHz. Two units for the same notion, in the same file. The action takes
  MHz and converts.
- **`EngageTargetsInZone` duplicates its target list** into a serialised `value` string
  (`"Air;Cruise missiles;"`) beside the `targetTypes` array; writing only the array leaves the mission
  carrying two versions of the same decision.
- **`SetFrequency` and `SwitchWaypoint` are not tasks** but *actions*, carried inside a `WrappedAction`
  envelope. Written as a bare task, DCS ignores it.

Two measured details the ticket did not mention: a waypoint's `type` and `action` are a **pair**
("Land" goes with "Landing"), and an added waypoint **inherits** its neighbour's altitude and speed —
otherwise it is written at altitude 0 and the flight dives into the ground to reach it — **unless
`altitude_ft`/`speed_kt` are given to `add`/`insert`**, which are then written (`FIX-MCP-EDITOR-
ROUNDTRIP`: they were accepted and then silently dropped, the inheritance overwriting the asked-for
value).

**Attack tasks must carry the full field set the editor keeps.** `FIX-MCP-EDITOR-ROUNDTRIP` measured
(2026-08-15) that a `Bombing` written without `weaponType` is **discarded by the editor on save** — a
strike package that drops nothing. `Bombing` and `AttackGroup` therefore now carry `weaponType`
(measured "Auto" default: 2032 for Bombing, 9659482112 for AttackGroup, overridable via `weapon_type`),
the `altitude`/`altitudeEnabled` and `direction`/`directionEnabled` pairs **present but disabled** by
default (enabled when the caller passes `altitude_ft`/`direction_deg`), and the
`expend`/`attackQty`/`groupAttack` set. `EngageTargetsInZone` also carries `noTargetTypes` (its
exclusion list, empty by default).

```json
{
  "miz_path": "path/to/mission.miz",
  "group_name": "Colt 1-1",
  "operation": "add_task",
  "index": 2,
  "task": "orbit",
  "task_params": {"pattern": "Race-Track", "altitude_ft": 20000, "speed_kt": 300}
}
```

### `edit_zone` (FEAT-MCP-MUTATION-ACTIONS lot)

Write. `add_trigger_zone` only creates **circular** zones and nothing edited one afterwards, so
adjusting a VEAF combat zone — which *is* a trigger zone — meant deleting it and building it again.

**Two measurements before any code**, as the ticket required:

- **A polygon zone's real shape**, read out of `veaf-demo-mission.miz` (`czBatumi`): `type: 2` plus a
  `verticies` list — DCS's own spelling, kept verbatim because correcting the typo would write a field
  DCS ignores — while `x`, `y` and `radius` **stay present**. A polygon is therefore not a circle with
  extra fields.
- **What the VEAF runtime handles.** `veafCombatZone.lua` branches on exactly two types: `0` →
  `mist.getUnitsInZones`, `2` → `mist.getUnitsInPolygon(triggerZone.verticies)`. There is **no
  `else`**, so a zone of any other type would contain no units, in silence — worse than not offering
  the shape. The action therefore writes only 0 and 2.

**David's call on the vertex count (2026-08-12)**: accept three or more, since "follow the ridge line"
is the real use case and mist handles an arbitrary polygon — but **warn** whenever the count is not
four, the DCS editor having no tool to draw or reshape a non-quad zone. The open question of whether it
*preserves* one was settled in game on 2026-08-15 (`FIX-MCP-EDITOR-ROUNDTRIP`): a 6-vertex zone came
back unchanged through a save, so the action **does not refuse** above four; the warning states a known
limitation (you cannot edit the shape by hand there), not an unknown risk.

Two refusals the ticket left open, decided here: a **link to a unit that does not exist** is refused
rather than warned (a zone linked to nothing simply never follows anything, silently), and a **name
collision** is refused (zones are referenced by name from `mission.yaml`).

```json
{
  "miz_path": "path/to/mission.miz",
  "zone_name": "czBatumi",
  "vertices": [
    {"x": -359753.0, "y": 614918.0},
    {"x": -355602.0, "y": 622688.0},
    {"x": -352849.0, "y": 617192.0},
    {"x": -358731.0, "y": 614282.0}
  ]
}
```

### `add_map_drawing` / `edit_map_drawing` (FEAT-MCP-MUTATION-ACTIONS lot)

Write. Nothing in VMCT touched F10 map drawings, so a briefing line, an ingress corridor or a no-fly
box was drawn by hand in the editor — **and vanished the moment the mission was rebuilt from its
folder**. That is the whole argument: a drawing an agent places is part of the recipe, a hand-drawn one
is not.

**The measurement that governs the design**, read out of this repository's fixtures:

> `points` are **relative to the drawing's `mapX`/`mapY` anchor**, the first one being `{0, 0}`.

A drawing written in absolute coordinates lands hundreds of kilometres away and **nothing errors** —
the same class of silent failure as confusing the mission table's `{x=north, y=east}` with a runtime
vec3 (see `docs/agents/dcs-coordinates.md`). So the actions take the absolute coordinates a caller
actually has and do the anchoring themselves. The payoff shows in `edit_map_drawing`: moving a drawing
is moving its anchor, and the shape follows for free.

**Six shapes ship because six shapes were measured**: `Line` (with `lineMode` `segment` or `segments`,
and `closed` for a shape that joins up), `Polygon` in `rect` mode (`width`/`height`/`angle`, **no**
points), `TextBox` (`text`/`font`/`fontSize`; the font is taken from a real drawing — one absent from DCS
renders as nothing), and — added 2026-08-15 from `bridge-Syria-editeur.miz` (ticket 10) — `Polygon`
in `circle` mode (`radius`, no points or angle), `oval` (`r1`/`r2`/`angle`), and `free` (`points`
relative to the anchor like a `Line`, a free-form filled area, three or more points).

`arrow` and `icon` were measured but stay **refused, with a reason** rather than a guess: an `arrow`
stores a computed 8-point outline **beside** its `length`/`angle`, so writing the parameters alone
needs an in-game round-trip to learn whether DCS recomputes the outline (its own ticket); an `icon`
needs a `file` from the editor's icon set (e.g. `P91000007.png`), which nothing here enumerates, and an
unvalidated name renders as nothing. `chevron` was removed — it is not a DCS editor tool.

The **layer** is a first-class parameter, never a default: a drawing on the wrong layer is invisible to
the pilots who need it and visible to the ones who should not see it.

```json
{
  "miz_path": "path/to/mission.miz",
  "layer": "Blue",
  "shape": "line",
  "name": "FSCL",
  "points": [{"x": -300000.0, "y": 600000.0}, {"x": -290000.0, "y": 610000.0}]
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

### `add_player_slot` (FIX-SCRATCH-MISSION-PLAYABLE lot)

Write. Creates a **player slot** — a flyable aircraft group — which `add_group` (ground) cannot, and
without which a from-scratch mission is not flyable at all. Timestamped backup before writing. Targets
a **folder** (durable) or a `.miz` (transient).

```json
{
  "target": "path/to/mission-folder",
  "coalition": "blue",
  "country_id": 2,
  "country_name": "USA",
  "name": "Player Viper",
  "unit_type": "F-16C_50",
  "position": {"x": 1000.0, "y": 2000.0},
  "start": "ground-cold",
  "parking": "43",
  "parking_id": "16",
  "airdrome_id": 24
}
```

- **`skill: Client`** — the multiplayer-slot skill, playable in single-player too. This action does
  **not** change an existing unit's skill: `set_unit_properties` refuses `Client`/`Player` and this is
  not a back door to it.
- **`dynSpawnTemplate` is set to `false`.** That flag marks a dynamic-spawn template, which needs an
  airfield configured for it; left on (as on a copy of a template) the slot sits in the file but does
  **not** appear in the slot list — the defect found in game on 2026-08-14.
- `start` — `"air"` (position + `altitude_ft` + `speed_kt` + `heading_deg`, no runtime data),
  `"ground-cold"` or `"ground-hot"`. A ground start **requires** `parking`, `parking_id` and
  `airdrome_id`; without them it is **refused** (the message names the data captured by
  `FEAT-MCP-MUTATION-ACTIONS` ticket 09), never guessed. The first waypoint's `type`/`action` pair is
  written per mode.
- **`frequency_mhz`** is written (group radio on) rather than inherited from a `communication: false`.
- Assigns the country to its side in `coalitions` (see `add_group`), so the mission stays loadable.

### `add_air_group` (FEAT-MCP-MUTATION-ACTIONS lot, ticket 09)

Write. Puts a **flight** (one or more aircraft) on the ramp, **resolving the stands itself** from an
airfield **name** — the *"a two-ship of F-16s at Incirlik"* case that `add_player_slot` (one aircraft,
caller supplies the spot) does not cover. Timestamped backup before writing. Targets a folder (durable)
or a `.miz` (transient).

```json
{
  "target": "path/to/mission-folder",
  "coalition": "blue", "country_id": 2, "country_name": "USA",
  "name": "Viper", "unit_type": "F-16C_50", "count": 2,
  "start": "parking-cold", "airfield": "Kobuleti"
}
```

- **Stand resolution.** The airfield name is resolved to an id (`veaf_libs.dcs_airdromes`), then to
  free stands via the slimmed bundled capture (`veaf_libs.dcs_parking`, generated by
  `veaf-build update-dcs-data --parking`). It takes `count` free stands, **nearest to the runway
  first**, and seats each aircraft at the stand's **exact position**.
- **`parking_id` = `parking`.** Settled in game 2026-08-15: `parking` is the capture's `Term_Index`,
  the aircraft seats from the exact position, and the editor's own `parking_id` — absent from the
  capture — is **not** load-bearing, so it is written equal to `parking`.
- **Only terminal types 104 and 68** are offered as parking (measured: real Caucasus missions park
  aircraft only on those). An airfield with none is **refused** rather than seating an aircraft on a
  runway threshold.
- **Collision refused.** A stand already occupied in the mission (an aircraft group whose first
  waypoint targets this airdrome and one of whose units declares that stand) is refused **naming** the
  group that holds it; auto-selection **skips** occupied stands.
- **Starts.** `parking-cold` / `parking-hot` (need `airfield`), `runway` (needs `airfield`, anchored on
  the field, no stand consumed), `air` (needs `position`). The first waypoint's `type`/`action` pair
  and its `ETA_locked` are written for you.
- **`skill`** defaults to an AI level (`High`) — a ramp flight is AI unless you ask for
  `Client`/`Player`. `parking` accepts an explicit stand list that overrides selection.
- An uncaptured theatre, an unknown airfield, or too few free stands are refused naming the cause.
  Assigns the country to its side in `coalitions`.

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

- A generic IF/THEN trigger editor (arbitrary DCS conditions/actions) — wave 2 is limited to
  startup script-loading / Lua-execution triggers.
- A per-module schema validator for `set_mission_module` (wave 4 stays generic).
- CAS composites (pure runtime, no authoring) and end-to-end generation from
  a prompt (the NL-MISSION-GEN goal beyond this lot).

See `.backlog/archive/FEAT-MCP-MISSION-EDITOR.md` for details.
