"""Propose and write a mission's ``training:`` block (FEAT-ROLE-TRAINING-VARIANTS 06).

`propose_training_plan` drafts the classification from what the data can tell — the enemy's air groups
tasked for air combat, the on-demand CAPs and the QRA, the long-range SAMs by their DCS attribute, the
combat zones, and the other SAMs in or near those zones. It proposes everything **as placed**: what the
briefing describes vaguely is for whoever reads the briefing to move into ``randomize``, and an action
does not read prose. Each proposal carries the reason it was made, so it can be overruled.

`set_training_plan` writes the block, comments preserved and backed up, once the build's own checks
accept it — the same ones ``validate_mission`` runs (:func:`mission_builder.training_variants.check_training`).
"""

from __future__ import annotations

import math
from pathlib import Path
from typing import Any

import yaml
from mission_builder.group_removal import iter_group_slots
from mission_builder.training_variants import ROLES, check_training, profile_name, reference_sources
from mission_tools.mission_yaml_editor import load_yaml, save_yaml
from veaf_libs.dcs_units_data import get_unit_attributes
from veaf_libs.mission_table import indexed

from veaf_mission_mcp.mission_folder import open_mission

#: Air tasks of a flight that fights other aircraft.
_AIR_COMBAT_TASKS = frozenset({"CAP", "Fighter Sweep", "Intercept", "Escort"})

#: How far from a combat zone's edge a SAM still counts as protecting it, in metres.
_THREAT_MARGIN = 15000.0

#: A player's unit skill.
_PLAYER_SKILLS = frozenset({"Client", "Player"})

_NOTE = (
    "Everything is proposed as placed. Read the briefing: an element it states (type and number) stays "
    "as it is; one it describes vaguely ('medium-range defences', 'an armoured column') moves from "
    "'elements' to 'randomize', with a pool of the same role, a count and a radius. Show the plan to the "
    "user before writing it with set_training_plan."
)


def _player_side(content: dict[str, Any]) -> str:
    """The coalition the players fly for: the one holding the most player slots, blue when none."""
    counts = {"blue": 0, "red": 0}
    for side, _, _, group in iter_group_slots(content):
        for unit in indexed(group.get("units")):
            if isinstance(unit, dict) and unit.get("skill") in _PLAYER_SKILLS and side in counts:
                counts[side] += 1
    return "red" if counts["red"] > counts["blue"] else "blue"


def _attributes(group: dict[str, Any]) -> set[str]:
    """Every DCS attribute of the group's unit types."""
    found: set[str] = set()
    for unit in indexed(group.get("units")):
        if isinstance(unit, dict):
            found |= get_unit_attributes(str(unit.get("type", "")))
    return found


def _first_position(group: dict[str, Any]) -> tuple[float, float]:
    """The group's first unit position."""
    units = indexed(group.get("units"))
    anchor = units[0] if units and isinstance(units[0], dict) else group
    return float(anchor.get("x", 0.0)), float(anchor.get("y", 0.0))


def _combat_zone_circles(config: dict[str, Any], content: dict[str, Any]) -> dict[str, tuple[float, float, float]]:
    """Each declared combat zone that is not an operation, with its trigger zone's circle."""
    raw_modules = config.get("modules")
    modules: dict[str, Any] = raw_modules if isinstance(raw_modules, dict) else {}
    cfg = next((v for k, v in modules.items() if str(k).upper() == "COMBATZONE"), None)
    entries = cfg.get("combat_zones") if isinstance(cfg, dict) else None
    zones = {
        str(z.get("name")): z for z in indexed((content.get("triggers") or {}).get("zones")) if isinstance(z, dict)
    }
    circles = {}
    for entry in entries or []:
        if not isinstance(entry, dict) or entry.get("type") == "operation":
            continue
        name = str(entry.get("zone_name") or entry.get("zone") or "")
        zone = zones.get(name)
        if zone is not None:
            circles[name] = (float(zone.get("x", 0.0)), float(zone.get("y", 0.0)), float(zone.get("radius", 0.0)))
    return circles


