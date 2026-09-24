"""Composite one-pass builders (wave 8) — lay down a full VEAF feature across both worlds.

Each builder orchestrates the wave-1..7 primitives on a mission **folder** (David's model): it
edits the durable source — the exploded ``src/mission/`` (trigger zones + groups) and
``mission.yaml`` (module config) — so a later ``veaf-tools build`` produces the ``.miz``. No build
is triggered here. See ``.backlog/FEAT-MCP-MISSION-EDITOR/PRD.md`` (wave 8).
"""

import copy
from pathlib import Path
from typing import Any

import yaml
from mission_tools.mission_yaml_editor import append_to_sequence, load_yaml, save_yaml
from veaf_libs.mission_table import indexed
from veaf_libs.shipped_defaults import shipped_default_file

from veaf_mission_mcp.add_air_group import insert_air_group_into_content
from veaf_mission_mcp.add_group import insert_group_into_content
from veaf_mission_mcp.add_trigger_zone import insert_trigger_zone
from veaf_mission_mcp.group_naming import resolve_group_name, validate_group_name
from veaf_mission_mcp.mission_folder import load_folder_mission, mission_yaml_path, save_folder_mission


def create_combat_zone(
    folder_path: Path,
    *,
    zone_name: str,
    position: dict[str, float],
    radius: float,
    groups: list[dict[str, Any]],
    coalition: str,
    country_id: int,
    country_name: str,
    category: str = "vehicle",
    combat_zone: dict[str, Any] | None = None,
) -> dict[str, Any]:
    """Create a complete VEAF combat zone in a mission folder, in one pass, both worlds.

    On the exploded `.miz` side (`src/mission/`): a circular trigger zone named `zone_name`, plus
    the given `groups` placed inside it — each group's name prefixed with `zone_name` so the zone
    captures it at runtime. On the `mission.yaml` side: a `modules.COMBATZONE.combat_zones[]` entry
    referencing `zone_name` (appended, not replacing existing zones). Not deduplicated. No build.

    Args:
        folder_path: The mission folder (holds `mission.yaml` + `src/mission/`).
        zone_name: The combat zone's trigger-zone name.
        position: The zone centre, `{"x": ..., "y": ...}`.
        radius: The zone radius, in metres.
        groups: `[{"name", "units": [{"type","count"}], "position"?}, ...]` placed inside the zone.
        coalition: `"blue"`, `"red"` or `"neutral"` the groups are placed under (runtime-agnostic;
            VEAF respawns them regardless).
        country_id: DCS numeric country id for the groups.
        country_name: DCS country name for the groups.
        category: Group category (default `"vehicle"`).
        combat_zone: Optional extra `combat_zones[]` keys (e.g. `friendly_name`, `training`).

    Returns:
        `{"zone_name", "zone_id", "groups": [<resolved names>], "warnings": [...]}`.

    Raises:
        FileNotFoundError: when the folder has no mission / `mission.yaml`.
        ValueError: when the mission has no readable content.
    """
    mission = load_folder_mission(folder_path)
    content = mission.mission_content
    if content is None:
        raise ValueError(f"Mission folder has no readable mission: {folder_path}")

    zone_id = insert_trigger_zone(content, name=zone_name, position=position, radius=radius)

    created: list[str] = []
    warnings: list[dict[str, Any]] = []
    for spec in groups:
        group_name = resolve_group_name(spec["name"], for_combat_zone=zone_name)
        build_warnings: list[str] = []
        insert_group_into_content(
            content,
            coalition=coalition,
            country_id=country_id,
            country_name=country_name,
            category=category,
            name=group_name,
            position=spec.get("position", position),
            units=spec["units"],
            warnings=build_warnings,
        )
        created.append(group_name)
        warnings += validate_group_name(group_name, expected_combat_zone=zone_name)["warnings"]
        warnings += [{"group": group_name, "warning": w} for w in build_warnings]

    save_folder_mission(mission, folder_path)
    _append_combat_zone(mission_yaml_path(folder_path), zone_name, combat_zone)

    return {"zone_name": zone_name, "zone_id": zone_id, "groups": created, "warnings": warnings}


