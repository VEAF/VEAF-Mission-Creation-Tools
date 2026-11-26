"""Adapt a freshly scaffolded mission folder to the mission asked for, in one action (MCP-CONTEXT-BUDGET).

The authoring guide asks, right after `scaffold_mission`, for five files to be fitted to the request:
`src/presets.yaml`, `src/versions.yaml`, `src/waypoints.yaml`, `src/dynamic-slot-templates.yaml` and
`mission.yaml`. A model did it by reading them: 68 759 characters on 2026-11-25, and a local model at
49 152 tokens of context filled up before it had placed anything. This action takes what the request
says and writes the five files itself; the model reads one line per file.
"""

import re
from datetime import date as dt_date
from pathlib import Path
from typing import Any

import yaml
from mission_tools.mission_yaml_editor import load_yaml, save_yaml
from mission_tools.miz_backup import backup_before_write
from presets_injector.airfield_channels_manager import (
    _normalise,
    rewrite_primary_2,
    theatre_aliases,
    theatre_collection,
)
from veaf_libs import coordinates
from veaf_libs.i18n import t
from veaf_libs.shipped_defaults import shipped_default_file

from veaf_mission_mcp.edit_mission_yaml import set_mission_module
from veaf_mission_mcp.map_tools import mission_theatre
from veaf_mission_mcp.mission_folder import mission_yaml_path
from veaf_mission_mcp.mission_settings import set_mission_date

#: The eras `mission.era` takes.
ERAS: tuple[str, ...] = ("MODERN", "COLD_WAR", "WW2")
#: The languages `mission.language` takes: the in-game VEAF messages and the briefing.
LANGUAGES: tuple[str, ...] = ("fr", "en")
#: The coalitions that can get dynamic slots.
COALITIONS: tuple[str, ...] = ("blue", "red")
#: Default altitude of a route point, in metres (20 000 ft, the scaffold's example).
DEFAULT_WAYPOINT_ALT = 6096.0
#: The route points of the scaffold's `src/waypoints.yaml`: examples, never a real mission's route.
EXAMPLE_WAYPOINTS = frozenset({"HOLDING_POINT", "INITIAL_POINT", "TARGET"})

_TIME = re.compile(r"^([01]\d|2[0-3]):[0-5]\d(:[0-5]\d)?$")
#: A generated `airports-*` collection's heading under `channels_collection`.
_AIRPORTS_HEADING = re.compile(r"^(?P<pad>\s*)(?P<name>airports-[a-z0-9-]+):\s*(#.*)?$")

_WAYPOINTS_HEADER = """\
# Waypoints of this mission, written by adapt_scaffold: each player flight gets them, in this order, then
# the mission's BULLSEYE. A plan lists its waypoints BY KEY; x/y are mission coordinates, alt in metres.
# The scaffold's commented example and its notes: published/src/defaults/mission-folder/src/waypoints.yaml.
"""

_SLOTS_HEADER = """\
# Dynamic-slot templates for this mission, written by adapt_scaffold: the catalogue shipped with veaf-tools,
# for {coalitions} only. As long as this file holds a group, it stands alone: the shipped catalogue is not
# read. Empty it (`coalitions: {{}}` under each category) to go back to the whole shipped catalogue.
"""


def _variant_name(start_time: str) -> str:
    """Name a weather variant after its time of day: `morning`, `noon`, `afternoon`, `evening`, `night`."""
    hour = int(start_time[:2])
    if 5 <= hour < 10:
        return "morning"
    if 10 <= hour < 14:
        return "noon"
    if 14 <= hour < 18:
        return "afternoon"
    if 18 <= hour < 21:
        return "evening"
    return "night"


