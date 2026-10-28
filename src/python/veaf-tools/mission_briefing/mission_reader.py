"""What a one-shot mission's briefing reads in the built mission (FEAT-MCP-MISSION-BRIEFING ticket 02).

The rest — date, weather, flights, support, carriers, QRA — is :func:`read_mission_picture`'s. Here:

- an objective's zone and its members: the groups (for a static, the **unit**) whose name starts with
  the zone's, case aside — the runtime's own membership rule; a group whose units carry names of their
  own is one target per unit (the SA-6's radar and launchers 1 to 4), any other one target named as a
  pilot would name it (FIX-BRIEFING-PARITY-MARTEAU 03);
- the operation's tasks in `mission.yaml`, which make the main objectives;
- the presets the build injected into each player flight's first aircraft, with the names it gave them
  (``Radio[n].channelsNames``), so the frequency plan is what the pilots will find in the cockpit.
"""

from __future__ import annotations

import re
from collections.abc import Iterator
from dataclasses import replace
from pathlib import Path
from typing import Any

from mission_tools.mission_yaml_editor import load_yaml
from presets_injector.airfield_channels_manager import load_reference
from veaf_libs.dcs_units_data import get_unit_attributes
from veaf_libs.i18n import t
from veaf_libs.mission_table import indexed

from mission_briefing.models import GroundPicture, MapLine, ObjectiveArea, RadioPlan, Target

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


def _capitalised(text: str) -> str:
    """``lanceur 1`` → ``Lanceur 1``; the rest of the word as it is (``PC``, ``SA8``)."""
    return text[:1].upper() + text[1:]


#: A VEAF spawn command a placeholder unit carries: ``#command="-armor" KhanArnabah-armor-1``.
_SPAWN_COMMAND = re.compile(r'#command="-?([A-Za-z0-9_]+)')

#: A unit name the Mission Editor gave, not the author: ``Sasa-t72 Unit #001``.
_GENERIC_UNIT = re.compile(r"(?:unit|unité)\s*#\d+$", re.IGNORECASE)

#: A spawn command's family a pilot names in words; the others are written as the command is (``SA-15``, ``AAA``).
_SPAWN_FAMILIES = ("armor", "infantry", "artillery", "transport", "convoy")

#: A target's role, from its DCS type's attributes: the first set it holds, in this order.
_ROLES: tuple[tuple[str, frozenset[str]], ...] = (
    ("ewr", frozenset({"EWR"})),
    ("sam_cc", frozenset({"SAM CC"})),
    ("aaa_missile", frozenset({"AAA", "AA_missile"})),
    ("aaa", frozenset({"AAA"})),
    ("ir_sam", frozenset({"IR Guided SAM"})),
    ("short_sam", frozenset({"SR SAM"})),
    ("launcher", frozenset({"SAM LL"})),
    ("sam_radar", frozenset({"SAM SR"})),
    ("sam_radar", frozenset({"SAM TR"})),
    ("mlrs", frozenset({"MLRS"})),
    ("artillery", frozenset({"Artillery"})),
    ("tank", frozenset({"Tanks"})),
    ("ifv", frozenset({"IFV"})),
    ("apc", frozenset({"APC"})),
    ("fortification", frozenset({"Fortifications"})),
)


def target_role(unit_type: str) -> str:
    """What a unit of that DCS type does, as the briefing says it: ``lanceur de la batterie``; empty when unknown."""
    attributes = get_unit_attributes(unit_type)
    for role, needed in _ROLES:
        if needed <= attributes:
            return t(f"mission_briefing.role.{role}")
    return ""


def _spawn_label(command: str) -> str:
    """A spawn command as a pilot names it: ``armor`` → ``Blindés``, ``sa13_squad`` → ``SA-13``, ``aaa`` → ``AAA``."""
    family = command.lower()
    if family in _SPAWN_FAMILIES:
        return t(f"mission_briefing.spawn.{family}")
    found = re.fullmatch(r"sa(\d+)\D*", family)
    return f"SA-{found.group(1)}" if found else family.split("_")[0].upper()