def _append_combat_zone(yaml_path: Path, zone_name: str, combat_zone: dict[str, Any] | None) -> None:
    """Append a `combat_zones[]` entry to `modules.COMBATZONE` in `mission.yaml`, preserving comments."""
    data: Any = load_yaml(yaml_path)
    modules: Any = data.get("modules") if hasattr(data, "get") else None
    if not hasattr(modules, "get"):
        modules = {}
        data["modules"] = modules
    combatzone: Any = modules.get("COMBATZONE")
    if not hasattr(combatzone, "get"):
        combatzone = {"enabled": True, "combat_zones": []}
        modules["COMBATZONE"] = combatzone
    combatzone["enabled"] = True
    zones: Any = combatzone.get("combat_zones")
    if not isinstance(zones, list):
        zones = []
        combatzone["combat_zones"] = zones
    entry: dict[str, Any] = {"type": "zone", "zone_name": zone_name}
    if combat_zone:
        entry.update(combat_zone)
    append_to_sequence(zones, entry)
    save_yaml(yaml_path, data)


def create_qra(
    folder_path: Path,
    *,
    name: str,
    coalition: str,
    trigger_zone: str,
    position: dict[str, float],
    radius: float,
    groups: list[dict[str, Any]],
    country_id: int,
    country_name: str,
    category: str = "plane",
    enemy_coalitions: list[str] | None = None,
    qra: dict[str, Any] | None = None,
) -> dict[str, Any]:
    """Create a complete VEAF QRA in a mission folder, in one pass, both worlds.

    Unlike a combat zone: QRA groups are referenced **by exact name** (not zone-prefixed),
    coalition **matters**, and interceptors are **Late Activation** (VEAF scrambles them). On the
    `.miz` side (`src/mission/`): the protected-airspace trigger zone + the Late-Activation
    interceptor group(s) on `coalition`. On `mission.yaml`: a `modules.QRA.definitions[]` entry
    (appended) referencing the group names verbatim.

    Args:
        folder_path: The mission folder.
        name: The QRA's identifier (radio prefix).
        coalition: The defending coalition (`"blue"`/`"red"`); the groups are placed on it and the
            YAML definition uses its upper-case form.
        trigger_zone: The protected-airspace trigger-zone name (created).
        position: The zone centre.
        radius: The zone radius, in metres.
        groups: `[{"name", "units", "position"?, "altitude_ft"?, "speed_kt"?, "pylons"?,
            "loadout_from"?}, ...]` — the interceptor group(s), one aircraft type each, built
            airborne and fuelled. `pylons` sets the loadout; `loadout_from` copies it from a group
            of the mission or of the spawnable/dynamic-slot catalogues (a `veafSpawn-*` template).
        country_id: DCS numeric country id for the interceptors.
        country_name: DCS country name for the interceptors.
        category: Kept for compatibility and ignored: the category comes from the aircraft type.
        enemy_coalitions: Optional coalitions whose entry scrambles the QRA (upper-cased).
        qra: Optional extra `definitions[]` keys (e.g. `delay_before_activating`).

    Returns:
        `{"qra", "trigger_zone", "zone_id", "groups": [...], "warnings": [...]}`.

    Raises:
        FileNotFoundError: when the folder has no mission / `mission.yaml`.
        ValueError: when the mission has no readable content.
    """
    mission = load_folder_mission(folder_path)
    content = mission.mission_content
    if content is None:
        raise ValueError(f"Mission folder has no readable mission: {folder_path}")

    zone_id = insert_trigger_zone(content, name=trigger_zone, position=position, radius=radius)

    group_names: list[str] = []
    warnings: list[dict[str, Any]] = []
    for spec in groups:
        group_name = spec["name"]
        unit_type, count = _single_type(spec["units"])
        _, air_warnings = insert_air_group_into_content(
            content,
            coalition=coalition.lower(),
            country_id=country_id,
            country_name=country_name,
            name=group_name,
            unit_type=unit_type,
            count=count,
            position=spec.get("position", position),
            altitude_ft=spec.get("altitude_ft", 15000.0),
            speed_kt=spec.get("speed_kt", 350.0),
            task=spec.get("task", "Intercept"),
            late_activation=True,
            pylons=_loadout(folder_path, content, spec),
        )
        group_names.append(group_name)
        warnings += validate_group_name(group_name)["warnings"]
        warnings += [{"group": group_name, "warning": w} for w in air_warnings]

    save_folder_mission(mission, folder_path)

    definition: dict[str, Any] = {
        "name": name,
        "coalition": coalition.upper(),
        "trigger_zone": trigger_zone,
        "simple_groups": group_names,
    }
    if enemy_coalitions:
        definition["enemy_coalitions"] = [c.upper() for c in enemy_coalitions]
    if qra:
        definition.update(qra)
    _append_qra_definition(mission_yaml_path(folder_path), definition)

    return {
        "qra": name,
        "trigger_zone": trigger_zone,
        "zone_id": zone_id,
        "groups": group_names,
        "warnings": warnings,
    }