def _check(
    mission_name: str | None,
    era: str | None,
    date: str | None,
    start_time: str | None,
    position: dict[str, Any] | None,
    waypoints: list[dict[str, Any]] | None,
    dynamic_slot_coalitions: list[str] | None,
) -> None:
    """Refuse a bad value before anything is written, each problem named.

    Raises:
        ValueError: Every problem found, in one message.
    """
    problems: list[str] = []
    if mission_name is not None and (not mission_name.strip() or not mission_name.isascii()):
        problems.append("mission_name must be non-empty ASCII (it names the .miz files)")
    if era is not None and era not in ERAS:
        problems.append(f"era must be one of {', '.join(ERAS)}")
    if date is not None:
        try:
            dt_date.fromisoformat(date)
        except ValueError:
            problems.append(f"date {date!r} is not YYYY-MM-DD")
    if start_time is not None and not _TIME.match(start_time):
        problems.append(f"start_time {start_time!r} is not HH:MM")
    if position is not None and not any(
        all(isinstance(position.get(key), int | float) for key in pair)
        for pair in (("latitude", "longitude"), ("x", "y"))
    ):
        problems.append("position needs a numeric latitude and longitude, or the map's x and y")
    for index, point in enumerate(waypoints or []):
        if not point.get("name") or not all(isinstance(point.get(key), int | float) for key in ("x", "y")):
            problems.append(f"waypoints[{index}] needs a name, x and y")
        elif "alt" in point and not isinstance(point["alt"], int | float):
            problems.append(f"waypoints[{index}] alt must be a number of metres")
    unknown = sorted(set(dynamic_slot_coalitions or []) - set(COALITIONS))
    if dynamic_slot_coalitions is not None and not dynamic_slot_coalitions:
        # A slot file with no group falls back to the whole shipped catalogue: an empty list would give
        # both coalitions, the opposite of what it says.
        problems.append("dynamic_slot_coalitions needs at least one coalition (omit it to keep both)")
    if unknown:
        problems.append(f"dynamic_slot_coalitions takes {', '.join(COALITIONS)}, not {', '.join(unknown)}")
    if problems:
        raise ValueError("adapt_scaffold: " + "; ".join(problems))


def _resolve_airfields(presets: dict[str, Any], theatre: str, airfields: list[str]) -> list[str]:
    """Return the plan's alias of each airfield named, or refuse with the theatre's names."""
    aliases = theatre_aliases(presets, theatre)
    resolved: list[str] = []
    unknown: list[str] = []
    for name in airfields:
        alias = aliases.get(_normalise(re.sub(r" \(.*\)$", "", name)))
        if alias is None:
            unknown.append(name)
        else:
            resolved.append(alias)
    if unknown and not aliases:
        raise ValueError(
            f"adapt_scaffold: src/presets.yaml has no airfield channel list for {theatre}: leave 'airfields' out, "
            "and write the second radio with edit_mission_file"
        )
    if unknown:
        raise ValueError(
            f"adapt_scaffold: no airfield {unknown} on {theatre}; its airfields: {', '.join(sorted(aliases.values()))}"
        )
    return resolved


def _drop_other_theatres(text: str, keep: str | None) -> tuple[str, list[str]]:
    """Remove the generated `airports-*` collections of the other theatres from a `presets.yaml` text.

    Args:
        text: The file's text.
        keep: The collection of the mission's theatre.

    Returns:
        The text, and the names of the collections removed.
    """
    newline = "\r\n" if "\r\n" in text else "\n"
    lines = text.split(newline)
    kept: list[str] = []
    removed: list[str] = []
    index = 0
    while index < len(lines):
        match = _AIRPORTS_HEADING.match(lines[index])
        if match is None or match["name"] == keep:
            kept.append(lines[index])
            index += 1
            continue
        removed.append(match["name"])
        depth = len(match["pad"])
        index += 1
        while index < len(lines) and (
            not lines[index].strip() or len(lines[index]) - len(lines[index].lstrip()) > depth
        ):
            index += 1
    return newline.join(kept), removed


def _write_backed_up(path: Path, content: bytes) -> None:
    """Write `content` over `path`, a backup of it taken first, as every other MCP write does."""
    if path.exists() and path.read_bytes() != content:
        backup_before_write(path)
    path.write_bytes(content)


def _adapt_presets(folder: Path, theatre: str, airfields: list[str] | None) -> str:
    """Fit `src/presets.yaml` to the theatre: its airfields on the second radio, no other theatre's list."""
    path = folder / "src" / "presets.yaml"
    text = path.read_bytes().decode("utf-8")  # its own line ends, kept on write
    presets = yaml.safe_load(text) or {}
    keep = theatre_collection(presets, theatre)
    # A theatre with no list of its own (Afghanistan, TheChannel, MarianaIslandsWWII) keeps them all: its
    # second radio still names the Caucasus airfields, and the build stops on an alias no list defines.
    text, removed = _drop_other_theatres(text, keep) if keep else (text, [])
    parts = []
    if airfields:
        chosen = _resolve_airfields(presets, theatre, airfields)
        text = rewrite_primary_2(text, chosen)
        parts.append(t("mcp.adapt.presets_radio", airfields=", ".join(chosen)))
    if removed:
        parts.append(t("mcp.adapt.presets_dropped", count=len(removed)))
    _write_backed_up(path, text.encode("utf-8"))
    return t("mcp.adapt.presets", details="; ".join(parts) or t("mcp.adapt.no_change"))


