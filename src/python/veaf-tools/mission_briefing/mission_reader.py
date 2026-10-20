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

from presets_injector.airfield_channels_manager import load_reference
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


def _numbered(container: Any) -> list[tuple[int, Any]]:
    """A Lua array as ``(index, value)``, from 1: luadata reads a sequence as a list, a sparse one as a dict."""
    if isinstance(container, dict):
        return sorted((int(key), value) for key, value in container.items())
    return list(enumerate(container or [], 1))


def _cockpit(group: dict[str, Any], units: list[Any], templates: bool) -> str | None:
    """How a group the players fly is named, ``None`` for one they do not fly.

    A dynamic-slot template counts only with ``templates``, under its aircraft type: its units are
    ``Client`` too, and the scaffold ships one per type whether a base offers dynamic slots or not.
    """
    if group.get("dynSpawnTemplate"):
        return str(units[0].get("type")) if templates else None
    return str(group.get("name")) if any(unit.get("skill") in ("Client", "Player") for unit in units) else None


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


def departures(
    content: dict[str, Any], side: str, theatre: str, *, templates: bool = True
) -> list[tuple[str, float, float]]:
    """The airfields the players take off from, each once: ``(name, x, y)`` where the flight starts.

    A flight from a carrier is left out (the carrier has its own symbol), and so is an air start.

    Args:
        content: The built mission's ``mission`` table.
        side: The players' side.
        theatre: The mission's theatre, to name the airfields.
        templates: Whether the dynamic-slot templates' airfields count, as for :func:`radio_plans`.

    Returns:
        The departures, in the order the flights appear.
    """
    names = {airdrome_id: str(entry["name"]) for airdrome_id, entry in load_reference(theatre).items()}
    found: dict[str, tuple[str, float, float]] = {}
    for category, group in _groups(content, side):
        if category not in ("plane", "helicopter"):
            continue
        if _cockpit(group, indexed(group["units"]), templates) is None:
            continue
        start = (indexed((group.get("route") or {}).get("points")) or [{}])[0]
        name = names.get(int(start["airdromeId"])) if start.get("airdromeId") is not None else None
        if name and name not in found:
            found[name] = (name, float(start["x"]), float(start["y"]))
    return list(found.values())


def radio_plans(content: dict[str, Any], side: str, *, templates: bool = True) -> list[RadioPlan]:
    """The presets in the players' aircraft, one entry per radio and per distinct channel list.

    Args:
        content: The built mission's ``mission`` table.
        side: The players' side.
        templates: Whether the dynamic-slot templates count: only where a base offers dynamic slots, since
            the scaffold ships one per type and a mission of named slots flies none of them.

    Returns:
        By radio, then in the order the flights appear; flights carrying the same channels share an entry.
    """
    found: dict[tuple[int, tuple[tuple[int, str, float], ...]], list[str]] = {}
    for category, group in _groups(content, side):
        if category not in ("plane", "helicopter"):
            continue
        units = indexed(group["units"])
        label = _cockpit(group, units, templates)
        if label is None:
            continue
        for number, radio in _numbered(units[0].get("Radio")):
            names = dict(_numbered(radio.get("channelsNames")))
            channels = tuple(
                (channel, str(names.get(channel, "")), float(freq))
                for channel, freq in _numbered(radio.get("channels"))
            )
            if channels:
                listed = found.setdefault((number, channels), [])
                if label not in listed:
                    listed.append(label)
    return [
        RadioPlan(radio, tuple(flights), channels)
        for (radio, channels), flights in sorted(found.items(), key=lambda item: item[0][0])
    ]
