"""Pluggable geocoding: resolve a real-world place name to coordinates.

DCS theatres are the real world projected, so a place name → lat/lon (here) → DCS x/y (via
:mod:`veaf_libs.coordinates`) lets tooling place things by real geography. Backend-swappable:
**OpenStreetMap Nominatim** by default (free, no key) and **Google Maps** when an API key is
configured. See ``.backlog/FEAT-GEO-PLACEMENT/PRD.md``.

Nominatim usage policy: low-volume authoring calls only, a descriptive ``User-Agent``, and
attribution of © OpenStreetMap contributors in any surfaced result.
"""

import os
from dataclasses import dataclass
from functools import lru_cache
from typing import Any, Protocol

import requests
import yaml

from veaf_libs.bundled_data import read_bundled_text

#: Descriptive User-Agent required by the Nominatim usage policy.
_USER_AGENT = "veaf-tools (+https://github.com/VEAF/VEAF-Mission-Creation-Tools)"
_NOMINATIM_URL = "https://nominatim.openstreetmap.org/search"
_GOOGLE_URL = "https://maps.googleapis.com/maps/api/geocode/json"
_TIMEOUT = 20
#: Environment variable holding a Google Maps Geocoding API key (opt-in backend).
_GOOGLE_KEY_ENV = "GOOGLE_MAPS_API_KEY"


@dataclass(frozen=True)
class Bounds:
    """A lat/lon bounding box used to bias/disambiguate a geocoder query."""

    min_lat: float
    min_lon: float
    max_lat: float
    max_lon: float


@dataclass(frozen=True)
class GeocodeResult:
    """A resolved place: decimal-degree coordinates plus the backend's display name."""

    lat: float
    lon: float
    display_name: str


class Geocoder(Protocol):
    """A geocoder resolves a place name to a :class:`GeocodeResult` (or ``None`` on a miss)."""

    def geocode(self, query: str, *, bounds: Bounds | None = None) -> GeocodeResult | None: ...


class NominatimGeocoder:
    """OpenStreetMap Nominatim backend (default; free, no API key)."""

    def geocode(self, query: str, *, bounds: Bounds | None = None) -> GeocodeResult | None:
        params: dict[str, str | int] = {"q": query, "format": "jsonv2", "limit": 1}
        if bounds is not None:
            # Nominatim viewbox order is lon,lat,lon,lat (x1,y1,x2,y2); `bounded=1` restricts to it.
            params["viewbox"] = f"{bounds.min_lon},{bounds.max_lat},{bounds.max_lon},{bounds.min_lat}"
            params["bounded"] = 1
        response = requests.get(_NOMINATIM_URL, params=params, headers={"User-Agent": _USER_AGENT}, timeout=_TIMEOUT)
        response.raise_for_status()
        results = response.json()
        if not results:
            return None
        hit = results[0]
        return GeocodeResult(float(hit["lat"]), float(hit["lon"]), hit.get("display_name", query))


class GoogleGeocoder:
    """Google Maps Geocoding backend (used when an API key is configured)."""

    def __init__(self, api_key: str) -> None:
        self._api_key = api_key

    def geocode(self, query: str, *, bounds: Bounds | None = None) -> GeocodeResult | None:
        params: dict[str, str] = {"address": query, "key": self._api_key}
        if bounds is not None:
            params["bounds"] = f"{bounds.min_lat},{bounds.min_lon}|{bounds.max_lat},{bounds.max_lon}"
        response = requests.get(_GOOGLE_URL, params=params, timeout=_TIMEOUT)
        response.raise_for_status()
        results = response.json().get("results") or []
        if not results:
            return None
        location = results[0]["geometry"]["location"]
        return GeocodeResult(location["lat"], location["lng"], results[0].get("formatted_address", query))


@lru_cache(maxsize=1)
def _bounds_table() -> dict[str, dict[str, Any]]:
    """Load the per-theatre bounding-box table (lowercased keys). Cached — static data."""
    raw = yaml.safe_load(read_bundled_text("veaf_libs", "data", "theatre-bounds.yaml")) or {}
    return {str(k).lower(): v for k, v in raw.items()}


def theatre_bounds(theatre: str) -> Bounds | None:
    """Return the approximate bounding box for ``theatre`` (case-insensitive), or ``None``.

    ``None`` means "no bias" — a caller degrades gracefully to an unrestricted geocoder query.
    """
    entry = _bounds_table().get(theatre.lower())
    if entry is None:
        return None
    return Bounds(entry["min_lat"], entry["min_lon"], entry["max_lat"], entry["max_lon"])


def get_geocoder(api_key: str | None = None) -> Geocoder:
    """Return the configured geocoder: Google if an API key is available, else OSM Nominatim.

    Args:
        api_key: An explicit Google Maps key; falls back to the ``GOOGLE_MAPS_API_KEY`` env var.

    Returns:
        A :class:`Geocoder` — :class:`GoogleGeocoder` when a key is present, else
        :class:`NominatimGeocoder`.
    """
    key = api_key or os.environ.get(_GOOGLE_KEY_ENV)
    return GoogleGeocoder(key) if key else NominatimGeocoder()