def _solar_position(theatre: str, position: dict[str, Any]) -> dict[str, Any]:
    """Return `versions.yaml`'s `position` for a point given as latitude/longitude or as the map's x/y.

    The build refuses a position without its timezone; the default is the nominal zone of the longitude,
    as for a theatre's own point (`theatre_position`), read only on a theatre whose DCS clock it does not know.
    """
    if "latitude" in position and "longitude" in position:
        latitude, longitude = float(position["latitude"]), float(position["longitude"])
    else:
        latitude, longitude = coordinates.xy_to_latlon(theatre, float(position["x"]), float(position["y"]))
    timezone = position.get("timezone") or f"Etc/GMT{-round(longitude / 15):+d}"
    return {"latitude": round(latitude, 4), "longitude": round(longitude, 4), "timezone": timezone}


def _adapt_versions(
    folder: Path,
    theatre: str,
    date: str | None,
    start_time: str | None,
    variant: str | None,
    position: dict[str, Any] | None,
) -> str | None:
    """Set the weather variant's name and time, `base_date` and `position` in `src/versions.yaml`."""
    if date is None and start_time is None and variant is None and position is None:
        return None
    path = folder / "src" / "versions.yaml"
    data = load_yaml(path)
    parts = []
    if position is not None:
        value = _solar_position(theatre, position)
        if "position" in data:
            data["position"] = value
        else:
            data.insert(0, "position", value)
        parts.append(t("mcp.adapt.versions_position", latitude=value["latitude"], longitude=value["longitude"]))
    if date is not None:
        data["base_date"] = date
        parts.append(t("mcp.adapt.versions_date", date=date))
    versions = data.get("versions") or []
    if versions and (start_time is not None or variant is not None):
        first = versions[0]
        if start_time is not None:
            first["time"] = start_time
        first["name"] = variant or (_variant_name(start_time) if start_time else first.get("name"))
        parts.append(t("mcp.adapt.versions_variant", name=first["name"], time=first.get("time")))
    save_yaml(path, data)
    return t("mcp.adapt.versions", details=", ".join(parts))


def _adapt_waypoints(folder: Path, waypoints: list[dict[str, Any]] | None) -> str | None:
    """Write the mission's route in `src/waypoints.yaml`, or no point at all, in place of the examples.

    Without `waypoints`, a route that is no longer the scaffold's examples is left alone: a second call, to
    change something else, must not erase the first call's route.
    """
    path = folder / "src" / "waypoints.yaml"
    if waypoints is None and path.exists():
        current = (yaml.safe_load(path.read_text(encoding="utf-8")) or {}).get("waypoints") or {}
        if not set(current) & EXAMPLE_WAYPOINTS:
            return None
    points: dict[str, Any] = {}
    for point in waypoints or []:
        key = re.sub(r"[^A-Za-z0-9_]+", "_", str(point["name"])).strip("_").upper() or "WP"
        while key in points:
            key += "_"
        points[key] = {
            "type": "Turning Point",
            "action": "Turning Point",
            "alt": float(point.get("alt", DEFAULT_WAYPOINT_ALT)),
            "alt_type": "BARO",
            "x": float(point["x"]),
            "y": float(point["y"]),
            "name": str(point["name"]),
        }
    content = {"waypoints": points, "settings": {"every_player_flight": {"waypoints": list(points)}}}
    text = _WAYPOINTS_HEADER + yaml.safe_dump(content, sort_keys=False, allow_unicode=True)
    _write_backed_up(path, text.encode("utf-8"))
    if not points:
        return t("mcp.adapt.waypoints_none")
    return t("mcp.adapt.waypoints", count=len(points), keys=", ".join(points))


def _template_types(group: dict[str, Any]) -> set[str]:
    """Return the aircraft types of one dynamic-slot template group."""
    units = group.get("units") or {}
    values = units.values() if isinstance(units, dict) else units
    return {str(unit.get("type")) for unit in values if isinstance(unit, dict) and unit.get("type")}


def _aircraft_key(name: str) -> str:
    """Reduce an aircraft name to letters and digits, upper case: `F/A-18C` and `FA-18C_hornet` meet."""
    return re.sub(r"[^A-Z0-9]", "", name.upper())


