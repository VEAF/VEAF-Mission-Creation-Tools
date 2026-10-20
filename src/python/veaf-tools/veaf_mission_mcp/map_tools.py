"""Map awareness + coordinate conversion for the LLM (wave 10).

`describe_map` lets the caller orient itself in a mission design-time (theatre, bullseyes, existing
zones/groups as reference points) without a running DCS. `resolve_coordinates` converts a position
between DCS local `x/y` and geographic `lat/lon` for the mission's theatre, reading the theatre from
the mission so the caller never supplies projection parameters. See
``.backlog/archive/FEAT-MCP-MISSION-EDITOR.md`` (wave 10).
"""

from pathlib import Path
from typing import Any

from mission_tools.miz_tools import DcsMission, read_miz
from presets_injector.airfield_channels_manager import load_reference
from veaf_libs import coordinates, dcs_airdromes, dcs_parking

from veaf_mission_mcp.describe_mission import _list_groups, _list_zones
from veaf_mission_mcp.mission_folder import load_folder_mission


def _load_mission(mission_path: Path) -> DcsMission:
    """Load a mission from either a `.miz` file or an exploded mission folder."""
    return load_folder_mission(mission_path) if mission_path.is_dir() else read_miz(mission_path)


def _bullseyes(content: dict[str, Any]) -> dict[str, dict[str, float]]:
    """Extract each coalition's bullseye position from the mission content."""
    result: dict[str, dict[str, float]] = {}
    for side, coalition in (content.get("coalition") or {}).items():
        if isinstance(coalition, dict) and isinstance(coalition.get("bullseye"), dict):
            bullseye = coalition["bullseye"]
            result[side] = {"x": bullseye.get("x"), "y": bullseye.get("y")}
    return result


def describe_map(mission_path: Path) -> dict[str, Any]:
    """Summarize a mission's map for orientation: theatre, bullseyes, and reference points.

    Args:
        mission_path: A `.miz` file or a mission folder.

    Returns:
        ``{theatre, bullseyes: {coalition: {x, y}}, zones: [...], groups: [...]}`` — zones and
        groups reuse the `describe_mission` extraction as reference points; each group also carries
        its ``x`` / ``y`` and its number of ``units``.

    Raises:
        ValueError: when the mission has no readable content.
    """
    mission = _load_mission(mission_path)
    content = mission.mission_content
    if content is None:
        raise ValueError(f"Not a valid DCS mission (missing 'mission' content): {mission_path}")
    return {
        "theatre": mission.theatre_content,
        "bullseyes": _bullseyes(content),
        "zones": _list_zones(content),
        "groups": _list_groups(content, with_position=True),
    }


def resolve_coordinates(
    mission_path: Path | None, position: dict[str, float], *, theatre: str | None = None
) -> dict[str, Any]:
    """Convert a position between DCS `x/y` and geographic `lat/lon` for the mission's theatre.

    Args:
        mission_path: A `.miz` file or mission folder (its theatre drives the projection); None
            before there is one.
        position: Either ``{"x", "y"}`` (DCS local) or ``{"lat", "lon"}`` (decimal degrees). If both
            are present, ``{x, y}`` takes precedence.
        theatre: The theatre, when there is no mission (FIX-OPENCODE-TEST-FINDINGS 03).

    Returns:
        ``{theatre, xy: {x, y}, latlon: {lat, lon}}`` — both representations of the same point.

    Raises:
        ValueError: when there is neither a mission nor a theatre, the mission has no theatre, the
            theatre is unsupported, or ``position`` is neither a complete ``{x, y}`` nor a complete
            ``{lat, lon}``.
    """
    theatre = theatre_of(mission_path, theatre)
    return {"theatre": theatre, **_convert(theatre, position)}


def resolve_coordinates_batch(
    mission_path: Path | None, positions: list[dict[str, float]], *, theatre: str | None = None
) -> dict[str, Any]:
    """Convert several positions at once, in the order given; the mission is read once.

    Args:
        mission_path: A `.miz` file or mission folder (its theatre drives the projection); None
            before there is one.
        positions: Each one as :func:`resolve_coordinates` takes it.
        theatre: The theatre, when there is no mission.

    Returns:
        ``{theatre, points: [{xy, latlon}, ...]}``, one point per position.

    Raises:
        ValueError: when the mission has no usable theatre, or a position is incomplete — named
            by its 0-based index.
    """
    theatre = theatre_of(mission_path, theatre)
    points: list[dict[str, Any]] = []
    for index, position in enumerate(positions):
        try:
            points.append(_convert(theatre, position))
        except ValueError as exc:
            raise ValueError(f"positions[{index}]: {exc}") from exc
    return {"theatre": theatre, "points": points}


def mission_theatre(mission_path: Path) -> str:
    """Return the mission's theatre, or refuse when it has none."""
    theatre = _load_mission(mission_path).theatre_content
    if not theatre:
        raise ValueError(f"Mission has no theatre, cannot convert coordinates: {mission_path}")
    return str(theatre)


