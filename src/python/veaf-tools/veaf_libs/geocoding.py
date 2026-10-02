"""Pluggable geocoding: resolve a real-world place name to coordinates.

DCS theatres are the real world projected, so a place name → lat/lon (here) → DCS x/y (via
:mod:`veaf_libs.coordinates`) lets tooling place things by real geography. Backend-swappable:
**OpenStreetMap Nominatim** by default (free, no key) and **Google Maps** when an API key is
configured. See ``.backlog/archive/FEAT-GEO-PLACEMENT.md``.

Nominatim usage policy: low-volume authoring calls only, a descriptive ``User-Agent``, and
attribution of © OpenStreetMap contributors in any surfaced result.
"""

import os
import time
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

#: Nominatim's usage policy: one request a second at most, per process here.
_MIN_INTERVAL_S = 1.0
_last_request = float("-inf")
_TOO_MANY_REQUESTS = 429
#: How long a 429 is waited out once: what ``Retry-After`` asks, bounded; a short back-off without it.
_DEFAULT_BACKOFF_S = 5.0
_MAX_BACKOFF_S = 30.0
#: How many candidates a query asks for.
_CANDIDATES = 5

#: OpenStreetMap classes that are a road or an area, not a place one can stand at.
_ROAD_OR_REGION_CLASSES: frozenset[str] = frozenset({"highway", "boundary"})
#: ``place`` types that are regions.
_REGION_PLACES: frozenset[tuple[str, str]] = frozenset(
    ("place", kind) for kind in ("country", "state", "region", "province", "county", "district", "municipality")
)


@dataclass(frozen=True)
class Bounds:
    """A lat/lon bounding box used to bias/disambiguate a geocoder query."""

    min_lat: float
    min_lon: float
    max_lat: float
    max_lon: float


@dataclass(frozen=True)
class GeocodeResult:
    """A resolved place: decimal-degree coordinates plus the backend's display name.

    ``osm_class`` and ``osm_type`` are OpenStreetMap's (``place``/``town``, ``highway``/``residential``,
    ``boundary``/``administrative``); ``None`` from a backend that does not give them.
    """

    lat: float
    lon: float
    display_name: str
    osm_class: str | None = None
    osm_type: str | None = None

    @property
    def is_road_or_region(self) -> bool:
        """Whether this is a road or an administrative area rather than a place one can stand at."""
        return self.osm_class in _ROAD_OR_REGION_CLASSES or (self.osm_class, self.osm_type) in _REGION_PLACES


class GeocodingRefusedError(RuntimeError):
    """The geocoding service refused the request (HTTP 429), even after waiting once."""


class Geocoder(Protocol):
    """A geocoder resolves a place name to a :class:`GeocodeResult` (or ``None`` on a miss)."""

    def geocode(self, query: str, *, bounds: Bounds | None = None) -> GeocodeResult | None: ...


def _pace() -> None:
    """Wait until a second has passed since the previous Nominatim request of this process.

    Twenty-one calls in a row got the Syria session banned for over half an hour: Nominatim's usage
    policy asks for one request a second at most (FIX-OPEN-TRAINING-SYRIA-FINDINGS ticket 07).
    """
    global _last_request  # noqa: PLW0603 - one pace per process, which is what the policy counts
    wait = _last_request + _MIN_INTERVAL_S - time.monotonic()
    if wait > 0:
        time.sleep(wait)
    _last_request = time.monotonic()


def _retry_after(response: requests.Response) -> float:
    """Return how long a 429 asks to wait, bounded, or a short back-off when it does not say."""
    try:
        asked = float(response.headers.get("Retry-After", ""))
    except ValueError:
        asked = _DEFAULT_BACKOFF_S
    return min(max(asked, 0.0), _MAX_BACKOFF_S)


class NominatimGeocoder:
    """OpenStreetMap Nominatim backend (default; free, no API key)."""

    def geocode(self, query: str, *, bounds: Bounds | None = None) -> GeocodeResult | None:
        """Resolve ``query``, preferring a named place over a road or a region.

        Several candidates are asked for: ``limit: 1`` took the first answer whatever it was, and
        « Al-Kiswah » came back as a street of Amman (FIX-OPEN-TRAINING-SYRIA-FINDINGS ticket 07).
        Nominatim often has a single candidate, so the class and type are returned for the caller to
        judge, and a road or a region is only chosen when nothing else came back.

        Raises:
            GeocodingRefusedError: When Nominatim answers 429 twice, the second time after waiting
                what it asked (bounded).
        """
        params: dict[str, str | int] = {"q": query, "format": "jsonv2", "limit": _CANDIDATES}
        if bounds is not None:
            # Nominatim viewbox order is lon,lat,lon,lat (x1,y1,x2,y2); `bounded=1` restricts to it.
            params["viewbox"] = f"{bounds.min_lon},{bounds.max_lat},{bounds.max_lon},{bounds.min_lat}"
            params["bounded"] = 1
        response = self._get(params)
        if response.status_code == _TOO_MANY_REQUESTS:
            time.sleep(_retry_after(response))
            response = self._get(params)
            if response.status_code == _TOO_MANY_REQUESTS:
                message = (
                    "Nominatim refused the request (HTTP 429, too many requests). Its usage policy allows "
                    "one request a second; a ban can last more than half an hour, so wait before trying again"
                )
                raise GeocodingRefusedError(message)
        response.raise_for_status()
        candidates = [
            GeocodeResult(
                float(hit["lat"]),
                float(hit["lon"]),
                hit.get("display_name", query),
                # jsonv2 names the class `category`; the json format names it `class`.
                hit.get("category") or hit.get("class"),
                hit.get("type"),
            )
            for hit in response.json()
        ]
        if not candidates:
            return None
        return next((c for c in candidates if not c.is_road_or_region), candidates[0])

    @staticmethod
    def _get(params: dict[str, str | int]) -> requests.Response:
        _pace()
        return requests.get(_NOMINATIM_URL, params=params, headers={"User-Agent": _USER_AGENT}, timeout=_TIMEOUT)


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