def _catalogue_types(catalogue: dict[str, Any]) -> set[str]:
    """Return every aircraft type of a dynamic-slot catalogue."""
    return {
        kind
        for block in catalogue.values()
        if isinstance(block, dict)
        for countries in (block.get("coalitions") or {}).values()
        for groups in (countries or {}).values()
        for group in (groups or {}).values()
        if isinstance(group, dict)
        for kind in _template_types(group)
    }


def _resolve_aircraft(catalogue: dict[str, Any], aircraft: list[str]) -> set[str]:
    """Return the catalogue's types each named aircraft stands for, or refuse with the types it has.

    A name matches the types whose letters and digits start with its own: `F/A-18C` gives `FA-18C_hornet`.
    """
    types = _catalogue_types(catalogue)
    chosen: set[str] = set()
    unknown: list[str] = []
    for name in aircraft:
        key = _aircraft_key(name)
        found = {kind for kind in types if key and _aircraft_key(kind).startswith(key)}
        if found:
            chosen |= found
        else:
            unknown.append(name)
    if unknown:
        raise ValueError(
            f"adapt_scaffold: no dynamic-slot template for {unknown}; the types: {', '.join(sorted(types))}"
        )
    return chosen


def _adapt_dynamic_slots(folder: Path, coalitions: list[str] | None, aircraft: list[str] | None) -> str | None:
    """Keep the shipped dynamic-slot catalogue's templates of the coalitions and aircraft named only.

    A local model asked for players "in F/A-18C" read five slices of the 181 000-character catalogue, 31 384
    characters, to find that type (MCP-CONTEXT-BUDGET, run 9): naming it here keeps only its templates.
    """
    sides = coalitions if coalitions is not None else list(COALITIONS)
    if set(sides) == set(COALITIONS) and not aircraft:
        return None
    shipped = shipped_default_file(folder, "src/dynamic-slot-templates.yaml")
    if shipped is None:
        raise ValueError("adapt_scaffold: the shipped dynamic-slot catalogue is not in the folder (published/)")
    catalogue = yaml.safe_load(shipped.read_text(encoding="utf-8")) or {}
    wanted = _resolve_aircraft(catalogue, aircraft) if aircraft else None
    kept: dict[str, Any] = {}
    for category, block in catalogue.items():
        if not isinstance(block, dict):
            continue
        sides_kept: dict[str, Any] = {}
        for side, countries in (block.get("coalitions") or {}).items():
            if side not in sides:
                continue
            countries_kept = {
                country: {
                    name: group
                    for name, group in (groups or {}).items()
                    if wanted is None or (isinstance(group, dict) and _template_types(group) & wanted)
                }
                for country, groups in (countries or {}).items()
            }
            countries_kept = {country: groups for country, groups in countries_kept.items() if groups}
            if countries_kept:
                sides_kept[side] = countries_kept
        kept[category] = {"coalitions": sides_kept}
    header = _SLOTS_HEADER.format(coalitions=", ".join(sides))
    text = header + yaml.safe_dump(kept, sort_keys=False, allow_unicode=True)
    _write_backed_up(folder / "src" / "dynamic-slot-templates.yaml", text.encode("utf-8"))
    if wanted is not None:
        return t("mcp.adapt.slots_aircraft", coalitions=", ".join(sides), aircraft=", ".join(sorted(wanted)))
    return t("mcp.adapt.slots", coalitions=", ".join(sides))


def _adapt_mission_yaml(
    folder: Path, mission_name: str | None, era: str | None, language: str | None, skynet: bool | None
) -> str | None:
    """Set `mission.name`, `mission.era`, `mission.language` and the SKYNET module in `mission.yaml`."""
    path = mission_yaml_path(folder)
    parts = []
    if mission_name is not None or era is not None or language is not None:
        data = load_yaml(path)
        mission = data.get("mission")
        if mission is None:
            mission = {}
            data["mission"] = mission
        if mission_name is not None:
            mission["name"] = mission_name
            parts.append(t("mcp.adapt.mission_name", name=mission_name))
        if era is not None:
            mission["era"] = era
            parts.append(t("mcp.adapt.mission_era", era=era))
        if language is not None:
            mission["language"] = language
            parts.append(t("mcp.adapt.mission_language", language=language))
        save_yaml(path, data)
    if skynet is not None:
        set_mission_module(path, "SKYNET", skynet)
        parts.append(t("mcp.adapt.skynet_on" if skynet else "mcp.adapt.skynet_off"))
    return t("mcp.adapt.mission_yaml", details=", ".join(parts)) if parts else None


