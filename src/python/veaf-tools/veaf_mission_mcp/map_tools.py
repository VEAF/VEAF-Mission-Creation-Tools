"""Map awareness + coordinate conversion for the LLM (wave 10).

`describe_map` lets the caller orient itself in a mission design-time (theatre, bullseyes, existing
zones/groups as reference points) without a running DCS. `resolve_coordinates` converts a position
between DCS local `x/y` and geographic `lat/lon` for the mission's theatre, reading the theatre from
the mission so the caller never supplies projection parameters. See
``.backlog/FEAT-MCP-MISSION-EDITOR/PRD.md`` (wave 10).
"""

from pathlib import Path
from typing import Any

from mission_tools.miz_tools import DcsMission, read_miz
from veaf_libs import coordinates, dcs_airdromes

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
        groups reuse the `describe_mission` extraction as reference points.

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
        "groups": _list_groups(content),
    }


def resolve_coordinates(mission_path: Path, position: dict[str, float]) -> dict[str, Any]:
    """Convert a position between DCS `x/y` and geographic `lat/lon` for the mission's theatre.

    Args:
        mission_path: A `.miz` file or mission folder (its theatre drives the projection).
        position: Either ``{"x", "y"}`` (DCS local) or ``{"lat", "lon"}`` (decimal degrees). If both
            are present, ``{x, y}`` takes precedence.

    Returns:
        ``{theatre, xy: {x, y}, latlon: {lat, lon}}`` — both representations of the same point.

    Raises:
        ValueError: when the mission has no theatre, the theatre is unsupported, or ``position`` is
            neither a complete ``{x, y}`` nor a complete ``{lat, lon}``.
    """
    theatre = _theatre(mission_path)
    return {"theatre": theatre, **_convert(theatre, position)}


def resolve_coordinates_batch(mission_path: Path, positions: list[dict[str, float]]) -> dict[str, Any]:
    """Convert several positions at once, in the order given; the mission is read once.

    Args:
        mission_path: A `.miz` file or mission folder (its theatre drives the projection).
        positions: Each one as :func:`resolve_coordinates` takes it.

    Returns:
        ``{theatre, points: [{xy, latlon}, ...]}``, one point per position.

    Raises:
        ValueError: when the mission has no usable theatre, or a position is incomplete — named
            by its 0-based index.
    """
    theatre = _theatre(mission_path)
    points: list[dict[str, Any]] = []
    for index, position in enumerate(positions):
        try:
            points.append(_convert(theatre, position))
        except ValueError as exc:
            raise ValueError(f"positions[{index}]: {exc}") from exc
    return {"theatre": theatre, "points": points}


def _theatre(mission_path: Path) -> str:
    """Return the mission's theatre, or refuse when it has none."""
    theatre = _load_mission(mission_path).theatre_content
    if not theatre:
        raise ValueError(f"Mission has no theatre, cannot convert coordinates: {mission_path}")
    return str(theatre)


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


def list_airfields(*, mission_path: Path | None = None, theatre: str | None = None) -> dict[str, Any]:
    """List a theatre's airbases — name, id and position — from the data shipped with the tools.

    Args:
        mission_path: A `.miz` or mission folder whose theatre to list; wins over ``theatre``.
        theatre: A DCS theatre name, when there is no mission yet.

    Returns:
        ``{theatre, airfields: [{name, id, lat, lon, x?, y?}]}`` — ``x``/``y`` (DCS local metres) when
        the theatre's projection is known, so a result can be placed on directly.

    Raises:
        ValueError: when neither is given, or the theatre has no airbase data.
    """
    if mission_path is not None:
        theatre = _theatre(mission_path)
    if not theatre:
        raise ValueError("list_airfields needs mission_path or theatre")
    airfields = dcs_airdromes.airfields_for_theatre(theatre)
    if not airfields:
        raise ValueError(f"No airbase data for theatre {theatre!r}")
    projected = theatre.lower() in {name.lower() for name in coordinates.supported_theatres()}
    for airfield in airfields:
        if projected:
            airfield["x"], airfield["y"] = coordinates.latlon_to_xy(theatre, airfield["lat"], airfield["lon"])
    return {"theatre": theatre, "airfields": airfields}
