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
#: The coalitions that can get dynamic slots.
COALITIONS: tuple[str, ...] = ("blue", "red")
#: Default altitude of a route point, in metres (20 000 ft, the scaffold's example).
DEFAULT_WAYPOINT_ALT = 6096.0

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
    unknown = sorted(set(dynamic_slot_coalitions or []) - set(COALITIONS))
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


def _adapt_presets(folder: Path, theatre: str, airfields: list[str] | None) -> str:
    """Fit `src/presets.yaml` to the theatre: its airfields on the second radio, no other theatre's list."""
    path = folder / "src" / "presets.yaml"
    text = path.read_bytes().decode("utf-8")  # its own line ends, kept on write
    presets = yaml.safe_load(text) or {}
    keep = theatre_collection(presets, theatre)
    text, removed = _drop_other_theatres(text, keep)
    parts = []
    if airfields:
        chosen = _resolve_airfields(presets, theatre, airfields)
        text = rewrite_primary_2(text, chosen)
        parts.append(t("mcp.adapt.presets_radio", airfields=", ".join(chosen)))
    if removed:
        parts.append(t("mcp.adapt.presets_dropped", count=len(removed)))
    path.write_bytes(text.encode("utf-8"))
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


def _adapt_waypoints(folder: Path, waypoints: list[dict[str, Any]] | None) -> str:
    """Write the mission's route in `src/waypoints.yaml`, or no point at all, in place of the examples."""
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
    (folder / "src" / "waypoints.yaml").write_text(text, encoding="utf-8")
    if not points:
        return t("mcp.adapt.waypoints_none")
    return t("mcp.adapt.waypoints", count=len(points), keys=", ".join(points))


def _adapt_dynamic_slots(folder: Path, coalitions: list[str] | None) -> str | None:
    """Keep the shipped dynamic-slot catalogue's templates of the coalitions named only."""
    if coalitions is None or set(coalitions) == set(COALITIONS):
        return None
    shipped = shipped_default_file(folder, "src/dynamic-slot-templates.yaml")
    if shipped is None:
        raise ValueError("adapt_scaffold: the shipped dynamic-slot catalogue is not in the folder (published/)")
    catalogue = yaml.safe_load(shipped.read_text(encoding="utf-8")) or {}
    kept = {
        category: {
            "coalitions": {
                side: groups for side, groups in (block.get("coalitions") or {}).items() if side in coalitions
            }
        }
        for category, block in catalogue.items()
        if isinstance(block, dict)
    }
    header = _SLOTS_HEADER.format(coalitions=", ".join(coalitions) or "no coalition")
    text = header + yaml.safe_dump(kept, sort_keys=False, allow_unicode=True)
    (folder / "src" / "dynamic-slot-templates.yaml").write_text(text, encoding="utf-8")
    return t("mcp.adapt.slots", coalitions=", ".join(coalitions) or "-")


def _adapt_mission_yaml(folder: Path, mission_name: str | None, era: str | None, skynet: bool | None) -> str | None:
    """Set `mission.name`, `mission.era` and the SKYNET module in `mission.yaml`."""
    path = mission_yaml_path(folder)
    parts = []
    if mission_name is not None or era is not None:
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
    date: str | None = None,
    start_time: str | None = None,
    variant: str | None = None,
    position: dict[str, Any] | None = None,
    airfields: list[str] | None = None,
    waypoints: list[dict[str, Any]] | None = None,
    dynamic_slot_coalitions: list[str] | None = None,
    skynet: bool | None = None,
) -> dict[str, Any]:
    """Fit a scaffolded mission folder to the mission asked for: steps 1 to 5 of the authoring guide.

    Every value is checked before anything is written. What is not given is left as the scaffold has
    it, except two things that are always wrong for a real mission: the example waypoints, removed, and
    the airfield lists of the other theatres in `src/presets.yaml`.

    Args:
        folder: The mission folder `scaffold_mission` laid down.
        mission_name: `mission.name`, ASCII.
        era: `mission.era`: MODERN, COLD_WAR or WW2.
        date: The mission's date, YYYY-MM-DD: the blank mission's and `versions.yaml` `base_date`.
        start_time: HH:MM on the theatre's clock: the blank mission's and the weather variant's.
        variant: The weather variant's name; by default named after `start_time` (`morning`, `noon`…).
        position: Where the mission flies, for sunrise and sunset: `{latitude, longitude}` or the map's
            `{x, y}`, `timezone` optional (the nominal zone of the longitude by default).
        airfields: The airfields on the second radio, channel 1 first (names of the theatre).
        waypoints: The route every player flight gets, `[{name, x, y, alt?}]` (alt in metres).
        dynamic_slot_coalitions: The coalitions whose dynamic-slot templates stay (`blue`, `red`).
        skynet: Turn the SKYNET module on (a SAM or an EWR zone) or off.

    Returns:
        `{"folder", "changes": [one line per file]}`.

    Raises:
        ValueError: A bad value, an airfield the theatre does not have, or a folder that is not a mission.
    """
    _check(mission_name, era, date, start_time, position, waypoints, dynamic_slot_coalitions)
    theatre = mission_theatre(folder)
    presets = yaml.safe_load((folder / "src" / "presets.yaml").read_text(encoding="utf-8")) or {}
    if airfields:
        _resolve_airfields(presets, theatre, airfields)
    changes = [_adapt_presets(folder, theatre, airfields)]
    changes.append(
        _adapt_versions(folder, theatre, date, start_time, variant, position)
        or t("mcp.adapt.unchanged", file="src/versions.yaml")
    )
    changes.append(_adapt_waypoints(folder, waypoints))
    changes.append(
        _adapt_dynamic_slots(folder, dynamic_slot_coalitions)
        or t("mcp.adapt.unchanged", file="src/dynamic-slot-templates.yaml")
    )
    changes.append(
        _adapt_mission_yaml(folder, mission_name, era, skynet) or t("mcp.adapt.unchanged", file="mission.yaml")
    )
    if date is not None or start_time is not None:
        written = set_mission_date(folder, date=date, start_time=start_time)
        changes.append(t("mcp.adapt.mission_date", date=written["date"], start_time=written["start_time"]))
    return {"folder": str(folder), "changes": changes}