def adapt_scaffold(
    folder: Path,
    *,
    mission_name: str | None = None,
    era: str | None = None,
    language: str | None = None,
    date: str | None = None,
    start_time: str | None = None,
    variant: str | None = None,
    position: dict[str, Any] | None = None,
    airfields: list[str] | None = None,
    waypoints: list[dict[str, Any]] | None = None,
    dynamic_slot_coalitions: list[str] | None = None,
    dynamic_slot_aircraft: list[str] | None = None,
    skynet: bool | None = None,
) -> dict[str, Any]:
    """Fit a scaffolded mission folder to the mission asked for: steps 1 to 5 of the authoring guide.

    Every value is checked before anything is written. What is not given is left as the scaffold has
    it, except two things that are always wrong for a real mission: the example waypoints, removed while
    they are there, and the airfield lists of the other theatres in `src/presets.yaml`. Each file rewritten
    whole is backed up first, in the folder's `.veaf-backups/`.

    Args:
        folder: The mission folder `scaffold_mission` laid down.
        mission_name: `mission.name`, ASCII.
        era: `mission.era`: MODERN, COLD_WAR or WW2.
        language: `mission.language`, `fr` or `en`: the user's, for the in-game messages and the briefing.
        date: The mission's date, YYYY-MM-DD: the blank mission's and `versions.yaml` `base_date`.
        start_time: HH:MM on the theatre's clock: the blank mission's and the weather variant's.
        variant: The weather variant's name; by default named after `start_time` (`morning`, `noon`…).
        position: Where the mission flies, for sunrise and sunset: `{latitude, longitude}` or the map's
            `{x, y}`, `timezone` optional (the nominal zone of the longitude by default).
        airfields: The airfields on the second radio, channel 1 first (names of the theatre).
        waypoints: The route every player flight gets, `[{name, x, y, alt?}]` (alt in metres).
        dynamic_slot_coalitions: The coalitions whose dynamic-slot templates stay (`blue`, `red`).
        dynamic_slot_aircraft: The aircraft the players fly (`F/A-18C`, `FA-18C_hornet`): only their templates
            stay; a name the catalogue does not have is refused with its types.
        skynet: Turn the SKYNET module on (a SAM or an EWR zone) or off.

    Returns:
        `{"folder", "changes": [one line per file]}`.

    Raises:
        ValueError: A bad value, an airfield the theatre does not have, or a folder that is not a mission.
    """
    _check(mission_name, era, date, start_time, position, waypoints, dynamic_slot_coalitions)
    if language is not None and language not in LANGUAGES:
        raise ValueError(f"adapt_scaffold: language must be one of {', '.join(LANGUAGES)}")
    theatre = mission_theatre(folder)
    presets = yaml.safe_load((folder / "src" / "presets.yaml").read_text(encoding="utf-8")) or {}
    if airfields:
        _resolve_airfields(presets, theatre, airfields)
    needs_catalogue = bool(dynamic_slot_aircraft) or (
        dynamic_slot_coalitions is not None and set(dynamic_slot_coalitions) != set(COALITIONS)
    )
    if needs_catalogue:
        shipped = shipped_default_file(folder, "src/dynamic-slot-templates.yaml")
        if shipped is None:
            raise ValueError("adapt_scaffold: the shipped dynamic-slot catalogue is not in the folder (published/)")
        if dynamic_slot_aircraft:
            _resolve_aircraft(yaml.safe_load(shipped.read_text(encoding="utf-8")) or {}, dynamic_slot_aircraft)
    changes = [_adapt_presets(folder, theatre, airfields)]
    changes.append(
        _adapt_versions(folder, theatre, date, start_time, variant, position)
        or t("mcp.adapt.unchanged", file="src/versions.yaml")
    )
    changes.append(_adapt_waypoints(folder, waypoints) or t("mcp.adapt.unchanged", file="src/waypoints.yaml"))
    changes.append(
        _adapt_dynamic_slots(folder, dynamic_slot_coalitions, dynamic_slot_aircraft)
        or t("mcp.adapt.unchanged", file="src/dynamic-slot-templates.yaml")
    )
    changes.append(
        _adapt_mission_yaml(folder, mission_name, era, language, skynet)
        or t("mcp.adapt.unchanged", file="mission.yaml")
    )
    if date is not None or start_time is not None:
        written = set_mission_date(folder, date=date, start_time=start_time)
        changes.append(t("mcp.adapt.mission_date", date=written["date"], start_time=written["start_time"]))
    return {"folder": str(folder), "changes": changes}