def theatre_of(mission_path: Path | None, theatre: str | None) -> str:
    """Return the theatre an action works in: the mission's, else the one named.

    Phase 1 of a mission prompt runs before any folder exists; with only a mission path to give, the
    AI fitted its own lat/lon model on `list_airfields`, 5 km off (FIX-OPENCODE-TEST-FINDINGS 03).

    Args:
        mission_path: A `.miz` or mission folder; wins over ``theatre``.
        theatre: A theatre name, in any case.

    Returns:
        The theatre, in DCS spelling when the tools know it.

    Raises:
        ValueError: when neither is given, or the mission has no theatre.
    """
    if mission_path is not None:
        return mission_theatre(mission_path)
    if not theatre:
        raise ValueError("give mission_path, or theatre before there is a mission")
    known = {name.lower(): name for name in coordinates.supported_theatres()}
    return known.get(theatre.strip().lower(), theatre.strip())


def _convert(theatre: str, position: dict[str, float]) -> dict[str, Any]:
    """Return ``{xy, latlon}`` for one position; ``{x, y}`` wins when both forms are given."""
    # {x, y} takes precedence when both forms are present (mirrored in the action schema doc).
    if position.get("x") is not None and position.get("y") is not None:
        x, y = float(position["x"]), float(position["y"])
        lat, lon = coordinates.xy_to_latlon(theatre, x, y)
    elif position.get("lat") is not None and position.get("lon") is not None:
        lat, lon = float(position["lat"]), float(position["lon"])
        x, y = coordinates.latlon_to_xy(theatre, lat, lon)
    else:
        got = ", ".join(sorted(position)) or "none"
        raise ValueError(f"position must be a complete {{x, y}} or {{lat, lon}}; got keys: {got}.")

    return {"xy": {"x": x, "y": y}, "latlon": {"lat": lat, "lon": lon}}


def _parking(theatre: str, airdrome_id: int) -> dict[str, int]:
    """Count an airfield's stands by the aircraft that can use them (a stand may serve both)."""
    stands = dcs_parking.stands_for_airbase(theatre, airdrome_id)
    return {
        "planes": sum(s.term_type in dcs_parking.PLANE_STAND_TYPES for s in stands),
        "helicopters": sum(s.term_type in dcs_parking.HELICOPTER_STAND_TYPES for s in stands),
    }


def list_airfields(
    *,
    mission_path: Path | None = None,
    theatre: str | None = None,
    name_contains: str | None = None,
    details: bool = False,
) -> dict[str, Any]:
    """List a theatre's airbases from the data shipped with the tools.

    Short by default: the answer stays in the AI's context to the end of its session, and every
    field for Syria's 223 airbases was 37k characters (FIX-OPENCODE-TEST-FINDINGS 06). The details
    answer what the AI read in the exe's own files before a mission existed: parking and the ATC
    frequencies (ticket 03).

    Args:
        mission_path: A `.miz` or mission folder whose theatre to list; wins over ``theatre``.
        theatre: A DCS theatre name, when there is no mission yet.
        name_contains: Keep only the airbases whose name holds this text, in any case.
        details: Add ``lat``/``lon``, ``parking`` (stands usable by ``planes`` and by
            ``helicopters``) and ``atc`` (``uhf``/``vhf``/``fm`` MHz, ``tacan``), as DCS gives them.

    Returns:
        ``{theatre, airfields: [{name, id, x, y}]}``, ``x``/``y`` in whole DCS metres when the
        theatre's projection is known, ``lat``/``lon`` otherwise; with a mission, each airbase's
        ``coalition`` too.

    Raises:
        ValueError: when neither is given, or the theatre has no airbase data.
    """
    coalitions: dict[int, str] = {}
    if mission_path is not None:
        mission = _load_mission(mission_path)
        theatre = mission.theatre_content or None
        if not theatre:
            raise ValueError(f"Mission has no theatre: {mission_path}")
        airports = (mission.warehouses_content or {}).get("airports") or {}
        coalitions = {
            int(key): str(entry.get("coalition", "NEUTRAL")).lower()
            for key, entry in airports.items()
            if isinstance(entry, dict) and str(key).isdigit()
        }
    if not theatre:
        raise ValueError("list_airfields needs mission_path or theatre")
    # DCS spelling: the frequency table is keyed by it, and `syria` gave every base an empty `atc`.
    theatre = theatre_of(None, theatre)
    airfields = dcs_airdromes.airfields_for_theatre(theatre)
    if not airfields:
        raise ValueError(f"No airbase data for theatre {theatre!r}")
    if name_contains:
        airfields = [a for a in airfields if name_contains.lower() in str(a["name"]).lower()]
    projected = coordinates.is_theatre_supported(theatre)
    reference = load_reference(theatre) if details else {}
    result = []
    for airfield in airfields:
        entry: dict[str, Any] = {"name": airfield["name"], "id": airfield["id"]}
        if projected:
            x, y = coordinates.latlon_to_xy(theatre, airfield["lat"], airfield["lon"])
            entry["x"], entry["y"] = round(x), round(y)
        if details or not projected:
            entry["lat"], entry["lon"] = round(airfield["lat"], 5), round(airfield["lon"], 5)
        if mission_path is not None:
            entry["coalition"] = coalitions.get(int(airfield["id"]), "neutral")
        if details:
            entry["parking"] = _parking(theatre, int(airfield["id"]))
            frequencies = reference.get(int(airfield["id"])) or {}
            entry["atc"] = {band: frequencies[band] for band in ("uhf", "vhf", "fm", "tacan") if band in frequencies}
        result.append(entry)
    return {"theatre": theatre, "airfields": result}
