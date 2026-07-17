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

Before naming a group, picking a unit type, or configuring a module, call the read-only oracle
actions. They read VEAF's canonical, always-current data — your training memory of DCS types or
VEAF conventions may be stale or wrong.

- `list_unit_types` — real DCS unit type ids (filter by category / name).
- `list_shortcuts` — VEAF spawn aliases (`shilka`, `sa8`, composite SAM/convoy groups).
- `describe_naming_conventions` — the reserved naming patterns (below).
- `describe_module` — is a module real? its doc page? enabled in this mission?

For an action's exact parameters, call `describe_action(name)`.

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
  `#spawndelay=` → tune combat-zone spawn behaviour.
- QRA deploy entries starting with `[` or `-` are read as commands, not group names.

## Combat zone vs QRA — two different group models

**Combat zone** — groups are found by **geometry** (inside the trigger zone), coalition is
ignored (VEAF despawns then respawns them), and membership also keys off the **zone-name prefix**.
So: create the trigger zone, then create groups named `<ZoneName>-...` placed inside it. To have
the zone spawn VEAF assets rather than hand-placed units, use a fake unit carrying
`#command="-<alias> ..."` (an alias from `list_shortcuts`) — set it as that unit's **`name`** (the
`units` entry takes an optional `name`; the runtime reads `#command`/`#spawn*` off the unit name).
**Prefer this `#command` fake-unit** for combat-zone content over hand-placing literal units.

**QRA** — interceptor groups are referenced **by exact name**, coalition **matters**, and they
**must be Late Activation** (VEAF scrambles them). So: create the trigger zone, create the
late-activation interceptor group with a coherent name, set its coalition, and list that exact
name in the QRA definition.

## Worked examples

- *"Create a CZ with two enemy armor groups."* → Create trigger zone (e.g. `CZ-North`). Add two
  groups named `CZ-North-armor-1` / `CZ-North-armor-2` inside it — either with concrete armor
  unit types from `list_unit_types`, or as fake-unit groups carrying `#command="-armor ..."` using
  an alias from `list_shortcuts`. Add the `COMBATZONE` block referencing `CZ-North`.
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

## Finish: validate, then build

When the mission is authored, close the loop without leaving the tools: run `validate_mission` on
the folder first (fix any error it reports), then `build_mission` to produce the playable `.miz`.
Surface build errors to the user rather than claiming success. This completes the empty-folder →
scaffold → edit → validate → build → play flow.

## Report back clearly

Tell the user which world you edited, the names/types you chose and why, and surface any
convention warning the actions returned so they can veto before you proceed with irreversible or
large changes.