def _append_qra_definition(yaml_path: Path, definition: dict[str, Any]) -> None:
    """Append a `definitions[]` entry to `modules.QRA` in `mission.yaml`, preserving comments."""
    data: Any = load_yaml(yaml_path)
    modules: Any = data.get("modules") if hasattr(data, "get") else None
    if not hasattr(modules, "get"):
        modules = {}
        data["modules"] = modules
    qra: Any = modules.get("QRA")
    if not hasattr(qra, "get"):
        qra = {"enabled": True, "definitions": []}
        modules["QRA"] = qra
    qra["enabled"] = True
    definitions: Any = qra.get("definitions")
    if not isinstance(definitions, list):
        definitions = []
        qra["definitions"] = definitions
    append_to_sequence(definitions, definition)
    save_yaml(yaml_path, data)


def create_cap_mission(
    folder_path: Path,
    *,
    mission_name: str,
    units: list[dict[str, Any]],
    coalition: str,
    country_id: int,
    country_name: str,
    position: dict[str, float],
    category: str = "plane",
    cap: dict[str, Any] | None = None,
    route: list[dict[str, float]] | None = None,
    altitude_ft: float = 20000.0,
    speed_kt: float = 350.0,
    pylons: dict[Any, Any] | None = None,
    loadout_from: str | None = None,
) -> dict[str, Any]:
    """Create an on-demand CAP mission in a mission folder, in one pass, both worlds.

    On the `.miz` side: a **Late-Activation** template group named `OnDemand-<mission_name>` (the
    name the runtime activates on demand). On `mission.yaml`: a `cap_missions[]` entry with
    `group_name: <mission_name>` — the build resolves it to the `OnDemand-`-prefixed group (see
    `group_validation`'s `ONDEMAND_CAP_PREFIX`).

    Args:
        folder_path: The mission folder.
        mission_name: The CAP mission name (the YAML `group_name`, un-prefixed).
        units: The template group's units (`[{"type","count"}, ...]`), one aircraft type.
        coalition: The coalition the template is placed on (`"blue"`/`"red"`).
        country_id: DCS numeric country id.
        country_name: DCS country name.
        position: The template group's anchor position, where it starts airborne.
        category: Kept for compatibility and ignored: the category comes from the aircraft type.
        cap: Optional extra `cap_missions[]` keys.
        route: Further points `{"x", "y", "altitude_ft"?}`; with one, the template flies a
            race-track between `position` and it — without, it orbits nowhere.
        altitude_ft: Altitude in feet.
        speed_kt: Speed in knots.
        pylons: The loadout, `{station: {"CLSID": ...}}`.
        loadout_from: A group to copy the loadout from (in the mission or the aircraft catalogues).

    Returns:
        `{"cap_mission", "group": <OnDemand- name>, "warnings": [...]}`.

    Raises:
        FileNotFoundError: when the folder has no mission / `mission.yaml`.
        ValueError: when the mission has no readable content.
    """
    mission = load_folder_mission(folder_path)
    content = mission.mission_content
    if content is None:
        raise ValueError(f"Mission folder has no readable mission: {folder_path}")

    group_name = f"OnDemand-{mission_name}"
    unit_type, count = _single_type(units)
    _, air_warnings = insert_air_group_into_content(
        content,
        coalition=coalition.lower(),
        country_id=country_id,
        country_name=country_name,
        name=group_name,
        unit_type=unit_type,
        count=count,
        position=position,
        altitude_ft=altitude_ft,
        speed_kt=speed_kt,
        task="CAP",
        late_activation=True,
        pylons=_loadout(folder_path, content, {"pylons": pylons, "loadout_from": loadout_from}),
        route=route,
    )
    save_folder_mission(mission, folder_path)

    entry: dict[str, Any] = {"group_name": mission_name}
    if cap:
        entry.update(cap)
    _append_cap_mission(mission_yaml_path(folder_path), entry)

    return {"cap_mission": mission_name, "group": group_name, "warnings": air_warnings}


