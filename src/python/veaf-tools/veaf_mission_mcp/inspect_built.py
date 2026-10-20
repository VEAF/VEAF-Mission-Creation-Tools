"""`inspect_built_mission` — what a built `.miz` holds, for the post-build check (FIX-OPENCODE-TEST-FINDINGS 07).

The authoring guide asked the AI to "open the built `.miz` and check"; with only the actions and a shell,
it unzipped the archive and parsed its Lua tables in PowerShell. This reads what that check needs, and
nothing more: one line per item, never a raw table, since the answer stays in the AI's context. A section
the mission does not have reads ``"absent"``, so silence is never taken for a pass.
"""

from pathlib import Path
from typing import Any

from campaign_manager.mission_picture import _tacan, _weather, callsign, find_built_mission, megahertz
from mission_tools.miz_tools import DcsMission, read_miz
from presets_injector.airfield_channels_manager import load_reference
from veaf_libs.mission_table import indexed

#: The folder the build writes the weather variants into, beside the main `.miz`.
_VARIANTS_FOLDER = "missions"
_ABSENT = "absent"
#: Group tasks that make a support aircraft.
_SUPPORT_TASKS = {"AWACS": "AWACS", "Refueling": "tanker"}


def _resolve(mission_path: Path) -> tuple[Path, list[Path]]:
    """Return the built `.miz` and its weather variants, from a `.miz` or a mission folder."""
    if not mission_path.is_dir():
        if not mission_path.is_file():
            raise FileNotFoundError(f"no such mission: {mission_path}")
        return mission_path, []
    miz = find_built_mission(mission_path)
    if miz is None:
        raise ValueError(f"{mission_path} holds no built .miz: run build_mission first")
    return miz, sorted((mission_path / _VARIANTS_FOLDER).glob("*.miz"))


def _template_types(content: dict[str, Any]) -> dict[int, tuple[str, str]]:
    """Group id -> (side, aircraft type) of every dynamic-slot template."""
    found: dict[int, tuple[str, str]] = {}
    for side_name, side in (content.get("coalition") or {}).items():
        for country in indexed(side.get("country")):
            for category in ("plane", "helicopter"):
                for group in indexed((country.get(category) or {}).get("group")):
                    units = indexed(group.get("units"))
                    if group.get("dynSpawnTemplate") and isinstance(group.get("groupId"), int) and units:
                        found[group["groupId"]] = (str(side_name), str(units[0].get("type")))
    return found


def _templates_by_side(templates: dict[int, tuple[str, str]]) -> dict[str, str] | str:
    """The aircraft types each side has a dynamic-slot template for, listed once for the whole report."""
    by_side: dict[str, set[str]] = {}
    for side, aircraft in templates.values():
        by_side.setdefault(side, set()).add(aircraft)
    return {
        side: f"{len(types)} types: {', '.join(sorted(types))}" for side, types in sorted(by_side.items())
    } or _ABSENT


def _offered(stock: Any) -> bool:
    """Whether a warehouse offers an aircraft: some stock, or unlimited."""
    return isinstance(stock, dict) and bool(stock.get("unlimited") or stock.get("initialAmount"))


def _stock_line(name: str, entry: dict[str, Any], templates: dict[int, tuple[str, str]]) -> str:
    """One warehouse as a line: side, dynamic slots, the types linked to a template, what else it offers.

    A base linked to every template of its side says so rather than listing them again: the shipped
    catalogue is sixty types, and each base repeating them made the answer 40 000 characters.
    """
    side = str(entry.get("coalition", "neutral")).lower()
    linked: set[str] = set()
    without = 0
    for kind in ("planes", "helicopters"):
        for aircraft, stock in ((entry.get("aircrafts") or {}).get(kind) or {}).items():
            if isinstance(stock, dict) and stock.get("linkDynTempl") in templates:
                linked.add(str(aircraft))
            elif _offered(stock):
                without += 1
    side_types = {aircraft for template_side, aircraft in templates.values() if template_side == side}
    slots = "on" if entry.get("dynamicSpawn") else "off"
    hot = ", hot start" if entry.get("allowHotStart") else ""
    if not linked:
        templates_text = "no template linked"
    elif linked == side_types:
        templates_text = f"every {side} template linked ({len(linked)})"
    elif side_types and linked < side_types and len(side_types - linked) < len(linked):
        templates_text = f"every {side} template linked but {', '.join(sorted(side_types - linked))}"
    else:
        templates_text = f"templates linked: {', '.join(sorted(linked))}"
    line = f"{name} ({side}): dynamic slots {slots}{hot}; {templates_text}"
    if without:
        line += f"; {without} more types stocked with no template (DCS defaults)"
    return line