def _group_name(rest: str, units: list[Any]) -> str:
    """A group's target name: the author's words, or its units' type when its suffix is a slug (``t72``, ``2s1``)."""
    types = list(dict.fromkeys(str(unit.get("type") or "") for unit in units))
    if re.fullmatch(r"[a-z0-9_-]+", rest) and len(types) == 1 and types[0]:
        return types[0].lstrip(".")
    return _capitalised(rest)


def _members(category: str, group: dict[str, Any], zone: str) -> list[Target]:
    """The targets one member group of a zone makes: one per unit when its units carry names of their own."""
    units = indexed(group["units"])
    first = units[0]
    if category == "static":
        kind = str(first.get("type") or "")
        name = _capitalised(_readable(str(first.get("name", "")), zone))
        return [Target(name, float(first["x"]), float(first["y"]), kind.lstrip("."), target_role(kind))]
    command = _SPAWN_COMMAND.search(str(first.get("name", "")))
    if command:
        label = _spawn_label(command.group(1))
        return [Target(label, float(first["x"]), float(first["y"]), t("mission_briefing.spawned"), spawned=True)]
    group_name = str(group.get("name", ""))
    names = [str(unit.get("name") or "") for unit in units]
    if all(_own_name(name, group_name) for name in names):
        return [
            Target(
                _capitalised(_readable(name, zone)),
                float(unit["x"]),
                float(unit["y"]),
                str(unit.get("type") or ""),
                target_role(str(unit.get("type") or "")),
            )
            for name, unit in zip(names, units, strict=True)
        ]
    return [
        Target(
            _group_name(_readable(group_name, zone), units),
            float(first["x"]),
            float(first["y"]),
            _kind(units),
            target_role(str(first.get("type") or "")),
        )
    ]


def _own_name(name: str, group: str) -> bool:
    """Whether the author named a unit: not ``<group> Unit #001`` nor the group's name and a number."""
    if not name or _GENERIC_UNIT.search(name):
        return False
    rest = name[len(group) :] if name.startswith(group) else name
    return re.fullmatch(r"[\s#_.-]*\d*", rest) is None


def _numbered_names(targets: list[Target]) -> tuple[Target, ...]:
    """Number the targets that share a name: two ``Blindés`` become ``Blindés 1`` and ``Blindés 2``."""
    counts: dict[str, int] = {}
    for target in targets:
        counts[target.name] = counts.get(target.name, 0) + 1
    seen: dict[str, int] = {}
    out = []
    for target in targets:
        if counts[target.name] > 1:
            seen[target.name] = seen.get(target.name, 0) + 1
            target = replace(target, name=f"{target.name} {seen[target.name]}")
        out.append(target)
    return tuple(out)


def _kind(units: list[Any]) -> str:
    """The units' DCS types, counted in the order they come: ``4 × 2S1, 3 × BM-21`` (one is just its type)."""
    counts: dict[str, int] = {}
    for unit in units:
        kind = str(unit.get("type") or "")
        if kind:
            counts[kind] = counts.get(kind, 0) + 1
    return ", ".join(kind if n == 1 else f"{n} × {kind}" for kind, n in counts.items())


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
    targets: list[Target] = []
    for category, group in _groups(content, enemy):
        first = indexed(group["units"])[0]
        name = str(first.get("name", "")) if category == "static" else str(group.get("name", ""))
        if name.lower().startswith(prefix):
            targets += _members(category, group, zone)
    return ObjectiveArea(
        zone, float(found["x"]), float(found["y"]), float(found.get("radius", 0)), _numbered_names(targets)
    )


