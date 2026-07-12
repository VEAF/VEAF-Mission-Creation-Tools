"""`describe_mission` — situational-awareness read action.

Wraps the existing pure-Python mission parser
(:func:`mission_tools.miz_tools.read_miz`) — no new Lua/JSON parsing — to summarize
the groups and trigger zones already present in a mission's source `.miz`, so the
calling LLM can check current state before running an editor-parity write action
(the same way a human checks the Mission Editor's outliner before adding something).
"""

from pathlib import Path
from typing import Any

from mission_tools.miz_tools import read_miz

_GROUP_CATEGORIES: tuple[str, ...] = ("plane", "helicopter", "vehicle", "ship", "static")


def describe_mission(miz_path: Path) -> dict[str, Any]:
    """Summarize a mission's current groups and trigger zones.

    Args:
        miz_path: Path to the mission's source `.miz`.

    Returns:
        A dict with ``groups`` (name, coalition, country, category) and ``zones``
        (name, x, y, radius).

    Raises:
        ValueError: If the archive has no `mission` file (not a valid mission archive).
    """
    mission = read_miz(miz_path)
    if mission.mission_content is None:
        raise ValueError(f"Not a valid DCS mission archive (missing 'mission' file): {miz_path}")
    return {
        "groups": _list_groups(mission.mission_content),
        "zones": _list_zones(mission.mission_content),
    }


def _list_zones(content: dict[str, Any]) -> list[dict[str, Any]]:
    """List trigger zones (name, position, radius)."""
    zones = (content.get("triggers") or {}).get("zones") or []
    if isinstance(zones, dict):
        zones = list(zones.values())
    return [
        {"name": zone.get("name"), "x": zone.get("x"), "y": zone.get("y"), "radius": zone.get("radius")}
        for zone in zones
        if isinstance(zone, dict) and zone.get("name")
    ]


def _list_groups(content: dict[str, Any]) -> list[dict[str, Any]]:
    """List groups (name, coalition, country, category) across all coalitions/countries."""
    result: list[dict[str, Any]] = []
    coalitions = content.get("coalition") or {}
    if not isinstance(coalitions, dict):
        return result
    for side, coalition in coalitions.items():
        if not isinstance(coalition, dict):
            continue
        countries = coalition.get("country") or []
        if isinstance(countries, dict):
            countries = list(countries.values())
        for country in countries:
            if not isinstance(country, dict):
                continue
            country_name = country.get("name")
            for category in _GROUP_CATEGORIES:
                container = country.get(category) or {}
                groups = container.get("group") if isinstance(container, dict) else None
                if isinstance(groups, dict):
                    groups = list(groups.values())
                for group in groups or []:
                    if isinstance(group, dict) and group.get("name"):
                        result.append(
                            {
                                "name": group.get("name"),
                                "coalition": side,
                                "country": country_name,
                                "category": category,
                            }
                        )
    return result