def _airbases(mission: DcsMission, templates: dict[int, tuple[str, str]]) -> list[str] | str:
    """The airfields a side holds or that offer slots."""
    names = {key: str(entry["name"]) for key, entry in load_reference(str(mission.theatre_content or "")).items()}
    lines = []
    for airdrome_id, entry in sorted(((mission.warehouses_content or {}).get("airports") or {}).items()):
        if not isinstance(entry, dict):
            continue
        if str(entry.get("coalition", "NEUTRAL")).upper() == "NEUTRAL" and not entry.get("dynamicSpawn"):
            continue
        lines.append(_stock_line(names.get(int(airdrome_id), f"airdrome {airdrome_id}"), entry, templates))
    return lines or _ABSENT


def _farps_and_ships(mission: DcsMission, templates: dict[int, tuple[str, str]]) -> list[str] | str:
    """The FARPs and ships that carry a warehouse, named by their unit."""
    unit_names: dict[int, str] = {}
    for side in ((mission.mission_content or {}).get("coalition") or {}).values():
        for country in indexed(side.get("country")):
            for category in ("ship", "static"):
                for group in indexed((country.get(category) or {}).get("group")):
                    for unit in indexed(group.get("units")):
                        if isinstance(unit.get("unitId"), int):
                            unit_names[unit["unitId"]] = str(unit.get("name"))
    lines = [
        _stock_line(unit_names.get(int(unit_id), f"unit {unit_id}"), entry, templates)
        for unit_id, entry in sorted(((mission.warehouses_content or {}).get("warehouses") or {}).items())
        if isinstance(entry, dict) and (entry.get("dynamicSpawn") or entry.get("aircrafts"))
    ]
    return lines or _ABSENT


def _player_groups(content: dict[str, Any]) -> list[tuple[str, dict[str, Any]]]:
    """(side, group) for every aircraft group a player flies: client slots and dynamic-slot templates."""
    found = []
    for side_name, side in (content.get("coalition") or {}).items():
        for country in indexed(side.get("country")):
            for category in ("plane", "helicopter"):
                for group in indexed((country.get(category) or {}).get("group")):
                    units = indexed(group.get("units"))
                    if units and (
                        group.get("dynSpawnTemplate") or any(u.get("skill") in ("Client", "Player") for u in units)
                    ):
                        found.append((str(side_name), group))
    return found


def _presets(players: list[tuple[str, dict[str, Any]]]) -> list[str] | str:
    """Per side and radio layout, the aircraft types that carry it — or carry no preset at all.

    Grouped by layout, not listed by type: sixty types a side, one line each, are what an AI does not
    need to read twice.
    """
    layouts: dict[tuple[str, str], set[str]] = {}
    for side, group in players:
        unit = indexed(group.get("units"))[0]
        counts = [
            len(indexed(radio.get("channels"))) for radio in indexed(unit.get("Radio")) if isinstance(radio, dict)
        ]
        layout = f"{len(counts)} radios, {'/'.join(map(str, counts))} channels" if any(counts) else "no presets"
        layouts.setdefault((side, layout), set()).add(str(unit.get("type")))
    lines = [f"{side}, {layout}: {', '.join(sorted(types))}" for (side, layout), types in sorted(layouts.items())]
    return lines or _ABSENT


def _bullseyes(content: dict[str, Any]) -> dict[str, dict[str, float]] | str:
    found = {
        str(side): {"x": round(float(b["x"])), "y": round(float(b["y"]))}
        for side, coalition in (content.get("coalition") or {}).items()
        if isinstance(b := coalition.get("bullseye"), dict) and "x" in b and "y" in b
    }
    return found or _ABSENT


