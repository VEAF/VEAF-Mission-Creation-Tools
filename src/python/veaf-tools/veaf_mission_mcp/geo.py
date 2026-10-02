"""`geocode` — resolve a real-world place (name, optional bearing/distance) to DCS coordinates.

DCS theatres are the real world projected, so a place name geocodes to lat/lon and projects to the
mission theatre's DCS x/y. Optional bearing + distance handle "10 km north of X". Results are
approximate (DCS terrain approximates reality) and always surfaced for the caller to sanity-check.
See ``.backlog/archive/FEAT-GEO-PLACEMENT.md``.
"""

from pathlib import Path
from typing import Any

from veaf_libs import coordinates, geocoding

from veaf_mission_mcp.map_tools import _load_mission


def _within(bounds: geocoding.Bounds, lat: float, lon: float) -> bool:
    return bounds.min_lat <= lat <= bounds.max_lat and bounds.min_lon <= lon <= bounds.max_lon


def geocode(
    mission_path: Path,
    query: str,
    *,
    bearing: float | None = None,
    distance_km: float | None = None,
    api_key: str | None = None,
) -> dict[str, Any]:
    """Resolve ``query`` to coordinates for the mission's theatre.

    Args:
        mission_path: A `.miz` or mission folder (its theatre drives the projection + bounds).
        query: A real-world place name ("Batumi", "Kobuleti airport").
        bearing: Optional bearing in degrees (clockwise from north) for a relative offset.
        distance_km: Optional distance in kilometres, applied along ``bearing``.
        api_key: Optional Google Maps key (else OSM Nominatim).

    Returns:
        ``{query, found, display_name, osm_class, osm_type, theatre, latlon: {lat, lon},
        xy: {x, y} | None, in_theatre_bounds, warnings}``. ``found`` is ``False`` when the geocoder
        returns no hit, or refuses the request (said in ``warnings``); a road or a region is warned
        about (FIX-OPEN-TRAINING-SYRIA-FINDINGS ticket 07).

    Raises:
        ValueError: when the mission has no theatre.
    """
    mission = _load_mission(mission_path)
    theatre = mission.theatre_content
    if not theatre:
        raise ValueError(f"Mission has no theatre, cannot geocode: {mission_path}")
    if (bearing is None) != (distance_km is None):
        raise ValueError("bearing and distance_km must be given together (or neither).")

    bounds = geocoding.theatre_bounds(theatre)
    try:
        hit = geocoding.get_geocoder(api_key).geocode(query, bounds=bounds)
        miss_warning = "no geocoding result"
    except geocoding.GeocodingRefusedError as refused:
        hit, miss_warning = None, str(refused)
    if hit is None:
        # Stable shape: same keys as a hit, nulled — callers never special-case the fields.
        return {
            "query": query,
            "found": False,
            "display_name": None,
            "osm_class": None,
            "osm_type": None,
            "theatre": theatre,
            "latlon": None,
            "xy": None,
            "in_theatre_bounds": None,
            "warnings": [miss_warning],
        }

    lat, lon = hit.lat, hit.lon
    if bearing is not None and distance_km is not None:
        lat, lon = coordinates.offset_latlon(lat, lon, bearing, distance_km * 1000.0)

    warnings: list[str] = []
    if hit.is_road_or_region:
        warnings.append(
            f"the answer is a {hit.osm_class}/{hit.osm_type}, not a named place: a road or an administrative "
            "area — check it is the place you meant, or search a nearby town or landmark"
        )
    xy: dict[str, float] | None = None
    if coordinates.is_theatre_supported(theatre):
        x, y = coordinates.latlon_to_xy(theatre, lat, lon)
        xy = {"x": x, "y": y}
    else:
        warnings.append(f"theatre '{theatre}' has no x/y projection; only lat/lon returned")

    in_bounds = bounds is None or _within(bounds, lat, lon)
    if bounds is not None and not in_bounds:
        warnings.append("resolved point is outside the theatre bounds — verify it is the place you meant")

    return {
        "query": query,
        "found": True,
        "display_name": hit.display_name,
        "osm_class": hit.osm_class,
        "osm_type": hit.osm_type,
        "theatre": theatre,
        "latlon": {"lat": lat, "lon": lon},
        "xy": xy,
        "in_theatre_bounds": in_bounds,
        "warnings": warnings,
    }
