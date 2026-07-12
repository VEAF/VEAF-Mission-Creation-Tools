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
import json

from mission_tools.group_insertion import GROUP_CATEGORIES, coerce_country_list, find_or_add_country, max_ids
from veaf_libs.bundled_data import read_bundled_text

_SIDES = ("blue", "red")
# Every category that can hold a group with units. Used to decide whether a
# coalition already has a unit (any unit keeps its DCS country alive — aircraft,
# ships and statics all count).
_UNIT_CATEGORIES = GROUP_CATEGORIES


@functools.lru_cache(maxsize=1)
def _templates() -> dict:
    """Load (and cache) the committed placeholder templates."""
    return json.loads(read_bundled_text("mission_builder", "data", "placeholder_groups.json"))


def _coalition_unit_count(coalition: dict) -> int:
    """Count every unit across every country/category of a coalition."""
    total = 0
    for country in coalition.get("country", []):
        for category in _UNIT_CATEGORIES:
            for group in country.get(category, {}).get("group", []):
                total += len(group.get("units", []))
    return total


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

    # Normalize every coalition's country container to a list up front, so the
    # id/unit scans below never trip over an empty `{}` (dict) or a malformed value.
    for coalition in coalitions.values():
        if isinstance(coalition, dict):
            coerce_country_list(coalition)

    templates = _templates()
    next_group_id, next_unit_id = (n + 1 for n in max_ids(mission_content))

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
        country = find_or_add_country(coalition, template["country_id"], template["country_name"])
        country.setdefault("vehicle", {}).setdefault("group", []).append(group)
        injected.append(side)
    return injected