def _weather_line(label: str, content: dict[str, Any]) -> str:
    seconds = int(content.get("start_time") or 0)
    weather = _weather(content.get("weather") or {})
    ground = weather.winds["ground"]
    sky = weather.cover if weather.cover == "clear" else f"{weather.cover} at {round(weather.cloud_base)} m"
    extras = "".join(f", {name}" for name, on in (("rain", weather.rain), ("fog", weather.fog)) if on)
    return (
        f"{label}: {seconds // 3600:02d}:{seconds % 3600 // 60:02d}, {sky}, wind {ground.origin:03d}°/"
        f"{ground.knots} kt at the ground, visibility {round(weather.visibility / 1000)} km{extras}"
    )


def _support(content: dict[str, Any]) -> list[str] | str:
    """Tankers and AWACS: callsign, task, type, frequency, TACAN, late activation."""
    lines = []
    for side_name, side in (content.get("coalition") or {}).items():
        for country in indexed(side.get("country")):
            for group in indexed((country.get("plane") or {}).get("group")):
                role = _SUPPORT_TASKS.get(str(group.get("task")))
                units = indexed(group.get("units"))
                if role is None or not units:
                    continue
                frequency = megahertz(group.get("frequency"))
                tacan = _tacan(group)
                line = f"{callsign(units[0])} ({side_name} {role}, {units[0].get('type')})"
                line += f": {frequency} MHz" if frequency else ": no frequency"
                line += f", TACAN {tacan}" if tacan else ""
                line += ", late activation" if group.get("lateActivation") else ""
                lines.append(line)
    return lines or _ABSENT


def _links(mission: DcsMission, templates: dict[int, tuple[str, str]]) -> tuple[int, int]:
    """Count the warehouse links to a template, and those pointing at no template group."""
    good = dead = 0
    for table in ("airports", "warehouses"):
        for entry in ((mission.warehouses_content or {}).get(table) or {}).values():
            for kind in ("planes", "helicopters"):
                for stock in (((entry or {}).get("aircrafts") or {}).get(kind) or {}).values():
                    if isinstance(stock, dict) and "linkDynTempl" in stock:
                        if stock["linkDynTempl"] in templates:
                            good += 1
                        else:
                            dead += 1
    return good, dead


def inspect_built_mission(mission_path: Path) -> dict[str, Any]:
    """Report what a built mission holds, compactly, for the guide's post-build check.

    Args:
        mission_path: A built `.miz`, or a mission folder: its most recent built `.miz` is read, and
            the weather variants the build wrote into its `missions/` folder.

    Returns:
        ``{miz, theatre, dynamic_slot_templates, airbases, farps_and_ships, presets, bullseye,
        weather, support, counters}``: the template types once per side; one line per airbase, FARP
        or ship, radio layout, variant and support aircraft; ``"absent"`` for a section the mission
        does not have. ``counters`` gives ``presets_injected`` (player groups
        whose aircraft carry presets), ``routes_on_player_groups``, ``warehouse_links``, ``dead_links``
        and ``variants``, so a zero is visible.

    Raises:
        FileNotFoundError: No such `.miz` or folder.
        ValueError: A folder with no built `.miz`.
    """
    miz, variants = _resolve(mission_path)
    mission = read_miz(miz)
    content = mission.mission_content or {}
    templates = _template_types(content)
    players = _player_groups(content)
    good, dead = _links(mission, templates)
    weather = [_weather_line("main", content)]
    weather += [_weather_line(variant.stem, read_miz(variant).mission_content or {}) for variant in variants]
    return {
        "miz": str(miz),
        "theatre": mission.theatre_content,
        "dynamic_slot_templates": _templates_by_side(templates),
        "airbases": _airbases(mission, templates),
        "farps_and_ships": _farps_and_ships(mission, templates),
        "presets": _presets(players),
        "bullseye": _bullseyes(content),
        "weather": weather,
        "support": _support(content),
        "counters": {
            "presets_injected": sum(
                any(indexed(radio.get("channels")) for radio in indexed(indexed(g.get("units"))[0].get("Radio")))
                for _side, g in players
            ),
            "routes_on_player_groups": sum(len(indexed((g.get("route") or {}).get("points"))) > 1 for _s, g in players),
            "warehouse_links": good,
            "dead_links": dead,
            "variants": len(variants),
        },
    }
