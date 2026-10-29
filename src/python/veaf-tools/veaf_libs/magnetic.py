"""Magnetic declination and magnetic bearings, as DCS computes them for a mission.

DCS takes the declination from the World Magnetic Model at the mission's month and year: the Mission
Editor calls ``magvar.init(date.Month, date.Year)`` (``MissionEditor/modules/me_weather.lua``) and ships
one WMM coefficient file per five-year epoch, 1985 to 2025 (``Data/MagVar/COF``). The same coefficients,
published by NOAA (public domain), are vendored under ``data/wmm``, copied from DCS's; this module evaluates
them in pure Python, at sea level. DCS's ``1990`` file reads ``l.5`` for the secular variation of
``g(7, 3)``: the vendored copy reads ``1.5``, a change below 0.01 degree.

The cockpits read bearings magnetic: the F-16C gives the bullseye "in degrees magnetic", the F/A-18C
shows magnetic headings unless TRUE is selected on the HSI (both from their DCS manuals). So does a
briefing that says where things stand.
"""

import math
from datetime import date
from functools import lru_cache

from veaf_libs.bundled_data import read_bundled_text
from veaf_libs.coordinates import xy_to_latlon

#: The epochs of the vendored coefficient files, ``data/wmm/WMM<epoch>.COF``.
_EPOCHS = (1985, 1990, 1995, 2000, 2005, 2010, 2015, 2020, 2025)

# WGS84, kilometres, and the geomagnetic reference radius.
_A = 6378.137
_F = 1 / 298.257223563
_E2 = _F * (2 - _F)
_RE = 6371.2

#: Coefficients ``(n, m) -> (g, h, g_dot, h_dot)``, nT and nT/year.
Coefficients = dict[tuple[int, int], tuple[float, float, float, float]]


@lru_cache(maxsize=None)
def _coefficients(epoch: int) -> Coefficients:
    """One epoch's coefficients, read from its ``.COF`` file: a header, ``n m g h ġ ḣ`` rows, a line of 9s."""
    rows: Coefficients = {}
    for row in read_bundled_text("veaf_libs", "data", "wmm", f"WMM{epoch}.COF").splitlines()[1:]:
        parts = row.split()
        if len(parts) < 6 or parts[0].startswith("9999"):
            break
        rows[int(parts[0]), int(parts[1])] = (float(parts[2]), float(parts[3]), float(parts[4]), float(parts[5]))
    return rows


def _potential(coefficients: Coefficients, dt: float, r: float, phi: float, lam: float) -> float:
    """The field's potential divided by the reference radius, at geocentric ``(r, phi, lam)``.

    The Schmidt semi-normalised Legendre functions are built by recursion on ``sin(phi)``.
    """
    x, c = math.sin(phi), math.cos(phi)
    degree = max(n for n, _ in coefficients)
    p = [[0.0] * (degree + 1) for _ in range(degree + 1)]
    p[0][0] = 1.0
    for n in range(1, degree + 1):
        p[n][n] = c if n == 1 else math.sqrt((2 * n - 1) / (2 * n)) * c * p[n - 1][n - 1]
        for m in range(n):
            below = math.sqrt((n - 1) ** 2 - m * m) * p[n - 2][m] if n >= 2 else 0.0
            p[n][m] = ((2 * n - 1) * x * p[n - 1][m] - below) / math.sqrt(n * n - m * m)
    total = 0.0
    for (n, m), (g, h, g_dot, h_dot) in coefficients.items():
        g, h = g + dt * g_dot, h + dt * h_dot
        total += (_RE / r) ** (n + 1) * (g * math.cos(m * lam) + h * math.sin(m * lam)) * p[n][m]
    return total


