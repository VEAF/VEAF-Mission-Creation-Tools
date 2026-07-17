"""Convert between DCS local coordinates (x/y, metres) and geographic lat/lon, per theatre.

The DCS ``coord.*`` conversions only exist in the in-game Lua runtime; this is a **pure-Python
port** of the Transverse Mercator (WGS84) forward/inverse used design-time, so tooling can place
things by lat/long without a running DCS. Each theatre has its own projection origin.

Ported from ``bfr-claude-plugins/plugins/dcs-mission-tools/tools/src/lib/projection.lua`` (MIT,
BFR / David Pierron & contributors). VEAF is Apache-2.0; MIT is compatible — attribution kept here.
See ``docs/adr/0015-coordinate-projection-port.md``.
"""

import math

# WGS84 ellipsoid + UTM scale, as in the source.
_A = 6378137.0
_F = 1 / 298.257223563
_K0 = 0.9996
_E2 = _F * (2 - _F)
_EP2 = _E2 / (1 - _E2)
_E4 = _E2 * _E2
_E6 = _E2 * _E2 * _E2

#: Per-theatre Transverse Mercator origin: central meridian (deg) + false offsets (metres).
_THEATRES: dict[str, dict[str, float]] = {
    "caucasus": {"lon0": 33, "x0": -99516.9999999732, "y0": -4998114.999999984},
    "syria": {"lon0": 39, "x0": 282801.00000003993, "y0": -3879865.9999999935},
    "persiangulf": {"lon0": 57, "x0": 75755.99999999645, "y0": -2894933.0000000377},
    "marianaislands": {"lon0": 147, "x0": 238417.99999989968, "y0": -1491840.000000048},
}


def supported_theatres() -> list[str]:
    """Return the theatre names coordinate conversion is available for (sorted)."""
    return sorted(_THEATRES)


def _theatre_params(theatre: str) -> dict[str, float]:
    """Return a theatre's projection params (case-insensitive), or raise ``ValueError``."""
    params = _THEATRES.get(theatre.lower())
    if params is None:
        raise ValueError(f"Unsupported theatre '{theatre}' (supported: {', '.join(supported_theatres())}).")
    return params


def _meridional_arc(phi: float) -> float:
    return _A * (
        (1 - _E2 / 4 - 3 * _E4 / 64 - 5 * _E6 / 256) * phi
        - (3 * _E2 / 8 + 3 * _E4 / 32 + 45 * _E6 / 1024) * math.sin(2 * phi)
        + (15 * _E4 / 256 + 45 * _E6 / 1024) * math.sin(4 * phi)
        - (35 * _E6 / 3072) * math.sin(6 * phi)
    )


def _tmerc_forward(phi: float, dlambda: float) -> tuple[float, float]:
    sin_phi, cos_phi = math.sin(phi), math.cos(phi)
    n = _A / math.sqrt(1 - _E2 * sin_phi**2)
    t = math.tan(phi) ** 2
    c = _EP2 * cos_phi**2
    a_coef = dlambda * cos_phi
    easting = (
        _K0 * n * (a_coef + (1 - t + c) * a_coef**3 / 6 + (5 - 18 * t + t**2 + 72 * c - 58 * _EP2) * a_coef**5 / 120)
    )
    northing = _K0 * (
        _meridional_arc(phi)
        + n
        * math.tan(phi)
        * (
            a_coef**2 / 2
            + (5 - t + 9 * c + 4 * c**2) * a_coef**4 / 24
            + (61 - 58 * t + t**2 + 600 * c - 330 * _EP2) * a_coef**6 / 720
        )
    )
    return northing, easting