def _append_cap_mission(yaml_path: Path, entry: dict[str, Any]) -> None:
    """Append an entry to the top-level `cap_missions:` list in `mission.yaml`, preserving comments."""
    data: Any = load_yaml(yaml_path)
    if not hasattr(data, "get"):
        raise ValueError(f"Mission config is not a mapping: {yaml_path}")
    caps: Any = data.get("cap_missions")
    if not isinstance(caps, list):
        caps = []
        data["cap_missions"] = caps
    append_to_sequence(caps, entry)
    save_yaml(yaml_path, data)


def _single_type(units: list[dict[str, Any]]) -> tuple[str, int]:
    """Return the one aircraft type of a flight and its size.

    Args:
        units: `[{"type", "count"?}, ...]`.

    Returns:
        `(unit_type, count)`.

    Raises:
        ValueError: If the flight mixes types, or has no aircraft.
    """
    types = {spec["type"] for spec in units}
    if len(types) != 1:
        raise ValueError(f"an air group takes one aircraft type, got {sorted(types) or 'none'}")
    count = sum(int(spec.get("count", 1)) for spec in units)
    if count < 1:
        raise ValueError("an air group needs at least one aircraft")
    return types.pop(), count


def _loadout(folder_path: Path, content: dict[str, Any], spec: dict[str, Any]) -> dict[Any, Any] | None:
    """Resolve a flight's loadout: explicit `pylons`, or copied from the group `loadout_from` names.

    An interceptor created without weapons is the next silent failure after one created without
    fuel. The `veafSpawn-*` groups of the aircraft catalogues are a sourced place to take a loadout
    from, so `loadout_from` looks in the mission first, then in the folder's catalogues, then in the
    shipped ones.

    Args:
        folder_path: The mission folder.
        content: The parsed mission table.
        spec: A mapping that may carry `pylons` and `loadout_from`.

    Returns:
        The pylons table, or None when neither is given.

    Raises:
        ValueError: If `loadout_from` names a group found nowhere, or one whose aircraft carry no
            pylons.
    """
    if spec.get("pylons"):
        return spec["pylons"]
    source = spec.get("loadout_from")
    if not source:
        return None
    group = _find_air_group_in_content(content, source) or _find_air_group_in_catalogues(folder_path, source)
    if group is None:
        raise ValueError(f"loadout_from: no aircraft group named {source!r} in the mission or the aircraft catalogues")
    for unit in indexed(group.get("units")):
        pylons = ((unit or {}).get("payload") or {}).get("pylons")
        if pylons:
            return copy.deepcopy(pylons)
    raise ValueError(f"loadout_from: the group {source!r} carries no pylons")


def _find_air_group_in_content(content: dict[str, Any], name: str) -> dict[str, Any] | None:
    """Return the plane or helicopter group of the mission table named `name`.

    Args:
        content: The parsed mission table.
        name: The exact group name.

    Returns:
        The group, or None when the mission has none by that name.
    """
    for coalition in (content.get("coalition") or {}).values():
        for country in indexed((coalition or {}).get("country")):
            for category in ("plane", "helicopter"):
                for group in indexed(((country or {}).get(category) or {}).get("group")):
                    if isinstance(group, dict) and group.get("name") == name:
                        return group
    return None


def _find_air_group_in_catalogues(folder_path: Path, name: str) -> dict[str, Any] | None:
    """Return the aircraft group named `name` from the aircraft catalogues, the folder's first.

    Looks in `src/spawnables.yaml` then `src/dynamic-slot-templates.yaml`, each in the folder and
    then in the shipped defaults — the order the build resolves them in.

    Args:
        folder_path: The mission folder.
        name: The exact group name.

    Returns:
        The group, or None when no catalogue has one by that name.
    """
    for relative in ("src/spawnables.yaml", "src/dynamic-slot-templates.yaml"):
        for path in (folder_path / relative, shipped_default_file(folder_path, relative)):
            if path is None or not path.is_file():
                continue
            data = yaml.safe_load(path.read_text(encoding="utf-8")) or {}
            for family in ("airplanes", "helicopters"):
                sides = ((data.get(family) or {}).get("coalitions")) or {}
                for countries in sides.values():
                    for groups in (countries or {}).values():
                        if isinstance(groups, dict) and isinstance(groups.get(name), dict):
                            return groups[name]
    return None