def operation_zones(folder: Path) -> tuple[set[str], set[str]] | None:
    """The zones the mission's operations task, and the zones another one chains, from `mission.yaml`.

    An operation's tasks are what ends it: the main objectives. A zone outside every operation is a
    secondary one, and a zone another zone chains (a counter-attack its fall triggers) is neither — it
    does not count in the operation's end (FIX-BRIEFING-PARITY-MARTEAU 05).

    Args:
        folder: The mission folder.

    Returns:
        ``(tasked, chained)``, zone names lower-cased; ``None`` when the mission declares no operation.
    """
    path = folder / "mission.yaml"
    data = load_yaml(path) if path.is_file() else {}
    modules = data.get("modules") if isinstance(data, dict) else None
    combat = modules.get("COMBATZONE") if isinstance(modules, dict) else None
    entries = combat.get("combat_zones") if isinstance(combat, dict) else None
    tasked: set[str] = set()
    chained: set[str] = set()
    operations = 0
    for entry in entries if isinstance(entries, list) else []:
        if not isinstance(entry, dict):
            continue
        if entry.get("type") == "operation":
            operations += 1
            for order in entry.get("tasking_orders") or []:
                name = order.get("zone_name") if isinstance(order, dict) else order
                if name:
                    tasked.add(str(name).lower())
        for name in entry.get("chained_zones") or []:
            chained.add(str(name).lower())
    return (tasked, chained) if operations else None


def _colour(text: Any) -> tuple[int, int, int]:
    """A drawing's ``0xRRGGBBAA`` as RGB; black when it cannot be read."""
    try:
        value = int(str(text), 16)
    except ValueError:
        return (0, 0, 0)
    return ((value >> 24) & 255, (value >> 16) & 255, (value >> 8) & 255)


def _drawn_lines(content: dict[str, Any], side: str) -> tuple[MapLine, ...]:
    """The lines drawn on the players' side's layer and the common one: a front line, a boundary."""
    layers = {side.lower(), "common"}
    found = []
    for layer in indexed((content.get("drawings") or {}).get("layers")):
        if str(layer.get("name", "")).lower() not in layers:
            continue
        for drawn in indexed(layer.get("objects")):
            points = indexed(drawn.get("points"))
            if drawn.get("primitiveType") != "Line" or drawn.get("visible") is False or len(points) < 2:
                continue
            x0, y0 = float(drawn.get("mapX", 0)), float(drawn.get("mapY", 0))
            found.append(
                MapLine(
                    str(drawn.get("name") or ""),
                    _colour(drawn.get("colorString")),
                    int(drawn.get("thickness") or 3),
                    "dash" in str(drawn.get("style") or "").lower(),
                    tuple((x0 + float(p["x"]), y0 + float(p["y"])) for p in points),
                )
            )
    return tuple(found)


def ground_picture(content: dict[str, Any], side: str) -> GroundPicture:
    """The ground the maps show besides the objectives: friendly units, JTACs, axes, drawn lines.

    The hand-made combat map of "Marteau du Golan" showed the allied brigade, the JTAC, the allied push
    and the probable counter-attack: what the tool's left out (FIX-BRIEFING-PARITY-MARTEAU 02).

    Args:
        content: The built mission's ``mission`` table.
        side: The players' side.

    Returns:
        What it found; each part empty when the mission has none.
    """
    friendlies: list[tuple[float, float]] = []
    jtacs: list[tuple[str, float, float]] = []
    axes: list[tuple[str, tuple[tuple[float, float], ...]]] = []
    for coalition in ("blue", "red"):
        for category, group in _groups(content, coalition):
            if category not in ("vehicle", "static"):
                continue
            first = indexed(group["units"])[0]
            name = str(group.get("name", ""))
            if coalition == side:
                if "jtac" in name.lower():
                    jtacs.append((re.sub(r"[-_]+", " ", name).strip(), float(first["x"]), float(first["y"])))
                else:
                    friendlies.append((float(first["x"]), float(first["y"])))
            route = indexed((group.get("route") or {}).get("points"))
            if category == "vehicle" and len(route) > 1:
                axes.append((coalition, tuple((float(p["x"]), float(p["y"])) for p in route)))
    return GroundPicture(tuple(friendlies), tuple(jtacs), tuple(axes), _drawn_lines(content, side))


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