def propose_training_plan(mission_path: Path) -> dict[str, Any]:
    """Draft a ``training:`` block for a mission folder, every element as placed.

    Args:
        mission_path: The mission folder (``mission.yaml`` + ``src/mission/``).

    Returns:
        ``{"training", "reasons", "enemy_coalition", "note"}``: the draft block, one reason per
        element in the same order, the side the draft treats as the enemy, and what is left to decide.

    Raises:
        ValueError: If the folder holds no readable mission.
    """
    _, content = open_mission(mission_path)
    yaml_path = mission_path / "mission.yaml"
    config: dict[str, Any] = {}
    if yaml_path.is_file():
        config = yaml.safe_load(yaml_path.read_text(encoding="utf-8")) or {}
    enemy = "red" if _player_side(content) == "blue" else "blue"
    elements: list[dict[str, Any]] = []
    reasons: list[str] = []

    def propose(element: dict[str, Any], reason: str) -> None:
        elements.append(element)
        reasons.append(reason)

    circles = _combat_zone_circles(config, content)
    for side, _, category, group in iter_group_slots(content):
        name = str(group.get("name", ""))
        if side != enemy or not name or group.get("lateActivation"):
            continue
        if category in ("plane", "helicopter") and group.get("task") in _AIR_COMBAT_TASKS:
            if not name.startswith(("veafSpawn-", "OnDemand-")):
                propose({"groups": [name], "kind": "enemy_cap"}, f"{enemy} {category} group tasked {group['task']}")
            continue
        if category != "vehicle":
            continue
        attributes = _attributes(group)
        if "LR SAM" in attributes:
            propose({"groups": [name], "kind": "sam_lr"}, "a unit type DCS rates 'LR SAM'")
            continue
        if "SAM related" not in attributes and "AAA" not in attributes:
            continue
        x, y = _first_position(group)
        near = [
            zone
            for zone, (zx, zy, radius) in circles.items()
            if math.hypot(x - zx, y - zy) <= radius + _THREAT_MARGIN or name.upper().startswith(zone.upper())
        ]
        if near:
            propose(
                {"groups": [name], "kind": "sam_threat"},
                f"air defence in or within {_THREAT_MARGIN / 1000:.0f} km of combat zone {near[0]}",
            )

    for zone in circles:
        propose({"zone": zone, "kind": "a2g_target"}, "a combat zone of the mission")
    for cap in config.get("cap_missions") or []:
        if isinstance(cap, dict) and cap.get("group_name"):
            propose({"cap_mission": str(cap["group_name"]), "kind": "enemy_cap"}, "an on-demand CAP")
    raw_modules = config.get("modules")
    modules: dict[str, Any] = raw_modules if isinstance(raw_modules, dict) else {}
    qra = next((v for k, v in modules.items() if str(k).upper() == "QRA"), None)
    for definition in (qra.get("definitions") if isinstance(qra, dict) else None) or []:
        if isinstance(definition, dict) and definition.get("name"):
            if str(definition.get("coalition", enemy)).lower() == enemy:
                propose({"qra": str(definition["name"]), "kind": "qra"}, f"a QRA defending for {enemy}")

    return {"training": {"elements": elements}, "reasons": reasons, "enemy_coalition": enemy, "note": _NOTE}


def set_training_plan(mission_path: Path, training: dict[str, Any]) -> dict[str, Any]:
    """Write the ``training:`` block of a mission folder's ``mission.yaml``, once the build accepts it.

    Args:
        mission_path: The mission folder.
        training: The block, as ``mission.yaml`` holds it (``elements``, ``randomize``).

    Returns:
        ``{"training", "warnings", "backup", "versions"}``: the block written, what the versions would
        warn about, the backup's path and the ``.miz`` suffixes the next build adds.

    Raises:
        ValueError: If the folder holds no readable mission, or the block does not fit it (the message
            lists every problem, as the build would).
    """
    _, content = open_mission(mission_path)
    yaml_path = mission_path / "mission.yaml"
    data = load_yaml(yaml_path)
    if not hasattr(data, "__setitem__"):
        raise ValueError(f"Mission config is not a mapping: {yaml_path}")
    plain = yaml.safe_load(yaml_path.read_text(encoding="utf-8")) or {}
    candidate = {**plain, "training": training}
    errors, warnings = check_training(candidate, content, reference_sources(mission_path, candidate, content))
    if errors:
        raise ValueError("\n".join(errors))
    data["training"] = training
    backup = save_yaml(yaml_path, data)
    return {
        "training": training,
        "warnings": warnings,
        "backup": str(backup),
        "versions": [f"_{profile_name(role)}" for role in ROLES],
    }
