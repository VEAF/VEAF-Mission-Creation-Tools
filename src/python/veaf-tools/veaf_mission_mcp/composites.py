"""Composite one-pass builders (wave 8) — lay down a full VEAF feature across both worlds.

Each builder orchestrates the wave-1..7 primitives on a mission **folder** (David's model): it
edits the durable source — the exploded ``src/mission/`` (trigger zones + groups) and
``mission.yaml`` (module config) — so a later ``veaf-tools build`` produces the ``.miz``. No build
is triggered here. See ``.backlog/FEAT-MCP-MISSION-EDITOR/PRD.md`` (wave 8).
"""

from pathlib import Path
from typing import Any

from mission_tools.mission_yaml_editor import load_yaml, save_yaml

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
        insert_group_into_content(
            content,
            coalition=coalition,
            country_id=country_id,
            country_name=country_name,
            category=category,
            name=group_name,
            position=spec.get("position", position),
            units=spec["units"],
        )
        created.append(group_name)
        warnings += validate_group_name(group_name, expected_combat_zone=zone_name)["warnings"]

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
    zones.append(entry)
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
        groups: `[{"name", "units", "position"?}, ...]` — the interceptor group(s).
        country_id: DCS numeric country id for the interceptors.
        country_name: DCS country name for the interceptors.
        category: Group category (default `"plane"`).
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
        insert_group_into_content(
            content,
            coalition=coalition.lower(),
            country_id=country_id,
            country_name=country_name,
            category=category,
            name=group_name,
            position=spec.get("position", position),
            units=spec["units"],
            late_activation=True,
        )
        group_names.append(group_name)
        warnings += validate_group_name(group_name)["warnings"]

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
    definitions.append(definition)
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
) -> dict[str, Any]:
    """Create an on-demand CAP mission in a mission folder, in one pass, both worlds.

    On the `.miz` side: a **Late-Activation** template group named `OnDemand-<mission_name>` (the
    name the runtime activates on demand). On `mission.yaml`: a `cap_missions[]` entry with
    `group_name: <mission_name>` — the build resolves it to the `OnDemand-`-prefixed group (see
    `group_validation`'s `ONDEMAND_CAP_PREFIX`).

    Args:
        folder_path: The mission folder.
        mission_name: The CAP mission name (the YAML `group_name`, un-prefixed).
        units: The template group's units (`[{"type","count"}, ...]`).
        coalition: The coalition the template is placed on (`"blue"`/`"red"`).
        country_id: DCS numeric country id.
        country_name: DCS country name.
        position: The template group's anchor position.
        category: Group category (default `"plane"`).
        cap: Optional extra `cap_missions[]` keys.

    Returns:
        `{"cap_mission", "group": <OnDemand- name>}`.

    Raises:
        FileNotFoundError: when the folder has no mission / `mission.yaml`.
        ValueError: when the mission has no readable content.
    """
    mission = load_folder_mission(folder_path)
    content = mission.mission_content
    if content is None:
        raise ValueError(f"Mission folder has no readable mission: {folder_path}")

    group_name = f"OnDemand-{mission_name}"
    insert_group_into_content(
        content,
        coalition=coalition.lower(),
        country_id=country_id,
        country_name=country_name,
        category=category,
        name=group_name,
        position=position,
        units=units,
        late_activation=True,
    )
    save_folder_mission(mission, folder_path)

    entry: dict[str, Any] = {"group_name": mission_name}
    if cap:
        entry.update(cap)
    _append_cap_mission(mission_yaml_path(folder_path), entry)

    return {"cap_mission": mission_name, "group": group_name}


def _append_cap_mission(yaml_path: Path, entry: dict[str, Any]) -> None:
    """Append an entry to the top-level `cap_missions:` list in `mission.yaml`, preserving comments."""
    data: Any = load_yaml(yaml_path)
    if not hasattr(data, "get"):
        raise ValueError(f"Mission config is not a mapping: {yaml_path}")
    caps: Any = data.get("cap_missions")
    if not isinstance(caps, list):
        caps = []
        data["cap_missions"] = caps
    caps.append(entry)
    save_yaml(yaml_path, data)