def _tmerc_inverse(northing: float, easting: float, lon0: float) -> tuple[float, float]:
    meridian = northing / _K0
    mu = meridian / (_A * (1 - _E2 / 4 - 3 * _E4 / 64 - 5 * _E6 / 256))
    e1 = (1 - math.sqrt(1 - _E2)) / (1 + math.sqrt(1 - _E2))

    phi1 = (
        mu
        + (3 * e1 / 2 - 27 * e1**3 / 32) * math.sin(2 * mu)
        + (21 * e1**2 / 16 - 55 * e1**4 / 32) * math.sin(4 * mu)
        + (151 * e1**3 / 96) * math.sin(6 * mu)
        + (1097 * e1**4 / 512) * math.sin(8 * mu)
    )

    cos_phi1 = math.cos(phi1)
    c1 = _EP2 * cos_phi1**2
    t1 = math.tan(phi1) ** 2
    n1 = _A / math.sqrt(1 - _E2 * math.sin(phi1) ** 2)
    r1 = _A * (1 - _E2) / (1 - _E2 * math.sin(phi1) ** 2) ** 1.5
    d = easting / (n1 * _K0)

    phi0 = phi1 - (n1 * math.tan(phi1) / r1) * (
        d**2 / 2
        - (5 + 3 * t1 + 10 * c1 - 4 * c1**2 - 9 * _EP2) * d**4 / 24
        + (61 + 90 * t1 + 298 * c1 + 45 * t1**2 - 252 * _EP2 - 3 * c1**2) * d**6 / 720
    )
    dlambda0 = (
        d - (1 + 2 * t1 + c1) * d**3 / 6 + (5 - 2 * c1 + 28 * t1 - 3 * c1**2 + 8 * _EP2 + 24 * t1**2) * d**5 / 120
    ) / cos_phi1

    # Newton refinement, matching the source's fixed-iteration loop.
    for _ in range(10):
        n0, e0 = _tmerc_forward(phi0, dlambda0)
        sin_p, cos_p = math.sin(phi0), math.cos(phi0)
        nv = _A / math.sqrt(1 - _E2 * sin_p**2)
        rv = _A * (1 - _E2) / (1 - _E2 * sin_p**2) ** 1.5
        dphi = (northing - n0) / (rv * _K0)
        ddlambda = (easting - e0) / (nv * cos_p * _K0)
        phi0 += dphi
        dlambda0 += ddlambda
        if abs(dphi) < 1e-13 and abs(ddlambda) < 1e-13:
            break

    return math.degrees(phi0), lon0 + math.degrees(dlambda0)


def xy_to_latlon(theatre: str, x: float, y: float) -> tuple[float, float]:
    """Convert DCS local coordinates ``(x, y)`` to ``(lat, lon)`` in decimal degrees.

    Args:
        theatre: The DCS theatre name (case-insensitive; must be supported).
        x: DCS local X (northing-like), in metres. ``y``: DCS local Y (easting-like), in metres.

    Returns:
        ``(latitude, longitude)`` in decimal degrees.

    Raises:
        ValueError: when ``theatre`` is not supported.
    """
    params = _theatre_params(theatre)
    return _tmerc_inverse(x - params["y0"], y - params["x0"], params["lon0"])


def latlon_to_xy(theatre: str, lat: float, lon: float) -> tuple[float, float]:
    """Convert geographic ``(lat, lon)`` in decimal degrees to DCS local ``(x, y)`` metres.

    Args:
        theatre: The DCS theatre name (case-insensitive; must be supported).
        lat: Latitude in decimal degrees. ``lon``: Longitude in decimal degrees.

    Returns:
        ``(x, y)`` DCS local coordinates in metres.

    Raises:
        ValueError: when ``theatre`` is not supported.
    """
    params = _theatre_params(theatre)
    northing, easting = _tmerc_forward(math.radians(lat), math.radians(lon - params["lon0"]))
    return northing + params["y0"], easting + params["x0"]


def is_theatre_supported(theatre: str) -> bool:
    """Return whether coordinate conversion is available for ``theatre`` (case-insensitive)."""
    return theatre.lower() in _THEATRES


#: Mean Earth radius (metres), for the great-circle offset.
_EARTH_RADIUS_M = 6371008.8


def offset_latlon(lat: float, lon: float, bearing_deg: float, distance_m: float) -> tuple[float, float]:
    """Return the point ``distance_m`` metres from ``(lat, lon)`` along ``bearing_deg``.

    Great-circle (spherical) destination — accurate to well within DCS placement needs at the
    ranges a Mission Maker uses (e.g. "10 km north of X"). Bearing is degrees clockwise from north.

    Args:
        lat: Start latitude in decimal degrees. ``lon``: start longitude in decimal degrees.
        bearing_deg: Bearing in degrees, clockwise from true north.
        distance_m: Distance in metres.

    Returns:
        ``(latitude, longitude)`` of the destination, in decimal degrees.
    """
    delta = distance_m / _EARTH_RADIUS_M
    theta = math.radians(bearing_deg)
    phi1 = math.radians(lat)
    lambda1 = math.radians(lon)

    phi2 = math.asin(math.sin(phi1) * math.cos(delta) + math.cos(phi1) * math.sin(delta) * math.cos(theta))
    lambda2 = lambda1 + math.atan2(
        math.sin(theta) * math.sin(delta) * math.cos(phi1),
        math.cos(delta) - math.sin(phi1) * math.sin(phi2),
    )
    return math.degrees(phi2), math.degrees(lambda2)


__all__ = [
    "supported_theatres",
    "is_theatre_supported",
    "xy_to_latlon",
    "latlon_to_xy",
    "offset_latlon",
]