def declination(lat: float, lon: float, when: float | date, height_km: float = 0.0) -> float:
    """The magnetic declination at a point, degrees, east positive.

    Args:
        lat: Geodetic latitude, degrees.
        lon: Longitude, degrees.
        when: A decimal year, or a date of which DCS keeps only the month and the year.
        height_km: Height above the ellipsoid, kilometres; DCS's declination is at sea level.

    Returns:
        The angle from true north to magnetic north, clockwise; from the last epoch at or before
        ``when``, the first one before 1985.
    """
    year = when.year + (when.month - 1) / 12 if isinstance(when, date) else when
    epoch = max([e for e in _EPOCHS if e <= year], default=_EPOCHS[0])
    coefficients = _coefficients(epoch)
    # Geodetic to geocentric: the field is expanded on a sphere.
    phi_d, lam = math.radians(lat), math.radians(lon)
    normal = _A / math.sqrt(1 - _E2 * math.sin(phi_d) ** 2)
    along = (normal + height_km) * math.cos(phi_d)
    up = (normal * (1 - _E2) + height_km) * math.sin(phi_d)
    r, phi = math.hypot(along, up), math.atan2(up, along)
    dt = year - epoch

    def v(r_: float, phi_: float, lam_: float) -> float:
        return _potential(coefficients, dt, r_, phi_, lam_)

    step = 1e-5
    north = -(v(r, phi + step, lam) - v(r, phi - step, lam)) / (2 * step) / r
    east = -(v(r, phi, lam + step) - v(r, phi, lam - step)) / (2 * step) / (r * math.cos(phi))
    down = (v(r + step, phi, lam) - v(r - step, phi, lam)) / (2 * step)
    # The north component, turned from the geocentric to the geodetic vertical.
    tilt = phi - phi_d
    north_geodetic = north * math.cos(tilt) - down * math.sin(tilt)
    return math.degrees(math.atan2(east, north_geodetic))


def _ecef(lat: float, lon: float) -> tuple[float, float, float]:
    """A point at sea level in Earth-centred coordinates, kilometres."""
    phi, lam = math.radians(lat), math.radians(lon)
    normal = _A / math.sqrt(1 - _E2 * math.sin(phi) ** 2)
    return (
        normal * math.cos(phi) * math.cos(lam),
        normal * math.cos(phi) * math.sin(lam),
        normal * (1 - _E2) * math.sin(phi),
    )


def true_bearing(lat1: float, lon1: float, lat2: float, lon2: float) -> float:
    """The bearing from the first point to the second on the WGS84 ellipsoid, degrees from true north in [0, 360).

    The direction to the second point, laid on the first one's horizon: within 0.001 degree of the geodesic
    up to 400 km, where a sphere is 0.1 degree off, enough to turn a rounded heading.
    """
    (x1, y1, z1), (x2, y2, z2) = _ecef(lat1, lon1), _ecef(lat2, lon2)
    dx, dy, dz = x2 - x1, y2 - y1, z2 - z1
    phi, lam = math.radians(lat1), math.radians(lon1)
    east = -math.sin(lam) * dx + math.cos(lam) * dy
    north = -math.sin(phi) * (math.cos(lam) * dx + math.sin(lam) * dy) + math.cos(phi) * dz
    return math.degrees(math.atan2(east, north)) % 360


def magnetic_bearing(theatre: str, when: date, origin: tuple[float, float], target: tuple[float, float]) -> int:
    """The magnetic bearing from one point of a mission to another, rounded, ``1``-``360``.

    The mission's ``(x, y)`` grid is a Transverse Mercator projection: its north is neither true nor
    magnetic (1.7 degrees off true on the Golan, 6 at Kobuleti). The bearing is taken true on the
    ellipsoid, then the declination at the origin, at the mission's date, is taken off it.

    Args:
        theatre: The mission's theatre (must be supported by :mod:`veaf_libs.coordinates`).
        when: The mission's date.
        origin: The point the bearing is taken from, DCS ``(x, y)``, metres.
        target: The point it goes to, DCS ``(x, y)``, metres.

    Returns:
        Degrees from magnetic north; ``360`` rather than ``0``, as a heading is read.
    """
    lat1, lon1 = xy_to_latlon(theatre, *origin)
    lat2, lon2 = xy_to_latlon(theatre, *target)
    bearing = true_bearing(lat1, lon1, lat2, lon2) - declination(lat1, lon1, when)
    return round(bearing) % 360 or 360
