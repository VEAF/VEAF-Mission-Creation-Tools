"""What a one-shot mission's briefing reads in the built mission (FEAT-MCP-MISSION-BRIEFING ticket 02).

The rest — date, weather, flights, support, carriers, QRA — is :func:`read_mission_picture`'s. Here:

- an objective's zone and its members: the groups (for a static, the **unit**) whose name starts with
  the zone's, case aside — the runtime's own membership rule;
- the presets the build injected into each player flight's first aircraft, with the names it gave them
  (``Radio[n].channelsNames``), so the frequency plan is what the pilots will find in the cockpit.
"""

from __future__ import annotations

from collections.abc import Iterator
from typing import Any

from veaf_libs.mission_table import indexed

from mission_briefing.models import ObjectiveArea, RadioPlan, Target

#: The categories a group can belong to, in a coalition's country.
_CATEGORIES = ("plane", "helicopter", "vehicle", "ship", "static")


def _groups(content: dict[str, Any], side: str | None = None) -> Iterator[tuple[str, dict[str, Any]]]:
    """Every group, ``(category, group)``, of one side or of all."""
    for name, coalition in (content.get("coalition") or {}).items():
        if side is not None and name != side:
            continue
        for country in indexed((coalition or {}).get("country")):
            for category in _CATEGORIES:
                for group in indexed((country.get(category) or {}).get("group")):
                    if indexed(group.get("units")):
                        yield category, group


def _readable(name: str, zone: str) -> str:
    """A member's name without the zone's prefix nor its markers: ``Khobi-SA8 #spawnradius=0`` → ``SA8``."""
    bare = name.split("#")[0].strip()
    rest = bare[len(zone) :].strip(" -_.")
    return rest or bare


def objective_area(content: dict[str, Any], zone: str, enemy: str) -> ObjectiveArea:
    """An objective's combat zone and its enemy members, where they stand.

    Args:
        content: The built mission's ``mission`` table.
        zone: The combat zone's trigger-zone name.
        enemy: The side whose units the objective is made of.

    Returns:
        The zone's centre and radius, and one target per member group (one per unit for statics).

    Raises:
        ValueError: If the mission has no trigger zone of that name.
    """
    zones = {str(z.get("name")): z for z in indexed((content.get("triggers") or {}).get("zones"))}
    if zone not in zones:
        raise ValueError(f"No trigger zone named {zone!r} in the built mission: is it a combat zone of this mission?")
    found = zones[zone]
    prefix = zone.lower()
    targets = []
    for category, group in _groups(content, enemy):
        first = indexed(group["units"])[0]
        name = str(first.get("name", "")) if category == "static" else str(group.get("name", ""))
        if name.lower().startswith(prefix):
            targets.append(Target(_readable(name, zone), float(first["x"]), float(first["y"])))
    return ObjectiveArea(zone, float(found["x"]), float(found["y"]), float(found.get("radius", 0)), tuple(targets))


def group_position(content: dict[str, Any], name: str) -> tuple[float, float] | None:
    """Where a group's first unit stands, whatever its side; ``None`` when there is no such group."""
    for _, group in _groups(content):
        if str(group.get("name")) == name:
            first = indexed(group["units"])[0]
            return float(first["x"]), float(first["y"])
    return None


def radio_plans(content: dict[str, Any], side: str) -> list[RadioPlan]:
    """The presets in the players' aircraft, one entry per radio and per distinct channel list.

    Args:
        content: The built mission's ``mission`` table.
        side: The players' side.

    Returns:
        By radio, then in the order the flights appear; flights carrying the same channels share an entry.
    """
    found: dict[tuple[int, tuple[tuple[int, str, float], ...]], list[str]] = {}
    for category, group in _groups(content, side):
        if category not in ("plane", "helicopter"):
            continue
        units = indexed(group["units"])
        players = any(unit.get("skill") in ("Client", "Player") for unit in units)
        if not players and not group.get("dynSpawnTemplate"):
            continue
        label = str(group.get("name")) if players else str(units[0].get("type"))
        for number, radio in (units[0].get("Radio") or {}).items():
            names = radio.get("channelsNames") or {}
            channels = tuple(
                (int(channel), str(names.get(channel, "")), float(freq))
                for channel, freq in sorted((radio.get("channels") or {}).items(), key=lambda item: int(item[0]))
            )
            if channels:
                listed = found.setdefault((int(number), channels), [])
                if label not in listed:
                    listed.append(label)
    return [
        RadioPlan(radio, tuple(flights), channels)
        for (radio, channels), flights in sorted(found.items(), key=lambda item: item[0][0])
    ]
