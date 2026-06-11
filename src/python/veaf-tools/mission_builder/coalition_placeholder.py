"""Ensure each side coalition owns at least one ground unit.

DCS purges any country that has zero units on save, and the VEAF injectors
(``inject-presets``, ``inject-waypoints``) skip groups when a coalition's tables
are incomplete — which is why a base mission historically had to ship one blue
*and* one red ground group placed by hand.

This module lifts that requirement: when a side coalition (``blue``/``red``) has
no unit at all, the build injects a single **hidden** placeholder ground group
(a real, roster-valid unit with a valid locked-ETA route, positioned on the
coalition bullseye) so DCS registers the coalition. A unit-less synthetic
country does not work — DCS strips it on save (see DCSDATA-007).

The placeholder templates are committed real groups (see
``data/placeholder_groups.json``); only their ids, name, ``hidden`` flag and
position are overridden at injection time.
"""

from __future__ import annotations

import copy
import functools
import importlib.resources
import json
import sys
from pathlib import Path

_SIDES = ("blue", "red")
_GROUND_CATEGORIES = ("vehicle", "plane", "helicopter")


def _read_templates_file() -> str:
    """Read the templates, whether running from source or a PyInstaller bundle."""
    bundle_path = Path(getattr(sys, "_MEIPASS", "")) / "mission_builder" / "data" / "placeholder_groups.json"
    if bundle_path.exists():
        return bundle_path.read_text(encoding="utf-8")
    pkg = importlib.resources.files("mission_builder") / "data"
    return (pkg / "placeholder_groups.json").read_text(encoding="utf-8")


@functools.lru_cache(maxsize=1)
def _templates() -> dict:
    """Load (and cache) the committed placeholder templates."""
    return json.loads(_read_templates_file())


def _coalition_unit_count(coalition: dict) -> int:
    """Count every unit across every country/category of a coalition."""
    total = 0
    for country in coalition.get("country", []):
        for category in _GROUND_CATEGORIES:
            for group in country.get(category, {}).get("group", []):
                total += len(group.get("units", []))
    return total


def _max_ids(mission_content: dict) -> tuple[int, int]:
    """Return the highest groupId and unitId currently used in the mission."""
    max_group_id = 0
    max_unit_id = 0
    for coalition in mission_content.get("coalition", {}).values():
        if not isinstance(coalition, dict):
            continue
        for country in coalition.get("country", []):
            for category in _GROUND_CATEGORIES:
                for group in country.get(category, {}).get("group", []):
                    max_group_id = max(max_group_id, int(group.get("groupId", 0) or 0))
                    for unit in group.get("units", []):
                        max_unit_id = max(max_unit_id, int(unit.get("unitId", 0) or 0))
    return max_group_id, max_unit_id


def _find_or_add_country(coalition: dict, country_id: int, country_name: str) -> dict:
    """Return the coalition country with *country_id*, creating it if absent."""
    countries = coalition.setdefault("country", [])
    for country in countries:
        if country.get("id") == country_id:
            return country
    country = {"id": country_id, "name": country_name}
    countries.append(country)
    return country


def _build_placeholder(template_group: dict, side: str, group_id: int, unit_id: int, bullseye: dict) -> dict:
    """Materialize a placeholder group from a template at the bullseye position."""
    group = copy.deepcopy(template_group)
    x = bullseye.get("x", 0)
    y = bullseye.get("y", 0)
    group["name"] = f"VEAF-placeholder-{side}"
    group["groupId"] = group_id
    group["hidden"] = True
    group["lateActivation"] = False
    group["x"] = x
    group["y"] = y
    unit = group["units"][0]
    unit["name"] = f"VEAF-placeholder-{side}-1"
    unit["unitId"] = unit_id
    unit["x"] = x
    unit["y"] = y
    for point in group.get("route", {}).get("points", []):
        point["x"] = x
        point["y"] = y
    return group


def ensure_coalitions_populated(mission_content: dict) -> list[str]:
    """Inject a hidden placeholder ground unit into any empty side coalition.

    For each of ``blue`` and ``red``, if the coalition has no unit at all, a
    single hidden placeholder ground group is appended (under its roster-valid
    template country, on the coalition bullseye) so DCS registers the coalition
    and the injectors do not skip groups.

    Args:
        mission_content: The parsed DCS ``mission`` table (mutated in place).

    Returns:
        The list of sides (``"blue"``/``"red"``) that received a placeholder.
    """
    coalitions = mission_content.get("coalition")
    if not isinstance(coalitions, dict):
        return []

    templates = _templates()
    next_group_id, next_unit_id = (n + 1 for n in _max_ids(mission_content))

    injected: list[str] = []
    for side in _SIDES:
        coalition = coalitions.get(side)
        if not isinstance(coalition, dict) or _coalition_unit_count(coalition) > 0:
            continue
        template = templates[side]
        bullseye = coalition.get("bullseye", {})
        group = _build_placeholder(template["group"], side, next_group_id, next_unit_id, bullseye)
        next_group_id += 1
        next_unit_id += 1
        country = _find_or_add_country(coalition, template["country_id"], template["country_name"])
        country.setdefault("vehicle", {}).setdefault("group", []).append(group)
        injected.append(side)
    return injected
